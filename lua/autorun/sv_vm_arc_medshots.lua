if CLIENT then return end

util.AddNetworkString("vm_arc_medshot_sync")
util.AddNetworkString("vm_arc_medshot_use")
util.AddNetworkString("vm_arc_medshot_reset")
util.AddNetworkString("vm_arc_medshot_effect")
util.AddNetworkString("vm_arc_medshot_drop")

net.Receive("vm_arc_medshot_drop", function(len, ply)
    local shotid = net.ReadUInt(ArcticMedShots_BITS) or -1

    if ArcticMedShots_PlayerMedAmount(ply, shotid) <= 0 then return end

    local shotname = ArcticMedShots_IDToShortName[shotid] or ""
    local shottable = ArcticMedShots[shotname]

    if ! shotname then return end

    local shot = ents.Create("arc_medshot_base")
    shot:SetPos(ply:EyePos())
    shot:SetAngles(AngleRand())
    shot:Spawn()
    shot:Activate()
    shot:SetOwner(ply)
    shot.Shots = {
        [shotname] = 1
    }
    shot:SetSkin(shottable.Skin or 0)
    if shottable.ShotMaterial then
        shot:SetMaterial(shottable.ShotMaterial)
    end

    local phys = shot:GetPhysicsObject()
    phys:ApplyForceCenter(ply:EyeAngles():Forward() * 256)

    ply.ArcticMedShots_Inv[shotid] = ArcticMedShots_PlayerMedAmount(ply, shotid) - 1
    ArcticMedShots_SyncPlayer(ply)
end)

-- receive command to use a medshot
net.Receive("vm_arc_medshot_use", function(len, ply)
    local shotid = net.ReadUInt(ArcticMedShots_BITS) or ""

    local shotname = ArcticMedShots_IDToShortName[shotid] or ""

    local shottable = ArcticMedShots[shotname]

    local target = net.ReadEntity()

    if ! ply:Alive() then return end

    if IsValid(target) then
        if target:IsPlayer() and ! target:Alive() then return end
        if ! (target:IsPlayer() or shottable.AvailableForNPCs) or (target:GetPos():Distance(ply:GetPos()) > 100) then
            return
        end
    else
        target = ply
    end

    if ! shottable then return end

    ply.ArcticMedShots_Inv = ply.ArcticMedShots_Inv or {}

    -- check to see if the player actually owns the shot in question
    if ArcticMedShots_PlayerMedAmount(ply, shotid) <= 0 then return end

    ply:DoAnimationEvent(ACT_GMOD_GESTURE_MELEE_SHOVE_1HAND)

    local filter = RecipientFilter()
    filter:AddAllPlayers()
    filter:RemovePlayer(ply)
    local injectsound = CreateSound(ply, "weapons/arc_vm_medshot/healthshot_success_01.wav", filter)
    injectsound:Play()

    timer.Simple(0.75, function()
        if ! IsValid(ply) then return end
        local shot = ents.Create("arc_medshot_used")
        shot:SetPos(ply:EyePos() - Vector(0, 0, 16))
        shot:SetAngles(AngleRand())
        shot:Spawn()
        shot:Activate()
        shot:SetOwner(ply)
        shot:SetSkin(shottable.Skin or 0)
        if shottable.ShotMaterial then
            shot:SetMaterial(shottable.ShotMaterial)
        end
    end)

    shottable.OnInject(target, ply)
    -- take a shot from the player's inventory
    ply.ArcticMedShots_Inv[shotid] = ArcticMedShots_PlayerMedAmount(ply, shotid) - 1
    ArcticMedShots_SyncPlayer(ply)

    if ply != target then
        -- we need to sync the use effect
        net.Start("vm_arc_medshot_use")
        net.WriteUInt(shottable.ID, ArcticMedShots_BITS)
        net.Send(target)
    end
end)

-- send medshot inventory data
function ArcticMedShots_SyncPlayer(ply)
    ply.ArcticMedShots_Inv = ply.ArcticMedShots_Inv or {}
    local count = 0
    for _, _ in pairs(ply.ArcticMedShots_Inv) do
        count = count + 1
    end

    -- {int id = int count}
    net.Start("vm_arc_medshot_sync")
    net.WriteUInt(count, ArcticMedShots_BITS)      -- how much data do we intend to send?
    for i, k in pairs(ply.ArcticMedShots_Inv) do
        net.WriteUInt(i, ArcticMedShots_BITS)      -- ID of the shot
        net.WriteUInt(math.Clamp(k, 0, 65000), 16) -- how many of it we have
    end
    net.Send(ply)
end

-- set up medshot inventory on spawn
hook.Add("PlayerSpawn", "ArcticMedShots_PlayerSpawn", function(ply)
    ply.ArcticMedShots_ActiveEffects = {}
    ply.ArcticMedShots_Inv = {}
    timer.Simple(0, function()
        ArcticMedShots_SyncPlayer(ply)
        net.Start("vm_arc_medshot_reset")
        net.Send(ply)
        local new = {}

        for _, i in ipairs(ArcticMedShots_PendingEffects) do
            if i.ply != ply then
                table.insert(new, i)
            end
        end

        ply.OriginalJumpPower = ply:GetJumpPower()
        --        ply.OriginalGravity = ply:GetGravity() -- to anyone who knows how Gravity works in Gmod, please let me know immediately @spennytommy on Discord. I will happily credit you for helping me to get this to work.

        ArcticMedShots_PendingEffects = new
    end)
end)


function replaceStim(entityPass, random, stim)
    local shotname
    local ent = entityPass
    if random then
        shotname = ArcticMedShots_IDToShortName[math.random(#ArcticMedShots_IDToShortName)]
    elseif not random then
        shotname = stim
    end

    local shottable = ArcticMedShots[shotname]
    if ! IsValid(ent) then return end

    timer.Simple(0, function()
        local shot = ents.Create("arc_medshot_base")
        shot:SetPos(ent:GetPos() + Vector(0, 0, 4))
        shot:SetAngles(AngleRand())
        shot:Spawn()
        shot:Activate()
        shot:SetOwner(ply)
        shot.Shots = {
            [shotname] = 1
        }
        shot:SetSkin(shottable.Skin or 0)
        if shottable.ShotMaterial then
            shot:SetMaterial(shottable.ShotMaterial)
        end

        SafeRemoveEntityDelayed(ent, 0)
    end)
end

hook.Add("OnEntityCreated", "ArcticMedShots_ReplaceHL2", function(ent)
    --print("[AACS] Ent Spawn Debug - pass")
    if ent:GetClass() == "item_healthvial" then
        --print("[AACS] Ent is HealthVial Debug - pass")
        if GetConVar("aacs_medshot_replace_vial"):GetInt() == 1 then
            --print("[AACS] ConVar Vial Replace is simple Debug - pass")
            replaceStim(ent, false, "01BonusHealth")
        elseif GetConVar("aacs_medshot_replace_vial"):GetInt() == 2 then
            replaceStim(ent, true)
        end
    end
    if ent:GetClass() == "item_healthkit" then
        if GetConVar("aacs_medshot_replace_medkit"):GetInt() == 1 then
            replaceStim(ent, false, "00InstantHealth")
        elseif GetConVar("aacs_medshot_replace_medkit"):GetInt() == 2 then
            replaceStim(ent, true)
        end
    end
    if ent:GetClass() == "item_battery" then
        if GetConVar("aacs_medshot_replace_suitbattery"):GetInt() == 1 then
            replaceStim(ent, false, "02ArmorRegen")
        elseif GetConVar("aacs_medshot_replace_suitbattery"):GetInt() == 2 then
            replaceStim(ent, true)
        end
    end
end)

-- Commented out this entire section in case we need it, you're free to remove it M541 if you wish to. ~Midawek

-- hook.Add("OnEntityCreated", "ArcticMedShots_ReplaceVials", function(ent)
--     if GetConVar("arc_medshot_random_replace_vial"):GetBool() and ent:GetClass() == "item_healthvial" then
--         timer.Simple(0, function()
--             if ! IsValid(ent) then return end

--             local shotname = ArcticMedShots_IDToShortName[math.random(#ArcticMedShots_IDToShortName)]
--             local shottable = ArcticMedShots[shotname]

--             local shot = ents.Create("arc_medshot_base")
--             shot:SetPos(ent:GetPos() + Vector(0, 0, 4))
--             shot:SetAngles(AngleRand())
--             shot:Spawn()
--             shot:Activate()
--             shot:SetOwner(ply)
--             shot.Shots = {
--                 [shotname] = 1
--             }
--             shot:SetSkin(shottable.Skin or 0)
--             if shottable.ShotMaterial then
--                 shot:SetMaterial(shottable.ShotMaterial)
--             end

--             SafeRemoveEntityDelayed(ent, 0)
--         end)
--     end
-- end)

-- hook.Add("OnEntityCreated", "ArcticMedShots_SimpleReplaceVials", function(ent)
--     if GetConVar("arc_medshot_simple_replace_vial"):GetBool() and ent:GetClass() == "item_healthvial" then
--         timer.Simple(0, function()
--             if ! IsValid(ent) then return end

--             local shotname = "01BonusHealth"
--             local shottable = ArcticMedShots[shotname]

--             local shot = ents.Create("arc_medshot_base")
--             shot:SetPos(ent:GetPos() + Vector(0, 0, 4))
--             shot:SetAngles(AngleRand())
--             shot:Spawn()
--             shot:Activate()
--             shot:SetOwner(ply)
--             shot.Shots = {
--                 [shotname] = 1
--             }
--             shot:SetSkin(shottable.Skin or 0)
--             if shottable.ShotMaterial then
--                 shot:SetMaterial(shottable.ShotMaterial)
--             end

--             SafeRemoveEntityDelayed(ent, 0)
--         end)
--     end
-- end)

-- hook.Add("OnEntityCreated", "ArcticMedShots_ReplaceMedkits", function(ent)
--     if GetConVar("arc_medshot_random_replace_medkit"):GetBool() and ent:GetClass() == "item_healthkit" then
--         timer.Simple(0, function()
--             if ! IsValid(ent) then return end

--             local shotname = ArcticMedShots_IDToShortName[math.random(#ArcticMedShots_IDToShortName)]
--             local shottable = ArcticMedShots[shotname]

--             local shot = ents.Create("arc_medshot_base")
--             shot:SetPos(ent:GetPos() + Vector(0, 0, 4))
--             shot:SetAngles(AngleRand())
--             shot:Spawn()
--             shot:Activate()
--             shot:SetOwner(ply)
--             shot.Shots = {
--                 [shotname] = 1
--             }
--             shot:SetSkin(shottable.Skin or 0)
--             if shottable.ShotMaterial then
--                 shot:SetMaterial(shottable.ShotMaterial)
--             end

--             SafeRemoveEntityDelayed(ent, 0)
--         end)
--     end
-- end)

-- hook.Add("OnEntityCreated", "ArcticMedShots_SimpleReplaceMedkits", function(ent)
--     if GetConVar("arc_medshot_simple_replace_medkit"):GetBool() and ent:GetClass() == "item_healthkit" then
--         timer.Simple(0, function()
--             if ! IsValid(ent) then return end

--             local shotname = "00InstantHealth"
--             local shottable = ArcticMedShots[shotname]

--             local shot = ents.Create("arc_medshot_base")
--             shot:SetPos(ent:GetPos() + Vector(0, 0, 4))
--             shot:SetAngles(AngleRand())
--             shot:Spawn()
--             shot:Activate()
--             shot:SetOwner(ply)
--             shot.Shots = {
--                 [shotname] = 1
--             }
--             shot:SetSkin(shottable.Skin or 0)
--             if shottable.ShotMaterial then
--                 shot:SetMaterial(shottable.ShotMaterial)
--             end

--             SafeRemoveEntityDelayed(ent, 0)
--         end)
--     end
-- end)

-- hook.Add("OnEntityCreated", "ArcticMedShots_ReplaceSuitBattery", function(ent)
--     if GetConVar("arc_medshot_random_replace_suitbattery"):GetBool() and ent:GetClass() == "item_battery" then
--         timer.Simple(0, function()
--             if ! IsValid(ent) then return end

--             local shotname = ArcticMedShots_IDToShortName[math.random(#ArcticMedShots_IDToShortName)]
--             local shottable = ArcticMedShots[shotname]

--             local shot = ents.Create("arc_medshot_base")
--             shot:SetPos(ent:GetPos() + Vector(0, 0, 4))
--             shot:SetAngles(AngleRand())
--             shot:Spawn()
--             shot:Activate()
--             shot:SetOwner(ply)
--             shot.Shots = {
--                 [shotname] = 1
--             }
--             shot:SetSkin(shottable.Skin or 0)
--             if shottable.ShotMaterial then
--                 shot:SetMaterial(shottable.ShotMaterial)
--             end

--             SafeRemoveEntityDelayed(ent, 0)
--         end)
--     end
-- end)

-- hook.Add("OnEntityCreated", "ArcticMedShots_SimpleReplaceSuitBattery", function(ent)
--     if GetConVar("arc_medshot_simple_replace_suitbattery"):GetBool() and ent:GetClass() == "item_battery" then
--         timer.Simple(0, function()
--             if ! IsValid(ent) then return end

--             local shotname = "02ArmorRegen"
--             local shottable = ArcticMedShots[shotname]

--             local shot = ents.Create("arc_medshot_base")
--             shot:SetPos(ent:GetPos() + Vector(0, 0, 4))
--             shot:SetAngles(AngleRand())
--             shot:Spawn()
--             shot:Activate()
--             shot:SetOwner(ply)
--             shot.Shots = {
--                 [shotname] = 1
--             }
--             shot:SetSkin(shottable.Skin or 0)
--             if shottable.ShotMaterial then
--                 shot:SetMaterial(shottable.ShotMaterial)
--             end

--             SafeRemoveEntityDelayed(ent, 0)
--         end)
--     end
-- end)

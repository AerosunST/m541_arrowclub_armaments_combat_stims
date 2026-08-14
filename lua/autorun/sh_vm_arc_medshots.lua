local COLOR_NEUTRAL = Color(255, 255, 255)
local COLOR_GOOD = Color(25, 255, 25)
local COLOR_BAD = Color(255, 25, 25)
local COLOR_UTILITY = Color(255, 192, 0)

AddCSLuaFile()

CreateConVar("aacs_medshot_replace_vial", 0, FCVAR_ARCHIVE + FCVAR_REPLICATED,
    "Replace HL2 MedVials (10 HP) with an Arrowclub Armaments Combat Stim. 0 = Off, 1 = Simple, 2 = Random. NOTE: When in Simple Mode, MedVials will be replaced with the Bonus Health Stim.",
    0, 2)

CreateConVar("aacs_medshot_replace_medkit", 0, FCVAR_ARCHIVE + FCVAR_REPLICATED,
    "Replace HL2 MedKits (25 HP) with an Arrowclub Armaments Combat Stim. 0 = Off, 1 = Simple, 2 = Random. NOTE: When in Simple Mode, MedKits will be replaced with the Instant Health Stim.",
    0, 2)

CreateConVar("aacs_medshot_replace_suitbattery", 0, FCVAR_ARCHIVE + FCVAR_REPLICATED,
    "Replace HL2 Suit Batteries (15 Armor) with an Arrowclub Armaments Combat Stim. 0 = Off, 1 = Simple, 2 = Random. NOTE: When in Simple Mode, Suit Batteries will be replaced with the Armor Regeneration Stim.",
    0, 2)

-- Commented out old commands in case we need it, you're free to remove it M541 if you wish to. ~Midawek

-- CreateConVar("arc_medshot_random_replace_vial", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Replace HL2 MedVials (10 HP) with a randomized Arrowclub Armaments Combat Stim. NOTE: Having this and its Simple counterpart set to 1 will cause two stims to appear, do with that information as you will.")

-- CreateConVar("arc_medshot_random_replace_medkit", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Replace HL2 MedKits (25 HP) with a randomized Arrowclub Armaments Combat Stim. NOTE: Having this and its Simple counterpart set to 1 will cause two stims to appear, do with that information as you will.")

-- CreateConVar("arc_medshot_random_replace_suitbattery", "0", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Replace HL2 Suit Batteries with a randomized Arrowclub Armaments Combat Stim. NOTE: Having this and its Simple counterpart set to 1 will cause two stims to appear, do with that information as you will.")

-- CreateConVar("arc_medshot_simple_replace_vial", "0", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Replace HL2 MedVials (10 HP) with the Bonus Health Combat Stim. NOTE: Having this and its Random counterpart set to 1 will cause two stims to appear, do with that information as you will.")

-- CreateConVar("arc_medshot_simple_replace_medkit", "0", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Replace HL2 MedKits (25 HP) with the Instant Health Combat Stim. NOTE: Having this and its Random counterpart set to 1 will cause two stims to appear, do with that information as you will.")

-- CreateConVar("arc_medshot_simple_replace_suitbattery", "0", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Replace HL2 Suit Batteries with the Armor Regeneration Combat Stim. NOTE: Having this and its Random counterpart set to 1 will cause two stims to appear, do with that information as you will.")

ArcticMedShots_BITS = 8            -- should be enough to allow all ArcticMedShots to be given a unique ID

ArcticMedShots_PendingEffects = {} -- {["player"] = ply, ["effect"] = "effect", ["duration"] = int duration, ["starttime"] = int starttime}

-- REMEMBER! These will also Think() on the client if networked EVEN IF it is not applied to the player!
ArcticMedShots_Effects = { -- ["name"] = {Network = bool, Think = function(ply, timeleft), OnWearOff = function(ply, timeleft)} end
    ["fx_health_regen"] = {
        Think = function(ply, timeleft)
            if CLIENT then return end
            ply.AMS_NextHealTime = ply.AMS_NextHealTime or 0
            if ply:Health() < ply:GetMaxHealth() and ply.AMS_NextHealTime < CurTime() then
                local newhp = ply:Health() + 25
                newhp = math.Clamp(newhp, 0, ply:GetMaxHealth())
                ply:SetHealth(newhp)
                ply.AMS_NextHealTime = CurTime() + 5
            end
        end,
        StatusIcon = Material("arc_vm_medshots/regenerating_health.png", "mips")
    },
    ["fx_flight"] = {
        Think = function(ply, timeleft)
            -- if CLIENT then return end
            if ply == Entity(1) then
                ply:SetVelocity(Vector(0, 0, 1000 * FrameTime()))
            else
                ply:SetVelocity(Vector(0, 0, 2000 * FrameTime()))
            end
        end,
        StatusIcon = Material("arc_vm_medshots/flight.png", "mips")
    },
    ["fx_armor_regen"] = {
        Think = function(ply, timeleft)
            if CLIENT then return end
            ply.AMS_NextArmorTime = ply.AMS_NextArmorTime or 0
            if ply:Armor() < 100 and ply.AMS_NextArmorTime < CurTime() then
                local newarmor = ply:Armor() + 1
                newarmor = math.Clamp(newarmor, 0, 100)
                ply:SetArmor(newarmor)
                ply.AMS_NextArmorTime = CurTime() + 0.2
            end
        end,
        StatusIcon = Material("arc_vm_medshots/regenerating_armor.png", "mips")
    },
    ["fx_jump_boost"] = {
        OnWearOff = function(ply, timeleft)
            ply:SetJumpPower(ply.OriginalJumpPower or ply:GetJumpPower())
        end,
        StatusIcon = Material("arc_vm_medshots/jump_boost.png", "mips")
    },
    ["fx_moongravity"] = { -- putting this on ice until I can figure out how the hell to do Gravity shit.
        OnWearOff = function(ply, timeleft)
            ply:SetGravity(ply.BaselineGravity)
        end,
        StatusIcon = Material("arc_vm_medshots/moon_gravity.png", "mips")
    },
    ["deadsilence"] = {
        Network = true,
        StatusIcon = Material("arc_vm_medshots/stealth.png", "mips")
    },
    ["psychosis"] = {
        OnWearOff = function(ply, timeleft)
            if CLIENT then
                ply.AMS_WhineSound:Stop()
            end
        end
    },
    ["fx_damage_boost"] = {
        StatusIcon = Material("arc_vm_medshots/damage_boost.png", "mips")
    },
    ["fx_speed_down"] = {
        StatusIcon = Material("arc_vm_medshots/speed_down.png", "mips")
    },
    ["fx_super_speed_down"] = {
        StatusIcon = Material("arc_vm_medshots/super_speed_down.png", "mips")
    },
    ["antitoxin"] = {
        StatusIcon = Material("arc_vm_medshots/poison resist.png", "mips")
    },
    ["fx_nightvision"] = {
        StatusIcon = Material("arc_vm_medshots/nightvision.png", "mips")
    },
    ["fx_resist_elements"] = {
        StatusIcon = Material("arc_vm_medshots/resist_elements.png", "mips")
    },
    ["fx_invulnerability"] = {
        StatusIcon = Material("arc_vm_medshots/invulnerability.png", "mips")
    },
    ["slam"] = {
        StatusIcon = Material("arc_vm_medshots/melee damage.png", "mips")
    },
    ["fx_speed_boost"] = {
        StatusIcon = Material("arc_vm_medshots/speed_up.png", "mips")
    },
    ["fx_superspeed"] = {
        StatusIcon = Material("arc_vm_medshots/super_speed.png", "mips")
    },
}

ArcticMedShots_EffectIDToShortName = {}

local randomeffects = {
    function(ply, infl) ArcticMedShots_ApplyEffect(ply, "fx_nightvision", 60) end, -- night vision
    function(ply, infl) ArcticMedShots_ApplyEffect(ply, "fx_speed_boost", 60) end,
    function(ply, infl) ArcticMedShots_ApplyEffect(ply, "fx_superspeed", 60) end,
    function(ply, infl) ArcticMedShots_ApplyEffect(ply, "fx_invulnerability", 60) end,
    function(ply, infl) ArcticMedShots_ApplyEffect(ply, "fx_health_regen", 60) end,
    function(ply, infl) ArcticMedShots_ApplyEffect(ply, "luciferone", 60) end,
    function(ply, infl) ArcticMedShots_ApplyEffect(ply, "fx_speed_down", 60) end,
    function(ply, infl) ArcticMedShots_ApplyEffect(ply, "fx_super_speed_down", 60) end,
    function(ply, infl)
        if SERVER then
            if ply:Health() < ply:GetMaxHealth() + 25 then
                local newhp = ply:Health() + 50
                newhp = math.Clamp(newhp, 0, ply:GetMaxHealth() + 25)
                ply:SetHealth(newhp)
            end
        end
    end,
    function(ply, infl) ArcticMedShots_ApplyEffect(ply, "fx_resist_elements", 60) end,
    function(ply, infl)
        ply.OriginalJumpPower = ply.OriginalJumpPower or ply:GetJumpPower()
        ply:SetJumpPower(ply.OriginalJumpPower * 2)
        ArcticMedShots_ApplyEffect(ply, "fx_jump_boost", 120)
    end
}

ArcticMedShots = {
    ["00InstantHealth"] = {
        QuickName = "InstaHeal",
        PrintName = "Instant Health",
        Description = { "Heals 50 HP instantly.", "Overheals up to +25 HP.", "Allergen Information: Contains WMV." },
        DescriptionColors = { COLOR_GOOD, COLOR_GOOD, COLOR_NEUTRAL },
        OnInject = function(ply, infl)
            if SERVER then
                if ply:Health() < ply:GetMaxHealth() + 25 then
                    local newhp = ply:Health() + 50
                    newhp = math.Clamp(newhp, 0, ply:GetMaxHealth() + 25)
                    ply:SetHealth(newhp)
                end
            end
        end, -- shared
        Skin = 0,
    },
    ["01BonusHealth"] = {
        QuickName = "Bonus HP",
        PrintName = "Bonus Health",
        Description = { "Heals 10 HP instantly.", "Overheals up to +200 HP.", "Allergen Information: Contains WMV." },
        DescriptionColors = { COLOR_GOOD, COLOR_GOOD, COLOR_NEUTRAL },
        OnInject = function(ply, infl)
            if SERVER then
                if ply:Health() < ply:GetMaxHealth() + 200 then
                    local newhp = ply:Health() + 10
                    newhp = math.Clamp(newhp, 0, ply:GetMaxHealth() + 200)
                    ply:SetHealth(newhp)
                end
            end
        end, -- shared
        Skin = 7,
    },
    ["02ArmorRegen"] = {
        QuickName = "Armor Regen",
        PrintName = "Armor Regeneration",
        Description = { "Regenerate 5 Suit Energy per second for 30 seconds.", "Allergen Information: Contains WMV." },
        DescriptionColors = { COLOR_GOOD, COLOR_NEUTRAL },
        OnInject = function(ply, infl)
            ArcticMedShots_ApplyEffect(ply, "fx_armor_regen", 30)
        end, -- shared
        Skin = 6,
    },
    ["01HealthRegen"] = {
        QuickName = "HP Regen",
        PrintName = "Health Regeneration",
        Description = { "Regenerate 25 HP every 5 seconds for 60 seconds.", "Allergen Information: Contains WMV." },
        DescriptionColors = { COLOR_GOOD, COLOR_NEUTRAL },
        OnInject = function(ply, infl)
            ArcticMedShots_ApplyEffect(ply, "fx_health_regen", 60)
        end, -- shared
        Skin = 4,
    },
    ["03Estrogen"] = {
        QuickName = "Estrogen",
        PrintName = "Estrogen",
        Description = { "It's Estrogen. It does what Estrogen does.", "You are loved and valid.", "Allergen Information: Contains WMV." },
        DescriptionColors = { COLOR_GOOD, COLOR_GOOD, COLOR_NEUTRAL },
        OnInject = function(ply, infl)
            if SERVER then
                if ply:Health() < ply:GetMaxHealth() then
                    local newhp = ply:Health() + 99999999999999
                    newhp = math.Clamp(newhp, 0, ply:GetMaxHealth())
                    ply:SetHealth(newhp)
                end
                if ply:Armor() < ply:GetMaxArmor() then
                    local newhp = ply:Armor() + 99999999999999
                    newhp = math.Clamp(newhp, 0, ply:GetMaxArmor())
                    ply:SetArmor(newhp)
                end
            end
        end, -- shared
        Skin = 5,
    },
    ["03ResistElements"] = {
        QuickName = "Element Shield",
        PrintName = "Resist Elemental Damage",
        Description = { "Immunity to all major Elemental Damage types for 120 seconds.", "Includes Fire, Poison, Drowning, and many more.", "NOTE: Some damage types still damage armor, health unaffected.", "Allergen Information: Contains WMV." },
        DescriptionColors = { COLOR_GOOD, COLOR_GOOD, COLOR_NEUTRAL, COLOR_NEUTRAL },
        ShotMaterial = "models/weapons/v_models/arc_vm_healthshot/shot_pyro",
        OnInject = function(ply, infl)
            ArcticMedShots_ApplyEffect(ply, "fx_resist_elements", 120)
        end, -- shared
        Skin = 17,
    },
    ["00Invulnerability"] = {
        QuickName = "Invincible",
        PrintName = "Invulnerability",
        Description = { "Immunity to ALL Damage for 30 Seconds.", "-75% Movement Speed for 60 seconds.", "Allergen Information: Contains WMV." },
        DescriptionColors = { COLOR_GOOD, COLOR_BAD, COLOR_NEUTRAL },
        OnInject = function(ply, infl)
            ArcticMedShots_ApplyEffect(ply, "fx_invulnerability", 30)
            ArcticMedShots_ApplyEffect(ply, "fx_super_speed_down", 60)
        end, -- shared
        Skin = 2,
    },
    ["011SpeedUp"] = {
        QuickName = "Speed Up",
        PrintName = "Speed Up",
        Description = { "+25% movement speed for 120 seconds.", "Allergen Information: Contains WMV." },
        DescriptionColors = { COLOR_UTILITY, COLOR_NEUTRAL },
        OnInject = function(ply, infl)
            ArcticMedShots_ApplyEffect(ply, "fx_speed_boost", 120)
        end, -- shared
        Skin = 1,
    },
    ["0012SuperSpeed"] = {
        QuickName = "SuperSpeed",
        PrintName = "Super Speed",
        Description = { "+200% movement speed for 5 seconds.", "Allergen Information: Contains WMV." },
        DescriptionColors = { COLOR_UTILITY, COLOR_NEUTRAL },
        OnInject = function(ply, infl)
            ArcticMedShots_ApplyEffect(ply, "fx_superspeed", 5)
        end, -- shared
        Skin = 10,
    },
    ["06JumpBoost"] = {
        QuickName = "Jump Boost",
        PrintName = "Jump Boost",
        Description = { "+100% jump strength for 120 seconds.", "Allergen Information: Contains WMV." },
        DescriptionColors = { COLOR_UTILITY, COLOR_NEUTRAL },
        OnInject = function(ply, infl)
            ply.OriginalJumpPower = ply.OriginalJumpPower or ply:GetJumpPower()
            ply:SetJumpPower(ply.OriginalJumpPower * 2)
            ArcticMedShots_ApplyEffect(ply, "fx_jump_boost", 120)
        end, -- shared
        Skin = 3,
    },
    ["02Flight"] = {
        QuickName = "Flight",
        PrintName = "Flight",
        Description = { "Ascend into the air for 3 seconds.", "You are not immune to fall damage when this effect wears off.", "Allergen Information: Contains WMV." },
        DescriptionColors = { COLOR_UTILITY, COLOR_BAD, COLOR_NEUTRAL, },
        ShotMaterial = "models/weapons/v_models/arc_vm_healthshot/shot_oil",
        OnInject = function(ply, infl)
            ArcticMedShots_ApplyEffect(ply, "fx_flight", 3)
        end,
        Skin = 13,
    },
    ["04DamageBoost"] = {
        QuickName = "Damage Up",
        PrintName = "Damage Boost",
        Description = { "All weapons deal +1000% more damage for 60 seconds.", "-25% movement speed for 60 seconds after effect wears off.", "Allergen Information: Contains WMV." },
        DescriptionColors = { COLOR_GOOD, COLOR_BAD, COLOR_NEUTRAL },
        ShotMaterial = "models/weapons/v_models/arc_vm_healthshot/shot_weed",
        OnInject = function(ply, infl)
            ArcticMedShots_ApplyEffect(ply, "fx_damage_boost", 60)
            ArcticMedShots_ApplyEffect(ply, "fx_speed_down", 60, 60)
        end, -- shared
        Skin = 15,
    },
    ["02RemoveEffects"] = {
        QuickName = "Clear Effects",
        PrintName = "Remove Status Effects",
        Description = { "Instantly removes all active effects.", "Includes positive effects.", "Allergen Information: Contains WMV." },
        DescriptionColors = { COLOR_UTILITY, COLOR_BAD, COLOR_NEUTRAL },
        OnInject = function(ply, infl)
            for i, k in pairs(ply.ArcticMedShots_ActiveEffects) do
                local shottable = ArcticMedShots_Effects[i] or {}

                local duration = k - CurTime()

                if shottable.Network then
                    ArcticMedShots_ApplyEffect(ply, i, duration / 9999)
                else
                    ply.ArcticMedShots_ActiveEffects[i] = CurTime() + (duration / 9999)
                end
            end
        end,
        Skin = 9,
    },
    ["10RandomEffect"] = {
        QuickName = "Random Effect",
        PrintName = "Random Effect",
        Description = { "Applies two completely random effects for 60 seconds.", "Effects can be good or bad.", "NOTE: Status Icons do not always reflect the effects actually given, this is a known bug.", "Allergen Information: May Contain WMV." },
        DescriptionColors = { COLOR_UTILITY, COLOR_BAD, COLOR_NEUTRAL, COLOR_NEUTRAL },
        OnInject = function(ply, infl)
            randomeffects[math.random(#randomeffects)](ply, infl)
            randomeffects[math.random(#randomeffects)](ply, infl)
        end,
        Skin = 12
    },
    ["02MoonGravity"] = { -- big thank you to Midawek and EthicalObligation to helping getting this work, love you so much!!11!!1!1 -M541
        QuickName = "Moon Gravity",
        PrintName = "Moon Gravity",
        Description = { "Reduces Player Gravity by 90% for 120 Seconds", "Allergen Information: Contains WMV." },
        DescriptionColors = { COLOR_GOOD, COLOR_NEUTRAL },
        OnInject = function(ply, infl)
            if not ply.BaselineGravity or ply.BaselineGravity ~= ply:GetGravity() then
                print("[AACS] NUH UH (BaselineGravity doesn't exist or has been modified prior to stim use)")
                return
            end

            ply:SetGravity(0.1667)
            --[[
                HEY TOMMY HAIIII
                IF YOU WANT TO CHANGE THE VALUE IT'S UP THERE
                ON ply:SetGravity(CHANGE ME), only a number tho, you can make math there should be fine
                KTHXBAIIII
                ~Midawek
            ]]
            ArcticMedShots_ApplyEffect(ply, "fx_moongravity", 120)
        end, -- shared
        Skin = 11,
    },
    ["00Nightvision"] = {
        QuickName = "Nightvision",
        PrintName = "Nightvision",
        Description = { "Nightvision for 300 seconds.", "May be difficult to see in bright areas.", "Allergen Information: Contains WMV." },
        DescriptionColors = { COLOR_UTILITY, COLOR_NEUTRAL, COLOR_NEUTRAL },
        OnInject = function(ply, infl)
            ArcticMedShots_ApplyEffect(ply, "fx_nightvision", 300)
        end, -- shared
        Skin = 8,
    },
    -- ["psycho"] = { -- NOTE: This is a leftover from the original Arctic's Combat Stims and should not be used in Arrowclub Armaments Combant Stims. It is here purely for reference purposes. -M541
    --     QuickName = "Psycho",
    --     PrintName = "'Psycho' Mescaline Street Mix",
    --     Description = {"THIS SHIT FUCKS YOU UP", "PHARMANARCHY FUCK THE USA", "  75% damage resistance for 30 seconds.", "  Wild, terrifying hallucinations."},
    --     DescriptionColors = {COLOR_NEUTRAL, COLOR_NEUTRAL, COLOR_GOOD, COLOR_BAD},
    --     OnInject = function(ply, infl)
    --         ArcticMedShots_ApplyEffect(ply, "dmg_resist_75", 30)
    --         ArcticMedShots_ApplyEffect(ply, "psychosis", 30)

    --         if CLIENT then
    --             local s = "npc/manhack/mh_blade_loop1.wav"
    --             ply.AMS_WhineSound = CreateSound(ply, s)
    --             ply.AMS_WhineSound:Play()
    --             ply.AMS_WhineSound:ChangeVolume(0, 0)
    --             ply.AMS_WhineSound:ChangeVolume(1, 5)
    --         end
    --     end,
    --     Skin = 0
    -- }
}

for _, v in pairs(file.Find("arctic_med_shots/*", "LUA")) do
    include("arctic_med_shots/" .. v)
    AddCSLuaFile("arctic_med_shots/" .. v)
end

ArcticMedShots_IDToShortName = {}

-- index arcticmedshots table to short name converter
for i, k in pairs(ArcticMedShots) do
    ArcticMedShots[i].ID = #ArcticMedShots_IDToShortName + 1
    ArcticMedShots_IDToShortName[#ArcticMedShots_IDToShortName + 1] = i
    if CLIENT then
        if k.EntityMaterial then
            k.Material = Material("entities/" .. tostring(k.EntityMaterial) .. ".png", "mips")
        else
            k.Material = Material("entities/arc_medshot_" .. tostring(k.Skin) .. ".png", "mips")
        end
    end
end

-- ditto for networked effects
for i, k in pairs(ArcticMedShots_Effects) do
    if k.Network then
        k.ID = #ArcticMedShots_EffectIDToShortName + 1
        ArcticMedShots_EffectIDToShortName[#ArcticMedShots_EffectIDToShortName + 1] = i
    end
end

function ArcticMedShots_PlayerMedAmount(ply, shotid)
    if ! ply.ArcticMedShots_Inv[shotid] then return 0 end
    return ply.ArcticMedShots_Inv[shotid]
end

function ArcticMedShots_ApplyEffect(ply, effect, duration, delay, infl)
    if ! IsValid(ply) then return end
    infl = infl or ply

    delay = delay or 0
    ply.ArcticMedShots_ActiveEffects = ply.ArcticMedShots_ActiveEffects or {}
    ply.ArcticMedShots_ActiveEffectsInflictors = ply.ArcticMedShots_ActiveEffectsInflictors or {}
    local efftable = ArcticMedShots_Effects[effect]

    if efftable and efftable.NoReset then
        if ArcticMedShots_GetEffect(ply, effect) then
            return
        end
    end

    if delay > 0 then
        table.insert(ArcticMedShots_PendingEffects, {
            ply = ply,
            effect = effect,
            duration = duration,
            starttime = CurTime() + delay,
            infl = infl
        })
    else
        ply.ArcticMedShots_ActiveEffects[effect] = CurTime() + duration
        ply.ArcticMedShots_ActiveEffectsInflictors[effect] = infl

        if SERVER and efftable and efftable.Network then
            local effid = efftable.ID

            net.Start("vm_arc_medshot_effect")
            net.WriteEntity(ply)
            net.WriteUInt(effid, 32)
            net.WriteUInt(math.floor(duration), 32)
            net.Broadcast()
        end
    end
end

function ArcticMedShots_GetEffect(ply, effect)
    ply.ArcticMedShots_ActiveEffects = ply.ArcticMedShots_ActiveEffects or {}

    if ply.ArcticMedShots_ActiveEffects[effect] and ply.ArcticMedShots_ActiveEffects[effect] > CurTime() then
        return true
    else
        return false
    end
end

hook.Add("Think", "ArcticMedShots_Effects", function()
    local plys

    plys = player.GetAll()

    if CLIENT then
        table.insert(plys, LocalPlayer())
    end

    for _, ply in ipairs(plys) do
        for effect, dietime in pairs(ply.ArcticMedShots_ActiveEffects or {}) do
            local f = ArcticMedShots_Effects[effect] or {}
            if dietime < CurTime() then
                if f.OnWearOff then
                    f.OnWearOff(ply, dietime - CurTime())
                end

                ply.ArcticMedShots_ActiveEffects[effect] = nil
                continue
            end

            if f.Think then
                f.Think(ply, dietime - CurTime())
            end
        end
    end

    local new = {}

    for _, i in ipairs(ArcticMedShots_PendingEffects) do
        if i.starttime <= CurTime() then
            ArcticMedShots_ApplyEffect(i.ply, i.effect, i.duration)
        else
            table.insert(new, i)
        end
    end

    ArcticMedShots_PendingEffects = new
end)

hook.Add("Move", "ArcticMedShots_Move", function(ply, mv)
    ply.ArcticMedShots_ActiveEffects = ply.ArcticMedShots_ActiveEffects or {}

    local s = 1

    if ArcticMedShots_GetEffect(ply, "fx_speed_boost") then
        s = s * 1.25
    end

    if ArcticMedShots_GetEffect(ply, "fx_superspeed") then
        s = s * 3
    end

    if ArcticMedShots_GetEffect(ply, "fx_speed_down") then
        s = s * 0.75
    end

    if ArcticMedShots_GetEffect(ply, "fx_super_speed_down") then -- edit fx_super_speed_down here
        s = s * 0.25
    end

    mv:SetMaxSpeed(mv:GetMaxSpeed() * s)
    mv:SetMaxClientSpeed(mv:GetMaxClientSpeed() * s)
end)

hook.Add("EntityTakeDamage", "ArcticMedShots_EntityTakeDamage", function(ply, dmg)
    local attacker = dmg:GetAttacker()

    if attacker:IsPlayer() then
        if ArcticMedShots_GetEffect(attacker, "slam") then
            if dmg:GetDamageType() == DMG_GENERIC or dmg:GetDamageType() == DMG_CLUB or dmg:GetDamageType() == DMG_SLASH then
                dmg:ScaleDamage(10)
            end
        end

        if ArcticMedShots_GetEffect(attacker, "fx_damage_boost") then
            dmg:ScaleDamage(10)
        end
    end

    if ! ply:IsPlayer() then return end

    ply.ArcticMedShots_ActiveEffects = ply.ArcticMedShots_ActiveEffects or {}

    if ArcticMedShots_GetEffect(ply, "fx_resist_elements") and dmg:GetDamageType() == DMG_BURN or dmg:GetDamageType() == DMG_SLOWBURN or dmg:GetDamageType() == DMG_POISON or dmg:GetDamageType() == DMG_ACID or dmg:GetDamageType() == DMG_SHOCK or dmg:GetDamageType() == DMG_RADIATION or dmg:GetDamageType() == DMG_PLASMA or dmg:GetDamageType() == DMG_DROWN then
        dmg:ScaleDamage(0)
    end

    if ArcticMedShots_GetEffect(ply, "fx_invulnerability") then
        dmg:ScaleDamage(0)
    end

    if ArcticMedShots_GetEffect(ply, "dmg_resist_75") and dmg:GetDamageType() != DMG_ACID then
        dmg:ScaleDamage(0.25)
    end

    if ArcticMedShots_GetEffect(ply, "antitoxin") then
        if dmg:GetDamageType() == DMG_POISON or dmg:GetDamageType() == DMG_NERVEGAS then
            dmg:ScaleDamage(0)
        end
    end
end)

hook.Add("PlayerFootstep", "ArcticMedShots_PlayerFootstep", function(ply, pos, foot, sound, vol, filter)
    if ArcticMedShots_GetEffect(ply, "deadsilence") then
        return true
    end
end)

hook.Add("PlayerDeath", "ArcticMedShots_ClearEffectsOnDeath", function(ply, inf, att)
    -- this is a bodge fix to a solution that will be properly addressed whenever we get to refreshing the codebase, tl;dr is that whenever a player dies, their effects are cleared ~Midawek
    if not IsValid(ply) then return end
    ply.ArcticMedShots_ActiveEffects = ply.ArcticMedShots_ActiveEffects or {}
    for effect, dietime in pairs(ply.ArcticMedShots_ActiveEffects) do
        local f = ArcticMedShots_Effects[effect] or {}
        if f.OnWearOff then
            f.OnWearOff(ply, dietime - CurTime())
        end
    end
    ply.ArcicMedShots_ActiveEffects = {}
end)

if SERVER then return end

local ArcticMedShots_Owned = {} -- a table of all the stuff we probably own

net.Receive("vm_arc_medshot_effect", function(len, ply)
    local tgt = net.ReadEntity()
    local effectid = net.ReadUInt(32)
    local duration = net.ReadUInt(32)

    tgt.ArcticMedShots_ActiveEffects = tgt.ArcticMedShots_ActiveEffects or {}

    local effect = ArcticMedShots_EffectIDToShortName[effectid]

    tgt.ArcticMedShots_ActiveEffects[effect] = CurTime() + duration
end)

-- receive data from server about our medshot inventory
net.Receive("vm_arc_medshot_sync", function(len, ply)
    LocalPlayer().ArcticMedShots_Inv = {}
    ArcticMedShots_Owned = {}
    local count = net.ReadUInt(ArcticMedShots_BITS)

    if count == 0 then return end

    for i = 1, count do
        local id = net.ReadUInt(ArcticMedShots_BITS)
        local amount = net.ReadUInt(16)

        LocalPlayer().ArcticMedShots_Inv[id] = amount
        -- print(tostring(id) .. " = " .. tostring(amount))
        if amount > 0 then
            table.insert(ArcticMedShots_Owned, id)
        end
    end
end)

-- reset effects
net.Receive("vm_arc_medshot_reset", function(len, ply)
    LocalPlayer().ArcticMedShots_ActiveEffects = {}
end)

local function DropMedShot(id)
    if ArcticMedShots_PlayerMedAmount(LocalPlayer(), id) <= 0 then return end

    net.Start("vm_arc_medshot_drop")
    net.WriteUInt(id, ArcticMedShots_BITS)
    net.SendToServer()

    if ArcticMedShots_PlayerMedAmount(LocalPlayer(), id) == 1 then return true end

    return false
end

local function UseMedShot(id)
    if ArcticMedShots_PlayerMedAmount(LocalPlayer(), id) <= 0 then return end
    -- play medshot animation
    if GCAL:Play("arc_vm_medshot_inject", "left_arm") then
        local shotname = ArcticMedShots_IDToShortName[id] or ""
        local shottable = ArcticMedShots[shotname]
        local e = GCAL.ActiveTracks["left_arm"].model
        -- old was VManip:GetVMGesture(), GCAL has no function to do it this yet so this is the best way ig as of 07/17/2026, will come back to it after I implement it in release
        -- ~Midawek
        e:SetSkin(shottable.Skin or 0)
        if shottable.ShotMaterial then
            e:SetMaterial(shottable.ShotMaterial)
        end
        timer.Simple(1, function()
            if ! shottable then return end
            if ! IsValid(LocalPlayer()) then return end

            net.Start("vm_arc_medshot_use")
            net.WriteUInt(id, ArcticMedShots_BITS)
            net.WriteEntity(NULL)
            net.SendToServer()

            shottable.OnInject(LocalPlayer())
        end)
    end
    -- send the request to use the medshot to the server
end

local function UseMedShot_Attack(id)
    if ArcticMedShots_PlayerMedAmount(LocalPlayer(), id) <= 0 then return false end

    local shotname = ArcticMedShots_IDToShortName[id] or ""
    local shottable = ArcticMedShots[shotname]

    local tr = util.TraceLine({
        start = LocalPlayer():EyePos(),
        endpos = LocalPlayer():EyePos() + (LocalPlayer():EyeAngles():Forward() * 64),
        filter = LocalPlayer()
    })

    local tgt = tr.Entity

    if ! tgt or ! IsValid(tgt) or ! (tgt:IsPlayer() or (tgt:IsNPC() and shottable.AvailableForNPCs)) then return false end

    if tgt:GetPos():Distance(LocalPlayer():GetPos()) > 64 then return false end

    -- play medshot animation
    if GCAL:Play("arc_vm_medshot_inject_player", "left_arm") then
        local e = GCAL.ActiveTracks["left_arm"].model
        e:SetSkin(shottable.Skin or 0)
        if shottable.ShotMaterial then
            e:SetMaterial(shottable.ShotMaterial)
        end
        timer.Simple(1, function()
            if ! shottable then return end
            if ! IsValid(LocalPlayer()) then return end

            net.Start("vm_arc_medshot_use")
            net.WriteUInt(id, ArcticMedShots_BITS)
            net.WriteEntity(tgt)
            net.SendToServer()
        end)

        return true
    end
    -- send the request to use the medshot to the server
end

local ArcticMedShots_Menu_Alpha = 0
local ArcticMedShots_Menu_Open = false
local ArcticMedShots_Menu_LerpAlpha = 0.1
local ArcticMedShots_Menu_Select = 1
local cancel_mat = Material("arc_vm_medshots/cancel.png", "mips")
local select_mat = Material("arc_vm_medshots/select.png", "mips")
local bg_mat = Material("arc_vm_medshots/background.png", "mips")
local eff_bg_mat = Material("arc_vm_medshots/eff_bg.png", "mips")
local font = "arc_vm_medshots_8"
local font5 = "arc_vm_medshots_6"
local font_large = "arc_vm_medshots_12"
local fontf = "Metropolis Black Italic"

surface.CreateFont("arc_vm_medshots_6", {
    font = fontf,
    size = ScreenScale(4),
    weight = 0,
    antialias = true,
    extended = true, -- Required for non-latin fonts
    shadow = true,
    outline = true,
})

surface.CreateFont("arc_vm_medshots_6_shadow", {
    font = fontf,
    size = ScreenScale(4),
    blursize = 5,
    weight = 0,
    antialias = true,
    extended = true, -- Required for non-latin fonts
})

surface.CreateFont("arc_vm_medshots_8", {
    font = fontf,
    size = ScreenScale(6),
    weight = 0,
    antialias = true,
    extended = true, -- Required for non-latin fonts
})

surface.CreateFont("arc_vm_medshots_8_shadow", {
    font = fontf,
    size = ScreenScale(6),
    blursize = 5,
    weight = 0,
    antialias = true,
    extended = true, -- Required for non-latin fonts
})

surface.CreateFont("arc_vm_medshots_12", {
    font = fontf,
    size = ScreenScale(12),
    weight = 0,
    antialias = true,
    extended = true, -- Required for non-latin fonts
})

surface.CreateFont("arc_vm_medshots_12_shadow", {
    font = fontf,
    size = ScreenScale(12),
    blursize = 5,
    weight = 0,
    antialias = true,
    extended = true, -- Required for non-latin fonts
})

concommand.Add("+arc_vm_medshot", function(ply)
    -- open the medshot menu
    ArcticMedShots_Menu_Open = true
end)

concommand.Add("-arc_vm_medshot", function(ply)
    -- when released, select the medshot we are currently interacting with
    if ArcticMedShots_Menu_Open then
        ArcticMedShots_Menu_Open = false
        if ArcticMedShots_Menu_Select != 0 then
            UseMedShot(ArcticMedShots_Owned[ArcticMedShots_Menu_Select])
        end
    end
end)

hook.Add("HUDPaint", "ArcticMedShots_Menu", function()
    local ss = ScreenScale(1)
    local eff_y = ss * 4
    local eff_x = ss * 4
    local eff_w = ss * 16
    local eff_h = eff_w

    for eff, time in pairs(LocalPlayer().ArcticMedShots_ActiveEffects) do
        local efftable = ArcticMedShots_Effects[eff]

        if ! efftable then continue end
        if ! efftable.StatusIcon then continue end

        if time > CurTime() and efftable.StatusIcon then
            local remaining = time - CurTime()

            local flash = true

            if remaining < 5 then
                local nearesthalfsecond = math.Round(remaining * 4)
                if nearesthalfsecond % 2 == 0 then
                    flash = false
                end
            end

            if flash then
                surface.SetDrawColor(255, 255, 255)
                surface.SetMaterial(eff_bg_mat)
                surface.DrawTexturedRect(eff_x, eff_y, eff_w, eff_h)
                surface.SetMaterial(efftable.StatusIcon)
                surface.DrawTexturedRect(eff_x, eff_y, eff_w, eff_h)
            end

            eff_y = eff_y + eff_w + (ss * 2)
        end
    end

    if ArcticMedShots_Menu_Open then
        ArcticMedShots_Menu_Alpha = math.Approach(ArcticMedShots_Menu_Alpha, 255,
            FrameTime() * 255 / ArcticMedShots_Menu_LerpAlpha)
    else
        ArcticMedShots_Menu_Alpha = math.Approach(ArcticMedShots_Menu_Alpha, 0,
            FrameTime() * 255 / ArcticMedShots_Menu_LerpAlpha)
    end

    if ArcticMedShots_Menu_Alpha > 0 then
        if ArcticMedShots_Menu_Select > #ArcticMedShots_Owned then
            ArcticMedShots_Menu_Select = #ArcticMedShots_Owned
        elseif ArcticMedShots_Menu_Select < 0 then
            ArcticMedShots_Menu_Select = 0
        end

        local bsize = ss * 32

        local helptext1 = "ATTACK1 to inject others"

        surface.SetFont(font)
        local w = surface.GetTextSize(helptext1)

        surface.SetTextColor(0, 0, 0, ArcticMedShots_Menu_Alpha)
        surface.SetFont(font .. "_shadow")
        surface.SetTextPos(ScrW() / 2 - (w / 2), ScrH() - ss * (8 + 8 + 4))
        surface.DrawText(helptext1)

        surface.SetTextColor(255, 255, 255, ArcticMedShots_Menu_Alpha)
        surface.SetFont(font)
        surface.SetTextPos(ScrW() / 2 - (w / 2), ScrH() - ss * (8 + 8 + 4))
        surface.DrawText(helptext1)

        local helptext2 = "ATTACK2 to drop a stim"

        surface.SetFont(font)
        w = surface.GetTextSize(helptext1)

        surface.SetTextColor(0, 0, 0, ArcticMedShots_Menu_Alpha)
        surface.SetFont(font .. "_shadow")
        surface.SetTextPos(ScrW() / 2 - (w / 2), ScrH() - ss * (8 + 4))
        surface.DrawText(helptext2)

        surface.SetTextColor(255, 255, 255, ArcticMedShots_Menu_Alpha)
        surface.SetFont(font)
        surface.SetTextPos(ScrW() / 2 - (w / 2), ScrH() - ss * (8 + 4))
        surface.DrawText(helptext2)

        surface.SetDrawColor(255, 255, 255, ArcticMedShots_Menu_Alpha)

        local offset = (ArcticMedShots_Menu_Select * -32 * ss) + (ScrH() / 2) - (16 * ss)

        surface.SetMaterial(cancel_mat)
        surface.DrawTexturedRect(ss * 4, offset, bsize, bsize)

        for i, k in ipairs(ArcticMedShots_Owned) do
            local shotname = ArcticMedShots_IDToShortName[k]
            if ! shotname then continue end
            local amt = ArcticMedShots_PlayerMedAmount(LocalPlayer(), k)
            if amt > 99 then
                amt = "99+"
            end
            surface.SetMaterial(bg_mat)
            surface.DrawTexturedRect(ss * 4, offset + (i * bsize), bsize, bsize)

            local shottable = ArcticMedShots[shotname]
            surface.SetMaterial(shottable.Material)
            surface.DrawTexturedRect(ss * 4, offset + (i * bsize), bsize, bsize)

            surface.SetFont(font5)
            w = surface.GetTextSize(shottable.QuickName)

            surface.SetTextColor(2, 0, 0, ArcticMedShots_Menu_Alpha)
            surface.SetFont(font5 .. "_shadow")
            surface.SetTextPos(ss * 4 + (ss * 30) - w, offset + (i * bsize) + (ss * (32 - 7)))
            surface.DrawText(shottable.QuickName)

            surface.SetTextColor(255, 255, 255, ArcticMedShots_Menu_Alpha) -- Stim Short Title Color (as in, the tiny little title text in the selection list)
            surface.SetFont(font5)
            surface.SetTextPos(ss * 4 + (ss * 30) - w, offset + (i * bsize) + (ss * (32 - 7)))
            surface.DrawText(shottable.QuickName)

            surface.SetFont(font)
            local w2 = surface.GetTextSize(tostring(amt))

            surface.SetTextColor(0, 0, 0, ArcticMedShots_Menu_Alpha)
            surface.SetFont(font .. "_shadow")
            surface.SetTextPos(ss * 2.5 + (ss * 29) - w2, offset + (i * bsize) + (ss * 3))
            surface.DrawText(tostring(amt))

            surface.SetTextColor(255, 255, 255, ArcticMedShots_Menu_Alpha) -- Stim Count Color
            surface.SetFont(font)
            surface.SetTextPos(ss * 2.5 + (ss * 29) - w2, offset + (i * bsize) + (ss * 3))
            surface.DrawText(tostring(amt))
        end

        surface.SetMaterial(select_mat)
        surface.DrawTexturedRect(ss * 4, (ScrH() / 2) - (16 * ss), bsize, bsize)

        local title = ""
        local desc = {}
        local desccolors = {}

        if ArcticMedShots_Menu_Select == 0 then
            title = "Cancel"
        else
            local shotid = ArcticMedShots_IDToShortName[ArcticMedShots_Owned[ArcticMedShots_Menu_Select]]
            local shottable = ArcticMedShots[shotid]
            if shottable then
                title = shottable.PrintName
                desc = shottable.Description
                desccolors = shottable.DescriptionColors
            end
        end

        surface.SetTextColor(0, 0, 0, ArcticMedShots_Menu_Alpha)
        surface.SetFont(font_large .. "_shadow")
        surface.SetTextPos(ss * (4 + 32 + 4), ScrH() / 2 - (ss * 16))
        surface.DrawText(title)

        surface.SetTextColor(255, 255, 255, ArcticMedShots_Menu_Alpha)
        surface.SetFont(font_large)
        surface.SetTextPos(ss * (4 + 32 + 4), ScrH() / 2 - (ss * 16))
        surface.DrawText(title)

        for i, k in ipairs(desc) do
            local dc = desccolors[i] or Color(255, 255, 255)
            surface.SetTextColor(0, 0, 0, ArcticMedShots_Menu_Alpha)
            surface.SetFont(font .. "_shadow")
            surface.SetTextPos(ss * (4 + 32 + 8), ScrH() / 2 - (ss * 12) + (ss * 8 * i))
            surface.DrawText(k)

            surface.SetTextColor(dc.r, dc.g, dc.b, ArcticMedShots_Menu_Alpha)
            surface.SetFont(font)
            surface.SetTextPos(ss * (4 + 32 + 8), ScrH() / 2 - (ss * 12) + (ss * 8 * i))
            surface.DrawText(k)
        end
    end
end)

local function ArcticMedShots_Menu_Scroll(amt)
    ArcticMedShots_Menu_Select = ArcticMedShots_Menu_Select + amt

    if ArcticMedShots_Menu_Select > #ArcticMedShots_Owned then
        ArcticMedShots_Menu_Select = #ArcticMedShots_Owned
    elseif ArcticMedShots_Menu_Select < 0 then
        ArcticMedShots_Menu_Select = 0
    end
end

hook.Add("PlayerBindPress", "ArcticMedShots_Binds", function(ply, bind, pressed)
    if ! ArcticMedShots_Menu_Open then return end
    if ! pressed then return end

    if bind == "invnext" then
        ArcticMedShots_Menu_Scroll(1)
        return true
    elseif bind == "invprev" then
        ArcticMedShots_Menu_Scroll(-1)
        return true
    elseif bind == "+attack" then
        if ArcticMedShots_Menu_Select != 0 then
            if UseMedShot_Attack(ArcticMedShots_Owned[ArcticMedShots_Menu_Select]) then
                ArcticMedShots_Menu_Open = false
            end
        end
        return true
    elseif bind == "+attack2" then
        if ArcticMedShots_Menu_Select != 0 then
            DropMedShot(ArcticMedShots_Owned[ArcticMedShots_Menu_Select])
            ArcticMedShots_Menu_Open = false
        end
        return true
    end
end)

local function jumpscare()
    render.UpdateScreenEffectTexture()
    render.SetMaterial(spookypics[math.random(#spookypics)])
    render.DrawScreenQuad(true)

    surface.PlaySound(superspookysounds[math.random(#superspookysounds)])
end

local mat_psychooverlay = Material("models/props_lab/tank_glass001")

hook.Add("RenderScreenspaceEffects", "ArcticMedShots_RSE", function()
    if ! LocalPlayer():IsValid() then return end

    LocalPlayer().ArcticMedShots_ActiveEffects = LocalPlayer().ArcticMedShots_ActiveEffects or {}

    if LocalPlayer().ArcticMedShots_ActiveEffects["fx_nightvision"] then
        local tab = {}

        tab["$pp_colour_addr"] = 0
        tab["$pp_colour_addg"] = 0
        tab["$pp_colour_addb"] = 0
        tab["$pp_colour_brightness"] = 0.01
        tab["$pp_colour_contrast"] = 3
        tab["$pp_colour_colour"] = 0.75
        tab["$pp_colour_mulr"] = 0
        tab["$pp_colour_mulg"] = 0.1
        tab["$pp_colour_mulb"] = 0.1

        DrawColorModify(tab)
    end

    if LocalPlayer().ArcticMedShots_ActiveEffects["psychosis"] then
        render.UpdateScreenEffectTexture()
        render.SetMaterial(mat_psychooverlay)
        render.DrawScreenQuad(true)

        local chance = 1 * FrameTime()

        if math.Rand(0, 100) < chance then
            jumpscare()
        end
    end
end)

net.Receive("vm_arc_medshot_use", function(len, ply)
    local shotid = net.ReadUInt(ArcticMedShots_BITS)
    local shot = ArcticMedShots_IDToShortName[shotid]
    local shottable = ArcticMedShots[shot]

    shottable.OnInject(LocalPlayer(), LocalPlayer())
end)

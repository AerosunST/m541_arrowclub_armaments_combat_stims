AddCSLuaFile()
local addonName = "Arrowclub Armanents Combat Stims"
-- M541 change this (^^^^^^^^) is if I am wrong ~Midawek
GCAL:RegisterAnim("arc_vm_medshot_inject",
    {
        model = "weapons/c_mifl_vm_medshot.mdl",
        sequence = "milf_vm_medshot_inject",
        lerp_peak = 1.8,
        easing_in = "Legacy",
        lerp_speed_in = 0.85,
        lerp_speed_out = 0.85,
        lerp_curve = 0.5,
        speed = 0.5,
        startcycle = 0,
        loop = false,
        sounds = {
            ["weapons/arc_vm_medshot/healthshot_prepare_01.wav"] = 0,
            -- ["weapons/arc_vm_medshot/adrenaline_cap_off.wav"] = 25 / 30,
            ["weapons/arc_vm_medshot/adrenaline_needle_open.wav"] = 7 / 30,
            ["weapons/arc_vm_medshot/healthshot_thud_01.wav"] = 28 / 30,
            ["weapons/arc_vm_medshot/healthshot_success_01.wav"] = 31 / 30
        },
        segmented = false,
        preventquit = false,
        locktoply = true,
        cam_ang = Angle(0, 90, 90),
        hand = "left",
        addon = addonName
        --  holdtime = nil
        -- psst, use instead gcal_play instead of `holdtime = nil` and thank me later ~Midawek
    }
)
-- Using arc_vm animation here as the mifl version doesn't have inject player animation!!
GCAL:RegisterAnim("arc_vm_medshot_inject_player",
    {
        model = "weapons/c_arc_vm_medshot.mdl",
        sequence = "arc_vm_medshot_inject_player",
        lerp_peak = 1.8,
        easing_in = "Legacy",
        lerp_speed_in = 0.85,
        lerp_speed_out = 0.85,
        lerp_curve = 0.5,
        speed = 0.5,
        startcycle = 0,
        loop = false,
        sounds = {
            ["weapons/arc_vm_medshot/healthshot_prepare_01.wav"] = 0,
            -- ["weapons/arc_vm_medshot/adrenaline_cap_off.wav"] = 25 / 30,
            ["weapons/arc_vm_medshot/adrenaline_needle_open.wav"] = 7 / 30,
            ["weapons/arc_vm_medshot/healthshot_thud_01.wav"] = 28 / 30,
            ["weapons/arc_vm_medshot/healthshot_success_01.wav"] = 31 / 30
        },
        segmented = false,
        preventquit = false,
        locktoply = true,
        cam_ang = Angle(0, 90, 90),
        hand = "left",
        addon = addonName
        -- holdtime = nil
    }
)

--this is for thirdperson, if you don't want it add to registers `thirdperson = false` and comment out RegisterTPIKOptions below... To be fair it's broken and it looks like the user is injecting in to their head and for the inject_player it looks fine...ish
-- ~Midawek
GCAL:RegisterTPIKOptions("arc_vm_medshot_inject", {
    model_bone = "ValveBiped.Bip01_L_Hand",
    model_max_distance = 2,
    target_radius = 20,
    offset_z = 0,
})

GCAL:RegisterTPIKOptions("arc_vm_medshot_inject_player", {
    model_bone = "ValveBiped.Bip01_L_Hand",
    --model_max_distance = 20,
    target_radius = 38,
})

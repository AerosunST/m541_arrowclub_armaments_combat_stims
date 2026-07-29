AddCSLuaFile()

ENT.PrintName = "Med Shot"
ENT.Spawnable = false
ENT.Category = "Arrowclub Armaments Combat Stims"
ENT.Type = "anim"
ENT.Base = "base_entity"

ENT.DisableDuplicator = true
ENT.Shots = {}
ENT.Skin = 0
ENT.Model = "models/weapons/w_arc_vm_medshot.mdl"
ENT.ShotMaterial = nil

function ENT:Initialize()
    self:SetModel(self.Model)

    if SERVER then
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetUseType(SIMPLE_USE)
        self:PhysWake()
        self:SetSkin(self.Skin)

        if self.ShotMaterial then
            self:SetMaterial(self.ShotMaterial)
        end

        self:SetTrigger(true) -- Enables Touch() to be called even when not colliding
        self:UseTriggerBounds(true, 16)

        timer.Simple(0, function()
            if !IsValid(self) then return end

            self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
        end)

        self.SpawnTime = CurTime()
    end
end

function ENT:Touch(ent)
    if !IsValid(ent) then return end
    if !ent:IsPlayer() or self.PickedUp then return end
    if ent == self:GetOwner() and self.SpawnTime > (CurTime() - 1) then return end

    ent.ArcticMedShots_Inv = ent.ArcticMedShots_Inv or {}

    for i, k in pairs(self.Shots) do
        if !isnumber(k) then continue end
        local shotid = ArcticMedShots[i].ID
        ent.ArcticMedShots_Inv[shotid] = (ent.ArcticMedShots_Inv[shotid] or 0) + k
    end

    ArcticMedShots_SyncPlayer(ent)

    self:Remove()
    self.PickedUp = true
    self:EmitSound("weapons/arc_vm_medshot/adrenaline_cap_off.wav")
end

function ENT:DrawTranslucent()
    self:Draw()
end

function ENT:Draw()
    self:DrawModel()
end
AddCSLuaFile()

ENT.PrintName = "Med Shot (Used)"
ENT.Spawnable = false
ENT.Category = "Arrowclub Armaments Combat Stims"
ENT.Type = "anim"
ENT.Base = "base_entity"

ENT.Skin = 0
ENT.Model = "models/weapons/w_arc_vm_medshot_used.mdl"
ENT.LifeTime = 5

ENT.Dying = false

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

        timer.Simple(0, function()
            if !IsValid(self) then return end

            self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
        end)

        self.SpawnTime = CurTime()
        self:NextThink(self.SpawnTime + self.LifeTime)
    end
end

function ENT:Think()
    if SERVER then
        if CurTime() - self.SpawnTime >= self.LifeTime then self:Remove() end
    else
        if !self.SpawnTime then
            self:SetRenderMode(RENDERMODE_TRANSALPHA)
            self.SpawnTime = CurTime()
        end

        if CurTime() - self.SpawnTime >= (self.LifeTime - 1) and !self.Dying then self:SetRenderFX( kRenderFxFadeFast ) end
    end
end

function ENT:DrawTranslucent()
    self:Draw()
end

function ENT:Draw()
    self:DrawModel()
end
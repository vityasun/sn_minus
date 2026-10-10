-- Written for: SlashMoon. By: VIKA & Ronni

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel("models/props_halloween/halloween_gift.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_BBOX)
    self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
    self:SetTrigger(true)
    self:SetUseType(SIMPLE_USE)
    self.SpawnTime = CurTime()
    self.IsUsed = false
    self:SetRenderMode(RENDERMODE_TRANSCOLOR)
    self:SetColor(Color(255, 255, 255, 255))
    self:EmitSound("items/battery_pickup.wav")
end

function ENT:OnRemove()
    if SlashMoon.Gifts and SlashMoon.Gifts.ClearGift then
        SlashMoon.Gifts.ClearGift(self)
    end
end

function ENT:Touch(ply)
    if self.IsUsed or CurTime() - self.SpawnTime < 1.5 then return end
    if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() or not ply:IsSurvivor() then return end

    self.IsUsed = true
    local owner = self:GetOwner()
    local ownGift = owner == ply
    local applied = false
    local negative = false

    if ownGift then
        applied = SlashMoon.Gifts.ApplyPositive(ply, self.SN_Reward)
    elseif math.Rand(0, 1) < (SlashMoon.Gifts.ForeignNegativeChance or 0.50) then
        local effect = SlashMoon.Gifts.PickNegative and SlashMoon.Gifts.PickNegative(ply)
        if not effect then self.IsUsed = false return end
        applied = SlashMoon.Gifts.ApplyNegative(ply, effect)
        negative = applied
    else
        applied = SlashMoon.Gifts.ApplyPositive(ply, self.SN_Reward)
    end

    if applied and not negative then ply:EmitSound("orch_hit_csharp_short.wav") end
    self:Remove()
end

function ENT:Use(ply)
    self:Touch(ply)
end

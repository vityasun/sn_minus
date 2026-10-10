-- Written for: SlashMoon. By: VIKA & Ronni

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel("models/props_mining/diesel_generator.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_VPHYSICS)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:EnableMotion(false) end

    self:SetNW2Bool("SN_Fueled", false)
    self:SetNW2Int("SN_Fuel", 0)
end

function ENT:OnTakeDamage() end

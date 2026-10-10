-- Written for: SlashMoon. By: VIKA & Ronni

-- ========================================================
-- SN Tasks: Charging Station Entity (Server)
-- ========================================================
AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

util.AddNetworkString("SN_Charging_Station_Charged")

function ENT:Initialize()
    self:SetModel("models/station_new/charging_station.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_VPHYSICS)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:EnableMotion(false) end

    self:SetNW2Bool("SN_ChargingStation", true)
    self.NextUse = 0
end

function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() or not activator:Alive() then return end
    if not SlashMoon.Tasks.Game.IsSurvivor(activator) then return end
    if activator:GetPos():Distance(self:GetPos()) > 120 then return end

    -- Rate limit
    if CurTime() < self.NextUse then return end
    self.NextUse = CurTime() + 0.5

    -- Charge the player's flashlight
    activator:Flashlight(true)

    -- Play sound
    activator:EmitSound("items/flashlight1.wav")

    -- Network broadcast
    net.Start("SN_Charging_Station_Charged")
        net.WriteEntity(activator)
    net.Broadcast()
end

function ENT:OnTakeDamage() end

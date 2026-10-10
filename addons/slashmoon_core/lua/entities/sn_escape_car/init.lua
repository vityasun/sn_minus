-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("tasks")

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

util.AddNetworkString("SN_Escape_CarTrigger")

function ENT:Initialize()
    self:SetModel("models/props_vehicles/car001a_hatchback.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_VPHYSICS)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:EnableMotion(false) end
end

function ENT:OnTakeDamage() end

-- Оставлено для совместимости со старыми клиентами. Прогресс и завершение
-- эвакуации обрабатываются серверным тиком фазы.
MODULE:Receive("SN_Escape_CarTrigger", function(len, ply)
    if not IsValid(ply) or len ~= 16 then return end
    if not SlashMoon.Security or not SlashMoon.Security.CheckRateLimit(ply, "escape_car_legacy", 1) then return end
    net.ReadEntity()
end)

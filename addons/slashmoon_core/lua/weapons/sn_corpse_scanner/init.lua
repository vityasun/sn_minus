-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("tasks")

AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

MODULE:Hook("PlayerDeath", "SN_Investigation_DropScanner", function(ply)
    if not IsValid(ply) then return end
    local scanner = ply:GetWeapon("sn_corpse_scanner")
    if IsValid(scanner) then ply:DropWeapon(scanner) end
end)

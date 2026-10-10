-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("tasks")

-- ========================================================
-- SN Tasks: Gascan Entity (Client HUD + Localized)
-- ========================================================
include("shared.lua")

function ENT:Draw()
    self:DrawModel()
end

MODULE:Hook("HUDPaint", "SN_GascanWorld_HUD", function()
    local ply = LocalPlayer()
    if not SlashMoon.Tasks.Game.IsSurvivor(ply) then return end

    local tr = ply:GetEyeTrace()
    local ent = tr.Entity
    if not IsValid(ent) or ent:GetClass() ~= "sn_gascan" then return end
    if ply:GetPos():Distance(ent:GetPos()) > 120 then return end

    local isUnknown = ent:GetNW2Bool("SN_UnknownFuel", true)
    local fuelTxt = isUnknown and "?" or (ent:GetNW2Int("SN_Fuel", 0) .. "%")

    local hintText = SlashMoon.Tasks.Lang("sn.inv.gascan_hint", fuelTxt)
    SlashMoon.UI.Draw.TextShadow(hintText, "SlashMoon.Header", ScrW() / 2, ScrH() / 2 + SlashMoon.UI.Scale(40), SlashMoon.UI.Colors.Theme, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

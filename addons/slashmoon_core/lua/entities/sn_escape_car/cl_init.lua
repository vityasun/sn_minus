-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("tasks")

-- ========================================================
-- SN Tasks: Escape Car Entity (Client HUD + Localized)
-- ========================================================
include("shared.lua")

function ENT:Draw() self:DrawModel() end

MODULE:Hook("HUDPaint", "SN_EscapeCar_HUD", function()
    local ply = LocalPlayer()
    if not SlashMoon.Tasks.Game.IsSurvivor(ply) then return end
    if ply:GetNW2Bool("fhi_escaped", false) then return end

    local phase = SlashMoon.Tasks.GetPhase and SlashMoon.Tasks.GetPhase() or "none"
    if phase ~= "escape" then return end

    local tr = ply:GetEyeTrace()
    local ent = tr.Entity
    if not IsValid(ent) or ent:GetClass() ~= "sn_escape_car" then return end
    if ply:GetPos():DistToSqr(ent:GetPos()) > 180 * 180 then return end

    local hintText = SlashMoon.Tasks.Lang("sn.escape.car_hint")
    SlashMoon.UI.Draw.TextShadow(hintText, "SlashMoon.Header", ScrW() / 2, ScrH() / 2 + SlashMoon.UI.Scale(40), Color(50, 220, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("tasks")

include("shared.lua")

function ENT:Draw()
    self:DrawModel()
end

MODULE:Hook("HUDPaint", "SN_DeliveryZone_HUD", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not SlashMoon.Tasks.Game.IsSurvivor(ply) then return end
    local ent = ply:GetEyeTrace().Entity
    if not IsValid(ent) or ent:GetClass() ~= "sn_delivery_zone" then return end
    if ply:GetPos():DistToSqr(ent:GetPos()) > 120 * 120 then return end
    local itemName = SlashMoon.Tasks.GetItemName(ent:GetNW2String("SN_DeliveryItem", ""))
    local delivered = ent:GetNW2Int("SN_DeliveredCount", 0)
    local required = math.max(1, ent:GetNW2Int("SN_DeliveryRequired", 1))
    local text = ent:GetNW2Bool("SN_Delivered", false)
        and SlashMoon.Tasks.Lang("sn.task.delivery.delivered")
        or SlashMoon.Tasks.Lang("sn.task.delivery.use_hint", itemName, delivered, required)
    SlashMoon.UI.Draw.TextShadow(text, "SlashMoon.Header", ScrW() / 2, ScrH() / 2 + 40, Color(80, 220, 140), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

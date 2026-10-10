-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("tasks")

include("shared.lua")

function ENT:Draw()
    self:DrawModel()
end

-- ========================================================
-- Подсказка при наведении на выброшенный предмет
-- Показывает название, тип и редкость (для оружия)
-- ========================================================
MODULE:Hook("HUDPaint", "SN_ItemDrop_HUD", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end

    local tr = ply:GetEyeTrace()
    local ent = tr.Entity

    if not IsValid(ent) or ent:GetClass() ~= "sn_item_drop" then return end
    if ply:GetPos():Distance(tr.HitPos) > 120 then return end

    local class = ent:GetNW2String("ItemClass", "")
    if class == "" then return end

    local data = SlashMoon.Tasks.GetItemData(class)
    local typeColor = SlashMoon.Tasks.GetTypeColor(data.type)

    -- Название предмета
    local y = ScrH() / 2 + 60
    SlashMoon.UI.Draw.TextShadow(data.name, "SlashMoon.Header", ScrW() / 2, y, typeColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    -- Редкость (для оружия)
    if data.type == "weapon" and data.rarity then
        local rarityColor = SlashMoon.Tasks.GetRarityColor(data.rarity)
        local rarityName = SlashMoon.Tasks.GetRarityName(data.rarity)
        y = y + 20
        SlashMoon.UI.Draw.TextShadow("[" .. rarityName .. "]", "SlashMoon.Small", ScrW() / 2, y, rarityColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- Подсказка подбора
    y = y + 25
    local hintText = SlashMoon.Tasks.Lang("sn.inv.pickup_hint", "")
    SlashMoon.UI.Draw.TextShadow("[E] " .. hintText, "SlashMoon.Small", ScrW() / 2, y, Color(200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

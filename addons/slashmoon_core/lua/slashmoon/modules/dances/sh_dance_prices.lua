-- Written for: SlashMoon. By: VIKA & Ronni

-- ========================================================
-- Цены анимаций берутся из магазина модуля "Хаб"
-- ========================================================

SlashMoon.Dances = SlashMoon.Dances or {}

--- Цена анимации (0 — бесплатно или магазин выключен).
function SlashMoon.Dances.GetPrice(animID)
    local hub = SlashMoon.Hub
    if hub and hub.GetPrice and SlashMoon.Modules.IsEnabled("hub") then
        return hub.GetPrice(animID) or 0
    end
    return 0
end

--- Платная ли анимация.
function SlashMoon.Dances.IsPaid(animID)
    if SlashMoon.Dances.IsFree(animID) then return false end
    return SlashMoon.Dances.GetPrice(animID) > 0
end

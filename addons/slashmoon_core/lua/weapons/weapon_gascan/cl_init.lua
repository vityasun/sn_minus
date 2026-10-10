-- Written for: SlashMoon. By: VIKA & Ronni

-- ========================================================
-- SN Tasks: Gas Can Weapon (Client HUD + Localized)
-- ========================================================
include("shared.lua")

function SWEP:DrawHUD()
    local fuel = self:GetNW2Int("SN_Fuel", 0)
    local sw, sh = ScrW(), ScrH()
    local bw, bh = SlashMoon.UI.Scale(160), SlashMoon.UI.Scale(14)
    local bx, by = sw - bw - SlashMoon.UI.Scale(24), sh - SlashMoon.UI.Scale(90)

    surface.SetDrawColor(SlashMoon.UI.Colors.DarkBG)
    surface.DrawRect(bx - 2, by - 2, bw + 4, bh + 4)

    surface.SetDrawColor(SlashMoon.UI.Colors.Theme)
    surface.DrawRect(bx, by, bw * (fuel / 100), bh)

    local fuelText = SlashMoon.Tasks.Lang("sn.inv.fuel_label", fuel)
    SlashMoon.UI.Draw.TextShadow(fuelText, "SlashMoon.Small", bx + bw / 2, by + bh / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

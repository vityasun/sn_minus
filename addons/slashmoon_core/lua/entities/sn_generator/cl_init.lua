-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("tasks")

-- ========================================================
-- SN Tasks: Generator Entity (Client HUD + Localized)
-- ========================================================
include("shared.lua")

function ENT:Draw()
    self:DrawModel()
end

MODULE:Hook("HUDPaint", "SN_Generator_HUD", function()
    local ply = LocalPlayer()
    if not SlashMoon.Tasks.Game.IsSurvivor(ply) then return end

    local tr = ply:GetEyeTrace()
    local ent = tr.Entity
    if not IsValid(ent) or ent:GetClass() ~= "sn_generator" then return end
    if ply:GetPos():Distance(ent:GetPos()) > 150 then return end

    local fueled = ent:GetNW2Bool("SN_Fueled", false)
    local fuel = ent:GetNW2Int("SN_Fuel", 0)
    local sw, sh = ScrW(), ScrH()

    local title = fueled and SlashMoon.Tasks.Lang("sn.task.generator.fueled") or SlashMoon.Tasks.Lang("sn.task.generator.title")
    local color = fueled and Color(50, 220, 100) or SlashMoon.UI.Colors.Theme

    SlashMoon.UI.Draw.TextShadow(title, "SlashMoon.Header", sw / 2, sh / 2 + SlashMoon.UI.Scale(40), color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    if not fueled then
        local bw, bh = SlashMoon.UI.Scale(160), SlashMoon.UI.Scale(12)
        local bx, by = sw / 2 - bw / 2, sh / 2 + SlashMoon.UI.Scale(60)

        surface.SetDrawColor(SlashMoon.UI.Colors.DarkBG)
        surface.DrawRect(bx, by, bw, bh)
        surface.SetDrawColor(SlashMoon.UI.Colors.Theme)
        surface.DrawRect(bx, by, bw * (fuel / 100), bh)
        surface.SetDrawColor(SlashMoon.UI.Colors.Outline)
        surface.DrawOutlinedRect(bx, by, bw, bh, 1)

        local progressText = SlashMoon.Tasks.Lang("sn.task.generator.progress", fuel)
        SlashMoon.UI.Draw.TextShadow(progressText, "SlashMoon.Small", sw / 2, by + bh + SlashMoon.UI.Scale(10), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end
end)

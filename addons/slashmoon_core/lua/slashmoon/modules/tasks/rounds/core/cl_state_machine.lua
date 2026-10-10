-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("tasks")

-- ========================================================
-- SN Gamemode: Client State UI & Fullscreen Results (Localized)
-- ========================================================
if not CLIENT then return end

local colors = SlashMoon.UI.Colors
local stateBannerText = ""
local stateBannerColor = color_white
local stateBannerEnd = 0
-- Баннеры смены состояния раунда вверху экрана
MODULE:Receive("SN_Round_StateChanged", function()
    local newState = net.ReadInt(4)
    local endTime = net.ReadFloat()

    if newState == SlashMoon.Rounds.STATE_PREPARE then
        stateBannerText = SlashMoon.Tasks.Lang("sn.round.prepare")
        stateBannerColor = colors.Theme
        stateBannerEnd = CurTime() + 4
        surface.PlaySound("ambient/alarms/warningbell1.wav")
    elseif newState == SlashMoon.Rounds.STATE_ACTIVE then
        stateBannerText = SlashMoon.Tasks.Lang("sn.round.active")
        stateBannerColor = Color(50, 200, 100)
        stateBannerEnd = CurTime() + 4
        surface.PlaySound("buttons/button14.wav")
    end
end)

-- Отрисовка плашки смены состояний вверху
MODULE:Hook("HUDPaint", "SN_State_DrawBanners", function()
    if CurTime() < stateBannerEnd then
        local alpha = math.Clamp((stateBannerEnd - CurTime()) * 255, 0, 255)
        local drawCol = Color(stateBannerColor.r, stateBannerColor.g, stateBannerColor.b, alpha)

        SlashMoon.UI.Draw.TextShadow(stateBannerText, "SlashMoon.Broadcast", ScrW() / 2, ScrH() * 0.2, drawCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end)

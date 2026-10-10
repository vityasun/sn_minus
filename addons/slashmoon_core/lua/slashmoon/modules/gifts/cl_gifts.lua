-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("gifts")

if not CLIENT then return end

SlashMoon.Gifts = SlashMoon.Gifts or {}
SlashMoon.Gifts.NegativeNotifications = SlashMoon.Gifts.NegativeNotifications or {}

MODULE:Receive("SN_Gifts_NegativeEffect", function()
    SlashMoon.Gifts.NegativeNotifications[#SlashMoon.Gifts.NegativeNotifications + 1] = {
        key = net.ReadString(),
        started = CurTime(),
        duration = 3,
    }
end)

MODULE:Hook("HUDPaint", "SN_Gifts_Notifications", function()
    local now = CurTime()
    local scale = SlashMoon.UI.Scale
    local colors = SlashMoon.UI.Colors

    for index = #SlashMoon.Gifts.NegativeNotifications, 1, -1 do
        local notice = SlashMoon.Gifts.NegativeNotifications[index]
        local elapsed = now - notice.started
        if elapsed >= notice.duration then
            table.remove(SlashMoon.Gifts.NegativeNotifications, index)
            continue
        end

        local alpha = math.Clamp(math.min(elapsed / 0.2, 1) * 255, 0, 255)
        if elapsed > notice.duration - 0.5 then
            alpha = math.Clamp((notice.duration - elapsed) / 0.5 * 255, 0, 255)
        end

        SlashMoon.UI.Draw.TextShadow(
            SlashMoon.Tasks.Lang(notice.key),
            "SlashMoon.Title",
            ScrW() / 2, ScrH() / 2 - scale(100),
            Color(255, 60, 60, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
        )
    end
end)

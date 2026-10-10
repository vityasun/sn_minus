-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("tasks")

if not CLIENT then return end

SlashMoon.Tasks = SlashMoon.Tasks or {}
SlashMoon.Tasks.InventoryNotifications = SlashMoon.Tasks.InventoryNotifications or {}

MODULE:Receive("SN_Inv_ItemReceived", function()
    local class = net.ReadString()
    if class == "" then return end

    SlashMoon.Tasks.InventoryNotifications[#SlashMoon.Tasks.InventoryNotifications + 1] = {
        class = class,
        started = CurTime(),
        duration = 4,
    }
end)

MODULE:Hook("HUDPaint", "SN_Inventory_ItemNotifications", function()
    local list = SlashMoon.Tasks.InventoryNotifications
    local scale = SlashMoon.UI.Scale
    local colors = SlashMoon.UI.Colors
    local now = CurTime()
    local width, height = scale(300), scale(58)
    local x = ScrW() - math.floor(ScrW() * 0.01) - width

    for index = #list, 1, -1 do
        local notification = list[index]
        local elapsed = now - notification.started
        if elapsed >= notification.duration then
            table.remove(list, index)
            continue
        end

        local alpha = 255
        if elapsed < 0.2 then
            alpha = math.Clamp(elapsed / 0.2 * 255, 0, 255)
        elseif elapsed > notification.duration - 0.4 then
            alpha = math.Clamp((notification.duration - elapsed) / 0.4 * 255, 0, 255)
        end

        local y = scale(80) + (index - 1) * (height + scale(6))
        surface.SetDrawColor(colors.DarkBG.r, colors.DarkBG.g, colors.DarkBG.b, alpha * 0.95)
        surface.DrawRect(x, y, width, height)
        surface.SetDrawColor(colors.Theme.r, colors.Theme.g, colors.Theme.b, alpha)
        surface.DrawRect(x, y, scale(4), height)
        surface.SetDrawColor(colors.Outline.r, colors.Outline.g, colors.Outline.b, alpha)
        surface.DrawOutlinedRect(x, y, width, height, 1)

        local itemData = SlashMoon.Tasks.GetItemData(notification.class) or {}
        local material = SlashMoon.Tasks.GetItemMaterial(notification.class)
        if material and not material:IsError() then
            surface.SetMaterial(material)
            surface.SetDrawColor(255, 255, 255, alpha)
            surface.DrawTexturedRect(x + scale(12), y + scale(9), scale(40), scale(40))
        end

        SlashMoon.UI.Draw.TextShadow(
            SlashMoon.Tasks.Lang("sn.inv.received", itemData.name or SlashMoon.Tasks.GetItemName(notification.class)),
            "SlashMoon.Small",
            x + scale(62), y + height / 2,
            Color(255, 255, 255, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
        )
    end
end)

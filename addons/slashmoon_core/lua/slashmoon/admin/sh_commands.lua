-- Written for: SlashMoon. By: VIKA & Ronni
-- ========================================================
-- SlashMoon Lib :: команды открытия админ-панели
--   консоль: slashmoon_menu / slashmoon_admin
--   чат:     !slashmoon  (или /slashmoon)
-- ========================================================

SlashMoon.AdminMenu = SlashMoon.AdminMenu or {}

local CHAT_COMMANDS = {
    ["!slashmoon"] = true,
    ["/slashmoon"] = true,
}

if CLIENT then
    local function RequestMenu()
        net.Start("SlashMoon.AdminMenu.Request")
        net.SendToServer()
    end

    concommand.Add("slashmoon_menu", RequestMenu, nil, "SlashMoon: открыть панель конфигурации")
    concommand.Add("slashmoon_admin", RequestMenu, nil, "SlashMoon: открыть панель конфигурации")
else
    hook.Add("PlayerSay", "SlashMoon.AdminMenu.Chat", function(ply, text)
        local cmd = string.lower(string.Trim(text or ""))
        if CHAT_COMMANDS[cmd] then
            SlashMoon.AdminMenu.Open(ply)
            return ""
        end
    end)
end

-- Written for: SlashMoon. By: VIKA & Ronni
-- ========================================================
-- SlashMoon Lib :: базовые утилиты (логирование, отладка)
-- ========================================================

SlashMoon = SlashMoon or {}

SlashMoon.LogColor = Color(150, 50, 255)

local cvDebug = CreateConVar("slashmoon_debug", "0", { FCVAR_ARCHIVE, FCVAR_DONTRECORD },
    "SlashMoon: вывод отладочных сообщений в консоль (0/1)")

local function Concat(...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[i] = tostring((select(i, ...)))
    end
    return table.concat(parts)
end

--- Служебное сообщение в консоль (всегда выводится).
function SlashMoon.Log(...)
    MsgC(SlashMoon.LogColor, "[SlashMoon] ", color_white, Concat(...), "\n")
end

--- Предупреждение в консоль (всегда выводится).
function SlashMoon.Warn(...)
    MsgC(SlashMoon.LogColor, "[SlashMoon] ", Color(255, 180, 60), Concat(...), "\n")
end

--- Включен ли режим отладки (convar slashmoon_debug).
function SlashMoon.IsDebug()
    return cvDebug:GetBool()
end

--- Отладочное сообщение: выводится только при slashmoon_debug 1.
function SlashMoon.Debug(...)
    if not cvDebug:GetBool() then return end
    MsgC(SlashMoon.LogColor, "[SlashMoon:Debug] ", color_white, Concat(...), "\n")
end

--- Безопасный вызов функции: ошибки логируются, но не прерывают выполнение.
-- @return boolean ok, any result
function SlashMoon.SafeCall(fn, ...)
    if not isfunction(fn) then return false end
    local ok, a, b, c = xpcall(fn, function(err)
        ErrorNoHaltWithStack("[SlashMoon] " .. tostring(err) .. "\n")
        return err
    end, ...)
    return ok, a, b, c
end

--- Форматирует секунды в MM:SS.
function SlashMoon.FormatTime(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
end

--- Сообщение игроку в чат (сервер) или локальному игроку (клиент) в фирменном стиле.
-- На сервере использует сетевое сообщение, чтобы поддерживать цвета.
if SERVER then
    util.AddNetworkString("SlashMoon.Chat")

    function SlashMoon.Notify(target, ...)
        net.Start("SlashMoon.Chat")
        net.WriteTable({ ... })
        if target == nil then
            net.Broadcast()
        else
            net.Send(target)
        end
    end
else
    function SlashMoon.Notify(...)
        chat.AddText(SlashMoon.LogColor, "[SlashMoon] ", color_white, ...)
    end

    net.Receive("SlashMoon.Chat", function()
        local args = net.ReadTable()
        SlashMoon.Notify(unpack(args))
    end)
end

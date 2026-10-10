-- Written for: SlashMoon. By: VIKA & Ronni
-- ========================================================
-- SlashMoon Lib :: защита сетевых обработчиков (анти-спам)
-- ========================================================

SlashMoon.Security = SlashMoon.Security or {}
local Security = SlashMoon.Security

--- Проверяет, не спамит ли игрок действием.
-- @param ply Player
-- @param action string имя действия
-- @param cooldown number кулдаун в секундах
-- @return boolean true — действие разрешено, false — спам
function Security.CheckRateLimit(ply, action, cooldown)
    if not IsValid(ply) or ply:IsBot() then return false end

    ply.SlashMoonRateLimits = ply.SlashMoonRateLimits or {}

    local ct = CurTime()
    if ct < (ply.SlashMoonRateLimits[action] or 0) then
        return false
    end

    ply.SlashMoonRateLimits[action] = ct + (cooldown or 0)
    return true
end

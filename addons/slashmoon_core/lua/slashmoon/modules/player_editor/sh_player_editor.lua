-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("player_editor")

-- ========================================================
-- Редактор персонажа: общие функции
-- ========================================================

SlashMoon.PlayerEditor = SlashMoon.PlayerEditor or {}
local Editor = SlashMoon.PlayerEditor

local blacklistCache, blacklistSource = {}, nil

--- Скрыта ли модель настройкой "Скрытые модели".
function Editor.IsBlacklisted(modelPath)
    if not modelPath then return false end
    local source = MODULE:GetOption("blacklist") or ""
    if source ~= blacklistSource then
        blacklistCache = {}
        for path in string.gmatch(source, "[^,%s]+") do
            blacklistCache[string.lower(path)] = true
        end
        blacklistSource = source
    end
    return blacklistCache[string.lower(modelPath)] == true
end

function Editor.IsBooster(plyOrSid)
    return SlashMoon.Boosters ~= nil and SlashMoon.Boosters.IsBooster(plyOrSid)
end

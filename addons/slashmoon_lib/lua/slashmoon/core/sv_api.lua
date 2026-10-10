-- Written for: SlashMoon. By: VIKA & Ronni
-- ========================================================
-- SlashMoon Lib :: настраиваемый REST-клиент (опционально)
--
-- В аддоне нет адресов внешних серверов. Если владельцу сервера нужен
-- собственный backend, его можно подключить одним из способов:
--   1) файл garrysmod/data/slashmoon/api.json:
--        { "base_url": "https://example.com", "key": "secret" }
--   2) из кода: SlashMoon.API.Configure("https://example.com", "secret")
-- Пока адрес не задан, все запросы тихо отклоняются (onError("api_disabled")).
-- ========================================================

SlashMoon.API = SlashMoon.API or {}
local API = SlashMoon.API

API.Config = API.Config or { BaseURL = "", Key = "" }

--- Задает адрес backend-а и ключ авторизации.
function API.Configure(baseURL, key)
    API.Config.BaseURL = string.TrimRight(tostring(baseURL or ""), "/")
    API.Config.Key = tostring(key or "")
    if API.IsEnabled() then
        hook.Run("SlashMoon.API.Ready")
    end
end

--- Включен ли API (задан ли корректный адрес).
function API.IsEnabled()
    return SlashMoon.HTTP.IsValidURL(API.Config.BaseURL)
end

--- POST-запрос с JSON-телом к настроенному backend-у.
-- @param endpoint string путь, например "/api/profile"
-- @param payload table тело запроса
-- @param onSuccess function(data)
-- @param onError function(code, body)
function API.Request(endpoint, payload, onSuccess, onError)
    if not API.IsEnabled() then
        if onError then onError(0, "api_disabled") end
        return false
    end

    local headers = {}
    if API.Config.Key ~= "" then
        headers["Authorization"] = API.Config.Key
    end

    return SlashMoon.HTTP.Request({
        url = SlashMoon.HTTP.JoinURL(API.Config.BaseURL, endpoint),
        method = "POST",
        json = payload or {},
        headers = headers,
        expectJSON = true,
        success = function(_, data)
            if onSuccess then onSuccess(data) end
        end,
        failed = function(reason, code, body)
            if onError then onError(code or 0, body or reason) end
        end,
    })
end

-- Загрузка настроек из data/slashmoon/api.json (если файл существует)
local cfg = SlashMoon.Data.ReadJSON("api.json")
if istable(cfg) then
    API.Configure(cfg.base_url, cfg.key)
end

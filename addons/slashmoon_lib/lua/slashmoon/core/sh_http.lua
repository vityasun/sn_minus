-- Written for: SlashMoon. By: VIKA & Ronni
-- ========================================================
-- SlashMoon Lib :: HTTP-библиотека
-- Обертки над http.Fetch / http.Post / HTTP() с поддержкой JSON,
-- таймаутов и единообразной обработкой ошибок.
-- В библиотеке НЕТ захардкоженных адресов: все URL передаются вызывающим кодом.
-- ========================================================

SlashMoon.HTTP = SlashMoon.HTTP or {}
local HTTPLib = SlashMoon.HTTP

HTTPLib.DefaultTimeout = 15
HTTPLib.UserAgent = "SlashMoon/" .. tostring(SlashMoon.Version or "1.0")

local function IsValidURL(url)
    return isstring(url) and (string.StartsWith(url, "http://") or string.StartsWith(url, "https://"))
end

HTTPLib.IsValidURL = IsValidURL

--- Склеивает базовый адрес и путь, избегая двойных слэшей.
function HTTPLib.JoinURL(base, path)
    base = string.TrimRight(tostring(base or ""), "/")
    path = tostring(path or "")
    if path == "" then return base end
    if not string.StartsWith(path, "/") then path = "/" .. path end
    return base .. path
end

--- Кодирует таблицу параметров в query-строку (?a=1&b=2).
function HTTPLib.BuildQuery(params)
    if not istable(params) or table.IsEmpty(params) then return "" end
    local parts = {}
    for k, v in SortedPairs(params) do
        parts[#parts + 1] = string.format("%s=%s", HTTPLib.URLEncode(tostring(k)), HTTPLib.URLEncode(tostring(v)))
    end
    return "?" .. table.concat(parts, "&")
end

--- Percent-encoding строки для URL.
function HTTPLib.URLEncode(str)
    str = tostring(str or "")
    str = string.gsub(str, "\n", "\r\n")
    str = string.gsub(str, "([^%w%-%_%.%~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
    return str
end

--- Универсальный HTTP-запрос.
-- @param opts table {
--   url = string,               -- обязательный
--   method = "GET"|"POST"|...,  -- по умолчанию GET
--   headers = table,
--   params = table,             -- form-параметры (POST) или query (GET)
--   json = table,               -- тело запроса в формате JSON (application/json)
--   body = string,              -- сырое тело запроса
--   timeout = number,
--   success = function(code, body, headers),
--   failed = function(reason, code, body),
--   expectJSON = boolean,       -- разобрать тело ответа как JSON (success получит таблицу)
-- }
-- @return boolean был ли запрос отправлен
function HTTPLib.Request(opts)
    if not istable(opts) or not IsValidURL(opts.url) then
        if opts and isfunction(opts.failed) then opts.failed("invalid_url") end
        return false
    end

    local method = string.upper(opts.method or "GET")
    local headers = table.Copy(opts.headers or {})
    headers["User-Agent"] = headers["User-Agent"] or HTTPLib.UserAgent

    local req = {
        url = opts.url,
        method = method,
        headers = headers,
        timeout = opts.timeout or HTTPLib.DefaultTimeout,
    }

    if opts.json ~= nil then
        req.body = SlashMoon.JSON.Encode(opts.json) or "{}"
        req.type = "application/json"
        headers["Content-Type"] = "application/json"
    elseif opts.body ~= nil then
        req.body = tostring(opts.body)
        req.type = opts.type or "text/plain"
    elseif opts.params ~= nil then
        if method == "GET" or method == "HEAD" then
            req.url = req.url .. HTTPLib.BuildQuery(opts.params)
        else
            req.parameters = opts.params
        end
    end

    req.success = function(code, body, respHeaders)
        if code < 200 or code >= 300 then
            SlashMoon.Debug("HTTP ", method, " ", opts.url, " -> ", code)
            if isfunction(opts.failed) then opts.failed("http_" .. code, code, body) end
            return
        end

        if opts.expectJSON then
            local data = SlashMoon.JSON.Decode(body)
            if data == nil then
                if isfunction(opts.failed) then opts.failed("invalid_json", code, body) end
                return
            end
            if isfunction(opts.success) then opts.success(code, data, respHeaders) end
            return
        end

        if isfunction(opts.success) then opts.success(code, body, respHeaders) end
    end

    req.failed = function(reason)
        SlashMoon.Debug("HTTP ", method, " ", opts.url, " failed: ", reason)
        if isfunction(opts.failed) then opts.failed(reason or "network_error") end
    end

    return HTTP(req) ~= false
end

--- GET-запрос, возвращает тело ответа строкой.
-- @param onSuccess function(body, code, headers)
-- @param onFail function(reason, code)
function HTTPLib.Fetch(url, onSuccess, onFail, headers)
    return HTTPLib.Request({
        url = url,
        method = "GET",
        headers = headers,
        success = function(code, body, h) if onSuccess then onSuccess(body, code, h) end end,
        failed = onFail,
    })
end

--- POST-запрос с form-параметрами.
function HTTPLib.Post(url, params, onSuccess, onFail, headers)
    return HTTPLib.Request({
        url = url,
        method = "POST",
        params = params or {},
        headers = headers,
        success = function(code, body, h) if onSuccess then onSuccess(body, code, h) end end,
        failed = onFail,
    })
end

--- GET-запрос с разбором JSON-ответа.
-- @param onSuccess function(data, code)
function HTTPLib.GetJSON(url, onSuccess, onFail, headers)
    return HTTPLib.Request({
        url = url,
        method = "GET",
        headers = headers,
        expectJSON = true,
        success = function(code, data) if onSuccess then onSuccess(data, code) end end,
        failed = onFail,
    })
end

--- POST-запрос с JSON-телом и разбором JSON-ответа.
function HTTPLib.PostJSON(url, payload, onSuccess, onFail, headers)
    return HTTPLib.Request({
        url = url,
        method = "POST",
        json = payload or {},
        headers = headers,
        expectJSON = true,
        success = function(code, data) if onSuccess then onSuccess(data, code) end end,
        failed = onFail,
    })
end

--- Разбивает текстовый ответ на непустые строки без комментариев (# ...).
-- Удобно для простых списков (например, SteamID по одному на строку).
function HTTPLib.ParseLines(body)
    local out = {}
    for line in string.gmatch(tostring(body or ""), "[^\r\n]+") do
        line = string.Trim(line)
        if line ~= "" and not string.StartsWith(line, "#") then
            out[#out + 1] = line
        end
    end
    return out
end

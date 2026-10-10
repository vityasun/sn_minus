-- Written for: SlashMoon. By: VIKA & Ronni
-- ========================================================
-- SlashMoon Lib :: JSON-утилиты
-- Безопасные обертки над util.TableToJSON / util.JSONToTable.
-- ========================================================

SlashMoon.JSON = SlashMoon.JSON or {}
local JSON = SlashMoon.JSON

--- Сериализует таблицу в JSON.
-- @param tbl table
-- @param pretty boolean|nil форматированный вывод
-- @return string|nil json
function JSON.Encode(tbl, pretty)
    if not istable(tbl) then return nil end
    local ok, res = pcall(util.TableToJSON, tbl, pretty == true)
    if ok then return res end
    SlashMoon.Debug("JSON.Encode: ", res)
    return nil
end

--- Безопасно разбирает JSON-строку.
-- @param str string
-- @param fallback any значение, возвращаемое при ошибке
-- @return table|any
function JSON.Decode(str, fallback)
    if not isstring(str) or str == "" then return fallback end
    local ok, res = pcall(util.JSONToTable, str)
    if ok and istable(res) then return res end
    return fallback
end

--- Сжимает таблицу в бинарную строку (JSON + LZMA) для передачи по сети.
function JSON.Compress(tbl)
    local json = JSON.Encode(tbl)
    if not json then return nil end
    return util.Compress(json)
end

--- Распаковывает строку, полученную через JSON.Compress.
function JSON.Decompress(data, fallback)
    if not isstring(data) or data == "" then return fallback end
    local json = util.Decompress(data)
    return JSON.Decode(json, fallback)
end

--- Отправляет таблицу в рамках текущего net-сообщения (сжато).
function JSON.NetWrite(tbl)
    local data = JSON.Compress(tbl or {}) or ""
    net.WriteUInt(#data, 32)
    net.WriteData(data, #data)
end

--- Читает таблицу, записанную через JSON.NetWrite.
function JSON.NetRead(fallback)
    local len = net.ReadUInt(32)
    if not len or len <= 0 then return fallback end
    return JSON.Decompress(net.ReadData(len), fallback)
end

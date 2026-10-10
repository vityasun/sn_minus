-- Written for: SlashMoon. By: VIKA & Ronni
-- ========================================================
-- SlashMoon Lib :: хранилище данных (garrysmod/data/slashmoon/)
-- ========================================================

SlashMoon.Data = SlashMoon.Data or {}
local Data = SlashMoon.Data

Data.Folder = "slashmoon"

local function FullPath(name)
    return Data.Folder .. "/" .. name
end

--- Гарантирует существование папки (включая вложенные).
function Data.EnsureFolder(sub)
    local path = Data.Folder
    if not file.IsDir(path, "DATA") then file.CreateDir(path) end
    if sub and sub ~= "" then
        path = FullPath(sub)
        if not file.IsDir(path, "DATA") then file.CreateDir(path) end
    end
end

--- Читает JSON-файл из data/slashmoon/.
-- @param name string относительный путь, например "config.json"
-- @param fallback any значение по умолчанию
function Data.ReadJSON(name, fallback)
    local raw = file.Read(FullPath(name), "DATA")
    if not raw then return fallback end
    return SlashMoon.JSON.Decode(raw, fallback)
end

--- Записывает таблицу в JSON-файл в data/slashmoon/.
-- Запись атомарная: сначала во временный файл, затем переименование.
function Data.WriteJSON(name, tbl, pretty)
    local json = SlashMoon.JSON.Encode(tbl, pretty ~= false)
    if not json then return false end

    local dir = string.GetPathFromFilename(name)
    Data.EnsureFolder(dir ~= "" and string.TrimRight(dir, "/") or nil)

    local path = FullPath(name)
    local tmp = path .. ".tmp.txt"
    file.Write(tmp, json)
    if file.Exists(path, "DATA") then file.Delete(path) end
    if not file.Rename(tmp, path) then
        file.Write(path, json)
        file.Delete(tmp)
    end
    return true
end

--- Полный путь в data/ для файла SlashMoon (для сторонних API).
Data.Path = FullPath

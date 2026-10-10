-- Written for: SlashMoon. By: VIKA & Ronni
-- ========================================================
-- SlashMoon UI :: шрифты
--
-- SlashMoon.UI.CreateFont("Title", 32, 800) создает шрифт "SlashMoon.Title".
-- Размер задается в пикселях макета 1440p и пересчитывается при смене разрешения.
-- ========================================================

local UI = SlashMoon.UI

UI.FontFamily = UI.FontFamily or "Montserrat"
UI.Fonts = UI.Fonts or {}

local function Build(name, data)
    local size = data.size
    if data.scaled ~= false then
        size = math.max(data.min or 10, UI.Scale(size))
    end

    surface.CreateFont(name, {
        font = data.font or UI.FontFamily,
        size = size,
        weight = data.weight or 500,
        extended = true,
        antialias = true,
        italic = data.italic,
        shadow = data.shadow,
        blursize = data.blursize,
    })
end

--- Создает (или пересоздает) шрифт.
-- @param name string имя без префикса ("Title" -> "SlashMoon.Title")
-- @param size number размер в пикселях макета 1440p
-- @param weight number|nil толщина (по умолчанию 500)
-- @param opts table|nil { font = "...", scaled = false, min = 10, italic = true, blursize = 2 }
-- @return string полное имя шрифта
function UI.CreateFont(name, size, weight, opts)
    local full = string.StartsWith(name, "SlashMoon.") and name or ("SlashMoon." .. name)
    local data = isstring(opts) and { font = opts } or table.Copy(opts or {})
    data.size = size or 16
    data.weight = weight or data.weight or 500
    UI.Fonts[full] = data
    Build(full, data)
    return full
end

--- Регистрирует шрифт с фиксированными параметрами surface.CreateFont (без масштабирования).
-- Нужен для 3D2D-экранов и рендер-таргетов, где размер не зависит от разрешения.
-- @param name string полное имя шрифта
-- @param data table таблица параметров surface.CreateFont
function UI.RegisterRawFont(name, data)
    data = table.Copy(data or {})
    data.extended = data.extended ~= false
    surface.CreateFont(name, data)
    return name
end

--- Пересоздает все шрифты (например, после смены разрешения или семейства).
function UI.RebuildFonts()
    for name, data in pairs(UI.Fonts) do
        Build(name, data)
    end
end

--- Возвращает имя шрифта по короткому имени ("Text" -> "SlashMoon.Text").
function UI.Font(name)
    return "SlashMoon." .. name
end

hook.Add("SlashMoon.UI.ScaleChanged", "SlashMoon.UI.Fonts", UI.RebuildFonts)

-- Базовый набор шрифтов библиотеки
UI.CreateFont("Title", 32, 800)
UI.CreateFont("Header", 24, 700)
UI.CreateFont("Subheader", 20, 600)
UI.CreateFont("Text", 22, 500)
UI.CreateFont("TextBold", 22, 700)
UI.CreateFont("Small", 16, 500)
UI.CreateFont("Tiny", 13, 500)
UI.CreateFont("Button", 20, 600)
UI.CreateFont("Icon", 26, 700)

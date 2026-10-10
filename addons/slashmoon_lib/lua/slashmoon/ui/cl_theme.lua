-- Written for: SlashMoon. By: VIKA & Ronni
-- ========================================================
-- SlashMoon UI :: тема (палитра)
--
-- ЕДИНСТВЕННОЕ место, где задаются цвета всех интерфейсов.
-- Чтобы перекрасить все меню разом:
--   SlashMoon.UI.SetTheme({ Accent = Color(0, 170, 255) })
-- или поменять акцентный цвет в админ-панели (модуль "Тема интерфейса").
--
-- Компоненты читают цвета из SlashMoon.UI.Colors каждый кадр, а SetTheme
-- изменяет объекты Color "на месте", поэтому смена темы применяется мгновенно.
-- ========================================================

SlashMoon.UI = SlashMoon.UI or {}
local UI = SlashMoon.UI

-- Палитра по умолчанию
UI.DefaultTheme = {
    Accent        = Color(150, 50, 255),       -- акцентный цвет (кнопки, переключатели, полосы)
    AccentText    = Color(255, 255, 255),      -- текст поверх акцентного цвета
    Background    = Color(20, 20, 20, 240),    -- фон окон
    Header        = Color(15, 15, 15, 255),    -- шапки, темные подложки
    Surface       = Color(28, 28, 32, 255),    -- карточки, строки, поля
    SurfaceHover  = Color(38, 38, 44, 255),    -- карточки при наведении
    Overlay       = Color(0, 0, 0, 180),       -- затемнение под модальными окнами
    Text          = Color(255, 255, 255),      -- основной текст
    TextMuted     = Color(150, 150, 150),      -- второстепенный текст
    TextDisabled  = Color(90, 90, 90),         -- текст выключенных элементов
    Border        = Color(150, 50, 255, 50),   -- обводки
    BorderNeutral = Color(55, 55, 60, 255),    -- нейтральные обводки
    Shadow        = Color(0, 0, 0, 150),       -- тени текста
    Success       = Color(50, 200, 100),
    Danger        = Color(255, 50, 50),
    Warning       = Color(255, 180, 60),
    Info          = Color(60, 170, 255),
}

-- Фирменный острый стиль SlashMoon: прямые углы, акцентная полоса слева,
-- тонкая неоновая обводка. Все скругления библиотеки отключены.
-- SlashMoon.UI.Sharp = false вернет скругления (радиус по умолчанию — UI.Radius).
UI.Sharp = true
UI.Radius = 6

UI.Colors = UI.Colors or {}
UI.ThemeVersion = (UI.ThemeVersion or 0)

-- Производные цвета, вычисляемые из базовых
local function RebuildDerived(c)
    c.AccentHover = c.AccentHover or Color(0, 0, 0)
    c.AccentHover.r = math.min(255, c.Accent.r + 25)
    c.AccentHover.g = math.min(255, c.Accent.g + 25)
    c.AccentHover.b = math.min(255, c.Accent.b + 25)
    c.AccentHover.a = c.Accent.a

    c.AccentDim = c.AccentDim or Color(0, 0, 0)
    c.AccentDim.r, c.AccentDim.g, c.AccentDim.b, c.AccentDim.a = c.Accent.r, c.Accent.g, c.Accent.b, 150

    c.Border.r, c.Border.g, c.Border.b = c.Accent.r, c.Accent.g, c.Accent.b

    -- Совместимость со старыми именами палитры
    c.Theme = c.Accent
    c.DarkBG = c.Header
    c.Hover = c.AccentDim
    c.Outline = c.Border
end

local function Assign(target, key, col)
    if not IsColor(col) and not istable(col) then return end
    local existing = target[key]
    if existing then
        existing.r, existing.g, existing.b = col.r or existing.r, col.g or existing.g, col.b or existing.b
        existing.a = col.a or 255
    else
        target[key] = Color(col.r or 255, col.g or 255, col.b or 255, col.a or 255)
    end
end

--- Применяет палитру (частично или целиком). Изменения видны во всех интерфейсах сразу.
-- @param theme table { Accent = Color(...), Background = Color(...), ... }
function UI.SetTheme(theme)
    for key, col in pairs(theme or {}) do
        Assign(UI.Colors, key, col)
    end
    RebuildDerived(UI.Colors)
    UI.ThemeVersion = UI.ThemeVersion + 1
    hook.Run("SlashMoon.UI.ThemeChanged", UI.Colors)
end

--- Сбрасывает палитру к значениям по умолчанию.
function UI.ResetTheme()
    UI.SetTheme(UI.DefaultTheme)
end

--- Возвращает цвет палитры по ключу (с опциональной прозрачностью).
-- Можно передать готовый Color — он вернется как есть.
function UI.Color(key, alpha)
    local col = IsColor(key) and key or UI.Colors[key] or UI.Colors.Text
    if alpha then
        return Color(col.r, col.g, col.b, alpha)
    end
    return col
end

--- Линейная интерполяция между цветами (результат пишется в out, если он передан).
function UI.LerpColor(t, from, to, out)
    out = out or Color(0, 0, 0)
    out.r = Lerp(t, from.r, to.r)
    out.g = Lerp(t, from.g, to.g)
    out.b = Lerp(t, from.b, to.b)
    out.a = Lerp(t, from.a or 255, to.a or 255)
    return out
end

-- Инициализация палитры
for key, col in pairs(UI.DefaultTheme) do
    if not UI.Colors[key] then Assign(UI.Colors, key, col) end
end
RebuildDerived(UI.Colors)

-- Короткий доступ: SlashMoon.Colors.Accent
SlashMoon.Colors = UI.Colors

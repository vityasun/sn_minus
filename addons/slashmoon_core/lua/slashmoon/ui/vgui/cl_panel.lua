-- Written for: SlashMoon. By: VIKA & Ronni
-- ========================================================
-- SlashMoon UI :: базовые контейнеры и текст
--   SlashMoon.Panel      — карточка с фоном из палитры
--   SlashMoon.Container  — прозрачный контейнер для разметки
--   SlashMoon.Label      — текст в стиле темы
--   SlashMoon.Header     — заголовок секции с акцентной полосой
--   SlashMoon.Divider    — разделитель
--   SlashMoon.SettingRow — строка настройки: название, описание, элемент управления
-- ========================================================

local UI = SlashMoon.UI
local Draw = UI.Draw
local colors = UI.Colors

local function ResolveColor(value)
    if value == false or value == nil then return nil end
    if IsColor(value) or istable(value) then return value end
    return colors[value]
end

-- ========================================================
-- SlashMoon.Panel
-- ========================================================
local PANEL = {}

function PANEL:Init()
    self.Background = "Surface"
    self.HoverBackground = nil
    self.Radius = UI.Radius
    self.OutlineColor = nil
    self.AccentBar = nil
    self._hover = 0
end

--- Цвет фона: ключ палитры ("Surface", "Header"...), Color или false (прозрачный).
function PANEL:SetBackground(value)
    self.Background = value
end

--- Цвет фона при наведении (ключ палитры или Color).
function PANEL:SetHoverBackground(value)
    self.HoverBackground = value
end

--- Скругление в пикселях макета 1440p (0 — без скругления).
function PANEL:SetRadius(px)
    self.Radius = px
end

--- Обводка: ключ палитры, Color, true (Border) или false.
function PANEL:SetOutline(value)
    self.OutlineColor = value == true and "Border" or value
end

--- Акцентная полоса слева: true (Accent), ключ палитры, Color или false.
function PANEL:SetAccentBar(value)
    self.AccentBar = value == true and "Accent" or value
end

function PANEL:Paint(w, h)
    if self.GetPaintBackground and not self:GetPaintBackground() then return end

    local r = UI.Scale(self.Radius)
    local bg = ResolveColor(self.Background)

    if self.HoverBackground then
        local hov = UI.Animate(self, "_hover", self:IsHovered() and 1 or 0)
        local hbg = ResolveColor(self.HoverBackground)
        if bg and hbg and hov > 0 then
            bg = UI.LerpColor(hov, bg, hbg, self._bgCache)
            self._bgCache = bg
        end
    end

    if bg then Draw.RoundedBox(r, 0, 0, w, h, bg) end

    local bar = ResolveColor(self.AccentBar)
    if bar then
        Draw.RoundedBox(r, 0, 0, UI.Scale(4), h, bar, true, false, true, false)
    end

    local outline = ResolveColor(self.OutlineColor)
    if outline then Draw.RoundedOutline(r, 0, 0, w, h, outline) end
end

vgui.Register("SlashMoon.Panel", PANEL, "DPanel")

-- ========================================================
-- SlashMoon.Container (прозрачный)
-- ========================================================
local CONTAINER = {}

function CONTAINER:Init()
    self:SetPaintBackground(false)
end

function CONTAINER:Paint() end

vgui.Register("SlashMoon.Container", CONTAINER, "DPanel")

-- ========================================================
-- SlashMoon.Label
-- ========================================================
local LABEL = {}

function LABEL:Init()
    self:SetFont("SlashMoon.Text")
    self:SetColorKey("Text")
end

--- Цвет текста из палитры по ключу (обновляется при смене темы).
function LABEL:SetColorKey(key)
    self.ColorKey = key
    self.ThemeVersion = UI.ThemeVersion
    local col = colors[key] or colors.Text
    self:SetTextColor(Color(col.r, col.g, col.b, col.a))
end

--- Второстепенный (приглушенный) текст.
function LABEL:SetMuted(muted)
    self:SetColorKey(muted and "TextMuted" or "Text")
end

--- Произвольный цвет текста (отключает привязку к палитре).
function LABEL:SetColor(col)
    self.ColorKey = nil
    self:SetTextColor(col)
end

function LABEL:Think()
    if self.ColorKey and self.ThemeVersion ~= UI.ThemeVersion then
        self:SetColorKey(self.ColorKey)
    end
end

vgui.Register("SlashMoon.Label", LABEL, "DLabel")

-- ========================================================
-- SlashMoon.Header (заголовок секции)
-- ========================================================
local HEADER = {}

function HEADER:Init()
    self.Text = ""
    self.Description = nil
    self:SetTall(UI.Scale(40))
end

function HEADER:SetText(text)
    self.Text = tostring(text or "")
end

function HEADER:SetDescription(text)
    self.Description = text
    self:SetTall(UI.Scale(text and text ~= "" and 58 or 40))
end

function HEADER:Paint(w, h)
    local barH = UI.Scale(22)
    Draw.RoundedBox(UI.Scale(2), 0, UI.Scale(9), UI.Scale(4), barH, colors.Accent)
    Draw.Text(self.Text, "SlashMoon.Subheader", UI.Scale(14), UI.Scale(20), colors.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    if self.Description and self.Description ~= "" then
        Draw.Text(self.Description, "SlashMoon.Small", UI.Scale(14), UI.Scale(44), colors.TextMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
end

vgui.Register("SlashMoon.Header", HEADER, "Panel")

-- ========================================================
-- SlashMoon.Divider
-- ========================================================
local DIVIDER = {}

function DIVIDER:Init()
    self:SetTall(UI.Scale(13))
end

function DIVIDER:Paint(w, h)
    Draw.Box(0, math.floor(h / 2), w, 1, colors.BorderNeutral)
end

vgui.Register("SlashMoon.Divider", DIVIDER, "Panel")

-- ========================================================
-- SlashMoon.SettingRow
--   local row = SlashMoon.UI.Create("SettingRow", parent)
--   row:Dock(TOP)
--   row:SetTitle("Название")
--   row:SetDescription("Описание")
--   row:SetControl(SlashMoon.UI.Create("Toggle"))
-- ========================================================
local ROW = {}

function ROW:Init()
    self.Title = ""
    self.Description = ""
    self:SetBackground("Surface")
    self:SetHoverBackground("SurfaceHover")
    self:SetTall(UI.Scale(64))
    self:DockMargin(0, 0, 0, UI.Scale(8))
    self:DockPadding(UI.Scale(16), UI.Scale(10), UI.Scale(16), UI.Scale(10))
    self.ControlWidth = nil
end

function ROW:SetTitle(text)
    self.Title = tostring(text or "")
end

function ROW:SetDescription(text)
    self.Description = tostring(text or "")
end

--- Помещает элемент управления в правую часть строки.
-- @param control Panel
-- @param width number|nil ширина в реальных пикселях (по умолчанию — ширина элемента)
function ROW:SetControl(control, width)
    self.Control = control
    control:SetParent(self)
    self.ControlWidth = width
    self:InvalidateLayout()
    return control
end

function ROW:PerformLayout(w, h)
    if not IsValid(self.Control) then return end
    local cw = self.ControlWidth or self.Control:GetWide()
    local ch = math.min(self.Control:GetTall(), h - UI.Scale(16))
    self.Control:SetSize(cw, ch)
    self.Control:SetPos(w - cw - UI.Scale(16), (h - ch) / 2)
end

function ROW:Paint(w, h)
    PANEL.Paint(self, w, h)
    local x = UI.Scale(16)
    if self.Description ~= "" then
        Draw.Text(self.Title, "SlashMoon.TextBold", x, h / 2 - UI.Scale(2), colors.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
        Draw.Text(self.Description, "SlashMoon.Small", x, h / 2 + UI.Scale(2), colors.TextMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    else
        Draw.Text(self.Title, "SlashMoon.TextBold", x, h / 2, colors.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
end

vgui.Register("SlashMoon.SettingRow", ROW, "SlashMoon.Panel")

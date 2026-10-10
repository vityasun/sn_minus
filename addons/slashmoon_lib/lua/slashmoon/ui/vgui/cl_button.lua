-- Written for: SlashMoon. By: VIKA & Ronni
-- ========================================================
-- SlashMoon UI :: кнопки
--   SlashMoon.Button     — кнопка с состояниями Default / Hover / Active / Disabled
--   SlashMoon.IconButton — квадратная кнопка-иконка
--
--   local btn = SlashMoon.UI.Create("Button", parent)
--   btn:SetText("СОХРАНИТЬ")
--   btn:SetVariant("primary")         -- primary | secondary | ghost | success | danger
--   btn:SetIcon("icon16/disk.png")
--   btn.DoClick = function() ... end
--   btn:SetEnabled(false)             -- состояние Disabled
--   btn:SetActive(true)               -- состояние Active (выбранная вкладка и т.п.)
-- ========================================================

local UI = SlashMoon.UI
local Draw = UI.Draw
local colors = UI.Colors
-- SetText нативный (метатаблица Panel): в таблице baseclass DButton его нет
local PanelMeta = FindMetaTable("Panel")

local VARIANT_ACCENT = {
    primary = "Accent",
    secondary = "Accent",
    ghost = "Accent",
    success = "Success",
    danger = "Danger",
    warning = "Warning",
}

local PANEL = {}

function PANEL:Init()
    PanelMeta.SetText(self, "")
    self.BtnText = ""
    self:SetFont("SlashMoon.Button")
    self.Variant = "secondary"
    self.AccentColor = nil
    self.TextAlign = TEXT_ALIGN_CENTER
    self.Active = false
    self.Radius = UI.Radius
    self._hover = 0
    self._press = 0
    self._active = 0
    self._bg = Color(0, 0, 0)
    self._fg = Color(0, 0, 0)
    self._outline = Color(0, 0, 0)
    self:SetTall(UI.Scale(44))
end

--- Текст кнопки.
function PANEL:SetText(text)
    self.BtnText = tostring(text or "")
    PanelMeta.SetText(self, "")
end
PANEL.SetBtnText = PANEL.SetText

function PANEL:GetText()
    return self.BtnText
end

--- Вариант оформления: primary | secondary | ghost | success | danger | warning.
function PANEL:SetVariant(variant)
    self.Variant = VARIANT_ACCENT[variant] and variant or "secondary"
end

--- Собственный акцентный цвет (перекрывает цвет варианта).
function PANEL:SetAccentColor(col)
    self.AccentColor = col
end

--- Иконка: Material или путь к png. side: "left" (по умолчанию) | "right".
function PANEL:SetIcon(mat, side)
    self.Icon = isstring(mat) and Draw.Material(mat) or mat
    self.IconSide = side or "left"
end

--- Выравнивание текста: TEXT_ALIGN_LEFT | TEXT_ALIGN_CENTER | TEXT_ALIGN_RIGHT.
function PANEL:SetTextAlign(align)
    self.TextAlign = align
end

--- Состояние Active (выбранная кнопка).
function PANEL:SetActive(active)
    self.Active = active == true
end

function PANEL:IsActive()
    return self.Active
end

--- Скругление в пикселях макета.
function PANEL:SetRadius(px)
    self.Radius = px
end

--- Ширина по содержимому.
function PANEL:SizeToContentsX(pad)
    surface.SetFont(self:GetFont())
    local tw = surface.GetTextSize(self.BtnText)
    local iconW = self.Icon and (self:GetTall() * 0.5 + UI.Scale(8)) or 0
    self:SetWide(tw + iconW + (pad or UI.Scale(32)))
end

function PANEL:OnCursorEntered()
    if self:IsEnabled() then UI.PlaySound("Hover") end
end

function PANEL:DoClickInternal()
    UI.PlaySound("Click")
end

function PANEL:Paint(w, h)
    local enabled = self:IsEnabled()
    local hov = UI.Animate(self, "_hover", (enabled and self:IsHovered()) and 1 or 0)
    local press = UI.Animate(self, "_press", (enabled and self:IsDown()) and 1 or 0, 20)
    local act = UI.Animate(self, "_active", self.Active and 1 or 0)
    local r = UI.Scale(self.Radius)

    local accent = self.AccentColor or colors[VARIANT_ACCENT[self.Variant]] or colors.Accent
    -- Буферы цветов создаются лениво: Paint может прийти раньше Init
    -- (автообновление Lua, панели, созданные до перезагрузки файла)
    local bg = self._bg or Color(0, 0, 0)
    local fg = self._fg or Color(0, 0, 0)
    local outline = self._outline or Color(0, 0, 0)
    self._bg, self._fg, self._outline = bg, fg, outline

    if self.Variant == "ghost" then
        -- ghost: прозрачная, подсветка при наведении, полоса слева у активной (вкладки, меню)
        local k = enabled and math.max(hov, act) or 0
        bg.r, bg.g, bg.b, bg.a = colors.SurfaceHover.r, colors.SurfaceHover.g, colors.SurfaceHover.b, 255 * k
        if bg.a > 1 then Draw.RoundedBox(r, 0, 0, w, h, bg) end
        if act > 0.01 then
            Draw.Box(0, 0, UI.Scale(4), h, Color(accent.r, accent.g, accent.b, 255 * act))
        end
        if enabled then
            UI.LerpColor(math.max(hov, act), colors.TextMuted, colors.Text, fg)
        else
            fg.r, fg.g, fg.b, fg.a = colors.TextDisabled.r, colors.TextDisabled.g, colors.TextDisabled.b, 255
        end
    else
        -- Фирменная кнопка SlashMoon: темная плашка, полоса 4px слева,
        -- обводка 1px разгорается при наведении. Цвет полосы задает вариант
        -- (primary/secondary — акцент, success — зеленый, danger — красный).
        if not enabled then accent = colors.TextDisabled end
        local k = enabled and math.max(hov, act) or 0
        bg.r, bg.g, bg.b, bg.a = colors.Header.r, colors.Header.g, colors.Header.b, colors.Header.a
        Draw.RoundedBox(r, 0, 0, w, h, bg)
        if press > 0.01 then
            Draw.RoundedBox(r, 0, 0, w, h, Color(accent.r, accent.g, accent.b, 40 * press))
        end
        Draw.RoundedBox(r, 0, 0, UI.Scale(4), h, accent, true, false, true, false)
        outline.r, outline.g, outline.b, outline.a = accent.r, accent.g, accent.b, enabled and (50 + 205 * k) or 30
        Draw.RoundedOutline(r, 0, 0, w, h, outline)
        if enabled then
            UI.LerpColor(k, colors.TextMuted, colors.Text, fg)
        else
            fg.r, fg.g, fg.b, fg.a = colors.TextDisabled.r, colors.TextDisabled.g, colors.TextDisabled.b, 255
        end
    end

    -- Иконка + текст
    local font = self:GetFont()
    surface.SetFont(font)
    local tw = surface.GetTextSize(self.BtnText)
    local iconSize = self.Icon and not self.Icon:IsError() and math.floor(h * 0.5) or 0
    local gap = (iconSize > 0 and tw > 0) and UI.Scale(8) or 0
    local total = iconSize + gap + tw
    local pad = UI.Scale(14)

    local x
    if self.TextAlign == TEXT_ALIGN_LEFT then
        x = pad + (self.Variant ~= "ghost" and UI.Scale(4) or 0)
    elseif self.TextAlign == TEXT_ALIGN_RIGHT then
        x = w - pad - total
    else
        x = (w - total) / 2
    end

    if iconSize > 0 then
        local ix = self.IconSide == "right" and (x + tw + gap) or x
        Draw.Icon(self.Icon, ix, (h - iconSize) / 2, iconSize, iconSize, fg)
        if self.IconSide ~= "right" then x = x + iconSize + gap end
    end

    if tw > 0 then
        draw.SimpleText(self.BtnText, font, x, h / 2, fg, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
end

vgui.Register("SlashMoon.Button", PANEL, "DButton")

-- ========================================================
-- SlashMoon.IconButton
-- ========================================================
local ICON = {}

function ICON:Init()
    PanelMeta.SetText(self, "")
    self.Icon = nil
    self.Glyph = nil
    self.IconColor = nil
    self.ActiveColor = nil
    self.Active = false
    self.Radius = UI.Radius
    self._hover = 0
    self._fg = Color(0, 0, 0)
end

--- Иконка: Material или путь к png.
function ICON:SetIcon(mat)
    self.Icon = isstring(mat) and Draw.Material(mat) or mat
end

--- Текстовый символ вместо иконки (например, "✕" или "+").
function ICON:SetGlyph(text)
    self.Glyph = text
end

function ICON:SetIconColor(col) self.IconColor = col end
function ICON:SetActiveColor(col) self.ActiveColor = col end
function ICON:SetActive(active) self.Active = active == true end
function ICON:IsActive() return self.Active end
function ICON:SetRadius(px) self.Radius = px end

function ICON:OnCursorEntered()
    if self:IsEnabled() then UI.PlaySound("Hover") end
end

function ICON:DoClickInternal()
    UI.PlaySound("Click")
end

function ICON:Paint(w, h)
    local enabled = self:IsEnabled()
    local hov = UI.Animate(self, "_hover", (enabled and self:IsHovered()) and 1 or 0, 15)
    local r = UI.Scale(self.Radius)
    local activeCol = self.ActiveColor or colors.Accent

    Draw.RoundedBox(r, 0, 0, w, h, colors.Header)
    if hov > 0.01 then
        Draw.RoundedBox(r, 0, 0, w, h, Color(activeCol.r, activeCol.g, activeCol.b, 200 * hov))
    end
    Draw.RoundedOutline(r, 0, 0, w, h, colors.Border)

    local fg = self._fg or Color(0, 0, 0)
    self._fg = fg
    if not enabled then
        fg.r, fg.g, fg.b, fg.a = colors.TextDisabled.r, colors.TextDisabled.g, colors.TextDisabled.b, 255
    elseif self.Active then
        fg.r, fg.g, fg.b, fg.a = activeCol.r, activeCol.g, activeCol.b, 255
        if hov > 0.5 then fg.r, fg.g, fg.b = 255, 255, 255 end
    else
        local base = self.IconColor or colors.Text
        fg.r, fg.g, fg.b, fg.a = base.r, base.g, base.b, base.a or 255
    end

    if self.Icon and not self.Icon:IsError() then
        local pad = math.floor(math.min(w, h) * 0.2)
        Draw.Icon(self.Icon, pad, pad, w - pad * 2, h - pad * 2, fg)
    elseif self.Glyph then
        draw.SimpleText(self.Glyph, "SlashMoon.Icon", w / 2, h / 2, fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

vgui.Register("SlashMoon.IconButton", ICON, "DButton")

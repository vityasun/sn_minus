-- Written for: SlashMoon. By: VIKA & Ronni
-- ========================================================
-- SlashMoon UI :: элементы управления
--   SlashMoon.Toggle      — переключатель (switch)
--   SlashMoon.Checkbox    — чекбокс с подписью
--   SlashMoon.SliderBar   — ползунок без подписи (замена DSlider)
--   SlashMoon.Slider      — ползунок с подписью и полем ввода (на базе DNumSlider)
--   SlashMoon.TextEntry   — поле ввода с плейсхолдером
--   SlashMoon.ComboBox    — выпадающий список
--   SlashMoon.Binder      — выбор клавиши
--   SlashMoon.ColorPicker — выбор цвета
-- ========================================================

local UI = SlashMoon.UI
local Draw = UI.Draw
local colors = UI.Colors

local DrawKnob

-- ========================================================
-- SlashMoon.Toggle
--   local t = SlashMoon.UI.Create("Toggle", parent)
--   t:SetValue(true)
--   t.OnChange = function(self, value) end
-- ========================================================
local TOGGLE = {}

function TOGGLE:Init()
    self:SetText("")
    self.Value = false
    self._anim = 0
    self._hover = 0
    self._track = Color(0, 0, 0)
    self:SetSize(UI.Scale(52), UI.Scale(28))
end

--- Устанавливает значение. silent = true — без вызова OnChange.
function TOGGLE:SetValue(value, silent)
    value = value == true
    if self.Value == value then return end
    self.Value = value
    if not silent and self.OnChange then self:OnChange(value) end
end

function TOGGLE:GetValue()
    return self.Value
end

TOGGLE.SetChecked = TOGGLE.SetValue
TOGGLE.GetChecked = TOGGLE.GetValue

--- Мгновенно выставляет анимацию в текущее состояние (без плавного перехода).
function TOGGLE:SnapAnimation()
    self._anim = self.Value and 1 or 0
end

function TOGGLE:DoClick()
    UI.PlaySound("Toggle")
    self:SetValue(not self.Value)
end

function TOGGLE:OnCursorEntered()
    if self:IsEnabled() then UI.PlaySound("Hover") end
end

function TOGGLE:Paint(w, h)
    local enabled = self:IsEnabled()
    local t = UI.Animate(self, "_anim", self.Value and 1 or 0, 14)
    local hov = UI.Animate(self, "_hover", (enabled and self:IsHovered()) and 1 or 0)

    -- Острый стиль: темная дорожка, заливка акцентом, квадратный ползунок
    local accent = enabled and colors.Accent or colors.TextDisabled
    Draw.Box(0, 0, w, h, colors.Header)
    if t > 0.01 then
        Draw.Box(0, 0, w * t, h, Color(accent.r, accent.g, accent.b, 200 * t))
    end
    local outline = UI.LerpColor(math.max(hov, t), colors.BorderNeutral, accent, self._track)
    Draw.Outline(0, 0, w, h, outline)

    local pad = math.max(2, math.floor(h * 0.15))
    local knob = h - pad * 2
    local x = pad + (w - knob - pad * 2) * t
    Draw.Box(x, pad, knob, knob, enabled and colors.Text or colors.TextMuted)
end

vgui.Register("SlashMoon.Toggle", TOGGLE, "DButton")

-- ========================================================
-- SlashMoon.Checkbox
--   local c = SlashMoon.UI.Create("Checkbox", parent)
--   c:SetLabel("Опция")
--   c:SetChecked(true)
--   c.OnChange = function(self, checked) end
-- ========================================================
local CHECK = {}

function CHECK:Init()
    self:SetText("")
    self.Checked = false
    self._anim = 0
    self._hover = 0

    self.Label = vgui.Create("SlashMoon.Label", self)
    self.Label:SetMuted(true)
    self.Label:SetText("")
    self.Label:SetMouseInputEnabled(false)

    self:SetTall(UI.Scale(32))
end

function CHECK:SetLabel(text)
    self.Label:SetText(text or "")
    self.Label:SizeToContents()
    self:InvalidateLayout()
end

function CHECK:SetChecked(checked, silent)
    checked = checked == true
    if self.Checked == checked then return end
    self.Checked = checked
    if not silent and self.OnChange then self:OnChange(checked) end
end

function CHECK:GetChecked()
    return self.Checked
end

CHECK.SetValue = CHECK.SetChecked
CHECK.GetValue = CHECK.GetChecked

function CHECK:DoClick()
    UI.PlaySound("Toggle")
    self:SetChecked(not self.Checked)
end

--- Ширина по подписи.
function CHECK:SizeToContents()
    self:SetWide(self:GetBoxSize() + UI.Scale(10) + self.Label:GetWide())
end

function CHECK:GetBoxSize()
    return math.min(self:GetTall(), UI.Scale(26))
end

function CHECK:PerformLayout(w, h)
    self.Label:SetPos(self:GetBoxSize() + UI.Scale(10), (h - self.Label:GetTall()) / 2)
end

function CHECK:Paint(w, h)
    local enabled = self:IsEnabled()
    local hovered = enabled and self:IsHovered()
    local t = UI.Animate(self, "_anim", self.Checked and 1 or 0, 15)
    local box = self:GetBoxSize()
    local y = (h - box) / 2
    local r = UI.Scale(4)

    Draw.RoundedBox(r, 0, y, box, box, colors.Header)
    Draw.RoundedOutline(r, 0, y, box, box, hovered and colors.Accent or colors.BorderNeutral)

    if t > 0.01 then
        local inner = (box - UI.Scale(10)) * t
        local off = (box - inner) / 2
        Draw.RoundedBox(math.floor(r / 2), off, y + off, inner, inner, enabled and colors.Accent or colors.TextDisabled)
    end

    local key = (not enabled and "TextDisabled") or ((hovered or self.Checked) and "Text") or "TextMuted"
    if self.Label.ColorKey ~= key then self.Label:SetColorKey(key) end
end

vgui.Register("SlashMoon.Checkbox", CHECK, "DButton")

-- ========================================================
-- SlashMoon.SliderBar
--   local s = SlashMoon.UI.Create("SliderBar", parent)
--   s:SetMinMax(0, 100); s:SetDecimals(0); s:SetValue(50)
--   s.OnValueChanged = function(self, value) end
-- ========================================================
local BAR = {}

-- Квадратный ползунок оригинального SN_Slider: акцентный квадрат с темным кантом
function DrawKnob(x, y, w, h, accent, hov)
    Draw.Box(x, y, w, h, Color(20, 20, 20, 255))
    Draw.Outline(x, y, w, h, accent)
    Draw.Box(x + 2, y + 2, w - 4, h - 4, hov and hov > 0.5 and UI.LerpColor(0.3, accent, colors.Text) or accent)
end

function BAR:Init()
    self.Min, self.Max = 0, 1
    self.Decimals = 2
    self.Value = 0
    self._hover = 0
    self:SetTall(UI.Scale(24))
    self:SetCursor("hand")
end

function BAR:SetMin(v) self.Min = tonumber(v) or 0 end
function BAR:SetMax(v) self.Max = tonumber(v) or 1 end
function BAR:GetMin() return self.Min end
function BAR:GetMax() return self.Max end
function BAR:SetMinMax(min, max) self:SetMin(min) self:SetMax(max) end
function BAR:SetDecimals(d) self.Decimals = d or 0 end

function BAR:SetValue(value, silent)
    value = math.Clamp(tonumber(value) or self.Min, math.min(self.Min, self.Max), math.max(self.Min, self.Max))
    value = math.Round(value, self.Decimals)
    if value == self.Value then return end
    self.Value = value
    if not silent and self.OnValueChanged then self:OnValueChanged(value) end
end

function BAR:GetValue()
    return self.Value
end

--- Доля заполнения 0..1 (совместимо с DSlider).
function BAR:GetSlideX()
    if self.Max == self.Min then return 0 end
    return (self.Value - self.Min) / (self.Max - self.Min)
end

function BAR:SetSlideX(fraction)
    self:SetValue(self.Min + (self.Max - self.Min) * math.Clamp(fraction or 0, 0, 1))
end

function BAR:UpdateFromCursor()
    local x = self:CursorPos()
    local knob = self:GetTall() * 0.7
    local fraction = (x - knob / 2) / math.max(1, self:GetWide() - knob)
    self:SetSlideX(fraction)
end

function BAR:OnMousePressed(code)
    if code ~= MOUSE_LEFT or not self:IsEnabled() then return end
    self.Dragging = true
    self:MouseCapture(true)
    self:UpdateFromCursor()
end

function BAR:OnMouseReleased()
    if not self.Dragging then return end
    self.Dragging = false
    self:MouseCapture(false)
    if self.OnValueReleased then self:OnValueReleased(self.Value) end
end

function BAR:Think()
    if self.Dragging then self:UpdateFromCursor() end
end

function BAR:Paint(w, h)
    local enabled = self:IsEnabled()
    local hov = UI.Animate(self, "_hover", (enabled and (self:IsHovered() or self.Dragging)) and 1 or 0)
    local trackH = math.max(4, math.floor(h * 0.35))
    local knob = math.floor(h * 0.7)
    local y = math.floor((h - trackH) / 2)
    local fill = self:GetSlideX()
    local accent = enabled and colors.Accent or colors.TextDisabled

    local half = math.floor(knob / 2)
    Draw.Box(half, y, w - knob, trackH, Color(0, 0, 0, 200))
    Draw.Box(half, y, (w - knob) * fill, trackH, accent)
    Draw.Outline(half, y, w - knob, trackH, Color(accent.r, accent.g, accent.b, 150))

    local kx = math.floor((w - knob) * fill)
    local ky = math.floor((h - knob) / 2)
    DrawKnob(kx, ky, knob, knob, accent, hov)
end

vgui.Register("SlashMoon.SliderBar", BAR, "Panel")

-- ========================================================
-- SlashMoon.Slider (DNumSlider с оформлением темы)
-- API полностью совместим с DNumSlider: SetText, SetMin, SetMax,
-- SetDecimals, SetValue, SetConVar, OnValueChanged.
-- ========================================================
local SLIDER = {}

function SLIDER:Init()
    self:SetTall(UI.Scale(40))

    self.Label:SetFont("SlashMoon.Small")
    self.Label:SetTextColor(colors.TextMuted)

    self.TextArea:SetFont("SlashMoon.Small")
    self.TextArea:SetTextColor(colors.Text)
    self.TextArea:SetWide(UI.Scale(56))
    self.TextArea.Paint = function(s, w, h)
        s:DrawTextEntryText(colors.Text, colors.Accent, colors.Text)
    end

    self.Slider.Paint = function(s, w, h)
        local trackH = math.max(4, UI.Scale(10))
        local y = math.floor(h / 2 - trackH / 2)
        Draw.Box(0, y, w, trackH, Color(0, 0, 0, 200))
        Draw.Box(0, y, w * s:GetSlideX(), trackH, colors.Accent)
        Draw.Outline(0, y, w, trackH, Color(colors.Accent.r, colors.Accent.g, colors.Accent.b, 150))
    end

    self.Slider.Knob:SetSize(UI.Scale(16), UI.Scale(20))
    self.Slider.Knob.Paint = function(s, w, h)
        DrawKnob(0, 0, w, h, colors.Accent, s:IsHovered() and 1 or 0)
    end
end

function SLIDER:ApplySchemeSettings()
    self.Label:SetTextColor(colors.TextMuted)
end

vgui.Register("SlashMoon.Slider", SLIDER, "DNumSlider")

-- ========================================================
-- SlashMoon.TextEntry
-- ========================================================
local ENTRY = {}

function ENTRY:Init()
    self:SetFont("SlashMoon.Text")
    self:SetTextColor(colors.Text)
    self:SetCursorColor(colors.Accent)
    self:SetHighlightColor(colors.Accent)
    self:SetPaintBackground(false)
    self:SetTall(UI.Scale(40))
    self._focus = 0
end

function ENTRY:Paint(w, h)
    local focused = self:IsEditing()
    local t = UI.Animate(self, "_focus", focused and 1 or 0)
    local r = UI.Scale(4)

    Draw.RoundedBox(r, 0, 0, w, h, Color(colors.Header.r, colors.Header.g, colors.Header.b, 200))
    Draw.Box(0, h - 2, w, 2, self:IsHovered() and colors.Border or Color(50, 50, 50, 200))

    -- Акцентная линия снизу, разъезжается из центра при фокусе
    if t > 0.01 then
        local lw = w * t
        Draw.Box((w - lw) / 2, h - 2, lw, 2, colors.Accent)
    end

    self:DrawTextEntryText(self:IsEnabled() and colors.Text or colors.TextDisabled, colors.AccentDim, colors.Text)

    local placeholder = self:GetPlaceholderText()
    if self:GetValue() == "" and placeholder and placeholder ~= "" and not focused then
        draw.SimpleText(placeholder, self:GetFont(), UI.Scale(6), h / 2, colors.TextDisabled, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
end

vgui.Register("SlashMoon.TextEntry", ENTRY, "DTextEntry")

-- ========================================================
-- SlashMoon.ComboBox
-- ========================================================
local COMBO = {}
local ComboBase = baseclass.Get("DComboBox")

function COMBO:Init()
    self:SetFont("SlashMoon.Small")
    self:SetTextColor(colors.Text)
    self:SetTall(UI.Scale(40))
    self._hover = 0
    self._outline = Color(0, 0, 0)
    self.DropButton.Paint = function(s, w, h)
        local cx, cy, sz = w / 2, h / 2, math.floor(math.min(w, h) * 0.18)
        surface.SetDrawColor(colors.TextMuted)
        for i = 0, 1 do
            surface.DrawLine(cx - sz, cy - sz / 2 + i, cx, cy + sz / 2 + i)
            surface.DrawLine(cx, cy + sz / 2 + i, cx + sz, cy - sz / 2 + i)
        end
    end
end

function COMBO:Paint(w, h)
    local hov = UI.Animate(self, "_hover", self:IsHovered() and 1 or 0)
    local r = UI.Scale(4)
    Draw.RoundedBox(r, 0, 0, w, h, colors.Header)
    Draw.RoundedOutline(r, 0, 0, w, h, UI.LerpColor(hov, colors.BorderNeutral, colors.Accent, self._outline))
    self:SetTextColor(self:IsEnabled() and colors.Text or colors.TextDisabled)
end

function COMBO:OpenMenu(...)
    ComboBase.OpenMenu(self, ...)
    local menu = self.Menu
    if not IsValid(menu) then return end

    menu.Paint = function(_, w, h)
        Draw.RoundedBox(UI.Scale(4), 0, 0, w, h, colors.Header)
        Draw.RoundedOutline(UI.Scale(4), 0, 0, w, h, colors.Border)
    end

    for _, opt in ipairs(menu:GetCanvas():GetChildren()) do
        opt:SetFont("SlashMoon.Small")
        opt:SetTextColor(colors.Text)
        opt:SetTall(UI.Scale(34))
        opt.Paint = function(s, w, h)
            if s:IsHovered() then
                Draw.Box(0, 0, w, h, colors.AccentDim)
            end
        end
    end
end

vgui.Register("SlashMoon.ComboBox", COMBO, "DComboBox")

-- ========================================================
-- SlashMoon.Binder (выбор клавиши)
-- ========================================================
local BINDER = {}

function BINDER:Init()
    self:SetFont("SlashMoon.Small")
    self:SetTextColor(colors.Text)
    self:SetTall(UI.Scale(40))
    self._hover = 0
    self._outline = Color(0, 0, 0)
end

function BINDER:Paint(w, h)
    local hov = UI.Animate(self, "_hover", self:IsHovered() and 1 or 0)
    local r = UI.Scale(4)
    Draw.RoundedBox(r, 0, 0, w, h, colors.Header)
    local trapping = input.IsKeyTrapping() and self.Trapping
    Draw.RoundedOutline(r, 0, 0, w, h, trapping and colors.Accent or UI.LerpColor(hov, colors.BorderNeutral, colors.Accent, self._outline))
    self:SetTextColor(trapping and colors.Accent or colors.Text)
end

vgui.Register("SlashMoon.Binder", BINDER, "DBinder")

-- ========================================================
-- SlashMoon.ColorPicker (DColorMixer в стиле темы)
-- ========================================================
local PICKER = {}

function PICKER:Init()
    self:SetPalette(false)
    self:SetAlphaBar(false)
    self:SetWangs(true)
    self:DockPadding(UI.Scale(8), UI.Scale(8), UI.Scale(8), UI.Scale(8))
end

function PICKER:Paint(w, h)
    Draw.RoundedBox(UI.Scale(4), 0, 0, w, h, colors.Header)
    Draw.RoundedOutline(UI.Scale(4), 0, 0, w, h, colors.BorderNeutral)
end

vgui.Register("SlashMoon.ColorPicker", PICKER, "DColorMixer")

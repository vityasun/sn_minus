-- Written for: SlashMoon. By: VIKA & Ronni
-- ========================================================
-- SlashMoon UI :: окно (SlashMoon.Frame)
--
--   local frame = SlashMoon.UI.Create("Frame")
--   frame:SetSize(SlashMoon.UI.Scale(800), SlashMoon.UI.Scale(600))
--   frame:Center()
--   frame:SetHeader("ЗАГОЛОВОК")
--
-- Возможности: шапка с заголовком/иконкой, неоновая линия сверху, кнопка закрытия "X",
-- плавное появление/исчезновение (альфа + сдвиг), закрытие по ESC,
-- перетаскивание за шапку, размытие фона.
-- ========================================================

local UI = SlashMoon.UI
local Draw = UI.Draw
local colors = UI.Colors
local BaseClass = baseclass.Get("DFrame")

local PANEL = {}

AccessorFunc(PANEL, "m_bBlur", "Blur", FORCE_BOOL)
AccessorFunc(PANEL, "m_bCloseOnEscape", "CloseOnEscape", FORCE_BOOL)
AccessorFunc(PANEL, "m_bAnimated", "Animated", FORCE_BOOL)
AccessorFunc(PANEL, "m_bShowHeader", "ShowHeader", FORCE_BOOL)

function PANEL:Init()
    -- Прячем стандартные элементы DFrame
    self:SetTitle("")
    self.lblTitle:SetVisible(false)
    self.btnClose:SetVisible(false)
    self.btnMaxim:SetVisible(false)
    self.btnMinim:SetVisible(false)

    self.TitleText = "SLASHMOON"
    self.SubTitleText = nil
    self.Icon = nil
    self.m_bBlur = true
    self.m_bCloseOnEscape = true
    self.m_bAnimated = true
    self.m_bShowHeader = true
    self.HeaderHeight = UI.Scale(56)

    -- Кнопка закрытия
    self.CloseBtn = vgui.Create("DButton", self)
    self.CloseBtn:SetText("")
    self.CloseBtn._hover = 0
    -- Квадрат во всю высоту шапки: "X", красная заливка при наведении
    self.CloseBtn.Paint = function(btn, w, h)
        local hovered = btn:IsHovered()
        if hovered then
            Draw.Box(0, 0, w, h, Color(colors.Danger.r, colors.Danger.g, colors.Danger.b, 200))
        end
        Draw.Text("X", "SlashMoon.Header", w / 2, h / 2, hovered and colors.Text or colors.TextMuted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    self.CloseBtn.DoClick = function()
        UI.PlaySound("Click")
        self:Close()
    end

    self:UpdatePadding()
    self:MakePopup()

    -- Плавное появление
    self:SetAlpha(0)
    self.OpenStart = SysTime()

    UI.PushEscape(self, function(frame)
        if frame:GetCloseOnEscape() then frame:Close() end
    end)

    UI.PlaySound("Open")
end

function PANEL:UpdatePadding()
    local pad = UI.Scale(12)
    local top = self.m_bShowHeader and self.HeaderHeight or 0
    self:DockPadding(pad, top + pad, pad, pad)
end

--- Заголовок окна.
function PANEL:SetHeader(title, subtitle)
    self.TitleText = tostring(title or "")
    if subtitle ~= nil then self.SubTitleText = subtitle end
end
PANEL.SetTitleText = PANEL.SetHeader

function PANEL:GetHeader()
    return self.TitleText
end

--- Подзаголовок (мелкий текст рядом с заголовком).
function PANEL:SetSubHeader(text)
    self.SubTitleText = text
end

--- Иконка в шапке (Material или путь к png).
function PANEL:SetIcon(mat)
    self.Icon = isstring(mat) and Draw.Material(mat) or mat
end

--- Совместимость со старым API.
function PANEL:SetBlurEnabled(enabled)
    self:SetBlur(enabled)
end

--- Показывать ли кнопку закрытия.
function PANEL:ShowCloseButton(show)
    self.CloseBtn:SetVisible(show ~= false)
end

--- Скрыть/показать шапку окна.
function PANEL:SetShowHeader(show)
    self.m_bShowHeader = show ~= false
    self.CloseBtn:SetVisible(self.m_bShowHeader)
    self:UpdatePadding()
    self:InvalidateLayout()
end

--- Высота шапки (в реальных пикселях).
function PANEL:SetHeaderHeight(h)
    self.HeaderHeight = h
    self:UpdatePadding()
    self:InvalidateLayout()
end

function PANEL:GetHeaderHeight()
    return self.m_bShowHeader and self.HeaderHeight or 0
end

--- Закрывает окно с анимацией.
function PANEL:Close()
    if self.Closing then return end
    self.Closing = true
    UI.PlaySound("Close")

    if not self.m_bAnimated then
        BaseClass.Close(self)
        self.Closing = false
        return
    end

    self:SetMouseInputEnabled(false)
    self:SetKeyboardInputEnabled(false)
    self:AlphaTo(0, 0.15, 0, function()
        if not IsValid(self) then return end
        BaseClass.Close(self)

        -- Окно с SetDeleteOnClose(false) только скрывается: готовим его к повторному показу
        if IsValid(self) then
            self.Closing = false
            self:SetAlpha(255)
            self:SetMouseInputEnabled(true)
            self:SetKeyboardInputEnabled(true)
        end
    end)
end

function PANEL:Think()
    BaseClass.Think(self)

    -- Анимация появления: альфа + небольшой сдвиг снизу вверх
    if self.OpenStart then
        local frac = self.m_bAnimated and math.Clamp((SysTime() - self.OpenStart) / 0.2, 0, 1) or 1
        local ease = math.ease and math.ease.OutCubic and math.ease.OutCubic(frac) or frac

        if not self.OpenBaseY then self.OpenBaseY = self.y end
        if self.y ~= self.LastAnimY and self.LastAnimY ~= nil then
            -- Позицию поменяли извне (Center/SetPos) — подстраиваемся
            self.OpenBaseY = self.y - (self.LastAnimOffset or 0)
        end

        local offset = math.Round((1 - ease) * UI.Scale(24))
        self:SetAlpha(255 * ease)
        self:SetPos(self.x, self.OpenBaseY + offset)
        self.LastAnimY = self.y
        self.LastAnimOffset = offset

        if frac >= 1 then
            self.OpenStart = nil
            self:SetPos(self.x, self.OpenBaseY)
        end
    end
end

function PANEL:OnMousePressed(code)
    local _, my = self:CursorPos()
    if self:GetDraggable() and self.m_bShowHeader and my <= self.HeaderHeight then
        self.Dragging = { gui.MouseX() - self.x, gui.MouseY() - self.y }
        self:MouseCapture(true)
        return
    end
    BaseClass.OnMousePressed(self, code)
end

function PANEL:PerformLayout(w, h)
    local size = self.HeaderHeight
    self.CloseBtn:SetSize(size, size)
    self.CloseBtn:SetPos(w - size, 0)
end

function PANEL:Paint(w, h)
    if self.m_bBlur then
        Derma_DrawBackgroundBlur(self, self.m_fCreateTime)
    end

    local r = UI.GetRadius()
    Draw.RoundedBox(r, 0, 0, w, h, colors.Background)

    if self.m_bShowHeader then
        local hh = self.HeaderHeight
        Draw.RoundedBox(r, 0, 0, w, hh, colors.Header, true, true, false, false)

        local x = UI.Scale(20)
        if self.Icon and not self.Icon:IsError() then
            local is = math.floor(hh * 0.5)
            Draw.Icon(self.Icon, x, (hh - is) / 2, is, is, colors.Text)
            x = x + is + UI.Scale(10)
        end

        local tw = Draw.Text(self.TitleText, "SlashMoon.Header", x, hh / 2 - 1, colors.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        if self.SubTitleText and self.SubTitleText ~= "" then
            Draw.Text(self.SubTitleText, "SlashMoon.Small", x + tw + UI.Scale(12), hh / 2, colors.TextMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end

    Draw.RoundedOutline(r, 0, 0, w, h, colors.Border)

    -- Неоновая линия по верхнему краю окна
    Draw.Box(0, 0, w, 2, colors.Accent)
end

vgui.Register("SlashMoon.Frame", PANEL, "DFrame")

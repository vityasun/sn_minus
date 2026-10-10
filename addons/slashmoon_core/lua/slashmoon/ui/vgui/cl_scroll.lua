-- Written for: SlashMoon. By: VIKA & Ronni
-- ========================================================
-- SlashMoon UI :: скролл-панель (SlashMoon.Scroll)
-- DScrollPanel со стилизованным скроллбаром и плавной прокруткой колесом.
-- ========================================================

local UI = SlashMoon.UI
local Draw = UI.Draw
local colors = UI.Colors

local PANEL = {}

function PANEL:Init()
    self.ScrollStep = UI.Scale(90)

    local vbar = self:GetVBar()
    vbar:SetWide(UI.Scale(6))
    vbar:SetHideButtons(true)
    vbar._hover = 0

    vbar.Paint = function(s, w, h)
        Draw.RoundedBox(math.floor(w / 2), 0, 0, w, h, Color(colors.Header.r, colors.Header.g, colors.Header.b, 120))
    end

    vbar.btnGrip._col = Color(0, 0, 0)
    vbar.btnGrip.Paint = function(grip, w, h)
        local hov = UI.Animate(vbar, "_hover", (grip:IsHovered() or vbar.Dragging) and 1 or 0)
        Draw.RoundedBox(math.floor(w / 2), 0, 0, w, h, UI.LerpColor(hov, colors.AccentDim, colors.Accent, grip._col))
        return true
    end

    -- Плавная прокрутка колесом мыши
    vbar.OnMouseWheeled = function(s, delta)
        if not s:IsVisible() then return false end
        local now = SysTime()
        local base = (s.SmoothTarget and now - (s.LastWheel or 0) < 0.4) and s.SmoothTarget or s:GetScroll()
        s.SmoothTarget = math.Clamp(base - delta * self.ScrollStep, 0, s.CanvasSize or 0)
        s.LastWheel = now
        s:AnimateTo(s.SmoothTarget, 0.25, 0, 0.35)
        return true
    end
end

--- Ширина скроллбара в пикселях макета.
function PANEL:SetScrollbarWidth(px)
    self:GetVBar():SetWide(UI.Scale(px))
end

--- Шаг прокрутки колесом (в пикселях макета).
function PANEL:SetScrollStep(px)
    self.ScrollStep = UI.Scale(px)
end

--- Прокрутка к началу/концу.
function PANEL:ScrollToTop()
    self:GetVBar():AnimateTo(0, 0.25, 0, 0.35)
end

function PANEL:ScrollToBottom()
    local vbar = self:GetVBar()
    vbar:AnimateTo(vbar.CanvasSize or 0, 0.25, 0, 0.35)
end

function PANEL:Paint() end

vgui.Register("SlashMoon.Scroll", PANEL, "DScrollPanel")

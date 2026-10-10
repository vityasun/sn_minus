-- Written for: SlashMoon. By: VIKA & Ronni
-- ========================================================
-- SlashMoon UI :: радиальное меню (SlashMoon.RadialMenu)
--
--   local radial = SlashMoon.UI.Create("RadialMenu")
--   radial:SetSlots({ { name = "Танец 1", data = "dance1" }, { name = "Пусто" } })
--   radial.OnSelect = function(self, index, slot) end
--
-- Полноэкранная панель: выбор сектора направлением мыши, клик — выбор и закрытие.
-- ========================================================

local UI = SlashMoon.UI
local Draw = UI.Draw
local colors = UI.Colors

local PANEL = {}

function PANEL:Init()
    self:SetSize(ScrW(), ScrH())
    self:SetPos(0, 0)
    self:MakePopup()
    self:SetKeyboardInputEnabled(false)

    self.Slots = {}
    self.States = {}
    self.Radius = UI.Scale(300)
    self.BoxW, self.BoxH = UI.Scale(240), UI.Scale(54)
    self.CenterSize = UI.Scale(110)
    self.Hint = "Выбрать"
    self.Blur = true
    self.LastHovered = -1
    self.SelectedSlot = nil
    self.m_fCreateTime = SysTime()

    UI.PushEscape(self, function(panel) panel:Remove() end)
end

--- Слоты меню: массив { name = "...", data = любое значение }. Слот без data считается пустым.
function PANEL:SetSlots(slots)
    self.Slots = slots or {}
    self.States = {}
    for i = 1, #self.Slots do
        self.States[i] = { offset = 0, alpha = 150, t = 0 }
    end
end

function PANEL:SetRadius(px) self.Radius = UI.Scale(px) end
function PANEL:SetHint(text) self.Hint = text end
function PANEL:SetBlur(blur) self.Blur = blur ~= false end

--- Переопределите, чтобы временно запретить выбор (например, курсор над кнопкой).
function PANEL:IsInputBlocked() return false end

--- Вызывается при выборе слота.
function PANEL:OnSelect(index, slot) end

function PANEL:GetSelected()
    return self.SelectedSlot, self.SelectedSlot and self.Slots[self.SelectedSlot]
end

function PANEL:Paint(w, h)
    if self.Blur then Derma_DrawBackgroundBlur(self, self.m_fCreateTime) end

    local count = #self.Slots
    if count == 0 then return end

    local cx, cy = w / 2, h / 2
    local mx, my = gui.MousePos()
    local ft = FrameTime()
    local step = 360 / count

    surface.SetDrawColor(255, 255, 255, 5)
    surface.DrawLine(cx, 0, cx, h)
    surface.DrawLine(0, cy, w, cy)

    -- Сектор под курсором
    local hovered = -1
    if not self:IsInputBlocked() then
        local ang = math.deg(math.atan2(my - cy, mx - cx))
        if ang < 0 then ang = ang + 360 end
        ang = (ang + 90 + step / 2) % 360
        hovered = math.floor(ang / step) + 1
    end

    if hovered ~= -1 and hovered ~= self.LastHovered then
        UI.PlaySound("Hover")
    end
    self.LastHovered = hovered
    self.SelectedSlot = hovered ~= -1 and hovered or nil

    -- Центр (ромб)
    local cs = self.CenterSize
    local shadowOff = UI.Scale(6)
    draw.NoTexture()
    surface.SetDrawColor(0, 0, 0, 150)
    surface.DrawPoly({
        { x = cx + shadowOff, y = cy - cs + shadowOff }, { x = cx + cs + shadowOff, y = cy + shadowOff },
        { x = cx + shadowOff, y = cy + cs + shadowOff }, { x = cx - cs + shadowOff, y = cy + shadowOff },
    })
    local center = { { x = cx, y = cy - cs }, { x = cx + cs, y = cy }, { x = cx, y = cy + cs }, { x = cx - cs, y = cy } }
    surface.SetDrawColor(colors.Header.r, colors.Header.g, colors.Header.b, 240)
    surface.DrawPoly(center)
    surface.SetDrawColor(colors.Accent.r, colors.Accent.g, colors.Accent.b, 100)
    for i = 1, 4 do
        local a, b = center[i], center[i % 4 + 1]
        surface.DrawLine(a.x, a.y, b.x, b.y)
    end

    local active = self.SelectedSlot and self.Slots[self.SelectedSlot]
    if active then
        Draw.TextShadow(active.name or "", "SlashMoon.Text", cx, cy - UI.Scale(10), colors.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        if active.data ~= nil then
            Draw.Text(self.Hint, "SlashMoon.Small", cx, cy + UI.Scale(18), colors.Accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    -- Слоты
    local bw, bh = self.BoxW, self.BoxH
    for i = 1, count do
        local isHovered = i == self.SelectedSlot
        local state = self.States[i]
        state.offset = Lerp(ft * 12, state.offset, isHovered and UI.Scale(36) or 0)
        state.alpha = Lerp(ft * 10, state.alpha, isHovered and 255 or 150)
        state.t = Lerp(ft * 15, state.t, isHovered and 1 or 0)

        local a = math.rad((i - 1) * step - 90)
        local x = cx + math.cos(a) * (self.Radius + state.offset)
        local y = cy + math.sin(a) * (self.Radius + state.offset)
        local sx, sy = x - bw / 2, y - bh / 2
        local accent = UI.LerpColor(state.t, colors.BorderNeutral, colors.Accent, state.col)
        state.col = accent

        Draw.Box(sx + shadowOff, sy + shadowOff, bw, bh, Color(0, 0, 0, 150))
        Draw.Box(sx, sy, bw, bh, Color(colors.Header.r, colors.Header.g, colors.Header.b, state.alpha))
        Draw.Box(sx, sy, UI.Scale(4), bh, accent)
        Draw.Outline(sx, sy, bw, bh, Color(accent.r, accent.g, accent.b, math.max(0, state.alpha - 100)))

        local slot = self.Slots[i]
        Draw.TextShadow(slot.name or "Пусто", "SlashMoon.Text", x, y, isHovered and colors.Text or colors.TextMuted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1)
    end
end

function PANEL:OnMouseReleased(code)
    if code == MOUSE_LEFT and self.SelectedSlot then
        UI.PlaySound("Click")
        self:OnSelect(self.SelectedSlot, self.Slots[self.SelectedSlot])
    end
    if not self:IsInputBlocked() and IsValid(self) then self:Remove() end
end

vgui.Register("SlashMoon.RadialMenu", PANEL, "EditablePanel")

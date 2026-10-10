-- Written for: SlashMoon. By: VIKA & Ronni
-- ========================================================
-- SlashMoon UI :: медиа и раскладки
--   SlashMoon.Avatar      — аватар Steam или произвольная картинка
--   SlashMoon.ModelPanel  — 3D-модель на фоне карточки
--   SlashMoon.Grid        — сетка карточек (DIconLayout)
--   SlashMoon.ProgressBar — полоса прогресса
-- ========================================================

local UI = SlashMoon.UI
local Draw = UI.Draw
local colors = UI.Colors

-- ========================================================
-- SlashMoon.Avatar
-- ========================================================
local AVATAR = {}

function AVATAR:Init()
    self.Material = nil
    self.BorderColor = nil
    self.Radius = 0

    self.SteamAvatar = vgui.Create("AvatarImage", self)
    self.SteamAvatar:SetVisible(false)
    self.SteamAvatar:SetMouseInputEnabled(false)
end

function AVATAR:PerformLayout(w, h)
    local pad = UI.Scale(2)
    self.SteamAvatar:SetPos(pad, pad)
    self.SteamAvatar:SetSize(w - pad * 2, h - pad * 2)
end

--- Произвольная картинка (путь к png или Material).
function AVATAR:SetImage(mat)
    if not mat or mat == "" then return end
    self.SteamAvatar:SetVisible(false)
    self.Material = isstring(mat) and Draw.Material(mat) or mat
end

--- Аватар игрока Steam.
function AVATAR:SetPlayer(ply, size)
    if not IsValid(ply) then return end
    self.Material = nil
    self.SteamAvatar:SetVisible(true)
    self.SteamAvatar:SetPlayer(ply, size or 64)
end

--- Аватар по SteamID64.
function AVATAR:SetSteamID(steamID64, size)
    self.Material = nil
    self.SteamAvatar:SetVisible(true)
    self.SteamAvatar:SetSteamID(steamID64, size or 64)
end

function AVATAR:SetBorderColor(col)
    self.BorderColor = col
end

function AVATAR:Paint(w, h)
    Draw.Box(0, 0, w, h, colors.Header)
    if self.Material and not self.Material:IsError() then
        local pad = UI.Scale(2)
        Draw.Icon(self.Material, pad, pad, w - pad * 2, h - pad * 2, color_white)
    end
end

function AVATAR:PaintOver(w, h)
    Draw.Outline(0, 0, w, h, self.BorderColor or colors.Border)
end

vgui.Register("SlashMoon.Avatar", AVATAR, "Panel")

-- ========================================================
-- SlashMoon.ModelPanel
-- ========================================================
local MODEL = {}
local ModelBase = baseclass.Get("DModelPanel")

function MODEL:Init()
    self.Background = "Header"
    self.Radius = UI.Radius
end

--- Фон: ключ палитры, Color или false.
function MODEL:SetBackground(value)
    self.Background = value
end

function MODEL:Paint(w, h)
    if self.Background then
        local col = (IsColor(self.Background) or istable(self.Background)) and self.Background or colors[self.Background]
        if col then Draw.RoundedBox(UI.Scale(self.Radius), 0, 0, w, h, col) end
    end
    ModelBase.Paint(self, w, h)
end

vgui.Register("SlashMoon.ModelPanel", MODEL, "DModelPanel")

-- ========================================================
-- SlashMoon.Grid
-- ========================================================
local GRID = {}

function GRID:Init()
    self:SetSpaceX(UI.Scale(10))
    self:SetSpaceY(UI.Scale(10))
    self:SetBorder(0)
end

vgui.Register("SlashMoon.Grid", GRID, "DIconLayout")

-- ========================================================
-- SlashMoon.ProgressBar
-- ========================================================
local PROGRESS = {}

function PROGRESS:Init()
    self.Fraction = 0
    self.Shown = 0
    self.BarColor = nil
    self.Text = nil
    self:SetTall(UI.Scale(14))
end

function PROGRESS:SetFraction(f) self.Fraction = math.Clamp(tonumber(f) or 0, 0, 1) end
function PROGRESS:GetFraction() return self.Fraction end
function PROGRESS:SetBarColor(col) self.BarColor = col end
function PROGRESS:SetText(text) self.Text = text end

function PROGRESS:Paint(w, h)
    local f = UI.Animate(self, "Shown", self.Fraction, 8)
    Draw.ProgressBar(0, 0, w, h, f, self.BarColor or colors.Accent, math.floor(h / 2))
    if self.Text then
        Draw.TextShadow(self.Text, "SlashMoon.Tiny", w / 2, h / 2, colors.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1)
    end
end

vgui.Register("SlashMoon.ProgressBar", PROGRESS, "Panel")

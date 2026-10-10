-- Written for: SlashMoon. By: VIKA & Ronni
-- ========================================================
-- SlashMoon UI :: адаптивность под разрешение экрана
--
-- Все размеры в интерфейсах задаются "в пикселях макета" 2560x1440
-- и переводятся в реальные пиксели через SlashMoon.UI.Scale(px).
-- ========================================================

local UI = SlashMoon.UI

UI.BaseWidth = 2560
UI.BaseHeight = 1440
UI.MinScale = 0.5

local function Recalc()
    UI.ScaleMultiplier = math.max(UI.MinScale, ScrH() / UI.BaseHeight)
    UI.ScaleMultiplierW = math.max(UI.MinScale, ScrW() / UI.BaseWidth)
end
Recalc()

--- Масштабирует размер макета (по высоте экрана).
function UI.Scale(px)
    return math.Round((tonumber(px) or 0) * UI.ScaleMultiplier)
end

--- Масштабирует размер макета по ширине экрана.
function UI.ScaleW(px)
    return math.Round((tonumber(px) or 0) * UI.ScaleMultiplierW)
end

--- Доля ширины экрана (0..1) в пикселях.
function UI.ScreenW(fraction)
    return math.Round(ScrW() * (fraction or 1))
end

--- Доля высоты экрана (0..1) в пикселях.
function UI.ScreenH(fraction)
    return math.Round(ScrH() * (fraction or 1))
end

--- Размер окна по доле экрана, ограниченный минимальным размером макета.
-- @return number w, number h
function UI.WindowSize(fracW, fracH, minW, minH)
    local w = math.max(UI.ScreenW(fracW), math.min(ScrW(), UI.Scale(minW or 0)))
    local h = math.max(UI.ScreenH(fracH), math.min(ScrH(), UI.Scale(minH or 0)))
    return w, h
end

hook.Add("OnScreenSizeChanged", "SlashMoon.UI.Scale", function()
    Recalc()
    hook.Run("SlashMoon.UI.ScaleChanged", UI.ScaleMultiplier)
end)

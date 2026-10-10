-- Written for: SlashMoon. By: VIKA & Ronni
-- ========================================================
-- SlashMoon UI :: примитивы отрисовки (VGUI, HUD, 3D2D)
-- ========================================================

local UI = SlashMoon.UI
UI.Draw = UI.Draw or {}
local Draw = UI.Draw
local colors = UI.Colors

-- Короткий доступ: SlashMoon.Draw.*
SlashMoon.Draw = Draw

local surface_SetDrawColor = surface.SetDrawColor
local surface_DrawRect = surface.DrawRect

--- Прямоугольник.
function Draw.Box(x, y, w, h, col)
    surface_SetDrawColor(col)
    surface_DrawRect(x, y, w, h)
end

--- Прямоугольник со скругленными углами (radius в реальных пикселях).
-- Можно отключить отдельные углы: tl, tr, bl, br = false.
function Draw.RoundedBox(radius, x, y, w, h, col, tl, tr, bl, br)
    if radius <= 0 then
        Draw.Box(x, y, w, h, col)
        return
    end
    if tl == nil then
        draw.RoundedBox(radius, x, y, w, h, col)
    else
        draw.RoundedBoxEx(radius, x, y, w, h, col, tl, tr ~= false, bl ~= false, br ~= false)
    end
end

--- Обводка прямоугольника.
function Draw.Outline(x, y, w, h, col, thickness)
    surface_SetDrawColor(col)
    surface.DrawOutlinedRect(x, y, w, h, thickness or 1)
end

-- Кэш точек дуг для скругленной обводки
local arcCache = {}
local function ArcPoints(radius)
    if arcCache[radius] then return arcCache[radius] end
    local pts = {}
    local steps = math.Clamp(math.ceil(radius / 2), 3, 12)
    for i = 0, steps do
        local a = math.rad(90 * i / steps)
        pts[#pts + 1] = { math.cos(a), math.sin(a) }
    end
    arcCache[radius] = pts
    return pts
end

--- Скругленная обводка толщиной 1px.
function Draw.RoundedOutline(radius, x, y, w, h, col)
    if radius <= 0 then
        Draw.Outline(x, y, w, h, col)
        return
    end
    radius = math.min(radius, math.floor(w / 2), math.floor(h / 2))
    surface_SetDrawColor(col)

    -- Прямые участки
    surface_DrawRect(x + radius, y, w - radius * 2, 1)
    surface_DrawRect(x + radius, y + h - 1, w - radius * 2, 1)
    surface_DrawRect(x, y + radius, 1, h - radius * 2)
    surface_DrawRect(x + w - 1, y + radius, 1, h - radius * 2)

    -- Углы
    local pts = ArcPoints(radius)
    local r = radius - 0.5
    local corners = {
        { x + radius, y + radius, -1, -1 },
        { x + w - radius - 1, y + radius, 1, -1 },
        { x + radius, y + h - radius - 1, -1, 1 },
        { x + w - radius - 1, y + h - radius - 1, 1, 1 },
    }
    for _, c in ipairs(corners) do
        for i = 1, #pts - 1 do
            local p1, p2 = pts[i], pts[i + 1]
            surface.DrawLine(c[1] + p1[1] * r * c[3], c[2] + p1[2] * r * c[4], c[1] + p2[1] * r * c[3], c[2] + p2[2] * r * c[4])
        end
    end
end

-- Кэш полигонов кругов
local circleCache = {}

--- Закрашенный круг.
function Draw.Circle(x, y, radius, col, segments)
    segments = segments or math.Clamp(math.floor(radius), 16, 64)
    local key = radius .. ":" .. segments
    local poly = circleCache[key]
    if not poly then
        poly = {}
        for i = 0, segments do
            local a = math.rad((i / segments) * -360)
            poly[#poly + 1] = { x = math.sin(a) * radius, y = math.cos(a) * radius }
        end
        circleCache[key] = poly
    end

    local translated = {}
    for i, p in ipairs(poly) do
        translated[i] = { x = p.x + x, y = p.y + y }
    end

    draw.NoTexture()
    surface_SetDrawColor(col)
    surface.DrawPoly(translated)
end

local blurMat = Material("pp/blurscreen")

--- Размытие участка экрана (координаты экранные).
function Draw.Blur(x, y, w, h, density, alpha)
    surface_SetDrawColor(255, 255, 255, alpha or 255)
    surface.SetMaterial(blurMat)
    for i = 1, (density or 3) do
        blurMat:SetFloat("$blur", (i / 3) * 4)
        blurMat:Recompute()
        render.UpdateScreenEffectTexture()
        render.SetScissorRect(x, y, x + w, y + h, true)
        surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
        render.SetScissorRect(0, 0, 0, 0, false)
    end
end

--- Размытие фона под панелью (вызывать из PANEL:Paint).
function Draw.PanelBlur(panel, density, alpha)
    local x, y = panel:LocalToScreen(0, 0)
    surface_SetDrawColor(255, 255, 255, alpha or 255)
    surface.SetMaterial(blurMat)
    for i = 1, (density or 3) do
        blurMat:SetFloat("$blur", (i / 3) * 4)
        blurMat:Recompute()
        render.UpdateScreenEffectTexture()
        surface.DrawTexturedRect(-x, -y, ScrW(), ScrH())
    end
end

--- Базовая плашка HUD (блюр + фон + акцентная полоса + обводка).
function Draw.HUDPanel(x, y, w, h)
    Draw.Blur(x, y, w, h, 3, 255)
    Draw.Box(x, y, w, h, colors.Background)
    Draw.Box(x, y, 4, h, colors.Accent)
    Draw.Outline(x, y, w, h, colors.Border)
end

--- Прогресс-бар. fraction: 0..1.
function Draw.ProgressBar(x, y, w, h, fraction, barColor, radius)
    radius = radius or 0
    Draw.RoundedBox(radius, x, y, w, h, Color(10, 10, 10, 200))
    local fillW = math.floor(math.max(0, w * math.Clamp(fraction or 0, 0, 1)))
    if fillW > 0 then
        Draw.RoundedBox(math.min(radius, math.floor(fillW / 2)), x, y, fillW, h, barColor or colors.Accent)
    end
    if radius > 0 then
        Draw.RoundedOutline(radius, x, y, w, h, colors.Shadow)
    else
        Draw.Outline(x, y, w, h, Color(0, 0, 0, 255))
    end
end

--- Текст.
function Draw.Text(text, font, x, y, col, alignX, alignY)
    return draw.SimpleText(text, font, x, y, col or colors.Text, alignX, alignY)
end

--- Текст с мягкой падающей тенью.
function Draw.TextShadow(text, font, x, y, col, alignX, alignY, offset)
    offset = offset or 2
    local shadow = colors.Shadow
    if col and col.a and col.a < 255 then
        shadow = Color(shadow.r, shadow.g, shadow.b, shadow.a * (col.a / 255))
    end
    draw.SimpleText(text, font, x + offset, y + offset, shadow, alignX, alignY)
    return draw.SimpleText(text, font, x, y, col or colors.Text, alignX, alignY)
end

--- Бейдж (плашка с текстом). Возвращает ширину + отступ для следующего бейджа.
function Draw.Badge(x, y, text, col, font)
    font = font or "SlashMoon.Small"
    surface.SetFont(font)
    local tw, th = surface.GetTextSize(text)
    local padX, padY = 12, 4
    local w, h = tw + padX, th + padY

    Draw.Box(x, y, w, h, Color(15, 15, 15, 240))
    Draw.Box(x, y, 3, h, col)
    Draw.Outline(x, y, w, h, Color(col.r, col.g, col.b, 100))
    draw.SimpleText(text, font, x + padX / 2 + 1, y + padY / 2, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    return w + 5
end

--- Иконка (материал) с цветом.
function Draw.Icon(mat, x, y, w, h, col)
    if not mat or mat:IsError() then return false end
    surface_SetDrawColor(col or color_white)
    surface.SetMaterial(mat)
    surface.DrawTexturedRect(x, y, w, h)
    return true
end

local gradUp = Material("vgui/gradient-u")
local gradDown = Material("vgui/gradient-d")
local gradLeft = Material("vgui/gradient-l")
local gradRight = Material("vgui/gradient-r")

--- Градиент. dir: "up" | "down" | "left" | "right".
function Draw.Gradient(x, y, w, h, dir, col)
    local mat = (dir == "up" and gradUp) or (dir == "left" and gradLeft) or (dir == "right" and gradRight) or gradDown
    surface_SetDrawColor(col)
    surface.SetMaterial(mat)
    surface.DrawTexturedRect(x, y, w, h)
end

--- Переносит текст по словам под заданную ширину. Возвращает массив строк.
function Draw.WrapText(text, font, maxWidth)
    surface.SetFont(font)
    local lines = {}
    for paragraph in string.gmatch(tostring(text) .. "\n", "(.-)\n") do
        local line = ""
        for word in string.gmatch(paragraph, "%S+") do
            local test = line == "" and word or (line .. " " .. word)
            if surface.GetTextSize(test) > maxWidth and line ~= "" then
                lines[#lines + 1] = line
                line = word
            else
                line = test
            end
        end
        lines[#lines + 1] = line
    end
    return lines
end

-- Кэш материалов по пути
local matCache = {}

--- Material() с кэшем (по умолчанию флаги "noclamp smooth").
function Draw.Material(path, flags)
    local key = path .. "|" .. (flags or "")
    if not matCache[key] then
        matCache[key] = Material(path, flags or "noclamp smooth")
    end
    return matCache[key]
end

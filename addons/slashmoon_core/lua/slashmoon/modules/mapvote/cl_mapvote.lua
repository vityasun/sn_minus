-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("mapvote")

-- ============================================================
-- Рулетка смены карты (оверлей поверх HUD в цветах темы)
-- ============================================================

local colors = SlashMoon.UI.Colors

local ROLL_DURATION = 10.0
local ITEM_W        = 128
local ITEM_H        = 128
local ITEM_GAP      = 15
local TOTAL_ITEMS   = 44
local mv = {}

-- Строим ленту: победитель строго в центре, остальное — все карты
local function BuildStrip(allMaps, winner)
    local strip = {}
    local centerIdx = math.floor(TOTAL_ITEMS / 2) + 1
    
    for i = 1, TOTAL_ITEMS do
        if i == centerIdx then
            strip[i] = winner
        else
            strip[i] = allMaps[((i - 1) % #allMaps) + 1]
        end
    end
    
    return strip, centerIdx
end

local function EaseOut(t)
    return 1 - math.pow(1 - t, 4)
end

-- ============================================================
-- СЕТЕВЫЕ ПРИЕМНИКИ
-- ============================================================
MODULE:Receive("fh_mapvote_start", function()
    local allMaps    = net.ReadTable()
    local winner     = net.ReadString()
    local recentMaps = net.ReadTable()
    local currentMap = net.ReadString()
    
    local recentSet = {}
    for _, m in ipairs(recentMaps) do recentSet[m] = true end
    if currentMap and currentMap ~= "" then recentSet[currentMap] = true end
    
    local strip, centerIdx = BuildStrip(allMaps, winner)
    
    mv = {
        active      = true,
        startTime   = CurTime(),
        strip       = strip,
        centerIdx   = centerIdx,
        winner      = winner,
        allMaps     = allMaps,
        recentSet   = recentSet,
        currentMap  = currentMap,
        finalOffset = (centerIdx - 1) * (ITEM_W + ITEM_GAP),
        startOffset = 0,
        finished    = false,
        result      = "",
        hideAt      = nil,
    }
end)

MODULE:Receive("fh_mapvote_result", function()
    mv.result   = net.ReadString()
    mv.finished = true
    mv.hideAt   = CurTime() + 6
end)

-- ============================================================
-- ОТРИСОВКА
-- ============================================================
MODULE:Hook("HUDPaint", "fh_mapvote_draw", function()
    if not mv.active then return end
    if mv.hideAt and CurTime() > mv.hideAt then
        mv.active = false
        return
    end
    
    local sw, sh = ScrW(), ScrH()
    local cx     = sw * 0.5
    local cy     = sh * 0.5
    
    local elapsed  = CurTime() - mv.startTime
    local progress = math.Clamp(elapsed / ROLL_DURATION, 0, 1)
    local eased    = EaseOut(progress)
    local offset   = Lerp(eased, mv.startOffset, mv.finalOffset)
    
    -- Размытие фона и затемнение
    SlashMoon.UI.Draw.Blur(0, 0, sw, sh, 3, 255)
    surface.SetDrawColor(0, 0, 0, 200)
    surface.DrawRect(0, 0, sw, sh)
    
    -- Главная панель
    local panelW = math.min(1000, sw * 0.8)
    local panelH = 260
    local panelX = cx - panelW * 0.5
    local panelY = cy - panelH * 0.5
    
    surface.SetDrawColor(colors.DarkBG)
    surface.DrawRect(panelX, panelY, panelW, panelH)
    
    -- Неоновая линия сверху
    surface.SetDrawColor(colors.Theme)
    surface.DrawRect(panelX, panelY, panelW, 2)
    
    -- Обводка окна
    surface.SetDrawColor(colors.Outline)
    surface.DrawOutlinedRect(panelX, panelY, panelW, panelH, 1)
    
    -- Тексты заголовка
    SlashMoon.UI.Draw.TextShadow("СМЕНА КАРТЫ", "SlashMoon.Title", cx, panelY + 30, colors.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    SlashMoon.UI.Draw.TextShadow(progress >= 1 and "РЕЗУЛЬТАТ ГОЛОСОВАНИЯ" or "ВРАЩЕНИЕ РУЛЕТКИ...", "SlashMoon.Text", cx, panelY + 60, colors.Theme, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    
    -- Область рулетки
    local stripY = panelY + 100
    local stripX = panelX + 20
    local stripW = panelW - 40
    
    -- Темный фон под лентой
    surface.SetDrawColor(10, 10, 10, 200)
    surface.DrawRect(stripX, stripY, stripW, ITEM_H)
    surface.SetDrawColor(0, 0, 0, 255)
    surface.DrawOutlinedRect(stripX, stripY, stripW, ITEM_H, 1)
    
    render.SetScissorRect(stripX, stripY, stripX + stripW, stripY + ITEM_H, true)
    
    if not mv.matCache then mv.matCache = {} end
    
    local function GetMapMaterial(map)
        if mv.matCache[map] ~= nil then return mv.matCache[map] end
        local paths = { "fh_mapvote/" .. map .. ".png", "maps/thumb/" .. map .. ".png", "maps/" .. map .. ".png" }
        local mat = nil
        for _, path in ipairs(paths) do
            if file.Exists("materials/" .. path, "GAME") then
                mat = Material(path, "noclamp smooth")
                if mat and not mat:IsError() then break end
                mat = nil
            end
        end
        mv.matCache[map] = mat or false
        return mv.matCache[map]
    end
    
    -- Отрисовка карточек
    for i = 1, #mv.strip do
        local map = mv.strip[i]
        local ix  = stripX + (i - 1) * (ITEM_W + ITEM_GAP) - offset + (stripW * 0.5 - ITEM_W * 0.5)
        local iy  = stripY
        
        if ix + ITEM_W < stripX or ix > stripX + stripW then continue end
        
        local isWinner  = (i == mv.centerIdx) and (progress >= 0.97)
        local isRecent  = mv.recentSet and mv.recentSet[map]
        
        -- Фон карточки
        surface.SetDrawColor(20, 20, 20, 255)
        surface.DrawRect(ix, iy, ITEM_W, ITEM_H)

        local mat = GetMapMaterial(map)
        if mat then
            surface.SetDrawColor(255, 255, 255, 255)
            surface.SetMaterial(mat)
            surface.DrawTexturedRect(ix, iy, ITEM_W, ITEM_H)
        end

        local short = string.upper(map:match("_(.+)$") or map:sub(1, 3))
        if #short > 10 then short = short:sub(1, 10) end

        if isWinner then
            -- Победитель: Яркая фиолетовая подсветка
            surface.SetDrawColor(colors.Theme.r, colors.Theme.g, colors.Theme.b, 50)
            surface.DrawRect(ix, iy, ITEM_W, ITEM_H)
            surface.SetDrawColor(colors.Theme)
            surface.DrawOutlinedRect(ix, iy, ITEM_W, ITEM_H, 3)
            
            -- Плашка с названием
            surface.SetDrawColor(colors.DarkBG)
            surface.DrawRect(ix, iy + ITEM_H - 30, ITEM_W, 30)
            SlashMoon.UI.Draw.TextShadow(short, "SlashMoon.Text", ix + ITEM_W/2, iy + ITEM_H - 15, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            
        elseif isRecent then
            -- Заблокировано: Красное затемнение
            surface.SetDrawColor(0, 0, 0, 220)
            surface.DrawRect(ix, iy, ITEM_W, ITEM_H)
            surface.SetDrawColor(255, 50, 50, 150)
            surface.DrawOutlinedRect(ix, iy, ITEM_W, ITEM_H, 1)
            
            SlashMoon.UI.Draw.TextShadow("БЛОКИРОВКА", "SlashMoon.Small", ix + ITEM_W/2, iy + ITEM_H/2 - 10, Color(255, 100, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            SlashMoon.UI.Draw.TextShadow(short, "SlashMoon.Small", ix + ITEM_W/2, iy + ITEM_H/2 + 10, colors.TextMuted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        else
            -- Обычная карта
            surface.SetDrawColor(0, 0, 0, 100)
            surface.DrawRect(ix, iy, ITEM_W, ITEM_H)
            surface.SetDrawColor(colors.Outline)
            surface.DrawOutlinedRect(ix, iy, ITEM_W, ITEM_H, 1)
            
            -- Плашка с названием (Тусклая)
            surface.SetDrawColor(15, 15, 15, 240)
            surface.DrawRect(ix, iy + ITEM_H - 30, ITEM_W, 30)
            SlashMoon.UI.Draw.TextShadow(short, "SlashMoon.Small", ix + ITEM_W/2, iy + ITEM_H - 15, colors.TextMuted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end
    
    render.SetScissorRect(0, 0, 0, 0, false)
    
    -- === НОВОЕ: Указатели рулетки (Неоновые треугольники) ===
    local arrowX = cx
    
    -- Верхний указатель
    draw.NoTexture()
    surface.SetDrawColor(colors.Theme)
    surface.DrawPoly({
        {x = arrowX - 10, y = stripY - 2},
        {x = arrowX + 10, y = stripY - 2},
        {x = arrowX,      y = stripY + 10},
    })
    
    -- Нижний указатель
    surface.DrawPoly({
        {x = arrowX - 10, y = stripY + ITEM_H + 2},
        {x = arrowX + 10, y = stripY + ITEM_H + 2},
        {x = arrowX,      y = stripY + ITEM_H - 10},
    })
    
    -- === НОВОЕ: Окно результата ===
    if mv.finished and mv.result ~= "" then
        local resultY = panelY + panelH + 20
        local resH = 60
        
        surface.SetDrawColor(colors.DarkBG)
        surface.DrawRect(panelX, resultY, panelW, resH)
        surface.SetDrawColor(50, 255, 100, 255) -- Зеленая неоновая линия успеха
        surface.DrawRect(panelX, resultY, panelW, 2)
        surface.SetDrawColor(colors.Outline)
        surface.DrawOutlinedRect(panelX, resultY, panelW, resH, 1)

        SlashMoon.UI.Draw.TextShadow("СЛЕДУЮЩАЯ КАРТА: " .. string.upper(mv.result), "SlashMoon.Header", cx, resultY + resH/2, Color(50, 255, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end)

MODULE:OnDisabled(function() mv = {} end)

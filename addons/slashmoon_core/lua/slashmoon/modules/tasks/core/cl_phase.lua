-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("tasks")

-- ========================================================
-- SN Tasks: Client Phase System & 3D GTA Escape Markers
-- Интеграция с SlashMoon.FH.Timer (без дублирования таймера)
-- ========================================================
if not CLIENT then return end

local colors = SlashMoon.UI.Colors

local COL = {
    ACCENT = colors.Accent, -- акцент темы (меняется вместе с палитрой)
    WARN   = Color(255, 150, 50),
    ESCAPE = Color(50, 255, 100),
    FAILED = Color(255, 50, 50)
}

local phaseState = { active = false, phase = "none", lastUpdateAt = 0, lastUpdateValue = 0, paused = false }
local escapeMarkers  = {}
local pendingMarkers = {}
local escapeProgress = 0
local iEscaped       = false

timer.Simple(1, function()
    if util.NetworkStringToID("SN_Phase_RequestState") == 0 then return end
    net.Start("SN_Phase_RequestState")
    net.SendToServer()
end)

local phaseConfig = {
    task    = { titleKey = "sn.phase.task",    color = COL.ACCENT, totalTime = 600 },
    penalty = { titleKey = "sn.phase.penalty",  color = COL.WARN,   totalTime = 600 },
    escape  = { titleKey = "sn.phase.escape",   color = COL.ESCAPE, totalTime = 120 },
}

-- ========================================================
-- ГЛОБАЛЬНЫЙ ЭКСПОРТ ФАЗЫ (для cl_tasklist.lua и других)
-- Раньше cl_tasklist проверял SlashMoon.Phase.State.phase (сервер!),
-- что всегда возвращало "none" на клиенте
-- ========================================================
function SlashMoon.Tasks.GetPhase()
    return phaseState.phase or "none"
end

function SlashMoon.Tasks.IsPhaseActive()
    return phaseState.active and phaseState.phase ~= "none"
end


local MAT_SOLID = CreateMaterial("fhi_marker_solid", "UnlitGeneric", {
    ["$basetexture"] = "vgui/white", ["$model"] = "0", ["$translucent"] = "1",
    ["$vertexcolor"] = "1", ["$vertexalpha"] = "1", ["$nocull"] = "1", ["$ignorez"] = "0"
})

-- ========================================================
-- ОБНОВЛЕНИЕ SlashMoon.FH.Timer (вместо отдельного DrawPhaseTimer)
-- Мы обновляем SlashMoon.FH.Timer чтобы cl_fh_hud_override.lua
-- рисовал таймер с нашими фазовыми данными.
-- Если SlashMoon.FH не существует — создаём, чтобы таймер
-- всегда был доступен (fallback рендер ниже).
-- ========================================================
local fhHUDHandledTimer = false  -- true = FH gamemode сам рисует таймер

local function UpdateFHTimer()
    if not phaseState.active or phaseState.phase == "none" then return end

    local cfg = phaseConfig[phaseState.phase]
    if not cfg then return end

    local me = LocalPlayer()
    local isAnim = SlashMoon.Tasks.Game.IsAnimatronic(me)

    -- Вычисляем оставшееся время
    local elapsed = (phaseState.lastUpdateAt == math.huge) and 0 or math.max(0, CurTime() - phaseState.lastUpdateAt)
    local timeLeft = math.max(0, phaseState.lastUpdateValue - elapsed)

    -- Локализованный заголовок фазы
    local title = SlashMoon.Tasks.Lang(cfg.titleKey)
    if phaseState.phase == "escape" then
        title = isAnim and SlashMoon.Tasks.Lang("sn.phase.hunt") or SlashMoon.Tasks.Lang("sn.phase.escape")
    end

    -- Создаём SlashMoon.FH если его нет (fallback для автономного режима)
    if not SlashMoon.FH then
        SlashMoon.FH = {}
        fhHUDHandledTimer = false
    elseif not fhHUDHandledTimer and SlashMoon.Modules.IsEnabled("hud") then
        fhHUDHandledTimer = true
    end

    -- Обновляем SlashMoon.FH.Timer чтобы FH HUD отрисовал его
    SlashMoon.FH.Timer = SlashMoon.FH.Timer or {}
    SlashMoon.FH.Timer.active = true
    SlashMoon.FH.Timer.mode = "game"
    SlashMoon.FH.Timer.title = title
    SlashMoon.FH.Timer.endT = CurTime() + timeLeft
    SlashMoon.FH.Timer.total = math.max(1, cfg.totalTime)
    SlashMoon.FH.Timer.setupEndT = 0
    SlashMoon.FH.Timer.setupTotal = 0
    SlashMoon.FH.Timer.sub = ""
end

-- ========================================================
-- ФАЗОВЫЙ ТАЙМЕР РАУНДА (в стиле HUD-модуля SlashMoon)
-- Рисуется когда FHI_IsPhaseActive() = true.
-- Дизайн: текстурный фон, глой, FormatTime,
-- фазовые цвета, прогресс-бар, доп. инфа о фазе.
-- ========================================================

-- Текстуры (те же что использует HUD-модуля SlashMoon)
local matTimerBg   = Material("vgui/sn/hud/timer/timer.png", "noclamp smooth")
local matTimerGlow = Material("vgui/sn/hud/timer/glow.png", "noclamp smooth")

-- Форматирование времени ММ:СС (как в библиотеке SlashMoon)
local function FormatTime(seconds)
    local m = math.floor(seconds / 60)
    local s = math.floor(seconds % 60)
    return string.format("%02d:%02d", m, s)
end

-- Рендер фазового таймера
MODULE:Hook("HUDPaint", "SN_Phase_Timer", function()
    if not phaseState.active or phaseState.phase == "none" then return end
    if not GetConVar("cl_drawhud"):GetBool() then return end

    local sw, sh = ScrW(), ScrH()

    -- === Параметры панели (как в HUD-модуля SlashMoon) ===
    local pnlW, pnlH = 350, 110
    local x = sw / 2 - pnlW / 2
    local y = 15

    -- === Вычисление времени ===
    local timeLeft = 0
    if SlashMoon.FH and SlashMoon.FH.Timer and SlashMoon.FH.Timer.active then
        timeLeft = math.max(0, SlashMoon.FH.Timer.endT - CurTime())
    else
        -- Fallback: вычисляем сами из phaseState
        local elapsed = (phaseState.lastUpdateAt == math.huge) and 0 or math.max(0, CurTime() - phaseState.lastUpdateAt)
        timeLeft = math.max(0, phaseState.lastUpdateValue - elapsed)
    end

    local total    = math.max(1, phaseConfig[phaseState.phase] and phaseConfig[phaseState.phase].totalTime or 600)
    local progress = math.Clamp(timeLeft / total, 0, 1)

    -- === Цвета фазы ===
    local phaseCol = COL.ACCENT
    if phaseState.phase == "penalty" then phaseCol = COL.WARN
    elseif phaseState.phase == "escape" then phaseCol = COL.ESCAPE end

    -- Пульсация при < 60 сек
    local pulse = 1
    if timeLeft < 60 then
        pulse = math.sin(CurTime() * 4) * 0.12 + 0.88
    end

    -- === Фон панели (текстура / fallback) ===
    if not matTimerBg:IsError() then
        surface.SetDrawColor(255, 255, 255, 250)
        surface.SetMaterial(matTimerBg)
        surface.DrawTexturedRect(x, y - 4, pnlW, pnlH)
    else
        surface.SetDrawColor(colors.DarkBG)
        surface.DrawRect(x, y, pnlW, pnlH)
        surface.SetDrawColor(phaseCol)
        surface.DrawRect(x, y, pnlW, 2)
        surface.SetDrawColor(colors.Outline)
        surface.DrawOutlinedRect(x, y, pnlW, pnlH, 1)
    end

    -- === Прогресс-бар (6px внизу панели) ===
    local barY = y + pnlH - 6
    local fillW = pnlW * progress

    surface.SetDrawColor(0, 0, 0, 200)
    surface.DrawRect(x, barY, pnlW, 6)
    surface.SetDrawColor(phaseCol.r * pulse, phaseCol.g * pulse, phaseCol.b * pulse, 255)
    surface.DrawRect(x, barY, fillW, 6)

    -- === Заголовок фазы ===
    local title = ""
    if SlashMoon.FH and SlashMoon.FH.Timer and SlashMoon.FH.Timer.title then
        title = SlashMoon.FH.Timer.title
    else
        local cfg = phaseConfig[phaseState.phase]
        if cfg then title = SlashMoon.Tasks.Lang(cfg.titleKey) end
    end

    SlashMoon.UI.Draw.TextShadow(title, "SlashMoon.Title", sw / 2, y + 25, phaseCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    -- === Время ММ:СС ===
    local timeStr = FormatTime(timeLeft)
    SlashMoon.UI.Draw.TextShadow(timeStr, "SlashMoon.PhaseTime", sw / 2, y + 60, colors.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    -- === Доп. инфа о фазе (под временем) ===
    local subText = ""
    if phaseState.phase == "task" then
        -- Показываем кол-во активных заданий
        local activeCount = SlashMoon.Tasks.GetActiveCount and SlashMoon.Tasks.GetActiveCount() or 0
        if activeCount > 0 then
            subText = SlashMoon.Tasks.Lang("sn.phase.tasks_active", activeCount)
        end
    elseif phaseState.phase == "penalty" then
        subText = SlashMoon.Tasks.Lang("sn.phase.penalty_hint")
    elseif phaseState.phase == "escape" then
        local me = LocalPlayer()
        if SlashMoon.Tasks.Game.IsSurvivor(me) and not iEscaped then
            subText = SlashMoon.Tasks.Lang("sn.phase.find_escape")
        end
    end

    if subText ~= "" then
        SlashMoon.UI.Draw.TextShadow(subText, "SlashMoon.Small", sw / 2, y + 82, colors.TextMuted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- === Glow-эффект ===
    if not matTimerGlow:IsError() then
        surface.SetDrawColor(phaseCol.r, phaseCol.g, phaseCol.b, 50)
        surface.SetMaterial(matTimerGlow)
        surface.DrawTexturedRect(sw / 2 - 114, y + 35, 227, 46)
    end
end)

-- ── 3D Рендер Колец Побега (GTA Style) ────────────────────────────────
local oldMarkerMeshes = SlashMoon.Tasks._EscapeMarkerMeshes or {}
for key, meshObject in pairs(oldMarkerMeshes) do
    if meshObject and meshObject.Destroy then meshObject:Destroy() end
    oldMarkerMeshes[key] = nil
end
local markerMeshes = {}
SlashMoon.Tasks._EscapeMarkerMeshes = markerMeshes
local escapeCars = {}
local nextEscapeCarScan = 0

local function BuildMarkerMesh(kind, innerR, outerR, radius, height, segs)
    local key = table.concat({ tostring(kind), tostring(innerR or 0), tostring(outerR or 0), tostring(radius or 0), tostring(height or 0), tostring(segs) }, ":")
    if markerMeshes[key] then return markerMeshes[key] end

    local result = Mesh()
    mesh.Begin(result, MATERIAL_QUADS, segs)
    for i = 0, segs - 1 do
        local a1 = math.rad(i / segs * 360)
        local a2 = math.rad((i + 1) / segs * 360)
        if kind == "ring" then
            mesh.Position(Vector(math.cos(a1) * innerR, math.sin(a1) * innerR, 0)); mesh.AdvanceVertex()
            mesh.Position(Vector(math.cos(a2) * innerR, math.sin(a2) * innerR, 0)); mesh.AdvanceVertex()
            mesh.Position(Vector(math.cos(a2) * outerR, math.sin(a2) * outerR, 0)); mesh.AdvanceVertex()
            mesh.Position(Vector(math.cos(a1) * outerR, math.sin(a1) * outerR, 0)); mesh.AdvanceVertex()
        else
            local x1, y1 = math.cos(a1) * radius, math.sin(a1) * radius
            local x2, y2 = math.cos(a2) * radius, math.sin(a2) * radius
            mesh.Position(Vector(x1, y1, 0)); mesh.AdvanceVertex()
            mesh.Position(Vector(x2, y2, 0)); mesh.AdvanceVertex()
            mesh.Position(Vector(x2, y2, height)); mesh.AdvanceVertex()
            mesh.Position(Vector(x1, y1, height)); mesh.AdvanceVertex()
        end
    end
    mesh.End()
    markerMeshes[key] = result
    return result
end

local function DrawMarkerMesh(meshObject, pos, col, blend)
    if not meshObject then return end
    local matrix = Matrix()
    matrix:SetTranslation(pos)
    cam.PushModelMatrix(matrix)
        render.SetMaterial(MAT_SOLID)
        render.SetColorModulation(col.r / 255, col.g / 255, col.b / 255)
        render.SetBlend(blend)
        meshObject:Draw()
        render.SetBlend(1)
        render.SetColorModulation(1, 1, 1)
    cam.PopModelMatrix()
end

local function DrawGTAMarker(pos, t)
    local R, H = 80, 180
    local p1 = math.sin(t * 2.5) * 0.5 + 0.5
    local p2 = math.sin(t * 4) * 0.5 + 0.5
    local rT = 4 + math.floor(p2 * 3 + 0.5)
    local ring = BuildMarkerMesh("ring", R - rT, R + rT, nil, nil, 48)
    local cylinder = BuildMarkerMesh("cylinder", nil, nil, R, H, 32)
    DrawMarkerMesh(ring, pos + Vector(0, 0, 2), Color(50, 220, 80), (180 + p2 * 70) / 255)
    DrawMarkerMesh(cylinder, pos, Color(50, 220, 80), (65 + p1 * 30) / 255)
end

MODULE:Hook("PostDrawTranslucentRenderables", "fhi_escape_markers_draw", function()
    if phaseState.phase ~= "escape" then return end
    local me = LocalPlayer()
    if not SlashMoon.Tasks.Game.IsSurvivor(me) then return end

    local t = CurTime()

    -- Рисуем 3D маркеры-кольца
    for _, markerPos in ipairs(escapeMarkers) do DrawGTAMarker(markerPos, t) end

    -- Рисуем кольцо вокруг машины эвакуации
    if CurTime() >= nextEscapeCarScan then
        escapeCars = ents.FindByClass("sn_escape_car")
        nextEscapeCarScan = CurTime() + 0.25
    end
    for _, ent in ipairs(escapeCars) do
        if IsValid(ent) then DrawGTAMarker(ent:GetPos(), t) end
    end
end)

MODULE:Hook("ShutDown", "SN_DestroyEscapeMarkerMeshes", function()
    for key, meshObject in pairs(markerMeshes) do
        if meshObject and meshObject.Destroy then meshObject:Destroy() end
        markerMeshes[key] = nil
    end
end)

-- ========================================================
-- СТРЕЛКА-УКАЗАТЕЛЬ НА ПОБЕГ (HUD)
-- Показывает направление и расстояние до ближайшей зоны/машины
-- ========================================================
MODULE:Hook("HUDPaint", "SN_Escape_DirectionArrow", function()
    if phaseState.phase ~= "escape" then return end
    if iEscaped then return end

    local me = LocalPlayer()
    if not IsValid(me) or not me:Alive() then return end
    if not SlashMoon.Tasks.Game.IsSurvivor(me) then return end

    -- Ищем ближайшую цель побега
    local myPos = me:GetPos()
    local nearestPos = nil
    local nearestDist = math.huge

    -- 3D зоны побега
    for _, markerPos in ipairs(escapeMarkers) do
        local dist = myPos:Distance(markerPos)
        if dist < nearestDist then
            nearestDist = dist
            nearestPos = markerPos
        end
    end

    -- Машина эвакуации
    for _, ent in ipairs(ents.FindByClass("sn_escape_car")) do
        if IsValid(ent) then
            local dist = myPos:Distance(ent:GetPos())
            if dist < nearestDist then
                nearestDist = dist
                nearestPos = ent:GetPos()
            end
        end
    end

    if not nearestPos then return end

    local sw, sh = ScrW(), ScrH()

    -- Если цель на экране — рисуем маркер-рамку
    -- Если нет — рисуем стрелку у края экрана
    local screenPos = nearestPos:ToScreen()
    local onScreen = screenPos.visible

    local arrowSize = SlashMoon.UI.Scale(28)
    local distMeters = math.floor(nearestDist / 40) -- Примерная конвертация в "метры"

    if onScreen then
        -- Маркер на экране над целью
        local cx, cy = screenPos.x, screenPos.y
        -- Ограничиваем чтобы не выходило за экран
        cx = math.Clamp(cx, arrowSize, sw - arrowSize)
        cy = math.Clamp(cy, arrowSize, sh - arrowSize)

        -- Пульсация
        local pulse = math.sin(CurTime() * 4) * 0.3 + 0.7

        -- Стрелка вниз (указывает на цель)
        local arrowCol = Color(50, 255, 100, math.floor(255 * pulse))
        surface.SetDrawColor(arrowCol)

        -- Треугольник вниз
        local ax, ay = cx, cy - arrowSize
        surface.DrawRect(ax - 2, ay - arrowSize, 4, arrowSize)
        surface.DrawRect(ax - arrowSize/2, ay - arrowSize/2, arrowSize, 2)

        -- Дистанция
        SlashMoon.UI.Draw.TextShadow(distMeters .. "м", "SlashMoon.Small", cx, cy - arrowSize * 2, Color(255, 255, 255, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    else
        -- Стрелка у края экрана, указывающая направление
        local dir = (nearestPos - myPos)
        dir.z = 0
        dir:Normalize()

        -- Угол направления (в радианах)
        local angle = math.atan2(dir.y, dir.x)

        -- Позиция стрелки на краю экрана
        local edgeDist = SlashMoon.UI.Scale(60)
        local cx = sw / 2 + math.cos(angle) * (sw / 2 - edgeDist)
        local cy = sh / 2 + math.sin(angle) * (sh / 2 - edgeDist)

        -- Ограничиваем
        cx = math.Clamp(cx, edgeDist, sw - edgeDist)
        cy = math.Clamp(cy, edgeDist, sh - edgeDist)

        -- Рисуем стрелку-треугольник
        local pulse = math.sin(CurTime() * 3) * 0.3 + 0.7
        local arrowCol = Color(50, 255, 100, math.floor(220 * pulse))

        -- Круг-фон
        surface.SetDrawColor(0, 0, 0, 150)
        local bgSize = arrowSize + SlashMoon.UI.Scale(8)
        -- Простая круглая подложка (квадрат с бордером)
        surface.DrawRect(cx - bgSize, cy - bgSize, bgSize * 2, bgSize * 2)

        surface.SetDrawColor(arrowCol)
        surface.DrawOutlinedRect(cx - bgSize, cy - bgSize, bgSize * 2, bgSize * 2)

        -- Текст дистанции
        SlashMoon.UI.Draw.TextShadow(distMeters .. "м", "SlashMoon.Header", cx, cy, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        -- Маленькая стрелка (→) рядом
        local arrowX = cx + math.cos(angle) * SlashMoon.UI.Scale(20)
        local arrowY = cy - math.sin(angle) * SlashMoon.UI.Scale(20)
        SlashMoon.UI.Draw.TextShadow("►", "SlashMoon.Small", arrowX, arrowY, arrowCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end)

-- HUD Полоски Побега (3.6 сек удержания)
MODULE:Hook("HUDPaint", "fhi_escape_progress_bar", function()
    if phaseState.phase ~= "escape" or escapeProgress <= 0 or iEscaped then return end
    local me = LocalPlayer()
    if not IsValid(me) or SlashMoon.Tasks.Game.IsAnimatronic(me) or SlashMoon.Tasks.Game.IsSpectator(me) then return end

    local sw = ScrW()
    local W, H = SlashMoon.UI.Scale(320), SlashMoon.UI.Scale(26)
    local x = sw / 2 - W / 2
    local y = ScrH() - SlashMoon.UI.Scale(100)

    surface.SetDrawColor(SlashMoon.UI.Colors.DarkBG)
    surface.DrawRect(x, y, W, H)
    surface.SetDrawColor(50, 220, 80)
    surface.DrawRect(x, y, W * escapeProgress, H)
    surface.SetDrawColor(SlashMoon.UI.Colors.Outline)
    surface.DrawOutlinedRect(x, y, W, H, 1)

    local barText = SlashMoon.Tasks.Lang("sn.escape.bar", math.floor(escapeProgress * 100))
    SlashMoon.UI.Draw.TextShadow(barText, "SlashMoon.PhaseHint", sw / 2, y + H / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

-- ========================================================
-- СЕТЕВЫЕ ПРИЕМНИКИ
-- ========================================================

MODULE:Receive("fh_phase_hud_override", function()
    local isActive = net.ReadBool()
    phaseState.active = isActive
    -- Больше НЕ добавляем свой DrawPhaseTimer!
    -- Вместо этого обновляем SlashMoon.FH.Timer через Think
end)

MODULE:Receive("fh_phase_update", function()
    local previousPhase = phaseState.phase
    phaseState.phase = net.ReadString()
    phaseState.lastUpdateValue = net.ReadFloat()
    phaseState.lastUpdateAt = CurTime()
    if phaseState.phase ~= previousPhase and phaseConfig[phaseState.phase] then
        phaseConfig[phaseState.phase].totalTime = math.max(1, phaseState.lastUpdateValue)
    end

    -- Сразу обновляем SlashMoon.FH.Timer при смене фазы
    UpdateFHTimer()

    if phaseState.phase == "escape" then
        escapeMarkers = {}
        escapeProgress = 0
        iEscaped = false
        for _, v in ipairs(pendingMarkers) do table.insert(escapeMarkers, v) end
        table.Empty(pendingMarkers)
    end
end)

MODULE:Receive("fhi_escape_marker_spawn", function()
    local pos = net.ReadVector()
    if phaseState.phase == "escape" then table.insert(escapeMarkers, pos)
    else table.insert(pendingMarkers, pos) end
end)

MODULE:Receive("fhi_escape_progress", function() escapeProgress = net.ReadFloat() end)

-- Полный сброс состояния побега (конец раунда)
MODULE:Receive("fhi_escape_reset", function()
    escapeMarkers  = {}
    pendingMarkers = {}
    escapeProgress = 0
    iEscaped       = false
end)

-- Постоянное обновление SlashMoon.FH.Timer (чтобы обратный отсчёт тикал)
MODULE:Hook("Think", "SN_Phase_UpdateFHTimer", function()
    if phaseState.active and phaseState.phase ~= "none" then
        UpdateFHTimer()
    end
end)

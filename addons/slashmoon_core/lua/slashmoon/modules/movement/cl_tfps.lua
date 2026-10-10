-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("movement")

-- ============================================================
-- === [ ЧАСТЬ 1: КОНВАРЫ И МЕНЮ НАСТРОЙКИ ДВИЖЕНИЯ ] ===
-- ============================================================

local Movement = SlashMoon.Movement
local UI = SlashMoon.UI

local function cvFloat(name)
    local c = GetConVar(name)
    return c and c:GetFloat() or 0
end
local function cvBool(name)
    local c = GetConVar(name)
    return c and c:GetBool() or false
end

local SURVIVOR_TEAM = TEAM_SURVIVOR or 2700

local function SendCvar(name, val)
    net.Start("FH_MovCfg_SetCvar")
    net.WriteString(name)
    net.WriteString(tostring(val))
    net.SendToServer()
end

local function Round(value, decimals)
    return decimals > 0 and math.Round(value, decimals) or math.Round(value)
end

-- Карточка с ползунком и полем ввода, привязанная к серверному convar
local function MakeSlider(grid, width, label, cvar, min, max, decimals)
    decimals = decimals or 0

    local card = grid:Add("SlashMoon.Panel")
    card:SetSize(width, UI.Scale(78))
    card:DockPadding(UI.Scale(12), UI.Scale(8), UI.Scale(12), UI.Scale(8))

    local top = UI.Create("Container", card)
    top:Dock(TOP)
    top:SetTall(UI.Scale(30))

    local numBox = UI.Create("TextEntry", top)
    numBox:Dock(RIGHT)
    numBox:SetWide(UI.Scale(90))
    numBox:SetFont("SlashMoon.Small")
    numBox:SetNumeric(true)

    local lbl = UI.Create("Label", top)
    lbl:Dock(FILL)
    lbl:SetFont("SlashMoon.Small")
    lbl:SetText(label)

    local bar = UI.Create("SliderBar", card)
    bar:Dock(BOTTOM)
    bar:SetMinMax(min, max)
    bar:SetDecimals(decimals)

    local lastInteract = 0
    local function SetUI(v)
        bar:SetValue(v, true)
        numBox:SetText(tostring(Round(v, decimals)))
    end
    SetUI(cvFloat(cvar))

    bar.OnValueChanged = function(_, v)
        lastInteract = CurTime()
        numBox:SetText(tostring(Round(v, decimals)))
    end
    bar.OnValueReleased = function(_, v)
        lastInteract = CurTime()
        SendCvar(cvar, Round(v, decimals))
    end
    numBox.OnEnter = function(self)
        local v = tonumber(self:GetValue())
        if not v then return end
        lastInteract = CurTime()
        v = math.Clamp(v, min, max)
        SetUI(v)
        SendCvar(cvar, Round(v, decimals))
    end

    -- Подтягиваем реальное значение convar (его мог изменить другой админ)
    card.Think = function()
        if CurTime() - lastInteract < 0.5 or bar.Dragging or numBox:IsEditing() then return end
        local real = cvFloat(cvar)
        if math.abs(real - bar:GetValue()) > (decimals > 0 and 0.01 or 0.5) then SetUI(real) end
    end

    return card
end

-- Переключатель серверного convar
local function MakeToggle(parent, label, cvar)
    local row = UI.Create("SettingRow", parent)
    row:Dock(TOP)
    row:SetTall(UI.Scale(56))
    row:SetTitle(label)

    local toggle = row:SetControl(UI.Create("Toggle"))
    toggle:SetValue(cvBool(cvar), true)
    toggle:SnapAnimation()
    toggle.OnChange = function(_, value)
        toggle.LastClick = CurTime()
        SendCvar(cvar, value and "1" or "0")
    end
    toggle.Think = function(self)
        if CurTime() - (self.LastClick or 0) < 0.5 then return end
        local real = cvBool(cvar)
        if real ~= self:GetValue() then self:SetValue(real, true) end
    end
    return toggle
end

local function Section(parent, title, description)
    local header = UI.Create("Header", parent)
    header:Dock(TOP)
    header:DockMargin(0, UI.Scale(8), 0, UI.Scale(4))
    header:SetText(title)
    if description then header:SetDescription(description) end
    return header
end

local function MakeGrid(parent)
    local grid = UI.Create("Grid", parent)
    grid:Dock(TOP)
    grid:DockMargin(0, 0, 0, UI.Scale(8))
    return grid
end

-- Ширина карточки: две карточки в ряд
local function HalfWidth(scroll)
    return math.floor((scroll:GetWide() - UI.Scale(20)) / 2) - UI.Scale(6)
end

local function NewScroll(content)
    local scroll = UI.Create("Scroll", content)
    scroll:Dock(FILL)
    scroll:InvalidateParent(true)
    return scroll
end

local function BuildAnimTab(content)
    local scroll = NewScroll(content)
    local w = math.floor((scroll:GetWide() - UI.Scale(20)) / 4) - UI.Scale(8)

    for _, anim in ipairs(Movement.AnimDefs or {}) do
        Section(scroll, anim.name, anim.id)
        local grid = MakeGrid(scroll)
        local id = anim.id:gsub("[%.]", "_")
        MakeSlider(grid, w, "Ходьба", "fh_mov_" .. id .. "_walk", 0, 800)
        MakeSlider(grid, w, "Бег", "fh_mov_" .. id .. "_run", 0, 1200)
        MakeSlider(grid, w, "Присед", "fh_mov_" .. id .. "_duck", 0, 600)
        MakeSlider(grid, w, "Прыжок", "fh_mov_" .. id .. "_jump", 0, 800)
    end
end

local FATIGUE_FX = {
    { toggle = "fh_fx_camera_sway", label = "Шатание камеры при усталости", sliders = { { "Сила шатания", "fh_fx_sway_strength", 0, 5.0, 2 }, { "Скорость шатания", "fh_fx_sway_speed", 0.1, 6.0, 2 } } },
    { toggle = "fh_fx_darkness", label = "Затемнение экрана", sliders = { { "Макс. затемнение", "fh_fx_max_darkness", 0, 0.8, 2 } } },
    { toggle = "fh_fx_frozen_frames", label = "Застывшие кадры (призраки)", sliders = { { "Прозрачность призрака", "fh_fx_frozen_alpha", 0, 0.8, 2 }, { "Скорость угасания", "fh_fx_frozen_decay", 0.05, 2.0, 2 } } },
    { toggle = "fh_fx_blur", label = "Размытие движения", sliders = { { "Интенсивность", "fh_fx_blur_intensity", 0, 1.0, 2 } } },
    { toggle = "fh_fx_mouse_drift", label = "Уход курсора", sliders = { { "Радиус ухода (градусы)", "fh_fx_drift_radius", 0, 60, 0 } } },
    { toggle = "fh_fx_color_desat", label = "Обесцвечивание", sliders = { { "Сила обесцвечивания", "fh_fx_desat_amount", 0, 1.0, 2 } } },
    { toggle = "fh_fx_gasp_sound", label = "Звук одышки", sliders = { { "Порог стамины (звук)", "fh_fx_gasp_threshold", 0, 0.6, 2 } } },
}

local function BuildSurvTab(content)
    local scroll = NewScroll(content)
    local hw = HalfWidth(scroll)

    Section(scroll, "Базовое движение")
    local grid = MakeGrid(scroll)
    MakeSlider(grid, hw, "Ходьба", "fh_surv_walk", 50, 500)
    MakeSlider(grid, hw, "Бег", "fh_surv_run", 50, 700)
    MakeSlider(grid, hw, "Присед", "fh_surv_duck", 0, 400)
    MakeSlider(grid, hw, "Прыжок", "fh_surv_jump", 0, 600)

    Section(scroll, "Стамина (bhop)")
    MakeToggle(scroll, "Стамина включена", "fh_stam_enabled")
    grid = MakeGrid(scroll)
    MakeSlider(grid, hw, "Интервал слива стамины (сек)", "fh_stam_drain_speed", 0.005, 2.0, 3)
    MakeSlider(grid, hw, "Задержка регена (сек)", "fh_stam_regen_delay", 0.0, 5.0, 1)
    MakeSlider(grid, hw, "Восстановление в сек", "fh_stam_regen_rate", 0.01, 1.0, 2)
    MakeSlider(grid, hw, "Порог эффектов (0-1)", "fh_stam_effect_threshold", 0.01, 0.5, 2)
    MakeSlider(grid, hw, "Макс. замедление (0-1)", "fh_stam_max_slow", 0.3, 1.0, 2)
    MakeSlider(grid, hw, "Мин. скорость для bhop", "fh_stam_bhop_min_speed", 100, 700)

    Section(scroll, "Камера: наклон и покачивание")
    MakeToggle(scroll, "Наклон камеры при страфе", "fh_fx_tilt")
    grid = MakeGrid(scroll)
    MakeSlider(grid, hw, "Интенсивность наклона", "fh_fx_tilt_intensity", 0, 10, 1)
    MakeSlider(grid, hw, "Плавность наклона", "fh_fx_tilt_smoothness", 1, 20, 1)
    MakeToggle(scroll, "Покачивание камеры (боббинг)", "fh_fx_camera_bob")
    grid = MakeGrid(scroll)
    MakeSlider(grid, hw, "Скорость (ходьба)", "fh_fx_bob_speed_walk", 1, 14, 1)
    MakeSlider(grid, hw, "Скорость (бег)", "fh_fx_bob_speed_run", 1, 16, 1)
    MakeSlider(grid, hw, "Интенсивность (ходьба)", "fh_fx_bob_intensity", 0, 2.0, 2)
    MakeSlider(grid, hw, "Интенсивность (бег)", "fh_fx_bob_intensity_run", 0, 2.0, 2)

    Section(scroll, "Эффекты усталости")
    for _, fx in ipairs(FATIGUE_FX) do
        MakeToggle(scroll, fx.label, fx.toggle)
        grid = MakeGrid(scroll)
        for _, sl in ipairs(fx.sliders) do
            MakeSlider(grid, hw, sl[1], sl[2], sl[3], sl[4], sl[5])
        end
    end
end

local function BuildFlashlightTab(content)
    local scroll = NewScroll(content)
    local hw = HalfWidth(scroll)

    Section(scroll, "Фонарик")
    local grid = MakeGrid(scroll)
    MakeSlider(grid, hw, "Яркость", "fh_fl_brightness", 0.1, 3.0, 2)
    MakeSlider(grid, hw, "Угол конуса (FOV)", "fh_fl_fov", 10, 120, 0)
    MakeSlider(grid, hw, "Дальность луча", "fh_fl_distance", 100, 2000, 0)
    MakeSlider(grid, hw, "Дальность чужих фонариков", "fh_fl_render_dist", 200, 3000, 0)
    MakeSlider(grid, hw, "Плавность движения", "fh_fl_smooth_speed", 1, 30, 1)
    MakeSlider(grid, hw, "Скорость поворота", "fh_fl_rot_speed", 1, 30, 1)
    MakeSlider(grid, hw, "Сила покачивания", "fh_fl_sway", 0, 3.0, 2)
    MakeSlider(grid, hw, "Скорость покачивания", "fh_fl_bob_speed", 0.1, 5.0, 2)

    Section(scroll, "Помехи Shadow Freddy")
    grid = MakeGrid(scroll)
    MakeSlider(grid, hw, "Радиус помех", "fh_fl_sfr_radius", 200, 3000, 0)
end

local function BuildFXTab(content)
    local scroll = NewScroll(content)
    local hw = HalfWidth(scroll)

    Section(scroll, "Адреналин")
    local grid = MakeGrid(scroll)
    MakeSlider(grid, hw, "Усиление FOV", "fh_adr_fov", 0, 40, 0)
    MakeSlider(grid, hw, "Насыщенность цвета", "fh_adr_saturation", 1.0, 3.0, 2)
    MakeSlider(grid, hw, "Скорость угасания", "fh_adr_fade_speed", 0.5, 10, 1)
    MakeSlider(grid, hw, "DSP эффект", "fh_adr_dsp", 0, 60, 0)

    Section(scroll, "Дефибриллятор (возрождение)")
    grid = MakeGrid(scroll)
    MakeSlider(grid, hw, "Длительность эффекта", "fh_dfb_duration", 0.5, 10, 1)
    MakeSlider(grid, hw, "DSP эффект", "fh_dfb_dsp", 0, 60, 0)
    MakeSlider(grid, hw, "Яркость вспышки", "fh_dfb_brightness", -1, 0, 2)
    MakeSlider(grid, hw, "Контраст", "fh_dfb_contrast", 1, 3, 2)
    MakeSlider(grid, hw, "Bloom", "fh_dfb_bloom", 0, 6, 1)
    MakeSlider(grid, hw, "Длительность вспышки", "fh_dfb_flash", 0.1, 1.0, 2)

    Section(scroll, "Эффекты низкого HP")
    grid = MakeGrid(scroll)
    MakeSlider(grid, hw, "HP начала эффекта", "fh_hp_start_fade", 10, 100, 0)
    MakeSlider(grid, hw, "HP критический", "fh_hp_critical", 5, 80, 0)
    MakeSlider(grid, hw, "Мин. насыщенность", "fh_hp_min_sat", 0, 1.0, 2)
    MakeSlider(grid, hw, "Макс. затемнение", "fh_hp_max_dark", 0, 0.5, 3)
    MakeSlider(grid, hw, "Размытие", "fh_hp_blur", 0, 0.5, 2)
    MakeSlider(grid, hw, "Дрейф (pitch)", "fh_hp_drift_pitch", 0, 5.0, 2)
end

local lastTab = "Аниматроники"

function Movement.OpenMenu()
    if IsValid(Movement.Frame) then
        Movement.Frame:Close()
        return
    end

    local w, h = UI.WindowSize(0.6, 0.75, 1400, 950)
    local frame = UI.Create("Frame")
    frame:SetSize(w, h)
    frame:Center()
    frame:SetHeader("НАСТРОЙКА ДВИЖЕНИЯ И ЭФФЕКТОВ", "только для администрации")
    frame:SetBlur(false)
    Movement.Frame = frame

    local tabs = UI.Create("Tabs", frame)
    tabs:Dock(FILL)
    tabs:InvalidateParent(true)
    tabs:AddTab("Аниматроники", BuildAnimTab)
    tabs:AddTab("Выжившие", BuildSurvTab)
    tabs:AddTab("Фонарик", BuildFlashlightTab)
    tabs:AddTab("Спецэффекты", BuildFXTab)
    tabs:SetActiveTab(lastTab)
    tabs.OnTabChanged = function(_, name) lastTab = name end
end

MODULE:Command("fh_movement_menu", function()
    if not SlashMoon.Admin.HasPermission(LocalPlayer(), "slashmoon_movement") then return end
    Movement.OpenMenu()
end)


MODULE:OnDisabled(function()
    if IsValid(Movement.Frame) then Movement.Frame:Remove() end
end)


-- ============================================================
-- === [ ЧАСТЬ 2: РЕАЛИСТИЧНАЯ КАМЕРА ВЫЖИВШИХ (True FPS) ] ===
-- ============================================================

local isAllow = false
local ViewOffsetUp, ViewOffsetForward = 0, 1.8 
local RollDependency = 0.1
local CurView = nil
local traceHit = false
local eyeAtt

local wasAlive = true
local justRespawned = false
local respawnGraceTime = 0
local RESPAWN_GRACE_DURATION = 1.5 

local d_weapon = { ["gmod_tool"] = true, ["weapon_physgun"] = true, ["gmod_camera"] = true }

local VIEWMODEL_WEAPONS = {
    ["weapon_cam"] = true,
    ["weapon_mask"] = true,
    ["weapon_killmask"] = true,
    ["weapon_crapvidcam"] = true,
    ["sn_investigation_tablet"] = true,
    ["sn_corpse_scanner"] = true,
    ["weapon_taser"] = true,
    ["weapon_killer_axe"] = true,
    ["weapon_gascan"] = true,
    ["weapon_fh_medkit"] = true,
    ["sn_animcam_tablet"] = true,
}

local EXCLUDED_MODELS = {
    ["models/bear_v1/bear_v1.mdl"] = true,
}

local function allow()
    local client = LocalPlayer()
    if not IsValid(client) then return false end
    if client:Team() ~= SURVIVOR_TEAM then return false end

    if client:GetMoveType() == MOVETYPE_NOCLIP then return false end
    if not client:Alive() then return false end
    if client:IsPlayingTaunt() then return false end
    if client:InVehicle() then return false end

    local weapon = client:GetActiveWeapon()
    if IsValid(weapon) and d_weapon[string.lower(weapon:GetClass())] then return false end

    local mdl = client:GetModel()
    if EXCLUDED_MODELS[mdl] then return false end

    return true
end

local function ShouldShowViewModel(client)
    if not IsValid(client) then return false end
    local wep = client:GetActiveWeapon()
    return IsValid(wep) and VIEWMODEL_WEAPONS[string.lower(wep:GetClass())] or false
end

MODULE:Hook("ShouldDrawLocalPlayer", "FH_SurvivorFPS_DrawPlayer", function(client)
    if not isAllow then return end
    if traceHit then return false end
    if ShouldShowViewModel(client) then
        return false
    end
    return true 
end)

local bCloserLook = false
local fovShift = 0
local bobTime, bobAmount, leanAmount, mouseLeanAmount = 0, 0, 0, 0
local lastMouseX = 0
local wasInAir, shakeAmount = false, 0

local function CalcViewHandler(client, pos, angles, fov)
    local FT = FrameTime()
    local eyeAngles = client:EyeAngles()

    local attID = client:LookupAttachment("eyes")
    if attID <= 0 then return end
    eyeAtt = client:GetAttachment(attID)

    if (traceHit and not client:InVehicle()) or not eyeAtt then return end

    local camSmooth = 15
    if not CurView then
        CurView = angles
    else
        CurView = LerpAngle(FT * camSmooth, CurView, angles + Angle(0, 0, eyeAtt.Ang.r * RollDependency))
    end

    local velocity = client:GetVelocity():Length2D()
    local isMoving = velocity > 10
    local isSprinting = client:KeyDown(IN_SPEED)

    local bobEnabled = cvBool("fh_fx_camera_bob")
    local bobIntWalk = cvFloat("fh_fx_bob_intensity")
    local bobIntRun = cvFloat("fh_fx_bob_intensity_run")
    local bobSpdWalk = cvFloat("fh_fx_bob_speed_walk")
    local bobSpdRun = cvFloat("fh_fx_bob_speed_run")

    local currentBobInt = isSprinting and bobIntRun or bobIntWalk
    local currentBobSpd = isSprinting and bobSpdRun or bobSpdWalk

    if isMoving and bobEnabled and currentBobInt > 0 then
        bobAmount = Lerp(0.1 * currentBobInt, bobAmount, math.Clamp(velocity / 200, 0, 1))
        bobTime = bobTime + FT * currentBobSpd
    else
        bobAmount = 0
    end

    local bobOffset = bobEnabled and Vector(math.sin(bobTime * 0.5) * bobAmount * 0.5, math.sin(bobTime) * bobAmount * 0.3, math.sin(bobTime * 0.5) * bobAmount * 0.5) or Vector(0, 0, 0)

    local tiltEnabled = cvBool("fh_fx_tilt")
    local tiltInt = cvFloat("fh_fx_tilt_intensity")
    local tiltSm = cvFloat("fh_fx_tilt_smoothness")

    local leanTarget = 0
    if tiltEnabled then
        if client:KeyDown(IN_MOVELEFT) then leanTarget = tiltInt
        elseif client:KeyDown(IN_MOVERIGHT) then leanTarget = -tiltInt end
    end

    local leanSpeedFactor = math.Clamp(velocity / 200, 0, 1)
    leanAmount = tiltEnabled and Lerp(FT * tiltSm, leanAmount, leanTarget * leanSpeedFactor) or 0

    local mouseDeltaX = eyeAngles.y - lastMouseX
    local delta = math.NormalizeAngle(mouseDeltaX)
    lastMouseX = eyeAngles.y

    local targetLeanAmount = delta * (tiltInt * 0.25)
    mouseLeanAmount = tiltEnabled and Lerp(FT * tiltSm, mouseLeanAmount, targetLeanAmount) or 0
    RollDependency = bobEnabled and Lerp(FT * 15 * currentBobInt, RollDependency, 0.05) or 0

    local waterLevel = client:WaterLevel()
    local isInAir = not client:IsOnGround()

    if isInAir and waterLevel < 1 then
        shakeAmount = currentBobInt > 0 and math.sin(RealTime() * 5) * 0.1 or 0
    elseif not isInAir and wasInAir then
        shakeAmount = currentBobInt > 0 and math.random() * 0.2 or 0
    end
    wasInAir = isInAir
    shakeAmount = Lerp(FT * 2, shakeAmount, 0)

    local shakeOffset = Vector(shakeAmount, shakeAmount, shakeAmount)
    local shakeAngle = Angle(shakeAmount, shakeAmount, 0)

    local swayEnabled = cvBool("fh_fx_camera_sway")
    local swayStr = cvFloat("fh_fx_sway_strength")
    local swaySpd = cvFloat("fh_fx_sway_speed")
    local stam = SlashMoon.Movement.GetStamina and SlashMoon.Movement.GetStamina() or 1.0
    local swayAngle = Angle(0, 0, 0)

    if swayEnabled and stam < 0.6 and not client:InVehicle() then
        local mult = (0.6 - stam) * 2
        swayAngle = Angle( math.sin(RealTime() * swaySpd) * swayStr * mult, math.cos(RealTime() * swaySpd * 0.8) * swayStr * mult, 0 )
    end

    -- =========================================================
    -- === ПОЛНОЦЕННЫЙ TRUE FPS (Камера строго на голове)
    -- =========================================================
    local showVM = ShouldShowViewModel(client)

    -- ИСПРАВЛЕНИЕ 1: Считаем множитель размера по СТАТИЧНОЙ высоте игрока (GetViewOffset).
    -- Теперь камера не будет пытаться "вдавить" себя сильнее, когда ты просто опускаешь голову!
    local standOffset = client:GetViewOffset().z
    local sizeMult = math.Clamp(64 / math.max(standOffset, 10), 1.0, 2.5)

    local pitch = eyeAngles.p
    
    local targetForward = showVM and (4.0 * sizeMult) or (1.8 * sizeMult) 
    local targetUp = 0.0

    if pitch > 0 then
        local frac = pitch / 90
        targetUp = Lerp(frac, 0.0, 3.5 * sizeMult)
    end

    ViewOffsetForward = Lerp(FT * 10, ViewOffsetForward, targetForward)
    ViewOffsetUp = Lerp(FT * 10, ViewOffsetUp, targetUp)

    local pushDir
    if showVM then
        pushDir = Angle(0, eyeAngles.y, 0):Forward()
    else
        pushDir = Angle(pitch * 0.4, eyeAngles.y, 0):Forward()
    end

    local baseOffset = pushDir * ViewOffsetForward + Vector(0, 0, ViewOffsetUp)
    local viewOrigin = eyeAtt.Pos + baseOffset + bobOffset + shakeOffset
    -- =========================================================

    local shift = velocity * 0.035
    local value = 0
    if client:KeyDown(IN_FORWARD) then value = shift
    elseif client:KeyDown(IN_BACK) then value = -shift end
    value = math.Clamp(value, -8, 8)

    if not vgui.CursorVisible() and client:KeyDown(IN_ZOOM) then
        value = value - 10
        bCloserLook = true
    end

    fovShift = Lerp(FT * (bCloserLook and 5 or 3), fovShift, value)

    local view = {
        origin = viewOrigin,
        angles = CurView + Angle(0, 0, leanAmount + mouseLeanAmount) + shakeAngle + swayAngle,
        fov = fov + fovShift,
        drawviewer = not showVM
    }

    if not justRespawned or CurTime() - respawnGraceTime >= RESPAWN_GRACE_DURATION then
        if justRespawned then justRespawned = false end
        view.znear = showVM and 2.0 or 4.6
    end

    client.FH_CameraPos = view.origin
    client.FH_CameraAng = view.angles

    return view
end

MODULE:Hook("CalcView", "FH_SurvivorFPS_CalcView", function(client, pos, angles, fov)
    bCloserLook = false
    if not isAllow then return end
    local view = CalcViewHandler(client, pos, angles, fov)
    if not view then return end
    return view
end)

MODULE:Hook("Think", "FH_SurvivorFPS_Think", function()
    local client = LocalPlayer()
    if IsValid(client) then
        local aliveNow = client:Alive()
        if wasAlive == false and aliveNow then
            CurView = nil
            ViewOffsetUp = 0
            ViewOffsetForward = 1.8
            RollDependency = 0.1
            bobTime, bobAmount, leanAmount, mouseLeanAmount = 0, 0, 0, 0
            lastMouseX = 0
            wasInAir, shakeAmount = false, 0
            fovShift = 0
            justRespawned = true
            respawnGraceTime = CurTime()
        end
        wasAlive = aliveNow
    end

    isAllow = allow()
    if not isAllow then return end

    if eyeAtt then
        local tr = util.TraceLine({ 
            start = eyeAtt.Pos, 
            endpos = eyeAtt.Pos + client:EyeAngles():Forward() * 1, 
            filter = client 
        })
        traceHit = tr.Hit and math.abs(tr.HitNormal.z) < 0.7
    end
end)

local vignitte_a = 0

MODULE:Hook("HUDPaint", "FH_SurvivorFPS_HUDPaint", function()
    if not isAllow then return end
    if (bCloserLook and vignitte_a < 200) or (not bCloserLook and vignitte_a > 0.1) then
        vignitte_a = Lerp(FrameTime() * 6, vignitte_a, bCloserLook and 220 or 0)
    end
    if vignitte_a > 0.5 then
        surface.SetDrawColor(0, 0, 0, vignitte_a)
    end
end)

MODULE:Hook("CreateMove", "FH_SurvivorFPS_CreateMove", function(ucmd)
    if not isAllow then return end
    local eyeAng = ucmd:GetViewAngles()
    ucmd:SetViewAngles(Angle(math.Clamp(eyeAng.p, -90, 75), eyeAng.y, eyeAng.r))
end)

MODULE:Command("fh_camerafix", function(client)
    local ang = client:EyeAngles()
    client:SetEyeAngles(Angle(ang.p, ang.y, 0))
end)

local cl_vm_lastAng = Angle(0, 0, 0)
local cl_vm_swayX, cl_vm_swayY = 0, 0
local cl_vm_strafeRoll = 0

MODULE:Hook("CalcViewModelView", "FH_SurvivorFPS_ViewModel", function(wep, vm, oldPos, oldAng, pos, ang)
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    if not isAllow then
        if IsValid(vm) then
            local mat = Matrix()
            mat:Scale(Vector(1, 1, 1))
            vm:EnableMatrix("RenderMultiply", mat)
        end
        return
    end

    -- 1. Считаем масштаб (игнорируя хитбокс)
    local _, hullMax = ply:GetHull()
    local baseHeight = hullMax.z or 72.0
    local sizeRatio = baseHeight / 72.0
    local finalScale = math.Clamp(ply:GetModelScale() * sizeRatio, 0.1, 5.0)

    -- 2. Забираем базовую физику GMod (сохраняет дефолтную тряску шагов и отдачу!)
    local localPos, localAng = WorldToLocal(pos, ang, oldPos, oldAng)
    if ply.FH_CameraPos and ply.FH_CameraAng then
        pos, ang = LocalToWorld(localPos, localAng, ply.FH_CameraPos, ply.FH_CameraAng)
    end

    -- ========================================================
    -- 3. КАСТОМНАЯ ПРОЦЕДУРНАЯ ИНЕРЦИЯ (Мощная)
    -- ========================================================
    local FT = FrameTime()
    local curAng = ply:EyeAngles()
    local speed = ply:GetVelocity():Length2D()
    
    -- Защита прицеливания (отключаем инерцию в прицеле, чтобы метко стрелять)
    local defaultFOV = GetConVar("fov_desired") and GetConVar("fov_desired"):GetFloat() or 90
    local isAiming = (ply:GetFOV() < (defaultFOV - 5))
    local physMult = isAiming and 0.1 or 1.0

    -- А. ИНЕРЦИЯ (Отставание оружия при поворотах)
    local angDelta = Angle(curAng.p - cl_vm_lastAng.p, curAng.y - cl_vm_lastAng.y, 0)
    angDelta:Normalize()
    cl_vm_lastAng = curAng

    -- Сделано еще более тяжелым: расширены лимиты до 30, возврат стал чуть медленнее (FT * 4)
    cl_vm_swayX = Lerp(FT * 2, cl_vm_swayX, math.Clamp(angDelta.y, -200, 200))
    cl_vm_swayY = Lerp(FT * 2, cl_vm_swayY, math.Clamp(angDelta.p, -200, 200))

    -- Б. НАКЛОН ПРИ СТРЕЙФЕ (Добавляет веса при ходьбе вбок)
    local targetRoll = 0
    if ply:KeyDown(IN_MOVELEFT) then targetRoll = -6
    elseif ply:KeyDown(IN_MOVERIGHT) then targetRoll = 6 end
    cl_vm_strafeRoll = Lerp(FT * 2, cl_vm_strafeRoll, targetRoll * math.Clamp(speed/100, 0, 1))

    -- В. ПРИМЕНЯЕМ ФИЗИКУ К ОРУЖИЮ
    local appliedSwayX = cl_vm_swayX * physMult
    local appliedSwayY = cl_vm_swayY * physMult

    -- Позиция: Оружие заметно "плавает" в руках при развороте
    pos = pos + ang:Right() * (appliedSwayX * 1) * finalScale
    pos = pos - ang:Up() * (appliedSwayY * 1) * finalScale
    pos = pos + ang:Forward() * (math.abs(appliedSwayY) * -1) * finalScale -- Слегка вжимается при кивке

    -- Углы: Очень сильная инерция ствола (увеличено до 2.0)
    ang:RotateAroundAxis(ang:Up(), appliedSwayX * 2.0)
    ang:RotateAroundAxis(ang:Right(), -appliedSwayY * 2.0)
    ang:RotateAroundAxis(ang:Forward(), appliedSwayX * 1.0 + (cl_vm_strafeRoll * physMult))
    -- ========================================================

    -- 4. Базовые корректирующие сдвиги
    local forwardShift = 2.0 * finalScale
    local downShift = 2.0 * finalScale 
    
    if finalScale < 0.9 then
        local extraDown = (1.0 - finalScale) * 15
        downShift = downShift + extraDown
    elseif finalScale > 1.1 then
        local extraForward = (finalScale - 1.0) * 12.0
        local extraDown = (finalScale - 1.0) * 5.0
        forwardShift = forwardShift + extraForward
        downShift = downShift + extraDown
    end

    pos = pos + ang:Forward() * forwardShift
    pos = pos - ang:Up() * downShift

    -- 5. Масштабируем визуально
    if IsValid(vm) then
        local mat = Matrix()
        mat:Scale(Vector(finalScale, finalScale, finalScale))
        vm:EnableMatrix("RenderMultiply", mat)
    end

    return pos, ang
end)
-- ============================================================
-- === [ ЧАСТЬ 3: DEBUG HUD (Только для Админов) ] ===
-- ============================================================

local stamDebugEnabled = false

MODULE:Command("fh_stam_debug", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    if not SlashMoon.Admin.HasPermission(ply, "slashmoon_movement") then return end
    stamDebugEnabled = not stamDebugEnabled
    chat.AddText(Color(100, 200, 100), "[MovConfig] Stamina HUD: " .. (stamDebugEnabled and "ON" or "OFF"))
end)

MODULE:Hook("HUDPaint", "FH_StamDebugHUD", function()
    if not stamDebugEnabled then return end

    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end
    if not SlashMoon.Admin.HasPermission(ply, "slashmoon_movement") then return end

    local stam    = SlashMoon.Movement.GetStamina and SlashMoon.Movement.GetStamina() or 1.0
    local fatigue = SlashMoon.Movement.GetFatigue and SlashMoon.Movement.GetFatigue() or 0

    local x, y, w, h, pad = 20, ScrH() - 160, 220, 128, 8

    draw.RoundedBox(6, x, y, w, h, Color(0, 0, 0, 160))
    draw.SimpleText("STAMINA DEBUG", "DermaDefaultBold", x + pad, y + pad, Color(255, 200, 50), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    local barW = w - pad * 2
    local stamPct = math.Clamp(stam, 0, 1)
    local barColor = Color(math.floor(255 * (1 - stamPct)), math.floor(255 * stamPct), 40)
    
    local by = y + 30
    draw.RoundedBox(4, x + pad, by, barW, 14, Color(40, 40, 40, 200))
    draw.RoundedBox(4, x + pad, by, math.floor(barW * stamPct), 14, barColor)
    draw.SimpleText(string.format("Stamina: %.0f%%", stamPct * 100), "DermaDefault", x + pad, by + 16, Color(220, 220, 220), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    local fy = by + 34
    draw.RoundedBox(4, x + pad, fy, barW, 14, Color(40, 40, 40, 200))
    draw.RoundedBox(4, x + pad, fy, math.floor(barW * fatigue), 14, Color(180, 80, 255))
    draw.SimpleText(string.format("Fatigue:  %.0f%%", fatigue * 100), "DermaDefault", x + pad, fy + 16, Color(220, 220, 220), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    local drainInterval = math.max(cvFloat("fh_stam_drain_speed") or 0.05, 0.005)
    local unitsPerSec   = math.floor(1 / drainInterval)
    local threshold = (GetConVar("fh_stam_effect_threshold") and GetConVar("fh_stam_effect_threshold"):GetFloat() or 0.25) * 100
    local maxSlow   = (GetConVar("fh_stam_max_slow") and GetConVar("fh_stam_max_slow"):GetFloat() or 0.50) * 100
    
    draw.SimpleText(string.format("Drain: %d ед/сек  (%.3f сек/ед)", unitsPerSec, drainInterval), "DermaDefault", x + pad, fy + 32, Color(180, 180, 180), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    draw.SimpleText(string.format("Порог: %.0f%%   Макс.замедл: -%.0f%%", threshold, maxSlow), "DermaDefault", x + pad, fy + 48, Color(180, 180, 180), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
end)


-- ============================================================
-- === [ ЧАСТЬ 4: НОГИ ОТ ПЕРВОГО ЛИЦА (При кастомном оружии) ] ===
-- ============================================================

local hiddenBones = {
    "ValveBiped.Bip01_Head1", "ValveBiped.Bip01_Neck1", "ValveBiped.Bip01_Spine4", "ValveBiped.Bip01_Spine2",
    "ValveBiped.Bip01_L_Hand", "ValveBiped.Bip01_L_Forearm", "ValveBiped.Bip01_L_Upperarm", "ValveBiped.Bip01_L_Clavicle",
    "ValveBiped.Bip01_R_Hand", "ValveBiped.Bip01_R_Forearm", "ValveBiped.Bip01_R_Upperarm", "ValveBiped.Bip01_R_Clavicle",
    "ValveBiped.Bip01_L_Finger4", "ValveBiped.Bip01_L_Finger41", "ValveBiped.Bip01_L_Finger42",
    "ValveBiped.Bip01_L_Finger3", "ValveBiped.Bip01_L_Finger31", "ValveBiped.Bip01_L_Finger32",
    "ValveBiped.Bip01_L_Finger2", "ValveBiped.Bip01_L_Finger21", "ValveBiped.Bip01_L_Finger22",
    "ValveBiped.Bip01_L_Finger1", "ValveBiped.Bip01_L_Finger11", "ValveBiped.Bip01_L_Finger12",
    "ValveBiped.Bip01_L_Finger0", "ValveBiped.Bip01_L_Finger01", "ValveBiped.Bip01_L_Finger02",
    "ValveBiped.Bip01_R_Finger4", "ValveBiped.Bip01_R_Finger41", "ValveBiped.Bip01_R_Finger42",
    "ValveBiped.Bip01_R_Finger3", "ValveBiped.Bip01_R_Finger31", "ValveBiped.Bip01_R_Finger32",
    "ValveBiped.Bip01_R_Finger2", "ValveBiped.Bip01_R_Finger21", "ValveBiped.Bip01_R_Finger22",
    "ValveBiped.Bip01_R_Finger1", "ValveBiped.Bip01_R_Finger11", "ValveBiped.Bip01_R_Finger12",
    "ValveBiped.Bip01_R_Finger0", "ValveBiped.Bip01_R_Finger01", "ValveBiped.Bip01_R_Finger02"
}

local legOffset = Vector(0, -100, 0)
local legScale = Vector(0, 0, 0) -- Полностью сжимаем кости верха тела, чтобы они точно не торчали

local function SpawnLegs(client)
    if IsValid(client.fh_legs) then
        client.fh_legs:Remove()
    end

    client.fh_legs = ClientsideModel(client:GetModel(), RENDERGROUP_VIEWMODEL)
    local legs = client.fh_legs

    if IsValid(legs) then
        for _, v in ipairs(hiddenBones) do
            local bone = legs:LookupBone(v)
            if bone and bone >= 0 then
                legs:ManipulateBonePosition(bone, legOffset)
                legs:ManipulateBoneAngles(bone, angle_zero)
                legs:ManipulateBoneScale(bone, legScale)
            end
        end

        legs:SetNoDraw(true)
        legs:SetIK(true)
    end
end

MODULE:Hook("RenderScreenspaceEffects", "FH_SurvivorFPS_LegsDraw", function()
    local client = LocalPlayer()
    
    -- Ноги рисуются ТОЛЬКО если активен True FPS скрипт И мы держим Viewmodel оружие
    -- (Так как при обычном оружии рисуется полноценное тело от 3-го лица)
    if not isAllow or not ShouldShowViewModel(client) then 
        if IsValid(client.fh_legs) then
            client.fh_legs:Remove()
            client.fh_legs = nil
        end
        return 
    end

    local angs = client:EyeAngles()
    if angs.p < 0 then return end -- Не рисуем, если игрок смотрит высоко вверх

    cam.Start3D(EyePos(), EyeAngles())
        if not IsValid(client.fh_legs) or client.fh_legs:GetModel() ~= client:GetModel() then
            SpawnLegs(client)
        end

        local legs = client.fh_legs
        if IsValid(legs) then
            local real_time = RealTime()

            angs.p = 0
            angs.r = 0

            local radAngle = math.rad(angs.y)
            local offset = 0
            local origin = client:GetPos()

            origin.x = origin.x + math.cos(radAngle) * offset
            origin.y = origin.y + math.sin(radAngle) * offset

            legs:SetPoseParameter("move_yaw", 360 * client:GetPoseParameter("move_yaw") - 180)
            legs:SetPoseParameter("move_x", client:GetPoseParameter("move_x") * 2 - 1)
            legs:SetPoseParameter("move_y", client:GetPoseParameter("move_y") * 2 - 1)
            legs:SetPoseParameter("body_yaw", (client:GetPoseParameter("body_yaw") * 180) - 90)
            legs:SetPoseParameter("spine_yaw", (client:GetPoseParameter("spine_yaw") * 180) - 90)

            legs:SetRenderMode(client:GetRenderMode())
            legs:SetMaterial(client:GetMaterial())
            legs:SetSequence(client:GetSequence())
            legs:SetColor(client:GetColor())
            
            -- Синхронизируем скины и бодигруппы (чтобы на ногах была правильная одежда)
            legs:SetSkin(client:GetSkin())
            for i = 0, client:GetNumBodyGroups() - 1 do
                legs:SetBodygroup(i, client:GetBodygroup(i))
            end

            legs:FrameAdvance(real_time - (legs.last_draw or real_time))
            legs:SetPlaybackRate(client:GetPlaybackRate())
            legs:SetRenderOrigin(origin)
            legs:SetRenderAngles(angs)
            legs:DrawModel()

            legs.last_draw = real_time
        end
    cam.End3D()
end)

MODULE:Hook("OnReloaded", "FH_SurvivorFPS_ResetLegs", function()
    if IsValid(LocalPlayer()) and IsValid(LocalPlayer().fh_legs) then
        LocalPlayer().fh_legs:Remove()
    end
end)
-- ============================================================
-- === [ ЧАСТЬ 5: 3D ПРОЕКЦИОННЫЙ ПРИЦЕЛ (TRUE CROSSHAIR) ] ===
-- ============================================================

MODULE:Hook("HUDShouldDraw", "FH_SurvivorFPS_HideDefaultCrosshair", function(name)
    if name == "CHudCrosshair" and isAllow then return false end
end)

MODULE:Hook("HUDPaint", "FH_SurvivorFPS_TrueCrosshair", function()
    if not isAllow then return end

    local ply = LocalPlayer()
    local wep = ply:GetActiveWeapon()

    if not IsValid(wep) then return end
    
    local wepClass = wep:GetClass()

    if wepClass == "sn_empty_hands" then
        local cv = GetConVar("emptyhands_showcrosshair")
        if cv and not cv:GetBool() then return end 
    else
        if wep.DrawCrosshair == false then return end
        if wepClass == "gmod_camera" then return end
    end

    local startPos = ply:GetShootPos()
    local aimVec = ply:GetAimVector()

    local tr = util.TraceLine({
        start = startPos,
        endpos = startPos + (aimVec * 10000),
        filter = ply,
        mask = MASK_SHOT
    })

    local screenPos = tr.HitPos:ToScreen()
    if not screenPos.visible then return end

    local x, y = screenPos.x, screenPos.y

    -- Читаем настройки из меню
    local cr = GetConVar("sn_crosshair_r") and GetConVar("sn_crosshair_r"):GetInt() or 255
    local cg = GetConVar("sn_crosshair_g") and GetConVar("sn_crosshair_g"):GetInt() or 255
    local cb = GetConVar("sn_crosshair_b") and GetConVar("sn_crosshair_b"):GetInt() or 255
    local ca = GetConVar("sn_crosshair_a") and GetConVar("sn_crosshair_a"):GetInt() or 200
    
    local len = GetConVar("sn_crosshair_size") and GetConVar("sn_crosshair_size"):GetInt() or 4
    local gapBase = GetConVar("sn_crosshair_gap") and GetConVar("sn_crosshair_gap"):GetInt() or 4
    local drawDot = GetConVar("sn_crosshair_dot") and GetConVar("sn_crosshair_dot"):GetBool() or true
    local drawShadow = GetConVar("sn_crosshair_shadow") and GetConVar("sn_crosshair_shadow"):GetBool() or true
    
    -- Проверяем, включен ли динамический разброс
    local useSpread = GetConVar("sn_crosshair_spread") == nil or GetConVar("sn_crosshair_spread"):GetBool()

    local spread = 0
    if useSpread then
        local velocity = ply:GetVelocity():Length2D()
        spread = math.Clamp(velocity / 100, 0, 5) * 4
    end

    local gap = gapBase + spread

    -- Рисуем обводку (Тени)
    if drawShadow then
        surface.SetDrawColor(0, 0, 0, math.min(ca, 180))
        if drawDot then surface.DrawRect(x - 1, y - 1, 3, 3) end
        
        if len > 0 then
            surface.DrawRect(x - gap - len, y - 1, len, 3)
            surface.DrawRect(x + gap, y - 1, len, 3)
            surface.DrawRect(x - 1, y - gap - len, 3, len)
            surface.DrawRect(x - 1, y + gap, 3, len)
        end
    end

    -- Рисуем сам прицел
    surface.SetDrawColor(cr, cg, cb, ca)
    if drawDot then surface.DrawRect(x, y, 1, 1) end
    
    if len > 0 then
        surface.DrawRect(x - gap - len + 1, y, len - 2, 1)
        surface.DrawRect(x + gap + 1, y, len - 2, 1)
        surface.DrawRect(x, y - gap - len + 1, 1, len - 2)
        surface.DrawRect(x, y + gap + 1, 1, len - 2)
    end
end)

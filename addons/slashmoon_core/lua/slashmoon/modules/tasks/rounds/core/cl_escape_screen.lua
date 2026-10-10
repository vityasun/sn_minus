-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("tasks")

-- ========================================================
-- SN Tasks: Fullscreen Escape Result Screen
-- ========================================================
if not CLIENT then return end

local escapeScreen = {
    active    = false,
    success   = false,
    startTime = 0,
    duration  = 5,
    particles = {},
}

-- ── Частицы ───────────────────────────────────────────────────────────
local function CreateParticles(success)
    escapeScreen.particles = {}
    for _ = 1, 60 do
        table.insert(escapeScreen.particles, {
            x     = math.random(0, ScrW()),
            y     = math.random(ScrH(), ScrH() + 300),
            speed = math.random(80, 280),
            size  = math.random(3, 8),
            col   = success and Color(60, 255, 110) or Color(255, 60, 60),
        })
    end
end

-- ── Показать экран ────────────────────────────────────────────────────
local function ShowEscapeScreen(success)
    -- Если уже показываем "успех" — не перебивать провалом
    if escapeScreen.active and escapeScreen.success and not success then return end

    escapeScreen.active    = true
    escapeScreen.success   = success
    escapeScreen.startTime = CurTime()

    CreateParticles(success)

    surface.PlaySound(success
        and "ambient/levels/labs/teleport_postblast_thunder1.wav"
        or  "ambient/alarms/klaxon1.wav")

    timer.Simple(escapeScreen.duration, function()
        escapeScreen.active = false
    end)
end

-- ── Отрисовка ─────────────────────────────────────────────────────────
MODULE:Hook("HUDPaint", "SN_EscapeScreen_Draw", function()
    if not escapeScreen.active then return end

    local elapsed = CurTime() - escapeScreen.startTime
    local dur     = escapeScreen.duration
    local sw, sh  = ScrW(), ScrH()

    -- Прозрачность: fade-in 0.5с, fade-out последние 0.8с
    local bgAlpha = 200
    if elapsed < 0.5 then
        bgAlpha = math.Clamp(elapsed / 0.5 * 200, 0, 200)
    elseif elapsed > dur - 0.8 then
        bgAlpha = math.Clamp((dur - elapsed) / 0.8 * 200, 0, 200)
    end

    local txtAlpha = 255
    if elapsed < 0.8 then
        txtAlpha = math.Clamp((elapsed - 0.2) / 0.6 * 255, 0, 255)
    elseif elapsed > dur - 0.8 then
        txtAlpha = math.Clamp((dur - elapsed) / 0.8 * 255, 0, 255)
    end

    -- Фон
    surface.SetDrawColor(0, 0, 0, bgAlpha)
    surface.DrawRect(0, 0, sw, sh)

    -- Частицы (поднимаются снизу)
    local dt = FrameTime()
    for _, p in ipairs(escapeScreen.particles) do
        p.y = p.y - p.speed * dt
        if p.y < -20 then
            p.y = sh + 20
            p.x = math.random(0, sw)
        end
        surface.SetDrawColor(p.col.r, p.col.g, p.col.b, txtAlpha * 0.7)
        surface.DrawRect(p.x, p.y, p.size, p.size)
    end

    local mainCol = escapeScreen.success
        and Color(60, 255, 110, txtAlpha)
        or  Color(255, 60,  60,  txtAlpha)

    -- Пульсирующий сдвиг
    local pulse = math.sin(CurTime() * 3) * SlashMoon.UI.Scale(8)
    local cy    = sh / 2 + pulse

    -- Главный текст
    local mainKey = escapeScreen.success and "sn.escape.success" or "sn.escape.failed"
    SlashMoon.UI.Draw.TextShadow(SlashMoon.Tasks.Lang(mainKey), "SlashMoon.Broadcast",
        sw / 2, cy - SlashMoon.UI.Scale(40),
        mainCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    -- Подзаголовок
    local subKey = escapeScreen.success and "sn.escape.you_escaped" or "sn.escape.you_died"
    SlashMoon.UI.Draw.TextShadow(SlashMoon.Tasks.Lang(subKey), "SlashMoon.Title",
        sw / 2, cy + SlashMoon.UI.Scale(30),
        Color(220, 220, 220, txtAlpha * 0.85),
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    -- Световая вспышка при успехе (первые 1.5с)
    if escapeScreen.success and elapsed < 1.5 then
        local flash = math.Clamp(math.sin(elapsed * 14) * 80, 0, 80)
        surface.SetDrawColor(60, 255, 110, flash)
        surface.DrawRect(0, 0, sw, sh)
    end

    -- Мигающие полосы тревоги при провале
    if not escapeScreen.success then
        local alarm = math.Clamp(math.abs(math.sin(CurTime() * 5)) * 120, 0, 120)
        surface.SetDrawColor(255, 30, 30, alarm)
        surface.DrawRect(0, 0,              sw, SlashMoon.UI.Scale(8))
        surface.DrawRect(0, sh - SlashMoon.UI.Scale(8), sw, SlashMoon.UI.Scale(8))
    end

    -- Полоса прогресса (убывает)
    local frac = math.Clamp(1 - elapsed / dur, 0, 1)
    surface.SetDrawColor(mainCol.r, mainCol.g, mainCol.b, 120)
    surface.DrawRect(0, sh - SlashMoon.UI.Scale(4), sw * frac, SlashMoon.UI.Scale(4))
end)

-- ── Сетевые обработчики ───────────────────────────────────────────────

-- Успешный побег: приходит сразу когда я добежал до зоны
MODULE:Receive("fhi_player_escaped", function()
    local ply = net.ReadEntity()
    if IsValid(ply) and ply == LocalPlayer() then
        ShowEscapeScreen(true)
    end
end)

local function HandleEscapeResult(escaped, notEscaped)
    local me = LocalPlayer()
    if not IsValid(me) then return end
    if not SlashMoon.Tasks.Game.IsSurvivorTeam(me) then return end

    local myNick = me:Nick()
    for _, nick in ipairs(escaped) do
        if nick == myNick then return end  -- я сбежал — экран успеха уже показан
    end

    -- Я не в списке сбежавших — провал
    ShowEscapeScreen(false)
end

-- Также показать провал при смерти во время фазы побега
MODULE:Hook("PlayerDeath", "SN_EscapeScreen_OnDeath", function(victim)
    if victim ~= LocalPlayer() then return end

    -- Небольшая задержка чтобы NW2 успел синхронизироваться
    timer.Simple(0.3, function()
        if not IsValid(victim) then return end
        local phase = SlashMoon.Tasks.GetPhase and SlashMoon.Tasks.GetPhase() or "none"
        if phase ~= "escape" then return end
        if victim:GetNW2Bool("fhi_escaped", false) then return end  -- уже сбежал
        ShowEscapeScreen(false)
    end)
end)

-- ── Экспорт ───────────────────────────────────────────────────────────
SlashMoon.Rounds = SlashMoon.Rounds or {}
SlashMoon.Rounds.ShowEscapeScreen = ShowEscapeScreen
SlashMoon.Rounds.HandleEscapeResult = HandleEscapeResult

SlashMoon.Debug("[UI] Экран побега загружен")

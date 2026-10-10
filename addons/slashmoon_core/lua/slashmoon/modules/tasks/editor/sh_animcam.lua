-- Written for: SlashMoon. By: VIKA & Ronni

-- ========================================================
-- SN Tasks: Секция редактора — Настройка планшета аниматроников
-- ========================================================
-- Позволяет map-мейкеру настраивать:
--   - Автовыдачу планшета выжившим
--   - Скорость разряда батареи
--   - Начальный заряд батареи
--   - Включён ли планшет на карте вообще
-- Конфиг хранится в MapConfig.animcam

if not CLIENT then return end

-- Отложенная регистрация: sh_animcam.lua загружается раньше sh_editor.lua
-- по алфавиту (a < e), поэтому RegisterSection ещё не существует.
-- timer.Simple(0, ...) откладывает вызов до конца текущего тика,
-- когда все файлы редактора уже загружены.
timer.Simple(0, function()
    if not SlashMoon.Tasks.Editor or not SlashMoon.Tasks.Editor.RegisterSection then return end

SlashMoon.Tasks.Editor.RegisterSection("animcam", {
    title = "Планшет аниматроников",
    order = 55,  -- После побега (50), перед тасками (10-90)

    fields = {
        {
            type    = "checkbox",
            label   = "Планшет включён на карте",
            path    = {"animcam", "enabled"},
            default = true,
        },
        {
            type    = "checkbox",
            label   = "Автовыдача выжившим при спавне",
            path    = {"animcam", "autogive"},
            default = false,
        },
        {
            type    = "number",
            label   = "Разряд батареи (в секунду)",
            path    = {"animcam", "drain_rate"},
            min     = 0,
            max     = 0.05,
            default = 0.00333,
            -- Для отображения: умножаем на 1000 чтобы было читаемо
            -- 0.00333 = ~5 минут на полной батарее
        },
        {
            type    = "number",
            label   = "Начальный заряд батареи (%)",
            path    = {"animcam", "initial_battery_pct"},
            min     = 10,
            max     = 100,
            default = 100,
        },
        {
            type    = "checkbox",
            label   = "Показывать подсказки управления (HUD)",
            path    = {"animcam", "show_hud_hints"},
            default = true,
        },
    },

    info = function(api)
        local cfg = api.GetConfig({"animcam"}) or {}
        local enabled = cfg.enabled ~= false
        local autogive = cfg.autogive == true
        local drain = tonumber(cfg.drain_rate) or 0.00333

        if not enabled then
            return "Планшет ОТКЛЮЧЕН на этой карте"
        end

        -- Считаем примерное время работы батареи
        local batteryPct = tonumber(cfg.initial_battery_pct) or 100
        local batteryFrac = batteryPct / 100
        local minutesFull = (1.0 / drain) / 60
        local minutesActual = minutesFull * batteryFrac

        return string.format("Вкл | Автогив: %s | ~%.1f мин работы (%d%% заряд)",
            autogive and "Да" or "Нет",
            minutesActual,
            batteryPct
        )
    end,
})

end) -- timer.Simple

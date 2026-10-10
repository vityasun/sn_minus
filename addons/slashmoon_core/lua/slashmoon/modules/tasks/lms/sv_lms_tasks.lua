-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("tasks")

-- ========================================================
-- SN Tasks: LMS ↔ Tasks Integration (Server)
-- Тонкая обёртка — основная логика LMS уже в sn_lib/lms/sv_lms.lua
-- Этот файл только добавляет сигнал SN_Tasks_AllCompleted
-- ========================================================
if not SERVER then return end

SlashMoon.Tasks = SlashMoon.Tasks or {}
SlashMoon.Tasks.LMS = SlashMoon.Tasks.LMS or {}

-- === СИГНАЛ ОТ ЗАДАНИЙ: Все задания выполнены ===
-- sn_lib LMS сам следит за PlayerDeath/Spawn/TeamChange/Disconnect/Escape.
-- Но когда задания выполнены — проверяем LMS принудительно,
-- т.к. фаза побега начнётся и при 1 выжившем LMS должен включиться.
MODULE:Hook("SN_Tasks_AllCompleted", "SN_Tasks_LMS_OnAllComplete", function()
    SlashMoon.Debug("[SN Tasks LMS] Все задания выполнены — проверяем LMS...")
    -- sn_lib LMS автоматически проверяет при PlayerDeath/Spawn,
    -- но принудительная проверка помогает при переходе фаз
    timer.Simple(0.5, function()
        -- Если sn_lib экспортирует CheckLMS, вызываем его
        if SlashMoon.LMS and SlashMoon.LMS.Check then
            SlashMoon.LMS.Check()
        end
    end)
end)

-- === ЭКСПОРТ (для совместимости) ===
SlashMoon.Tasks.LMS.Check = function()
    if SlashMoon.LMS and SlashMoon.LMS.Check then SlashMoon.LMS.Check() end
end
SlashMoon.Tasks.LMS.Start = function(ply)
    if SlashMoon.LMS and SlashMoon.LMS.Start then SlashMoon.LMS.Start(ply) end
end
SlashMoon.Tasks.LMS.Stop = function(reason)
    if SlashMoon.LMS and SlashMoon.LMS.Stop then SlashMoon.LMS.Stop(reason) end
end

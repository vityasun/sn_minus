-- Written for: SlashMoon. By: VIKA & Ronni
-- ========================================================
-- SlashMoon UI :: общие хелперы компонентов
-- ========================================================

local UI = SlashMoon.UI

-- Звуки интерфейса (стандартные звуки HL2; можно заменить на свои или "" для тишины)
UI.Sounds = UI.Sounds or {
    Hover = "ui/buttonrollover.wav",
    Click = "ui/buttonclick.wav",
    Toggle = "ui/buttonclickrelease.wav",
    Open = "",
    Close = "",
}

--- Проигрывает звук интерфейса по имени из UI.Sounds.
function UI.PlaySound(kind)
    -- Модули могут отключить звуки интерфейса (например, пользовательской настройкой)
    if hook.Run("SlashMoon.UI.ShouldPlaySound", kind) == false then return end
    local snd = UI.Sounds[kind]
    if snd and snd ~= "" then surface.PlaySound(snd) end
end

--- Создает компонент библиотеки: UI.Create("Button", parent) -> vgui "SlashMoon.Button".
function UI.Create(kind, parent, name)
    return vgui.Create("SlashMoon." .. kind, parent, name)
end

--- Плавно приближает поле panel[key] к target. Возвращает новое значение.
-- Используется во всех компонентах для анимаций наведения/нажатия.
function UI.Animate(panel, key, target, speed)
    local cur = panel[key] or target
    cur = Lerp(math.min(1, FrameTime() * (speed or 12)), cur, target)
    if math.abs(cur - target) < 0.001 then cur = target end
    panel[key] = cur
    return cur
end

--- Масштабированное скругление по умолчанию.
function UI.GetRadius(px)
    return UI.Scale(px or UI.Radius)
end

-- ========================================================
-- Перехват ESC: окна библиотеки закрываются по Escape,
-- не открывая меню паузы.
-- ========================================================
UI.EscapeStack = UI.EscapeStack or {}

--- Регистрирует панель, которая закрывается по ESC (последняя добавленная — первая).
function UI.PushEscape(panel, fn)
    for i = #UI.EscapeStack, 1, -1 do
        if UI.EscapeStack[i].panel == panel then table.remove(UI.EscapeStack, i) end
    end
    UI.EscapeStack[#UI.EscapeStack + 1] = { panel = panel, fn = fn }
end

--- Обрабатывает нажатие ESC. Возвращает true, если событие поглощено.
function UI.HandleEscape()
    for i = #UI.EscapeStack, 1, -1 do
        local entry = UI.EscapeStack[i]
        if not IsValid(entry.panel) then
            table.remove(UI.EscapeStack, i)
        elseif entry.panel.GetCloseOnEscape and not entry.panel:GetCloseOnEscape() then
            continue -- окно само управляет закрытием по ESC
        elseif entry.panel:IsVisible() and not entry.panel.Closing then
            -- Запись не удаляется: окно с SetDeleteOnClose(false) можно показать снова,
            -- удаленные панели вычищаются при следующем проходе
            entry.fn(entry.panel)
            return true
        end
    end

    -- Внешние обработчики (модули могут вернуть true, чтобы поглотить ESC)
    if hook.Run("SlashMoon.UI.InterceptEscape") == true then return true end
    return false
end

hook.Add("OnPauseMenuShow", "SlashMoon.UI.Escape", function()
    if UI.HandleEscape() then return false end
end)

--- Закрывает все открытые окна библиотеки.
function UI.CloseAll()
    for i = #UI.EscapeStack, 1, -1 do
        local entry = UI.EscapeStack[i]
        if IsValid(entry.panel) then entry.fn(entry.panel) end
    end
    UI.EscapeStack = {}
end

-- Written for: SlashMoon. By: VIKA & Ronni
-- ========================================================
-- SlashMoon UI :: встроенный модуль "Тема интерфейса"
-- Позволяет поменять акцентный цвет ВСЕХ интерфейсов из админ-панели.
-- ========================================================

local MODULE = SlashMoon.Modules.Register({
    id = "ui_theme",
    name = "Тема интерфейса",
    description = "Единая палитра для всех меню. Акцентный цвет применяется у всех игроков сразу.",
    category = "Интерфейс",
    default = true,
    order = 0,
    options = {
        { key = "accent", type = "color", default = Color(150, 50, 255), name = "Акцентный цвет", shared = true },
    },
})

if CLIENT then
    local function Apply()
        local accent = MODULE:IsEnabled() and MODULE:GetOption("accent") or SlashMoon.UI.DefaultTheme.Accent
        SlashMoon.UI.SetTheme({ Accent = accent })
    end

    hook.Add("SlashMoon.ModulesSynced", "SlashMoon.UI.ThemeApply", Apply)
end

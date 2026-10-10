-- Written for: SlashMoon. By: VIKA & Ronni
SlashMoon.Modules.Register({
    id = "player_editor",
    name = "Редактор персонажа",
    description = "Выбор модели игрока со скинами, bodygroups и цветом (консоль: ronni_player_editor, "
        .. "иконка в контекстном меню). Бустеры могут приватизировать одну модель.",
    category = "Интерфейс",
    author = "Ronni",
    default = true,
    options = {
        { key = "blacklist", type = "string", shared = true, maxLength = 4000, name = "Скрытые модели",
            description = "Пути моделей через запятую (в нижнем регистре)",
            default = "models/bear_v1/bear_v1.mdl, models/bear_v2/bear_v2.mdl, models/hellinspector/familyguy_bttm/peter_pm.mdl, "
                .. "models/survivors/shinano_loose_punk.mdl, models/cryptiacurves/deltarune/stylized_noelle_holiday_casual_pm_sfw.mdl, "
                .. "models/player/zombie_soldier.mdl, models/player/zombie_classic.mdl" },
    },
})

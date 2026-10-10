-- Written for: SlashMoon. By: VIKA & Ronni
-- Каждая опция модуля привязана к convar аддона Sliding Ability (поле convar)
local OPTIONS = {
    { key = "max_speed", convar = "sliding_ability_max_speed", type = "number", default = 650, min = 1, max = 3000, decimals = 0, name = "Максимальная скорость" },
    { key = "acceleration", convar = "sliding_ability_acceleration", type = "number", default = 250, min = 1, max = 1000, decimals = 0, name = "Замедление",
        description = "Больше значение — короче скольжение" },
    { key = "speed_boost", convar = "sliding_ability_speedBoost", type = "number", default = 1.5, min = 1, max = 5, decimals = 1, name = "Множитель стартовой скорости" },
    { key = "threshold", convar = "sliding_ability_threshold", type = "number", default = -1, min = -1, max = 500, decimals = 0, name = "Порог скорости",
        description = "-1 — автоматически" },
    { key = "cooldown", convar = "sliding_ability_cooldown", type = "number", default = 0.5, min = 0, max = 3, decimals = 1, name = "Кулдаун (сек)" },
    { key = "cooldown_jump", convar = "sliding_ability_cooldown_jump", type = "number", default = 1.5, min = 0, max = 3, decimals = 1, name = "Кулдаун после прыжка (сек)" },
    { key = "dust", convar = "sliding_ability_DustEffect", type = "bool", default = true, name = "Частицы пыли" },
    { key = "origin_anim", convar = "sliding_ability_OriginAnim", type = "bool", default = false, name = "Оригинальная анимация" },
    { key = "viewpunch", convar = "sliding_ability_viewpunch", type = "number", default = 1, min = -5, max = 5, decimals = 1, name = "Сила наклона камеры" },
    { key = "vm_pos", convar = "sliding_ability_tilt_viewmodelPosition", type = "number", default = 2, min = -4, max = 4, decimals = 1, name = "Смещение viewmodel" },
    { key = "vm_ang", convar = "sliding_ability_tilt_viewmodelAngle", type = "number", default = 45, min = -90, max = 90, decimals = 0, name = "Угол viewmodel" },
    { key = "model_height", convar = "sliding_ability_modelHeight", type = "number", default = 8, min = -30, max = 30, decimals = 0, name = "Высота модели" },
    { key = "model_tilt", convar = "sliding_ability_modelTilt", type = "number", default = 25, min = 0, max = 90, decimals = 0, name = "Наклон модели" },
    { key = "anim_time", convar = "sliding_ability_animTransitionTime", type = "number", default = 0.2, min = 0, max = 1, decimals = 2, name = "Время перехода анимации" },
    { key = "legs_ang", convar = "sliding_ability_legsAng", type = "number", default = 20, min = 0, max = 90, decimals = 0, name = "Угол ног" },
    { key = "thigh_ang", convar = "sliding_ability_thighAng", type = "number", default = 60, min = -90, max = 90, decimals = 0, name = "Угол бедра" },
    { key = "calf_ang", convar = "sliding_ability_calfAng", type = "number", default = 65, min = -90, max = 90, decimals = 0, name = "Угол голени" },
    { key = "foot_ang", convar = "sliding_ability_footAng", type = "number", default = 30, min = -90, max = 90, decimals = 0, name = "Угол стопы" },
}

SlashMoon.Modules.Register({
    id = "sliding",
    name = "Скольжение",
    description = "Скольжение при приседании на бегу (на основе Sliding Ability by GreatZenkakuMan). "
        .. "Все настройки скольжения вынесены в эту панель вместо меню спавна.",
    category = "Геймплей",
    default = true,
    options = OPTIONS,
})

-- Written for: SlashMoon. By: VIKA & Ronni
SlashMoon.Modules.Register({
    id = "postprocess",
    name = "Постобработка карт",
    description = "Цветокоррекция и Bloom для каждой карты отдельно. Настраивается админом через меню "
        .. "(консоль: sn_admin_pp) с живым предпросмотром, хранится в data/sn_postprocess/<карта>.json.",
    category = "Графика",
    default = true,
})

SlashMoon.Admin.RegisterPermission("slashmoon_postprocess", "admin", "Настройка постобработки карты")

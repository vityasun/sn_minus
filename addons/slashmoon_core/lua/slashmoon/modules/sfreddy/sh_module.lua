-- Written for: SlashMoon. By: VIKA & Ronni
SlashMoon.Modules.Register({
    id = "sfreddy",
    name = "Реворк Shadow Freddy (WIP)",
    description = "Экспериментальный реворк Shadow Freddy: плюши-ловушки и ускорение. Основная логика была отключена "
        .. "в исходной сборке и оставлена в файлах модуля как заготовка. Модель и звуки шагов входят в аддон.",
    category = "Аниматроники",
    default = false,
    entities = { "sfreddy_plushie" },
})

SlashMoon.Admin.RegisterPermission("slashmoon_sfreddy_debug", "admin", "Отладочный телепорт к плюшам Shadow Freddy")

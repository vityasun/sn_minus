-- Written for: SlashMoon. By: VIKA & Ronni
SlashMoon.Modules.Register({
    id = "endo_copies",
    name = "Копии Эндо",
    description = "Эндоскелет расставляет копии и переключает сознание между ними (удержание ПКМ на копии). "
        .. "Копии видят выживших в конусе зрения, принимают урон и могут быть толкнуты.",
    category = "Аниматроники",
    default = true,
    entities = { "endo_copy" },
})

SlashMoon.Admin.RegisterPermission("slashmoon_endo_debug", "superadmin", "Отладка зрения копий Эндо (endo_vision_debug)")

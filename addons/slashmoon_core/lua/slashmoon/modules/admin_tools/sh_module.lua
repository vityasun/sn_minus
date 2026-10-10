-- Written for: SlashMoon. By: VIKA & Ronni
SlashMoon.Modules.Register({
    id = "admin_tools",
    name = "Инструменты администрации",
    description = "Выдача физгана администрации при спавне и автоматическая невидимость в noclip (без луча физгана).",
    category = "Администрирование",
    default = true,
    options = {
        { key = "give_physgun", type = "bool", default = true, name = "Выдавать физган при спавне" },
        { key = "noclip_invis", type = "bool", default = true, name = "Невидимость в noclip" },
    },
})

SlashMoon.Admin.RegisterPermission("slashmoon_physgun", "admin", "Получение физгана при спавне")
SlashMoon.Admin.RegisterPermission("slashmoon_noclip_invis", "superadmin", "Невидимость в режиме noclip")

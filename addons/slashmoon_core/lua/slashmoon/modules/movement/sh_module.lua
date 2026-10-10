-- Written for: SlashMoon. By: VIKA & Ronni
SlashMoon.Modules.Register({
    id = "movement",
    name = "Движение и выносливость",
    description = "Скорости аниматроников и выживших, стамина при банни-хопе, эффекты усталости и низкого HP, "
        .. "реалистичная камера от первого лица, фонарик, ближний бой аниматроников с кровотечением. "
        .. "Меню настройки: консольная команда fh_movement_menu (F4 занят хабом).",
    category = "Геймплей",
    author = "Ronni",
    default = true,
    order = 50,
    files = { "sh_rmc.lua", "sh_melee.lua", "sv_rmc.lua", "cl_tfps.lua" },
})

SlashMoon.Admin.RegisterPermission("slashmoon_movement", "admin", "Настройка движения и эффектов (fh_movement_menu)")

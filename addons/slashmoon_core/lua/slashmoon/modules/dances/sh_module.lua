-- Written for: SlashMoon. By: VIKA & Ronni
SlashMoon.Modules.Register({
    id = "dances",
    name = "Танцы и эмоции",
    description = "Колесо эмоций на клавишу H с 8 слотами, экипировка анимаций с предпросмотром, "
        .. "синхронизация анимаций и музыки между игроками (основано на wOS Dance System).",
    category = "Развлечения",
    default = true,
    order = 60,
    files = {
        "sh_dance_system.lua", "sh_dance_prices.lua", "sv_dance_system.lua",
        "cl_dance_init.lua", "cl_sync.lua", "cl_music.lua", "cl_db.lua", "cl_radial.lua", "cl_config.lua",
    },
})

SlashMoon.Admin.RegisterPermission("slashmoon_dances_force", "superadmin", "Принудительный запуск танца у игрока (sn_force_dance)")

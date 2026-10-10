-- Written for: SlashMoon. By: VIKA & Ronni
SlashMoon.Modules.Register({
    id = "round_types",
    name = "Умный выбор раундов",
    description = "Подменяет выбор типа раунда Fazbear's Hunt: особые раунды (Springtrap, Bear5) выпадают "
        .. "с заданным шансом и кулдауном. При отключении возвращается стандартный выбор гейммода.",
    category = "Геймплей",
    default = true,
    options = {
        { key = "springtrap_cooldown", type = "number", default = 3, min = 0, max = 50, decimals = 0, name = "Кулдаун Springtrap (раундов)" },
        { key = "springtrap_chance", type = "number", default = 40, min = 0, max = 100, decimals = 0, name = "Шанс Springtrap, %" },
        { key = "bear5_cooldown", type = "number", default = 8, min = 0, max = 50, decimals = 0, name = "Кулдаун Bear5 (раундов)" },
        { key = "bear5_chance", type = "number", default = 80, min = 0, max = 100, decimals = 0, name = "Шанс Bear5, %" },
    },
})

SlashMoon.Admin.RegisterPermission("slashmoon_rounds_view", "admin", "Просмотр статуса выбора раундов")
SlashMoon.Admin.RegisterPermission("slashmoon_rounds_manage", "superadmin", "Сброс и форсирование особых раундов")

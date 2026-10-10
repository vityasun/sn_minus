-- Written for: SlashMoon. By: VIKA & Ronni
SlashMoon.Modules.Register({
    id = "ping",
    name = "Метки",
    description = "Метки для союзников: ALT + ЛКМ ставит метку в точку взгляда. Видна только своей команде.",
    category = "Геймплей",
    author = "VIKA",
    default = true,
    options = {
        { key = "cooldown", type = "number", default = 30, min = 0, max = 300, decimals = 0, name = "Кулдаун (сек)" },
        { key = "duration", type = "number", default = 15, min = 1, max = 120, decimals = 0, name = "Время жизни метки (сек)", shared = true },
        { key = "max_dist", type = "number", default = 900, min = 100, max = 5000, decimals = 0, name = "Дальность установки", shared = true },
        { key = "max_vis", type = "number", default = 2500, min = 100, max = 10000, decimals = 0, name = "Дальность видимости для выживших", shared = true },
    },
})

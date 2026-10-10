-- Written for: SlashMoon. By: VIKA & Ronni
SlashMoon.Modules.Register({
    id = "gifts",
    name = "Подарки с предметами",
    description = "Заменяет подарки гейммода: выжившие получают предметы в инвентарь (модуль \"Задания\") "
        .. "или случайные эффекты, чужой подарок может оказаться негативным.",
    category = "Геймплей",
    default = true,
    order = 120,
    entities = { "sn_inventory_gift" },
    options = {
        { key = "interval", type = "number", default = 120, min = 15, max = 600, decimals = 0, name = "Интервал появления (сек)" },
    },
})

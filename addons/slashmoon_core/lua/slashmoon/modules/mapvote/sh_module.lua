-- Written for: SlashMoon. By: VIKA & Ronni
SlashMoon.Modules.Register({
    id = "mapvote",
    name = "Ротация карт",
    description = "Каждые N раундов запускается \"рулетка\" выбора следующей карты из data/fh_maplist.txt. "
        .. "Недавно сыгранные карты временно исключаются.",
    category = "Сервер",
    default = true,
    options = {
        { key = "rounds_per_map", type = "number", default = 5, min = 1, max = 50, decimals = 0, name = "Раундов на карту" },
        { key = "map_cooldown", type = "number", default = 3, min = 0, max = 20, decimals = 0, name = "Кулдаун карты (ротаций)" },
    },
})

SlashMoon.Admin.RegisterPermission("slashmoon_mapvote", "superadmin", "Управление ротацией карт (fh_force_mapvote и др.)")

-- Written for: SlashMoon. By: VIKA & Ronni
SlashMoon.Modules.Register({
    id = "hub",
    name = "Хаб",
    description = "Главное меню сервера (F4): профиль с аватарами и баннерами, магазин анимаций и наборов, "
        .. "галерея аниматроников, задания с наградами, промокоды. Экономика хранится локально в SQLite сервера.",
    category = "Интерфейс",
    default = true,
    order = 40,
    files = {
        "sh_hub_content.lua", "sv_hub_db.lua", "sv_hub.lua",
        "cl_hub.lua", "cl_tab_main.lua", "cl_tab_shop.lua", "cl_tab_gallery.lua", "cl_tab_tasks.lua",
    },
    options = {
        { key = "currency", type = "string", default = "FC", shared = true, maxLength = 8, name = "Название валюты" },
        { key = "start_balance", type = "number", default = 0, min = 0, max = 100000, decimals = 0, name = "Стартовый баланс" },
        { key = "dance_price", type = "number", default = 250, min = 0, max = 100000, decimals = 0, shared = true,
            name = "Цена платной анимации", description = "Применяется ко всем платным анимациям без своей цены" },
        { key = "prices", type = "string", default = "", shared = true, maxLength = 4000, name = "Индивидуальные цены",
            description = "Формат: id=цена; id=цена (анимации и наборы)" },
        { key = "promocodes", type = "string", default = "", maxLength = 4000, name = "Промокоды",
            description = "Формат: КОД=balance:100; КОД2=item:bundle_neon; КОД3=balance:50:10 (последнее число — лимит активаций)" },
        { key = "servers", type = "string", default = "", shared = true, maxLength = 2000, name = "Серверы для кнопки \"Играть\"",
            description = "Формат: Название=ip:port; Название 2=ip:port. Пусто — кнопка просто закрывает хаб" },
        { key = "open_on_join", type = "bool", default = false, name = "Открывать хаб при входе",
            description = "Удобно для сервера-лобби" },
        { key = "watermark", type = "bool", default = false, shared = true, name = "Водяной знак с UID игрока" },
    },
})

SlashMoon.Admin.RegisterPermission("slashmoon_hub_money", "superadmin", "Выдача валюты хаба (sn_addmoney)")

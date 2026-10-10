-- Written for: SlashMoon. By: VIKA & Ronni
SlashMoon.Modules.Register({
    id = "boosters",
    name = "Бустеры",
    description = "Список игроков-бустеров (поддержавших проект): бейдж в табло и приватные модели в редакторе игрока. "
        .. "Список задается SteamID64 вручную и/или загружается из текстового файла по URL (один SteamID64 в строке).",
    category = "Сообщество",
    default = true,
    order = 15,
    options = {
        { key = "steamids", type = "string", default = "", name = "SteamID64 бустеров",
            description = "Через запятую или пробел" },
        { key = "url", type = "string", default = "", name = "URL списка (необязательно)",
            description = "Текстовый файл: один SteamID64 в строке. Пусто — только ручной список" },
    },
})

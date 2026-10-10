-- Written for: SlashMoon. By: VIKA & Ronni
SlashMoon.Modules.Register({
    id = "lms",
    name = "Последний выживший (LMS)",
    description = "Когда в живых остается один выживший, всем игрокам включается музыка и показывается плашка с его ником. "
        .. "Трек может быть локальным звуком (sound/...) или URL. Персональные треки игроков — по шаблону <base_url><uid>_<slot>.wav.",
    category = "Геймплей",
    default = true,
    options = {
        { key = "default_track", type = "string", default = "music/hl2_song3.mp3", name = "Трек по умолчанию",
            description = "Путь к звуку (относительно sound/) или полный http(s) URL" },
        { key = "base_url", type = "string", default = "", name = "Базовый URL персональных треков",
            description = "Например https://example.com/lms/ — пусто: персональные треки отключены" },
        { key = "max_slot", type = "number", default = 64, min = 1, max = 256, decimals = 0, name = "Максимум слотов треков" },
    },
})

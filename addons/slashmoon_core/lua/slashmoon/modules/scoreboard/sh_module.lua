-- Written for: SlashMoon. By: VIKA & Ronni
SlashMoon.Modules.Register({
    id = "scoreboard",
    name = "Табло (TAB)",
    description = "Табло игроков по командам: аватары аниматроников, баннеры, бейджи рангов и бустеров, "
        .. "громкость голоса и админ-действия (через SAM или ULX).",
    category = "Интерфейс",
    default = true,
    options = {
        { key = "badges", type = "string", shared = true, name = "Бейджи рангов",
            default = "superadmin=DEV:255,50,50; admin=MOD:255,150,0",
            description = "Формат: ранг=ТЕКСТ:R,G,B; ранг=ТЕКСТ:R,G,B" },
    },
})

SlashMoon.Admin.RegisterPermission("slashmoon_scoreboard_admin", "admin", "Админ-действия в табло")

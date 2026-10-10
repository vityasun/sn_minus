-- Written for: SlashMoon. By: VIKA & Ronni

-- ========================================================
-- SN Tasks: Секция редактора — Маркеры побега
-- ========================================================
if not CLIENT then return end

SlashMoon.Tasks.Editor.RegisterSection("escape", {
    title = "Маркеры побега",
    order = 50,

    fields = {
        {
            type    = "number",
            label   = "Зон побега (0=все)",
            path    = {"escape_count"},
            min     = 0,
            max     = 20,
            default = 0,
        },
    },

    buttons = {
        {
            label  = "+ Маркер побега",
            color  = Color(50, 220, 80, 200),
            placing = {
                model       = "models/editor/playerstart.mdl",
                color       = Color(50, 220, 80, 200),
                config_path = {"escape_positions"},
                label       = "Побег #%d",
            },
        },
        {
            label  = "✖ Удалить посл. маркер",
            color  = Color(200, 60, 60, 200),
            action = function(api)
                local positions = api.GetConfig({"escape_positions"}) or {}
                if #positions > 0 then
                    table.remove(positions)
                    api.SetConfig({"escape_positions"}, positions)
                    api.Chat("Удалён последний маркер побега")
                else
                    api.Chat("Нет маркеров для удаления")
                end
            end,
        },
        {
            label  = "✖✖ Очистить маркеры побега",
            color  = Color(180, 40, 40, 200),
            action = function(api)
                api.SetConfig({"escape_positions"}, {})
                api.Chat("Все маркеры побега очищены")
            end,
        },
    },

    info = function(api)
        local positions = api.GetConfig({"escape_positions"}) or {}
        return "Маркеров размещено: " .. #positions
    end,

    markers = {
        {
            config_path = {"escape_positions"},
            model       = "models/editor/playerstart.mdl",
            color       = Color(50, 220, 80, 200),
            label       = "Побег #%d",
        },
    },

    list_items = function(api, add_row)
        local positions = api.GetConfig({"escape_positions"}) or {}
        for i, info in ipairs(positions) do
            local label = "Побег #" .. i

            local onTeleport = SlashMoon.Tasks.Editor.MakeTeleport(function()
                return info
            end)

            local onDelete = function()
                local pos = api.GetConfig({"escape_positions"}) or {}
                table.remove(pos, i)
                api.SetConfig({"escape_positions"}, pos)
                api.Chat("Удалён маркер побега #" .. i)
            end

            add_row(label, Color(50, 220, 80), onDelete, onTeleport)
        end
    end,
})

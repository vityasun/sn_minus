-- Written for: SlashMoon. By: VIKA & Ronni

-- ========================================================
-- SN Tasks: Секция редактора — Зарядные станции
-- ========================================================
if not CLIENT then return end

local CHARGING_MODEL  = "models/station_new/charging_station.mdl"
local CHARGING_COLOR  = Color(80, 160, 255, 200)

SlashMoon.Tasks.Editor.RegisterSection("charging", {
    title = "Зарядные станции",
    order = 60,

    buttons = {
        {
            label  = "+ Зарядная станция",
            color  = CHARGING_COLOR,
            placing = {
                model       = CHARGING_MODEL,
                color       = CHARGING_COLOR,
                config_path = {"charging_station_positions"},
                label       = "Станция #%d",
            },
        },
        {
            label  = "✖ Удалить посл. станцию",
            color  = Color(200, 60, 60, 200),
            action = function(api)
                local positions = api.GetConfig({"charging_station_positions"}) or {}
                if #positions > 0 then
                    table.remove(positions)
                    api.SetConfig({"charging_station_positions"}, positions)
                    api.Chat("Удалена последняя зарядная станция")
                else
                    api.Chat("Нет станций для удаления")
                end
            end,
        },
        {
            label  = "✖✖ Очистить все станции",
            color  = Color(180, 40, 40, 200),
            action = function(api)
                api.SetConfig({"charging_station_positions"}, {})
                api.Chat("Все зарядные станции очищены")
            end,
        },
    },

    info = function(api)
        local positions = api.GetConfig({"charging_station_positions"}) or {}
        return "Станций размещено: " .. #positions
    end,

    markers = {
        {
            config_path = {"charging_station_positions"},
            model       = CHARGING_MODEL,
            color       = CHARGING_COLOR,
            label       = "Станция #%d",
        },
    },

    list_items = function(api, add_row)
        local positions = api.GetConfig({"charging_station_positions"}) or {}
        for i, info in ipairs(positions) do
            local label = "Станция #" .. i

            local onTeleport = SlashMoon.Tasks.Editor.MakeTeleport(function()
                return info
            end)

            local onDelete = function()
                local pos = api.GetConfig({"charging_station_positions"}) or {}
                table.remove(pos, i)
                api.SetConfig({"charging_station_positions"}, pos)
                api.Chat("Удалена зарядная станция #" .. i)
            end

            add_row(label, CHARGING_COLOR, onDelete, onTeleport)
        end
    end,
})

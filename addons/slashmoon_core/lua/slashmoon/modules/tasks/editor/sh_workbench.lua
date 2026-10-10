-- Written for: SlashMoon. By: VIKA & Ronni

-- ========================================================
-- SN Tasks: Секция редактора — Верстаки
-- ========================================================
if not CLIENT then return end

local WORKBENCH_MODEL  = "models/props_lab/workspace004.mdl"
local WORKBENCH_COLOR  = Color(50, 200, 255, 200)

SlashMoon.Tasks.Editor.RegisterSection("workbench", {
    title = SlashMoon.Tasks.Lang("sn.workbench.editor_title"),
    order = 65,

    buttons = {
        {
            label  = SlashMoon.Tasks.Lang("sn.workbench.add_pos"),
            color  = WORKBENCH_COLOR,
            placing = {
                model       = WORKBENCH_MODEL,
                color       = WORKBENCH_COLOR,
                config_path = {"workbench_positions"},
                label       = "Верстак #%d",
            },
        },
        {
            label  = "✖ Удалить посл. верстак",
            color  = Color(200, 60, 60, 200),
            action = function(api)
                local positions = api.GetConfig({"workbench_positions"}) or {}
                if #positions > 0 then
                    table.remove(positions)
                    api.SetConfig({"workbench_positions"}, positions)
                    api.Chat("Удалён последний верстак")
                else
                    api.Chat("Нет верстаков для удаления")
                end
            end,
        },
        {
            label  = "✖✖ " .. SlashMoon.Tasks.Lang("sn.workbench.clear"),
            color  = Color(180, 40, 40, 200),
            action = function(api)
                api.SetConfig({"workbench_positions"}, {})
                api.Chat(SlashMoon.Tasks.Lang("sn.workbench.cleared"))
            end,
        },
    },

    info = function(api)
        local positions = api.GetConfig({"workbench_positions"}) or {}
        return "Верстаков размещено: " .. #positions
    end,

    markers = {
        {
            config_path = {"workbench_positions"},
            model       = WORKBENCH_MODEL,
            color       = WORKBENCH_COLOR,
            label       = "Верстак #%d",
        },
    },

    list_items = function(api, add_row)
        local positions = api.GetConfig({"workbench_positions"}) or {}
        for i, info in ipairs(positions) do
            local label = "Верстак #" .. i

            local onTeleport = SlashMoon.Tasks.Editor.MakeTeleport(function()
                return info
            end)

            local onDelete = function()
                local pos = api.GetConfig({"workbench_positions"}) or {}
                table.remove(pos, i)
                api.SetConfig({"workbench_positions"}, pos)
                api.Chat("Удалён верстак #" .. i)
            end

            add_row(label, WORKBENCH_COLOR, onDelete, onTeleport)
        end
    end,
})

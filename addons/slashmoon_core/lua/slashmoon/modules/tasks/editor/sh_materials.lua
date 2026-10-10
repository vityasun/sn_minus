-- Written for: SlashMoon. By: VIKA & Ronni

if not CLIENT then return end

local MATERIALS = {
    "mat_scrap", "mat_wire", "mat_chip", "mat_battery", "mat_circuit_board",
    "mat_transistor", "mat_key", "mat_plastic", "mat_medpack", "mat_fuse",
    "mat_acid", "mat_solvent",
}

local function MaterialName(class)
    local data = SlashMoon.Tasks.GetItemData(class)
    return data and data.name or class
end

local fields = {
    { type = "number", label = SlashMoon.Tasks.Lang("sn.matspawn.min_dist"), path = {"material_spawn", "navmesh", "minDist"}, min = 0, max = 1000, default = 200 },
    { type = "number", label = SlashMoon.Tasks.Lang("sn.matspawn.object_dist"), path = {"material_spawn", "navmesh", "minDistFromObjects"}, min = 0, max = 1500, default = 300 },
    { type = "number", label = SlashMoon.Tasks.Lang("sn.matspawn.z_offset"), path = {"material_spawn", "navmesh", "zOffset"}, min = -50, max = 100, default = 10 },
}

for _, class in ipairs(MATERIALS) do
    table.insert(fields, {
        type = "number",
        label = MaterialName(class),
        path = {"material_spawn", "navmesh", "counts", class},
        min = 0,
        max = 50,
        default = 3,
    })
end

local buttons = {
    { label = SlashMoon.Tasks.Lang("sn.matspawn.mode_config"), action = function(api) api.SetConfig({"material_spawn", "mode"}, "config") end },
    { label = SlashMoon.Tasks.Lang("sn.matspawn.mode_navmesh"), action = function(api) api.SetConfig({"material_spawn", "mode"}, "navmesh") end },
    { label = SlashMoon.Tasks.Lang("sn.matspawn.mode_both"), action = function(api) api.SetConfig({"material_spawn", "mode"}, "both") end },
}

for _, class in ipairs(MATERIALS) do
    table.insert(buttons, {
        label = "+ " .. MaterialName(class),
        placing = {
            model = SlashMoon.Tasks.GetItemModel(class),
            color = Color(100, 210, 140, 180),
            config_path = {"material_spawn", "config_positions"},
            on_store = function(api, pos, ang, entry)
                entry.class = class
                table.insert(api.EnsureConfig({"material_spawn", "config_positions"}), entry)
            end,
        },
    })
end

table.insert(buttons, {
    label = SlashMoon.Tasks.Lang("sn.matspawn.run"),
    action = function() RunConsoleCommand("sn_matspawn_run") end,
})
table.insert(buttons, {
    label = SlashMoon.Tasks.Lang("sn.matspawn.clear_spawned"),
    action = function() RunConsoleCommand("sn_matspawn_clear") end,
})

SlashMoon.Tasks.Editor.RegisterSection("material_spawn", {
    title = SlashMoon.Tasks.Lang("sn.matspawn.editor_title"),
    order = 70,
    fields = fields,
    buttons = buttons,
    info = function(api)
        local mode = api.GetConfig({"material_spawn", "mode"}) or "navmesh"
        local positions = api.GetConfig({"material_spawn", "config_positions"}) or {}
        return SlashMoon.Tasks.Lang("sn.matspawn.editor_info", mode, #positions)
    end,
    custom_markers = function(api)
        for i, info in ipairs(api.GetConfig({"material_spawn", "config_positions"}) or {}) do
            if not info.pos then continue end
            api.PlaceMarker(
                Vector(info.pos.x, info.pos.y, info.pos.z),
                Angle(info.ang and info.ang.p or 0, info.ang and info.ang.y or 0, info.ang and info.ang.r or 0),
                SlashMoon.Tasks.GetItemModel(info.class),
                Color(100, 210, 140, 180),
                MaterialName(info.class) .. " #" .. i
            )
        end
    end,
    list_items = function(api, addRow)
        for i, info in ipairs(api.GetConfig({"material_spawn", "config_positions"}) or {}) do
            local onTeleport = SlashMoon.Tasks.Editor.MakeTeleport(function() return info end)
            local onDelete = function()
                local positions = api.GetConfig({"material_spawn", "config_positions"}) or {}
                table.remove(positions, i)
                api.SetConfig({"material_spawn", "config_positions"}, positions)
            end
            addRow(MaterialName(info.class) .. " #" .. i, Color(100, 210, 140), onDelete, onTeleport)
        end
    end,
})

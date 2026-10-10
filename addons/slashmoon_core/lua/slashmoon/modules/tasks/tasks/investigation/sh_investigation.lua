-- Written for: SlashMoon. By: VIKA & Ronni

SlashMoon.Tasks = SlashMoon.Tasks or {}
SlashMoon.Tasks.Items = SlashMoon.Tasks.Items or {}
SlashMoon.Tasks.Investigation = SlashMoon.Tasks.Investigation or {}

SlashMoon.Tasks.Investigation.Models = {
    "models/police.mdl",
    "models/kleiner.mdl",
}

SlashMoon.Tasks.Items["sn_investigation_passport"] = SlashMoon.Tasks.Items["sn_investigation_passport"] or {
    name = "Passport",
    nameKey = "sn.investigation.passport",
    type = "document",
    unique = true,
    icon = "materials/sn_task/items/passport.png",
}

SlashMoon.Tasks.Items["sn_investigation_personal_item"] = SlashMoon.Tasks.Items["sn_investigation_personal_item"] or {
    name = "Personal item",
    nameKey = "sn.investigation.personal_item",
    type = "misc",
    unique = false,
    stackable = true,
}

SlashMoon.Tasks.Items["sn_corpse_scanner"] = SlashMoon.Tasks.Items["sn_corpse_scanner"] or {
    name = "Investigation scanner",
    nameKey = "sn.investigation.scanner",
    type = "tool",
    unique = true,
    equippable = true,
}

SlashMoon.Tasks.Investigation.PersonalItems = {
    "sn_investigation_glasses",
    "sn_investigation_cigarettes",
    "sn_investigation_mobile",
}

local function InvestigationSpawn(cfg, spawnedEnts)
    if SERVER and SlashMoon.Tasks.Investigation.ServerSpawn then
        return SlashMoon.Tasks.Investigation.ServerSpawn(cfg, spawnedEnts)
    end
end

local function InvestigationThink(state)
    if SERVER and SlashMoon.Tasks.Investigation.ServerThink then
        return SlashMoon.Tasks.Investigation.ServerThink(state)
    end
end

local function InvestigationCleanup(state)
    if SERVER and SlashMoon.Tasks.Investigation.ServerCleanup then
        return SlashMoon.Tasks.Investigation.ServerCleanup(state)
    end
end

for _, itemClass in ipairs(SlashMoon.Tasks.Investigation.PersonalItems) do
    SlashMoon.Tasks.Items[itemClass] = SlashMoon.Tasks.Items[itemClass] or {
        name = "Personal item",
        nameKey = "sn.investigation.personal_item",
        type = "misc",
        stackable = true,
    }
end

SlashMoon.Tasks.Register("investigation", {
    nameKey = "sn.task.investigation.name",
    client_hint = "sn.task.investigation.description",
    spawn = InvestigationSpawn,
    think = InvestigationThink,
    cleanup = InvestigationCleanup,
    rotation = {
        weight = 50,
        minSurvivors = 2,
        calculateRequired = function(survivorCount)
            return 1
        end,
    },
    editor = {
        title = "Расследование",
        order = 35,
        fields = {
            {
                type = "checkbox",
                label = "Включить расследование",
                path = { "tasks", "investigation", "enabled" },
                default = true,
            },
            {
                type = "number",
                label = "Шанс появления, %",
                path = { "tasks", "investigation", "chance" },
                default = 50,
                min = 0,
                max = 100,
            },
            {
                type = "number",
                label = "Количество следователей",
                path = { "tasks", "investigation", "investigator_count" },
                default = 1,
                min = 1,
                max = 4,
            },
        },
        info = function(api)
            local cfg = api.GetConfig({ "tasks", "investigation" }) or {}
            return "Следователей: " .. math.Clamp(tonumber(cfg.investigator_count) or 1, 1, 4) .. " | Трупы: 1 + 2 пустышки по навмешу"
        end,
    },
})

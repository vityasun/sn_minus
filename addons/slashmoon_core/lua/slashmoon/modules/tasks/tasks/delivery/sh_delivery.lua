-- Written for: SlashMoon. By: VIKA & Ronni

SlashMoon.Tasks = SlashMoon.Tasks or {}

SlashMoon.Tasks.DeliveryRecipes = {
    delivery_receiver = {
        id = "delivery_receiver",
        ingredients = { "mat_circuit_board", "mat_transistor", "mat_wire" },
        result = "item_delivery_receiver",
        nameKey = "sn.workbench.recipe_delivery_receiver",
        craftTime = 6,
    },
    delivery_radio = {
        id = "delivery_radio",
        ingredients = { "mat_circuit_board", "mat_wire", "mat_wire", "mat_plastic" },
        result = "item_delivery_radio",
        nameKey = "sn.workbench.recipe_delivery_radio",
        craftTime = 7,
    },
    delivery_medical = {
        id = "delivery_medical",
        ingredients = { "mat_medpack", "mat_medpack", "mat_plastic" },
        result = "item_delivery_medical",
        nameKey = "sn.workbench.recipe_delivery_medical",
        craftTime = 6,
    },
    delivery_food = {
        id = "delivery_food",
        ingredients = { "mat_plastic", "mat_key", "mat_scrap" },
        result = "item_delivery_food",
        nameKey = "sn.workbench.recipe_delivery_food",
        craftTime = 5,
    },
    delivery_chemicals = {
        id = "delivery_chemicals",
        ingredients = { "mat_acid", "mat_solvent", "mat_plastic" },
        result = "item_delivery_chemicals",
        nameKey = "sn.workbench.recipe_delivery_chemicals",
        craftTime = 7,
    },
}

SlashMoon.Tasks.CustomDeliveryRecipes = SlashMoon.Tasks.CustomDeliveryRecipes or {}

function SlashMoon.Tasks.GetDeliveryRecipePool()
    if SlashMoon.Tasks.DeliveryUseCustomRecipes ~= false and not table.IsEmpty(SlashMoon.Tasks.CustomDeliveryRecipes or {}) then
        return table.Copy(SlashMoon.Tasks.CustomDeliveryRecipes)
    end

    local pool = {}
    for id, recipe in pairs(SlashMoon.Tasks.DeliveryRecipes or {}) do
        pool[id] = recipe
    end
    return pool
end

local function RecipeName(recipeID)
    local recipe = SlashMoon.Tasks.DeliveryRecipes[recipeID]
    if not recipe then return recipeID end
    return SlashMoon.Tasks.GetItemName(recipe.result)
end

SlashMoon.Tasks.Register("delivery", {
    nameKey = "sn.task.delivery.name",
    client_hint = SlashMoon.Tasks.Lang("sn.task.delivery.description"),

    rotation = {
        weight = 100,
        minSurvivors = 1,
        calculateRequired = function(survCount)
            return math.Clamp(math.ceil(survCount / 5), 1, 6)
        end,
    },

    editor = {
        title = SlashMoon.Tasks.Lang("sn.task.delivery.name"),
        order = 20,
        fields = {
            {
                type = "checkbox",
                label = SlashMoon.Tasks.Lang("sn.task.delivery.allow_custom_recipes"),
                path = { "tasks", "delivery", "allow_custom_recipes" },
                default = true,
            },
        },
        buttons = (function()
            local buttons = {}
            buttons[#buttons + 1] = {
                label = SlashMoon.Tasks.Lang("sn.task.delivery.add_zone"),
                color = Color(80, 210, 140),
                placing = {
                    model = "models/Items/item_item_crate.mdl",
                    color = Color(80, 210, 140, 180),
                    config_path = { "tasks", "delivery", "delivery_positions" },
                    label = "Delivery #%d",
                },
            }
            buttons[#buttons + 1] = {
                label = SlashMoon.Tasks.Lang("sn.task.delivery.clear_zones"),
                color = Color(180, 40, 40),
                action = function(api)
                    api.SetConfig({ "tasks", "delivery", "delivery_positions" }, {})
                end,
            }
            return buttons
        end)(),
        info = function(api)
            local cfg = api.GetConfig({ "tasks", "delivery" }) or {}
            return SlashMoon.Tasks.Lang("sn.task.delivery.editor_info_random", #(cfg.delivery_positions or {}))
        end,
        markers = {
            {
                config_path = { "tasks", "delivery", "delivery_positions" },
                model = "models/Items/item_item_crate.mdl",
                color = Color(80, 210, 140, 180),
                label = "Delivery #%d",
            },
        },
        list_items = function(api, addRow)
            local cfg = api.GetConfig({ "tasks", "delivery" }) or {}
            for i, info in ipairs(cfg.delivery_positions or {}) do
                local idx = i
                addRow(
                    SlashMoon.Tasks.Lang("sn.task.delivery.zone", i),
                    Color(80, 210, 140),
                    function()
                        local positions = api.GetConfig({ "tasks", "delivery", "delivery_positions" }) or {}
                        table.remove(positions, idx)
                        api.SetConfig({ "tasks", "delivery", "delivery_positions" }, positions)
                    end,
                    SlashMoon.Tasks.Editor.MakeTeleport(function() return info end)
                )
            end
        end,
    },

    spawn = function(cfg, spawnedEnts)
        SlashMoon.Tasks.DeliveryUseCustomRecipes = cfg.allow_custom_recipes ~= false
        local recipePool = SlashMoon.Tasks.GetDeliveryRecipePool()
        local recipeIDs = table.GetKeys(recipePool)
        if #recipeIDs == 0 then return nil end
        local recipeID = recipeIDs[math.random(#recipeIDs)]
        local recipe = recipeID and recipePool[recipeID]
        local required = math.Clamp(math.floor(tonumber(cfg.required) or 1), 1, 6)
        local info = cfg.delivery_positions and cfg.delivery_positions[1]
        if not recipe or not info or not info.pos then return nil end
        if #ents.FindByClass("sn_workbench") == 0 then return nil end

        local ent = ents.Create("sn_delivery_zone")
        if not IsValid(ent) then return nil end
        ent:SetPos(Vector(info.pos.x, info.pos.y, info.pos.z))
        ent:SetAngles(Angle(info.ang and info.ang.p or 0, info.ang and info.ang.y or 0, info.ang and info.ang.r or 0))
        ent:Spawn()
        if not IsValid(ent) then return nil end
        ent:Activate()
        ent:SetNW2String("SN_DeliveryItem", recipe.result)
        ent:SetNW2Int("SN_DeliveryRequired", required)
        ent:SetNW2Int("SN_DeliveredCount", 0)
        table.insert(spawnedEnts, ent)

        local navAreas = navmesh.GetAllNavAreas()
        local ingredientsToSpawn = {}
        for _ = 1, required do
            for _, ingredient in ipairs(recipe.ingredients) do
                ingredientsToSpawn[#ingredientsToSpawn + 1] = ingredient
            end
        end
        local reserveCount = math.max(1, math.ceil(#ingredientsToSpawn * 0.5))
        for i = 1, reserveCount do
            ingredientsToSpawn[#ingredientsToSpawn + 1] = recipe.ingredients[((i - 1) % #recipe.ingredients) + 1]
        end

        for i, ingredient in ipairs(ingredientsToSpawn) do
            local spawnPos
            if #navAreas > 0 then
                spawnPos = navAreas[math.random(#navAreas)]:GetRandomPoint() + Vector(0, 0, 10)
            else
                spawnPos = ent:GetPos() + Vector(math.random(-500, 500), math.random(-500, 500), 20 + i * 4)
            end
            local drop = SlashMoon.Tasks.SpawnDrop(ingredient, spawnPos)
            if IsValid(drop) then table.insert(spawnedEnts, drop) end
        end

        return {
            done = false,
            failed = false,
            displayKey = "sn.task.delivery.display",
            displayArgs = { SlashMoon.Tasks.GetItemName(recipe.result), required },
            descriptionKey = "sn.task.delivery.description",
            descriptionArgs = { SlashMoon.Tasks.GetItemName(recipe.result), required },
            recipe = recipe,
            required = required,
            deliveryZone = ent,
        }
    end,

    think = function(state)
        if not IsValid(state.deliveryZone) then state.failed = true return end
        if state.deliveryZone:GetNW2Bool("SN_Delivered", false) then state.done = true end
    end,

    cleanup = function(state)
        local result = state.recipe and state.recipe.result
        if not result then return end
        for _, ply in ipairs(player.GetAll()) do
            for i = #(ply.SN_Backpack or {}), 1, -1 do
                if SlashMoon.Tasks.ParseItemEntry(ply.SN_Backpack[i]).baseClass == result then
                    table.remove(ply.SN_Backpack, i)
                end
            end
            SlashMoon.Tasks.SyncInventory(ply)
        end
    end,
})

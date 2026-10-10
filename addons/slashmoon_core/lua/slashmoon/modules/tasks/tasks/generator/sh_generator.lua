-- Written for: SlashMoon. By: VIKA & Ronni

-- ========================================================
-- SN Tasks: Задание "Генератор" (Localized + Improved Spawn)
-- ========================================================

SlashMoon.Tasks.Register("generator", {
    name = SlashMoon.Tasks.Lang("sn.task.generator.name"),
    client_hint = SlashMoon.Tasks.Lang("sn.task.generator.hint"),

    rotation = {
        weight = 100,
        minSurvivors = 1,
        calculateRequired = function(survCount)
            return math.Clamp(math.ceil(survCount / 5), 1, 6)
        end
    },

    editor = {
        title = SlashMoon.Tasks.Lang("sn.task.generator.name"),
        order = 10,

        fields = {
            {
                type    = "number",
                label   = SlashMoon.Tasks.Lang("sn.task.generator.count"),
                path    = {"tasks", "generator", "count"},
                min     = 1,
                max     = 10,
                default = 1,
            },
        },

        buttons = {
            {
                label = "+ Позиция генератора",
                color = Color(220, 130, 0),
                placing = {
                    model  = "models/props_mining/diesel_generator.mdl",
                    color  = Color(255, 150, 0, 180),
                    label  = "Генератор #%d",
                    config_path = {"tasks", "generator", "generator_positions"},
                },
            },
            {
                label = "+ Позиция канистры",
                color = Color(200, 60, 60),
                placing = {
                    model  = "models/props_junk/gascan001a.mdl",
                    color  = Color(255, 80, 80, 180),
                    label  = "Канистра #%d",
                    config_path = {"tasks", "generator", "gascan_positions"},
                },
            },
            {
                label = "✖ Удалить посл. генератор",
                color = Color(140, 40, 40),
                action = function(api)
                    local cfg = api.EnsureConfig({"tasks", "generator"})
                    cfg.generator_positions = cfg.generator_positions or {}
                    if #cfg.generator_positions > 0 then
                        table.remove(cfg.generator_positions)
                        api.RefreshAll()
                    else
                        api.Chat("Нет генераторов.")
                    end
                end,
            },
            {
                label = "✖ Удалить посл. канистру",
                color = Color(140, 40, 40),
                action = function(api)
                    local cfg = api.EnsureConfig({"tasks", "generator"})
                    cfg.gascan_positions = cfg.gascan_positions or {}
                    if #cfg.gascan_positions > 0 then
                        table.remove(cfg.gascan_positions)
                        api.RefreshAll()
                    else
                        api.Chat("Нет канистр.")
                    end
                end,
            },
            {
                label = "✖✖ Очистить всё (генераторы + канистры)",
                color = Color(120, 20, 20),
                action = function(api)
                    local cfg = api.EnsureConfig({"tasks", "generator"})
                    cfg.generator_positions = {}
                    cfg.gascan_positions    = {}
                    api.RefreshAll()
                    api.Chat("Генераторы и канистры очищены.")
                end,
            },
        },

        info = function(api)
            local cfg = api.GetConfig({"tasks", "generator"}) or {}
            return string.format("Генераторов: %d | Канистр: %d",
                #(cfg.generator_positions or {}),
                #(cfg.gascan_positions or {}))
        end,

        markers = {
            {
                config_path = {"tasks", "generator", "generator_positions"},
                model = "models/props_mining/diesel_generator.mdl",
                color = Color(255, 150, 0, 180),
                label = "Генератор #%d",
            },
            {
                config_path = {"tasks", "generator", "gascan_positions"},
                model = "models/props_junk/gascan001a.mdl",
                color = Color(255, 80, 80, 180),
                label = "Канистра #%d",
            },
        },

        list_items = function(api, add_row)
            local cfg = api.GetConfig({"tasks", "generator"}) or {}
            cfg.generator_positions = cfg.generator_positions or {}
            cfg.gascan_positions    = cfg.gascan_positions    or {}

            for i = 1, #cfg.generator_positions do
                local idx = i
                add_row(
                    "Генератор #" .. i,
                    Color(255, 150, 0),
                    function()
                        table.remove(cfg.generator_positions, idx)
                        api.RefreshAll()
                    end,
                    SlashMoon.Tasks.Editor.MakeTeleport(function()
                        return cfg.generator_positions[idx]
                    end)
                )
            end

            for i = 1, #cfg.gascan_positions do
                local idx = i
                add_row(
                    "Канистра #" .. i,
                    Color(255, 80, 80),
                    function()
                        table.remove(cfg.gascan_positions, idx)
                        api.RefreshAll()
                    end,
                    SlashMoon.Tasks.Editor.MakeTeleport(function()
                        return cfg.gascan_positions[idx]
                    end)
                )
            end
        end,
    },

    spawn = function(cfg, spawnedEnts)
        local genPos = cfg.generator_positions or {}
        if #genPos == 0 then return nil end

        local genCount = math.min(#genPos, math.max(1, tonumber(cfg.required) or tonumber(cfg.count) or 1))
        local targetTotal = genCount + 3

        local sGen = table.Copy(genPos)
        for i = #sGen, 2, -1 do
            local j = math.random(i); sGen[i], sGen[j] = sGen[j], sGen[i]
        end

        -- The editor pool may contain only the real objective positions.
        -- Fill the missing decoy positions from navmesh instead of turning
        -- real generators into fuelable fakes.
        local areas = navmesh and navmesh.GetAllNavAreas() or {}
        while #sGen < targetTotal and #areas > 0 do
            local area = areas[math.random(#areas)]
            if not area then break end
            local pos = area:GetRandomPoint()
            sGen[#sGen + 1] = {
                pos = { x = pos.x, y = pos.y, z = pos.z },
                ang = { p = 0, y = math.random(0, 360), r = 0 },
            }
        end
        local dummyCount = math.max(0, math.min(3, #sGen - genCount))

        -- === ПРАВИЛО: 3 КАНИСТРЫ НА 1 ГЕНЕРАТОР ===
        local gascansToSpawn = math.ceil(genCount * 3.5)

        -- === УЛУЧШЕННЫЙ СПАВН КАНИСТР С ФОЛЛБЭКОМ ===
        local hasNavMesh = #areas > 0

        if hasNavMesh then
            for i = 1, gascansToSpawn do
                local area = areas[math.random(#areas)]
                if area then
                    local pos = area:GetRandomPoint()
                    local ent = ents.Create("sn_gascan")
                    if IsValid(ent) then
                        ent:SetPos(pos + Vector(0, 0, 10))
                        ent:SetAngles(Angle(0, math.random(0, 360), 0))
                        ent:SetNW2Int("SN_Fuel", math.random(50, 78))
                        ent:Spawn()
                        if not IsValid(ent) then continue end
                        ent:Activate()
                        table.insert(spawnedEnts, ent)
                    end
                end
            end
        else
            -- === ФОЛЛБЭК: Спавн канистр рядом с генераторами ===
            SlashMoon.Debug(SlashMoon.Tasks.Lang("sn.task.no_navmesh"))

            for i = 1, gascansToSpawn do
                -- Выбираем случайный генератор как якорь
                local anchorInfo = sGen[math.random(#sGen)]
                if anchorInfo then
                    local anchorPos = Vector(anchorInfo.pos.x, anchorInfo.pos.y, anchorInfo.pos.z)
                    -- Рандомная позиция в радиусе 500-1500 юнитов от генератора
                    local offset = Vector(
                        math.random(-1500, 1500),
                        math.random(-1500, 1500),
                        math.random(0, 50)
                    )
                    local pos = anchorPos + offset

                    -- Трейс вниз чтобы поставить на землю
                    local tr = util.TraceLine({
                        start = pos + Vector(0, 0, 100),
                        endpos = pos - Vector(0, 0, 500),
                        mask = MASK_SOLID
                    })

                    local spawnPos = tr.Hit and tr.HitPos + Vector(0, 0, 5) or pos

                    local ent = ents.Create("sn_gascan")
                    if IsValid(ent) then
                        ent:SetPos(spawnPos)
                        ent:SetAngles(Angle(0, math.random(0, 360), 0))
                        ent:SetNW2Int("SN_Fuel", math.random(50, 78))
                        ent:Spawn()
                        if not IsValid(ent) then continue end
                        ent:Activate()
                        table.insert(spawnedEnts, ent)
                    end
                end
            end
        end

        -- Спавн Генераторов
        local subtasks = { _subtasks = true }
        for i = 1, math.min(genCount + dummyCount, #sGen) do
            local info = sGen[i]
            local pos = Vector(info.pos.x, info.pos.y, info.pos.z)
            local ang = Angle(info.ang.p, info.ang.y, info.ang.r)

            local isDecoy = i > genCount
            local genEnt = ents.Create(isDecoy and "sn_generator_decoy" or "sn_generator")
            if not IsValid(genEnt) then continue end
            genEnt:SetPos(pos)
            genEnt:SetAngles(ang)
            genEnt:Spawn()
            if not IsValid(genEnt) then continue end
            genEnt:Activate()
            table.insert(spawnedEnts, genEnt)

            if isDecoy then
                continue
            end

            subtasks["generator_" .. i] = {
                done        = false,
                failed      = false,
                displayKey  = "sn.task.generator.display",
                displayArgs = { i },
                displayName = SlashMoon.Tasks.Lang("sn.task.generator.display", i),
                generator   = genEnt,
            }
        end

        return subtasks
    end,

    think = function(state)
        local gen = state.generator
        if not IsValid(gen) then state.failed = true return end

        if gen:GetNW2Bool("SN_Fueled", false) and not state.done then
            state.done = true

            -- Вызов Juice (сочный эффект)
            net.Start("SN_Phase_Juice")
            net.WriteVector(gen:GetPos())
            net.WriteBool(true)
            net.Broadcast()
        end
    end,

    cleanup = function(state) end
})

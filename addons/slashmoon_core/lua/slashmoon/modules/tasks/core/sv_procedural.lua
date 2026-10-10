-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("tasks")

-- ========================================================
-- SN Tasks: Server Procedural Generation Engine
-- Port from fh_interactive/sv_procedural.lua
-- ========================================================
if not SERVER then return end

SlashMoon.ProcGen = {
    history = {},            -- [mapname] = { rounds = {...} }  — loaded history
    placedThisRound = {},    -- [category] = { Vector, Vector, ... }  — runtime anti-cluster
    currentRoundLog = {},    -- [category] = { posHash, posHash, ... }  — for commit to history
    currentRoundNumber = 0,
}


-- ── Position hash (for comparison in history) ─────────────────────────
local function PosHash(info)
    return string.format("%.1f,%.1f,%.1f", info.pos.x, info.pos.y, info.pos.z)
end

-- ── History load/save ─────────────────────────────────────────────────
local function LoadHistory()
    local path = string.format(SlashMoon.ProcGenConfig.HISTORY_FILE_FMT, game.GetMap())
    if not file.Exists(path, "DATA") then return { rounds = {} } end
    local t = util.JSONToTable(file.Read(path, "DATA") or "{}")
    return t or { rounds = {} }
end

local function SaveHistory()
    local dir = "sn_tasks/procgen"
    if not file.IsDir(dir, "DATA") then file.CreateDir(dir) end
    local path = string.format(SlashMoon.ProcGenConfig.HISTORY_FILE_FMT, game.GetMap())
    file.Write(path, util.TableToJSON(SlashMoon.ProcGen.history, true))
end

-- ── Check: was position used in last N rounds? ───────────────────────
local function IsPositionFresh(posHash, category, depth)
    local rounds = SlashMoon.ProcGen.history.rounds or {}
    local cutoff = #rounds - depth + 1
    if cutoff < 1 then cutoff = 1 end
    for i = cutoff, #rounds do
        local r = rounds[i]
        if r and r.placements and r.placements[category] then
            for _, h in ipairs(r.placements[category]) do
                if h == posHash then return false end
            end
        end
    end
    return true
end

-- ── Validate candidate with all constraints ──────────────────────────
local function IsValidPlacement(posInfo, category, alreadyChosen, opts)
    opts = opts or {}
    local pVec = Vector(posInfo.pos.x, posInfo.pos.y, posInfo.pos.z)

    -- Intra-category distance
    local minIntra = SlashMoon.ProcGenConfig.MIN_DIST_INTRA[category] or 0
    for _, c in ipairs(alreadyChosen) do
        local cVec = Vector(c.pos.x, c.pos.y, c.pos.z)
        if pVec:Distance(cVec) < minIntra then return false, "intra" end
    end

    -- Cross-category distance (check against placedThisRound)
    local crossRules = SlashMoon.ProcGenConfig.MIN_DIST_CROSS[category] or {}
    for otherCat, minDist in pairs(crossRules) do
        for _, placedVec in ipairs(SlashMoon.ProcGen.placedThisRound[otherCat] or {}) do
            if pVec:Distance(placedVec) < minDist then return false, "cross:" .. otherCat end
        end
    end

    return true
end

-- ── Main position-picking function ───────────────────────────────────
function SlashMoon.ProcGen.PickPositions(pool, k, category, opts)
    opts = opts or {}
    if not pool or #pool == 0 then return {} end
    k = math.min(k or #pool, #pool)
    if k <= 0 then return table.Copy(pool) end  -- 0 = all

    -- Step 1: filter fresh (not in history for last N rounds)
    local freshPool = {}
    local stalePool = {}
    for _, info in ipairs(pool) do
        if IsPositionFresh(PosHash(info), category, SlashMoon.ProcGenConfig.HISTORY_DEPTH) then
            table.insert(freshPool, info)
        else
            table.insert(stalePool, info)
        end
    end

    -- Step 2: shuffle
    local function Shuffle(t)
        for i = #t, 2, -1 do
            local j = math.random(i); t[i], t[j] = t[j], t[i]
        end
    end
    Shuffle(freshPool)
    Shuffle(stalePool)

    -- Step 3: greedy selection from fresh, with anti-cluster
    local chosen = {}
    local function TryFill(sourcePool)
        local i = 1
        while i <= #sourcePool and #chosen < k do
            local cand = sourcePool[i]
            local ok = IsValidPlacement(cand, category, chosen, opts)
            if ok then
                table.insert(chosen, cand)
                table.remove(sourcePool, i)
            else
                i = i + 1
            end
        end
    end

    TryFill(freshPool)

    -- Step 4: if fresh wasn't enough — fallback to stale
    if #chosen < k then
        SlashMoon.Debug(string.format(
            "[sn:procgen] %s: fresh pool (%d) < k (%d), using stale positions",
            category, #freshPool, k))
        TryFill(stalePool)
    end

    -- Step 5: if still not enough — relax constraints (take what we can)
    if #chosen < k then
        local remaining = {}
        for _, p in ipairs(freshPool) do table.insert(remaining, p) end
        for _, p in ipairs(stalePool) do table.insert(remaining, p) end
        Shuffle(remaining)
        for _, p in ipairs(remaining) do
            if #chosen >= k then break end
            -- Check only intra-category (no cross)
            local pVec = Vector(p.pos.x, p.pos.y, p.pos.z)
            local minIntra = SlashMoon.ProcGenConfig.MIN_DIST_INTRA[category] or 0
            local ok = true
            for _, c in ipairs(chosen) do
                if pVec:Distance(Vector(c.pos.x, c.pos.y, c.pos.z)) < minIntra * 0.5 then
                    ok = false; break
                end
            end
            if ok then table.insert(chosen, p) end
        end
        -- Final brute fallback: just take what's left
        while #chosen < k and #remaining > 0 do
            table.insert(chosen, remaining[1])
            table.remove(remaining, 1)
        end
    end

    -- Step 6: register in placedThisRound + currentRoundLog
    SlashMoon.ProcGen.placedThisRound[category] = SlashMoon.ProcGen.placedThisRound[category] or {}
    SlashMoon.ProcGen.currentRoundLog[category] = SlashMoon.ProcGen.currentRoundLog[category] or {}
    for _, info in ipairs(chosen) do
        local v = Vector(info.pos.x, info.pos.y, info.pos.z)
        table.insert(SlashMoon.ProcGen.placedThisRound[category], v)
        table.insert(SlashMoon.ProcGen.currentRoundLog[category], PosHash(info))
    end

    SlashMoon.Debug(string.format(
        "[sn:procgen] %s: picked %d/%d (fresh=%d, stale=%d)",
        category, #chosen, k, #freshPool, #stalePool))

    return chosen
end

-- ── Apply procedural generation to round config ──────────────────────
function SlashMoon.ProcGen.Apply(cfg)
    -- Reset round state
    SlashMoon.ProcGen.placedThisRound = {}
    SlashMoon.ProcGen.currentRoundLog = {}
    SlashMoon.ProcGen.currentRoundNumber = SlashMoon.Tasks.RoundCount or 0

    local C = SlashMoon.ProcGenConfig.ENABLED

    -- 1. Generators (pick from pool based on count)
    for taskID, g in pairs(cfg.tasks or {}) do
        local baseID = g._taskType or string.match(taskID, "^(.-)_%d+$") or taskID
        if baseID ~= "generator" then continue end
        local count = tonumber(g.required) or tonumber(g.count) or 1
        if C.generator then
            local pool = g.generator_positions or {}
            local pickCount = math.min(#pool, count + 3)
            local chosen = SlashMoon.ProcGen.PickPositions(pool, pickCount, "generator", {})
            g.generator_positions = chosen
            -- `required` is the number of real objectives; the remaining
            -- three positions are decoys and must not create subtasks.
            g.count = count
        end
        if C.gascan then
            local pool = g.gascan_positions or {}
            local k = math.min(#pool, math.ceil(3.5 * (tonumber(g.count) or 1)))
            g.gascan_positions = SlashMoon.ProcGen.PickPositions(pool, k, "gascan", {})
        end
    end

    -- 2. Delivery zones
    if C.delivery then
        for taskID, taskCfg in pairs(cfg.tasks or {}) do
            local baseID = taskCfg._taskType or string.match(taskID, "^(.-)_%d+$") or taskID
            if baseID == "delivery" and taskCfg.delivery_positions then
                taskCfg.delivery_positions = SlashMoon.ProcGen.PickPositions(taskCfg.delivery_positions, 1, "delivery", {})
            end
        end
    end

    -- 3. Collectibles (for each collect_* task)
    if C.collect and cfg.tasks then
        for taskID, tcfg in pairs(cfg.tasks) do
            local baseID = tcfg._taskType or string.match(taskID, "^(.-)_%d+$") or taskID
            if baseID == "collect" and tcfg.collect_positions then
                local required = tonumber(tcfg.required) or #tcfg.collect_positions
                -- Spawn at least required, but no more than pool
                local k = math.min(#tcfg.collect_positions, math.max(required, math.min(#tcfg.collect_positions, required + 3)))
                local chosen = SlashMoon.ProcGen.PickPositions(tcfg.collect_positions, k, "collect", {})
                tcfg.collect_positions = chosen
            end
            if baseID == "collect" and tcfg.delivery_positions and C.delivery then
                -- If more than 1 delivery zone, pick subset
                local k = #tcfg.delivery_positions > 1 and 1 or #tcfg.delivery_positions
                local chosen = SlashMoon.ProcGen.PickPositions(tcfg.delivery_positions, k, "delivery", {})
                tcfg.delivery_positions = chosen
            end
        end
    end

    -- 4. Escape (based on escape_count)
    if C.escape and cfg.escape_positions then
        local count = tonumber(cfg.escape_count) or 0
        local k = count > 0 and count or #cfg.escape_positions
        local chosen = SlashMoon.ProcGen.PickPositions(cfg.escape_positions, k, "escape", {})
        cfg.escape_positions = chosen
        cfg.escape_count = 0  -- SpawnEscapeMarkers will take all from chosen
    end

    -- 5. Charging stations
    if C.charging and cfg.charging_station_positions then
        local count = tonumber(cfg.charging_count) or SlashMoon.ProcGenConfig.DEFAULT_COUNTS.charging
        local k = count > 0 and count or #cfg.charging_station_positions
        local chosen = SlashMoon.ProcGen.PickPositions(cfg.charging_station_positions, k, "charging", {})
        cfg.charging_station_positions = chosen
    end
end

-- Commit round placements to history at end of game
MODULE:Hook("SN_Game_RoundEnd", "sn_procedural_commit", function()
    -- Save chosen positions to history
    if not SlashMoon.ProcGen.history.rounds then SlashMoon.ProcGen.history.rounds = {} end
    table.insert(SlashMoon.ProcGen.history.rounds, {
        round      = SlashMoon.ProcGen.currentRoundNumber,
        timestamp  = os.time(),
        placements = table.Copy(SlashMoon.ProcGen.currentRoundLog),
    })

    -- Prune: keep only last HISTORY_DEPTH * 2 rounds
    -- (with margin, so map downtime doesn't wipe everything)
    local maxHistory = SlashMoon.ProcGenConfig.HISTORY_DEPTH * 2
    while #SlashMoon.ProcGen.history.rounds > maxHistory do
        table.remove(SlashMoon.ProcGen.history.rounds, 1)
    end

    SaveHistory()
    SlashMoon.Debug(string.format(
        "[sn:procgen] Round %d committed. History: %d rounds",
        SlashMoon.ProcGen.currentRoundNumber, #SlashMoon.ProcGen.history.rounds))
end)

-- Load history on map start
MODULE:Hook("InitPostEntity", "sn_procedural_load", function()
    SlashMoon.ProcGen.history = LoadHistory()
end)
SlashMoon.ProcGen.history = LoadHistory()

-- Reload history on map cleanup
MODULE:Hook("PostCleanupMap", "sn_procedural_reload", function()
    SlashMoon.ProcGen.history = LoadHistory()
    SlashMoon.ProcGen.placedThisRound = {}
    SlashMoon.ProcGen.currentRoundLog = {}
end)

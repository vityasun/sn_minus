-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("tasks")

-- ========================================================
-- SN Tasks: Last Survivor Highlight System (OUTLINE)
-- Port from fh_interactive/cl_surv_halo.lua
-- Client-only: highlights ALL interactive entities when
-- exactly 1 survivor remains alive
-- ========================================================
if not CLIENT then return end

-- ----------------------------------------------------------------
-- Configuration
-- ----------------------------------------------------------------
local HIGHLIGHT_CLASSES = {
    "sn_generator",
    "sn_gascan",
    "sn_collect_item",
    "sn_escape_car",
    "sn_workbench",
}

local HIGHLIGHT_COLOR = Color(255, 200, 50)
local HIGHLIGHT_WIDTH = 3
local HIGHLIGHT_MODE  = OUTLINE_MODE_BOTH or 2
local HIGHLIGHT_PRIORITY = 48

-- ----------------------------------------------------------------
-- OUTLINE helpers (same pattern as SlashMoon.Penalty)
-- ----------------------------------------------------------------
local function OutlinedLibAvailable()
    return OutlineObjectAdd ~= nil and OutlineObjectRemove ~= nil
end

local function AddOutline(ent)
    OutlineObjectAdd(ent, HIGHLIGHT_COLOR, HIGHLIGHT_WIDTH, HIGHLIGHT_MODE, HIGHLIGHT_PRIORITY)
end

local function RemoveOutline(ent)
    OutlineObjectRemove(ent)
end

-- ----------------------------------------------------------------
-- State: track which entities we are currently outlining
-- ----------------------------------------------------------------
local oldOutlineState = SlashMoon.Tasks._LastSurvivorOutlineState or {}
for _, ent in ipairs(oldOutlineState.outlinedEnts or {}) do
    if IsValid(ent) and OutlineObjectRemove then OutlineObjectRemove(ent) end
end
local outlinedEnts = {}   -- ordered list
local outlinedSet  = {}   -- [ent] = true for fast lookup
SlashMoon.Tasks._LastSurvivorOutlineState = { outlinedEnts = outlinedEnts }
local nextRefresh = 0
local cachedSurvivorCount = 0
local cachedDesired = {}

-- ----------------------------------------------------------------
-- Count alive, non-escaped survivors
-- ----------------------------------------------------------------
local function CountAliveSurvivors()
    local count = 0
    for _, p in ipairs(player.GetAll()) do
        if SlashMoon.Tasks.Game.IsSurvivor(p) then
            count = count + 1
        end
    end
    return count
end

local function IsLocalSurvivor()
    local ply = LocalPlayer()
    return IsValid(ply) and ply:Alive() and SlashMoon.Tasks.Game.IsSurvivor(ply)
end

-- ----------------------------------------------------------------
-- Gather all interactive entities of the tracked classes
-- ----------------------------------------------------------------
local function GetInteractiveEntities()
    local result = {}
    for _, className in ipairs(HIGHLIGHT_CLASSES) do
        for _, ent in ipairs(ents.FindByClass(className)) do
            if IsValid(ent) then
                result[#result + 1] = ent
            end
        end
    end
    return result
end

-- ----------------------------------------------------------------
-- Per-frame Think: enable/disable outlines
-- ----------------------------------------------------------------
MODULE:Hook("Think", "SN_LastSurvivor_OutlineThink", function()
    if CurTime() < nextRefresh then return end
    if not IsLocalSurvivor() then
        if #outlinedEnts > 0 then
            for _, ent in ipairs(outlinedEnts) do
                if IsValid(ent) then RemoveOutline(ent) end
            end
            table.Empty(outlinedEnts)
            table.Empty(outlinedSet)
        end
        nextRefresh = CurTime() + 0.25
        return
    end
    -- Only active during a live game
    if SlashMoon.Rounds.GetState and SlashMoon.Rounds.GetState() ~= SlashMoon.Rounds.STATE_ACTIVE then
        -- Clean up any lingering outlines when game is off
        if #outlinedEnts > 0 then
            for _, ent in ipairs(outlinedEnts) do
                if IsValid(ent) then RemoveOutline(ent) end
            end
            table.Empty(outlinedEnts)
            table.Empty(outlinedSet)
        end
        return
    end

    -- OUTLINE library must be available
    if not OutlinedLibAvailable() then return end

    cachedSurvivorCount = CountAliveSurvivors()
    cachedDesired = GetInteractiveEntities()
    nextRefresh = CurTime() + 0.25
    local shouldHighlight = (cachedSurvivorCount == 1)

    if not shouldHighlight then
        -- Remove all outlines
        if #outlinedEnts > 0 then
            for _, ent in ipairs(outlinedEnts) do
                if IsValid(ent) then RemoveOutline(ent) end
            end
            table.Empty(outlinedEnts)
            table.Empty(outlinedSet)
        end
        return
    end

    -- Build the new set of entities to outline
    local desired    = cachedDesired
    local newOutlined = {}
    local newSet      = {}

    for _, ent in ipairs(desired) do
        AddOutline(ent)
        newOutlined[#newOutlined + 1] = ent
        newSet[ent] = true
    end

    -- Remove outlines from entities no longer in the desired set
    for _, ent in ipairs(outlinedEnts) do
        if IsValid(ent) and not newSet[ent] then
            RemoveOutline(ent)
        end
    end

    outlinedEnts = newOutlined
    outlinedSet  = newSet
    SlashMoon.Tasks._LastSurvivorOutlineState.outlinedEnts = outlinedEnts
end)

-- ----------------------------------------------------------------
-- Cleanup on round end / player disconnect
-- ----------------------------------------------------------------
SlashMoon.Debug("[SN_LastSurvivor] Last survivor highlight system loaded")

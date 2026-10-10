-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("tasks")

-- ========================================================
-- SN Tasks: Penalty Highlight System (OUTLINE)
-- Port from fh_interactive/cl_hl_penalty.lua
-- Client-only: highlights entities during penalty phase
-- ========================================================
if not CLIENT then return end

SlashMoon.Penalty = SlashMoon.Penalty or {}
SlashMoon.Penalty._rules = SlashMoon.Penalty._rules or {}
local nextOutlineUpdate = 0

for _, oldRule in ipairs(SlashMoon.Penalty._rules) do
    for _, ent in ipairs(oldRule.outlined or {}) do
        if IsValid(ent) and OutlineObjectRemove then OutlineObjectRemove(ent) end
    end
end
table.Empty(SlashMoon.Penalty._rules)

-- ----------------------------------------------------------------
-- Helpers: OUTLINE library availability
-- ----------------------------------------------------------------
local function OutlinedLibAvailable()
    return OutlineObjectAdd ~= nil and OutlineObjectRemove ~= nil
end

local function AddOutline(ent, color, width, mode, priority)
    if not OutlinedLibAvailable() then return end
    OutlineObjectAdd(ent, color, width, mode, priority)
end

local function RemoveOutline(ent)
    if not OutlinedLibAvailable() then return end
    OutlineObjectRemove(ent)
end

-- ----------------------------------------------------------------
-- Resolve a color that may be a Color value or a function(ent)->Color
-- ----------------------------------------------------------------
local function ResolveColor(colorOrFn, ent)
    if isfunction(colorOrFn) then return colorOrFn(ent) end
    return colorOrFn
end

-- ----------------------------------------------------------------
-- SlashMoon.Penalty.RegisterAutoReveal(ruleName, opts)
--
-- opts.getEntities  function() -> {ent,...}   REQUIRED
-- opts.color        Color | function(ent)->Color   outline color
-- opts.width        number   default 3
-- opts.maxDist      number   default 4000
-- opts.mode         OUTLINE_MODE_*   default OUTLINE_MODE_BOTH (through walls)
-- opts.priority     number   default 48
-- opts.condition    function() -> bool   optional additional filter
-- opts.alsoWhen     function() -> bool   highlight ALSO active outside penalty
-- ----------------------------------------------------------------
function SlashMoon.Penalty.RegisterAutoReveal(ruleName, opts)
    if not opts or not opts.getEntities then
        SlashMoon.Debug("[SlashMoon.Penalty] RegisterAutoReveal: getEntities is required for rule '" .. tostring(ruleName) .. "'")
        return
    end

    for _, oldRule in ipairs(SlashMoon.Penalty._rules) do
        if oldRule.name == ruleName then return end
    end

    local defaultMode = OUTLINE_MODE_BOTH or 2

    local rule = {
        name       = ruleName,
        getEntities = opts.getEntities,
        color       = opts.color or Color(255, 200, 50),
        width       = opts.width or 3,
        maxDist     = opts.maxDist or 4000,
        mode        = opts.mode or defaultMode,
        priority    = opts.priority or 48,
        condition   = opts.condition or function() return true end,
        alsoWhen    = opts.alsoWhen or function() return false end,
        -- Internal state
        outlinedSet = {},   -- [ent] = true  — entities currently outlined
        outlined    = {},   -- ordered list for iteration
        registered  = false,
        retryCount  = 0,
        maxRetries  = 30,
        nextScan    = 0,
        cachedEntities = {},
    }

    table.insert(SlashMoon.Penalty._rules, rule)
    SlashMoon.Debug("[SlashMoon.Penalty] Rule '" .. ruleName .. "' queued, attempting OUTLINE registration...")

    -- Try to register immediately; schedule retries if library not yet loaded
    SlashMoon.Penalty._tryRegisterRule(rule)
end

-- ----------------------------------------------------------------
-- Retry loop: wait for OUTLINE library to become available
-- ----------------------------------------------------------------
function SlashMoon.Penalty._tryRegisterRule(rule)
    if OutlinedLibAvailable() then
        rule.registered = true
        SlashMoon.Debug("[SlashMoon.Penalty] OUTLINE library found — rule '" .. rule.name .. "' registered (attempt " .. (rule.retryCount + 1) .. ")")
        return
    end

    rule.retryCount = rule.retryCount + 1
    if rule.retryCount <= rule.maxRetries then
        timer.Simple(1, function()
            if rule.removed then return end   -- safety: rule was explicitly removed
            SlashMoon.Penalty._tryRegisterRule(rule)
        end)
    else
        SlashMoon.Debug("[SlashMoon.Penalty] OUTLINE library not found after " .. rule.maxRetries .. " retries for rule '" .. rule.name .. "' — will check each frame")
    end
end

-- ----------------------------------------------------------------
-- Per-frame Think: enable/disable outlines per rule
-- ----------------------------------------------------------------
MODULE:Hook("Think", "SN_PENALTY_OutlineThink", function()
    if CurTime() < nextOutlineUpdate then return end
    nextOutlineUpdate = CurTime() + 0.1
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local isLocalSurvivor = ply:Alive() and SlashMoon.Tasks.Game.IsSurvivor(ply)

    -- Resolve current phase once per frame
    local phase = "none"
    if SlashMoon.Tasks and SlashMoon.Tasks.GetPhase then
        phase = SlashMoon.Tasks.GetPhase()
    end

    local isPenalty = (phase == "penalty")
    local myPos     = ply:GetPos()

    for _, rule in ipairs(SlashMoon.Penalty._rules) do
        -- Determine if this rule should be active this frame
        local active = isLocalSurvivor and (isPenalty or rule.alsoWhen())

        if not active or not rule.condition() then
            -- Deactivate all outlined entities for this rule
            for _, ent in ipairs(rule.outlined) do
                if IsValid(ent) then
                    RemoveOutline(ent)
                end
            end
            table.Empty(rule.outlined)
            table.Empty(rule.outlinedSet)
        elseif OutlinedLibAvailable() then
            if CurTime() >= rule.nextScan then
                rule.cachedEntities = rule.getEntities() or {}
                rule.nextScan = CurTime() + 0.25
            end
            local desired = rule.cachedEntities
            local newOutlined = {}
            local newSet = {}

            for _, ent in ipairs(desired) do
                if IsValid(ent) then
                    if ent:GetPos():DistToSqr(myPos) <= (rule.maxDist * rule.maxDist) then
                        local col = ResolveColor(rule.color, ent)
                        AddOutline(ent, col, rule.width, rule.mode, rule.priority)
                        newOutlined[#newOutlined + 1] = ent
                        newSet[ent] = true
                    elseif rule.outlinedSet[ent] then
                        RemoveOutline(ent)
                    end
                end
            end

            for _, ent in ipairs(rule.outlined) do
                if IsValid(ent) and not newSet[ent] then RemoveOutline(ent) end
            end

            rule.outlined = newOutlined
            rule.outlinedSet = newSet
        end
    end
end)

SlashMoon.Debug("[SlashMoon.Penalty] Penalty highlight system loaded")

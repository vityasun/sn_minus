-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("tasks")

if not SERVER then return end

util.AddNetworkString("SN_Investigation_Assign")
util.AddNetworkString("SN_Investigation_Scan")
util.AddNetworkString("SN_Investigation_Submit")
util.AddNetworkString("SN_Investigation_Result")
util.AddNetworkString("SN_Investigation_SubmitAck")
util.AddNetworkString("SN_Investigation_ReportData")
util.AddNetworkString("SN_Investigation_ReportSubmit")
util.AddNetworkString("SN_Investigation_CloseReport")

local TASK_ID = "investigation"
local SCANNER = "sn_corpse_scanner"
local REPORT_TABLET = "sn_investigation_tablet"
local BOX = 150
local MAX_SCAN_DISTANCE = 180
local SEARCH_DURATION = 3

local function ActiveState()
    for taskID, state in pairs(SlashMoon.Tasks.ActiveState or {}) do
        if SlashMoon.Tasks.Get(taskID) == SlashMoon.Tasks.Registry[TASK_ID] then return state end
    end
end

local function IsInvestigator(ply)
    return IsValid(ply) and ply:Alive() and SlashMoon.Tasks.Game.IsSurvivor(ply) and ply:HasWeapon(SCANNER)
end

local function ItemName(class)
    local names = {
        prop_physics = "boxes",
        prop_dynamic = "equipment",
        sn_generator = "generator",
        func_door = "doors",
    }
    return names[class]
end

local function BuildClue(pos)
    local found = {}
    for _, ent in ipairs(ents.FindInBox(pos - Vector(BOX, BOX, BOX), pos + Vector(BOX, BOX, BOX))) do
        if IsValid(ent) and not ent:IsPlayer() and ent:GetClass() ~= "worldspawn" and ent:GetClass() ~= "prop_ragdoll" then
            local name = ItemName(ent:GetClass())
            if name then found[name] = true end
        end
    end
    local options = {}
    for name in pairs(found) do options[#options + 1] = name end
    return #options > 0 and options[math.random(#options)] or "field"
end

local function BuildReportOptions(correctLocation)
    local pool = { "boxes", "generator", "equipment", "doors", "field" }
    local options = { correctLocation }

    while #options < 3 do
        local candidate = pool[math.random(#pool)]
        if candidate ~= correctLocation and not table.HasValue(options, candidate) then
            options[#options + 1] = candidate
        end
    end

    for i = #options, 2, -1 do
        local j = math.random(i)
        options[i], options[j] = options[j], options[i]
    end

    return options
end

local function SpawnCorpse(pos, model, real, caseID)
    -- Use the native ragdoll entity. A scripted entity based on prop_ragdoll
    -- remains in its bind pose on some FH builds and does not expose reliable
    -- ragdoll physics.
    local ent = ents.Create("prop_ragdoll")
    if not IsValid(ent) then return end
    ent:SetModel(model)
    ent:SetPos(pos + Vector(0, 0, 24))
    ent:SetAngles(Angle(0, math.random(0, 359), 0))
    ent:SetNW2Bool("SN_InvestigationReal", real)
    ent:SetNW2String("SN_InvestigationCase", real and caseID or "")
    ent:SetNW2Bool("SN_InvestigationCorpse", true)
    ent:SetNW2Bool("SN_InvestigationSearched", false)
    ent:Spawn()
    ent:Activate()
    ent:SetCollisionGroup(COLLISION_GROUP_WEAPON)

    timer.Simple(0, function()
        if not IsValid(ent) then return end
        for index = 0, ent:GetPhysicsObjectCount() - 1 do
            local phys = ent:GetPhysicsObjectNum(index)
            if IsValid(phys) then phys:Wake() end
        end
    end)
    return ent
end

local function PickAreas(count)
    local areas = navmesh.GetAllNavAreas()
    local result = {}
    if #areas == 0 then return result end
    for i = 1, count do
        local area = areas[math.random(#areas)]
        result[#result + 1] = area:GetCenter() + Vector(0, 0, 8)
    end
    return result
end

local function GiveScanner(ply, state)
    if not IsValid(ply) or not ply:HasWeapon(SCANNER) then
        if IsValid(ply) then ply:Give(SCANNER) end
    end
    if IsValid(ply) then
        net.Start("SN_Investigation_Assign")
            net.WriteString("sn.investigation.location." .. state.clue)
            net.WriteString(state.caseID)
        net.Send(ply)
    end
end

local function IsTaskCorpse(state, ent)
    for _, corpse in ipairs(state.corpses or {}) do
        if corpse == ent then return true end
    end
    return false
end

SlashMoon.Tasks.Investigation.ServerSpawn = function(cfg, spawned)
    local positions = PickAreas(3)
    if #positions < 3 then return end
    local caseID = string.format("%d_%d", os.time(), math.random(100000, 999999))
    local state = {
        done = false,
        failed = false,
        clue = BuildClue(positions[1]),
        caseID = caseID,
        investigators = {},
        searches = {},
        corpses = {},
        submission = nil,
    }
    state.reportOptions = BuildReportOptions(state.clue)
    for i, pos in ipairs(positions) do
        local ent = SpawnCorpse(pos, SlashMoon.Tasks.Investigation.Models[math.random(#SlashMoon.Tasks.Investigation.Models)], i == 1, caseID)
        if IsValid(ent) then
            state.corpses[#state.corpses + 1] = ent
            spawned[#spawned + 1] = ent
        end
    end
    local count = math.Clamp(tonumber(cfg.investigator_count) or 1, 1, 4)
    local candidates = {}
    for _, ply in ipairs(player.GetAll()) do
        if SlashMoon.Tasks.Game.IsSurvivor(ply) then candidates[#candidates + 1] = ply end
    end
    for i = #candidates, 2, -1 do local j = math.random(i); candidates[i], candidates[j] = candidates[j], candidates[i] end
    for i = 1, math.min(count, #candidates) do
        state.investigators[candidates[i]] = true
        GiveScanner(candidates[i], state)
    end
    return state
end

SlashMoon.Tasks.Investigation.ServerThink = function(state)
    if state.submission and CurTime() >= state.submission.finishAt then
        local ok = state.submission.caseID == state.caseID
        for ply in pairs(state.investigators) do
            if IsValid(ply) then
                net.Start("SN_Investigation_Result") net.WriteBool(ok) net.Send(ply)
            end
        end
        state.submission = nil
        if ok then state.done = true end
    end
    for ply in pairs(state.investigators) do
        if not IsValid(ply) or not ply:Alive() or not ply:HasWeapon(SCANNER) then state.investigators[ply] = nil end
    end

    for ply, search in pairs(state.searches or {}) do
        local trace = IsValid(ply) and ply:GetEyeTrace()
        local valid = IsInvestigator(ply)
            and IsValid(search.corpse)
            and IsTaskCorpse(state, search.corpse)
            and ply:KeyDown(IN_USE)
            and trace.Entity == search.corpse
            and ply:GetPos():DistToSqr(trace.HitPos) <= MAX_SCAN_DISTANCE * MAX_SCAN_DISTANCE

        if not valid then
            state.searches[ply] = nil
        elseif CurTime() >= search.finishAt then
            local corpse = search.corpse
            corpse:SetNW2Bool("SN_InvestigationSearched", true)
            corpse.SN_Loot = { backpack = {}, hotbar = {} }
            corpse.SN_LootInvestigatorOnly = true
            corpse:SetNW2Bool("SN_Lootable", true)
            corpse:SetNW2Bool("SN_InvestigationLoot", true)

            local caseID = corpse:GetNW2String("SN_InvestigationCase", "")
            if corpse:GetNW2Bool("SN_InvestigationReal", false) and caseID ~= "" then
                corpse.SN_Loot.backpack[1] = "sn_investigation_passport:" .. caseID
            else
                local items = SlashMoon.Tasks.Investigation.PersonalItems or { "sn_investigation_personal_item" }
                corpse.SN_Loot.backpack[1] = items[math.random(#items)]
            end

            net.Start("SN_Inv_OpenLootUI")
                net.WriteEntity(corpse)
                net.WriteTable(corpse.SN_Loot.backpack)
                net.WriteTable(corpse.SN_Loot.hotbar)
            net.Send(ply)
            state.searches[ply] = nil
        end
    end
    local aliveInvestigator = false
    for _, ply in ipairs(player.GetAll()) do
        if IsInvestigator(ply) then aliveInvestigator = true break end
    end
    if not aliveInvestigator and not state.done then
        for _, ply in ipairs(player.GetAll()) do
            if SlashMoon.Tasks.Game.IsSurvivor(ply) then
                state.investigators[ply] = true
                GiveScanner(ply, state)
                break
            end
        end
    end
end

SlashMoon.Tasks.Investigation.ServerCleanup = function(state)
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:HasWeapon(SCANNER) then ply:StripWeapon(SCANNER) end
        if IsValid(ply) and ply:HasWeapon(REPORT_TABLET) then ply:StripWeapon(REPORT_TABLET) end
    end
    for _, scanner in ipairs(ents.FindByClass(SCANNER)) do
        if IsValid(scanner) then scanner:Remove() end
    end
    for _, tablet in ipairs(ents.FindByClass(REPORT_TABLET)) do
        if IsValid(tablet) then tablet:Remove() end
    end
end

MODULE:Hook("PlayerButtonDown", "SN_Investigation_SearchCorpse", function(ply, key)
    if key ~= KEY_E or not IsInvestigator(ply) then return end

    local trace = ply:GetEyeTrace()
    local ent = trace.Entity
    local state = ActiveState()
    if not state or not IsValid(ent) or not ent:GetNW2Bool("SN_InvestigationCorpse", false) then return end
    if ent:GetNW2Bool("SN_InvestigationSearched", false) or not IsTaskCorpse(state, ent) then return end
    if ply:GetPos():DistToSqr(trace.HitPos) > MAX_SCAN_DISTANCE * MAX_SCAN_DISTANCE then return end
    state.searches[ply] = { corpse = ent, finishAt = CurTime() + SEARCH_DURATION }
end)

MODULE:Receive("SN_Investigation_ReportData", function(_, ply)
    if not IsInvestigator(ply) then return end
    if not SlashMoon.Security.CheckRateLimit(ply, "investigation_report_open", 0.5) then return end

    local state = ActiveState()
    if not state or state.submission then return end

    if not ply:HasWeapon(REPORT_TABLET) then ply:Give(REPORT_TABLET) end
    local tablet = ply:GetWeapon(REPORT_TABLET)
    if IsValid(tablet) then tablet:SetFullView(true) end
    ply:SelectWeapon(REPORT_TABLET)

    local hasPassport = false
    for _, item in ipairs(ply.SN_Backpack or {}) do
        if item == "sn_investigation_passport:" .. state.caseID then
            hasPassport = true
            break
        end
    end

    net.Start("SN_Investigation_ReportData")
        net.WriteString("sn.investigation.location." .. state.clue)
        net.WriteBool(hasPassport)
        net.WriteUInt(#state.reportOptions, 2)
        for _, location in ipairs(state.reportOptions) do
            net.WriteString("sn.investigation.location." .. location)
        end
    net.Send(ply)
end)

MODULE:Receive("SN_Investigation_ReportSubmit", function(_, ply)
    if not IsInvestigator(ply) or not ply:HasWeapon(REPORT_TABLET) then return end
    local state = ActiveState()
    if not state or state.submission then return end

    local selectedIndex = net.ReadUInt(2)
    local selectedLocation = state.reportOptions[selectedIndex]
    if not selectedLocation then return end

    local passportIndex
    for index, item in ipairs(ply.SN_Backpack or {}) do
        if item == "sn_investigation_passport:" .. state.caseID then
            passportIndex = index
            break
        end
    end
    if not passportIndex or selectedLocation ~= state.clue then
        net.Start("SN_Investigation_SubmitAck") net.WriteBool(false) net.WriteFloat(0) net.Send(ply)
        return
    end

    table.remove(ply.SN_Backpack, passportIndex)
    SlashMoon.Tasks.SyncInventory(ply)
    ply:StripWeapon(REPORT_TABLET)
    local duration = math.Rand(4, 9)
    state.submission = { caseID = state.caseID, finishAt = CurTime() + duration }
    net.Start("SN_Investigation_SubmitAck") net.WriteBool(true) net.WriteFloat(duration) net.Send(ply)
end)

MODULE:Receive("SN_Investigation_CloseReport", function(_, ply)
    local tablet = IsValid(ply) and ply:GetWeapon(REPORT_TABLET)
    if not IsValid(tablet) then return end
    tablet:SetFullView(false)
    if ply:HasWeapon(SCANNER) then ply:SelectWeapon(SCANNER) end
end)

MODULE:Hook("PlayerDeath", "SN_Investigation_ScannerTransfer", function(dead)
    local state = ActiveState()
    if not state or not state.investigators[dead] then return end
    state.investigators[dead] = nil

    timer.Simple(0, function()
        local current = ActiveState()
        if not current or current.done then return end
        for _, candidate in ipairs(player.GetAll()) do
            if SlashMoon.Tasks.Game.IsSurvivor(candidate) and not IsInvestigator(candidate) then
                current.investigators[candidate] = true
                GiveScanner(candidate, current)
                break
            end
        end
    end)
end)

MODULE:Hook("PlayerPickupWeapon", "SN_Investigation_ScannerPickup", function(ply, weapon)
    if not IsValid(weapon) or weapon:GetClass() ~= SCANNER then return end
    local state = ActiveState()
    if state and SlashMoon.Tasks.Game.IsSurvivor(ply) then
        state.investigators[ply] = true
        GiveScanner(ply, state)
    end
end)

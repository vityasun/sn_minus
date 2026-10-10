-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("boosters")

-- ========================================================
-- Бустеры: общий список SteamID64, доступный на сервере и клиенте
--   SlashMoon.Boosters.IsBooster(plyOrSteamID64)
--   SlashMoon.Boosters.OnRefresh(fn)
-- ========================================================

SlashMoon.Boosters = SlashMoon.Boosters or {}
local Boosters = SlashMoon.Boosters

local list = {}
local callbacks = {}

function Boosters.GetList()
    return list
end

function Boosters.IsBooster(plyOrSid)
    if not MODULE:IsEnabled() then return false end
    local sid = plyOrSid
    if isentity(plyOrSid) then
        if not IsValid(plyOrSid) then return false end
        sid = plyOrSid:SteamID64()
    end
    return list[tostring(sid)] == true
end

function Boosters.OnRefresh(fn)
    if isfunction(fn) then table.insert(callbacks, fn) end
end

local function FireCallbacks()
    for _, fn in ipairs(callbacks) do SlashMoon.SafeCall(fn) end
end

local function ParseIDs(text, into)
    for id in string.gmatch(tostring(text or ""), "%d+") do
        if #id >= 15 then into[id] = true end
    end
    return into
end

if SERVER then
    util.AddNetworkString("Boosters_Sync")

    local function Send(target)
        local ids = table.GetKeys(list)
        net.Start("Boosters_Sync")
        net.WriteUInt(#ids, 16)
        for _, id in ipairs(ids) do net.WriteString(id) end
        if target then net.Send(target) else net.Broadcast() end
    end

    local function Apply(newList)
        list = newList
        SlashMoon.Debug("[Boosters] Загружено: ", table.Count(list))
        Send()
        FireCallbacks()
    end

    --- Перечитывает список (ручной + удаленный).
    function Boosters.Refresh()
        local manual = ParseIDs(MODULE:GetOption("steamids"), {})
        local url = MODULE:GetOption("url")

        if not SlashMoon.HTTP.IsValidURL(url) then
            Apply(manual)
            return
        end

        SlashMoon.HTTP.Fetch(url, function(body)
            local merged = table.Copy(manual)
            for _, line in ipairs(SlashMoon.HTTP.ParseLines(body)) do ParseIDs(line, merged) end
            Apply(merged)
        end, function(err)
            SlashMoon.Warn("[Boosters] Не удалось загрузить список: ", err)
            Apply(manual)
        end)
    end

    MODULE:Hook("Initialize", "SlashMoon.Boosters.Init", Boosters.Refresh)
    MODULE:Hook("fh_postendgame", "SlashMoon.Boosters.Refresh", Boosters.Refresh)
    MODULE:Hook("SlashMoon.OptionChanged", "SlashMoon.Boosters.Options", function(id)
        if id == "boosters" then Boosters.Refresh() end
    end)

    MODULE:Hook("PlayerInitialSpawn", "Boosters_OnJoin", function(ply)
        timer.Simple(2, function()
            if IsValid(ply) then Send(ply) end
        end)
    end)
end

if CLIENT then
    MODULE:Receive("Boosters_Sync", function()
        local count = net.ReadUInt(16)
        local newList = {}
        for _ = 1, count do newList[net.ReadString()] = true end
        list = newList
        FireCallbacks()
    end)
end

MODULE:OnEnabled(FireCallbacks)
MODULE:OnDisabled(FireCallbacks)

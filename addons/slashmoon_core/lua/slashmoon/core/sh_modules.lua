-- Written for: SlashMoon. By: VIKA & Ronni
-- ========================================================
-- SlashMoon Lib :: реестр модулей
--
-- Модуль — папка lua/slashmoon/modules/<id>/ в ЛЮБОМ аддоне.
-- Внутри обязателен манифест sh_module.lua:
--
--   SlashMoon.Modules.Register({
--       id = "example",
--       name = "Пример",
--       description = "Что делает модуль",
--       category = "Геймплей",
--       default = true,                        -- включен по умолчанию
--       files = { "sh_example.lua" },          -- порядок загрузки (необязательно)
--       entities = { "my_ent" },               -- энтити модуля (необязательно)
--       weapons = { "my_swep" },               -- оружие модуля (необязательно)
--       options = {                            -- настройки в админ-панели (необязательно)
--           { key = "cooldown", type = "number", default = 30, min = 0, max = 600, name = "Кулдаун" },
--           { key = "title", type = "string", default = "", name = "Заголовок", shared = true },
--       },
--   })
--
-- В коде модуля вместо hook.Add / timer.Create / net.Receive / concommand.Add
-- используются методы объекта модуля — тогда при отключении модуля всё
-- безопасно снимается, а при включении — возвращается:
--
--   local MODULE = SlashMoon.Modules.Get("example")
--   MODULE:Hook("Think", "Example.Think", fn)
--   MODULE:Timer("Example.Tick", 1, 0, fn)
--   MODULE:Receive("Example.Net", fn)
--   MODULE:Command("example_cmd", fn)
--   MODULE:OnDisabled(function() ... end)
-- ========================================================

SlashMoon.Modules = SlashMoon.Modules or {}
local Modules = SlashMoon.Modules

Modules.Folder = SlashMoon.Root .. "modules/"
Modules.List = Modules.List or {}          -- [id] = MODULE
Modules.ClassOwner = Modules.ClassOwner or {} -- [class энтити/оружия] = id модуля
Modules.Fired = Modules.Fired or {}        -- события инициализации, которые уже произошли

local OPTION_TYPES = { bool = true, number = true, string = true, color = true }
local LATE_INIT_EVENTS = { "Initialize", "PostGamemodeLoaded", "InitPostEntity" }

for _, event in ipairs(LATE_INIT_EVENTS) do
    hook.Add(event, "SlashMoon.Modules.Fired." .. event, function()
        Modules.Fired[event] = true
    end)
end

-- ========================================================
-- Объект модуля
-- ========================================================
local MODULE = {}
MODULE.__index = MODULE
Modules.Meta = MODULE

local function ConVarName(id)
    return "slashmoon_module_" .. id
end

function MODULE:IsEnabled()
    return self.enabled == true
end

function MODULE:GetName()
    return self.name or self.id
end

-- ---------- Хуки ----------

--- Добавляет хук, привязанный к модулю.
function MODULE:Hook(event, id, fn)
    self.hooks[event] = self.hooks[event] or {}
    self.hooks[event][id] = fn
    if self.enabled then hook.Add(event, id, fn) end
end

--- Убирает хук модуля.
function MODULE:Unhook(event, id)
    if self.hooks[event] then self.hooks[event][id] = nil end
    hook.Remove(event, id)
end

-- ---------- Таймеры ----------

local function PruneTimers(timers)
    for name, data in pairs(timers) do
        if data.reps ~= 0 and not timer.Exists(name) then timers[name] = nil end
    end
end

--- Создает именованный таймер, привязанный к модулю.
-- Бесконечные таймеры (reps = 0) пересоздаются при повторном включении модуля.
function MODULE:Timer(name, delay, reps, fn)
    self.timerCount = (self.timerCount or 0) + 1
    if self.timerCount % 64 == 0 then PruneTimers(self.timers) end

    self.timers[name] = { delay = delay, reps = reps or 1, fn = fn }
    if self.enabled then timer.Create(name, delay, reps or 1, fn) end
end

--- Удаляет таймер модуля.
function MODULE:RemoveTimer(name)
    self.timers[name] = nil
    timer.Remove(name)
end

-- ---------- Сеть ----------

function MODULE:InstallReceiver(key)
    local current = net.Receivers[key]
    self.wrappers[key] = self.wrappers[key] or function(...)
        local fn = self.receivers[key]
        if fn and self.enabled then return fn(...) end
    end

    -- Запоминаем чужой обработчик (например, гейммода), чтобы вернуть его при отключении
    if current and current ~= self.wrappers[key] and self.originals[key] == nil then
        self.originals[key] = current
    end

    net.Receivers[key] = self.wrappers[key]
end

function MODULE:UninstallReceiver(key)
    if net.Receivers[key] == self.wrappers[key] then
        net.Receivers[key] = self.originals[key]
    end
end

--- Регистрирует обработчик сетевого сообщения, привязанный к модулю.
function MODULE:Receive(name, fn)
    local key = string.lower(name)
    self.receivers[key] = fn
    if self.enabled then self:InstallReceiver(key) end
end

-- ---------- Консольные команды ----------

--- Регистрирует консольную команду, привязанную к модулю.
function MODULE:Command(name, fn, autoComplete, help, flags)
    self.commands[name] = { fn = fn, autoComplete = autoComplete, help = help, flags = flags }
    if self.enabled then concommand.Add(name, fn, autoComplete, help, flags) end
end

-- ---------- Колбэки ----------

--- Функция будет вызвана при включении модуля на лету.
function MODULE:OnEnabled(fn)
    table.insert(self.callbacks.enable, fn)
end

--- Функция будет вызвана при отключении модуля (закрытие меню, очистка состояния и т.д.).
function MODULE:OnDisabled(fn)
    table.insert(self.callbacks.disable, fn)
end

-- ---------- Опции ----------

--- Возвращает значение опции модуля.
function MODULE:GetOption(key)
    local value = self.optionValues[key]
    if value ~= nil then return value end
    local def = self.optionDefs[key]
    if def then return def.default end
end

local function CoerceOption(def, value)
    if def.type == "bool" then
        return tobool(value)
    elseif def.type == "number" then
        value = tonumber(value) or def.default or 0
        if def.min then value = math.max(def.min, value) end
        if def.max then value = math.min(def.max, value) end
        if def.decimals == 0 then value = math.Round(value) end
        return value
    elseif def.type == "color" then
        if istable(value) then
            return Color(tonumber(value.r) or 255, tonumber(value.g) or 255, tonumber(value.b) or 255, tonumber(value.a) or 255)
        end
        return def.default
    end
    value = tostring(value or "")
    if def.maxLength then value = string.sub(value, 1, def.maxLength) end
    return value
end

Modules.CoerceOption = CoerceOption

-- ---------- Включение / отключение ----------

function MODULE:Enable(runtime)
    if self.enabled then return end
    self.enabled = true

    for event, list in pairs(self.hooks) do
        for id, fn in pairs(list) do
            if isstring(id) or IsValid(id) then
                hook.Add(event, id, fn)
            else
                list[id] = nil
            end
        end
    end

    for name, data in pairs(self.timers) do
        if data.reps == 0 then timer.Create(name, data.delay, 0, data.fn) end
    end

    for key in pairs(self.receivers) do self:InstallReceiver(key) end

    for name, data in pairs(self.commands) do
        concommand.Add(name, data.fn, data.autoComplete, data.help, data.flags)
    end

    if runtime then
        -- Догоняем события инициализации, которые прошли, пока модуль был выключен
        for _, event in ipairs(LATE_INIT_EVENTS) do
            if Modules.Fired[event] and self.hooks[event] then
                for id, fn in pairs(self.hooks[event]) do
                    if isstring(id) then
                        SlashMoon.SafeCall(fn)
                    else
                        SlashMoon.SafeCall(fn, id)
                    end
                end
            end
        end

        for _, fn in ipairs(self.callbacks.enable) do SlashMoon.SafeCall(fn, self) end
    end

    hook.Run("SlashMoon.ModuleEnabled", self.id, self)
end

function MODULE:Disable()
    if not self.enabled then return end
    self.enabled = false

    for event, list in pairs(self.hooks) do
        for id in pairs(list) do hook.Remove(event, id) end
    end

    for name in pairs(self.timers) do timer.Remove(name) end
    PruneTimers(self.timers)

    for key in pairs(self.receivers) do self:UninstallReceiver(key) end

    for name in pairs(self.commands) do concommand.Remove(name) end

    for _, fn in ipairs(self.callbacks.disable) do SlashMoon.SafeCall(fn, self) end

    -- Убираем с карты энтити и оружие модуля
    if SERVER then
        for _, class in ipairs(self.entities) do
            for _, ent in ipairs(ents.FindByClass(class)) do
                if IsValid(ent) then ent:Remove() end
            end
        end
        for _, class in ipairs(self.weapons) do
            for _, ply in ipairs(player.GetAll()) do
                if ply:HasWeapon(class) then ply:StripWeapon(class) end
            end
        end
    end

    hook.Run("SlashMoon.ModuleDisabled", self.id, self)
end

-- ========================================================
-- Реестр
-- ========================================================

--- Возвращает объект модуля (создает пустой, если модуль еще не зарегистрирован).
function Modules.Get(id)
    local mod = Modules.List[id]
    if mod then return mod end

    mod = setmetatable({
        id = id,
        enabled = false,
        registered = false,
        hooks = {}, timers = {}, receivers = {}, wrappers = {}, originals = {}, commands = {},
        callbacks = { enable = {}, disable = {} },
        options = {}, optionDefs = {}, optionValues = {},
        entities = {}, weapons = {},
    }, MODULE)
    Modules.List[id] = mod
    return mod
end

--- Включен ли модуль. Несуществующий модуль считается выключенным.
function Modules.IsEnabled(id)
    local mod = Modules.List[id]
    return mod ~= nil and mod.enabled == true
end

--- Регистрирует модуль (вызывается из манифеста sh_module.lua).
function Modules.Register(def)
    assert(istable(def) and isstring(def.id) and def.id ~= "", "SlashMoon.Modules.Register: нужен id")
    assert(string.match(def.id, "^[%w_]+$"), "SlashMoon.Modules.Register: id может содержать только латиницу, цифры и _")

    local mod = Modules.Get(def.id)
    mod.name = def.name or def.id
    mod.description = def.description or ""
    mod.category = def.category or "Прочее"
    mod.author = def.author
    mod.default = def.default ~= false
    mod.order = tonumber(def.order) or 100
    mod.files = def.files
    mod.path = def.path or Modules.LoadingPath
    mod.entities = def.entities or {}
    mod.weapons = def.weapons or {}
    mod.options = {}
    mod.optionDefs = {}
    mod.registered = true

    for _, opt in ipairs(def.options or {}) do
        if isstring(opt.key) and OPTION_TYPES[opt.type] then
            mod.options[#mod.options + 1] = opt
            mod.optionDefs[opt.key] = opt
        end
    end

    for _, class in ipairs(mod.entities) do Modules.ClassOwner[class] = mod.id end
    for _, class in ipairs(mod.weapons) do Modules.ClassOwner[class] = mod.id end

    -- Начальное состояние: на сервере из config.json, на клиенте из реплицируемого convar
    local enabled
    if SERVER then
        enabled = SlashMoon.Config.IsModuleEnabled(mod.id, mod.default)
        for _, opt in ipairs(mod.options) do
            local saved = SlashMoon.Config.GetOption(mod.id, opt.key)
            if saved ~= nil then mod.optionValues[opt.key] = CoerceOption(opt, saved) end
        end
    end

    local cv = CreateConVar(ConVarName(mod.id), (enabled == nil and mod.default or enabled) and "1" or "0",
        { FCVAR_REPLICATED, FCVAR_DONTRECORD }, "SlashMoon: состояние модуля " .. mod.id)

    if SERVER then
        cv:SetBool(enabled)
    else
        enabled = cv:GetBool()
    end

    if enabled then mod:Enable(false) end
    return mod
end

--- Модули, отсортированные по order и id.
function Modules.GetSorted()
    local out = {}
    for _, mod in pairs(Modules.List) do
        if mod.registered then out[#out + 1] = mod end
    end
    table.sort(out, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.id < b.id
    end)
    return out
end

--- Загружает файлы одного модуля.
function Modules.LoadFiles(mod)
    local base = Modules.Folder .. mod.path .. "/"
    if istable(mod.files) then
        for _, rel in ipairs(mod.files) do
            SlashMoon.IncludeFile(base .. rel)
        end
    else
        SlashMoon.IncludeFolder(base, true, { ["sh_module.lua"] = true })
    end
end

--- Находит и загружает все модули из lua/slashmoon/modules/ (всех аддонов).
function Modules.LoadAll()
    local _, folders = file.Find(Modules.Folder .. "*", "LUA", "nameasc")

    for _, folder in ipairs(folders or {}) do
        local manifest = Modules.Folder .. folder .. "/sh_module.lua"
        if file.Exists(manifest, "LUA") then
            Modules.LoadingPath = folder
            SlashMoon.IncludeFile(manifest, "sh")
            Modules.LoadingPath = nil
        end
    end

    for _, mod in ipairs(Modules.GetSorted()) do
        if mod.path and not mod.loaded then
            mod.loaded = true
            Modules.LoadFiles(mod)
        end
    end

    hook.Run("SlashMoon.ModulesLoaded")
end

-- ========================================================
-- Синхронизация состояния с клиентами
-- ========================================================

-- Собирает состояние модулей и shared-опций для клиентов
local function BuildSyncData()
    local data = {}
    for id, mod in pairs(Modules.List) do
        if mod.registered then
            local opts = {}
            for _, opt in ipairs(mod.options) do
                if opt.shared then opts[opt.key] = mod:GetOption(opt.key) end
            end
            data[id] = { e = mod.enabled, o = opts }
        end
    end
    return data
end

if SERVER then
    util.AddNetworkString("SlashMoon.Modules.Sync")
    util.AddNetworkString("SlashMoon.Modules.RequestSync")

    --- Отправляет состояние модулей игроку (или всем, если target = nil).
    function Modules.Sync(target)
        net.Start("SlashMoon.Modules.Sync")
        SlashMoon.JSON.NetWrite(BuildSyncData())
        if target then net.Send(target) else net.Broadcast() end
    end

    net.Receive("SlashMoon.Modules.RequestSync", function(_, ply)
        if not SlashMoon.Security.CheckRateLimit(ply, "slashmoon_modules_sync", 5) then return end
        Modules.Sync(ply)
    end)

    --- Включает/выключает модуль на лету и сохраняет состояние в config.json.
    -- @return boolean изменилось ли состояние
    function Modules.SetEnabled(id, enabled)
        local mod = Modules.List[id]
        if not mod or not mod.registered then return false end
        enabled = enabled == true
        if mod.enabled == enabled then return false end

        if enabled then mod:Enable(true) else mod:Disable() end

        SlashMoon.Config.SetModuleEnabled(id, enabled)
        GetConVar(ConVarName(id)):SetBool(enabled)
        Modules.Sync()

        SlashMoon.Log("Модуль '", id, "' ", enabled and "включен" or "отключен")
        return true
    end

    --- Изменяет опцию модуля и сохраняет ее в config.json.
    function Modules.SetOption(id, key, value)
        local mod = Modules.List[id]
        local def = mod and mod.optionDefs[key]
        if not def then return false end

        value = CoerceOption(def, value)
        mod.optionValues[key] = value
        SlashMoon.Config.SetOption(id, key, def.type == "color" and { r = value.r, g = value.g, b = value.b, a = value.a } or value)

        hook.Run("SlashMoon.OptionChanged", id, key, value)
        if def.shared then Modules.Sync() end
        return true
    end

    -- Блокируем спавн энтити и оружия выключенных модулей
    local function BlockDisabled(_, class)
        local owner = Modules.ClassOwner[class]
        if owner and not Modules.IsEnabled(owner) then return false end
    end
    hook.Add("PlayerSpawnSENT", "SlashMoon.Modules.Block", BlockDisabled)
    hook.Add("PlayerSpawnSWEP", "SlashMoon.Modules.Block", BlockDisabled)
    hook.Add("PlayerGiveSWEP", "SlashMoon.Modules.Block", BlockDisabled)
    hook.Add("PlayerCanPickupWeapon", "SlashMoon.Modules.Block", function(_, wep)
        if IsValid(wep) then return BlockDisabled(nil, wep:GetClass()) end
    end)
else
    net.Receive("SlashMoon.Modules.Sync", function()
        local data = SlashMoon.JSON.NetRead({})
        for id, state in pairs(data) do
            local mod = Modules.List[id]
            if mod and mod.registered then
                for key, value in pairs(state.o or {}) do
                    local def = mod.optionDefs[key]
                    if def then mod.optionValues[key] = CoerceOption(def, value) end
                end
                if state.e and not mod.enabled then
                    mod:Enable(true)
                elseif not state.e and mod.enabled then
                    mod:Disable()
                end
            end
        end
        hook.Run("SlashMoon.ModulesSynced")
    end)

    hook.Add("InitPostEntity", "SlashMoon.Modules.RequestSync", function()
        net.Start("SlashMoon.Modules.RequestSync")
        net.SendToServer()
    end)
end

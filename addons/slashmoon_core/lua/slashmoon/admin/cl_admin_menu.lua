-- Written for: SlashMoon. By: VIKA & Ronni
-- ========================================================
-- SlashMoon Lib :: админ-панель конфигурации (клиент)
-- Построена только на компонентах SlashMoon.UI.
-- ========================================================

SlashMoon.AdminMenu = SlashMoon.AdminMenu or {}
local AdminMenu = SlashMoon.AdminMenu
local UI = SlashMoon.UI

local cvLive = CreateClientConVar("slashmoon_menu_live", "1", true, false, "Применять изменения в панели SlashMoon сразу")

AdminMenu.Pending = AdminMenu.Pending or { modules = {}, options = {} }

local function PendingCount()
    local n = table.Count(AdminMenu.Pending.modules)
    for _, opts in pairs(AdminMenu.Pending.options) do n = n + table.Count(opts) end
    return n
end

local function ClearPending()
    AdminMenu.Pending = { modules = {}, options = {} }
end

--- Отправляет накопленные изменения на сервер.
function AdminMenu.Apply()
    if PendingCount() == 0 then return end
    net.Start("SlashMoon.AdminMenu.Apply")
    SlashMoon.JSON.NetWrite(AdminMenu.Pending)
    net.SendToServer()
    ClearPending()
    AdminMenu.RefreshToolbar()
end

local function QueueModule(id, enabled)
    AdminMenu.Pending.modules[id] = enabled
    if cvLive:GetBool() then AdminMenu.Apply() else AdminMenu.RefreshToolbar() end
end

local function QueueOption(id, key, value)
    -- Ответ сервера не должен пересоздавать редакторы, пока админ с ними работает
    AdminMenu.KeepDetails = true
    AdminMenu.Pending.options[id] = AdminMenu.Pending.options[id] or {}
    AdminMenu.Pending.options[id][key] = value
    if cvLive:GetBool() then AdminMenu.Apply() else AdminMenu.RefreshToolbar() end
end

-- Текущее значение с учетом неотправленных изменений
local function EffectiveEnabled(mod)
    local pending = AdminMenu.Pending.modules[mod.id]
    if pending ~= nil then return pending end
    return mod.enabled
end

local function EffectiveOption(mod, opt)
    local pending = AdminMenu.Pending.options[mod.id]
    if pending and pending[opt.key] ~= nil then return pending[opt.key] end
    return opt.value
end

local function ToColor(value, fallback)
    if istable(value) then return Color(value.r or 255, value.g or 255, value.b or 255, value.a or 255) end
    return fallback or color_white
end

-- ========================================================
-- Редакторы опций
-- ========================================================
local Editors = {}

function Editors.bool(row, mod, opt, canEdit)
    local toggle = row:SetControl(UI.Create("Toggle"))
    toggle:SetValue(EffectiveOption(mod, opt) == true, true)
    toggle:SnapAnimation()
    toggle:SetEnabled(canEdit)
    toggle.OnChange = function(_, value) QueueOption(mod.id, opt.key, value) end
end

function Editors.number(row, mod, opt, canEdit)
    local holder = row:SetControl(UI.Create("Container"), UI.Scale(320))
    holder:SetTall(UI.Scale(40))

    local entry = UI.Create("TextEntry", holder)
    entry:Dock(RIGHT)
    entry:SetWide(UI.Scale(80))
    entry:SetNumeric(true)
    entry:SetEnabled(canEdit)

    local value = tonumber(EffectiveOption(mod, opt)) or tonumber(opt.default) or 0
    entry:SetValue(tostring(value))

    if opt.min and opt.max then
        local bar = UI.Create("SliderBar", holder)
        bar:Dock(FILL)
        bar:DockMargin(0, 0, UI.Scale(10), 0)
        bar:SetMinMax(opt.min, opt.max)
        bar:SetDecimals(opt.decimals or 0)
        bar:SetValue(value, true)
        bar:SetEnabled(canEdit)
        bar.OnValueChanged = function(_, v) entry:SetValue(tostring(v)) end
        bar.OnValueReleased = function(_, v) QueueOption(mod.id, opt.key, v) end
        entry.OnEnter = function(s)
            local v = tonumber(s:GetValue()) or value
            bar:SetValue(v, true)
            QueueOption(mod.id, opt.key, v)
        end
    else
        entry:Dock(FILL)
        entry.OnEnter = function(s)
            QueueOption(mod.id, opt.key, tonumber(s:GetValue()) or value)
        end
    end
end

function Editors.string(row, mod, opt, canEdit)
    local entry = row:SetControl(UI.Create("TextEntry"), UI.Scale(320))
    entry:SetValue(tostring(EffectiveOption(mod, opt) or ""))
    entry:SetPlaceholderText(tostring(opt.default or ""))
    entry:SetEnabled(canEdit)
    entry.OnEnter = function(s) QueueOption(mod.id, opt.key, s:GetValue()) end
    entry.OnLoseFocus = function(s)
        if s:GetValue() ~= tostring(EffectiveOption(mod, opt) or "") then
            QueueOption(mod.id, opt.key, s:GetValue())
        end
    end
end

function Editors.color(row, mod, opt, canEdit)
    row:SetTall(UI.Scale(200))
    local picker = row:SetControl(UI.Create("ColorPicker"), UI.Scale(320))
    picker:SetTall(UI.Scale(180))
    picker:SetColor(ToColor(EffectiveOption(mod, opt), ToColor(opt.default)))
    picker:SetEnabled(canEdit)
    picker.ValueChanged = function(_, col)
        timer.Create("SlashMoon.AdminMenu.Color", 0.4, 1, function()
            QueueOption(mod.id, opt.key, { r = col.r, g = col.g, b = col.b, a = col.a })
        end)
    end
end

-- ========================================================
-- Построение окна
-- ========================================================

function AdminMenu.RefreshToolbar()
    local frame = AdminMenu.Frame
    if not IsValid(frame) then return end
    local n = PendingCount()
    frame.ApplyBtn:SetText(n > 0 and ("ПРИМЕНИТЬ (" .. n .. ")") or "ПРИМЕНИТЬ")
    frame.ApplyBtn:SetEnabled(n > 0 and AdminMenu.Data.canEdit)
    frame.ResetBtn:SetEnabled(n > 0)
end

local function FindModule(id)
    for _, mod in ipairs(AdminMenu.Data.modules or {}) do
        if mod.id == id then return mod end
    end
end

function AdminMenu.BuildDetails()
    local frame = AdminMenu.Frame
    local details = frame.Details
    details:Clear()

    local mod = FindModule(AdminMenu.Selected)
    if not mod then
        local hint = UI.Create("Label", details)
        hint:Dock(FILL)
        hint:SetContentAlignment(5)
        hint:SetMuted(true)
        hint:SetText("Выберите модуль слева, чтобы увидеть подробности и настройки")
        return
    end

    local canEdit = AdminMenu.Data.canEdit
    local scroll = UI.Create("Scroll", details)
    scroll:Dock(FILL)

    local title = UI.Create("Header", scroll)
    title:Dock(TOP)
    title:SetText(mod.name)
    title:SetDescription(mod.id .. "  •  " .. mod.category .. (mod.author and ("  •  " .. mod.author) or ""))

    local desc = UI.Create("Label", scroll)
    desc:Dock(TOP)
    desc:DockMargin(UI.Scale(14), UI.Scale(4), UI.Scale(8), UI.Scale(12))
    desc:SetWrap(true)
    desc:SetAutoStretchVertical(true)
    desc:SetMuted(true)
    desc:SetText(mod.description ~= "" and mod.description or "Описание отсутствует.")

    local stateRow = UI.Create("SettingRow", scroll)
    stateRow:Dock(TOP)
    stateRow:SetTitle("Модуль включен")
    stateRow:SetDescription("По умолчанию: " .. (mod.default and "включен" or "выключен"))
    local toggle = stateRow:SetControl(UI.Create("Toggle"))
    toggle:SetValue(EffectiveEnabled(mod), true)
    toggle:SnapAnimation()
    toggle:SetEnabled(canEdit)
    toggle.OnChange = function(_, value)
        QueueModule(mod.id, value)
        AdminMenu.BuildList()
    end

    if #mod.options > 0 then
        local header = UI.Create("Header", scroll)
        header:Dock(TOP)
        header:DockMargin(0, UI.Scale(10), 0, UI.Scale(4))
        header:SetText("Настройки")

        for _, opt in ipairs(mod.options) do
            local row = UI.Create("SettingRow", scroll)
            row:Dock(TOP)
            row:SetTitle(opt.name)
            row:SetDescription(opt.description or ("по умолчанию: " .. (opt.type == "color" and "цвет" or tostring(opt.default))))
            local editor = Editors[opt.type]
            if editor then editor(row, mod, opt, canEdit) end
        end
    end

    local classes = {}
    for _, c in ipairs(mod.entities or {}) do classes[#classes + 1] = c end
    for _, c in ipairs(mod.weapons or {}) do classes[#classes + 1] = c end
    if #classes > 0 then
        local header = UI.Create("Header", scroll)
        header:Dock(TOP)
        header:DockMargin(0, UI.Scale(10), 0, UI.Scale(4))
        header:SetText("Энтити и оружие")
        header:SetDescription("Удаляются с карты и блокируются для спавна при отключении модуля")

        local list = UI.Create("Label", scroll)
        list:Dock(TOP)
        list:DockMargin(UI.Scale(14), 0, UI.Scale(8), UI.Scale(8))
        list:SetFont("SlashMoon.Small")
        list:SetMuted(true)
        list:SetWrap(true)
        list:SetAutoStretchVertical(true)
        list:SetText(table.concat(classes, ", "))
    end
end

function AdminMenu.BuildList()
    local frame = AdminMenu.Frame
    if not IsValid(frame) then return end

    local scroll = frame.List
    scroll:Clear()

    local query = string.lower(string.Trim(frame.Search:GetValue() or ""))
    local canEdit = AdminMenu.Data.canEdit
    local byCategory, categories = {}, {}

    for _, mod in ipairs(AdminMenu.Data.modules or {}) do
        local haystack = string.lower(mod.name .. " " .. mod.id .. " " .. mod.description)
        if query == "" or string.find(haystack, query, 1, true) then
            if not byCategory[mod.category] then
                byCategory[mod.category] = {}
                categories[#categories + 1] = mod.category
            end
            table.insert(byCategory[mod.category], mod)
        end
    end
    table.sort(categories)

    if #categories == 0 then
        local empty = UI.Create("Label", scroll)
        empty:Dock(TOP)
        empty:SetMuted(true)
        empty:SetText("Ничего не найдено")
        return
    end

    for _, category in ipairs(categories) do
        local header = UI.Create("Header", scroll)
        header:Dock(TOP)
        header:SetText(category)
        header:DockMargin(0, UI.Scale(4), 0, UI.Scale(4))

        for _, mod in ipairs(byCategory[category]) do
            local row = UI.Create("SettingRow", scroll)
            row:Dock(TOP)
            row:SetTitle(mod.name)
            row:SetDescription(mod.id)
            row:SetCursor("hand")
            if mod.id == AdminMenu.Selected then row:SetAccentBar(true) end
            if AdminMenu.Pending.modules[mod.id] ~= nil then row:SetOutline("Warning") end

            row.OnMousePressed = function()
                AdminMenu.Selected = mod.id
                AdminMenu.BuildList()
                AdminMenu.BuildDetails()
            end

            local toggle = row:SetControl(UI.Create("Toggle"))
            toggle:SetValue(EffectiveEnabled(mod), true)
            toggle:SnapAnimation()
            toggle:SetEnabled(canEdit)
            toggle.OnChange = function(_, value)
                QueueModule(mod.id, value)
                row:SetOutline(not cvLive:GetBool() and "Warning" or nil)
                if AdminMenu.Selected == mod.id then AdminMenu.BuildDetails() end
            end
        end
    end
end

function AdminMenu.Build()
    if IsValid(AdminMenu.Frame) then AdminMenu.Frame:Remove() end
    local data = AdminMenu.Data

    local w, h = UI.WindowSize(0.62, 0.78, 1400, 900)
    local frame = UI.Create("Frame")
    frame:SetSize(w, h)
    frame:Center()
    frame:SetHeader("SLASHMOON", "панель конфигурации • v" .. tostring(data.version))
    AdminMenu.Frame = frame

    -- Панель инструментов
    local toolbar = UI.Create("Container", frame)
    toolbar:Dock(TOP)
    toolbar:SetTall(UI.Scale(44))
    toolbar:DockMargin(0, 0, 0, UI.Scale(10))

    local search = UI.Create("TextEntry", toolbar)
    search:Dock(LEFT)
    search:SetWide(UI.Scale(380))
    search:SetPlaceholderText("Поиск модуля...")
    search:SetUpdateOnType(true)
    search.OnValueChange = function() AdminMenu.BuildList() end
    frame.Search = search

    local apply = UI.Create("Button", toolbar)
    apply:Dock(RIGHT)
    apply:SetWide(UI.Scale(220))
    apply:SetVariant("primary")
    apply.DoClick = AdminMenu.Apply
    frame.ApplyBtn = apply

    local reset = UI.Create("Button", toolbar)
    reset:Dock(RIGHT)
    reset:SetWide(UI.Scale(160))
    reset:DockMargin(0, 0, UI.Scale(10), 0)
    reset:SetVariant("ghost")
    reset:SetText("ОТМЕНИТЬ")
    reset.DoClick = function()
        ClearPending()
        AdminMenu.RefreshToolbar()
        AdminMenu.BuildList()
        AdminMenu.BuildDetails()
    end
    frame.ResetBtn = reset

    local live = UI.Create("Checkbox", toolbar)
    live:Dock(RIGHT)
    live:DockMargin(0, 0, UI.Scale(16), 0)
    live:SetLabel("Применять сразу")
    live:SizeToContents()
    live:SetChecked(cvLive:GetBool(), true)
    live.OnChange = function(_, value)
        RunConsoleCommand("slashmoon_menu_live", value and "1" or "0")
        if value then AdminMenu.Apply() end
    end

    -- Нижняя строка состояния
    local footer = UI.Create("Label", frame)
    footer:Dock(BOTTOM)
    footer:DockMargin(0, UI.Scale(8), 0, 0)
    footer:SetFont("SlashMoon.Small")
    footer:SetMuted(true)
    local deps = #(data.detected or {}) > 0 and table.concat(data.detected, ", ") or "нет"
    footer:SetText(string.format("Админ-система: %s   •   Найдены аддоны: %s   •   Конфиг: %s%s",
        string.upper(data.adminSystem or "default"), deps, data.configPath or "", data.canEdit and "" or "   •   только просмотр"))

    -- Тело: список модулей + подробности
    local body = UI.Create("Container", frame)
    body:Dock(FILL)

    local list = UI.Create("Scroll", body)
    list:Dock(LEFT)
    list:SetWide(math.floor(w * 0.45))
    frame.List = list

    local details = UI.Create("Panel", body)
    details:Dock(FILL)
    details:DockMargin(UI.Scale(12), 0, 0, 0)
    details:SetBackground("Header")
    details:DockPadding(UI.Scale(14), UI.Scale(10), UI.Scale(14), UI.Scale(10))
    frame.Details = details

    AdminMenu.RefreshToolbar()
    AdminMenu.BuildList()
    AdminMenu.BuildDetails()
end

net.Receive("SlashMoon.AdminMenu.Data", function()
    local data = SlashMoon.JSON.NetRead({})
    AdminMenu.Data = data

    if data.open then
        ClearPending()
        AdminMenu.Build()
    elseif IsValid(AdminMenu.Frame) then
        AdminMenu.RefreshToolbar()
        AdminMenu.BuildList()
        if not AdminMenu.KeepDetails then AdminMenu.BuildDetails() end
    end
    AdminMenu.KeepDetails = false

    if data.notice and IsValid(AdminMenu.Frame) then
        UI.Toast(data.notice, "success", 3)
    end
end)

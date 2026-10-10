-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("escmenu")

-- ========================================================
-- Настройки игрока (открываются из меню паузы)
-- ========================================================

SlashMoon.EscMenu = SlashMoon.EscMenu or {}
local EscMenu = SlashMoon.EscMenu
local UI = SlashMoon.UI

-- ==========================================
-- ЛОКАЛЬНЫЕ КОНВАРЫ
-- ==========================================
CreateClientConVar("sn_thirdperson", "0", true, false, "Включить третье лицо")
CreateClientConVar("sn_ui_sounds_on", "1", true, false, "Включить звуки интерфейса")
CreateClientConVar("sn_inventory_key", tostring(KEY_I), true, false, "Клавиша открытия инвентаря")
if not GetConVar("sn_hints_enabled") then
    CreateClientConVar("sn_hints_enabled", "1", true, false, "Показывать игровые подсказки")
end

-- Прицел (используется модулем movement)
CreateClientConVar("sn_crosshair_r", "255", true, false)
CreateClientConVar("sn_crosshair_g", "255", true, false)
CreateClientConVar("sn_crosshair_b", "255", true, false)
CreateClientConVar("sn_crosshair_a", "200", true, false)
CreateClientConVar("sn_crosshair_size", "4", true, false)
CreateClientConVar("sn_crosshair_gap", "4", true, false)
CreateClientConVar("sn_crosshair_dot", "1", true, false)
CreateClientConVar("sn_crosshair_shadow", "1", true, false)
CreateClientConVar("sn_crosshair_spread", "1", true, false)

-- Отключение звуков интерфейса библиотеки
MODULE:Hook("SlashMoon.UI.ShouldPlaySound", "SlashMoon.EscMenu.UISounds", function()
    local cv = GetConVar("sn_ui_sounds_on")
    if cv and not cv:GetBool() then return false end
end)

local function SetConVarValue(name, value)
    if isbool(value) then value = value and "1" or "0" end
    RunConsoleCommand(name, tostring(value))
end

-- ==========================================
-- ПОСТРОИТЕЛИ ЭЛЕМЕНТОВ
-- ==========================================
local function AddHeader(parent, title)
    local header = UI.Create("Header", parent)
    header:Dock(TOP)
    header:DockMargin(0, UI.Scale(10), 0, UI.Scale(6))
    header:SetText(title)
    return header
end

-- Переключатель, привязанный к convar (inverse — галочка означает значение 0)
local function AddToggle(parent, title, cvarName, inverse, description)
    local cv = GetConVar(cvarName)
    if not cv then return end

    local row = UI.Create("SettingRow", parent)
    row:Dock(TOP)
    row:SetTitle(title)
    if description then row:SetDescription(description) end

    local toggle = row:SetControl(UI.Create("Toggle"))
    local value = cv:GetBool()
    if inverse then value = not value end
    toggle:SetValue(value, true)
    toggle:SnapAnimation()
    toggle.OnChange = function(_, checked)
        if inverse then checked = not checked end
        SetConVarValue(cvarName, checked)
    end
    return toggle
end

local function AddSlider(parent, title, cvarName, minVal, maxVal, decimals)
    if not GetConVar(cvarName) then return end

    local slider = UI.Create("Slider", parent)
    slider:Dock(TOP)
    slider:DockMargin(UI.Scale(10), 0, UI.Scale(10), UI.Scale(6))
    slider:SetText(title)
    slider:SetMinMax(minVal or 0, maxVal or 1)
    slider:SetDecimals(decimals or 2)
    slider:SetConVar(cvarName)
    return slider
end

local function AddKeyBinder(parent, title, cvarName, defaultKey)
    local row = UI.Create("SettingRow", parent)
    row:Dock(TOP)
    row:SetTitle(title)

    local binder = row:SetControl(UI.Create("Binder"), UI.Scale(240))
    local cv = GetConVar(cvarName)
    local currentKey = cv and cv:GetInt() or defaultKey
    if not input.GetKeyName(currentKey) then currentKey = defaultKey end
    binder:SetValue(currentKey)

    binder.OnChange = function(self, keyCode)
        if not input.GetKeyName(keyCode) then
            self:SetValue(defaultKey)
            keyCode = defaultKey
        end
        SetConVarValue(cvarName, keyCode)
    end
    return binder
end

local function AddColorPicker(parent, title, cvarR, cvarG, cvarB, cvarA)
    local row = UI.Create("SettingRow", parent)
    row:Dock(TOP)
    row:SetTall(UI.Scale(220))
    row:SetTitle(title)

    local mixer = row:SetControl(UI.Create("ColorPicker"), UI.Scale(360))
    mixer:SetTall(UI.Scale(200))
    mixer:SetAlphaBar(true)

    local function Get(name, fallback)
        local cv = GetConVar(name)
        return cv and cv:GetInt() or fallback
    end
    mixer:SetColor(Color(Get(cvarR, 255), Get(cvarG, 255), Get(cvarB, 255), Get(cvarA, 200)))

    mixer.ValueChanged = function(_, col)
        SetConVarValue(cvarR, col.r)
        SetConVarValue(cvarG, col.g)
        SetConVarValue(cvarB, col.b)
        SetConVarValue(cvarA, col.a)
    end
    return mixer
end

-- ==========================================
-- ВКЛАДКИ
-- ==========================================
local function BuildGeneral(content)
    local scroll = UI.Create("Scroll", content)
    scroll:Dock(FILL)

    AddHeader(scroll, "РЕЖИМ")
    AddToggle(scroll, "Третье лицо", "sn_thirdperson")
    AddToggle(scroll, "Отказаться от роли аниматроника", "fh_opt_out_anim")
    AddToggle(scroll, "Третье лицо у аниматроников", "fh_thirdperson")
    AddToggle(scroll, "Подсвечивать союзников", "fh_halo_teammates")

    AddHeader(scroll, "ГРАФИКА")
    AddToggle(scroll, "Bloom (свечение карты)", "sn_postprocess_bloom")

    AddHeader(scroll, "ПРИЦЕЛ")
    AddColorPicker(scroll, "Цвет и прозрачность", "sn_crosshair_r", "sn_crosshair_g", "sn_crosshair_b", "sn_crosshair_a")
    AddSlider(scroll, "Длина палочек", "sn_crosshair_size", 0, 20, 0)
    AddSlider(scroll, "Отступ от центра", "sn_crosshair_gap", 0, 20, 0)
    AddToggle(scroll, "Точка по центру", "sn_crosshair_dot")
    AddToggle(scroll, "Тень (для читаемости)", "sn_crosshair_shadow")
    AddToggle(scroll, "Динамический разброс", "sn_crosshair_spread")

    AddHeader(scroll, "ЗВУК")
    AddSlider(scroll, "Громкость танцев", "wos_dance_music_vol", 0, 1, 2)
    AddSlider(scroll, "Громкость LMS", "fh_lms_volume", 0, 1, 2)
    AddToggle(scroll, "Слышать наблюдателей", "proximity_hear_spectators")
    AddToggle(scroll, "Музыка танцев", "wos_dance_music_on")
    AddToggle(scroll, "Звуки интерфейса", "sn_ui_sounds_on")

    -- snd_mute_losefocus нельзя менять через RunConsoleCommand напрямую
    local muteRow = UI.Create("SettingRow", scroll)
    muteRow:Dock(TOP)
    muteRow:SetTitle("Без звука вне окна игры (Alt-Tab)")
    local muteToggle = muteRow:SetControl(UI.Create("Toggle"))
    local muteCv = GetConVar("snd_mute_losefocus")
    muteToggle:SetValue(muteCv and muteCv:GetBool() or false, true)
    muteToggle:SnapAnimation()
    muteToggle.OnChange = function(_, checked)
        local cmd = "snd_mute_losefocus " .. (checked and "1" or "0")
        if isfunction(RunGameUICommand) then
            RunGameUICommand(cmd)
        else
            LocalPlayer():ConCommand(cmd)
        end
    end
end

local HINT_ROWS = {
    { "F3", "Открепить мышку и открыть меню заданий" },
    { "F4", "Открыть хаб" },
    { "ДВОЙНОЙ КЛИК", "Быстрая экипировка предмета" },
    { "H", "Открыть колесо эмоций" },
    { "F8", "Показать или скрыть подсказки" },
    { "ALT + ЛКМ", "Поставить метку для команды" },
}

local function BuildBinds(content)
    local scroll = UI.Create("Scroll", content)
    scroll:Dock(FILL)

    AddHeader(scroll, "БИНДЫ")
    AddKeyBinder(scroll, "Открыть / закрыть инвентарь", "sn_inventory_key", KEY_I)

    AddHeader(scroll, "ПОДСКАЗКИ")
    AddToggle(scroll, "Показывать подсказки", "sn_hints_enabled")

    for _, hint in ipairs(HINT_ROWS) do
        local row = UI.Create("SettingRow", scroll)
        row:Dock(TOP)
        row:SetTall(UI.Scale(48))
        row:SetAccentBar(true)
        row:SetTitle(hint[1])
        local label = row:SetControl(UI.Create("Label"), UI.Scale(520))
        label:SetFont("SlashMoon.Small")
        label:SetMuted(true)
        label:SetContentAlignment(6)
        label:SetText(hint[2])
    end
end

-- ==========================================
-- ОКНО
-- ==========================================
function EscMenu.OpenSettings()
    if IsValid(EscMenu.SettingsFrame) then EscMenu.SettingsFrame:Remove() end

    local w, h = UI.WindowSize(0.45, 0.8, 1100, 900)
    local frame = UI.Create("Frame")
    frame:SetSize(w, h)
    frame:Center()
    frame:SetHeader("НАСТРОЙКИ")
    EscMenu.SettingsFrame = frame

    local tabs = UI.Create("Tabs", frame)
    tabs:Dock(FILL)
    tabs:AddTab("ОСНОВНЫЕ", BuildGeneral)
    tabs:AddTab("БИНДЫ И ПОДСКАЗКИ", BuildBinds)
end

MODULE:Command("sn_settings", function() EscMenu.OpenSettings() end, nil, "SlashMoon: открыть настройки игрока")

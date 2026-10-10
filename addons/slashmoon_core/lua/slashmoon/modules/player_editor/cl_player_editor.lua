-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("player_editor")

-- ========================================================
-- Редактор персонажа: интерфейс (SlashMoon.UI)
-- ========================================================

local Editor = SlashMoon.PlayerEditor
local UI = SlashMoon.UI
local Draw = UI.Draw
local colors = UI.Colors

local PRIVATE_COLOR = Color(255, 210, 60)
local DEFAULT_ANIMATIONS = { "idle_all_01", "menu_walk", "pose_standing_02", "pose_standing_03", "idle_fist" }

local selectedModel = nil
local PrivateModels = {}

MODULE:Hook("PostGamemodeLoaded", "ronni_pe_convars", function()
    local flags = { FCVAR_ARCHIVE, FCVAR_USERINFO, FCVAR_DONTRECORD }
    if not ConVarExists("cl_playercolor") then CreateConVar("cl_playercolor", "0.24 0.34 0.41", flags) end
    if not ConVarExists("cl_weaponcolor") then CreateConVar("cl_weaponcolor", "0.30 1.80 2.10", flags) end
    if not ConVarExists("cl_playerskin") then CreateConVar("cl_playerskin", "0", flags) end
    if not ConVarExists("cl_playerbodygroups") then CreateConVar("cl_playerbodygroups", "0", flags) end
end)

local function RefreshButtons()
    if IsValid(Editor.Frame) and Editor.Frame.UpdatePrivateButton then Editor.Frame.UpdatePrivateButton() end
end

MODULE:Receive("ronni_pe_send_private_list", function()
    PrivateModels = net.ReadTable()
    RefreshButtons()
end)

if SlashMoon.Boosters then SlashMoon.Boosters.OnRefresh(RefreshButtons) end

local function ModelPath(modelName)
    return string.lower(player_manager.TranslatePlayerModel(modelName))
end

local function IsModelLocked(modelName)
    if not modelName then return false end
    local owner = PrivateModels[ModelPath(modelName)]
    return owner ~= nil and owner ~= LocalPlayer():SteamID64()
end

local function IsModelOwnedByMe(modelName)
    return modelName ~= nil and PrivateModels[ModelPath(modelName)] == LocalPlayer():SteamID64()
end

local function ApplyModel()
    if not selectedModel then return end
    if IsModelLocked(selectedModel) then
        UI.Toast("Эта модель приватизирована!", "error")
        return
    end

    RunConsoleCommand("cl_playermodel", selectedModel)

    net.Start("ronni_pe_apply_model")
    net.WriteString(selectedModel)
    net.WriteInt(GetConVar("cl_playerskin"):GetInt(), 8)
    net.WriteString(GetConVar("cl_playerbodygroups"):GetString())
    net.WriteVector(Vector(GetConVar("cl_playercolor"):GetString()))
    net.WriteVector(Vector(GetConVar("cl_weaponcolor"):GetString()))
    net.SendToServer()

    UI.Toast("Модель применена", "success", 2)
end

-- Колонка с заголовком
local function Column(parent, title)
    local col = UI.Create("Panel", parent)
    col:SetBackground("Header")
    col:DockPadding(UI.Scale(10), UI.Scale(6), UI.Scale(10), UI.Scale(10))
    local header = UI.Create("Header", col)
    header:Dock(TOP)
    header:SetText(title)
    return col
end

local function BuildMenu()
    if IsValid(Editor.Frame) then Editor.Frame:Remove() end

    local w, h = UI.WindowSize(0.7, 0.75, 1500, 950)
    local frame = UI.Create("Frame")
    frame:SetSize(w, h)
    frame:Center()
    frame:SetHeader("РЕДАКТОР ПЕРСОНАЖА")
    Editor.Frame = frame

    local gap = UI.Scale(10)
    local inner = w - UI.Scale(24) - gap * 2

    -- ═══ Колонка 1: модели ═══
    local left = Column(frame, "МОДЕЛИ")
    left:Dock(LEFT)
    left:SetWide(math.floor(inner * 0.42))

    local search = UI.Create("TextEntry", left)
    search:Dock(TOP)
    search:DockMargin(0, 0, 0, UI.Scale(8))
    search:SetPlaceholderText("Поиск...")
    search:SetUpdateOnType(true)

    local modelScroll = UI.Create("Scroll", left)
    modelScroll:Dock(FILL)

    local grid = UI.Create("Grid", modelScroll)
    grid:Dock(FILL)
    grid:SetSpaceX(UI.Scale(6))
    grid:SetSpaceY(UI.Scale(6))

    -- ═══ Колонка 2: предпросмотр ═══
    local mid = Column(frame, "ПРЕДПРОСМОТР")
    mid:Dock(LEFT)
    mid:DockMargin(gap, 0, 0, 0)
    mid:SetWide(math.floor(inner * 0.29))

    local privBtn = UI.Create("Button", mid)
    privBtn:Dock(BOTTOM)
    privBtn:DockMargin(0, UI.Scale(8), 0, 0)

    local applyBtn = UI.Create("Button", mid)
    applyBtn:Dock(BOTTOM)
    applyBtn:DockMargin(0, UI.Scale(8), 0, 0)
    applyBtn:SetVariant("primary")
    applyBtn:SetText("ПРИМЕНИТЬ МОДЕЛЬ")
    applyBtn.DoClick = ApplyModel

    local preview = UI.Create("ModelPanel", mid)
    preview:Dock(FILL)
    preview:SetBackground(false)
    preview:SetFOV(55)
    preview:SetCamPos(Vector(0, 0, 0))
    preview:SetDirectionalLight(BOX_RIGHT, Color(255, 70, 70, 160))
    preview:SetDirectionalLight(BOX_LEFT, Color(70, 70, 130, 255))
    preview:SetAmbientLight(Vector(-30, -30, -30))
    preview:SetAnimated(true)
    preview:SetLookAt(Vector(-80, 0, -20))
    preview.Angles = Angle(0, 0, 0)
    preview.Pos = Vector(-80, 0, -61)

    function preview:LayoutEntity(ent)
        if self.bAnimated then self:RunAnimation() end
        if self.Pressed == MOUSE_LEFT then
            local mx = gui.MousePos()
            self.Angles = self.Angles - Angle(0, (self.PressX or mx) - mx, 0)
            self.PressX, self.PressY = gui.MousePos()
        end
        ent:SetAngles(self.Angles)
        ent:SetPos(self.Pos)
    end
    function preview:DragMousePress(btn) self.PressX, self.PressY = gui.MousePos() self.Pressed = btn end
    function preview:DragMouseRelease() self.Pressed = false end
    function preview:OnMouseWheeled(delta) self.Pos = self.Pos - Vector(delta * -7, 0, 0) end

    -- ═══ Колонка 3: скин, bodygroups, цвет ═══
    local right = Column(frame, "НАСТРОЙКИ")
    right:Dock(FILL)
    right:DockMargin(gap, 0, 0, 0)

    local settings = UI.Create("Scroll", right)
    settings:Dock(FILL)

    local function UpdatePrivateButton()
        if not IsValid(privBtn) then return end
        local booster = Editor.IsBooster(LocalPlayer():SteamID64())
        privBtn:SetEnabled(booster and not IsModelLocked(selectedModel))
        privBtn:SetAccentColor(PRIVATE_COLOR)

        if not booster then
            privBtn:SetText("ПРИВАТИЗАЦИЯ (ТОЛЬКО БУСТЕРЫ)")
        elseif IsModelOwnedByMe(selectedModel) then
            privBtn:SetText("★ СНЯТЬ ПРИВАТИЗАЦИЮ")
        elseif IsModelLocked(selectedModel) then
            privBtn:SetText("ЗАНЯТА ДРУГИМ ИГРОКОМ")
        else
            privBtn:SetText("ПРИВАТИЗИРОВАТЬ МОДЕЛЬ")
        end
    end
    frame.UpdatePrivateButton = UpdatePrivateButton

    privBtn.DoClick = function()
        if not selectedModel or IsModelLocked(selectedModel) then return end
        net.Start("ronni_pe_privatize_model")
        net.WriteString(selectedModel)
        net.WriteInt(IsModelOwnedByMe(selectedModel) and 2 or 1, 4)
        net.SendToServer()
    end

    local function AddValueSlider(title, current, maxVal, onChange)
        local row = UI.Create("SettingRow", settings)
        row:Dock(TOP)
        row:SetTall(UI.Scale(56))
        row:SetTitle(title)

        local holder = row:SetControl(UI.Create("Container"), math.floor(right:GetWide() * 0.55))
        holder:SetTall(UI.Scale(30))

        local value = UI.Create("Label", holder)
        value:Dock(RIGHT)
        value:SetWide(UI.Scale(40))
        value:SetFont("SlashMoon.Small")
        value:SetContentAlignment(6)
        value:SetColorKey("Accent")
        value:SetText(tostring(current))

        local bar = UI.Create("SliderBar", holder)
        bar:Dock(FILL)
        bar:SetMinMax(0, maxVal)
        bar:SetDecimals(0)
        bar:SetValue(current, true)
        bar.OnValueChanged = function(_, v)
            value:SetText(tostring(v))
            onChange(v)
        end
    end

    local function RebuildSettings()
        settings:Clear()
        local ent = IsValid(preview) and preview.Entity
        if not IsValid(ent) then return end

        local header = UI.Create("Header", settings)
        header:Dock(TOP)
        header:SetText("СКИН / BODYGROUPS")

        local count = 0
        local skins = ent:SkinCount() - 1
        if skins > 0 then
            count = count + 1
            AddValueSlider("Скин", GetConVar("cl_playerskin"):GetInt(), skins, function(v)
                ent:SetSkin(v)
                RunConsoleCommand("cl_playerskin", v)
            end)
        end

        local groups = string.Explode(" ", GetConVar("cl_playerbodygroups"):GetString())
        for k = 0, ent:GetNumBodyGroups() - 1 do
            local bodygroupCount = ent:GetBodygroupCount(k)
            if bodygroupCount > 1 then
                count = count + 1
                AddValueSlider(ent:GetBodygroupName(k), tonumber(groups[k + 1]) or 0, bodygroupCount - 1, function(v)
                    ent:SetBodygroup(k, v)
                    local str = string.Explode(" ", GetConVar("cl_playerbodygroups"):GetString())
                    for i = 1, k + 1 do str[i] = str[i] or 0 end
                    str[k + 1] = v
                    RunConsoleCommand("cl_playerbodygroups", table.concat(str, " "))
                end)
            end
        end

        if count == 0 then
            local empty = UI.Create("Label", settings)
            empty:Dock(TOP)
            empty:DockMargin(UI.Scale(14), 0, 0, UI.Scale(8))
            empty:SetFont("SlashMoon.Small")
            empty:SetMuted(true)
            empty:SetText("Нет скинов / bodygroups")
        end

        local colorHeader = UI.Create("Header", settings)
        colorHeader:Dock(TOP)
        colorHeader:DockMargin(0, UI.Scale(10), 0, 0)
        colorHeader:SetText("ЦВЕТ ИГРОКА")

        local mixer = UI.Create("ColorPicker", settings)
        mixer:Dock(TOP)
        mixer:SetTall(UI.Scale(220))
        mixer:SetVector(Vector(GetConVar("cl_playercolor"):GetString()))
        mixer.ValueChanged = function(self)
            RunConsoleCommand("cl_playercolor", tostring(self:GetVector()))
        end
    end

    local function SetPreviewModel(name)
        preview:SetModel(player_manager.TranslatePlayerModel(name))
        if not IsValid(preview.Entity) then return end
        preview.Entity:SetPos(Vector(-80, 0, -61))
        local anims = list.Get("PlayerOptionsAnimations")[name] or DEFAULT_ANIMATIONS
        local seq = preview.Entity:LookupSequence(anims[math.random(1, #anims)])
        if seq and seq > 0 then preview.Entity:ResetSequence(seq) end
    end

    local cards = {}
    local function PopulateModels(filter)
        grid:Clear()
        cards = {}
        local query = string.lower(filter or "")
        local cardW, cardH = UI.Scale(104), UI.Scale(120)

        for name, model in SortedPairs(player_manager.AllValidModels()) do
            if Editor.IsBlacklisted(model) then continue end
            if query ~= "" and not string.find(string.lower(name), query, 1, true) then continue end

            local card = grid:Add("SlashMoon.Panel")
            card:SetSize(cardW, cardH)
            card:SetBackground("Surface")
            card:SetHoverBackground("SurfaceHover")
            card.ModelName = name

            card.PaintOver = function(self, cw, ch)
                local r = UI.Scale(self.Radius)
                if self.ModelName == selectedModel then
                    Draw.RoundedOutline(r, 0, 0, cw, ch, colors.Accent)
                end
                if IsModelLocked(self.ModelName) then
                    Draw.RoundedBox(r, 0, 0, cw, ch, Color(0, 0, 0, 175))
                    Draw.Text("ЗАНЯТО", "SlashMoon.Tiny", cw / 2, ch / 2, colors.Danger, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                elseif IsModelOwnedByMe(self.ModelName) then
                    Draw.RoundedOutline(r, 0, 0, cw, ch, PRIVATE_COLOR)
                    Draw.Text("★", "SlashMoon.Small", cw - UI.Scale(6), UI.Scale(4), PRIVATE_COLOR, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
                end
                local short = #self.ModelName > 11 and (string.sub(self.ModelName, 1, 11) .. "…") or self.ModelName
                Draw.Text(short, "SlashMoon.Tiny", cw / 2, ch - UI.Scale(6), colors.TextMuted, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
            end

            -- SpawnIcon — стандартный рендер иконки модели внутри карточки библиотеки
            local icon = vgui.Create("SpawnIcon", card)
            icon:SetPos(UI.Scale(8), UI.Scale(4))
            icon:SetSize(cardW - UI.Scale(16), cardW - UI.Scale(16))
            icon:SetModel(model)
            icon:SetTooltip(name)
            icon.PaintOver = function() end
            icon.DoClick = function()
                if IsModelLocked(name) then
                    UI.Toast("Эта модель приватизирована другим игроком!", "error")
                    return
                end
                selectedModel = name
                SetPreviewModel(name)
                RebuildSettings()
                UpdatePrivateButton()
            end

            cards[#cards + 1] = card
        end
    end

    search.OnValueChange = function(self) PopulateModels(self:GetValue()) end

    selectedModel = LocalPlayer():GetInfo("cl_playermodel")
    SetPreviewModel(selectedModel)
    PopulateModels()
    timer.Simple(0, function()
        if IsValid(frame) then
            RebuildSettings()
            UpdatePrivateButton()
        end
    end)
end

local function ToggleMenu()
    if IsValid(Editor.Frame) and not Editor.Frame.Closing then
        Editor.Frame:Close()
        return
    end
    BuildMenu()
end

MODULE:Command("ronni_player_editor", ToggleMenu, nil, "SlashMoon: редактор персонажа")

MODULE:Hook("PostGamemodeLoaded", "ronni_pe_desktop", function()
    list.Set("DesktopWindows", "PlayerEditor", {
        title = "Player Model",
        icon = "icon64/playermodel.png",
        init = function(_, window)
            window:Remove()
            RunConsoleCommand("ronni_player_editor")
        end,
    })
end)

MODULE:OnDisabled(function()
    if IsValid(Editor.Frame) then Editor.Frame:Remove() end
end)

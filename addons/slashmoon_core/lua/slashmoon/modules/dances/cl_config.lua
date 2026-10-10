-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("dances")

-- ========================================================
-- Экипировка анимаций: 8 слотов колеса эмоций + 3D-предпросмотр
-- ========================================================

local UI = SlashMoon.UI
local Dances = SlashMoon.Dances

local function SetupPreview(previewModel)
    previewModel:SetModel(LocalPlayer():GetModel())
    if not IsValid(previewModel.Entity) then return end

    local mn, mx = previewModel.Entity:GetRenderBounds()
    local size = math.max(math.abs(mn.x) + math.abs(mx.x), math.abs(mn.y) + math.abs(mx.y), math.abs(mn.z) + math.abs(mx.z))
    previewModel:SetFOV(35)
    previewModel:SetCamPos(Vector(size + 20, size, size * 0.4))
    previewModel:SetLookAt((mn + mx) * 0.5)

    previewModel.LayoutEntity = function(self, ent)
        ent:FrameAdvance(RealTime() - (self.LastPaint or RealTime()))
        self.LastPaint = RealTime()
        local dir = (self:GetCamPos() - self:GetLookAt()):Angle()
        ent:SetAngles(Angle(0, dir.y, 0))
    end

    function previewModel:PlayAnim(animID)
        local ent = self.Entity
        if not IsValid(ent) then return end

        local animData = animID and Dances.Animations[animID]
        if (not animData or animData.mode ~= "actmod") and ent:GetModel() ~= LocalPlayer():GetModel() then
            self:SetModel(LocalPlayer():GetModel())
            ent = self.Entity
        end

        local seq
        if animData then
            seq = ent:LookupSequence(animData.seq)
        else
            seq = ent:LookupSequence("idle_all_01")
            if seq <= 0 then seq = ent:LookupSequence("idle_subtle") end
        end
        if seq and seq > 0 then ent:ResetSequence(seq) end
    end

    previewModel:PlayAnim(nil)
end

function Dances.OpenConfig()
    if IsValid(Dances.ConfigFrame) then Dances.ConfigFrame:Remove() end

    local frame = UI.Create("Frame")
    frame:SetSize(UI.Scale(1100), UI.Scale(820))
    frame:Center()
    frame:SetHeader("ЭКИПИРОВКА АНИМАЦИЙ")
    Dances.ConfigFrame = frame

    -- 1. Панель звука (низ)
    local soundPnl = UI.Create("Panel", frame)
    soundPnl:Dock(BOTTOM)
    soundPnl:SetTall(UI.Scale(64))
    soundPnl:DockMargin(0, UI.Scale(10), 0, 0)
    soundPnl:SetBackground("Header")
    soundPnl:SetAccentBar(true)
    soundPnl:DockPadding(UI.Scale(18), UI.Scale(10), UI.Scale(18), UI.Scale(10))

    local cvMusicOn = GetConVar("wos_dance_music_on")
    local musicToggle = UI.Create("Checkbox", soundPnl)
    musicToggle:Dock(LEFT)
    musicToggle:SetLabel("Музыка танцев")
    musicToggle:SizeToContents()
    musicToggle:SetChecked(cvMusicOn and cvMusicOn:GetBool(), true)
    musicToggle.OnChange = function(_, checked)
        RunConsoleCommand("wos_dance_music_on", checked and "1" or "0")
    end

    local volume = UI.Create("Slider", soundPnl)
    volume:Dock(FILL)
    volume:DockMargin(UI.Scale(30), 0, 0, 0)
    volume:SetText("Громкость")
    volume:SetMinMax(0, 1)
    volume:SetDecimals(2)
    volume:SetConVar("wos_dance_music_vol")

    -- 2. Предпросмотр (справа)
    local previewPanel = UI.Create("Panel", frame)
    previewPanel:Dock(RIGHT)
    previewPanel:SetWide(UI.Scale(440))
    previewPanel:DockMargin(UI.Scale(10), 0, 0, 0)
    previewPanel:SetBackground("Header")
    previewPanel:SetOutline(true)

    local previewModel = UI.Create("ModelPanel", previewPanel)
    previewModel:Dock(FILL)
    previewModel:SetBackground(false)
    SetupPreview(previewModel)

    -- 3. Слоты (слева)
    local scroll = UI.Create("Scroll", frame)
    scroll:Dock(FILL)

    for i, bind in ipairs(Dances.GetCircleData()) do
        local row = UI.Create("SettingRow", scroll)
        row:Dock(TOP)
        row:SetTall(UI.Scale(64))
        row:SetAccentBar(true)
        row:SetTitle(bind.name or "Пусто")
        row:SetDescription("СЛОТ " .. string.format("%02d", i))

        row.OnCursorEntered = function()
            local current = Dances.GetCircleData()[i]
            previewModel:PlayAnim(current and current.id or nil)
        end

        local pick = row:SetControl(UI.Create("Button"), UI.Scale(170))
        pick:SetTall(UI.Scale(40))
        pick:SetText("ВЫБРАТЬ")
        pick.OnCursorEntered = row.OnCursorEntered
        pick.DoClick = function()
            local menu = UI.Menu()
            for catID, catData in SortedPairsByMemberValue(Dances.Categories, "name") do
                local sub = menu:AddSubMenu(catData.name)
                for animID, animData in SortedPairsByMemberValue(Dances.Animations, "name") do
                    if animData.cat == catID and Dances.HasDance(LocalPlayer(), animID) then
                        sub:AddOption(animData.name, function()
                            Dances.SetAnimSlot(i, animID)
                            row:SetTitle(animData.name)
                            previewModel:PlayAnim(animID)
                        end):SetIcon("icon16/user.png")
                    end
                end
            end
            menu:AddSpacer()
            menu:AddColoredOption("Очистить слот", UI.Colors.Danger, function()
                Dances.SetAnimSlot(i, nil)
                row:SetTitle("Пусто")
                previewModel:PlayAnim(nil)
            end)
            menu:Open()
        end
    end
end

MODULE:Command("wos_dance_menu", function() Dances.OpenConfig() end, nil, "SlashMoon: экипировка анимаций")

MODULE:OnDisabled(function()
    if IsValid(Dances.ConfigFrame) then Dances.ConfigFrame:Remove() end
end)

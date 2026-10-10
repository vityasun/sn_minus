-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("tasks")

-- ========================================================
-- SN Tasks: UI Редактора (v3 — Full API + 3D Markers + Info + Lists)
-- ========================================================
if not CLIENT then return end

SlashMoon.Tasks = SlashMoon.Tasks or {}
SlashMoon.Tasks.Editor = SlashMoon.Tasks.Editor or {}
SlashMoon.Tasks.Editor.State = {
    Config       = {},
    Markers      = {},      -- ClientsideModel список
    MarkerInfo   = {},      -- [ent] = "label"
    PlacingModel = nil,
    PlacingSpec  = nil,
    PlacingSection = nil,
    PlacingPath  = nil,
    PlacingCycleModels = nil,
    PlacingModelIdx = 1,
    AddAng       = 0,
}

local colors = SlashMoon.UI.Colors
local EditorMenu = nil
local _infoLabels = {}   -- [sectionID] = DLabel
local _listPanel  = nil  -- DScrollPanel для "Предметы на карте"

-- Forward declaration
local RefreshItemList = function() end

-- ══════════════════════════════════════════════════════════════════════
-- FRAMEWORK HELPER IMPLEMENTATIONS (вызываются из API)
-- ══════════════════════════════════════════════════════════════════════

-- Создать ClientsideModel маркер
SlashMoon.Tasks.Editor._PlaceMarker = function(pos, ang, model, color, label, skin)
    if not model then return nil end
    local ent = ClientsideModel(model)
    if not IsValid(ent) then return nil end
    ent:SetPos(pos)
    ent:SetAngles(ang)
    if color then
        ent:SetColor(color)
        ent:SetRenderMode(RENDERMODE_TRANSALPHA)
    end
    if skin then ent:SetSkin(skin) end
    ent:Spawn()
    table.insert(SlashMoon.Tasks.Editor.State.Markers, ent)
    if label then
        SlashMoon.Tasks.Editor.State.MarkerInfo[ent] = label
    end
    return ent
end

-- Очистить все маркеры
local function ClearMarkers()
    for _, e in ipairs(SlashMoon.Tasks.Editor.State.Markers) do
        if IsValid(e) then e:Remove() end
    end
    table.Empty(SlashMoon.Tasks.Editor.State.Markers)
    table.Empty(SlashMoon.Tasks.Editor.State.MarkerInfo)
end

-- Перерисовать все маркеры из конфига
SlashMoon.Tasks.Editor._RedrawAllMarkers = function()
    ClearMarkers()
    for _, section in ipairs(SlashMoon.Tasks.Editor.GetSections()) do
        local api = SlashMoon.Tasks.Editor.GetAPI(section)

        -- Стандартные маркеры
        if section.markers then
            for _, mspec in ipairs(section.markers) do
                local list = api.GetConfig(mspec.config_path) or {}
                for i, info in ipairs(list) do
                    local pos = Vector(info.pos.x, info.pos.y, info.pos.z)
                    local ang = Angle(
                        info.ang and info.ang.p or 0,
                        info.ang and info.ang.y or 0,
                        info.ang and info.ang.r or 0
                    )
                    local mdl = mspec.model_field and info[mspec.model_field] or mspec.model
                    local lbl = mspec.label and string.format(mspec.label, i)
                    api.PlaceMarker(pos, ang, mdl, mspec.color, lbl, mspec.skin)
                end
            end
        end

        -- Кастомные маркеры
        if section.custom_markers then
            section.custom_markers(api)
        end
    end
end

-- Обновить все info-лейблы + список + маркеры
SlashMoon.Tasks.Editor._RefreshAll = function()
    for _, section in ipairs(SlashMoon.Tasks.Editor.GetSections()) do
        local lbl = _infoLabels[section.id]
        if IsValid(lbl) and section.info then
            local api = SlashMoon.Tasks.Editor.GetAPI(section)
            lbl:SetText(section.info(api) or "")
        end
    end
    RefreshItemList()
    SlashMoon.Tasks.Editor._RedrawAllMarkers()
end

-- ══════════════════════════════════════════════════════════════════════
-- КНОПКА В С-МЕНЮ
-- ══════════════════════════════════════════════════════════════════════
local cmenuBtn = nil

MODULE:Hook("OnContextMenuOpen", "SN_Editor_CMenu", function()
    if not SlashMoon.Admin.HasPermission(LocalPlayer(), "slashmoon_tasks_editor") then return end
    if LocalPlayer():Team() ~= SlashMoon.TEAM_EDITOR then return end
    if not IsValid(cmenuBtn) and IsValid(g_ContextMenu) then
        cmenuBtn = vgui.Create("SlashMoon.Button", g_ContextMenu)
        cmenuBtn:SetSize(SlashMoon.UI.Scale(200), SlashMoon.UI.Scale(40))
        cmenuBtn:SetPos(ScrW() / 2 - SlashMoon.UI.Scale(100), SlashMoon.UI.Scale(20))
        cmenuBtn:SetBtnText("SN EDITOR")
        cmenuBtn.DoClick = function()
            surface.PlaySound("UI/buttonclick.wav")
            RunConsoleCommand("sn_editor")
            g_ContextMenu:Hide()
        end
    end
    if IsValid(cmenuBtn) then cmenuBtn:SetVisible(true) end
end)

MODULE:Hook("OnContextMenuClose", "SN_Editor_CMenu", function()
    if IsValid(cmenuBtn) then cmenuBtn:SetVisible(false) end
end)

-- ══════════════════════════════════════════════════════════════════════
-- 3D МАРКЕРЫ (ClientsideModel + 3D2D Labels)
-- ══════════════════════════════════════════════════════════════════════
MODULE:Hook("PostDrawTranslucentRenderables", "SN_Editor_3DMarkers", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    if not SlashMoon.Admin.HasPermission(ply, "slashmoon_tasks_editor") or ply:Team() ~= SlashMoon.TEAM_EDITOR then return end

    -- Рисуем 3D2D лейблы над каждым маркером
    for _, ent in ipairs(SlashMoon.Tasks.Editor.State.Markers) do
        if not IsValid(ent) then continue end
        local label = SlashMoon.Tasks.Editor.State.MarkerInfo[ent]
        if not label then continue end

        local pos = ent:GetPos() + Vector(0, 0, 30)
        local ang = ply:EyeAngles()
        ang:RotateAroundAxis(ang:Up(), -90)
        ang:RotateAroundAxis(ang:Forward(), 90)

        cam.Start3D2D(pos, ang, 0.1)
            SlashMoon.UI.Draw.TextShadow(label, "SlashMoon.Small", 0, 0, colors.Theme, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        cam.End3D2D()
    end
end)

-- ══════════════════════════════════════════════════════════════════════
-- СПИСОК ПРЕДМЕТОВ НА КАРТЕ
-- ══════════════════════════════════════════════════════════════════════
RefreshItemList = function()
    if not IsValid(_listPanel) then return end

    -- Очищаем старые строки
    for _, child in ipairs(_listPanel:GetCanvas():GetChildren()) do
        if IsValid(child) then child:Remove() end
    end

    -- Добавляем строки из каждой секции
    for _, section in ipairs(SlashMoon.Tasks.Editor.GetSections()) do
        if not section.list_items then continue end
        local api = SlashMoon.Tasks.Editor.GetAPI(section)

        -- add_row(label, color, onDelete, onTeleport)
        local function add_row(label, rowColor, onDelete, onTeleport)
            local row = vgui.Create("SlashMoon.Panel", _listPanel)
            row:Dock(TOP)
            row:SetTall(SlashMoon.UI.Scale(35))
            row:DockMargin(0, 0, 0, 3)
            row.Paint = function(self, w, h)
                surface.SetDrawColor(20, 20, 20, 200)
                surface.DrawRect(0, 0, w, h)
                -- Цветная полоска слева
                surface.SetDrawColor(rowColor)
                surface.DrawRect(0, 2, 3, h - 4)
            end

            local lbl = vgui.Create("SlashMoon.Label", row)
            lbl:Dock(LEFT)
            lbl:DockMargin(10, 0, 0, 0)
            lbl:SetFont("SlashMoon.Small")
            lbl:SetTextColor(color_white)
            lbl:SetText(label)

            if onTeleport then
                local tpBtn = vgui.Create("SlashMoon.Button", row)
                tpBtn:Dock(RIGHT)
                tpBtn:SetWide(SlashMoon.UI.Scale(50))
                tpBtn:DockMargin(0, 0, 5, 0)
                tpBtn:SetBtnText(SlashMoon.Tasks.Lang("sn.editor.teleport"))
                tpBtn.DoClick = function()
                    surface.PlaySound("UI/buttonclick.wav")
                    onTeleport()
                end
            end

            if onDelete then
                local delBtn = vgui.Create("SlashMoon.Button", row)
                delBtn:Dock(RIGHT)
                delBtn:SetWide(SlashMoon.UI.Scale(70))
                delBtn:SetBtnText(SlashMoon.Tasks.Lang("sn.editor.delete"))
                delBtn.DoClick = function()
                    surface.PlaySound("UI/buttonclick.wav")
                    onDelete()
                    SlashMoon.Tasks.Editor._RefreshAll()
                    -- Переоткрываем меню для обновления
                    if IsValid(EditorMenu) then
                        EditorMenu:Remove()
                        SlashMoon.Tasks.Editor.OpenMenu()
                    end
                end
            end
        end

        section.list_items(api, add_row)
    end
end

-- ══════════════════════════════════════════════════════════════════════
-- ОКНО РЕДАКТОРА
-- ══════════════════════════════════════════════════════════════════════
function SlashMoon.Tasks.Editor.OpenMenu()
    if not SlashMoon.Admin.HasPermission(LocalPlayer(), "slashmoon_tasks_editor") then return end
    if LocalPlayer():Team() ~= SlashMoon.TEAM_EDITOR then return end
    if IsValid(EditorMenu) then EditorMenu:Remove() end

    EditorMenu = vgui.Create("SlashMoon.Frame")
    EditorMenu:SetSize(SlashMoon.UI.Scale(420), ScrH() - SlashMoon.UI.Scale(100))
    EditorMenu:SetPos(SlashMoon.UI.Scale(20), SlashMoon.UI.Scale(50))
    EditorMenu:SetHeader(SlashMoon.Tasks.Lang("sn.editor.title", game.GetMap()))
    EditorMenu:MakePopup()
    EditorMenu:SetKeyboardInputEnabled(false)

    local scroll = vgui.Create("SlashMoon.Scroll", EditorMenu)
    scroll:Dock(FILL)
    scroll:DockMargin(10, 10, 10, 10)

    -- === СЕКЦИИ ===
    for _, sec in ipairs(SlashMoon.Tasks.Editor.GetSections()) do
        local api = SlashMoon.Tasks.Editor.GetAPI(sec)

        -- Заголовок секции
        local header = vgui.Create("SlashMoon.Label", scroll)
        header:Dock(TOP)
        header:SetTall(SlashMoon.UI.Scale(30))
        header:DockMargin(0, 15, 0, 5)
        header:SetFont("SlashMoon.Header")
        header:SetTextColor(colors.Theme)
        header:SetText("── " .. sec.title .. " ──")

        -- Info строка (если есть)
        if sec.info then
            local infoLbl = vgui.Create("SlashMoon.Label", scroll)
            infoLbl:Dock(TOP)
            infoLbl:DockMargin(5, 0, 0, 5)
            infoLbl:SetFont("SlashMoon.Small")
            infoLbl:SetTextColor(colors.TextMuted)
            infoLbl:SetText(sec.info(api) or "")
            infoLbl:SizeToContentsY()
            _infoLabels[sec.id] = infoLbl
        end

        -- Fields
        if sec.fields then
            for _, field in ipairs(sec.fields) do
                local fieldDef = field
                if fieldDef.type == "checkbox" then
                    local cbPnl = vgui.Create("SlashMoon.Panel", scroll)
                    cbPnl:Dock(TOP); cbPnl:SetTall(SlashMoon.UI.Scale(35)); cbPnl:DockMargin(0, 0, 0, 5); cbPnl.Paint = function() end

                    local cb = vgui.Create("SlashMoon.Checkbox", cbPnl)
                    cb:Dock(LEFT); cb:SetWide(SlashMoon.UI.Scale(300)); cb:SetLabel(fieldDef.label)
                    local curVal = SlashMoon.Tasks.Editor.NestedGet(SlashMoon.Tasks.Editor.State.Config, fieldDef.path)
                    if curVal == nil then curVal = fieldDef.default end
                    cb:SetChecked(tobool(curVal))
                    cb.OnChange = function(self, val)
                        SlashMoon.Tasks.Editor.NestedSet(SlashMoon.Tasks.Editor.State.Config, fieldDef.path, val)
                        if fieldDef.on_change then
                            fieldDef.on_change(api, val)
                        end
                    end

                elseif fieldDef.type == "number" then
                    local numPnl = vgui.Create("SlashMoon.Panel", scroll)
                    numPnl:Dock(TOP); numPnl:SetTall(SlashMoon.UI.Scale(45)); numPnl:DockMargin(0, 0, 0, 5)
                    numPnl.Paint = function(self, w, h) surface.SetDrawColor(30, 30, 30, 150) surface.DrawRect(0, 0, w, h) end

                    local slider = vgui.Create("SlashMoon.Slider", numPnl)
                    slider:Dock(FILL); slider:DockMargin(10, 0, 10, 0); slider:SetText(fieldDef.label)
                    slider:SetMin(fieldDef.min or 0); slider:SetMax(fieldDef.max or 100); slider:SetDecimals(0)
                    slider.Label:SetTextColor(Color(200, 200, 200)); slider.Label:SetFont("SlashMoon.Small")
                    local curVal = SlashMoon.Tasks.Editor.NestedGet(SlashMoon.Tasks.Editor.State.Config, fieldDef.path)
                    if curVal == nil then curVal = fieldDef.default end
                    slider:SetValue(curVal)
                    slider.OnValueChanged = function(self, val)
                        local rounded = math.Round(val)
                        SlashMoon.Tasks.Editor.NestedSet(SlashMoon.Tasks.Editor.State.Config, fieldDef.path, rounded)
                        if fieldDef.on_change then
                            fieldDef.on_change(api, rounded)
                        end
                    end
                end
            end
        end

        -- Buttons
        if sec.buttons then
            for _, btnDef in ipairs(sec.buttons) do
                local btn = vgui.Create("SlashMoon.Button", scroll)
                btn:Dock(TOP); btn:SetTall(SlashMoon.UI.Scale(35)); btn:DockMargin(0, 0, 0, 5)
                btn:SetBtnText(btnDef.label)
                btn.DoClick = function()
                    surface.PlaySound("UI/buttonclick.wav")
                    if btnDef.action then
                        btnDef.action(api)
                        SlashMoon.Tasks.Editor._RefreshAll()
                        EditorMenu:Remove()
                        SlashMoon.Tasks.Editor.OpenMenu()
                    elseif btnDef.placing then
                        SlashMoon.Tasks.Editor.StartPlacing(btnDef.placing, sec)
                    end
                end
            end
        end
    end

    -- === СПИСОК ОБЪЕКТОВ НА КАРТЕ ===
    local listHeader = vgui.Create("SlashMoon.Label", scroll)
    listHeader:Dock(TOP); listHeader:SetTall(SlashMoon.UI.Scale(30)); listHeader:DockMargin(0, 20, 0, 5)
    listHeader:SetFont("SlashMoon.Header"); listHeader:SetTextColor(colors.Theme)
    listHeader:SetText("── " .. SlashMoon.Tasks.Lang("sn.editor.objects") .. " ──")

    _listPanel = vgui.Create("SlashMoon.Scroll", scroll)
    _listPanel:Dock(TOP)
    _listPanel:SetTall(SlashMoon.UI.Scale(200))
    _listPanel:GetVBar():SetWide(3)

    RefreshItemList()

    -- === КНОПКИ СОХРАНЕНИЯ / ЗАГРУЗКИ / ОЧИСТКИ ===
    local btnRow = vgui.Create("SlashMoon.Panel", scroll)
    btnRow:Dock(TOP); btnRow:SetTall(SlashMoon.UI.Scale(45)); btnRow:DockMargin(0, 30, 0, 10)
    btnRow.Paint = function() end

    local saveBtn = vgui.Create("SlashMoon.Button", btnRow)
    saveBtn:Dock(LEFT); saveBtn:SetWide(SlashMoon.UI.Scale(120)); saveBtn:DockMargin(0, 0, 5, 0)
    saveBtn:SetBtnText(SlashMoon.Tasks.Lang("sn.editor.save"))
    saveBtn.DoClick = function()
        surface.PlaySound("UI/buttonclick.wav")
        SlashMoon.Tasks.MapConfig = table.Copy(SlashMoon.Tasks.Editor.State.Config)
        net.Start("SN_Editor_Save")
        net.WriteTable(SlashMoon.Tasks.Editor.State.Config)
        net.SendToServer()
    end

    local loadBtn = vgui.Create("SlashMoon.Button", btnRow)
    loadBtn:Dock(LEFT); loadBtn:SetWide(SlashMoon.UI.Scale(120)); loadBtn:DockMargin(0, 0, 5, 0)
    loadBtn:SetBtnText(SlashMoon.Tasks.Lang("sn.editor.load"))
    loadBtn.DoClick = function()
        surface.PlaySound("UI/buttonclick.wav")
        net.Start("SN_Editor_Load")
        net.SendToServer()
    end

    local clearBtn = vgui.Create("SlashMoon.Button", btnRow)
    clearBtn:Dock(LEFT); clearBtn:SetWide(SlashMoon.UI.Scale(120))
    clearBtn:SetBtnText(SlashMoon.Tasks.Lang("sn.editor.clear"))
    clearBtn.DoClick = function()
        surface.PlaySound("UI/buttonclick.wav")
        net.Start("SN_Editor_Clear")
        net.SendToServer()
    end
end

-- ══════════════════════════════════════════════════════════════════════
-- СЕТЕВЫЕ ПРИЕМНИКИ
-- ══════════════════════════════════════════════════════════════════════
MODULE:Receive("SN_Editor_Open", function()
    if not SlashMoon.Admin.HasPermission(LocalPlayer(), "slashmoon_tasks_editor") then return end
    local state = net.ReadBool()
    if state then
        SlashMoon.Tasks.MapConfig = net.ReadTable() or {}
        SlashMoon.Tasks.Editor.State.Config = table.Copy(SlashMoon.Tasks.MapConfig)
        SlashMoon.Tasks.Editor.OpenMenu()
        SlashMoon.Tasks.Editor._RedrawAllMarkers()
    else
        if IsValid(EditorMenu) then EditorMenu:Remove() end
        ClearMarkers()
        if IsValid(SlashMoon.Tasks.Editor.State.PlacingModel) then
            SlashMoon.Tasks.Editor.State.PlacingModel:Remove()
            SlashMoon.Tasks.Editor.State.PlacingModel = nil
        end
    end
end)

-- ══════════════════════════════════════════════════════════════════════
-- РАЗМЕЩЕНИЕ ОБЪЕКТОВ (Ghost Placing + cycle_models)
-- ══════════════════════════════════════════════════════════════════════
function SlashMoon.Tasks.Editor.StartPlacing(spec, section)
    if not SlashMoon.Admin.HasPermission(LocalPlayer(), "slashmoon_tasks_editor") then return end
    if LocalPlayer():Team() ~= SlashMoon.TEAM_EDITOR then return end
    -- Удаляем предыдущий ghost
    if IsValid(SlashMoon.Tasks.Editor.State.PlacingModel) then
        SlashMoon.Tasks.Editor.State.PlacingModel:Remove()
    end

    -- Определяем начальную модель
    local models = spec.cycle_models
    local modelIdx = 1
    local model = models and models[1] or spec.model

    local ghost = ClientsideModel(model)
    if not IsValid(ghost) then return end
    ghost:SetRenderMode(RENDERMODE_TRANSALPHA)
    ghost:SetColor(spec.color or Color(0, 255, 100, 150))
    ghost:SetSkin(spec.skin or 0)

    SlashMoon.Tasks.Editor.State.PlacingModel      = ghost
    SlashMoon.Tasks.Editor.State.PlacingSpec       = spec
    SlashMoon.Tasks.Editor.State.PlacingSection    = section
    SlashMoon.Tasks.Editor.State.PlacingPath       = spec.config_path
    SlashMoon.Tasks.Editor.State.PlacingCycleModels = models
    SlashMoon.Tasks.Editor.State.PlacingModelIdx   = modelIdx
    SlashMoon.Tasks.Editor.State.AddAng            = 0

    if IsValid(EditorMenu) then EditorMenu:Remove() end

    local modelList = models and #models > 1 and ("\n" .. SlashMoon.Tasks.Lang("sn.editor.change_model", #models)) or ""
    LocalPlayer():ChatPrint(SlashMoon.Tasks.Lang("sn.editor.placement") .. modelList)
end

-- Ghost следит за курсором
MODULE:Hook("Think", "SN_Editor_GhostThink", function()
    if not SlashMoon.Admin.HasPermission(LocalPlayer(), "slashmoon_tasks_editor") then return end
    if LocalPlayer():Team() ~= SlashMoon.TEAM_EDITOR then return end
    local ghost = SlashMoon.Tasks.Editor.State.PlacingModel
    if not IsValid(ghost) then return end
    local tr = LocalPlayer():GetEyeTrace()
    ghost:SetPos(tr.HitPos)
    ghost:SetAngles(Angle(0, SlashMoon.Tasks.Editor.State.AddAng, 0))
end)

-- Вращение колёсиком + смена модели
MODULE:Hook("InputMouseApply", "SN_Editor_Rotate", function(cmd)
    if not SlashMoon.Admin.HasPermission(LocalPlayer(), "slashmoon_tasks_editor") then return end
    if LocalPlayer():Team() ~= SlashMoon.TEAM_EDITOR then return end
    if not IsValid(SlashMoon.Tasks.Editor.State.PlacingModel) then return end
    local wheel = cmd:GetMouseWheel()
    if wheel == 0 then return end

    local models = SlashMoon.Tasks.Editor.State.PlacingCycleModels

    -- Shift+колесо = смена модели (если cycle_models)
    if models and #models > 1 and input.IsKeyDown(KEY_LSHIFT) then
        local idx = SlashMoon.Tasks.Editor.State.PlacingModelIdx
        idx = idx + math.Clamp(wheel, -1, 1)
        if idx < 1 then idx = #models end
        if idx > #models then idx = 1 end
        SlashMoon.Tasks.Editor.State.PlacingModelIdx = idx

        -- Пересоздаём ghost с новой моделью
        local oldGhost = SlashMoon.Tasks.Editor.State.PlacingModel
        local spec = SlashMoon.Tasks.Editor.State.PlacingSpec
        local newGhost = ClientsideModel(models[idx])
        if not IsValid(newGhost) then return end
        newGhost:SetRenderMode(RENDERMODE_TRANSALPHA)
        newGhost:SetColor(spec.color or Color(0, 255, 100, 150))
        if IsValid(oldGhost) then oldGhost:Remove() end
        SlashMoon.Tasks.Editor.State.PlacingModel = newGhost
    else
        -- Обычное вращение
        SlashMoon.Tasks.Editor.State.AddAng = (SlashMoon.Tasks.Editor.State.AddAng + math.Clamp(wheel, -1, 1) * 22.5) % 360
    end
end)

-- Клик: поставить / отменить / открыть меню
MODULE:Hook("PlayerButtonDown", "SN_Editor_PlaceClick", function(ply, key)
    if ply ~= LocalPlayer() then return end
    if not SlashMoon.Admin.HasPermission(ply, "slashmoon_tasks_editor") or ply:Team() ~= SlashMoon.TEAM_EDITOR then return end
    local ghost = SlashMoon.Tasks.Editor.State.PlacingModel

    if IsValid(ghost) then
        if key == MOUSE_LEFT then
            local pos = ghost:GetPos()
            local ang = ghost:GetAngles()
            local spec = SlashMoon.Tasks.Editor.State.PlacingSpec
            local section = SlashMoon.Tasks.Editor.State.PlacingSection
            local slot = SlashMoon.Tasks.Editor.NestedEnsure(SlashMoon.Tasks.Editor.State.Config, SlashMoon.Tasks.Editor.State.PlacingPath)

            local entry = {
                pos = { x = pos.x, y = pos.y, z = pos.z },
                ang = { p = ang.p, y = ang.y, r = ang.r }
            }

            -- model_field: сохранить выбранную модель в entry
            if spec.model_field then
                local models = SlashMoon.Tasks.Editor.State.PlacingCycleModels
                local idx = SlashMoon.Tasks.Editor.State.PlacingModelIdx
                entry[spec.model_field] = models and models[idx] or spec.model
            end

            -- on_store: кастомная логика сохранения
            if spec.on_store then
                local api = SlashMoon.Tasks.Editor.GetAPI(section)
                spec.on_store(api, pos, ang, entry)
            else
                table.insert(slot, entry)
            end

            surface.PlaySound("buttons/button14.wav")
            ply:ChatPrint(SlashMoon.Tasks.Lang("sn.editor.pos_added"))
            ghost:Remove()
            SlashMoon.Tasks.Editor.State.PlacingModel = nil
            SlashMoon.Tasks.Editor._RefreshAll()
            SlashMoon.Tasks.Editor.OpenMenu()

        elseif key == MOUSE_RIGHT then
            ghost:Remove()
            SlashMoon.Tasks.Editor.State.PlacingModel = nil
            SlashMoon.Tasks.Editor.OpenMenu()
        end

    elseif key == KEY_I and SlashMoon.Admin.HasPermission(ply, "slashmoon_tasks_editor") and ply:Team() == SlashMoon.TEAM_EDITOR then
        if IsFirstTimePredicted() then SlashMoon.Tasks.Editor.OpenMenu() end
    end
end)

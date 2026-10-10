-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("tasks")

-- ========================================================
-- SN Tasks: Client Inventory (Original Design + Bugfixes)
-- + Осмотреть (Inspect), панель описания слева, rarity colors
-- ========================================================
if not CLIENT then return end

SlashMoon.Tasks = SlashMoon.Tasks or {}
SlashMoon.Tasks.Backpack = SlashMoon.Tasks.Backpack or {}
SlashMoon.Tasks.Hotbar = SlashMoon.Tasks.Hotbar or {}
SlashMoon.Tasks.Config = SlashMoon.Tasks.Config or {}
SlashMoon.Tasks.Config.MaxHotbar = SlashMoon.Tasks.Config.MaxHotbar or 3

local colors = SlashMoon.UI.Colors
local InvRoot = nil
local InvMenu = nil
local LootRoot = nil
local LootMenu = nil
local InspectPanel = nil   -- Панель осмотра (слева от инвентаря)
local InspectContent = nil
local InspectClass = nil   -- Класс предмета в панели осмотра

-- === КЭШИРОВАНИЕ ДАННЫХ ПРЕДМЕТОВ НА КЛИЕНТЕ ===
local ClientItemCache = {}

local function GetCachedItemData(class)
    if not ClientItemCache[class] then
        ClientItemCache[class] = SlashMoon.Tasks.GetItemData(class)
    end
    return ClientItemCache[class]
end

-- Очистка кэша при смене карты
MODULE:Hook("OnCleanup", "SN_Inv_ClearCache", function()
    ClientItemCache = {}
end)

local function IsAlreadyInHotbar(class)
    for i = 1, SlashMoon.Tasks.Config.MaxHotbar do
        if SlashMoon.Tasks.Hotbar and SlashMoon.Tasks.Hotbar[i] == class then return true end
    end
    return false
end

-- ========================================================
-- СИНХРОНИЗАЦИЯ (поддержка сжатого и классического формата)
-- ========================================================

MODULE:Receive("SN_Inv_Sync", function()
    local isCompressed = net.ReadBool()

    if isCompressed then
        local dataLen = net.ReadUInt(32)
        if dataLen <= 0 or dataLen > 65535 then return end
        local rawData = net.ReadData(dataLen)
        local jsonStr = util.Decompress(rawData)

        if jsonStr then
            local data = util.JSONToTable(jsonStr)
            if data then
                -- Сервер отправляет ключи "bp" и "hb"
                SlashMoon.Tasks.Backpack = data.bp or data.backpack or {}
                SlashMoon.Tasks.Hotbar = data.hb or data.hotbar or {}
            end
        end
    else
        -- Fallback: net.ReadTable (как net.WriteTable на сервере)
        SlashMoon.Tasks.Backpack = net.ReadTable() or {}
        SlashMoon.Tasks.Hotbar = net.ReadTable() or {}
    end

    -- Обновляем инвентарь если открыт
    if IsValid(InvMenu) and InvMenu.Rebuild then
        InvMenu:Rebuild()
    end
end)

-- Дельта-обновление (микро-синхронизация)
-- Сервер отправляет: count, затем count записей {type, slot, value}
MODULE:Receive("SN_Inv_DeltaUpdate", function()
    local updateCount = net.ReadUInt(8)

    for _ = 1, updateCount do
        local field = net.ReadString()   -- "backpack" or "hotbar"
        local index = net.ReadUInt(8)
        local value = net.ReadString()

        if field == "backpack" then
            if value == "" then
                table.remove(SlashMoon.Tasks.Backpack, index)
            else
                SlashMoon.Tasks.Backpack[index] = value
            end
        elseif field == "hotbar" then
            if value == "" then
                SlashMoon.Tasks.Hotbar[index] = nil
            else
                SlashMoon.Tasks.Hotbar[index] = value
            end
        end
    end

    if IsValid(InvMenu) and InvMenu.Rebuild then
        InvMenu:Rebuild()
    end
end)

-- ========================================================
-- ЛУТ: ПРИЁМ ДАННЫХ О ТРУПЕ
-- ========================================================
MODULE:Receive("SN_Inv_OpenLootUI", function()
    -- Сервер отправляет: entity, WriteTable(backpack), WriteTable(hotbar)
    local ent = net.ReadEntity()
    local bpItems = net.ReadTable() or {}
    local hbItems = net.ReadTable() or {}

    if not IsValid(ent) then return end

    if IsValid(InvRoot) then InvRoot:Remove() end

    if not IsValid(LootRoot) or LootRoot.TargetEnt ~= ent then
        if IsValid(LootRoot) then
            LootRoot.Removing = true
            LootRoot:Remove()
        end

        LootRoot = vgui.Create("SlashMoon.Panel")
        LootRoot:SetSize(ScrW(), ScrH())
        LootRoot:MakePopup()
        LootRoot:SetKeyboardInputEnabled(false)
        LootRoot.TargetEnt = ent
        LootRoot.Paint = function(self, w, h)
            surface.SetDrawColor(0, 0, 0, 100)
            surface.DrawRect(0, 0, w, h)
        end
        LootRoot.Think = function(self)
            local target = self.TargetEnt
            local ply = LocalPlayer()
            if not IsValid(target)
            or (not SlashMoon.Tasks.Game.CanLootCorpse(ply) and not target:GetNW2Bool("SN_InvestigationLoot", false))
            or ply:GetPos():DistToSqr(target:GetPos()) > 160 * 160 then
                self.Removing = true
                self:Remove()
            end
        end
        LootRoot.OnRemove = function(self)
            if LootRoot == self then LootRoot = nil end
            LootMenu = nil
        end

        LootMenu = vgui.Create("SlashMoon.Frame", LootRoot)
        LootMenu:SetBlurEnabled(false)
        LootMenu:SetSize(SlashMoon.UI.Scale(1000), SlashMoon.UI.Scale(700))
        LootMenu:Center()
        local corpseName = ent:GetNW2String("SN_CorpseName", SlashMoon.Tasks.Lang("sn.inv.corpse_unknown"))
        LootMenu:SetHeader(SlashMoon.Tasks.Lang("sn.inv.loot_title", corpseName))
        LootMenu.OnRemove = function()
            if IsValid(LootRoot) and not LootRoot.Removing then
                LootRoot.Removing = true
                LootRoot:Remove()
            end
        end

        local leftPanel = vgui.Create("SlashMoon.Panel", LootMenu)
        leftPanel:Dock(LEFT)
        leftPanel:SetWide(SlashMoon.UI.Scale(500))
        leftPanel:DockMargin(15, 15, 0, 15)
        leftPanel.Paint = function(self, w, h)
            surface.SetDrawColor(20, 20, 20, 200)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(colors.Theme)
            surface.DrawRect(0, 0, w, 2)
            surface.SetDrawColor(colors.Outline)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end

        local footer = vgui.Create("SlashMoon.Label", leftPanel)
        footer:Dock(BOTTOM)
        footer:SetTall(SlashMoon.UI.Scale(40))
        footer:DockMargin(10, 4, 10, 10)
        footer:SetFont("SlashMoon.Small")
        footer:SetTextColor(colors.TextMuted)
        footer:SetContentAlignment(5)
        footer:SetText(SlashMoon.Tasks.Lang("sn.inv.loot_take_hint"))

        local scroll = vgui.Create("SlashMoon.Scroll", leftPanel)
        scroll:Dock(FILL)
        scroll:DockMargin(10, 10, 10, 4)

        local grid = vgui.Create("SlashMoon.Grid", scroll)
        grid:Dock(FILL)
        grid:SetSpaceX(SlashMoon.UI.Scale(8))
        grid:SetSpaceY(SlashMoon.UI.Scale(8))

        local rightPanel = vgui.Create("SlashMoon.Panel", LootMenu)
        rightPanel:Dock(FILL)
        rightPanel:DockMargin(15, 15, 15, 15)
        rightPanel.Paint = function(self, w, h)
            surface.SetDrawColor(15, 15, 15, 240)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(colors.Theme)
            surface.DrawRect(0, 0, w, 2)
            surface.SetDrawColor(colors.Outline)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            SlashMoon.UI.Draw.TextShadow(SlashMoon.Tasks.Lang("sn.inv.equip"), "SlashMoon.Header", 15, 15, colors.TextMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end

        local corpseModel = vgui.Create("SlashMoon.ModelPanel", rightPanel)
        corpseModel:Dock(FILL)
        corpseModel:SetModel(ent:GetModel())
        corpseModel:SetFOV(35)
        corpseModel:SetCamPos(Vector(70, 0, 40))
        corpseModel:SetLookAt(Vector(0, 0, 40))
        corpseModel.LayoutEntity = function(self, modelEnt)
            modelEnt:SetSequence(modelEnt:LookupSequence("pose_standing_01") or 0)
            self:RunAnimation()
        end

        LootMenu.LootGrid = grid
        LootMenu.LootEquipment = rightPanel
        LootMenu.LootEquipmentSlots = {}

        rightPanel.PerformLayout = function(self, w)
            local slotSize = SlashMoon.UI.Scale(100)
            local slots = LootMenu.LootEquipmentSlots
            if slots[1] then slots[1]:SetPos(SlashMoon.UI.Scale(30), SlashMoon.UI.Scale(120)) end
            if slots[2] then slots[2]:SetPos(w - slotSize - SlashMoon.UI.Scale(30), SlashMoon.UI.Scale(120)) end
            if slots[3] then slots[3]:SetPos(SlashMoon.UI.Scale(30), SlashMoon.UI.Scale(270)) end
        end
    end

    LootRoot.TargetEnt = ent

    function LootMenu:Rebuild(backpack, hotbar)
        local grid = self.LootGrid
        local equipment = self.LootEquipment
        if not IsValid(grid) or not IsValid(equipment) then return end
        grid:Clear()

        for _, slot in ipairs(self.LootEquipmentSlots) do slot:Remove() end
        table.Empty(self.LootEquipmentSlots)

        local function PopulateSlot(slot, itemInfo, equipped)
            if not itemInfo then return end
            local itemClass = itemInfo.class
            local data = GetCachedItemData(itemClass)
            local parsed = SlashMoon.Tasks.ParseItemEntry(itemClass)
            local typeColor = SlashMoon.Tasks.GetTypeColor(data.type)
            local rarityColor = SlashMoon.Tasks.GetRarityColor(data.rarity or "common")

            local btn = vgui.Create("SlashMoon.Button", slot)
            btn:Dock(FILL)
            btn:DockMargin(equipped and 2 or 0, equipped and 2 or 0, equipped and 2 or 0, equipped and 2 or 0)
            btn:SetText("")
            btn:SetTooltip(SlashMoon.Tasks.Lang("sn.inv.take") .. ": " .. data.name)
            btn.Paint = function(self, w, h)
                local hovered = self:IsHovered()
                surface.SetDrawColor(equipped and 20 or 30, equipped and 20 or 30, equipped and 20 or 30, 230)
                surface.DrawRect(0, 0, w, h)

                if equipped then
                    surface.SetDrawColor(rarityColor)
                    surface.DrawOutlinedRect(0, 0, w, h, 3)
                else
                    surface.SetDrawColor(typeColor)
                    surface.DrawRect(0, 0, 4, h)
                end

                if data.type == "weapon" and data.rarity and not equipped then
                    if data.rarity ~= "common" then
                        surface.SetDrawColor(rarityColor.r, rarityColor.g, rarityColor.b, 45)
                        surface.DrawRect(4, 0, w - 4, h)
                        surface.SetDrawColor(rarityColor)
                        surface.DrawOutlinedRect(2, 2, w - 4, h - 4, 2)
                    else
                        surface.SetDrawColor(rarityColor.r, rarityColor.g, rarityColor.b, 80)
                        surface.DrawOutlinedRect(2, 2, w - 4, h - 4, 1)
                    end
                end

                if hovered then
                    surface.SetDrawColor(typeColor.r, typeColor.g, typeColor.b, 55)
                    surface.DrawRect(0, 0, w, h)
                end

                local mat = SlashMoon.Tasks.GetItemMaterial(itemClass)
                if mat and not mat:IsError() then
                    local iconSize = math.min(w, h) - 20
                    surface.SetMaterial(mat)
                    surface.SetDrawColor(255, 255, 255, hovered and 255 or 220)
                    surface.DrawTexturedRect((w - iconSize) / 2, (h - iconSize) / 2, iconSize, iconSize)
                    if not equipped then
                        SlashMoon.UI.Draw.TextShadow(data.name, "SlashMoon.Small", w / 2, h - 7, hovered and color_white or colors.TextMuted, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
                    end
                else
                    SlashMoon.UI.Draw.TextShadow(data.name, "SlashMoon.Small", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end

                if parsed.count > 1 then
                    local countText = tostring(parsed.count)
                    local badgeW = math.max(22, #countText * 8 + 8)
                    local badgeH = 17
                    local bx, by = w - badgeW - 3, h - badgeH - 3
                    surface.SetDrawColor(0, 0, 0, 200)
                    surface.DrawRect(bx, by, badgeW, badgeH)
                    surface.SetDrawColor(typeColor)
                    surface.DrawOutlinedRect(bx, by, badgeW, badgeH, 1)
                    SlashMoon.UI.Draw.TextShadow(countText, "SlashMoon.Small", bx + badgeW / 2, by + badgeH / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end

                surface.SetDrawColor(colors.Outline)
                surface.DrawOutlinedRect(0, 0, w, h, 1)
            end
            btn.DoClick = function(self)
                if self.TakePending or not IsValid(LootRoot) or not IsValid(LootRoot.TargetEnt) then return end
                self.TakePending = true
                self:SetEnabled(false)
                surface.PlaySound("items/ammo_pickup.wav")
                net.Start("SN_Inv_TakeLoot")
                net.WriteEntity(LootRoot.TargetEnt)
                net.WriteString(itemInfo.source)
                net.WriteUInt(itemInfo.idx, 8)
                net.WriteString(itemClass)
                net.SendToServer()
                timer.Simple(0.75, function()
                    if IsValid(self) then
                        self.TakePending = false
                        self:SetEnabled(true)
                    end
                end)
            end
        end

        local backpackItems = backpack or {}
        local backpackSlots = math.max(30, math.ceil((#backpackItems + 5) / 5) * 5)
        local backpackSlotSize = SlashMoon.UI.Scale(90)
        for idx = 1, backpackSlots do
            local slot = grid:Add("SlashMoon.Panel")
            slot:SetSize(backpackSlotSize, backpackSlotSize)
            slot.Paint = function(self, w, h)
                surface.SetDrawColor(30, 30, 30, 200)
                surface.DrawRect(0, 0, w, h)
                surface.SetDrawColor(colors.Outline)
                surface.DrawOutlinedRect(0, 0, w, h, 1)
            end

            local itemClass = backpackItems[idx]
            if itemClass then
                PopulateSlot(slot, { class = itemClass, source = "backpack", idx = idx }, false)
            end
        end
        grid:SizeToChildren(false, true)

        local hotbarItems = hotbar or {}
        for idx = 1, SlashMoon.Tasks.Config.MaxHotbar do
            local slotIdx = idx
            local slot = vgui.Create("SlashMoon.Panel", equipment)
            slot:SetSize(SlashMoon.UI.Scale(100), SlashMoon.UI.Scale(100))
            slot.Paint = function(self, w, h)
                surface.SetDrawColor(20, 20, 20, 240)
                surface.DrawRect(0, 0, w, h)
                surface.SetDrawColor(colors.Theme)
                surface.DrawOutlinedRect(0, 0, w, h, 1)

                if not hotbarItems[slotIdx] then
                    SlashMoon.UI.Draw.TextShadow(SlashMoon.Tasks.Lang("sn.hotbar.empty"), "SlashMoon.Small", w / 2, h / 2, colors.TextMuted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
            end
            self.LootEquipmentSlots[slotIdx] = slot

            local itemClass = hotbarItems[slotIdx]
            if itemClass then
                PopulateSlot(slot, { class = itemClass, source = "hotbar", idx = slotIdx }, true)
            end
        end
        equipment:InvalidateLayout(true)
    end

    LootMenu:Rebuild(bpItems, hbItems)
end)

-- ========================================================
-- КОНТЕКСТНОЕ МЕНЮ
-- ========================================================

function SlashMoon.Tasks.OpenContextMenu(options)
    if IsValid(SlashMoon.Tasks.ActiveContextMenu) then SlashMoon.Tasks.ActiveContextMenu:Remove() end

    local shield = SlashMoon.UI.Shield()

    SlashMoon.Tasks.ActiveContextMenu = shield

    local menuWidth = SlashMoon.UI.Scale(180)
    local btnHeight = SlashMoon.UI.Scale(32)
    local totalHeight = #options * btnHeight

    local menu = vgui.Create("SlashMoon.Panel", shield)
    menu:SetSize(menuWidth, totalHeight)

    menu.Paint = function(self, w, h)
        surface.SetDrawColor(15, 15, 15, 250)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(colors.Theme)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local curY = 0
    for _, opt in ipairs(options) do
        local btn = vgui.Create("SlashMoon.Button", menu)
        btn:SetSize(menuWidth, btnHeight)
        btn:SetPos(0, curY)
        btn:SetText("")

        btn.Paint = function(self, w, h)
            local isHovered = self:IsHovered()
            if isHovered then
                local bgCol = opt.color or colors.Theme
                surface.SetDrawColor(bgCol.r, bgCol.g, bgCol.b, 100)
                surface.DrawRect(0, 0, w, h)
                surface.SetDrawColor(bgCol)
                surface.DrawRect(0, 0, 3, h)
            end
            draw.SimpleText(opt.text, "SlashMoon.Small", 15, h/2, colors.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            surface.SetDrawColor(colors.Outline)
            surface.DrawRect(0, h - 1, w, 1)
        end

        btn.DoClick = function()
            shield:Remove()
            if opt.onClick then opt.onClick() end
        end

        curY = curY + btnHeight
    end

    local mx, my = gui.MousePos()
    if mx + menuWidth > ScrW() then mx = ScrW() - menuWidth end
    if my + totalHeight > ScrH() then my = ScrH() - totalHeight end
    menu:SetPos(mx, my)
end

-- ========================================================
-- ПАНЕЛЬ ОСМОТРА (слева от основного окна инвентаря)
-- Показывает: иконку, название, тип, редкость, описание, стата
-- ========================================================
local function UpdateInspectPanel(itemClass)
    if not IsValid(InspectPanel) or not IsValid(InspectContent) then return end
    if not itemClass or itemClass == "" then
        InspectPanel:SetVisible(false)
        InspectClass = nil
        return
    end

    InspectClass = itemClass
    InspectPanel:SetVisible(true)

    local data = GetCachedItemData(itemClass)
    local parsedItem = SlashMoon.Tasks.ParseItemEntry(itemClass)
    local typeColor = SlashMoon.Tasks.GetTypeColor(data.type)
    local rarityColor = SlashMoon.Tasks.GetRarityColor(data.rarity or "common")
    local rarityName = SlashMoon.Tasks.GetRarityName(data.rarity or "common")
    local description = SlashMoon.Tasks.GetItemDescription(itemClass)

    InspectContent:Clear()

    -- Иконка предмета
    local iconPanel = vgui.Create("SlashMoon.Panel", InspectContent)
    iconPanel:Dock(TOP)
    iconPanel:SetTall(SlashMoon.UI.Scale(80))
    iconPanel:DockMargin(SlashMoon.UI.Scale(10), SlashMoon.UI.Scale(5), SlashMoon.UI.Scale(10), 0)
    iconPanel.Paint = function(self, w, h)
        local mat = SlashMoon.Tasks.GetItemMaterial(itemClass)
        if mat and not mat:IsError() then
            local iconSize = math.min(w, h) - 10
            surface.SetMaterial(mat)
            surface.SetDrawColor(255, 255, 255, 240)
            surface.DrawTexturedRect((w - iconSize) / 2, (h - iconSize) / 2, iconSize, iconSize)
        end
        -- Рамка по типу
        surface.SetDrawColor(typeColor)
        surface.DrawOutlinedRect(0, 0, w, h, 2)
    end

    -- Название предмета
    local nameLabel = vgui.Create("SlashMoon.Label", InspectContent)
    nameLabel:Dock(TOP)
    nameLabel:SetTall(SlashMoon.UI.Scale(24))
    nameLabel:DockMargin(SlashMoon.UI.Scale(10), SlashMoon.UI.Scale(8), 0, 0)
    nameLabel:SetFont("SlashMoon.Text")
    nameLabel:SetTextColor(color_white)
    nameLabel:SetText(data.name)

    -- Тип предмета
    local typeLabel = vgui.Create("SlashMoon.Label", InspectContent)
    typeLabel:Dock(TOP)
    typeLabel:SetTall(SlashMoon.UI.Scale(20))
    typeLabel:DockMargin(SlashMoon.UI.Scale(10), SlashMoon.UI.Scale(2), 0, 0)
    typeLabel:SetFont("SlashMoon.Small")
    typeLabel:SetTextColor(typeColor)
    typeLabel:SetText(SlashMoon.Tasks.Lang("sn.inv.type") .. ": " .. SlashMoon.Tasks.Lang("sn.inv.type." .. data.type))

    -- Редкость (показываем для всех, но особенно выделяем для оружия)
    local rarityLabel = vgui.Create("SlashMoon.Label", InspectContent)
    rarityLabel:Dock(TOP)
    rarityLabel:SetTall(SlashMoon.UI.Scale(20))
    rarityLabel:DockMargin(SlashMoon.UI.Scale(10), SlashMoon.UI.Scale(2), 0, 0)
    rarityLabel:SetFont("SlashMoon.Small")
    rarityLabel:SetTextColor(rarityColor)
    rarityLabel:SetText(SlashMoon.Tasks.Lang("sn.inv.rarity") .. ": " .. rarityName)

    -- Разделитель
    local divider1 = vgui.Create("SlashMoon.Panel", InspectContent)
    divider1:Dock(TOP)
    divider1:SetTall(SlashMoon.UI.Scale(8))
    divider1:DockMargin(SlashMoon.UI.Scale(10), SlashMoon.UI.Scale(5), SlashMoon.UI.Scale(10), 0)
    divider1.Paint = function(self, w, h)
        surface.SetDrawColor(colors.Outline)
        surface.DrawRect(0, h / 2, w, 1)
    end

    -- Описание
    local descLabel = vgui.Create("SlashMoon.Label", InspectContent)
    descLabel:Dock(TOP)
    descLabel:SetWrap(true)
    descLabel:SetAutoStretchVertical(true)
    descLabel:DockMargin(SlashMoon.UI.Scale(10), SlashMoon.UI.Scale(5), SlashMoon.UI.Scale(10), 0)
    descLabel:SetFont("SlashMoon.Small")
    descLabel:SetTextColor(colors.TextMuted)
    descLabel:SetText(description ~= "" and description or SlashMoon.Tasks.Lang("sn.inv.no_description"))

    -- Разделитель
    local divider2 = vgui.Create("SlashMoon.Panel", InspectContent)
    divider2:Dock(TOP)
    divider2:SetTall(SlashMoon.UI.Scale(8))
    divider2:DockMargin(SlashMoon.UI.Scale(10), SlashMoon.UI.Scale(8), SlashMoon.UI.Scale(10), 0)
    divider2.Paint = function(self, w, h)
        surface.SetDrawColor(colors.Outline)
        surface.DrawRect(0, h / 2, w, 1)
    end

    -- Характеристики
    local statsLabel = vgui.Create("SlashMoon.Label", InspectContent)
    statsLabel:Dock(TOP)
    statsLabel:SetTall(SlashMoon.UI.Scale(20))
    statsLabel:DockMargin(SlashMoon.UI.Scale(10), SlashMoon.UI.Scale(2), 0, 0)
    statsLabel:SetFont("SlashMoon.Small")
    statsLabel:SetTextColor(colors.TextMuted)
    statsLabel:SetText(SlashMoon.Tasks.Lang("sn.inv.characteristics"))

    -- Экипируемость
    local equippable = SlashMoon.Tasks.IsEquippable(itemClass)
    local equipLabel = vgui.Create("SlashMoon.Label", InspectContent)
    equipLabel:Dock(TOP)
    equipLabel:SetTall(SlashMoon.UI.Scale(18))
    equipLabel:DockMargin(SlashMoon.UI.Scale(15), SlashMoon.UI.Scale(2), 0, 0)
    equipLabel:SetFont("SlashMoon.Small")
    equipLabel:SetTextColor(equippable and Color(50, 255, 100) or Color(255, 100, 80))
    equipLabel:SetText("  " .. (equippable and SlashMoon.Tasks.Lang("sn.inv.can_equip") or SlashMoon.Tasks.Lang("sn.inv.cannot_equip")))

    -- Стакируемость
    local stackable = SlashMoon.Tasks.IsStackable(itemClass)
    local stackLabel = vgui.Create("SlashMoon.Label", InspectContent)
    stackLabel:Dock(TOP)
    stackLabel:SetTall(SlashMoon.UI.Scale(18))
    stackLabel:DockMargin(SlashMoon.UI.Scale(15), SlashMoon.UI.Scale(2), 0, 0)
    stackLabel:SetFont("SlashMoon.Small")
    stackLabel:SetTextColor(stackable and Color(50, 255, 100) or Color(180, 180, 180))
    stackLabel:SetText("  " .. (stackable and SlashMoon.Tasks.Lang("sn.inv.stackable") or SlashMoon.Tasks.Lang("sn.inv.not_stackable")))

    -- Уникальность
    local unique = data.unique
    local uniqueLabel = vgui.Create("SlashMoon.Label", InspectContent)
    uniqueLabel:Dock(TOP)
    uniqueLabel:SetTall(SlashMoon.UI.Scale(18))
    uniqueLabel:DockMargin(SlashMoon.UI.Scale(15), SlashMoon.UI.Scale(2), 0, 0)
    uniqueLabel:SetFont("SlashMoon.Small")
    uniqueLabel:SetTextColor(unique and Color(255, 180, 50) or Color(180, 180, 180))
    uniqueLabel:SetText("  " .. (unique and SlashMoon.Tasks.Lang("sn.inv.unique") or SlashMoon.Tasks.Lang("sn.inv.not_unique")))

    -- Количество в стаке
    if parsedItem.count > 1 then
        local countLabel = vgui.Create("SlashMoon.Label", InspectContent)
        countLabel:Dock(TOP)
        countLabel:SetTall(SlashMoon.UI.Scale(18))
        countLabel:DockMargin(SlashMoon.UI.Scale(15), SlashMoon.UI.Scale(2), 0, 0)
        countLabel:SetFont("SlashMoon.Small")
        countLabel:SetTextColor(color_white)
        countLabel:SetText("  " .. SlashMoon.Tasks.Lang("sn.inv.count") .. ": " .. parsedItem.count)
    end

    -- Топливо канистры
    if data.fuel then
        local fuelLabel = vgui.Create("SlashMoon.Label", InspectContent)
        fuelLabel:Dock(TOP)
        fuelLabel:SetTall(SlashMoon.UI.Scale(18))
        fuelLabel:DockMargin(SlashMoon.UI.Scale(15), SlashMoon.UI.Scale(2), 0, 0)
        fuelLabel:SetFont("SlashMoon.Small")
        fuelLabel:SetTextColor(Color(255, 200, 50))
        fuelLabel:SetText("  " .. SlashMoon.Tasks.Lang("sn.inv.fuel") .. ": " .. data.fuel .. "%")
    end

    InspectContent:InvalidateLayout(true)
end

-- ========================================================
-- ОКНО ИНВЕНТАРЯ (Оригинальный дизайн: DModelPanel + слоты вокруг)
-- + Панель осмотра СЛЕВА
-- ========================================================

function SlashMoon.Tasks.OpenInventory()
    if IsValid(InvRoot) then InvRoot:Remove() return end

    local ply = LocalPlayer()
    if not SlashMoon.Tasks.Game.IsSurvivor(ply) or SlashMoon.Tasks.Game.IsEditor(ply) then return end

    if ply:GetNW2Bool("KillerMaskEquiped", false) then
        SlashMoon.UI.Popup(SlashMoon.Tasks.Lang("sn.inv.mania_title"), SlashMoon.Tasks.Lang("sn.inv.mania_text"), SlashMoon.Tasks.Lang("sn.inv.ok"))
        return
    end

    net.Start("SN_Inv_RequestSync")
    net.SendToServer()

    InvRoot = vgui.Create("SlashMoon.Panel")
    InvRoot:SetSize(ScrW(), ScrH())
    InvRoot:MakePopup()
    InvRoot:SetKeyboardInputEnabled(false)
    InvRoot.Paint = function(self, w, h)
        surface.SetDrawColor(0, 0, 0, 100)
        surface.DrawRect(0, 0, w, h)
    end

    -- InvRoot is a full-screen popup used for the backdrop and drag receiver.
    -- Clicking it must not leave the child frame behind in the popup stack.
    InvRoot.OnMousePressed = function(self)
        if IsValid(InvMenu) then
            InvMenu:MakePopup()
            InvMenu:MoveToFront()
            if InvMenu.RequestFocus then InvMenu:RequestFocus() end
        end
    end
    
    -- Drag-сброс вне меню = выброс в мир
    InvRoot:Receiver("SN_Item", function(self, panels, bDoDrop, Command, x, y)
        if bDoDrop then
            local mx, my = gui.MousePos()
            local menuX, menuY = InvMenu:GetPos()
            local menuW, menuH = InvMenu:GetSize()

            if mx >= menuX and mx <= menuX + menuW and my >= menuY and my <= menuY + menuH then return end

            local pnl = panels[1]
            surface.PlaySound("physics/cardboard/cardboard_box_impact_soft2.wav")
            net.Start("SN_Inv_Action")
            net.WriteString("drop_world")
            net.WriteString(pnl.ItemType)
            net.WriteString(pnl.ItemClass)
            net.WriteUInt(pnl.SlotIndex or 0, 8)
            net.SendToServer()
        end
    end)

    -- ══════════════════════════════════════════════════════════
    -- ОСНОВНОЕ ОКНО ИНВЕНТАРЯ (создаём ПЕРВЫМ — блюр должен
    -- отрисоваться до панели осмотра, иначе блюр замылит её)
    -- ══════════════════════════════════════════════════════════
    InvMenu = vgui.Create("SlashMoon.Frame", InvRoot)
    InvMenu:SetBlurEnabled(false)
    InvMenu:SetSize(SlashMoon.UI.Scale(1000), SlashMoon.UI.Scale(700))
    InvMenu:Center()
    InvMenu:SetHeader(SlashMoon.Tasks.Lang("sn.inv.title"))
    InvMenu.OnRemove = function()
        if IsValid(InvRoot) then InvRoot:Remove() end
    end

    -- ══════════════════════════════════════════════════════════
    -- ПАНЕЛЬ ОСМОТРА (СЛЕВА от основного окна)
    -- Создаём ПОСЛЕ InvMenu — чтобы рендерился поверх блюра.
    -- Используем DPanel вместо SN_Frame: панели осмотра не нужен
    -- MakePopup() — иначе она перехватывает ESC у основного окна.
    -- ══════════════════════════════════════════════════════════
    InspectPanel = vgui.Create("SlashMoon.Panel", InvRoot)
    InspectPanel:SetSize(SlashMoon.UI.Scale(280), SlashMoon.UI.Scale(700))
    InspectPanel:SetVisible(false) -- Скрыта до выбора "Осмотреть"
    InspectPanel:SetMouseInputEnabled(false)
    InspectPanel:SetKeyboardInputEnabled(false)
    -- Заголовок (используется в Paint)
    InspectPanel.TitleText = SlashMoon.Tasks.Lang("sn.inv.inspect")
    -- Заглушка CloseBtn — чтобы UpdateInspectPanel не падала при очистке детей
    InspectPanel.CloseBtn = NULL
    -- Отрисовка в стиле SN_Frame, но без Derma_DrawBackgroundBlur и без MakePopup
    InspectPanel.Paint = function(self, w, h)
        -- Основной фон
        surface.SetDrawColor(colors.Background)
        surface.DrawRect(0, 0, w, h)

        -- Шапка
        surface.SetDrawColor(colors.DarkBG)
        surface.DrawRect(0, 0, w, 40)

        -- Неоновая линия сверху
        surface.SetDrawColor(colors.Theme)
        surface.DrawRect(0, 0, w, 2)

        -- Обводка всего окна
        surface.SetDrawColor(colors.Outline)
        surface.DrawOutlinedRect(0, 0, w, h, 1)

        -- Заголовок
        draw.SimpleText(self.TitleText, "SlashMoon.Header", 15, 20, colors.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    InspectContent = vgui.Create("SlashMoon.Scroll", InspectPanel)
    InspectContent:Dock(FILL)
    InspectContent:DockMargin(SlashMoon.UI.Scale(6), SlashMoon.UI.Scale(42), SlashMoon.UI.Scale(6), SlashMoon.UI.Scale(6))
    InspectContent:SetMouseInputEnabled(false)
    InspectContent:SetKeyboardInputEnabled(false)

    -- Позиционируем панель осмотра слева от основного окна
    local function PositionInspectPanel()
        if not IsValid(InspectPanel) or not IsValid(InvMenu) then return end
        local menuX, menuY = InvMenu:GetPos()
        local inspectW = InspectPanel:GetWide()
        local newX = menuX - inspectW - SlashMoon.UI.Scale(10)
        -- Не двигаем основное окно: повторный осмотр больше не уводит инвентарь за экран.
        newX = math.max(SlashMoon.UI.Scale(5), newX)
        InspectPanel:SetPos(newX, menuY)
    end

    PositionInspectPanel()

    -- === ЛЕВАЯ ПАНЕЛЬ (РЮКЗАК) ===
    local leftPanel = vgui.Create("SlashMoon.Panel", InvMenu)
    leftPanel:Dock(LEFT)
    leftPanel:SetWide(SlashMoon.UI.Scale(500))
    leftPanel:DockMargin(15, 15, 0, 15)
    leftPanel.Paint = function(self, w, h)
        surface.SetDrawColor(20, 20, 20, 200)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(colors.Theme)
        surface.DrawRect(0, 0, w, 2)
        surface.SetDrawColor(colors.Outline)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local sortBtn = vgui.Create("SlashMoon.Button", leftPanel)
    sortBtn:Dock(BOTTOM)
    sortBtn:SetTall(SlashMoon.UI.Scale(40))
    sortBtn:DockMargin(10, 10, 10, 10)
    sortBtn:SetBtnText(SlashMoon.Tasks.Lang("sn.inv.sort"))
    sortBtn.DoClick = function()
        surface.PlaySound("UI/buttonclick.wav")
        net.Start("SN_Inv_Action")
        net.WriteString("sort")
        net.SendToServer()
    end

    local bpScroll = vgui.Create("SlashMoon.Scroll", leftPanel)
    bpScroll:Dock(FILL)
    bpScroll:DockMargin(10, 10, 10, 10)

    local bpGrid = vgui.Create("SlashMoon.Grid", bpScroll)
    bpGrid:Dock(FILL)
    bpGrid:SetSpaceX(SlashMoon.UI.Scale(8))
    bpGrid:SetSpaceY(SlashMoon.UI.Scale(8))

    -- Обработчик сброса на рюкзак (из хотбара)
    local function HandleBackpackDrop(self, panels, bDoDrop, Command, x, y)
        if bDoDrop then
            local pnl = panels[1]
            if pnl.ItemType == "hotbar" then
                surface.PlaySound("UI/buttonclick.wav")
                net.Start("SN_Inv_Action")
                net.WriteString("drag_hb_to_bp")
                net.WriteUInt(pnl.SlotIndex, 4)
                net.SendToServer()
            end
        end
    end
    leftPanel:Receiver("SN_Item", HandleBackpackDrop)
    bpScroll:Receiver("SN_Item", HandleBackpackDrop)

    -- === ПРАВАЯ ПАНЕЛЬ (ЭКИПИРОВКА + МОДЕЛЬКА) ===
    local rightPanel = vgui.Create("SlashMoon.Panel", InvMenu)
    rightPanel:Dock(FILL)
    rightPanel:DockMargin(15, 15, 15, 15)
    rightPanel.Paint = function(self, w, h)
        surface.SetDrawColor(15, 15, 15, 240)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(colors.Theme)
        surface.DrawRect(0, 0, w, 2)
        surface.SetDrawColor(colors.Outline)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        SlashMoon.UI.Draw.TextShadow(SlashMoon.Tasks.Lang("sn.inv.equip"), "SlashMoon.Header", 15, 15, colors.TextMuted, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end

    -- Моделька игрока (как в оригинале)
    local playerModel = vgui.Create("SlashMoon.ModelPanel", rightPanel)
    playerModel:Dock(FILL)
    playerModel:SetModel(ply:GetModel())
    playerModel:SetFOV(35)
    playerModel:SetCamPos(Vector(70, 0, 40))
    playerModel:SetLookAt(Vector(0, 0, 40))
    playerModel.LayoutEntity = function(self, ent)
        ent:SetSequence(ent:LookupSequence("pose_standing_01") or 0)
        self:RunAnimation()
    end

    -- === ХОТБАР СЛОТЫ (вокруг модельки, как в оригинале) ===
    local hotbarSlots = {}

    function InvMenu:Rebuild()
        bpGrid:Clear()

        -- Сетка рюкзака: минимум 30 слотов, по 5 в ряд
        local itemsCount = #SlashMoon.Tasks.Backpack
        local totalSlots = math.max(30, math.ceil((itemsCount + 5) / 5) * 5)
        local slotSize = SlashMoon.UI.Scale(90)

        for i = 1, totalSlots do
            local item = SlashMoon.Tasks.Backpack[i]
            local slot = bpGrid:Add("SlashMoon.Panel")
            slot:SetSize(slotSize, slotSize)
            slot:Receiver("SN_Item", HandleBackpackDrop)

            slot.Paint = function(self, w, h)
                surface.SetDrawColor(30, 30, 30, 200)
                surface.DrawRect(0, 0, w, h)
                surface.SetDrawColor(colors.Outline)
                surface.DrawOutlinedRect(0, 0, w, h, 1)
            end

            if item then
                local btn = vgui.Create("SlashMoon.Button", slot)
                btn:Dock(FILL)
                btn:SetText("")
                btn.ItemType = "backpack"
                btn.ItemClass = item
                btn.SlotIndex = i
                btn.LastClick = 0
                btn:Droppable("SN_Item")
                btn:Receiver("SN_Item", HandleBackpackDrop)

                local data = GetCachedItemData(item)
                local parsedItem = SlashMoon.Tasks.ParseItemEntry(item)
                local isEquippable = SlashMoon.Tasks.IsEquippable(item)
                local stackCount = parsedItem.count

                btn.Paint = function(self, w, h)
                    local isHovered = self:IsHovered()
                    
                    -- Фон слота
                    surface.SetDrawColor(30, 30, 30, 200)
                    surface.DrawRect(0, 0, w, h)
                    
                    -- Цветная полоска по типу предмета (слева)
                    local typeColor = SlashMoon.Tasks.GetTypeColor(data.type)
                    surface.SetDrawColor(typeColor)
                    surface.DrawRect(0, 0, 4, h)
                    
                    -- Редкость: обводка рамкой (для оружия — ярко, для остальных — тонко)
                    if data.type == "weapon" and data.rarity then
                        local rarityCol = SlashMoon.Tasks.GetRarityColor(data.rarity)
                        if data.rarity ~= "common" then
                            -- Нередкое оружие: яркая рамка + свечение
                            surface.SetDrawColor(rarityCol.r, rarityCol.g, rarityCol.b, 60)
                            surface.DrawRect(4, 0, w - 4, h)
                            surface.SetDrawColor(rarityCol)
                            surface.DrawOutlinedRect(2, 2, w - 4, h - 4, 2)
                        else
                            -- Common: тонкая серая рамка
                            surface.SetDrawColor(rarityCol.r, rarityCol.g, rarityCol.b, 80)
                            surface.DrawOutlinedRect(2, 2, w - 4, h - 4, 1)
                        end
                    end

                    -- Подсветка при наведении
                    if isHovered then
                        surface.SetDrawColor(typeColor.r, typeColor.g, typeColor.b, 40)
                        surface.DrawRect(0, 0, w, h)
                    end

                    -- Получаем актуальный материал каждый кадр
                    local mat = SlashMoon.Tasks.GetItemMaterial(item)
                    
                    -- Иконка или текст
                    if mat and not mat:IsError() then
                        local iconSize = w - 20
                        surface.SetMaterial(mat)
                        surface.SetDrawColor(255, 255, 255, isHovered and 255 or 220)
                        surface.DrawTexturedRect(10, (h - iconSize) / 2, iconSize, iconSize)
                        SlashMoon.UI.Draw.TextShadow(data.name, "SlashMoon.Small", w / 2, h - 8, isHovered and color_white or colors.TextMuted, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
                    else
                        SlashMoon.UI.Draw.TextShadow(data.name, "SlashMoon.Small", w/2, h/2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    end

                    -- Счётчик стака (правый нижний угол)
                    if stackCount > 1 then
                        local countText = tostring(stackCount)
                        local countW = surface.GetTextSize("SlashMoon.Small") > 0 and #countText * 8 + 8 or 24
                        countW = math.max(countW, 22)
                        local countH = 16
                        local cx = w - countW - 2
                        local cy = h - countH - 2

                        surface.SetDrawColor(0, 0, 0, 180)
                        surface.DrawRect(cx, cy, countW, countH)
                        surface.SetDrawColor(typeColor)
                        surface.DrawOutlinedRect(cx, cy, countW, countH, 1)
                        SlashMoon.UI.Draw.TextShadow(countText, "SlashMoon.Small", cx + countW / 2, cy + countH / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    end

                    -- Редкость: маленький индикатор (для оружия) в правом верхнем углу
                    if data.type == "weapon" and data.rarity and data.rarity ~= "common" then
                        local rarityCol = SlashMoon.Tasks.GetRarityColor(data.rarity)
                        local dotSize = 6
                        surface.SetDrawColor(rarityCol)
                        surface.DrawRect(w - dotSize - 3, 3, dotSize, dotSize)
                    end
                    
                    -- Обводка
                    surface.SetDrawColor(colors.Outline)
                    surface.DrawOutlinedRect(0, 0, w, h, 1)
                end

                local oldPress = btn.OnMousePressed
                btn.OnMousePressed = function(self, code)
                    if code == MOUSE_LEFT then
                        -- Дабл-клик = экипировать (ТОЛЬКО оружие)
                        if RealTime() - (self.LastClick or 0) < 0.35 then
                            if not isEquippable then
                                surface.PlaySound("buttons/button10.wav")
                                return
                            end
                            if IsAlreadyInHotbar(item) then
                                surface.PlaySound("buttons/button10.wav")
                                SlashMoon.UI.Popup(SlashMoon.Tasks.Lang("sn.inv.mania_title"), SlashMoon.Tasks.Lang("sn.inv.equip"), SlashMoon.Tasks.Lang("sn.inv.ok"))
                                return
                            end

                            surface.PlaySound("UI/buttonclick.wav")
                            net.Start("SN_Inv_Action")
                            net.WriteString("fast_equip")
                            net.WriteString(item)
                            net.SendToServer()
                            self.LastClick = 0
                            return
                        end
                        self.LastClick = RealTime()

                    elseif code == MOUSE_RIGHT then
                        surface.PlaySound("UI/buttonclick.wav")
                        local contextOptions = {}

                        -- "Экипировать" — только для оружия
                        if isEquippable then
                            table.insert(contextOptions, { text = SlashMoon.Tasks.Lang("sn.inv.equip"), color = Color(50, 200, 100), onClick = function()
                                if IsAlreadyInHotbar(item) then
                                    surface.PlaySound("buttons/button10.wav")
                                    return
                                end

                                net.Start("SN_Inv_Action")
                                net.WriteString("fast_equip")
                                net.WriteString(item)
                                net.SendToServer()
                            end })
                        end

                        -- "Осмотреть" — для ВСЕХ предметов
                        table.insert(contextOptions, { text = SlashMoon.Tasks.Lang("sn.inv.inspect"), color = Color(100, 180, 255), onClick = function()
                            surface.PlaySound("UI/buttonclick.wav")
                            UpdateInspectPanel(item)
                            PositionInspectPanel()
                        end })

                        table.insert(contextOptions, { text = SlashMoon.Tasks.Lang("sn.inv.drop_world"), color = Color(255,50,50), onClick = function()
                            net.Start("SN_Inv_Action")
                            net.WriteString("drop_world")
                            net.WriteString("backpack")
                            net.WriteString(item)
                            net.WriteUInt(i, 8)
                            net.SendToServer()
                        end })

                        SlashMoon.Tasks.OpenContextMenu(contextOptions)
                        return
                    end

                    if oldPress then oldPress(self, code) end
                end
            end
        end

        -- Обновление слотов хотбара
        for _, s in ipairs(hotbarSlots) do s:Remove() end
        table.Empty(hotbarSlots)

        for i = 1, SlashMoon.Tasks.Config.MaxHotbar do
            local slotIdx = i
            local item = SlashMoon.Tasks.Hotbar[slotIdx]
            local slot = vgui.Create("SlashMoon.Panel", rightPanel)
            slot:SetSize(SlashMoon.UI.Scale(100), SlashMoon.UI.Scale(100))
            table.insert(hotbarSlots, slot)

            slot.Paint = function(self, w, h)
                surface.SetDrawColor(20, 20, 20, 240)
                surface.DrawRect(0, 0, w, h)
                surface.SetDrawColor(colors.Theme)
                surface.DrawOutlinedRect(0, 0, w, h, 1)

                if not item then
                    SlashMoon.UI.Draw.TextShadow(SlashMoon.Tasks.Lang("sn.hotbar.empty"), "SlashMoon.Small", w/2, h/2, colors.TextMuted, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
            end

            -- Обработчик сброса на слот хотбара
            local function HandleHotbarDrop(self, panels, bDoDrop, Command, x, y)
                if bDoDrop then
                    local pnl = panels[1]

                    if pnl.ItemType == "backpack" then
                        -- Только оружие можно экипировать
                        if not SlashMoon.Tasks.IsEquippable(pnl.ItemClass) then
                            surface.PlaySound("buttons/button10.wav")
                            return
                        end
                        if IsAlreadyInHotbar(pnl.ItemClass) then
                            surface.PlaySound("buttons/button10.wav")
                            return
                        end

                        surface.PlaySound("UI/buttonclick.wav")
                        net.Start("SN_Inv_Action")
                        net.WriteString("drag_bp_to_hb")
                        net.WriteString(pnl.ItemClass)
                        net.WriteUInt(slotIdx, 4)
                        net.SendToServer()
                    elseif pnl.ItemType == "hotbar" then
                        surface.PlaySound("UI/buttonclick.wav")
                        net.Start("SN_Inv_Action")
                        net.WriteString("swap_hb")
                        net.WriteUInt(pnl.SlotIndex, 4)
                        net.WriteUInt(slotIdx, 4)
                        net.SendToServer()
                    end
                end
            end
            slot:Receiver("SN_Item", HandleHotbarDrop)

            if item then
                local btn = vgui.Create("SlashMoon.Button", slot)
                btn:Dock(FILL)
                btn:DockMargin(2,2,2,2)
                btn:SetText("")
                btn.ItemType = "hotbar"
                btn.ItemClass = item
                btn.SlotIndex = slotIdx
                btn.LastClick = 0
                btn:Droppable("SN_Item")
                btn:Receiver("SN_Item", HandleHotbarDrop)

                local data = GetCachedItemData(item)

                btn.Paint = function(self, w, h)
                    local isHovered = self:IsHovered()
                    
                    -- Фон слота
                    surface.SetDrawColor(20, 20, 20, 200)
                    surface.DrawRect(0, 0, w, h)
                    
                    -- Рамка: приоритет редкости для оружия, тип для остального
                    if data.type == "weapon" and data.rarity then
                        local rarityCol = SlashMoon.Tasks.GetRarityColor(data.rarity)
                        -- Свечение фона для нередкого оружия
                        if data.rarity ~= "common" then
                            surface.SetDrawColor(rarityCol.r, rarityCol.g, rarityCol.b, 40)
                            surface.DrawRect(0, 0, w, h)
                        end
                        surface.SetDrawColor(rarityCol)
                        surface.DrawOutlinedRect(0, 0, w, h, 3)
                    else
                        local typeColor = SlashMoon.Tasks.GetTypeColor(data.type)
                        surface.SetDrawColor(typeColor)
                        surface.DrawOutlinedRect(0, 0, w, h, 3)
                    end

                    -- Подсветка при наведении
                    if isHovered then
                        local typeColor = SlashMoon.Tasks.GetTypeColor(data.type)
                        surface.SetDrawColor(typeColor.r, typeColor.g, typeColor.b, 60)
                        surface.DrawRect(0, 0, w, h)
                    end
                    
                    -- Получаем актуальный материал каждый кадр
                    local mat = SlashMoon.Tasks.GetItemMaterial(item)
                    
                    -- Иконка или текст
                    if mat and not mat:IsError() then
                        local iconSize = math.min(w, h) - 16
                        surface.SetMaterial(mat)
                        surface.SetDrawColor(255, 255, 255, isHovered and 255 or 200)
                        local x = (w - iconSize) / 2
                        local y = (h - iconSize) / 2
                        surface.DrawTexturedRect(x, y, iconSize, iconSize)
                    else
                        SlashMoon.UI.Draw.TextShadow(data.name, "SlashMoon.Small", w/2, h/2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    end
                end

                local oldPress = btn.OnMousePressed
                btn.OnMousePressed = function(self, code)
                    if code == MOUSE_LEFT then
                        -- Дабл-клик = убрать в рюкзак
                        if RealTime() - (self.LastClick or 0) < 0.35 then
                            surface.PlaySound("UI/buttonclick.wav")
                            net.Start("SN_Inv_Action")
                            net.WriteString("unequip")
                            net.WriteUInt(slotIdx, 4)
                            net.SendToServer()
                            self.LastClick = 0
                            return
                        end
                        self.LastClick = RealTime()

                    elseif code == MOUSE_RIGHT then
                        surface.PlaySound("UI/buttonclick.wav")
                        local contextOptions = {
                            { text = SlashMoon.Tasks.Lang("sn.inv.unequip"), color = Color(255, 150, 50), onClick = function()
                                net.Start("SN_Inv_Action")
                                net.WriteString("unequip")
                                net.WriteUInt(slotIdx, 4)
                                net.SendToServer()
                            end },
                            -- "Осмотреть" для хотбара тоже
                            { text = SlashMoon.Tasks.Lang("sn.inv.inspect"), color = Color(100, 180, 255), onClick = function()
                                surface.PlaySound("UI/buttonclick.wav")
                                UpdateInspectPanel(item)
                                PositionInspectPanel()
                            end },
                            { text = SlashMoon.Tasks.Lang("sn.inv.drop_world"), color = Color(255,50,50), onClick = function()
                                net.Start("SN_Inv_Action")
                                net.WriteString("drop_world")
                                net.WriteString("hotbar")
                                net.WriteString(item)
                                net.WriteUInt(slotIdx, 8)
                                net.SendToServer()
                            end }
                        }
                        SlashMoon.Tasks.OpenContextMenu(contextOptions)
                        return
                    end

                    if oldPress then oldPress(self, code) end
                end
            end
        end
        rightPanel:InvalidateLayout(true)
    end

    -- Позиционирование слотов вокруг модельки (как в оригинале)
    rightPanel.PerformLayout = function(self, w, h)
        local slotSize = SlashMoon.UI.Scale(100)

        if hotbarSlots[1] then hotbarSlots[1]:SetPos(SlashMoon.UI.Scale(30), SlashMoon.UI.Scale(120)) end
        if hotbarSlots[2] then hotbarSlots[2]:SetPos(w - slotSize - SlashMoon.UI.Scale(30), SlashMoon.UI.Scale(120)) end
        if hotbarSlots[3] then hotbarSlots[3]:SetPos(SlashMoon.UI.Scale(30), SlashMoon.UI.Scale(270)) end
    end

    InvMenu:Rebuild()
end

-- ========================================================
-- ОТКРЫТИЕ ИНВЕНТАРЯ НА КЛАВИШУ I (как в оригинале)
-- ========================================================

if not GetConVar("sn_inventory_key") then
    CreateClientConVar("sn_inventory_key", tostring(KEY_I), true, false, "Клавиша открытия инвентаря")
end

local inventoryKeyWasDown = false

local function GetInventoryKey()
    local cv = GetConVar("sn_inventory_key")
    local keyCode = cv and cv:GetInt() or KEY_I
    return input.GetKeyName(keyCode) and keyCode or KEY_I
end

SlashMoon.Tasks.GetInventoryKey = GetInventoryKey

local function IsInventoryInputBlocked()
    if gui.IsGameUIVisible and gui.IsGameUIVisible() then return true end

    local focus = vgui.GetKeyboardFocus and vgui.GetKeyboardFocus()
    if not IsValid(focus) then return false end

    local className = focus.GetClassName and focus:GetClassName() or focus:GetClass()
    return className == "DTextEntry"
        or className == "DTextEntryMultiLine"
        or className == "TextEntry"
        or className == "DBinder"
end

MODULE:Hook("Think", "SN_Inventory_ToggleUI", function()
    local isDown = input.IsKeyDown(GetInventoryKey())
    if isDown == inventoryKeyWasDown then return end
    inventoryKeyWasDown = isDown
    if not isDown then return end

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    if IsInventoryInputBlocked() then return end

    -- A press always closes an existing inventory, even if the player's
    -- state changed while it was open.
    if IsValid(InvRoot) then
        InvRoot:Remove()
        return
    end

    if SlashMoon.Tasks.Game.IsSpectator(ply) or SlashMoon.Tasks.Game.IsEditor(ply) then return end

    if ply:GetNW2Bool("KillerMaskEquiped", false) then
        surface.PlaySound("buttons/button10.wav")
        SlashMoon.UI.Popup(SlashMoon.Tasks.Lang("sn.inv.mania_title"), SlashMoon.Tasks.Lang("sn.inv.mania_text"), SlashMoon.Tasks.Lang("sn.inv.ok"))
        return
    end

    SlashMoon.Tasks.OpenInventory()
end)

-- Консольная команда (для отладки)
MODULE:Command("sn_inventory", function()
    SlashMoon.Tasks.OpenInventory()
end)

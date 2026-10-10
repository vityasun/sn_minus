-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("tasks")

-- ========================================================
-- SN Tasks: Pinned crafting recipe HUD
-- ========================================================
if not CLIENT then return end

SlashMoon.Tasks = SlashMoon.Tasks or {}

local pinnedRecipe
local recipePanel
local editing = false
local dragOffsetX, dragOffsetY
local CreateRecipePanel
local position = {
    x = nil,
    y = SlashMoon.UI.Scale(90),
}

SlashMoon.Tasks.PinnedRecipe = nil

local function GroupIngredients(ingredients)
    local grouped = {}
    local order = {}

    for _, ingredient in ipairs(ingredients or {}) do
        local parsed = SlashMoon.Tasks.ParseItemEntry(ingredient)
        local itemClass = parsed.baseClass
        if not grouped[itemClass] then
            grouped[itemClass] = { class = itemClass, count = 0 }
            order[#order + 1] = grouped[itemClass]
        end
        grouped[itemClass].count = grouped[itemClass].count + (parsed.count or 1)
    end

    return order
end

local function GetRecipePosition(width)
    return position.x or ScrW() - width - SlashMoon.UI.Scale(20), position.y
end

local function SavePosition(panel)
    position.x, position.y = panel:GetPos()
end

local function CloseEditing()
    editing = false
    if IsValid(recipePanel) then
        recipePanel.Dragging = false
        recipePanel:MouseCapture(false)
        recipePanel:SetMouseInputEnabled(false)
        recipePanel:SetKeyboardInputEnabled(false)
        recipePanel:SetCursor("arrow")
    end
    gui.EnableScreenClicker(false)
end

function SlashMoon.Tasks.SetPinnedRecipeEditing(enabled)
    if not pinnedRecipe then
        CloseEditing()
        return
    end

    if not enabled then
        CloseEditing()
        return
    end

    editing = true
    if not IsValid(recipePanel) then CreateRecipePanel() end
    if not IsValid(recipePanel) then return end

    recipePanel:SetMouseInputEnabled(true)
    recipePanel:SetKeyboardInputEnabled(false)
    recipePanel:SetCursor("sizeall")
    recipePanel:MakePopup()
    gui.EnableScreenClicker(true)
end

CreateRecipePanel = function()
    if IsValid(recipePanel) then recipePanel:Remove() end
    if not pinnedRecipe then return end

    local scale = SlashMoon.UI.Scale
    local width = scale(285)
    local rowHeight = scale(42)
    local headerHeight = scale(38)
    local height = headerHeight + scale(8) + #pinnedRecipe.ingredients * rowHeight + scale(10)
    local x, y = GetRecipePosition(width)

    recipePanel = vgui.Create("SlashMoon.Panel")
    recipePanel:SetSize(width, height)
    recipePanel:SetPos(math.Clamp(x, 0, ScrW() - width), math.Clamp(y, 0, ScrH() - height))
    recipePanel:SetMouseInputEnabled(editing)
    recipePanel:SetCursor(editing and "sizeall" or "arrow")

    recipePanel.Paint = function(self, w, h)
        local colors = SlashMoon.UI.Colors
        surface.SetDrawColor(colors.DarkBG)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(colors.Theme)
        surface.DrawRect(0, 0, w, scale(3))
        surface.SetDrawColor(colors.Outline)
        surface.DrawOutlinedRect(0, 0, w, h, 1)

        SlashMoon.UI.Draw.TextShadow(SlashMoon.Tasks.Lang("sn.workbench.pinned_recipe"), "SlashMoon.Header", scale(12), headerHeight / 2, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        SlashMoon.UI.Draw.TextShadow(SlashMoon.Tasks.Lang(pinnedRecipe.nameKey), "SlashMoon.Small", w - scale(12), headerHeight / 2, colors.TextMuted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

        for index, ingredient in ipairs(pinnedRecipe.ingredients) do
            local itemClass = ingredient.class
            local itemData = SlashMoon.Tasks.GetItemData(itemClass) or {}
            local count = 0
            local yPos = headerHeight + scale(8) + (index - 1) * rowHeight
            for _, item in ipairs(SlashMoon.Tasks.Backpack or {}) do
                local backpackItem = SlashMoon.Tasks.ParseItemEntry(item)
                if backpackItem.baseClass == itemClass then count = count + backpackItem.count end
            end

            surface.SetDrawColor(15, 15, 15, 220)
            surface.DrawRect(scale(8), yPos, w - scale(16), rowHeight - scale(4))
            surface.SetDrawColor(SlashMoon.Tasks.GetTypeColor(itemData.type))
            surface.DrawRect(scale(8), yPos, scale(3), rowHeight - scale(4))

            local material = SlashMoon.Tasks.GetItemMaterial(itemClass)
            if material and not material:IsError() then
                surface.SetMaterial(material)
                surface.SetDrawColor(255, 255, 255, 230)
                surface.DrawTexturedRect(scale(17), yPos + scale(5), rowHeight - scale(14), rowHeight - scale(14))
            end

            SlashMoon.UI.Draw.TextShadow(SlashMoon.Tasks.GetItemName(itemClass), "SlashMoon.Small", scale(58), yPos + scale(12), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            local enough = count >= ingredient.count
            SlashMoon.UI.Draw.TextShadow(count .. " / " .. ingredient.count, "SlashMoon.Small", scale(58), yPos + scale(28), enough and Color(80, 220, 100) or Color(255, 100, 80), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end

    recipePanel.OnMousePressed = function(self, code)
        if not editing or code ~= MOUSE_LEFT then return end
        dragOffsetX, dragOffsetY = gui.MouseX() - self.x, gui.MouseY() - self.y
        self.Dragging = true
        self:MouseCapture(true)
    end

    recipePanel.OnMouseReleased = function(self, code)
        if code ~= MOUSE_LEFT then return end
        self.Dragging = false
        self:MouseCapture(false)
        SavePosition(self)
    end

    recipePanel.Think = function(self)
        if not editing or not self.Dragging then return end
        local x = math.Clamp(gui.MouseX() - dragOffsetX, 0, ScrW() - self:GetWide())
        local y = math.Clamp(gui.MouseY() - dragOffsetY, 0, ScrH() - self:GetTall())
        self:SetPos(x, y)
    end
end

local function RebuildPinnedRecipePanel()
    if pinnedRecipe then CreateRecipePanel() end
end

MODULE:Receive("SN_Workbench_PinnedRecipe", function()
    if not net.ReadBool() then
        pinnedRecipe = nil
        SlashMoon.Tasks.PinnedRecipe = nil
        editing = false
        hook.Run("SN_Tasks_PinnedRecipeChanged")
        if IsValid(recipePanel) then recipePanel:Remove() end
        return
    end

    pinnedRecipe = {
        id = net.ReadString(),
        nameKey = net.ReadString(),
        result = net.ReadString(),
        ingredients = {},
    }
    local ingredients = {}
    for i = 1, net.ReadUInt(8) do ingredients[i] = net.ReadString() end
    pinnedRecipe.ingredients = GroupIngredients(ingredients)
    SlashMoon.Tasks.PinnedRecipe = pinnedRecipe
    editing = false
    hook.Run("SN_Tasks_PinnedRecipeChanged")
    RebuildPinnedRecipePanel()
end)

local function ToggleRecipeEditing()
    SlashMoon.Tasks.SetPinnedRecipeEditing(not editing)
end

MODULE:Hook("SN_Tasks_LanguageChanged", "SN_Tasks_RebuildPinnedRecipe", function()
    RebuildPinnedRecipePanel()
end)

MODULE:Hook("SN_Tasks_PinnedRecipeChanged", "SN_Tasks_RebuildPinnedRecipeButton", RebuildPinnedRecipePanel)

MODULE:Hook("Think", "SN_Tasks_PinnedRecipeState", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() or SlashMoon.Tasks.Game.IsAnimatronic(ply) or SlashMoon.Tasks.Game.IsSpectator(ply) then
        if IsValid(recipePanel) then recipePanel:SetVisible(false) end
        return
    end
    if IsValid(recipePanel) then recipePanel:SetVisible(true) end
end)

MODULE:Hook("InitPostEntity", "SN_Tasks_RequestPinnedRecipe", function()
    timer.Simple(2, function()
        net.Start("SN_Workbench_RequestPinnedRecipe")
        net.SendToServer()
    end)
end)

MODULE:Hook("ShutDown", "SN_Tasks_RemovePinnedRecipe", function()
    if IsValid(recipePanel) then recipePanel:Remove() end
end)

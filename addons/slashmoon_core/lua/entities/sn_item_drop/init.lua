-- Written for: SlashMoon. By: VIKA & Ronni

AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel("models/Items/BoxSRounds.mdl") -- Дефолтная моделька
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
end

function ENT:SetItem(class)
    self:SetNW2String("ItemClass", class)
    self:SetModelScale(SlashMoon.Tasks.GetItemWorldScale and SlashMoon.Tasks.GetItemWorldScale(class) or 1, 0)
    
    -- Получаем модельку из новой системы моделей
    -- SlashMoon.Tasks.GetItemModel учитывает: конкретный предмет → редкость оружия → тип предмета
    local modelPath = SlashMoon.Tasks.GetItemModel and SlashMoon.Tasks.GetItemModel(class)
        or "models/Items/BoxSRounds.mdl"
    
    -- Проверяем, что модель существует (предотвращаем errors)
    if util.IsValidModel(modelPath) then
        self:SetModel(modelPath)
    else
        -- Фоллбэк: по типу предмета
        local data = SlashMoon.Tasks.GetItemData(class)
        if data.type == "material" then
            self:SetModel("models/props_junk/cardboard_box004a.mdl")
        elseif data.type == "chemical" then
            self:SetModel("models/props_junk/PropaneCanister001a.mdl")
        elseif data.type == "electronic" then
            self:SetModel("models/props_lab/reciever01c.mdl")
        elseif data.type == "consumable" then
            self:SetModel("models/props_junk/PopCan01a.mdl")
        elseif data.type == "tool" then
            self:SetModel("models/props_c17/tools_wrench01a.mdl")
        elseif data.type == "quest" then
            self:SetModel("models/Items/item_item_crate.mdl")
        elseif data.type == "rare" then
            self:SetModel("models/Items/Flare.mdl")
        else
            self:SetModel("models/Items/BoxSRounds.mdl")
        end
    end
    
    -- Переинициализируем физику под новую модельку
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then 
        phys:Wake() 
        phys:SetMass(15) -- Чтобы коробки не разлетались от малейшего пинка
    end
end

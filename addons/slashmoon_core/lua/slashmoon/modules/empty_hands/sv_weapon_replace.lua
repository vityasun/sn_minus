-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("empty_hands")

-- ========================================================
-- Автоматическая подмена оружия
-- ========================================================

if not SERVER then return end

-- Словарь замен (В будущем сюда можно вписать и другие замены)
local WeaponReplacements = {
    ["weapon_empty_hands"] = "sn_empty_hands", -- На всякий случай добавил с правильным написанием, если была опечатка
}

-- Хук WeaponEquip срабатывает в тот момент, когда оружие ФИЗИЧЕСКИ попадает в инвентарь
MODULE:Hook("WeaponEquip", "SN_ReplaceWeapons", function(weapon, ply)
    if not IsValid(weapon) or not IsValid(ply) or not ply:IsPlayer() then return end
    
    local class = weapon:GetClass()
    local replacement = WeaponReplacements[class]

    if replacement then
        -- Обязательно используем таймер в 0 секунд (след. кадр). 
        -- Удалять оружие прямо внутри хука WeaponEquip нельзя — это вызовет краш движка Source!
        timer.Simple(0, function()
            if IsValid(ply) then
                -- Проверяем, держит ли игрок это оружие прямо сейчас в руках
                local wasActive = false
                local activeWep = ply:GetActiveWeapon()
                if IsValid(activeWep) and activeWep:GetClass() == class then
                    wasActive = true
                end

                -- Удаляем старое оружие
                ply:StripWeapon(class)
                
                -- Выдаем новое
                if not ply:HasWeapon(replacement) then
                    ply:Give(replacement)
                end
                
                -- Если гейммод заставил игрока взять старые руки в руки, 
                -- мы заставляем его взять новые, чтобы он не стоял с пустой анимацией
                if wasActive then
                    ply:SelectWeapon(replacement)
                end
            end
        end)
    end
end)

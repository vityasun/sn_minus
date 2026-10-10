-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("gf_rework")

-- ========================================================
-- Реворк Золотого Фредди: клиентская часть
-- ========================================================

local GF_PendingOverlay = false

---------------------------------------------------------------------------
-- СКРЫТИЕ МОДЕЛИ ОТ ВСЕХ КРОМЕ ЦЕЛИ
---------------------------------------------------------------------------
MODULE:Hook("PrePlayerDraw", "GF_Rework_HideFromOthers", function(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    
    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    
    -- Проверяем наш режим ожидания
    if ply:GetNW2Bool("GF_Pending_G") then
        local target = ply:GetNW2Entity("GF_Pending_Target")
        
        -- Если я не цель, скрываем модель полностью
        if lp ~= target then
            return true
        end
    end
    
    -- Также учитываем оригинальный аутворлд
    if ply:GetNW2Bool("_OUTWORLD_gfreddy") then
        if not lp:GetNW2Bool("_OUTWORLD_target") then
            return true
        end
    end
end)

MODULE:Hook("ForceDrawPill", "GF_Rework_HidePillFromOthers", function(ply, ent)
    if not IsValid(ply) or not IsValid(ent) then return end
    
    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    
    if ply:GetNW2Bool("GF_Pending_G") then
        local target = ply:GetNW2Entity("GF_Pending_Target")
        if lp ~= target then
            return false
        end
    end
    
    if ply:GetNW2Bool("_OUTWORLD_gfreddy") then
        if not lp:GetNW2Bool("_OUTWORLD_target") then
            return false
        end
    end
end)

---------------------------------------------------------------------------
-- ЗВУКОВЫЕ УВЕДОМЛЕНИЯ
---------------------------------------------------------------------------
MODULE:Receive("gf_rework_pending_start", function()
    local otherPly = net.ReadPlayer()
    local lp = LocalPlayer()
    
    if not IsValid(lp) then return end
    
    if otherPly == lp then
        -- Я Золотой Фредди
        notification.AddLegacy("Цель выбрана: она должна увидеть вас", NOTIFY_HINT, 5)
        surface.PlaySound("buttons/blip1.wav")
    else
        -- Я Цель
        notification.AddLegacy("Золотой Фредди охотится за вами!", NOTIFY_ERROR, 5)
        surface.PlaySound("fnaf2/gfreddy/gfreddy_target.wav")
        
        GF_PendingOverlay = true
    end
end)

MODULE:Receive("gf_rework_pending_end", function()
    notification.AddLegacy("Охота Золотого Фредди отменена", NOTIFY_HINT, 3)
    GF_PendingOverlay = false
end)

MODULE:Hook("PlayerSpawn", "GF_Rework_Cleanup_Spawn", function(ply)
    if ply == LocalPlayer() then
        GF_PendingOverlay = false
    end
end)

MODULE:Hook("PostCleanupMap", "GF_Rework_Cleanup_Client", function()
    GF_PendingOverlay = false
end)

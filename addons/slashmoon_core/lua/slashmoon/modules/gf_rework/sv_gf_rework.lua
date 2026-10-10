-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("gf_rework")

-- ========================================================
-- Реворк Золотого Фредди: перед аутворлдом цель должна увидеть ГФ
-- ========================================================

util.AddNetworkString("gf_rework_pending_start")
util.AddNetworkString("gf_rework_pending_end")
util.AddNetworkString("gf_rework_outworld_force")

-- Ожидающие цели: [gf_ply] = { target = ply, startTime = time, ent = pill_ent }
MODULE.PendingState = MODULE.PendingState or {}
local GF_PendingState = MODULE.PendingState

-- Флаг, чтобы не перехватывать собственный запуск аутворлда
local GF_IsInRework = false

---------------------------------------------------------------------------
-- ФУНКЦИЯ ЗАПУСКА ОЖИДАНИЯ
---------------------------------------------------------------------------
local function StartPendingOutworld(gf_ply, ent, target_ply)
    if not IsValid(gf_ply) or not IsValid(target_ply) then return false end
    if not IsValid(ent) then return false end
    
    -- Если уже есть активный аутворлд - отмена
    if wgfreddy_targets[gf_ply] or outworld_victims[target_ply] then
        return false
    end
    
    -- Если уже в режиме ожидания
    if GF_PendingState[gf_ply] then
        return false
    end
    
    -- Сохраняем состояние
    GF_PendingState[gf_ply] = {
        target = target_ply,
        startTime = CurTime(),
        ent = ent,
        seeStartTime = nil
    }
    
    -- Сетевые переменные для клиентов
    gf_ply:SetNW2Bool("GF_Pending_G", true)
    gf_ply:SetNW2Entity("GF_Pending_Target", target_ply)
    
    target_ply:SetNW2Bool("GF_Pending_T", true)
    target_ply:SetNW2Entity("GF_Pending_Source", gf_ply)
    
    -- Уведомления
    net.Start("gf_rework_pending_start")
    net.WritePlayer(gf_ply)
    net.Send(target_ply)
    
    net.Start("gf_rework_pending_start")
    net.WritePlayer(target_ply)
    net.Send(gf_ply)
    
    gf_ply:ChatPrint("[GF] Цель выбрана: " .. target_ply:Nick() .. ". Игрок должен увидеть вас!")
    target_ply:ChatPrint("[GF] Золотой Фредди охотится за вами. Найдите его!")
    
    -- Звук для цели
    target_ply:EmitSound("fnaf2/gfreddy/gfreddy_target.wav", 100, 100, 0.5)
    
    return true
end

---------------------------------------------------------------------------
-- ФУНКЦИЯ ЗАПУСКА ПОЛНОГО АУТВОРЛДА
---------------------------------------------------------------------------
local function ForceStartOutworld(gf_ply, ent, target_ply)
    if not IsValid(gf_ply) or not IsValid(target_ply) then return end
    if not IsValid(ent) then return end
    
    -- Очищаем pending состояние
    GF_PendingState[gf_ply] = nil
    
    -- Сбрасываем наши флаги
    gf_ply:SetNW2Bool("GF_Pending_G", false)
    gf_ply:SetNW2Entity("GF_Pending_Target", nil)
    target_ply:SetNW2Bool("GF_Pending_T", false)
    target_ply:SetNW2Entity("GF_Pending_Source", nil)
    
    -- Запускаем функцию гейммода (ищется в момент вызова: гейммод грузится после autorun)
    if not isfunction(start_outworld) then return end
    GF_IsInRework = true
    SlashMoon.SafeCall(start_outworld, gf_ply, ent, target_ply)
    GF_IsInRework = false
    
    gf_ply:ChatPrint("[GF] Аутворлд запущен!")
end

---------------------------------------------------------------------------
-- ПЕРЕХВАТ RELOAD (ВЫБОР ЦЕЛИ)
---------------------------------------------------------------------------
MODULE:Hook("PillAbilityReload", "GF_Rework_InterceptReload", function(ply, ent)
    if not IsValid(ply) or not IsValid(ent) then return end
    if ent.formTable.name ~= "pill_wgfreddy2" then return end
    
    -- Если уже в полноценном аутворлде - пропускаем
    if wgfreddy_targets[ply] then
        return
    end
    
    -- Если в режиме ожидания - отменяем его
    if GF_PendingState[ply] then
        local data = GF_PendingState[ply]
        GF_PendingState[ply] = nil
        
        ply:SetNW2Bool("GF_Pending_G", false)
        ply:SetNW2Entity("GF_Pending_Target", nil)
        
        if IsValid(data.target) then
            data.target:SetNW2Bool("GF_Pending_T", false)
            data.target:SetNW2Entity("GF_Pending_Source", nil)
        end
        
        net.Start("gf_rework_pending_end")
        net.Broadcast()
        
        ply:ChatPrint("[GF] Охота отменена.")
        return true
    end
    
    -- Получаем цель как в оригинале
    local target = fh_get_wgfreddy_target(ply)
    if not IsValid(target) then 
        ply:ChatPrint("[GF] Нет доступной цели.")
        return 
    end
    
    -- Запускаем режим ожидания вместо полного аутворлда
    StartPendingOutworld(ply, ent, target)
    
    return true -- Блокируем оригинальную функцию
end)

---------------------------------------------------------------------------
-- ПРОВЕРКА ВИДИМОСТИ КАЖДЫЙ ТИК
---------------------------------------------------------------------------
MODULE:Hook("Think", "GF_Rework_VisibilityCheck", function()
    for gf, data in pairs(GF_PendingState) do
        if not IsValid(gf) or not IsValid(data.target) then
            GF_PendingState[gf] = nil
            continue
        end
        
        if not gf:Alive() or not data.target:Alive() then
            GF_PendingState[gf] = nil
            continue
        end
        
        local ent = data.ent
        if not IsValid(ent) then
            GF_PendingState[gf] = nil
            continue
        end
        
        -- Проверяем клоак (невидимость) - если невидим, не активируем
        if ent.cloaked then
            data.seeStartTime = nil
            continue
        end
        
        -- Проверка: модель не должна быть models/null
        if ent:GetMaterial() == "models/null" then
            data.seeStartTime = nil
            continue
        end
        
        -- Проверка линии видимости от цели к ГФ
        local trace = util.TraceLine({
            start = data.target:EyePos(),
            endpos = gf:EyePos(),
            filter = {gf, data.target, ent},
            mask = MASK_BLOCKLOS_AND_NPCS
        })
        
        local distance = data.target:EyePos():Distance(gf:EyePos())
        
        -- Если видим и дистанция до 1500 юнитов
        if not trace.Hit and distance < 1500 then
            if not data.seeStartTime then
                data.seeStartTime = CurTime()
            end
            
            -- Требуем 0.7 секунды непрерывной видимости
            if CurTime() - data.seeStartTime > 0.7 then
                ForceStartOutworld(gf, ent, data.target)
            end
        else
            data.seeStartTime = nil
        end
    end
end)

---------------------------------------------------------------------------
-- ОЧИСТКА ПРИ СМЕРТИ/ОТКЛЮЧЕНИИ/РЕСТОРЕ
---------------------------------------------------------------------------
local function CleanupPending(ply)
    if GF_PendingState[ply] then
        local data = GF_PendingState[ply]
        GF_PendingState[ply] = nil
        
        ply:SetNW2Bool("GF_Pending_G", false)
        ply:SetNW2Entity("GF_Pending_Target", nil)
        
        if IsValid(data.target) then
            data.target:SetNW2Bool("GF_Pending_T", false)
            data.target:SetNW2Entity("GF_Pending_Source", nil)
        end
        
        net.Start("gf_rework_pending_end")
        net.Broadcast()
    end
    
    -- Если игрок был целью
    for gf, data in pairs(GF_PendingState) do
        if data.target == ply then
            GF_PendingState[gf] = nil
            
            gf:SetNW2Bool("GF_Pending_G", false)
            gf:SetNW2Entity("GF_Pending_Target", nil)
            
            ply:SetNW2Bool("GF_Pending_T", false)
            ply:SetNW2Entity("GF_Pending_Source", nil)
        end
    end
end

MODULE:Hook("PlayerDeath", "GF_Rework_Cleanup_Death", CleanupPending)
MODULE:Hook("PlayerDisconnected", "GF_Rework_Cleanup_Disconnect", CleanupPending)
MODULE:Hook("PlayerSilentDeath", "GF_Rework_Cleanup_SilentDeath", CleanupPending)

MODULE:Hook("PillRestore", "GF_Rework_Cleanup_Restore", function(ply, ent)
    if ent.formTable.name == "pill_wgfreddy2" then
        CleanupPending(ply)
    end
end)

MODULE:Hook("PostCleanupMap", "GF_Rework_Cleanup_Map", function()
    table.Empty(GF_PendingState)
end)

-- При отключении модуля снимаем все ожидания
MODULE:OnDisabled(function()
    for gf in pairs(GF_PendingState) do
        if IsValid(gf) then CleanupPending(gf) end
    end
    table.Empty(GF_PendingState)
end)

---------------------------------------------------------------------------
-- ЗАЩИТА ОТ ДВОЙНОГО ЗАПУСКА
---------------------------------------------------------------------------
MODULE:Hook("CanStartOutworld", "GF_Rework_BlockOriginal", function(ply, ent, target)
    if GF_IsInRework then return end
    
    if ent.formTable.name == "pill_wgfreddy2" then
        return false -- Блокируем оригинальный запуск
    end
end)

---------------------------------------------------------------------------
-- КОМАНДА ДЛЯ ТЕСТА (АДМИН)
---------------------------------------------------------------------------
MODULE:Command("gf_force_outworld", function(ply, cmd, args)
    if not IsValid(ply) or not SlashMoon.Admin.HasPermission(ply, "slashmoon_gf_force") then return end

    local gf = GF_PendingState[ply]
    if gf then
        local ent = pills.getMappedEnt(ply)
        if IsValid(ent) then
            ForceStartOutworld(ply, ent, gf.target)
            ply:ChatPrint("[GF] Принудительный запуск аутворлда.")
        end
    end
end)

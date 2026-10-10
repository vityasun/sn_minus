-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("bonnie_mask_fix")

-- ========================================================
-- Патч для SWEP Маски Бонни
-- ========================================================

if SERVER then
    util.AddNetworkString("SN_ForceRemoveMask")

    -- Универсальная функция экстренного снятия маски
    local function ForceRemoveMask(ply)
        if not IsValid(ply) or not ply.invisible then return end

        local tName = "fh_invisibility_timer" .. ply:EntIndex()

        -- 1. Если таймер свепа еще жив - заставляем его сработать ПРЯМО СЕЙЧАС (0.01 сек)
        if timer.Exists(tName) then
            timer.Adjust(tName, 0.01, 1)
        else
            -- Если таймера уже нет, но игрок забаговался - снимаем эффекты жестко вручную
            ply.invisible = false
            ply:SetColor(Color(255, 255, 255, 255))
            ply:SetMaterial("")
            ply:SetRenderMode(RENDERMODE_NORMAL)
            ply:DrawShadow(true)
            
            for _, wep in ipairs(ply:GetWeapons()) do
                if IsValid(wep) then
                    wep:SetNoDraw(false)
                    wep:DrawShadow(true)
                    wep:SetRenderMode(RENDERMODE_NORMAL)
                end
            end
        end

        -- 2. Отправляем сигнал клиенту, чтобы он убрал синий экран
        net.Start("SN_ForceRemoveMask")
        net.Send(ply)
    end

    -- === 1. ПЕРЕХВАТ СМЕРТИ ===
    -- Срабатывает за долю секунды ДО создания трупа/рэгдолла
    MODULE:Hook("DoPlayerDeath", "SN_FixBonnieMask_Death", function(ply)
        ForceRemoveMask(ply)
    end)

    -- === 2. ПЕРЕХВАТ СКРИМЕРОВ ===
    -- Режим FH выдает ply.jumpscared = true во время скримера. Отслеживаем это.
    MODULE:Hook("Think", "SN_FixBonnieMask_Jumpscare", function()
        for _, ply in ipairs(player.GetAll()) do
            if ply.invisible and ply.jumpscared then
                ForceRemoveMask(ply)
            end
        end
    end)

    -- === 3. ЖЕЛЕЗОБЕТОННЫЙ ФИКС РЭГДОЛЛА ===
    -- Даже если смерть произошла слишком быстро, мы насильно отчищаем труп от инвиза
    MODULE:Hook("fh_createragdoll", "SN_FixBonnieMask_RagdollPatch", function(ply, rag)
        if IsValid(rag) then
            rag:SetColor(Color(255, 255, 255, 255))
            rag:SetMaterial("")
            rag:SetRenderMode(RENDERMODE_NORMAL)
            rag:DrawShadow(true)
        end
    end)
end

if CLIENT then
    -- === 4. КЛИЕНТСКИЙ ФИКС СИНЕГО ЭКРАНА ===
    MODULE:Receive("SN_ForceRemoveMask", function()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end

        local tName = "fh_invisibility_timer" .. ply:EntIndex()
        
        -- У свепа на клиенте есть свой таймер, который возвращает цвета в норму. 
        -- Мы просто заставляем его отработать в этот же кадр!
        if timer.Exists(tName) then
            timer.Adjust(tName, 0.01, 1)
        end
    end)
end

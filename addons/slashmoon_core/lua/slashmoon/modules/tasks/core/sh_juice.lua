-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("tasks")

-- ========================================================
-- SN Tasks: Модуль сочной отдачи от интерактива (Juice)
-- ========================================================
SlashMoon.Juice = SlashMoon.Juice or {}

if SERVER then
    util.AddNetworkString("SN_Phase_Juice")
end

if CLIENT then
    -- Эффект успеха: шейк камеры, вспышка зеленого света, звук
    function SlashMoon.Juice.PlaySuccess(pos, soundPath)
        local ply = LocalPlayer()
        if IsValid(ply) and ply:GetPos():Distance(pos) < 600 then
            util.ScreenShake(pos, 3, 10, 0.4, 400)
            
            local dlight = DynamicLight(ply:EntIndex() + 99)
            if dlight then
                dlight.pos = pos + Vector(0, 0, 30)
                dlight.r = 50
                dlight.g = 255
                dlight.b = 100
                dlight.brightness = 3
                dlight.Size = 250
                dlight.Decay = 1000
                dlight.DieTime = CurTime() + 0.3
            end
            
            if soundPath then surface.PlaySound(soundPath) end
        end
    end

    -- Эффект ошибки / пенальти: красный пульс света и утяжеленный шейк
    function SlashMoon.Juice.PlayFail(pos, soundPath)
        local ply = LocalPlayer()
        if IsValid(ply) and ply:GetPos():Distance(pos) < 800 then
            util.ScreenShake(pos, 7, 25, 0.6, 600)
            
            local dlight = DynamicLight(ply:EntIndex() + 100)
            if dlight then
                dlight.pos = pos + Vector(0, 0, 30)
                dlight.r = 255
                dlight.g = 30
                dlight.b = 30
                dlight.brightness = 5
                dlight.Size = 400
                dlight.Decay = 1200
                dlight.DieTime = CurTime() + 0.5
            end
            
            if soundPath then surface.PlaySound(soundPath) end
        end
    end

    -- Сетевой приемник для вызовов с сервера
    MODULE:Receive("SN_Phase_Juice", function()
        local pos = net.ReadVector()
        local isSuccess = net.ReadBool()

        if isSuccess then
            SlashMoon.Juice.PlaySuccess(pos)
        else
            SlashMoon.Juice.PlayFail(pos)
        end
    end)
end

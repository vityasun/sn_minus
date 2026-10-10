-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("dances")

SlashMoon.Dances.CameraPos = SlashMoon.Dances.CameraPos or Vector(0, 0, 0)

-- === ОПТИМИЗАЦИЯ #1 ===
-- CreateClientConVar ВОЗВРАЩАЕТ объект ConVar. Кэшируем его один раз,
-- вместо GetConVar("...") каждый кадр в Think (поиск по имени — дорого).
local cvMusicOn = CreateClientConVar("wos_dance_music_on", "1", true, false, "Включена ли музыка танцев")
local cvMusicVol = CreateClientConVar("wos_dance_music_vol", "1", true, false, "Громкость музыки танцев 0-1")

-- === ОПТИМИЗАЦИЯ #2 ===
-- Константы вынесены наверх: вектор смещения больше не создаётся каждый кадр,
-- сравнение дистанций идёт через DistToSqr (без извлечения квадратного корня).
local MUSIC_POS_OFFSET = Vector(0, 0, 40)
local SYNC_RANGE_SQR = 400 * 400
-- Перевыбор лидера: мгновенно при любом изменении состояния,
-- иначе не чаще 4 раз в секунду (вместо каждого кадра).
local LEADER_REELECT_INTERVAL = 0.25
local VOLUME_CHANGE_THRESHOLD = 0.01

MODULE:Hook("RenderScene", "wOS_Dance_CameraPos", function(origin, angles, fov)
    SlashMoon.Dances.CameraPos = origin
end)

function SlashMoon.Dances.PlayMusic(ply, filepath)
    SlashMoon.Dances.StopMusic(ply)

    ply.wOS_MusicPlaybackID = (ply.wOS_MusicPlaybackID or 0) + 1
    local currentPlayback = ply.wOS_MusicPlaybackID

    sound.PlayFile("sound/" .. filepath, "3d noplay", function(station, errCode, errStr)
        if not IsValid(station) then return end

        if not IsValid(ply) or ply.wOS_MusicPlaybackID ~= currentPlayback or not ply.wOS_IsLeader or ply:GetNW2String("wOS_Dance_ID", "") == "" then
            station:Stop()
            return
        end

        station:SetPos(ply:GetPos() + MUSIC_POS_OFFSET)
        station:Set3DFadeDistance(150, 600)
        station:SetVolume(1)
        station:EnableLooping(true)
        station:Play()
        ply.wOS_LastMusicVol = 1

        SlashMoon.Dances.MusicChannels[ply] = station
    end)
end

function SlashMoon.Dances.StopMusic(ply)
    local station = SlashMoon.Dances.MusicChannels[ply]
    if IsValid(station) then station:Stop() end
    SlashMoon.Dances.MusicChannels[ply] = nil
end

-- === ОПТИМИЗАЦИЯ #3 ===
-- Переиспользуемый список танцующих: таблица создаётся один раз,
-- а не аллоцируется заново каждый кадр.
local dancers = {}
local nextElection = 0

MODULE:Hook("Think", "wOS_Dance_Music_Think", function()
    local myPos = SlashMoon.Dances.CameraPos

    local players = player.GetAll()
    local numPlayers = #players
    local numDancers = 0
    local stateChanged = false

    -- Один проход по игрокам: детект смены состояния + сбор танцующих.
    for i = 1, numPlayers do
        local ply = players[i]
        local danceID = ply:GetNW2String("wOS_Dance_ID", "")

        if danceID ~= (ply.wOS_LocalDance_ID or "") then
            stateChanged = true
            ply.wOS_LocalDance_ID = danceID
            SlashMoon.Dances.StopMusic(ply)
            ply:AnimResetGestureSlot(GESTURE_SLOT_CUSTOM)
            ply.wOS_IsLeader = false

            if danceID ~= "" then
                local wep = ply:GetActiveWeapon()
                if IsValid(wep) then
                    ply.wOS_Dance_HiddenWep = wep
                    wep:SetNoDraw(true)
                end

                local animData = SlashMoon.Dances.Animations[danceID]
                if animData then
                    local catData = SlashMoon.Dances.Categories[animData.cat]
                    if animData.mode == "actmod" then
                        local seqID = ply:LookupSequence(animData.seq)
                        if seqID and seqID >= 0 then
                            ply:ResetSequence(seqID)
                            ply:SetCycle(animData.cycle or 0)
                            ply:SetPlaybackRate(animData.rate or 1)
                        end
                    elseif catData.type == "gesture" or animData.loop == false then
                        local seqID = ply:LookupSequence(animData.seq)
                        if seqID and seqID > 0 then
                            ply:AddVCDSequenceToGestureSlot(GESTURE_SLOT_CUSTOM, seqID, 0, true)
                        end
                    else
                        ply:SetCycle(0)
                    end
                end
            else
                ply.wOS_SyncTarget = nil
                if IsValid(ply.wOS_Dance_HiddenWep) then
                    ply.wOS_Dance_HiddenWep:SetNoDraw(false)
                    ply.wOS_Dance_HiddenWep = nil
                end
            end
        end

        if danceID ~= "" then
            numDancers = numDancers + 1
            dancers[numDancers] = ply
        end
    end

    -- === ГЛАВНАЯ ОПТИМИЗАЦИЯ #4 ===
    -- Если никто не танцует (самый частый случай на сервере) —
    -- выходим сразу, не делая никакой дальнейшей работы.
    if numDancers == 0 then return end

    -- === ОПТИМИЗАЦИЯ #5 ===
    -- Выбор лидера: раньше O(N^2) по ВСЕМ игрокам КАЖДЫЙ кадр
    -- (при 32 игроках ~1000 итераций * 66 кадров = 66 000 итераций/сек).
    -- Теперь: только по танцующим, только при изменениях либо 4 раза/сек.
    -- Реакция на новые танцы — мгновенная (stateChanged сбрасывает таймер).
    local now = CurTime()
    if stateChanged then nextElection = 0 end

    if now >= nextElection then
        nextElection = now + LEADER_REELECT_INTERVAL

        for i = 1, numDancers do
            local ply = dancers[i]
            local danceID = ply.wOS_LocalDance_ID
            local animData = SlashMoon.Dances.Animations[danceID]
            if animData then
                local leader = ply
                local myStartTime = ply:GetNW2Float("wOS_Dance_StartTime", 0)
                local plyPos = ply:GetPos()

                for j = 1, numDancers do
                    if j ~= i then
                        local other = dancers[j]
                        -- DistToSqr вместо Distance: без sqrt,
                        -- wOS_LocalDance_ID уже закэширован выше (без NW2-чтения)
                        if other.wOS_LocalDance_ID == danceID and plyPos:DistToSqr(other:GetPos()) <= SYNC_RANGE_SQR then
                            local otherStartTime = other:GetNW2Float("wOS_Dance_StartTime", 0)

                            if otherStartTime < myStartTime then
                                leader = other
                                myStartTime = otherStartTime
                            elseif otherStartTime == myStartTime and other:EntIndex() < leader:EntIndex() then
                                leader = other
                            end
                        end
                    end
                end

                local isLeader = (leader == ply)
                ply.wOS_SyncTarget = isLeader and nil or leader

                if isLeader then
                    if not ply.wOS_IsLeader then
                        ply.wOS_IsLeader = true
                        if animData.music then
                            SlashMoon.Dances.PlayMusic(ply, animData.music)
                        end
                    end
                else
                    if ply.wOS_IsLeader then
                        ply.wOS_IsLeader = false
                        SlashMoon.Dances.StopMusic(ply)
                    end
                end
            end
        end
    end

    -- === ОПТИМИЗАЦИЯ #6 + ФИКС УТЕЧКИ ===
    -- Обновляем только реально существующие станции (обычно 1-3),
    -- итерируя саму таблицу MusicChannels, а не всех игроков.
    -- ФИКС: если игрок ВЫШЕЛ с сервера, его станция больше не потеряется
    -- и не будет играть вечно — IsValid(ply) глушит её сразу.
    local isMusicOn = cvMusicOn:GetBool()
    local userVol = cvMusicVol:GetFloat()

    for ply, station in pairs(SlashMoon.Dances.MusicChannels) do
        if not IsValid(station) then
            SlashMoon.Dances.MusicChannels[ply] = nil
        elseif not IsValid(ply) or not ply:Alive() or ply.wOS_LocalDance_ID == "" or not ply.wOS_IsLeader then
            SlashMoon.Dances.StopMusic(ply)
        else
            local sourcePos = ply:GetPos() + MUSIC_POS_OFFSET
            station:SetPos(sourcePos)

            local dist = myPos:Distance(sourcePos)
            local vol

            if not isMusicOn or dist > 400 then
                vol = 0 -- Музыка играет, но беззвучно (сохраняет тайминги)
            else
                local distVolume = 1 - math.Clamp((dist - 150) / 250, 0, 1)
                vol = distVolume * userVol
            end

            -- === ОПТИМИЗАЦИЯ #7 ===
            -- SetVolume отправляется в аудиодвижок только когда
            -- громкость реально изменилась, а не каждый кадр.
            if math.abs(vol - (ply.wOS_LastMusicVol or -1)) > VOLUME_CHANGE_THRESHOLD then
                ply.wOS_LastMusicVol = vol
                station:SetVolume(vol)
            end
        end
    end
end)

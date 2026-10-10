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

-- ========================================================
-- Музыка эмоции: интро (animData.music) и луп (animData.repeatMusic).
-- Интро играет один раз, затем без паузы включается луп (он загружается
-- заранее, пока играет интро). Если лупа нет или он совпадает с интро —
-- один трек на повторе (для loop = false — один раз).
-- Позиция трека считается от wOS_Dance_StartTime лидера, поэтому игрок,
-- подошедший позже, слышит музыку с того же места, что и остальные.
-- ========================================================

-- Состояние двухфазной музыки по игроку: { loop = канал, introDone = bool, loopOffset = сек }
SlashMoon.Dances.MusicState = SlashMoon.Dances.MusicState or {}
local MusicState = SlashMoon.Dances.MusicState

local function IsCurrentPlayback(ply, playback)
    return IsValid(ply) and ply.wOS_MusicPlaybackID == playback and ply.wOS_IsLeader
        and ply:GetNW2String("wOS_Dance_ID", "") ~= ""
end

-- Загружает трек в 3D-канал без воспроизведения. callback(station) — только для актуального запуска,
-- onFail() — если файл не загрузился.
local function LoadTrack(ply, playback, path, callback, onFail)
    sound.PlayFile("sound/" .. path, "3d noplay", function(station)
        if not IsValid(station) then
            if onFail and IsCurrentPlayback(ply, playback) then onFail() end
            return
        end
        if not IsCurrentPlayback(ply, playback) then
            station:Stop()
            return
        end
        station:SetPos(ply:GetPos() + MUSIC_POS_OFFSET)
        station:Set3DFadeDistance(150, 600)
        station:SetVolume(ply.wOS_LastMusicVol or 1)
        callback(station)
    end)
end

-- Сколько секунд прошло с начала танца лидера
local function DanceElapsed(ply)
    local started = ply:GetNW2Float("wOS_Dance_StartTime", 0)
    if started <= 0 then return 0 end
    return math.max(0, CurTime() - started)
end

-- Запускает канал с позиции offset (сек). false — одноразовый трек уже закончился.
local function StartAt(station, offset, looping)
    local len = station:GetLength()
    if offset > 0 and len > 0 then
        if looping then
            offset = offset % len
        elseif offset >= len then
            station:Stop()
            return false
        end
        station:SetTime(offset)
    end
    station:EnableLooping(looping)
    station:Play()
    return true
end

--- Переключает музыку лидера с интро на луп (offset — позиция в лупе, сек).
function SlashMoon.Dances.SwitchToLoop(ply, offset)
    local channels = SlashMoon.Dances.MusicChannels
    local state = MusicState[ply]
    if not state then return end

    local intro = channels[ply]
    if IsValid(intro) then intro:Stop() end
    channels[ply] = nil
    state.introDone = true

    if IsValid(state.loop) then
        local loopStation = state.loop
        MusicState[ply] = nil
        StartAt(loopStation, offset or 0, true)
        channels[ply] = loopStation
    else
        -- Луп еще грузится: стартует в своем колбэке с этого места
        state.loopOffset = offset or 0
        state.loopStartedAt = CurTime()
    end
end

function SlashMoon.Dances.PlayMusic(ply, animData)
    SlashMoon.Dances.StopMusic(ply)
    if not istable(animData) or not animData.music then return end

    ply.wOS_MusicPlaybackID = (ply.wOS_MusicPlaybackID or 0) + 1
    local playback = ply.wOS_MusicPlaybackID
    local intro = animData.music
    local loopTrack = animData.repeatMusic
    local channels = SlashMoon.Dances.MusicChannels

    -- Один трек: повтор, для одноразовых эмоций (loop = false) — один раз
    if not loopTrack or loopTrack == intro then
        local looping = animData.loop ~= false
        LoadTrack(ply, playback, intro, function(station)
            if StartAt(station, DanceElapsed(ply), looping) then
                channels[ply] = station
            end
        end)
        return
    end

    -- Интро + луп: грузим оба, луп ждет окончания интро
    local state = { introDone = false }
    MusicState[ply] = state

    LoadTrack(ply, playback, loopTrack, function(loopStation)
        if MusicState[ply] ~= state then loopStation:Stop() return end
        loopStation:EnableLooping(true)
        state.loop = loopStation

        if state.introDone then
            -- Интро закончилось раньше, чем загрузился луп
            local offset = (state.loopOffset or 0) + (CurTime() - (state.loopStartedAt or CurTime()))
            MusicState[ply] = nil
            StartAt(loopStation, offset, true)
            channels[ply] = loopStation
        end
    end)

    LoadTrack(ply, playback, intro, function(introStation)
        if MusicState[ply] ~= state then introStation:Stop() return end
        local elapsed = DanceElapsed(ply)
        local introLen = introStation:GetLength()

        if introLen > 0 and elapsed >= introLen then
            -- Подошли позже, интро уже отыграло: сразу луп с нужного места
            introStation:Stop()
            SlashMoon.Dances.SwitchToLoop(ply, elapsed - introLen)
            return
        end

        StartAt(introStation, elapsed, false)
        channels[ply] = introStation
    end, function()
        -- Интро не загрузилось: играем луп
        if MusicState[ply] == state then
            SlashMoon.Dances.SwitchToLoop(ply, DanceElapsed(ply))
        end
    end)
end

function SlashMoon.Dances.StopMusic(ply)
    local channels = SlashMoon.Dances.MusicChannels
    local station = channels[ply]
    if IsValid(station) then station:Stop() end
    channels[ply] = nil

    local state = MusicState[ply]
    if state and IsValid(state.loop) then state.loop:Stop() end
    MusicState[ply] = nil
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
                            SlashMoon.Dances.PlayMusic(ply, animData)
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
        elseif MusicState[ply] and not MusicState[ply].introDone and station:GetState() == GMOD_CHANNEL_STOPPED then
            -- Интро доиграло: включаем луп (если еще грузится — стартует сам)
            SlashMoon.Dances.SwitchToLoop(ply, 0)
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

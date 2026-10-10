-- Written for: SlashMoon. By: VIKA & Ronni

-- -- sv_endo_copy_push.lua
-- if CLIENT then return end

-- local COPY_PUSH_RANGE    = 100   -- дистанция для E, как у игроков в sv_push.lua
-- local COPY_PUSH_DISTANCE = 90    -- итоговая дальность толчка
-- local COPY_PUSH_DURATION = 0.18  -- за сколько секунд проедет
-- local COPY_PUSH_STEPS    = 9     -- на сколько шагов бьём анимацию толчка
-- local COPY_PUSH_COOLDOWN = 0.5   -- КД на конкретную копию (анти-спам)

-- -- Насколько выше текущей позиции начинаем трассировку до пола и насколько
-- -- глубоко трассируем вниз. GROUND_TRACE_DOWN намеренно большой (было 64) —
-- -- маленький диапазон был причиной "улетает в небо": если толчок на любом
-- -- шаге проходил через небольшую кочку/порог и хал-трейс не находил пол в
-- -- пределах 64 юнитов вниз (что легко происходит на лестницах/уступах),
-- -- копия так и оставалась висеть на той высоте, куда её отнесло — а следующий
-- -- шаг толкал её ещё дальше от уже неправильной базы.
-- local GROUND_TRACE_UP    = 16
-- local GROUND_TRACE_DOWN  = 300

-- local PushSound_copies = {
--     "physics/metal/metal_solid_impact_hard1.wav",
--     "physics/metal/metal_solid_impact_hard4.wav",
--     "physics/metal/metal_solid_impact_hard5.wav",
--     "physics/metal/metal_solid_impact_soft1.wav",
-- }

-- local copyPushCooldown = {}

-- -- Двигает копию к targetPos, останавливаясь на первом препятствии,
-- -- и прижимает результат к полу. Никакой физики — просто трассировка.
-- local function TraceMoveCopy(copy, targetPos)
--     if not IsValid(copy) then return end

--     local mins, maxs = copy:GetCollisionBounds()
--     local startPos = copy:GetPos()

--     local tr = util.TraceHull({
--         start  = startPos,
--         endpos = targetPos,
--         mins   = mins,
--         maxs   = maxs,
--         filter = copy,
--         mask   = MASK_PLAYERSOLID,
--     })

--     local newPos = tr.HitPos

--     -- Прижимаем к полу отдельной трассировкой вниз — диапазон увеличен и
--     -- начинается чуть выше, чтобы надёжно находить пол даже на
--     -- лестницах/уступах/небольших порогах (см. константы выше).
--     local groundTr = util.TraceHull({
--         start  = newPos + Vector(0, 0, GROUND_TRACE_UP),
--         endpos = newPos - Vector(0, 0, GROUND_TRACE_DOWN),
--         mins   = mins,
--         maxs   = maxs,
--         filter = copy,
--         mask   = MASK_PLAYERSOLID,
--     })

--     if groundTr.Hit then
--         newPos = groundTr.HitPos
--     else
--         -- Пол не нашёлся вообще (толкнули в пропасть/за грань карты) —
--         -- НЕ телепортируем в никуда, остаёмся на прошлой валидной позиции.
--         -- Это и есть защита от "улетает в небо/висит в воздухе": лучше
--         -- недотолкнуть, чем оставить копию висящей.
--         newPos = startPos
--     end

--     copy:SetPos(newPos)
-- end

-- local function PushEndoCopy(ply, copy)
--     if not IsValid(ply) or not IsValid(copy) then return end
--     if copyPushCooldown[copy] and copyPushCooldown[copy] > CurTime() then return end
--     copyPushCooldown[copy] = CurTime() + COPY_PUSH_COOLDOWN

--     local dir = ply:EyeAngles():Forward()
--     -- Толчок строго горизонтальный — вертикальное позиционирование целиком
--     -- отдано трассировке до пола в TraceMoveCopy. Раньше здесь был
--     -- Clamp(dir.z, -0.1, 0.2): при взгляде вверх толчок получал заметную
--     -- вертикальную составляющую, а хал-трейс толчка идёт по прямой (не
--     -- огибает рельеф) — на открытом пространстве это позволяло копии
--     -- "взлететь" на высоту до ~18 юнитов за один шаг, а на нескольких
--     -- шагах подряд — заметно выше.
--     dir.z = 0
--     dir:Normalize()

--     copy:EmitSound(PushSound_copies[math.random(#PushSound_copies)], 100, 100)

--     local startPos = copy:GetPos()
--     local step = 0
--     local timerName = "copy_push_" .. copy:EntIndex()

--     MODULE:Timer(timerName, COPY_PUSH_DURATION / COPY_PUSH_STEPS, COPY_PUSH_STEPS, function()
--         if not IsValid(copy) then
--             MODULE:RemoveTimer(timerName)
--             return
--         end

--         step = step + 1
--         local frac = step / COPY_PUSH_STEPS
--         local eased = 1 - (1 - frac) * (1 - frac) -- ease-out: быстрее в начале, плавнее к концу

--         TraceMoveCopy(copy, startPos + dir * (COPY_PUSH_DISTANCE * eased))
--     end)
-- end

-- MODULE:Hook("KeyPress", "PushEndoCopyInteraction", function(ply, key)
--     if key ~= IN_USE then return end
--     if not IsValid(ply) or ply:Team() == TEAM_SPECTATOR then return end

--     local ent = ply:GetEyeTrace().Entity
--     if not IsValid(ent) or ent:GetClass() ~= "endo_copy" then return end
--     if ply:GetPos():Distance(ent:GetPos()) > COPY_PUSH_RANGE then return end

--     -- Тот же хук, что и для игроков в sv_push.lua — если где-то есть
--     -- логика блокировки толчков (например, во время фазы задания),
--     -- она сработает и здесь.
--     local allowed = hook.Run("ShouldPlayerPush", ply, ent)
--     if allowed == false then return end

--     PushEndoCopy(ply, ent)
-- end)

-- MODULE:Hook("EntityRemoved", "copy_push_cleanup", function(ent)
--     if not copyPushCooldown[ent] then return end
--     copyPushCooldown[ent] = nil
--     MODULE:RemoveTimer("copy_push_" .. ent:EntIndex())
-- end)

-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("endo_copies")

local ANIM_FPS    = 24
local ANIM_FRAMES = 59
local ANIM_DUR    = ANIM_FRAMES / ANIM_FPS  -- ~2.46 сек

if not SERVER then return end

util.AddNetworkString("endo_set_hovered")
util.AddNetworkString("endo_force_duck")
util.AddNetworkString("endo_start_switch")
util.AddNetworkString("endo_switch_denied")
-- =====================================================================
--  STATE
-- =====================================================================
local endoCopies     = {}   -- [Player] = { endo_copy, ... }
local endoHovered    = {}   -- [Player] = endo_copy | nil

-- =====================================================================
--  CONFIG
-- =====================================================================
local COPY_COUNT         = 3
local SPAWN_RADIUS_MIN   = 1500   -- было 200 — копии спавнились слишком близко к игроку
local SPAWN_RADIUS_MAX   = 10000   -- было 600
local MIN_COPY_SEP       = 200  -- было хардкод 180 — копии спавнились близко друг к другу; теперь минимальная дистанция между копиями = минимальной дистанции от игрока
local HULL_MINS          = Vector(-16, -16, 0)
local HULL_MAXS          = Vector( 16,  16, 86)
-- Насколько раздуваем hull по X/Y ТОЛЬКО для финальной проверки "тут
-- достаточно свободно" — без этого позиция вплотную к стене формально
-- проходила (StartSolid=false), и копия спавнилась впритык к геометрии.
local SPAWN_WALL_CLEARANCE = 6
-- Сколько юнитов свободного места по бокам требуем при спавне копии —
-- без этого копия могла заспавниться формально не в солиде, но вплотную
-- к стене (тот же приём, что и SWITCH_WALL_CLEARANCE для свитча).
local SWITCH_WALL_CLEARANCE = 6
local ENDO_MODEL         = "models/mountroid/thudner/hw withered pack/endo02.mdl"
local COPY_HP = 3000
local endoActiveCopy = {}

-- Глобальный доступ для интеграции со станом киллера / шокером
function MODULE.GetActiveCopy(ply)
    return endoActiveCopy and endoActiveCopy[ply] or nil
end

local function ValidateSpawnPos(candidate, filterEnt)
    -- Trace hull downward to land on the actual floor
    local downTr = util.TraceHull({
        start  = candidate + Vector(0, 0, 100),
        endpos = candidate - Vector(0, 0,  60),
        mins   = HULL_MINS,
        maxs   = HULL_MAXS,
        mask   = MASK_PLAYERSOLID,
        filter = filterEnt,
    })

    if downTr.StartSolid then return nil end

    local finalPos = downTr.Hit
        and (downTr.HitPos + Vector(0, 0, 1))
        or candidate

    -- Confirm the landing spot itself is clear (стены, дверные проёмы,
    -- слишком узкие места — хитбокс копии тут просто не влезет). Hull
    -- раздут на SPAWN_WALL_CLEARANCE по X/Y — позиция впритык к стене
    -- (формально не солид, но без запаса) теперь тоже отбраковывается.
    local clearTr = util.TraceHull({
        start  = finalPos,
        endpos = finalPos,
        mins   = Vector(HULL_MINS.x - SPAWN_WALL_CLEARANCE, HULL_MINS.y - SPAWN_WALL_CLEARANCE, HULL_MINS.z),
        maxs   = Vector(HULL_MAXS.x + SPAWN_WALL_CLEARANCE, HULL_MAXS.y + SPAWN_WALL_CLEARANCE, HULL_MAXS.z),
        mask   = MASK_PLAYERSOLID,
        filter = filterEnt,
    })
    if clearTr.StartSolid then return nil end

    -- Don't overlap a living player
    for _, ply in player.Iterator() do
        if ply == filterEnt then continue end
        if ply:GetPos():Distance2D(finalPos) < 50 then
            return nil
        end
    end

    return finalPos
end

--- Attempt to find a navmesh-grounded, geometry-clear spawn position
--- for one copy near `origin`.  Returns a Vector or nil on failure.
local function FindCopySpawnPos(origin, usedPositions, filterEnt)
    -- 30 random attempts in a ring around origin
    for _ = 1, 30 do
        local angle = math.random() * 360
        local dist  = math.random(SPAWN_RADIUS_MIN, SPAWN_RADIUS_MAX)
        local candidate = origin + Vector(
            math.cos(math.rad(angle)) * dist,
            math.sin(math.rad(angle)) * dist,
            60   -- probe above floor
        )

        -- Snap to nearest nav area so we stay on walkable ground
        local area = navmesh.GetNearestNavArea(candidate, false, 350, false, false)
        if not IsValid(area) then continue end

        local navPos = area:GetClosestPointOnArea(candidate)

        -- Enforce minimum separation between copies
        local tooClose = false
        for _, used in ipairs(usedPositions) do
            if navPos:Distance(used) < MIN_COPY_SEP then
                tooClose = true
                break
            end
        end
        if tooClose then continue end

        local finalPos = ValidateSpawnPos(navPos, filterEnt)
        if finalPos then return finalPos end
    end

    -- Fallback: try cardinal nav areas close to origin.
    -- Раньше тут возвращалась голая точка с навмеша БЕЗ клиренс-проверки —
    -- теперь гоняем её через тот же ValidateSpawnPos, что и основной цикл,
    -- и если она внутри стены/проёма — просто идём к следующему углу,
    -- а не отдаём заведомо плохую позицию. Дистанция подтянута к новому
    -- SPAWN_RADIUS_MIN, чтобы фоллбэк не спавнил заметно ближе основного цикла.
    for _, ang in ipairs({ 0, 90, 180, 270 }) do
        local fbPos = origin + Vector(
            math.cos(math.rad(ang)) * SPAWN_RADIUS_MIN,
            math.sin(math.rad(ang)) * SPAWN_RADIUS_MIN,
            0
        )
        local area = navmesh.GetNearestNavArea(fbPos, false, 400)
        if IsValid(area) then
            local navPos = area:GetClosestPointOnArea(fbPos)
            local finalPos = ValidateSpawnPos(navPos, filterEnt)
            if finalPos then return finalPos end
        end
    end

    return nil
end

-- =====================================================================
--  COPY MANAGEMENT
-- =====================================================================

local function RemoveEndoCopies(ply)
    local copies = endoCopies[ply]
    if not copies then return end

    for _, copy in ipairs(copies) do
        if IsValid(copy) then copy:Remove() end
    end

    endoCopies[ply]  = nil
    endoHovered[ply] = nil
    endoActiveCopy[ply] = nil
end

--- Применяет статичные boneMorphs из formTable (см. pill_costume.lua,
--- функция PillApply / formTable.boneMorphs) на копию — чтобы форма тела
--- совпадала с живым pill'ом ещё ДО всякой позы. Раньше копии этого не
--- получали вообще, только сам SetModel — если у pill_endo02 в форме
--- заданы кастомные bone-морфы, копия визуально отличалась формой.
local function ApplyBoneMorphs(ent, formTable)
    if not IsValid(ent) or not formTable or not formTable.boneMorphs then return end

    for boneName, v in pairs(formTable.boneMorphs) do
        local b = ent:LookupBone(boneName)
        if not b then continue end

        if v.pos then ent:ManipulateBonePosition(b, v.pos) end
        if v.rot then ent:ManipulateBoneAngles(b, v.rot) end
        if v.scale then ent:ManipulateBoneScale(b, v.scale) end
    end
end

local function SpawnEndoCopies(ply)
    RemoveEndoCopies(ply)
    if not IsValid(ply) then return end

    local origin       = ply:GetPos()
    local copies       = {}
    local usedPositions = {}

    local pill      = ply:GetPill()
    local formTable = IsValid(pill) and pill.formTable or nil

    for i = 1, COPY_COUNT do
        local pos = FindCopySpawnPos(origin, usedPositions, ply)
        if not pos then
            SlashMoon.Debug("[EndoCopies] Не найдена позиция для копии #", i)
            continue
        end

        table.insert(usedPositions, pos)

        local copy = ents.Create("endo_copy")
        if not IsValid(copy) then continue end

        copy:SetPos(pos)
        copy:SetAngles(Angle(0, math.random(360), 0))
        copy:SetOwnerPlayer(ply)
        copy:SetCopyIndex(i)
        copy:SetIsHovered(false)
        copy:Spawn()
        copy:Activate()
        copy:SetCopyHP(COPY_HP)

        ApplyBoneMorphs(copy, formTable)

        table.insert(copies, copy)
    end

    endoCopies[ply] = copies
    SlashMoon.Debug("[EndoCopies] Создано копий: ", #copies, " для ", ply:Nick())
end

-- =====================================================================
--  NETWORK — receive hovered copy from client
-- =====================================================================

MODULE:Receive("endo_set_hovered", function(_, ply)
    local copy = net.ReadEntity()

    -- Clear the old highlighted copy first
    local prev = endoHovered[ply]
    if IsValid(prev) then
        prev:SetIsHovered(false)
    end
    endoHovered[ply] = nil

    -- Accept only copies that actually belong to this player
    if IsValid(copy)
    and copy:GetClass() == "endo_copy"
    and copy:GetOwnerPlayer() == ply then
        copy:SetIsHovered(true)
        endoHovered[ply] = copy
    end
end)

-- =====================================================================
--  GAMEMODE INTEGRATION — runs after all Lua files are loaded
-- =====================================================================

local CHARGE_TIME    = 1.0   -- seconds to hold RMB before teleport
local endoCharging   = {}    -- [Player] = { startTime, targetCopy }

local function CancelEndoCharge(ply)
    endoCharging[ply] = nil
    if IsValid(ply) then
        ply:SetNW2Float("endo_charge_start", 0)
    end
end

-- =====================================================================
--  SWITCH VALIDATION — TraceHull-проверка позиции копии перед свитчем
--  Копия может оказаться заблокирована динамическим пропом (закрылась
--  дверь, сдвинулся лифт, съехал мост) уже после спавна. Если просто
--  телепортировать туда игрока — он застрянет в солиде. Проверяем.
-- =====================================================================

-- Дефолтный standing hull игрока в GMod (16×16×72). Используем хардкод,
-- а не ply:GetHull(), т.к. PerformEndoSwitch ниже временно сжимает
-- GetHull() до duck-размера — если в этот момент кто-то спросит
-- GetHull(), получит 36u вместо 72u и решение будет неверным.
local STAND_HULL_MINS = Vector(-16, -16, 0)
local STAND_HULL_MAXS = Vector(16, 16, 72)

-- Точечная TraceHull (start == endpos) — тот же приём, что в
-- ValidateSpawnPos выше. StartSolid = позиция внутри солида — ловит
-- мир + динамические пропы (двери, лифты, мосты), но НЕ ловит другие
-- копии (они в COLLISION_GROUP_PUSHAWAY, см. init.lua — специально
-- сделано, чтобы не блокировать player-solid трейсы).
--
-- wallClearance (опционально): раздувает hull по X/Y на N юнитов ТОЛЬКО
-- для этой проверки (сама позиция не двигается). Без этого позиция
-- вплотную к стене проходила проверку — хитбокс формально не солид, но
-- впритык: после свитча камера клипает в стену, при повороте плечи модели
-- проходят сквозь геометрию. С паддингом такая позиция считается занятой.
local function IsHullPosClear(pos, mins, maxs, filter, wallClearance)
    wallClearance = wallClearance or 0
    local checkMins, checkMaxs = mins, maxs
    if wallClearance > 0 then
        checkMins = Vector(mins.x - wallClearance, mins.y - wallClearance, mins.z)
        checkMaxs = Vector(maxs.x + wallClearance, maxs.y + wallClearance, maxs.z)
    end

    local tr = util.TraceHull({
        start  = pos + Vector(0, 0, 1),
        endpos = pos + Vector(0, 0, 1),
        mins   = checkMins,
        maxs   = checkMaxs,
        mask   = MASK_PLAYERSOLID,
        filter = filter,
    })
    return not tr.StartSolid
end

-- Сколько юнитов свободного места по бокам требуем вокруг позиции свитча
-- (и для копии, и для игрока). Если вплотную к стене меньше этого — свитч
-- запрещён, даже если сам хитбокс формально не солид.
local SWITCH_WALL_CLEARANCE = 24

-- ★ COPY-VS-COPY DISTANCE CHECK
-- Другие копии не ловятся TraceHull (см. выше), поэтому расстояние до
-- них проверяем вручную, ровно как MIN_COPY_SEP при спавне. excludeCopy —
-- копия, которую не учитываем (обычно сама целевая копия свитча).
local function IsFarFromOtherCopies(pos, ownerCopies, excludeCopy)
    if not ownerCopies then return true end
    local minSepSqr = MIN_COPY_SEP * MIN_COPY_SEP
    for _, other in ipairs(ownerCopies) do
        if IsValid(other) and other ~= excludeCopy then
            -- other:GetPos() может устареть на один кадр, но для
            -- проверки дистанции этого достаточно.
            if pos:DistToSqr(other:GetPos()) < minSepSqr then
                return false
            end
        end
    end
    return true
end

-- Проверяет, может ли игрок безопасно встать в позицию копии, И может
-- ли копия безопасно встать на текущую позицию игрока (при свитче они
-- меняются местами — см. PerformEndoSwitch: hovered:SetPos(oldPos)).
--
-- Это ДВЕ разные проверки с ДВУМЯ разными халлами — они соответствуют
-- двум независимым местам в PerformEndoSwitch, где решается duck/stand:
--
--   • copyPos (куда телепортируется игрок): решает wasCopyCrouched —
--     ТЕКУЩИЙ сохранённый хитбокс самой копии (copy:GetCollisionBounds()).
--     Жать Ctrl ЗАРАНЕЕ не нужно — если копия стоит в вентиляции,
--     PerformEndoSwitch сам зажмёт игроку присед через endo_force_duck
--     ПОСЛЕ свапа. Поэтому здесь смотрим на саму копию, а не на игрока.
--
--   • plyPos (куда встанет покидаемая копия): решает ply:Crouching() —
--     РЕАЛЬНЫЙ присед игрока в момент свапа (см.
--     hovered:SetCollisionBounds(duckMins/standMins, ...) ниже по файлу).
--     Копия получает тот хитбокс, в котором игрок сейчас физически стоит.
--
-- Блокирует свитч если:
--   1) целевая копия стоит в двери/на лифте/в другом динамическом пропе
--   2) целевая копия слишком близко к другой копии владельца
--   3) сам игрок (Эндо) стоит в двери/на лифте/в другом динамическом пропе
--   4) сам игрок (Эндо) слишком близко к другой копии владельца
-- StartSolid = hull внутри солида (дверь, стена лифта, закрывшийся мост).
local function CanSwitchToCopy(ply, copy)
    if not IsValid(ply) or not IsValid(copy) then return false end

    local copyPos = copy:GetPos()
    local plyPos  = ply:GetPos()

    -- Hull для copyPos: duck если ЦЕЛЕВАЯ КОПИЯ сейчас сама duck-размера.
    local _, copyMaxs = copy:GetCollisionBounds()
    local copyCrouched = copyMaxs.z < 50
    local copyMins, copyHullMaxs
    if copyCrouched then
        copyMins, copyHullMaxs = ply:GetHullDuck()
    else
        copyMins, copyHullMaxs = STAND_HULL_MINS, STAND_HULL_MAXS
    end

    -- Hull для plyPos: duck если ИГРОК сейчас реально в приседе.
    local plyMins, plyHullMaxs
    if ply:Crouching() then
        plyMins, plyHullMaxs = ply:GetHullDuck()
    else
        plyMins, plyHullMaxs = STAND_HULL_MINS, STAND_HULL_MAXS
    end

    -- Фильтр: игрок + целевая копия + предыдущая активная копия.
    -- Остальные сущности (динамические пропы, двери, лифты) блокируют.
    local filter = { ply, copy }
    local prevActive = endoActiveCopy[ply]
    if IsValid(prevActive) and prevActive ~= copy then
        filter[#filter + 1] = prevActive
    end

    local ownerCopies = endoCopies[ply]

    -- 1-2) Целевая позиция копии: не солид, не рядом с другой копией,
    -- не впритык к стене (SWITCH_WALL_CLEARANCE).
    if not IsHullPosClear(copyPos, copyMins, copyHullMaxs, filter, SWITCH_WALL_CLEARANCE) then return false end
    if not IsFarFromOtherCopies(copyPos, ownerCopies, copy) then return false end

    -- 3-4) Текущая позиция игрока: та же проверка, т.к. копия встанет
    -- именно сюда.
    if not IsHullPosClear(plyPos, plyMins, plyHullMaxs, filter, SWITCH_WALL_CLEARANCE) then return false end
    if not IsFarFromOtherCopies(plyPos, ownerCopies, copy) then return false end

    return true
end

-- Уведомляет клиента, что свитч невозможен — без чата, клиент сам
-- отрисует фидбек (флэш цвета RMB-иконки способности + звук отказа,
-- см. cl_endo_copies.lua, MODULE:Receive("endo_switch_denied")).
local function NotifySwitchDenied(ply)
    if not IsValid(ply) then return end
    net.Start("endo_switch_denied")
    net.Send(ply)
end

local function PerformEndoSwitch(ply, hovered)
    local oldPos  = ply:GetPos()
    local copyPos = hovered:GetPos()

    -- Проверяем была ли копия в приседе ДО изменения её хитбокса
    local _, origCopyMaxs = hovered:GetCollisionBounds()
    local wasCopyCrouched = origCopyMaxs.z < 50

    -- Сохраняем standing hull ДО любых модификаций. Кулдаун свитча 7с,
    -- восстановление hull'а — <2с, так что к этому моменту GetHull()
    -- уже нормальный (72u). Но если вдруг нет (пред. свитч не успел
    -- сбросить) — fallback на хардкод-дефолт.
    local standMins, standMaxs = ply:GetHull()
    if standMaxs.z < 50 then
        standMins = STAND_HULL_MINS
        standMaxs = STAND_HULL_MAXS
    end
    local duckMins, duckMaxs = ply:GetHullDuck()

    -- Сохраняем angles и позу пила ДО телепорта
    local savedAngles = ply:EyeAngles()
    local pill = ply:GetPill()
    local savedSeq   = IsValid(pill) and pill:GetSequence() or -1
    local savedCycle = IsValid(pill) and pill:GetCycle() or 0

    local copyDestPos = oldPos + Vector(0, 0, 1)
    if not ply:OnGround() then
        local tr = util.TraceHull({
            start  = oldPos + Vector(0, 0, 5),
            endpos = oldPos - Vector(0, 0, 500),
            mins   = HULL_MINS,
            maxs   = HULL_MAXS,
            mask   = MASK_PLAYERSOLID,
            filter = ply,
        })
        if tr.Hit then
            copyDestPos = tr.HitPos + Vector(0, 0, 1)
        end
    end

    -- ★ CROUCH FIX: сжимаем standing hull игрока ДО телепорта, а не после.
    -- Раньше SetHull(duck) шёл ПОСЛЕ SetPos — один кадр игрок стоял с 72u
    -- hull внутри 36u вентиляции, движок resolves коллизию и пихает игрока
    -- в стену/пол. Теперь hull сжат заранее → collide не с чем.
    if wasCopyCrouched then
        ply:SetHull(duckMins, duckMaxs)
    end

    hovered:SetPos(copyDestPos)
    ply:SetPos(copyPos + Vector(0, 0, 1))
    local prevActive = endoActiveCopy[ply]

    -- Сохраняем HP в покидаемую копию, НО никогда не перезаписываем HP
    -- оригинала — оно должно хранить HP от первого свитча для восстановления.
    if IsValid(prevActive) and not prevActive:GetIsOriginal() then
        prevActive:SetCopyHP(math.max(ply:Health(), 1))
    end

    -- Обмениваем ХП: копия получает наше, мы получаем её
    local playerHP = ply:Health()
    local copyHP = hovered:GetCopyHP()
    hovered:SetCopyHP(playerHP)
    ply:SetHealth(copyHP)
    ply:SetVelocity(Vector(0, 0, 0))
    endoActiveCopy[ply] = hovered

    -- Копируем углы взгляда на копию
    hovered:SetAngles(Angle(0, savedAngles.y, 0))

    -- Замораживаем копию в позе игрока
    if savedSeq >= 0 then
        hovered:SetSequence(savedSeq)
        hovered:SetCycle(savedCycle)
        hovered:SetPlaybackRate(0)
    end

    -- Гасим jiggle-кости (если они есть в модели) — иначе провода/тряпки
    -- будут чуть подрагивать даже у "мёртвой" замороженной копии, что
    -- portит иллюзию статики. ManipulateBoneJiggle безопасно вызывать
    -- на не-jiggle костях — просто ничего не делает.
    for i = 0, hovered:GetBoneCount() - 1 do
        hovered:ManipulateBoneJiggle(i, 2) -- 2 = принудительно выключить jiggle
    end

    -- Копируем хитбокс (присед/стоя) на покидаемую копию.
    -- ВАЖНО: берём сохранённые standMins/standMaxs, а НЕ ply:GetHull() —
    -- выше мы могли сжать GetHull() до duck-размера, и тогда копия получит
    -- миниатюрный standing хитбокс, и при следующем свитче на неё
    -- wasCopyCrouched сработает ложно (maxs.z < 50).
    if ply:Crouching() then
        hovered:SetCollisionBounds(duckMins, duckMaxs)
    else
        hovered:SetCollisionBounds(standMins, standMaxs)
    end

    -- Если копия была в приседе — принудительно ставим игрока в присед.
    -- Hull уже сжат ДО телепорта (см. выше). Здесь только отправляем
    -- endo_force_duck, чтобы клиент зажал IN_DUCK — движок переключится
    -- на HullDuck, и мы сможем безопасно восстановить standing hull до 72u.
    if wasCopyCrouched then
        net.Start("endo_force_duck")
        net.Send(ply)

        -- Восстанавливаем standing hull когда игрок РЕАЛЬНО присел
        -- (Crouching() = true → движок использует HullDuck, Hull в
        -- коллизиях не участвует → безопасно вернуть 72u). Если за 2с
        -- не присел (сетевой сбой?) — восстанавливаем принудительно:
        -- если игрок в вентиляции, движок не даст ему встать (проверит
        -- standing hull и заблокирует uncrouch).
        --
        -- Старый код слепо ставил SetHull(72u) через timer.Simple(2) —
        -- если игрок за эти 2с УЖЕ присел и стоит в вентиляции, restore
        -- проходит нормально (Hull не используется при crouch). Но если
        -- игрок за 2с не успел присел (пинг, лаг) — restore ставит 72u,
        -- а crouch ещё не активен → движок uses Hull(72u) в вентиляции
        -- → stuck. Поллинг Crouching() решает это.
        local plyId = ply:EntIndex()
        local timerName = "endo_crouch_restore_" .. plyId
        local attempts = 0
        MODULE:Timer(timerName, 0.1, 20, function()
            attempts = attempts + 1
            if not IsValid(ply) then
                MODULE:RemoveTimer(timerName)
                return
            end
            -- Crouching() = true → движок на HullDuck, Hull свободен.
            -- Либо 20 попыток (2с) — fallback, дальше ждать бессмысленно.
            if ply:Crouching() or attempts >= 20 then
                ply:SetHull(standMins, standMaxs)
                MODULE:RemoveTimer(timerName)
            end
        end)
    end

    -- Логика IsOriginal:
    --  - Переключаемся НА оригинал → снимаем с него флаг (игрок "вернулся")
    --  - Нет оригинала (первый свитч) → помечаем целевую копию как оригинал
    --  - Переключаемся на обычную копию, оригинал есть → не трогаем
    if hovered:GetIsOriginal() then
        hovered:SetIsOriginal(false)
    else
        local hasOriginal = false
        for _, c in ipairs(endoCopies[ply] or {}) do
            if IsValid(c) and c:GetIsOriginal() then
                hasOriginal = true
                break
            end
        end
        if not hasOriginal then
            hovered:SetIsOriginal(true)
        end
    end

    hovered:SetIsHovered(false)
    endoHovered[ply] = nil

    cooldown.Set(ply, "endo_switch", 7)
    cooldown.Send(ply, "endo_switch")
end

local switchingPlayers = {}

local SWITCH_FADE = 0.5
local function StartEndoSwitch(ply, targetCopy)
    if switchingPlayers[ply] then return end

    if not CanSwitchToCopy(ply, targetCopy) then
        CancelEndoCharge(ply)
        NotifySwitchDenied(ply)
        return
    end

    switchingPlayers[ply] = true

    ply:Freeze(true)

    net.Start("endo_start_switch")
    net.WriteFloat(ANIM_DUR)
    net.WriteFloat(SWITCH_FADE)
    net.Send(ply)

    -- Свитч на середине анимации
    timer.Simple(ANIM_DUR / 2, function()
        if IsValid(ply) and IsValid(targetCopy) then
            PerformEndoSwitch(ply, targetCopy)
        end
    end)

    -- Разморозка = последний кадр
    timer.Simple(ANIM_DUR, function()
        if not IsValid(ply) then return end
        switchingPlayers[ply] = nil
        ply:Freeze(false)
    end)
end

MODULE:Hook("InitPostEntity", "endo_copies_sv_init", function()
    if engine.ActiveGamemode() ~= "fazbearshunt" then return end


    -- Хуки гейммода для эндо снимаются и возвращаются при отключении модуля
    MODULE:SuppressHook("OnPlayerPhysicsDrop", "fh_endo_prop_drop")
    MODULE:SuppressHook("PlayerUse", "fh_endo_largeprop_pickup")
    MODULE:SuppressHook("OnPlayerPhysicsPickup", "fh_endo_pickup")

    -- ---- запоминаем исходные поля пилла, чтобы вернуть их при отключении ----
    local origTable = pills.getPillTable("pill_endo02")
    if origTable and not MODULE.OriginalPill then
        MODULE.OriginalPill = { onRemove = origTable.onRemove, health = origTable.health, attack2 = origTable.attack2 }
    end
    local origOnRemove = MODULE.OriginalPill and MODULE.OriginalPill.onRemove

    -- pills.editPillTable("pill_endo02", "attack2", {
    --     mode = "trigger",
    --     func = function(ply, ent) end
    -- })

    pills.editPillTable("pill_endo02", "onRemove", function(ent, formTable, ply)
        if origOnRemove then origOnRemove(ent, formTable, ply) end
        CancelEndoCharge(ply)
        if IsValid(ply) then RemoveEndoCopies(ply) end
    end)
    pills.editPillTable("pill_endo02", "health", 5000)

    -- ---- replace attack2 -------------------------------------------
    --   Hovering a copy  →  start charge (hold RMB to teleport)
    --   No copy hovered  →  original grab behavior (fallback)
    --
    pills.editPillTable("pill_endo02", "attack2", {
        mode = "trigger",
        func = function(ply, ent)
            local hovered = endoHovered[ply]

            if IsValid(hovered) then
                if cooldown.Exists(ply, "endo_switch") then return end
                if endoCharging[ply] then return end

                -- Не начинаем заряд, если свитч уже невозможен (Эндо сам
                -- стоит в дверном проёме/на лифте/рядом с другой копией,
                -- либо целевая копия заблокирована) — иначе полоска
                -- заряда мигнёт на кадр и тут же оборвётся тиком ниже.
                if not CanSwitchToCopy(ply, hovered) then
                    NotifySwitchDenied(ply)
                    return
                end

                -- Release any grabbed player before charging
                endo.releasePlayer(ply)

                endoCharging[ply] = {
                    startTime  = CurTime(),
                    targetCopy = hovered,
                }
                ply:SetNW2Float("endo_charge_start", CurTime())

            else
                if cooldown.Exists(ply, "grab") then return end
                if IsValid(ply:GetEntityInUse()) then return end
                -- endo.grabNeareastPlayer(ply, ent)
            end
        end,
    })

    -- Tick charge progress — teleport when ready
    MODULE:Hook("Think", "endo_charge_tick", function()
        for ply, data in pairs(endoCharging) do
            if not IsValid(ply) or not IsValid(data.targetCopy) then
                CancelEndoCharge(ply)
                continue
            end
            -- Cancel if player looked away from the target copy
            if endoHovered[ply] ~= data.targetCopy then
                CancelEndoCharge(ply)
                continue
            end
            -- Cancel if destination is blocked (dynamic prop moved in,
            -- door closed, elevator shifted, etc.). TraceHull check
            -- every frame — позиция копии может поменяться в любой момент.
            if not CanSwitchToCopy(ply, data.targetCopy) then
                CancelEndoCharge(ply)
                NotifySwitchDenied(ply)
                continue
            end
            if CurTime() - data.startTime >= CHARGE_TIME then
                StartEndoSwitch(ply, data.targetCopy)
                CancelEndoCharge(ply)
            end
        end
    end)

    -- Cancel charge if player releases RMB early
    MODULE:Hook("KeyRelease", "endo_switch_cancel", function(ply, key)
        if key == IN_ATTACK2 then
            CancelEndoCharge(ply)
        end
    end)

end)

-- =====================================================================
--  HOOKS — lifecycle
-- =====================================================================

local function TransferToNextCopy(ply)
    local deadCopy = endoActiveCopy[ply]
    local copies = endoCopies[ply]
    if not copies then return false end

    -- СНАЧАЛА удаляем мёртвую копию со взрывом,
    -- чтобы взрыв был ВСЕГДА, даже если это последняя копия
    if IsValid(deadCopy) then
        if deadCopy.Explode then deadCopy:Explode() end
        for i, c in ipairs(copies) do
            if c == deadCopy then
                table.remove(copies, i)
                break
            end
        end
        deadCopy:Remove()
        endoActiveCopy[ply] = nil
    end

    -- Теперь ищем ближайшую живую копию
    local bestCopy = nil
    local bestDist = math.huge
    for _, copy in ipairs(copies) do
        if not IsValid(copy) then continue end
        if copy:GetCopyHP() <= 0 then continue end
        local d = ply:GetPos():DistToSqr(copy:GetPos())
        if d < bestDist then
            bestDist = d
            bestCopy = copy
        end
    end

    if not IsValid(bestCopy) then return false end

    -- Свап позиций: копия идёт на место игрока, игрок — на место копии
    local newPos = bestCopy:GetPos()
    local oldPos = ply:GetPos()
    bestCopy:SetPos(oldPos)
    ply:SetPos(newPos + Vector(0, 0, 1))
    ply:SetHealth(bestCopy:GetCopyHP())
    ply:SetVelocity(Vector(0, 0, 0))
    endoActiveCopy[ply] = bestCopy

    return true
end

MODULE:Hook("EntityTakeDamage", "endo_copy_entity_damage", function(target, dmginfo)
    if not IsValid(target) or target:GetClass() ~= "endo_copy" then return end

    local attacker = dmginfo:GetAttacker()
    if not IsValid(attacker) or not attacker:IsKiller() then return end

    -- Масштабируем урон если топор бьёт по энтити (20-30 по умолчанию)
    local dmg = dmginfo:GetDamage()
    if dmg < 100 then
        local animsCount = team.NumPlayers(TEAM_PILLS) or 1
        dmg = math.random(550, 600) + math.max(1, animsCount - 1) * 15
    end

    local newHP = target:GetCopyHP() - dmg
    target:SetCopyHP(math.max(newHP, 0))

    -- Визуальные эффекты и звук — как у обычного эндо при ударе топором
    local hitPos = dmginfo:GetDamagePosition()
    if not hitPos or hitPos == Vector(0, 0, 0) then
        hitPos = target:GetPos() + Vector(0, 0, 43)
    end
    target:EmitSound("physics/metal/metal_sheet_impact_hard" .. math.random(7, 8) .. ".wav")
    local fx = EffectData()
    fx:SetOrigin(hitPos)
    fx:SetStart(hitPos)
    util.Effect("cball_explode", fx, true, true)

    if newHP <= 0 then
        local owner = target:GetOwnerPlayer()

        if IsValid(owner) and endoActiveCopy[owner] == target then
            -- Активная копия убита — TransferToNextCopy сам удалит её со взрывом
            if not TransferToNextCopy(owner) then
                owner:Kill()
            end
        else
            -- Неактивная копия убита — взрыв и удаление вручную
            if target.Explode then target:Explode() end
            if IsValid(owner) then
                local copies = endoCopies[owner]
                if copies then
                    for i, c in ipairs(copies) do
                        if c == target then
                            table.remove(copies, i)
                            break
                        end
                    end
                end
            end
            target:Remove()
        end
    end

    dmginfo:SetDamage(0)
end)

MODULE:Hook("EntityTakeDamage", "endo_copy_player_damage_redirect", function(target, dmginfo)
    if not target:IsPlayer() then return end
    if not target:IsAnimatronic() then return end

    local pill = target:GetPill()
    if not IsValid(pill) or pill:GetPillName() ~= "pill_endo02" then return end

    local attacker = dmginfo:GetAttacker()
    if not IsValid(attacker) or not attacker:IsKiller() then return end

    local activeCopy = endoActiveCopy[target]

    -- Safety: очищаем устаревшую ссылку на удалённую копию
    if activeCopy ~= nil and not IsValid(activeCopy) then
        endoActiveCopy[target] = nil
        activeCopy = nil
    end

    if IsValid(activeCopy) then
        -- Игрок "в" копии — редиректим урон на неё
        local dmg = dmginfo:GetDamage()
        local newHP = activeCopy:GetCopyHP() - dmg
        activeCopy:SetCopyHP(math.max(newHP, 0))

        if newHP <= 0 then
            if not TransferToNextCopy(target) then
                dmginfo:SetDamage(target:Health())
            else
                dmginfo:SetDamage(0)
            end
        else
            target:SetHealth(newHP)
            dmginfo:SetDamage(0)
        end
    end
end, -1)

-- Spawn copies when a player receives the endo02 pill
MODULE:Hook("PillServerApply", "endo_copies_spawn", function(ply, pillName)
    if pillName ~= "pill_endo02" then return end
    -- Small delay so the pill entity is fully initialised
    timer.Simple(0.4, function()
        if IsValid(ply) and ply:IsAnimatronic() then
            SpawnEndoCopies(ply)
        end
    end)
end)

MODULE:Hook("PlayerDisconnected", "endo_copies_disconnect", RemoveEndoCopies)

MODULE:Hook("PlayerChangedTeam", "endo_copies_teamchange", function(ply, _, newTeam)
    -- Animatronic team in FH is 2701; TEAM_PILLS is also used while in pill
    if newTeam ~= 2701 and newTeam ~= TEAM_PILLS then
        RemoveEndoCopies(ply)
    end
end)

MODULE:Hook("fh_postendgame", "endo_copies_roundend", function()
    for ply in pairs(table.Copy(endoCopies)) do
        if IsValid(ply) then RemoveEndoCopies(ply) end
    end
end)

-- Отключение модуля: убираем копии и возвращаем исходный пилл гейммода
MODULE:OnDisabled(function()
    for ply in pairs(table.Copy(endoCopies)) do
        CancelEndoCharge(ply)
        if IsValid(ply) then RemoveEndoCopies(ply) end
    end
    if pills and pills.editPillTable and MODULE.OriginalPill then
        for key, value in pairs(MODULE.OriginalPill) do
            pills.editPillTable("pill_endo02", key, value)
        end
    end
end)

MODULE:Hook("PostCleanupMap", "endo_copies_mapclean", function()
    table.Empty(endoCopies)
    table.Empty(endoHovered)
end)

-- если эндо не на земле то пусть падает нах
MODULE:Hook("Think", "endo_copy_physics", function()
    for _, copies in pairs(endoCopies) do
        for _, copy in ipairs(copies) do
            if not IsValid(copy) then continue end

            if not copy:IsOnGround() then
                copy:SetVelocity(Vector(0, 0, -800) * FrameTime() + (copy:GetVelocity() or Vector(0, 0, 0)))
            else
                local vel = copy:GetVelocity()
                if vel:LengthSqr() > 1 then
                    copy:SetVelocity(Vector(0, 0, 0))
                end
            end
        end
    end
end)

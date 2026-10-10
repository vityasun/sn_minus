-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("dances")

sql.Query("CREATE TABLE IF NOT EXISTS wos_dance_binds (slot INTEGER PRIMARY KEY, anim_id TEXT)")

-- === ОПТИМИЗАЦИЯ #15 ===
-- Кэш биндов в памяти. Раньше каждый вызов GetCircleData() делал полный
-- SELECT * из SQLite: при наведении на слот в меню конфигурации, при каждом
-- открытии радиального меню и при отпускании клавиши H.
-- Теперь SQL дёргается только при изменении биндов либо раз в 3 секунды
-- (TTL нужен, чтобы подтягивались покупки анимаций из инвентаря SlashMoon.Hub).
local bindsCache = nil
local bindsCacheTime = 0
local CACHE_TTL = 3

function SlashMoon.Dances.RefreshBinds()
    bindsCache = nil
    bindsCacheTime = 0
end

function SlashMoon.Dances.SetAnimSlot(slot, animID)
    -- === ЗАЩИТА: валидация слота (раньше нечисловой слот давал SQL-ошибку,
    -- а слот извне мог быть вектором для SQL-инъекции) ===
    slot = tonumber(slot)
    if not slot or slot < 1 or slot > 8 then return end

    if not animID or animID == "" then
        sql.Query("DELETE FROM wos_dance_binds WHERE slot = " .. slot)
        SlashMoon.Dances.RefreshBinds()
        return
    end

    local safeID = sql.SQLStr(animID)
    -- === ОПТИМИЗАЦИЯ #16 ===
    -- Один запрос INSERT OR REPLACE вместо связки SELECT + UPDATE/INSERT.
    sql.Query("INSERT OR REPLACE INTO wos_dance_binds (slot, anim_id) VALUES (" .. slot .. ", " .. safeID .. ")")
    SlashMoon.Dances.RefreshBinds()
end

function SlashMoon.Dances.GetCircleData()
    if bindsCache and (SysTime() - bindsCacheTime) < CACHE_TTL then
        return bindsCache
    end

    local data = sql.Query("SELECT * FROM wos_dance_binds")
    local binds = {}
    for i = 1, 8 do binds[i] = { id = nil, name = "Пусто" } end

    if data then
        local ply = LocalPlayer()
        for _, row in ipairs(data) do
            local slot = tonumber(row.slot)
            if slot and slot >= 1 and slot <= 8 then
                local animData = SlashMoon.Dances.Animations[row.anim_id]
                if animData and SlashMoon.Dances.HasDance(ply, row.anim_id) then
                    binds[slot] = { id = row.anim_id, name = animData.name }
                end
            end
        end
    end

    bindsCache = binds
    bindsCacheTime = SysTime()
    return binds
end

MODULE:Command("wos_bind", function(ply, cmd, args)
    if not args[1] or not args[2] then return end
    SlashMoon.Dances.SetAnimSlot(tonumber(args[1]), args[2])
end)

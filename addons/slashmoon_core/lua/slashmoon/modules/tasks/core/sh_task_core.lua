-- Written for: SlashMoon. By: VIKA & Ronni

-- ========================================================
-- SN Tasks: Shared Ядро Заданий (v2 — Assert Validation)
-- ========================================================
SlashMoon.Tasks = SlashMoon.Tasks or {}
SlashMoon.Tasks.Registry = SlashMoon.Tasks.Registry or {}

-- ── Register — с валидацией как в fh_interactive ─────────────────────
function SlashMoon.Tasks.Register(id, data)
    assert(isstring(id),   "[SN Tasks] Register: id must be string, got " .. type(id))
    assert(istable(data),  "[SN Tasks] Register: data must be table, got " .. type(data))
    assert(isstring(data.name) or isstring(data.nameKey),
        "[SN Tasks] Register: data.name or data.nameKey required for " .. tostring(id))
    assert(isfunction(data.spawn) or SERVER == false,
        "[SN Tasks] Register: data.spawn required on server for " .. tostring(id))
    
    data.id = id
    SlashMoon.Tasks.Registry[id] = data

    -- Автоматическая регистрация интерфейса в Редакторе
    if CLIENT and data.editor then
        timer.Simple(0, function()
            if SlashMoon.Tasks.Editor and SlashMoon.Tasks.Editor.RegisterSection then
                SlashMoon.Tasks.Editor.RegisterSection(id, data.editor)
            end
        end)
    end

    if SERVER then
        SlashMoon.Debug("[SN Tasks] Зарегистрировано задание: " .. id)
    end
end

-- ── Get — с поддержкой суффиксированных ID ───────────────────────────
-- generator_3, collect_1 и т.д.
function SlashMoon.Tasks.Get(id)
    if SlashMoon.Tasks.Registry[id] then return SlashMoon.Tasks.Registry[id] end
    local baseID = string.match(id, "^(.-)_%d+$")
    return baseID and SlashMoon.Tasks.Registry[baseID] or nil
end

-- ── GetActiveCount — сколько активных заданий ────────────────────────
function SlashMoon.Tasks.GetActiveCount()
    local total, done, failed = 0, 0, 0
    for _, state in pairs(SlashMoon.Tasks.ActiveState or {}) do
        total = total + 1
        if state.done then done = done + 1 end
        if state.failed then failed = failed + 1 end
    end
    return total, done, failed
end

-- Written for: SlashMoon. By: VIKA & Ronni
-- ========================================================
-- SlashMoon Lib :: мягкие зависимости (soft dependencies)
-- Аддон НЕ содержит SAM / ULX / SUI / eChat / eLib, но умеет
-- определять их наличие в среде, не вызывая ошибок при отсутствии.
-- ========================================================

SlashMoon.Compat = SlashMoon.Compat or {}
local Compat = SlashMoon.Compat

-- Детекторы: функция возвращает true, если зависимость установлена.
-- Проверки ленивые — вызываются в момент запроса, поэтому порядок загрузки аддонов не важен.
Compat.Detectors = {
    sam = function()
        return istable(sam) and istable(sam.permissions) and isfunction(sam.permissions.add)
    end,
    ulx = function()
        return istable(ULib) and istable(ULib.ucl) and isfunction(ULib.ucl.query)
    end,
    sui = function()
        return istable(SUI) or istable(sui)
    end,
    echat = function()
        return istable(eChat) or istable(echat)
    end,
    elib = function()
        return istable(esclib) or istable(eLib) or istable(elib)
    end,
    cami = function()
        return istable(CAMI) and isfunction(CAMI.GetUsergroups)
    end,
}

--- Проверяет, установлена ли зависимость.
-- @param name string "sam" | "ulx" | "sui" | "echat" | "elib" | "cami"
function Compat.Has(name)
    local detector = Compat.Detectors[string.lower(tostring(name))]
    if not detector then return false end
    local ok, res = pcall(detector)
    return ok and res == true
end

--- Регистрирует собственный детектор зависимости.
function Compat.Register(name, detector)
    Compat.Detectors[string.lower(name)] = detector
end

--- Выполняет функцию, только если зависимость установлена. Ошибки внутри не роняют аддон.
-- @return boolean выполнена ли функция
function Compat.With(name, fn, ...)
    if not Compat.Has(name) then return false end
    return (SlashMoon.SafeCall(fn, ...))
end

--- Список обнаруженных зависимостей (для админ-панели и отладки).
function Compat.GetDetected()
    local out = {}
    for name in SortedPairs(Compat.Detectors) do
        if Compat.Has(name) then out[#out + 1] = name end
    end
    return out
end

hook.Add("InitPostEntity", "SlashMoon.Compat.Report", function()
    local detected = Compat.GetDetected()
    SlashMoon.Debug("Обнаружены зависимости: ", #detected > 0 and table.concat(detected, ", ") or "нет")
end)

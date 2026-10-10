-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("sliding")

-- ========================================================
-- Синхронизация опций модуля с convar'ами Sliding Ability.
-- Convar'ы реплицируются клиентам, а их callback'и обновляют параметры анимации.
-- ========================================================

local function ApplyOption(def)
    local cv = GetConVar(def.convar)
    if not cv then return end
    local value = MODULE:GetOption(def.key)
    if def.type == "bool" then
        cv:SetBool(value == true)
    else
        cv:SetFloat(tonumber(value) or def.default)
    end
end

local function ApplyAll()
    for _, def in ipairs(MODULE.options) do ApplyOption(def) end
end

-- Convar'ы создаются в sh_sliding.lua, поэтому применяем после загрузки модулей
hook.Add("SlashMoon.ModulesLoaded", "SlashMoon.Sliding.ApplyOptions", ApplyAll)

hook.Add("SlashMoon.OptionChanged", "SlashMoon.Sliding.ApplyOption", function(id, key)
    if id ~= "sliding" then return end
    local def = MODULE.optionDefs[key]
    if def then ApplyOption(def) end
end)

-- Written for: SlashMoon. By: VIKA & Ronni

-- ========================================================
-- SN Tasks: Задание "Выживание" (Localized)
-- ========================================================

SlashMoon.Tasks.Register("survival", {
    name = SlashMoon.Tasks.Lang("sn.task.survival.name"),
    client_hint = SlashMoon.Tasks.Lang("sn.task.survival.hint"),

    rotation = {
        weight = 30,
        minSurvivors = 21,
        chance = 0.05
    },

    spawn = function(cfg, spawnedEnts)
        return { done = false, failed = false, displayName = SlashMoon.Tasks.Lang("sn.task.survival.display") }
    end,

    think = function(state)
        local curPhase = (SlashMoon.Phase and SlashMoon.Phase.State and SlashMoon.Phase.State.phase) or "none"
        if curPhase == "penalty" or curPhase == "escape" then
            state.done = true
        end
    end,

    cleanup = function(state) end,

    editor = {
        title = SlashMoon.Tasks.Lang("sn.task.survival.name"),
        order = 90,
        fields = {
            { type = "checkbox", label = SlashMoon.Tasks.Lang("sn.task.survival.allow_spawn"), path = {"rotation", "allow_survival"}, default = true }
        }
    }
})

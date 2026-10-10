-- Written for: SlashMoon. By: VIKA & Ronni

-- Таблица создается сразу: энтити и оружие модуля ссылаются на нее при загрузке
SlashMoon.Tasks = SlashMoon.Tasks or {}
SlashMoon.Rounds = SlashMoon.Rounds or {}
SlashMoon.Phase = SlashMoon.Phase or {}

SlashMoon.Modules.Register({
    id = "tasks",
    name = "Задания и фазы раунда",
    description = "Система заданий выживших (генераторы, доставка, расследование, выживание), фазы раунда и побег, "
        .. "инвентарь и крафт на верстаке, процедурная расстановка, планшет камер, редактор точек для карт "
        .. "и админ-панель инвентаря. Конфиги карт хранятся в data/sn_tasks/.",
    category = "Геймплей",
    default = true,
    order = 100,
    defer = true, -- зависит от глобалов гейммода, грузится после него
    files = {
        "core/sh_localization.lua", "core/sh_task_core.lua", "sh_config.lua", "compat/sh_game.lua",

        "inventory/core/cl_inventory.lua", "inventory/core/sh_inventory.lua", "inventory/core/sh_items.lua",
        "inventory/core/sv_inventory.lua", "inventory/client/cl_item_notifications.lua",

        "core/cl_hints.lua", "core/cl_last_survivor_highlight.lua", "core/cl_penalty_highlight.lua", "core/cl_phase.lua",
        "core/cl_recipe_pin.lua", "core/cl_task_highlight.lua", "core/cl_tasklist.lua", "core/sh_juice.lua",
        "core/sh_procedural_config.lua", "core/sv_escape_corpse.lua", "core/sv_phase.lua", "core/sv_player_stats.lua",
        "core/sv_procedural.lua", "core/sv_rotation.lua", "core/sv_task_core.lua",

        "editor/sh_editor.lua", "editor/cl_editor.lua", "editor/sh_animcam.lua", "editor/sh_charging.lua",
        "editor/sh_escape.lua", "editor/sh_materials.lua", "editor/sh_workbench.lua",

        "tasks/delivery/sh_delivery.lua", "tasks/generator/sh_generator.lua",
        "tasks/investigation/sh_investigation.lua", "tasks/investigation/sv_investigation.lua",
        "tasks/survival/sh_survival.lua",

        "lms/sv_lms_tasks.lua",

        "rounds/core/cl_escape_screen.lua", "rounds/core/cl_round_summary.lua", "rounds/core/cl_state_machine.lua",
        "rounds/core/sh_state_machine.lua", "rounds/core/sv_state_machine.lua",

        "admin/sv_admin_inv.lua", "admin/sv_material_spawn.lua", "admin/cl_admin_inv.lua",
        "sv_animcam.lua",
        "sv_tasks_init.lua",
    },
    entities = {
        "sn_charging_station", "sn_delivery_zone", "sn_escape_car", "sn_gascan", "sn_generator",
        "sn_generator_decoy", "sn_investigation_corpse", "sn_item_drop", "sn_workbench",
    },
    weapons = {
        "sn_animcam_tablet", "sn_corpse_scanner", "sn_investigation_tablet", "weapon_gascan", "weapon_adrenaline_fix",
    },
})

SlashMoon.Admin.RegisterPermission("slashmoon_tasks_admin", "admin", "Админ-панель инвентаря (выдача и создание предметов)")
SlashMoon.Admin.RegisterPermission("slashmoon_tasks_editor", "superadmin", "Редактор точек заданий и спавна материалов на карте")
SlashMoon.Admin.RegisterPermission("slashmoon_tasks_manage", "superadmin", "Управление раундом, планшетами и отладкой заданий")

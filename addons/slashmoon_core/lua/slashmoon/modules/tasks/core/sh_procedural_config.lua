-- Written for: SlashMoon. By: VIKA & Ronni

-- ========================================================
-- SN Tasks: Shared Procedural Generation Config
-- Port from fh_interactive/sh_procedural_config.lua
-- ========================================================
SlashMoon.ProcGenConfig = {
    HISTORY_DEPTH       = 3,        -- remember last 3 rounds
    HISTORY_FILE_FMT    = "sn_tasks/procgen/%s.json",

    -- Minimum distances WITHIN category (between two objects of same type)
    MIN_DIST_INTRA = {
        generator = 800,
        gascan    = 60,
        collect   = 200,
        delivery  = 400,
        escape    = 500,
        charging  = 400,
        material  = 200,
    },

    -- Minimum distances BETWEEN categories (cross-category anti-cluster)
    -- Format: [catA][catB] = min_dist
    MIN_DIST_CROSS = {
        generator = { gascan = 150, charging = 400, escape = 400, material = 300 },
        gascan    = { generator = 150, charging = 200, material = 150 },
        charging  = { generator = 400, escape = 300, material = 200 },
        escape    = { generator = 400, charging = 300, material = 300 },
        material  = { generator = 300, gascan = 150, charging = 200, escape = 300 },
    },

    -- Default counts (when cfg has no explicit *_count)
    DEFAULT_COUNTS = {
        charging = 0,
    },

    ENABLED = {
        generator = true, gascan = true, collect = true, delivery = true,
        escape = true, charging = true, material = true,
    },
}

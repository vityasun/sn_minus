-- Written for: SlashMoon. By: VIKA & Ronni
-- ========================================================
-- SlashMoon Lib :: загрузчик
-- Порядок: ядро -> UI-библиотека -> админ-панель -> модули.
-- ========================================================

SlashMoon = SlashMoon or {}
SlashMoon.Version = "1.0.0"
SlashMoon.Root = "slashmoon/"

--- Подключает файл с учетом реалма по префиксу имени (sv_ / cl_ / sh_).
-- Файлы без префикса считаются общими (shared).
-- @param path string путь относительно lua/
-- @param realm string|nil принудительный реалм: "sv", "cl" или "sh"
function SlashMoon.IncludeFile(path, realm)
    realm = realm or string.sub(string.GetFileFromFilename(path), 1, 2)

    if realm == "sv" then
        if SERVER then include(path) end
    elseif realm == "cl" then
        if SERVER then
            AddCSLuaFile(path)
        else
            include(path)
        end
    else
        if SERVER then AddCSLuaFile(path) end
        return include(path)
    end
end

local REALM_ORDER = { ["sh_"] = 1, ["sv_"] = 2, ["cl_"] = 3 }

--- Рекурсивно подключает все .lua файлы папки (sh_ -> sv_ -> cl_, внутри по алфавиту; затем подпапки).
-- @param folder string путь к папке относительно lua/
-- @param recursive boolean обходить ли подпапки
-- @param exclude table|nil множество имен файлов, которые нужно пропустить
function SlashMoon.IncludeFolder(folder, recursive, exclude)
    folder = string.TrimRight(folder, "/") .. "/"
    exclude = exclude or {}

    local files, folders = file.Find(folder .. "*", "LUA", "nameasc")

    -- Внутри папки сначала общие файлы, затем серверные, затем клиентские:
    -- cl_/sv_ файлы опираются на таблицы, которые объявляют sh_ файлы.
    local queue = {}
    for _, name in ipairs(files or {}) do
        if string.EndsWith(name, ".lua") and not exclude[name] and not exclude[folder .. name] then
            queue[#queue + 1] = name
        end
    end
    table.sort(queue, function(a, b)
        local ra, rb = REALM_ORDER[string.sub(a, 1, 3)] or 1, REALM_ORDER[string.sub(b, 1, 3)] or 1
        if ra ~= rb then return ra < rb end
        return a < b
    end)

    for _, name in ipairs(queue) do
        SlashMoon.IncludeFile(folder .. name)
    end

    if recursive then
        for _, sub in ipairs(folders or {}) do
            SlashMoon.IncludeFolder(folder .. sub, true, exclude)
        end
    end
end

local root = SlashMoon.Root

-- 1. Ядро (порядок важен)
SlashMoon.IncludeFile(root .. "core/sh_util.lua")
SlashMoon.IncludeFile(root .. "core/sh_json.lua")
SlashMoon.IncludeFile(root .. "core/sh_http.lua")
SlashMoon.IncludeFile(root .. "core/sh_compat.lua")
SlashMoon.IncludeFile(root .. "core/sh_admin.lua")
SlashMoon.IncludeFile(root .. "core/sv_data.lua")
SlashMoon.IncludeFile(root .. "core/sv_security.lua")
SlashMoon.IncludeFile(root .. "core/sv_api.lua")
SlashMoon.IncludeFile(root .. "core/sv_config.lua")
SlashMoon.IncludeFile(root .. "core/sh_modules.lua")

-- 2. UI-библиотека (клиент)
if SERVER then
    -- Шрифт Montserrat (SIL Open Font License) скачивается клиентами автоматически
    for _, weight in ipairs({ "Regular", "Medium", "SemiBold", "Bold" }) do
        resource.AddFile("resource/fonts/Montserrat-" .. weight .. ".ttf")
    end
end
SlashMoon.IncludeFile(root .. "ui/cl_theme.lua")
SlashMoon.IncludeFile(root .. "ui/cl_scale.lua")
SlashMoon.IncludeFile(root .. "ui/cl_fonts.lua")
SlashMoon.IncludeFile(root .. "ui/cl_draw.lua")
SlashMoon.IncludeFile(root .. "ui/cl_ui.lua")
SlashMoon.IncludeFolder(root .. "ui/vgui", false)
SlashMoon.IncludeFile(root .. "ui/cl_popups.lua")
SlashMoon.IncludeFile(root .. "ui/cl_demo.lua")
SlashMoon.IncludeFile(root .. "ui/sh_theme_module.lua")

-- 3. Админ-панель конфигурации
SlashMoon.IncludeFile(root .. "admin/sv_admin_menu.lua")
SlashMoon.IncludeFile(root .. "admin/cl_admin_menu.lua")
SlashMoon.IncludeFile(root .. "admin/sh_commands.lua")

-- 4. Расширения: общие файлы аддонов-потребителей (lua/slashmoon/extensions/),
-- загружаются после библиотеки и до модулей (шрифты, общие хелперы и т.п.)
SlashMoon.IncludeFolder(root .. "extensions", true)

-- 5. Модули
SlashMoon.Modules.LoadAll()

hook.Run("SlashMoon.Loaded")
SlashMoon.Log("Библиотека загружена, версия ", SlashMoon.Version, " | модулей: ", table.Count(SlashMoon.Modules.List))

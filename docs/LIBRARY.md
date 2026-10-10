# SlashMoon Lib

Библиотека для разработчиков Garry's Mod: UI-фреймворк, слой совместимости с админ-системами
(SAM / ULX / стандартные проверки), реестр модулей с включением и выключением на лету,
панель конфигурации, JSON-конфиг и HTTP-утилиты.

Библиотека входит в аддон `slashmoon_core`, но не зависит от его модулей. Отдельный пакет
собирается командой `python3 tools/build_lib.py` (результат появится в `dist/slashmoon_lib`).
Пути файлов в обоих пакетах совпадают, поэтому их можно устанавливать одновременно.

- [Установка](#установка)
- [Структура](#структура)
- [Модули](#модули)
- [Админ-система](#админ-система)
- [UI-библиотека](#ui-библиотека)
- [Утилиты](#утилиты)
- [Хуки](#хуки)

## Установка

Скопируйте папку `slashmoon_lib` (или `slashmoon_core`) в `garrysmod/addons/`.
После запуска сервера в консоли появится `[SlashMoon] Библиотека загружена`.

Демонстрация всех компонентов: консольная команда `slashmoon_ui_demo` (на клиенте).

## Структура

```
lua/autorun/slashmoon_lib_init.lua   точка входа
lua/slashmoon/sh_loader.lua          порядок загрузки
lua/slashmoon/core/                  ядро: логи, JSON, HTTP, админ-слой, модули, конфиг
lua/slashmoon/ui/                    UI: тема, масштабирование, шрифты, отрисовка, компоненты
lua/slashmoon/admin/                 панель конфигурации (!slashmoon / slashmoon_menu)
lua/slashmoon/extensions/            общие файлы аддонов-потребителей (грузятся до модулей)
lua/slashmoon/modules/<id>/          модули (из любого аддона)
```

Реалм файла определяется префиксом: `sv_` — сервер, `cl_` — клиент, `sh_` (или без префикса) — оба.

## Модули

Модуль — это папка `lua/slashmoon/modules/<id>/` в любом аддоне. В ней обязателен манифест `sh_module.lua`:

```lua
-- Written for: SlashMoon. By: VIKA & Ronni
SlashMoon.Modules.Register({
    id = "example",                     -- латиница, цифры, _
    name = "Пример",
    description = "Что делает модуль",
    category = "Геймплей",              -- группа в панели конфигурации
    default = true,                     -- включен по умолчанию
    order = 100,                        -- порядок загрузки (меньше — раньше)
    files = { "sh_example.lua" },       -- необязательно: явный порядок файлов
    defer = false,                      -- true: грузить файлы после гейммода
    entities = { "my_ent" },            -- удаляются и блокируются при выключении
    weapons = { "my_swep" },
    options = {
        { key = "cooldown", type = "number", default = 30, min = 0, max = 600, decimals = 0, name = "Кулдаун" },
        { key = "title", type = "string", default = "", name = "Заголовок", shared = true },
        { key = "enabled_fx", type = "bool", default = true, name = "Эффекты" },
        { key = "tint", type = "color", default = Color(255, 0, 0), name = "Цвет", shared = true },
    },
})
```

Опции появляются в панели конфигурации и сохраняются в `data/slashmoon/config.json`.
Опции с `shared = true` синхронизируются с клиентами; остальные доступны только на сервере
(в них можно хранить секреты).

### Код модуля

Вместо глобальных `hook.Add / timer.Create / net.Receive / concommand.Add` используйте методы модуля.
Тогда при выключении модуля из панели всё снимается, а при включении возвращается:

```lua
-- Written for: SlashMoon. By: VIKA & Ronni
local MODULE = SlashMoon.Modules.Get("example")

MODULE:Hook("PlayerSpawn", "Example.Spawn", function(ply) end)
MODULE:Timer("Example.Tick", 1, 0, function() end)      -- бесконечные таймеры пересоздаются при включении
MODULE:Receive("Example.Net", function(len, ply) end)     -- чужой обработчик возвращается при выключении
MODULE:Command("example_cmd", function(ply, cmd, args) end)
MODULE:SuppressHook("HUDPaint", "GamemodeHook")           -- временно снять чужой хук

MODULE:OnEnabled(function() end)
MODULE:OnDisabled(function() end)                         -- закрыть меню, сбросить состояние

local cooldown = MODULE:GetOption("cooldown")
if MODULE:IsEnabled() then end
```

Если модуль включили на лету, его хуки `Initialize`, `PostGamemodeLoaded` и `InitPostEntity`
вызываются один раз автоматически: модуль «догоняет» уже прошедшую инициализацию.

### API реестра

| Функция | Описание |
| --- | --- |
| `SlashMoon.Modules.Get(id)` | объект модуля |
| `SlashMoon.Modules.IsEnabled(id)` | включен ли модуль |
| `SlashMoon.Modules.SetEnabled(id, bool)` | сервер: включить/выключить и сохранить |
| `SlashMoon.Modules.SetOption(id, key, value)` | сервер: изменить опцию и сохранить |
| `SlashMoon.Modules.GetSorted()` | список модулей |

Консоль сервера: `slashmoon_module` — список модулей, `slashmoon_module <id> <0|1>` — переключить.

## Админ-система

Автоопределение: **SAM** → **ULX/ULib** → стандартные `IsSuperAdmin()/IsAdmin()`.

```lua
-- Регистрация права (в SAM: sam.permissions.add, в ULX: ULib.ucl.registerAccess)
SlashMoon.Admin.RegisterPermission("example_manage", "admin", "Управление примером")

SlashMoon.Admin.HasPermission(ply, "example_manage")  -- консоль сервера всегда true
SlashMoon.Admin.GetRank(ply)                           -- usergroup / ранг SAM
SlashMoon.Admin.GetSystem()                            -- "sam" | "ulx" | "default"
SlashMoon.Admin.GetPlayersWithPermission(name)

-- Клиент: админ-команды через активную систему (pm, goto, bring, return, kick, ban)
SlashMoon.Admin.RunCommand("kick", target, "причина")
```

Мягкие зависимости проверяются без ошибок при их отсутствии:

```lua
SlashMoon.Compat.Has("sam")     -- sam | ulx | sui | echat | elib | cami
SlashMoon.Compat.With("echat", function() ... end)
```

## UI-библиотека

### Тема

Все цвета — в `SlashMoon.UI.Colors` (`SlashMoon.Colors`):
`Accent`, `AccentHover`, `AccentDim`, `AccentText`, `Background`, `Header`, `Surface`, `SurfaceHover`,
`Overlay`, `Text`, `TextMuted`, `TextDisabled`, `Border`, `BorderNeutral`, `Shadow`,
`Success`, `Danger`, `Warning`, `Info`.

```lua
SlashMoon.UI.SetTheme({ Accent = Color(0, 170, 255) })  -- перекрашивает все интерфейсы сразу
SlashMoon.UI.ResetTheme()
```

Акцентный цвет также настраивается из панели конфигурации (модуль «Тема интерфейса»).

### Масштабирование и шрифты

Размеры задаются в пикселях макета 2560×1440:

```lua
SlashMoon.UI.Scale(40)                     -- по высоте экрана
SlashMoon.UI.ScaleW(40)                    -- по ширине
SlashMoon.UI.WindowSize(0.5, 0.7, 1000, 800)
SlashMoon.UI.CreateFont("MyFont", 24, 700) -- шрифт "SlashMoon.MyFont", пересоздается при смене разрешения
```

Базовые шрифты: `SlashMoon.Title`, `Header`, `Subheader`, `Text`, `TextBold`, `Small`, `Tiny`, `Button`.

Стиль по умолчанию — фирменный острый: прямые углы, акцентная полоса 4px слева, тонкая обводка,
которая разгорается при наведении. `Draw.RoundedBox` / `Draw.RoundedOutline` в этом режиме рисуют
обычные прямоугольники. Скругления можно включить: `SlashMoon.UI.Sharp = false` (радиус — `SlashMoon.UI.Radius`).

### Компоненты

Создание: `SlashMoon.UI.Create("Button", parent)` или `vgui.Create("SlashMoon.Button", parent)`.

| Компонент | Назначение |
| --- | --- |
| `Frame` | окно: шапка, неоновая линия сверху, иконка, кнопка закрытия «X», анимация открытия/закрытия, ESC, перетаскивание |
| `Panel` / `Container` | карточка с фоном из палитры / прозрачный контейнер |
| `Label`, `Header`, `Divider` | текст, заголовок секции, разделитель |
| `SettingRow` | строка настройки: название, описание, элемент справа |
| `Button` | фирменная плашка с полосой слева; варианты `primary` / `secondary` / `ghost` / `success` / `danger` (цвет полосы и обводки); состояния Default / Hover / Active / Disabled; иконки |
| `IconButton` | квадратная кнопка с иконкой или символом |
| `Toggle`, `Checkbox` | переключатель и чекбокс |
| `SliderBar`, `Slider` | ползунок и ползунок с подписью (совместим с DNumSlider) |
| `TextEntry`, `ComboBox`, `Binder`, `ColorPicker` | ввод текста, список, выбор клавиши, выбор цвета |
| `Scroll` | скролл-панель со стилизованным скроллбаром и плавной прокруткой |
| `Tabs` | вкладки (горизонтальные или боковые), ленивое построение |
| `Avatar`, `ModelPanel`, `Grid`, `ProgressBar` | аватар Steam / картинка, 3D-модель, сетка карточек, прогресс |
| `RadialMenu` | радиальное меню выбора |

```lua
local frame = SlashMoon.UI.Create("Frame")
frame:SetSize(SlashMoon.UI.Scale(900), SlashMoon.UI.Scale(700))
frame:Center()
frame:SetHeader("НАСТРОЙКИ", "подзаголовок")

local tabs = SlashMoon.UI.Create("Tabs", frame)
tabs:Dock(FILL)
tabs:AddTab("Основные", function(content)
    local row = SlashMoon.UI.Create("SettingRow", content)
    row:Dock(TOP)
    row:SetTitle("Звук")
    row:SetDescription("Включить звуки интерфейса")
    local toggle = row:SetControl(SlashMoon.UI.Create("Toggle"))
    toggle.OnChange = function(_, value) end
end)
```

### Всплывающие окна и меню

```lua
SlashMoon.UI.Popup(title, message, confirmText, onConfirm, cancelText, onCancel)
SlashMoon.UI.InputPopup(title, message, placeholder, confirmText, function(text) end, cancelText)
SlashMoon.UI.DoubleInputPopup(title, message, ph1, ph2, confirmText, function(a, b) end, cancelText)
SlashMoon.UI.ActionMenu(title, { { text = "...", color = Color(...), onClick = fn } })
SlashMoon.UI.ContextMenu()        -- меню у курсора: AddOption, AddSpacer, AddPanel, Open
SlashMoon.UI.Menu()               -- DermaMenu в стиле темы, с подменю
SlashMoon.UI.Toast("Сохранено", "success", 3)   -- info | success | error | warning
```

### Отрисовка

`SlashMoon.UI.Draw` (`SlashMoon.Draw`): `Box`, `RoundedBox`, `Outline`, `RoundedOutline`, `Circle`,
`Blur`, `PanelBlur`, `HUDPanel`, `ProgressBar`, `Text`, `TextShadow`, `Badge`, `Icon`, `Gradient`,
`WrapText`, `Material` (с кэшем).

## Утилиты

```lua
SlashMoon.Log("сообщение")          -- всегда
SlashMoon.Warn("предупреждение")
SlashMoon.Debug("отладка")          -- только при slashmoon_debug 1
SlashMoon.SafeCall(fn, ...)
SlashMoon.Notify(ply, Color(...), "текст")   -- цветное сообщение в чат
SlashMoon.PlaySound(path, fallback)          -- клиент: звук, только если файл существует

SlashMoon.JSON.Encode(tbl, pretty) / Decode(str, fallback) / NetWrite(tbl) / NetRead()
SlashMoon.Data.ReadJSON("file.json") / WriteJSON("file.json", tbl)  -- data/slashmoon/
SlashMoon.Security.CheckRateLimit(ply, "action", seconds)

-- HTTP без захардкоженных адресов
SlashMoon.HTTP.Fetch(url, onSuccess, onFail, headers)
SlashMoon.HTTP.Post(url, params, onSuccess, onFail, headers)
SlashMoon.HTTP.GetJSON(url, onSuccess, onFail)
SlashMoon.HTTP.PostJSON(url, payload, onSuccess, onFail)
SlashMoon.HTTP.Request({ url = ..., method = "PATCH", json = {...}, expectJSON = true, success = fn, failed = fn })

-- Собственный REST-backend (необязательно): data/slashmoon/api.json { "base_url": "...", "key": "..." }
SlashMoon.API.Configure(baseURL, key)
SlashMoon.API.Request("/endpoint", payload, onSuccess, onError)
```

## Хуки

| Хук | Аргументы |
| --- | --- |
| `SlashMoon.Loaded` | — |
| `SlashMoon.ModulesLoaded` | — |
| `SlashMoon.ModuleLoaded` | id, module (для `defer`-модулей) |
| `SlashMoon.ModuleEnabled` / `SlashMoon.ModuleDisabled` | id, module |
| `SlashMoon.ModulesSynced` | — (клиент получил состояние модулей) |
| `SlashMoon.OptionChanged` | id, key, value (сервер) |
| `SlashMoon.ConfigSaved` / `SlashMoon.ConfigChanged` | — / ply, changes |
| `SlashMoon.UI.ThemeChanged` | colors |
| `SlashMoon.UI.ScaleChanged` | multiplier |
| `SlashMoon.UI.InterceptEscape` | вернуть `true`, чтобы поглотить ESC |
| `SlashMoon.UI.ShouldPlaySound` | kind; вернуть `false`, чтобы заглушить звук |
| `SlashMoon.API.Ready` | — |

#!/usr/bin/env python3
# ============================================================
# SlashMoon: сборка отдельного аддона-библиотеки slashmoon_lib
#
# Библиотека живет внутри аддона slashmoon_core (единый исходник).
# Скрипт копирует только файлы библиотеки — без модулей режима —
# в dist/slashmoon_lib, готовый к установке в garrysmod/addons/
# или к публикации в Workshop отдельным аддоном.
#
# Пути файлов совпадают с slashmoon_core, поэтому оба аддона можно
# ставить одновременно: GMod загрузит библиотеку один раз.
#
# Использование: python3 tools/build_lib.py [папка_вывода]
# ============================================================
import json
import os
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CORE = os.path.join(ROOT, "addons", "slashmoon_core")
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "dist", "slashmoon_lib")

# Что входит в библиотеку (пути относительно аддона)
LIBRARY = [
    "lua/autorun/slashmoon_lib_init.lua",
    "lua/slashmoon/sh_loader.lua",
    "lua/slashmoon/core",
    "lua/slashmoon/ui",
    "lua/slashmoon/admin",
    "resource/fonts",
]

ADDON_JSON = {
    "title": "SlashMoon Lib",
    "type": "tool",
    "tags": ["build", "fun"],
    "description": "Developer library for Garry's Mod: UI framework, SAM/ULX admin layer, "
                   "module registry with toggles, JSON config and HTTP helpers.",
    "ignore": ["*.md", "*.txt"],
}


def main():
    if os.path.exists(OUT):
        shutil.rmtree(OUT)

    for rel in LIBRARY:
        src = os.path.join(CORE, rel)
        dst = os.path.join(OUT, rel)
        if os.path.isdir(src):
            shutil.copytree(src, dst)
        else:
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copy2(src, dst)

    # Папка модулей пустая: сюда разработчики добавляют свои модули
    os.makedirs(os.path.join(OUT, "lua", "slashmoon", "modules"), exist_ok=True)

    with open(os.path.join(OUT, "addon.json"), "w", encoding="utf-8") as fh:
        json.dump(ADDON_JSON, fh, ensure_ascii=False, indent=4)

    docs = os.path.join(ROOT, "docs", "LIBRARY.md")
    if os.path.exists(docs):
        shutil.copy2(docs, os.path.join(OUT, "README.md"))

    count = sum(len(files) for _, _, files in os.walk(OUT))
    print("slashmoon_lib собрана: %s (%d файлов)" % (OUT, count))


if __name__ == "__main__":
    main()

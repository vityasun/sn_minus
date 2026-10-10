#!/usr/bin/env python3
# ============================================================
# SlashMoon: сборка отдельного аддона-библиотеки slashmoon_lib
#
# Исходник библиотеки — внутри аддона slashmoon_core. Скрипт копирует
# только файлы библиотеки (без модулей режима) в addons/slashmoon_lib —
# отдельный аддон для разработчиков, который лежит в репозитории.
# Руками addons/slashmoon_lib не правится: правки делаются в slashmoon_core,
# затем запускается этот скрипт.
#
# Пути файлов совпадают с slashmoon_core, поэтому оба аддона можно
# ставить одновременно: GMod загрузит библиотеку один раз.
#
# Использование:
#   python3 tools/build_lib.py            пересобрать addons/slashmoon_lib
#   python3 tools/build_lib.py <папка>    собрать в другую папку
#   python3 tools/build_lib.py --check    проверить, что addons/slashmoon_lib актуальна
# ============================================================
import filecmp
import json
import os
import shutil
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CORE = os.path.join(ROOT, "addons", "slashmoon_core")
DEFAULT_OUT = os.path.join(ROOT, "addons", "slashmoon_lib")

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


# Файлы из корня репозитория, которые кладутся рядом с библиотекой
EXTRA = {
    "LICENSE": "LICENSE",
    "licenses/Montserrat-OFL.txt": "licenses/Montserrat-OFL.txt",
    "docs/LIBRARY.md": "README.md",
}


def build(out):
    if os.path.exists(out):
        shutil.rmtree(out)

    for rel in LIBRARY:
        src = os.path.join(CORE, rel)
        dst = os.path.join(out, rel)
        if os.path.isdir(src):
            shutil.copytree(src, dst)
        else:
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copy2(src, dst)

    # Папка модулей пустая: сюда разработчики добавляют свои модули
    # (.gitkeep — чтобы git сохранил пустую папку)
    modules = os.path.join(out, "lua", "slashmoon", "modules")
    os.makedirs(modules, exist_ok=True)
    open(os.path.join(modules, ".gitkeep"), "w").close()

    with open(os.path.join(out, "addon.json"), "w", encoding="utf-8") as fh:
        json.dump(ADDON_JSON, fh, ensure_ascii=False, indent=4)
        fh.write("\n")

    for src_rel, dst_rel in EXTRA.items():
        dst = os.path.join(out, dst_rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(os.path.join(ROOT, src_rel), dst)


def diff_trees(a, b, rel=""):
    """Список путей, которые отличаются между папками a и b."""
    cmp = filecmp.dircmp(a, b)
    out = [os.path.join(rel, n) for n in cmp.left_only + cmp.right_only + cmp.funny_files]
    _, mismatch, errors = filecmp.cmpfiles(a, b, cmp.common_files, shallow=False)
    out += [os.path.join(rel, n) for n in mismatch + errors]
    for sub in cmp.common_dirs:
        out += diff_trees(os.path.join(a, sub), os.path.join(b, sub), os.path.join(rel, sub))
    return out


def main():
    args = sys.argv[1:]

    if args[:1] == ["--check"]:
        with tempfile.TemporaryDirectory() as tmp:
            fresh = os.path.join(tmp, "slashmoon_lib")
            build(fresh)
            if not os.path.isdir(DEFAULT_OUT):
                print("addons/slashmoon_lib отсутствует: запустите python3 tools/build_lib.py")
                return 1
            changed = diff_trees(fresh, DEFAULT_OUT)
        if changed:
            print("addons/slashmoon_lib устарела (запустите python3 tools/build_lib.py):")
            for path in sorted(changed):
                print("  " + path)
            return 1
        print("addons/slashmoon_lib актуальна")
        return 0

    out = args[0] if args else DEFAULT_OUT
    build(out)
    count = sum(len(files) for _, _, files in os.walk(out))
    print("slashmoon_lib собрана: %s (%d файлов)" % (out, count))
    return 0


if __name__ == "__main__":
    sys.exit(main())

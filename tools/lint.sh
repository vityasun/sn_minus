#!/usr/bin/env bash
# ============================================================
# SlashMoon: проверка Lua-кода аддона
#   - синтаксис (GLua конвертируется в Lua 5.1 через tools/glua2lua.py)
#   - запись в глобальные переменные (загрязнение неймспейса)
#   - обращения к неизвестным глобалам (опечатки)
#   - копирайт в первой строке каждого файла
#   - addons/slashmoon_lib совпадает с библиотекой внутри slashmoon_core
# Требования: python3, luacheck (luarocks install luacheck)
# Использование: tools/lint.sh [папка lua] (по умолчанию addons/slashmoon_core/lua)
# ============================================================
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${1:-$ROOT/addons/slashmoon_core/lua}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

HEADER="-- Written for: SlashMoon. By: VIKA & Ronni"
STATUS=0

echo "== Копирайт"
while IFS= read -r -d '' f; do
    if [ "$(head -1 "$f")" != "$HEADER" ]; then
        echo "нет копирайта: $f"
        STATUS=1
    fi
done < <(find "$SRC" -name '*.lua' -print0)

python3 -I "$ROOT/tools/glua2lua.py" "$SRC" "$TMP/conv"
(cd "$TMP/conv" && luacheck . --std lua51 --codes --no-color --formatter plain --no-max-line-length -qq > "$TMP/out.txt" 2>&1) || true

# Глобалы гейммода Fazbear's Hunt и сторонних библиотек, которые аддон намеренно использует
ALLOWED_SETS="ENT|SWEP|EFFECT|SlashMoon|net|fh|isGameOn|roundActive|roundEnding|currentAbilities|survivors|TEAM_SURVIVOR|TEAM_PILLS|language|highlight|StartBleeding|StopBleeding|EmitSound|StopSound|Effect|Get|Set|Process"

echo "== Синтаксические ошибки"
if grep -E '\(E[0-9]+\)' "$TMP/out.txt"; then STATUS=1; fi

echo "== Запись в глобальные переменные"
if grep -E '\(W11[12]\)' "$TMP/out.txt" | grep -vE "variable '($ALLOWED_SETS)'"; then STATUS=1; fi

echo "== Неизвестные глобалы"
UNKNOWN="$(grep -E '\(W113\)' "$TMP/out.txt" | sed -E "s/.*variable '(.*)'/\1/" | sort -u | grep -vxFf "$ROOT/tools/gmod_globals.txt" || true)"
if [ -n "$UNKNOWN" ]; then echo "$UNKNOWN"; STATUS=1; fi

echo "== Отдельная библиотека (addons/slashmoon_lib)"
if [ -z "${1:-}" ]; then
    python3 -I "$ROOT/tools/build_lib.py" --check || STATUS=1
fi

[ $STATUS -eq 0 ] && echo "OK"
exit $STATUS

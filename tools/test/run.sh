#!/usr/bin/env bash
# Smoke-тесты сборки в эмуляции GMod. Нужны LuaJIT (luajit в PATH или LUAJIT=...) и libsqlite3.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LUAJIT="${LUAJIT:-luajit}"
status=0
# Синтаксис всех Lua-файлов сборки (ULX/ULib — сторонние, используют расширения GLua).
export LIST="${TMPDIR:-/tmp}/stalker_lua_files.txt"
find "$ROOT" -path "$ROOT/ulx" -prune -o -path "$ROOT/ulib" -prune -o -path "$ROOT/tools" -prune -o -name '*.lua' -print > "$LIST"
"$LUAJIT" -e '
local bad,n=0,0
for path in io.lines(os.getenv("LIST")) do n=n+1;local f,err=loadfile(path);if not f then print("SYNTAX "..err);bad=bad+1 end end
print(("syntax: %d файлов, ошибок %d"):format(n,bad));os.exit(bad==0 and 0 or 1)' || status=1
for realm in server client; do
  DATA_DIR="$(mktemp -d)"
  GMOD_REALM=$realm GMOD_ROOT="$ROOT" GMOD_DATA="$DATA_DIR" "$LUAJIT" "$ROOT/tools/test/run_tests.lua" || status=1
  rm -rf "$DATA_DIR"
done
exit $status

#!/bin/sh
# Erzeugt src/workspace/Haus.rbxmx aus HouseModel.lua.
# Benötigt die Luau-CLI (https://github.com/luau-lang/luau/releases), z. B.: LUAU=/pfad/zu/luau ./build.sh
set -e
cd "$(dirname "$0")"
LUAU="${LUAU:-luau}"
tmp="$(mktemp "${TMPDIR:-/tmp}/house-XXXXXX.luau")"
trap 'rm -f "$tmp"' EXIT
{
	cat RobloxMock.luau
	echo 'local HouseModel = (function()'
	cat HouseModel.lua
	echo 'end)()'
	cat export.luau
} > "$tmp"
"$LUAU" "$tmp" > ../../src/workspace/Haus.rbxmx
echo "src/workspace/Haus.rbxmx geschrieben"

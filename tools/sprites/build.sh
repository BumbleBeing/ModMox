#!/usr/bin/env bash
# Builds pixel icons from a text grid with Aseprite, and a contact sheet to review them.
#
#   ASEPRITE=~/Projects/aseprite/build/bin/aseprite tools/sprites/build.sh
#   ... tools/sprites/build.sh --force=flying,reach    redraw those from the grid
#   ... tools/sprites/build.sh --force                 redraw every icon from the grid
#   ... tools/sprites/build.sh GRID_FILE OUT_FOLDER    another icon set
#
# An existing .aseprite file is kept (and its PNG exported again) unless forced, so icons
# touched up by hand are safe. The sheet lands in tools/sprites/preview/. New sprites get
# the shared palette, tools/sprites/modmox.gpl.
set -euo pipefail
cd "$(dirname "$0")/../.."
: "${ASEPRITE:?Set ASEPRITE to the Aseprite binary}"

force=""
paths=()
for arg in "$@"; do
	case "$arg" in
		--force) force="all" ;;
		--force=*) force="${arg#--force=}" ;;
		*) paths+=("$arg") ;;
	esac
done
grid="${paths[0]:-tools/sprites/keyword_icons.txt}"
out="${paths[1]:-ui/sprites/keywords}"
preview="tools/sprites/preview/$(basename "${grid%.*}").png"

output="$("$ASEPRITE" -b \
	--script-param grid="$(realpath "$grid")" \
	--script-param out="$(realpath -m "$out")" \
	--script-param preview="$(realpath -m "$preview")" \
	--script-param palette="$(realpath tools/sprites/modmox.gpl)" \
	--script-param force="$force" \
	--script tools/sprites/build_sprites.lua 2>&1)" || true
echo "$output"
grep -q "^OK: " <<<"$output"

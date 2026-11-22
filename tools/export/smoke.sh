#!/usr/bin/env bash
# Runs the exported Linux build (milestone 20) and saves a picture of each screen the dry run
# checks into build/smoke/: an encounter (Portraits, the player panels), the deckbuilder
# (card faces with their art), the Stage Map (Map Backdrop, Scenery), the Credits and Art
# Attribution (the art manifests). Each run's output is searched for errors, the build must
# hold each file the game reads that is not a resource (no picture shows credits.txt: the
# roll starts below the screen), and the game's own log must be in its ModMox user
# directory. Needs a display.
#
#   tools/export/smoke.sh
set -euo pipefail
cd "$(dirname "$0")/../.."
game="$PWD/build/linux/ModMox.x86_64"
if [[ ! -x "$game" ]]; then
	echo "No Linux build: run tools/export/export.sh first." >&2
	exit 1
fi
out="$PWD/build/smoke"
log="${XDG_DATA_HOME:-$HOME/.local/share}/ModMox/logs/godot.log"
rm -rf "$out"
mkdir -p "$out"
failed=0

# Runs the game with the flags after [name] and saves its picture as build/smoke/[name].png.
shot() {
	local name=$1
	shift
	timeout 120 "$game" -- "$@" --screenshot="$out/$name.png" > "$out/$name.out" 2>&1 || true
	if [[ -s "$out/$name.png" ]]; then
		echo "Saved $name.png"
	else
		echo "No picture of $name: see build/smoke/$name.out" >&2
		failed=1
	fi
	if grep -nE 'SCRIPT ERROR|^ERROR|Parse Error' "$out/$name.out" > "$out/$name.errors"; then
		echo "Errors in $name:" >&2
		cat "$out/$name.errors" >&2
		failed=1
	else
		rm -f "$out/$name.errors"
	fi
}

shot encounter --hero=red_green --villain=white_black --seed=7
shot deckbuilder --deckbuilder
shot stage_map --stage-map --run-seed=7 --stage=white
shot credits --credits
shot art_attribution --credits --page=art
# The files test_export.gd's KNOWN_READS names: the pck's index holds each path it carries.
for read in content/credits/credits.txt content/art/art.json content/art/emblems/art.json \
		ui/sprites/portraits/art.json ui/sprites/portraits/breath.json; do
	if ! grep -qaF "$read" "$game"; then
		echo "The build does not carry $read" >&2
		failed=1
	fi
done
if [[ -f "$log" ]]; then
	echo "The game's log is at $log"
else
	echo "No log at $log" >&2
	failed=1
fi
exit $failed

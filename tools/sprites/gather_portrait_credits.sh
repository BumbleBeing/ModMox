#!/usr/bin/env bash
# Gathers the credit line in each Portrait grid's header into ui/sprites/portraits/art.json,
# which the Credits' Art Attribution page reads (milestone 19). A grid drawn after a Magic
# card's art says so in a line such as
#
#   ; Drawn after the art of Adorned Pouncer: Hour of Devastation (hou) #2, by Slawomir Maniak.
#
# and becomes, under the grid's file name,
#
#   "adorned_pouncer": {"card": "Adorned Pouncer", "set": "hou", "collector_number": "2", "artist": "Slawomir Maniak"}
#
# The card's name ends at the line's first colon, since a set's name may hold one ("Ikoria:
# Lair of Behemoths"). A grid with no such line, such as the placeholders, is left out.
# tools/sprites/build.sh runs this after every build; it can also be run on its own.
set -euo pipefail
cd "$(dirname "$0")/../.."

out="ui/sprites/portraits/art.json"
escape() { sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' <<<"$1"; }

entries=()
for grid in tools/sprites/portraits/*.txt; do
	line="$(sed -nE 's/^; Drawn after the art of ([^:]+): .+ \(([A-Za-z0-9]+)\) #([^,]+), by (.+)\.[[:space:]]*$/\1\t\2\t\3\t\4/p' "$grid" | head -n 1)"
	[[ -z "$line" ]] && continue
	IFS=$'\t' read -r card card_set number artist <<<"$line"
	key="$(basename "${grid%.txt}")"
	entries+=("$(printf '\t"%s": {"card": "%s", "set": "%s", "collector_number": "%s", "artist": "%s"}' \
		"$key" "$(escape "$card")" "$(escape "$card_set")" "$(escape "$number")" "$(escape "$artist")")")
done

{
	echo "{"
	for index in "${!entries[@]}"; do
		if (( index < ${#entries[@]} - 1 )); then
			echo "${entries[$index]},"
		else
			echo "${entries[$index]}"
		fi
	done
	echo "}"
} >"$out"
echo "Gathered ${#entries[@]} Portrait credits into $out"

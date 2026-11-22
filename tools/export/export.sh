#!/usr/bin/env bash
# Exports the playtest builds (milestone 20): build/linux/ModMox.x86_64 and
# build/windows/ModMox.exe, each a release build with its pck embedded and LICENSES.txt
# beside it. Card and token art is gitignored, so it refuses to export until every card and
# token has its art: run tools/art/fetch_art.gd first.
#
#   GODOT=~/Desktop/Godot_v4.7.2-stable_linux.x86_64 tools/export/export.sh
#   tools/export/export.sh --linux-only    the Linux build alone
set -euo pipefail
cd "$(dirname "$0")/../.."
: "${GODOT:?Set GODOT to the Godot 4.7.2 binary.}"

platforms=(linux windows)
for arg in "$@"; do
	case "$arg" in
		--linux-only) platforms=(linux) ;;
		*) echo "Unknown option: $arg" >&2; exit 2 ;;
	esac
done

missing=()
for card in content/cards/*/*.tres; do
	[[ -f "content/art/$(basename "$card" .tres).jpg" ]] || missing+=("$card")
done
for token in content/tokens/*.tres; do
	[[ -f "content/art/tokens/$(basename "$token" .tres).jpg" ]] || missing+=("$token")
done
if (( ${#missing[@]} > 0 )); then
	echo "No art for:" >&2
	printf '  %s\n' "${missing[@]}" >&2
	echo "Run: \$GODOT --headless --path . -s res://tools/art/fetch_art.gd" >&2
	exit 1
fi

engine=$("$GODOT" --version | grep -oE '^[0-9]+(\.[0-9]+)+\.[a-z0-9]+')
templates="$HOME/.local/share/godot/export_templates/$engine"
for platform in "${platforms[@]}"; do
	case "$platform" in
		linux) template=linux_release.x86_64 ;;
		windows) template=windows_release_x86_64.exe ;;
	esac
	if [[ ! -f "$templates/$template" ]]; then
		echo "No $template in $templates: install the export templates from the editor" >&2
		echo "(Editor > Manage Export Templates > Download and Install)." >&2
		exit 1
	fi
done

rm -rf build/linux build/windows
mkdir -p build
# So that Godot never imports a build, or carries one into the next.
touch build/.gdignore
"$GODOT" --headless --path . --import
for platform in "${platforms[@]}"; do
	case "$platform" in
		linux) preset="Linux"; file=ModMox.x86_64 ;;
		windows) preset="Windows Desktop"; file=ModMox.exe ;;
	esac
	mkdir -p "build/$platform"
	"$GODOT" --headless --path . --export-release "$preset" "$PWD/build/$platform/$file"
	if [[ ! -s "build/$platform/$file" ]]; then
		echo "The $preset export made nothing." >&2
		exit 1
	fi
	"$GODOT" --headless --path . -s res://tools/export/licenses.gd -- "$PWD/build/$platform/LICENSES.txt"
done
echo "Exported $(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot) for ${platforms[*]}."

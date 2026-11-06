#!/usr/bin/env bash
# Runs the rules engine test suite headless.
#
# Usage: tools/test.sh [extra GUT options, e.g. -gselect=test_static_typing]
# Set GODOT to the Godot 4.7.2 executable if it is not on PATH as "godot".
set -euo pipefail

GODOT="${GODOT:-godot}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v "$GODOT" >/dev/null 2>&1; then
	echo "Godot not found. Set GODOT=/path/to/Godot_v4.7.2-stable_linux.x86_64" >&2
	exit 127
fi

# Refresh the import cache and global class registry so new class_names resolve.
"$GODOT" --headless --path "$PROJECT_DIR" --import >/dev/null 2>&1 || true

exec "$GODOT" --headless --path "$PROJECT_DIR" -s res://addons/gut/gut_cmdln.gd "$@"

#!/usr/bin/env bash
# Runs a command inside hard limits, so a runaway test or a hung Godot can never take the
# machine down with it: everything it starts shares one memory cap and one CPU cap, and is
# killed together when the cap, the time limit or the command's end is reached.
#
# Usage:
#   tools/guarded.sh tools/test.sh --jobs=4       the whole suite, limited
#   tools/guarded.sh godot --headless ...         any one command
#
# Limits, each overridable in the environment:
#   GUARD_MEM=6G       memory for the command and all its children together (no swap)
#   GUARD_CPU=600%     CPU: 100% is one core
#   GUARD_SECONDS=600  wall time, after which everything is killed
#
# It refuses to start while another test run is going, since two at once is what fills
# the memory.
set -euo pipefail

if pgrep -f 'addons/gut/gut_cmdln\.gd' >/dev/null 2>&1; then
	echo "A test run is already going (see: pgrep -af gut_cmdln). Wait for it, or stop it first." >&2
	exit 75
fi

exec systemd-run --user --scope --quiet --collect \
	-p MemoryMax="${GUARD_MEM:-6G}" -p MemorySwapMax=0 \
	-p CPUQuota="${GUARD_CPU:-600%}" \
	-p RuntimeMaxSec="${GUARD_SECONDS:-600}" \
	-- nice -n 10 "$@"

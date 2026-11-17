#!/usr/bin/env bash
# Fails when a test run's output shows that Godot never freed something by the time it
# quit (conventions, "The run ends clean"), and prints what Godot said.
#
# Usage: tools/leak_check.sh <file holding the run's output>
set -euo pipefail

# What Godot prints at exit for leaked objects, resources, RIDs and Variant pool pages.
LEAKS='^(WARNING|ERROR): ([0-9]+ ObjectDB instances were leaked at exit|[0-9]+ resources still in use at exit|[0-9]+ RID allocations of type .* were leaked at exit|Pages in use exist at exit)'

if found="$(grep -aE "$LEAKS" "$1")"; then
	echo "The test run leaked. Godot said at exit:"
	echo "$found"
	echo 'See "The run ends clean" in addons/modmox_rules/docs/conventions.md for how to find the cause.'
	exit 1
fi

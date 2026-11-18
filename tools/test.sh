#!/usr/bin/env bash
# Runs the test suite headless.
#
# Usage:
#   tools/test.sh                 the whole suite, split across parallel Godot processes
#   tools/test.sh --quick         only the tests near what git says changed, in parallel
#   tools/test.sh --jobs=N        set how many processes (default: half the cores, at most 8)
#   tools/test.sh --serial        the whole suite in one process, as it always ran
#   tools/test.sh -gselect=x ...  any GUT options: passed through to one process, as before
#
# Set GODOT to the Godot 4.7.2 executable if it is not on PATH as "godot".
#
# A parallel run deals the test files out by how long each took last time (kept in
# .godot/test_times.tsv), so the processes finish together. Each process has its own user://
# (in .godot/test_shards/), since tests write settings, key bindings and the frame cache there.
set -euo pipefail

GODOT="${GODOT:-godot}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TIMES_FILE="$PROJECT_DIR/.godot/test_times.tsv"
SHARD_HOME="$PROJECT_DIR/.godot/test_shards"
# The suite's folders, as .gutconfig.json lists them.
SUITE_DIRS=(addons/modmox_rules/tests addons/modmox_ai/tests tests)

if ! command -v "$GODOT" >/dev/null 2>&1; then
	echo "Godot not found. Set GODOT=/path/to/Godot_v4.7.2-stable_linux.x86_64" >&2
	exit 127
fi

mode=parallel
jobs=""
gut_args=()
for arg in "$@"; do
	case "$arg" in
		--quick) mode=quick ;;
		--serial) mode=serial ;;
		--jobs=*) jobs="${arg#--jobs=}" ;;
		*) gut_args+=("$arg") ;;
	esac
done
# GUT options choose their own tests, so they run in one process as they always did.
if [ "${#gut_args[@]}" -gt 0 ]; then
	if [ "$mode" = quick ]; then
		echo "--quick picks its own tests; it cannot be used with GUT options." >&2
		exit 2
	fi
	mode=serial
fi

# Refresh the import cache and global class registry so new class_names resolve.
"$GODOT" --headless --path "$PROJECT_DIR" --import >/dev/null 2>&1 || true

# Bake every card Frame afresh, so the suite tests the baking and not Frames kept on disk.
export MODMOX_FRAME_CACHE=off

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if [ "$mode" = serial ]; then
	# A run that leaks fails, even when every test passed (conventions, "The run ends clean").
	status=0
	"$GODOT" --headless --path "$PROJECT_DIR" -s res://addons/gut/gut_cmdln.gd "${gut_args[@]}" 2>&1 | tee "$WORK/out" || status=$?
	"$PROJECT_DIR/tools/leak_check.sh" "$WORK/out" || status=1
	exit "$status"
fi

cd "$PROJECT_DIR"

# Every test file in the given folders (or the files themselves), as res:// paths.
test_files_in() {
	local path
	for path in "$@"; do
		if [ -f "$path" ]; then
			echo "res://$path"
		elif [ -d "$path" ]; then
			find "$path" -name 'test_*.gd' -type f | sed 's|^|res://|'
		fi
	done
}

# The test folders or files a changed path is tested by, for --quick.
tests_for_change() {
	local path="$1"
	case "$path" in
		*.md | *.uid | *.import | docs/* | */docs/* | .claude/*) return ;;
	esac
	# A test file runs itself; a helper beside tests runs that folder.
	case "$path" in
		tests/* | addons/modmox_rules/tests/* | addons/modmox_ai/tests/*)
			case "$(basename "$path")" in
				test_*.gd) echo "$path" ;;
				*) dirname "$path" ;;
			esac
			return
			;;
	esac
	case "$path" in
		# The AI plays through the engine, so an engine change runs the AI's tests too.
		addons/modmox_rules/*) echo addons/modmox_rules/tests; echo addons/modmox_ai/tests ;;
		addons/modmox_ai/*) echo addons/modmox_ai/tests ;;
		ui/*/*)
			local area="${path#ui/}"
			area="${area%%/*}"
			if [ -d "tests/ui/$area" ]; then echo "tests/ui/$area"; else echo tests/ui; fi
			;;
		ui/*) echo tests/ui ;;
		content/*) echo tests/content ;;
		run/*) echo tests/run ;;
		tools/*) echo tests/tools ;;
	esac
}

if [ "$mode" = quick ]; then
	changed="$(git status --porcelain --untracked-files=all | sed -E 's/^.. //; s/.* -> //')"
	targets="$(while IFS= read -r path; do [ -n "$path" ] && tests_for_change "$path"; done <<<"$changed" | sort -u)"
	if [ -z "$targets" ]; then
		echo "Nothing git shows as changed has tests near it. Run tools/test.sh for the whole suite."
		exit 0
	fi
	# The conventions' checks (static typing, naming) are quick and hold over every file.
	targets="$targets"$'\n'"addons/modmox_rules/tests/conventions"
	echo "Quick run over:"
	sed 's/^/  /' <<<"$targets"
	mapfile -t target_list <<<"$targets"
	test_files_in "${target_list[@]}" | sort -u >"$WORK/files"
else
	test_files_in "${SUITE_DIRS[@]}" | sort -u >"$WORK/files"
fi

file_count="$(wc -l <"$WORK/files")"
if [ "$file_count" -eq 0 ]; then
	echo "No test files found." >&2
	exit 1
fi

if [ -z "$jobs" ]; then
	jobs=$(($(nproc) / 2))
	[ "$jobs" -gt 8 ] && jobs=8
fi
[ "$jobs" -lt 1 ] && jobs=1
[ "$jobs" -gt "$file_count" ] && jobs="$file_count"

# Deal the files out, longest first, each to the process with the least time so far. A file
# not timed yet counts as two seconds.
touch "$TIMES_FILE"
awk -F'\t' -v jobs="$jobs" -v work="$WORK" '
	FNR == NR { time[$1] = $2; next }
	{ t = ($0 in time) ? time[$0] : 2.0; print t "\t" $0 }
' "$TIMES_FILE" "$WORK/files" | sort -t$'\t' -k1,1gr | awk -F'\t' -v jobs="$jobs" -v work="$WORK" '
	BEGIN { for (i = 0; i < jobs; i++) load[i] = 0 }
	{
		best = 0
		for (i = 1; i < jobs; i++) if (load[i] < load[best]) best = i
		load[best] += $1
		print $2 > (work "/shard_" best ".list")
	}
'

shards=()
for list in "$WORK"/shard_*.list; do
	shards+=("$(basename "$list" .list)")
done

echo "Running $file_count test files in ${#shards[@]} processes..."
start=$SECONDS
for shard in "${shards[@]}"; do
	(
		n="${shard#shard_}"
		mkdir -p "$SHARD_HOME/$n"
		code=0
		XDG_DATA_HOME="$SHARD_HOME/$n" "$GODOT" --headless --path "$PROJECT_DIR" \
			-s res://addons/gut/gut_cmdln.gd -gconfig= -gexit -glog=1 \
			-gtest="$(paste -sd, "$WORK/$shard.list")" \
			-gjunit_xml_file="$WORK/$shard.xml" >"$WORK/$shard.log" 2>&1 || code=$?
		echo "$code" >"$WORK/$shard.status"
		# GUT prints no "Failing Tests" line when none failed.
		failing="$(grep -aE '^Failing Tests' "$WORK/$shard.log" | grep -oE '[0-9]+' || echo 0)"
		echo "  process $((n + 1)) of ${#shards[@]} done after $((SECONDS - start)) s ($failing failing)"
	) &
done
wait

# Each process's full output, in turn.
status=0
for shard in "${shards[@]}"; do
	echo
	echo "=============== process $((${shard#shard_} + 1)) of ${#shards[@]} ==============="
	cat "$WORK/$shard.log"
	[ "$(cat "$WORK/$shard.status" 2>/dev/null || echo 1)" = 0 ] || status=1
	# A run that leaks fails, even when every test passed (conventions, "The run ends clean").
	"$PROJECT_DIR/tools/leak_check.sh" "$WORK/$shard.log" || status=1
done

# Keep how long each file took, for dealing the next run out.
for xml in "$WORK"/shard_*.xml; do
	[ -f "$xml" ] || continue
	grep -oE '<testsuite name="[^"]*"[^>]*time="[0-9.]+"' "$xml" |
		sed -E 's/<testsuite name="([^"]*)".*time="([0-9.]+)"/res:\/\/\1\t\2/'
done >"$WORK/new_times"
awk -F'\t' 'FNR == NR { t[$1] = $2; next } !($1 in t) { print } END { for (k in t) print k "\t" t[k] }' \
	"$WORK/new_times" "$TIMES_FILE" | sort >"$WORK/times" && mv "$WORK/times" "$TIMES_FILE"

# One summary for the whole run.
sum() { cat "$WORK"/shard_*.log | grep -aE "^$1 " | grep -oE '[0-9]+' | awk '{ s += $1 } END { print s + 0 }'; }
echo
echo "=============== all ${#shards[@]} processes ==============="
echo "Scripts        $(sum Scripts)"
echo "Tests          $(sum Tests)"
echo "Passing Tests  $(sum 'Passing Tests')"
echo "Failing Tests  $(sum 'Failing Tests')"
echo "Wall time      $((SECONDS - start)) s"
failed_scripts="$(cat "$WORK"/shard_*.xml 2>/dev/null | grep -oE '<testsuite name="[^"]*"[^>]*failures="[1-9][0-9]*"' |
	sed -E 's/<testsuite name="([^"]*)".*/res:\/\/\1/' | sort -u || true)"
if [ -n "$failed_scripts" ]; then
	echo "Scripts with failing tests:"
	sed 's/^/  /' <<<"$failed_scripts"
fi
for shard in "${shards[@]}"; do
	if ! grep -aqE '^Tests ' "$WORK/$shard.log"; then
		echo "Process $((${shard#shard_} + 1)) did not finish its run; see its output above."
		status=1
	fi
done
if [ "$mode" = quick ]; then
	echo "This was a quick run. Run tools/test.sh for the whole suite before committing."
fi
exit "$status"

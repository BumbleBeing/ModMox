#!/usr/bin/env bash
# Pushes the exported playtest builds to the itch.io project with butler (milestone 20): the
# Linux build to its linux channel and the Windows build to its windows channel, each named
# by the project's version, then tags the commit demo-<version> in git (ADR 0074), locally
# only. It refuses a working tree with changes or a build older than the last commit, so the
# tag names what was built, and a version already tagged.
#
#   ITCH_TARGET=user/game tools/export/push.sh
#   tools/export/push.sh --linux-only    the Linux build alone
set -euo pipefail
cd "$(dirname "$0")/../.."
: "${ITCH_TARGET:?Set ITCH_TARGET to the itch.io project, as user/game.}"

platforms=(linux windows)
for arg in "$@"; do
	case "$arg" in
		--linux-only) platforms=(linux) ;;
		*) echo "Unknown option: $arg" >&2; exit 2 ;;
	esac
done

if ! command -v butler > /dev/null; then
	echo "No butler on PATH: install it and run butler login." >&2
	exit 1
fi
version=$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)
if [[ -z "$version" ]]; then
	echo "No application/config/version in project.godot." >&2
	exit 1
fi
tag="demo-$version"
if [[ -n "$(git status --porcelain)" ]]; then
	echo "The working tree has changes: commit them first, so $tag names what was built." >&2
	exit 1
fi
if git rev-parse -q --verify "refs/tags/$tag" > /dev/null; then
	echo "$tag is already tagged: bump application/config/version and export again." >&2
	exit 1
fi
committed=$(git log -1 --format=%ct)
for platform in "${platforms[@]}"; do
	built=$(find "build/$platform" -maxdepth 1 -name 'ModMox.*' -printf '%T@\n' 2> /dev/null | head -1)
	if [[ -z "$built" ]] || (( ${built%.*} < committed )); then
		echo "build/$platform is missing or older than the last commit: run tools/export/export.sh." >&2
		exit 1
	fi
done

for platform in "${platforms[@]}"; do
	butler push "build/$platform" "$ITCH_TARGET:$platform" --userversion "$version"
done
git tag "$tag"
echo "Pushed $version for ${platforms[*]} and tagged $tag (the tag is not pushed to GitHub)."

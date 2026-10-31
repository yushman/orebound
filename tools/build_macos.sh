#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
command -v godot >/dev/null || { echo "godot not found on PATH" >&2; exit 1; }

version=$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)
commit=$(git rev-parse --short HEAD)
[ -z "$(git status --porcelain)" ] || commit="$commit-dirty"

printf '{"commit": "%s"}\n' "$commit" > build_info.json
rm -rf build
mkdir -p build
godot --headless --import
godot --headless --export-release "macOS" build/Orebound.app

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
cp -R build/Orebound.app "$stage/"
cp tools/tester/README-macOS.md "$stage/"
archive="build/orebound-macos-$version-$commit.zip"
ditto -c -k --norsrc "$stage" "$archive"
echo "$archive"

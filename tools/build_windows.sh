#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
command -v godot >/dev/null || { echo "godot not found on PATH" >&2; exit 1; }

version=$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)
commit=$(git rev-parse --short HEAD)
[ -z "$(git status --porcelain)" ] || commit="$commit-dirty"

printf '{"commit": "%s"}\n' "$commit" > build_info.json
rm -rf build/windows
mkdir -p build/windows
godot --headless --import
godot --headless --export-release "Windows Desktop" build/windows/Orebound.exe

archive="build/orebound-windows-$version-$commit.zip"
rm -f "$archive"
zip -j "$archive" build/windows/Orebound.exe tools/tester/README-Windows.md
echo "$archive"

#!/usr/bin/env bash
# Build the signed Android release APK.
#
# Godot 4.7's CLI exporter reads release-signing credentials from the
# GODOT_ANDROID_KEYSTORE_RELEASE_* environment variables rather than from
# export_presets.cfg, so this script exports them from the local keystore notes.
# No secret is stored in this file or anywhere tracked by git.
#
# Usage: tools/build_android_release.sh [output.apk]
set -euo pipefail
cd "$(dirname "$0")/.."

INFO="keystore/READ-ME-RELEASE-SIGNING.txt"
KEYSTORE="keystore/toxicwasteland-release.jks"
GODOT="${GODOT:-/f/Godot/Godot_v4.7.2-stable_win64_console.exe}"
OUT="${1:-build/android/ToxicWasteland-1.0.0.apk}"

if [ ! -f "$INFO" ] || [ ! -f "$KEYSTORE" ]; then
	echo "Missing $INFO or $KEYSTORE - keep the release keystore in ./keystore/ (never commit it)." >&2
	exit 1
fi

ALIAS="$(sed -n 's/^Key alias *: *//p' "$INFO" | head -1)"
PASS="$(sed -n 's/^Store password *: *//p' "$INFO" | head -1)"

# Godot wants a native absolute path ("F:/..."), pwd -W gives that on Windows.
ROOT="$(pwd -W 2>/dev/null || pwd)"
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$ROOT/$KEYSTORE"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="$ALIAS"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$PASS"

mkdir -p "$(dirname "$OUT")"
"$GODOT" --headless --path . --export-release "Android" "$OUT"
echo "Signed release APK: $OUT"

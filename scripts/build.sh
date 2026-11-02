#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
bin_dir="$(swift build -c release --show-bin-path)"
app="build/dvale.app"
signing_identity="${DVALE_SIGNING_IDENTITY:-}"
if [ -z "$signing_identity" ] && [ -s build/signing-identity.txt ]; then
    IFS= read -r signing_identity < build/signing-identity.txt
fi
signing_identity="${signing_identity:--}"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin_dir/dvale" "$app/Contents/MacOS/dvale"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp LICENSE THIRD_PARTY_NOTICES.txt "$app/Contents/Resources/"
codesign --force --sign "$signing_identity" --identifier local.stillbar.app "$app"
codesign --verify --strict "$app"
# Remember the chosen identity in ignored build output so the next ordinary
# build does not silently revert to ad-hoc signing and invalidate permissions.
printf '%s\n' "$signing_identity" > build/signing-identity.txt
printf 'Built %s/%s\n' "$PWD" "$app"

#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-${RUNNER_TEMP:-/tmp}/NexQuoteDerivedData}"
SOURCE_PACKAGES_PATH="${SOURCE_PACKAGES_PATH:-${RUNNER_TEMP:-/tmp}/NexQuoteSourcePackages}"
ARTIFACTS_PATH="${ARTIFACTS_PATH:-$ROOT/artifacts}"

cd "$ROOT"
mkdir -p "$ARTIFACTS_PATH"

python3 scripts/repo_guard.py tree
python3 scripts/repo_guard.py docs
python3 scripts/repo_guard.py secrets --scope tree
python3 scripts/validate_project.py

plutil -lint App/Info.plist App/App.entitlements
plutil -lint ShareExtension/Info.plist ShareExtension/ShareExtension.entitlements
plutil -lint Shared/PrivacyInfo.xcprivacy

SIMULATOR_UDID="$(xcrun simctl list devices available -j | python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
preferred = ["iPhone 16 Pro", "iPhone 16", "iPhone 15", "iPhone SE (3rd generation)"]
available = [device for runtime in devices.values() for device in runtime if device.get("isAvailable")]
for name in preferred:
    match = next((device for device in available if device["name"] == name), None)
    if match:
        print(match["udid"])
        raise SystemExit
raise SystemExit("No supported iPhone simulator is available")
')"
DESTINATION="platform=iOS Simulator,id=$SIMULATOR_UDID"

xcrun simctl boot "$SIMULATOR_UDID" 2>/dev/null || true
open -a Simulator --args -CurrentDeviceUDID "$SIMULATOR_UDID" 2>/dev/null || true
xcrun simctl bootstatus "$SIMULATOR_UDID" -b

xcodebuild \
  -resolvePackageDependencies \
  -project App.xcodeproj \
  -scheme App \
  -clonedSourcePackagesDirPath "$SOURCE_PACKAGES_PATH"

COMMON=(
  -project App.xcodeproj
  -scheme App
  -destination "$DESTINATION"
  -derivedDataPath "$DERIVED_DATA_PATH"
  -clonedSourcePackagesDirPath "$SOURCE_PACKAGES_PATH"
  CODE_SIGNING_ALLOWED=NO
  CODE_SIGNING_REQUIRED=NO
  COMPILER_INDEX_STORE_ENABLE=NO
)

set -o pipefail
xcodebuild "${COMMON[@]}" -configuration Debug build | tee "$ARTIFACTS_PATH/debug-build.log"
xcodebuild "${COMMON[@]}" -configuration Debug test | tee "$ARTIFACTS_PATH/test.log"
xcodebuild "${COMMON[@]}" -configuration Release build | tee "$ARTIFACTS_PATH/release-build.log"

APP_PATH="$DERIVED_DATA_PATH/Build/Products/Debug-iphonesimulator/App.app"
EXTENSION_PATH="$APP_PATH/PlugIns/ShareExtension.appex"
test -d "$APP_PATH"
test -d "$EXTENSION_PATH"
test -f "$APP_PATH/public/index.html"
test -f "$APP_PATH/PrivacyInfo.xcprivacy"
test -f "$EXTENSION_PATH/PrivacyInfo.xcprivacy"

xcrun simctl install "$SIMULATOR_UDID" "$APP_PATH"
SIMCTL_CHILD_NQ_HARNESS_SHARE_TEXT="Synthetic freight request for public simulator proof" \
  xcrun simctl launch --terminate-running-process "$SIMULATOR_UDID" com.nexquote.app \
  -NQHarnessRoute "/app/rates/import?source=deep-link"
sleep 4
xcrun simctl io "$SIMULATOR_UDID" screenshot "$ARTIFACTS_PATH/nexquote-ios-simulator.png"

echo "iOS validation passed on simulator $SIMULATOR_UDID."


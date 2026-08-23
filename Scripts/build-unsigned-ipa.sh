#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
DERIVED_DATA="$BUILD_DIR/DerivedData"
APP_PATH="$DERIVED_DATA/Build/Products/Release-iphoneos/ChatGPTLite.app"
PAYLOAD_DIR="$BUILD_DIR/Payload"
IPA_PATH="$BUILD_DIR/ChatGPTLite-unsigned.ipa"

rm -rf "$DERIVED_DATA" "$PAYLOAD_DIR" "$IPA_PATH"
mkdir -p "$BUILD_DIR"

xcodebuild \
  -project "$PROJECT_DIR/ChatGPTLite.xcodeproj" \
  -scheme ChatGPTLite \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  build

test -d "$APP_PATH"
mkdir -p "$PAYLOAD_DIR"
cp -R "$APP_PATH" "$PAYLOAD_DIR/"

(
  cd "$BUILD_DIR"
  /usr/bin/zip -qry "$(basename "$IPA_PATH")" Payload
)

rm -rf "$PAYLOAD_DIR"
echo "Created: $IPA_PATH"

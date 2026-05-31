#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Codex Usage"
APP_DIR="$ROOT_DIR/.build/$APP_NAME.app"
DIST_DIR="$ROOT_DIR/.build/dist"
STAGING_DIR="$ROOT_DIR/.build/dmg-staging"
DMG_PATH="$DIST_DIR/$APP_NAME.dmg"

IDENTITY="${DEVELOPER_ID_APPLICATION:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
ALLOW_UNSIGNED="${ALLOW_UNSIGNED:-0}"
SKIP_NOTARIZE="${SKIP_NOTARIZE:-0}"

if [[ -z "$IDENTITY" && "$ALLOW_UNSIGNED" != "1" ]]; then
  echo "DEVELOPER_ID_APPLICATION is required for distributable DMG builds." >&2
  echo "Set ALLOW_UNSIGNED=1 only for local packaging tests." >&2
  exit 2
fi

"$ROOT_DIR/Scripts/build_app.sh"

if [[ -n "$IDENTITY" ]]; then
  codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP_DIR"
  codesign --verify --deep --strict --verbose=2 "$APP_DIR"
  spctl -a -vv "$APP_DIR"
fi

rm -rf "$STAGING_DIR" "$DIST_DIR"
mkdir -p "$STAGING_DIR" "$DIST_DIR"
cp -R "$APP_DIR" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

if [[ -n "$IDENTITY" ]]; then
  codesign --force --timestamp --sign "$IDENTITY" "$DMG_PATH"
  codesign --verify --verbose=2 "$DMG_PATH"
fi

if [[ -n "$IDENTITY" && "$SKIP_NOTARIZE" != "1" ]]; then
  if [[ -z "$NOTARY_PROFILE" ]]; then
    echo "NOTARY_PROFILE is required unless SKIP_NOTARIZE=1." >&2
    exit 2
  fi

  xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG_PATH"
  spctl -a -t open --context context:primary-signature -vv "$DMG_PATH"
fi

if [[ -z "$IDENTITY" ]]; then
  echo "Created unsigned local test DMG: $DMG_PATH" >&2
else
  echo "$DMG_PATH"
fi

#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$DIR/NotchBuddy"
APP="$DIR/NotchBuddy.app"

echo "→ 빌드 중..."

# 앱 번들 구조 생성
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

# Info.plist 변수 치환 후 복사
sed \
  -e 's/$(EXECUTABLE_NAME)/NotchBuddy/g' \
  -e 's/$(PRODUCT_BUNDLE_IDENTIFIER)/com.notchbuddy.app/g' \
  -e 's/$(PRODUCT_NAME)/NotchBuddy/g' \
  -e 's/$(PRODUCT_BUNDLE_PACKAGE_TYPE)/APPL/g' \
  -e 's/$(MACOSX_DEPLOYMENT_TARGET)/12.0/g' \
  -e 's/$(DEVELOPMENT_LANGUAGE)/en/g' \
  "$SRC/Info.plist" > "$APP/Contents/Info.plist"

printf 'APPL????' > "$APP/Contents/PkgInfo"

# default.gif 복사 (있을 경우)
[ -f "$SRC/default.gif" ] && cp "$SRC/default.gif" "$APP/Contents/Resources/"

# 컴파일
SDK=$(xcrun --show-sdk-path --sdk macosx)
ARCH=$(uname -m)

swiftc \
  -target "${ARCH}-apple-macosx12.0" \
  -sdk "$SDK" \
  -framework AppKit \
  -framework Vision \
  -framework CoreImage \
  -module-name NotchBuddy \
  "$SRC/AppMain.swift" \
  "$SRC/AppDelegate.swift" \
  "$SRC/NotchOverlay.swift" \
  "$SRC/GIFLoader.swift" \
  "$SRC/GIFAnimationView.swift" \
  "$SRC/BackgroundRemover.swift" \
  "$SRC/PersistenceManager.swift" \
  "$SRC/DropZoneViewController.swift" \
  -o "$APP/Contents/MacOS/NotchBuddy"

# 서명 (ad-hoc, 배포용 아님)
codesign --force --deep --sign - "$APP"

echo "✓ 빌드 완료"
echo "→ 실행 중..."
open "$APP"

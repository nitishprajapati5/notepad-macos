#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

VERSION=$(grep "^VERSION" Makefile | head -n 1 | awk '{print $3}')
DMG_PATH="build/Notepad-macOS-v${VERSION}.dmg"
CASK_FILE="Casks/notepad.rb"

if [ ! -f "$DMG_PATH" ]; then
    echo "❌ Error: DMG not found at $DMG_PATH. Run 'make package' first."
    exit 1
fi

SHA256=$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')

echo "Updating $CASK_FILE for version $VERSION..."
echo "SHA256: $SHA256"

# Update version and sha256 in Casks/notepad.rb
sed -i '' "s/version \".*\"/version \"$VERSION\"/" "$CASK_FILE"
sed -i '' "s/sha256 \".*\"/sha256 \"$SHA256\"/" "$CASK_FILE"

echo "✅ $CASK_FILE successfully updated!"
git diff "$CASK_FILE"

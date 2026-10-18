#!/bin/bash
set -e

# ==============================================================================
# Notepad for macOS — Code Signing & Notarization Pipeline
# ==============================================================================
# Usage:
#   1. Using stored Keychain profile (Recommended):
#        xcrun notarytool store-credentials "notary-profile" \
#            --apple-id "you@example.com" \
#            --team-id "55B894539Z" \
#            --password "<app-specific-password>"
#        ./scripts/notarize.sh --keychain-profile "notary-profile"
#
#   2. Using App Store Connect API Key:
#        ./scripts/notarize.sh \
#            --api-key-path "AuthKey_XXXX.p8" \
#            --api-key-id "XXXX" \
#            --api-issuer "YYYY-ZZZZ-..."
#
#   3. Using Apple ID & App-Specific Password directly:
#        ./scripts/notarize.sh \
#            --apple-id "you@example.com" \
#            --password "<app-specific-password>" \
#            --team-id "55B894539Z"
#
#   4. Sign-only (without notarization, for local testing):
#        ./scripts/notarize.sh --sign-only
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

APP_PATH="build/Notepad.app"
ENTITLEMENTS_PATH="resources/Notepad.entitlements"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SIGN_IDENTITY="${SIGN_IDENTITY:-}"
KEYCHAIN_PROFILE="${KEYCHAIN_PROFILE:-}"
APPLE_ID="${APPLE_ID:-}"
APPLE_PASSWORD="${APPLE_PASSWORD:-}"
TEAM_ID="${TEAM_ID:-}"
API_KEY_PATH="${API_KEY_PATH:-}"
API_KEY_ID="${API_KEY_ID:-}"
API_ISSUER="${API_ISSUER:-}"
SIGN_ONLY=false
SKIP_BUILD=false
ADHOC=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --identity|--sign-identity) SIGN_IDENTITY="$2"; shift ;;
        --keychain-profile|--profile) KEYCHAIN_PROFILE="$2"; shift ;;
        --apple-id) APPLE_ID="$2"; shift ;;
        --password) APPLE_PASSWORD="$2"; shift ;;
        --team-id) TEAM_ID="$2"; shift ;;
        --api-key-path) API_KEY_PATH="$2"; shift ;;
        --api-key-id) API_KEY_ID="$2"; shift ;;
        --api-issuer) API_ISSUER="$2"; shift ;;
        --adhoc) ADHOC=true; SIGN_ONLY=true ;;
        --sign-only) SIGN_ONLY=true ;;
        --skip-build) SKIP_BUILD=true ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --adhoc                      Sign with ad-hoc signature (no Apple ID required)"
            echo "  --identity <name>            Code signing identity name or hash (use '-' for ad-hoc)"
            echo "  --keychain-profile <name>    notarytool keychain profile name"
            echo "  --apple-id <email>           Apple ID email for notarization"
            echo "  --password <pwd>             App-specific password"
            echo "  --team-id <id>               Apple Developer Team ID"
            echo "  --api-key-path <path>        Path to App Store Connect .p8 key"
            echo "  --api-key-id <id>            App Store Connect Key ID"
            echo "  --api-issuer <uuid>          App Store Connect Issuer ID"
            echo "  --sign-only                  Only sign the app and DMG, skip submission"
            echo "  --skip-build                 Skip 'make all' and 'make package'"
            exit 0
            ;;
        *) echo -e "${RED}Unknown option: $1${NC}"; exit 1 ;;
    esac
    shift
done

echo -e "${BLUE}======================================================${NC}"
echo -e "${BLUE}  Notepad for macOS — Signing & Notarization Pipeline ${NC}"
echo -e "${BLUE}======================================================${NC}"

# 1. Detect Code Signing Identity
if [ "$ADHOC" = true ] || [ "$SIGN_IDENTITY" = "-" ]; then
    SIGN_IDENTITY="-"
elif [ -z "$SIGN_IDENTITY" ]; then
    echo -e "🔍 Auto-detecting Developer ID Application certificate..."
    SIGN_IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -n 1 | awk -F'"' '{print $2}' || true)
    
    if [ -z "$SIGN_IDENTITY" ]; then
        # Check for Apple Development identity as fallback for sign-only
        SIGN_IDENTITY=$(security find-identity -v -p codesigning | grep "Apple Development" | head -n 1 | awk -F'"' '{print $2}' || true)
        if [ -n "$SIGN_IDENTITY" ] && [ "$SIGN_ONLY" = false ]; then
            echo -e "${YELLOW}⚠️ Notice: Found '$SIGN_IDENTITY', but Apple Notary requires 'Developer ID Application'.${NC}"
            echo -e "${YELLOW}   If you only wish to test signed bundles locally, use --sign-only.${NC}"
        fi
    fi
fi

if [ -z "$SIGN_IDENTITY" ]; then
    if [ "$SIGN_ONLY" = true ]; then
        echo -e "${YELLOW}ℹ️ No certificate found in Keychain. Defaulting to Ad-Hoc signature (-s -).${NC}"
        SIGN_IDENTITY="-"
    else
        echo -e "${RED}❌ Error: No valid code signing identity found in macOS Keychain.${NC}"
        echo "Run 'security find-identity -v -p codesigning' to check available identities."
        echo "Or run with '--adhoc' / '--sign-only' to sign locally without an Apple ID."
        exit 1
    fi
fi

if [ "$SIGN_IDENTITY" = "-" ]; then
    echo -e "🔑 Using Signing Identity: ${GREEN}Ad-Hoc (Free / No Apple ID)${NC}"
else
    echo -e "🔑 Using Signing Identity: ${GREEN}$SIGN_IDENTITY${NC}"
fi

# 2. Build binaries if needed
if [ "$SKIP_BUILD" = false ]; then
    echo -e "\n🔨 Building application (Universal 2: arm64 + x86_64)..."
    make clean
    make -j$(sysctl -n hw.ncpu)
fi

if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}❌ Error: $APP_PATH does not exist!${NC}"
    exit 1
fi

# 3. Code-sign Application Bundle
if [ "$SIGN_IDENTITY" = "-" ]; then
    echo -e "\n✍️  Code-signing Notepad.app with Ad-Hoc signature..."
    codesign --deep --force --sign - "$APP_PATH"
else
    echo -e "\n✍️  Code-signing Notepad.app with Hardened Runtime..."
    codesign --deep --force --options runtime --timestamp \
        --entitlements "$ENTITLEMENTS_PATH" \
        --sign "$SIGN_IDENTITY" \
        "$APP_PATH"
fi

echo -e "🔎 Verifying bundle signature..."
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
echo -e "${GREEN}✅ Notepad.app signature verified successfully!${NC}"

# 4. Package DMG
echo -e "\n📦 Packaging installer disk image (DMG)..."
make package

DMG_PATH=$(find build -name "Notepad-macOS-*.dmg" | grep -v "Notepad-macOS.dmg" | head -n 1 || echo "build/Notepad-macOS.dmg")
if [ ! -f "$DMG_PATH" ]; then
    DMG_PATH="build/Notepad-macOS.dmg"
fi

# 5. Code-sign DMG
echo -e "✍️  Code-signing DMG: $DMG_PATH..."
if [ "$SIGN_IDENTITY" = "-" ]; then
    codesign --force --sign - "$DMG_PATH"
    if [ -f "build/Notepad-macOS.dmg" ] && [ "build/Notepad-macOS.dmg" != "$DMG_PATH" ]; then
        codesign --force --sign - "build/Notepad-macOS.dmg" || true
    fi
else
    codesign --force --timestamp \
        --sign "$SIGN_IDENTITY" \
        "$DMG_PATH"
    if [ -f "build/Notepad-macOS.dmg" ] && [ "build/Notepad-macOS.dmg" != "$DMG_PATH" ]; then
        codesign --force --timestamp --sign "$SIGN_IDENTITY" "build/Notepad-macOS.dmg" || true
    fi
fi

codesign --verify --strict --verbose=2 "$DMG_PATH"
echo -e "${GREEN}✅ DMG signed and verified!${NC}"

if [ "$SIGN_ONLY" = true ]; then
    echo -e "\n${GREEN}🎉 Finished Signing (Sign-Only)!${NC}"
    echo "  App: $APP_PATH"
    echo "  DMG: $DMG_PATH"
    if [ "$SIGN_IDENTITY" = "-" ]; then
        echo -e "\n${YELLOW}💡 Note for users downloading un-notarized app:${NC}"
        echo "  • Open via Right-Click → Open → Open"
        echo "  • Or run: xattr -cr /Applications/Notepad.app"
    fi
    exit 0
fi

# 6. Submit to Apple Notary Service
echo -e "\n☁️  Submitting $DMG_PATH to Apple Notary Service..."

NOTARY_ARGS=()
if [ -n "$KEYCHAIN_PROFILE" ]; then
    echo "Using keychain profile: $KEYCHAIN_PROFILE"
    NOTARY_ARGS+=(--keychain-profile "$KEYCHAIN_PROFILE")
elif [ -n "$API_KEY_PATH" ] && [ -n "$API_KEY_ID" ] && [ -n "$API_ISSUER" ]; then
    echo "Using App Store Connect API Key ($API_KEY_ID)"
    NOTARY_ARGS+=(--key "$API_KEY_PATH" --key-id "$API_KEY_ID" --issuer "$API_ISSUER")
elif [ -n "$APPLE_ID" ] && [ -n "$APPLE_PASSWORD" ]; then
    echo "Using Apple ID: $APPLE_ID"
    NOTARY_ARGS+=(--apple-id "$APPLE_ID" --password "$APPLE_PASSWORD")
    if [ -n "$TEAM_ID" ]; then
        NOTARY_ARGS+=(--team-id "$TEAM_ID")
    fi
else
    # Try default keychain profile 'notarytool-profile' if present
    if xcrun notarytool history --keychain-profile "notarytool-profile" >/dev/null 2>&1; then
        echo "Using default keychain profile 'notarytool-profile'"
        NOTARY_ARGS+=(--keychain-profile "notarytool-profile")
    else
        echo -e "${RED}❌ Error: No notarization credentials specified!${NC}"
        echo "Provide credentials via one of:"
        echo "  1) --keychain-profile <profile_name>"
        echo "  2) --api-key-path <p8> --api-key-id <id> --api-issuer <uuid>"
        echo "  3) --apple-id <email> --password <app-specific-pwd> --team-id <team_id>"
        echo ""
        echo "To store a keychain profile once and for all, run:"
        echo "  xcrun notarytool store-credentials \"notarytool-profile\" \\"
        echo "      --apple-id \"your-email@example.com\" \\"
        echo "      --team-id \"YOUR_TEAM_ID\" \\"
        echo "      --password \"your-app-specific-password\""
        exit 1
    fi
fi

# Execute submission and wait for ticket
xcrun notarytool submit "$DMG_PATH" "${NOTARY_ARGS[@]}" --wait

# 7. Staple the Ticket
echo -e "\n📎 Stapling notarization ticket to DMG..."
xcrun stapler staple "$DMG_PATH"

if [ -f "build/Notepad-macOS.dmg" ] && [ "build/Notepad-macOS.dmg" != "$DMG_PATH" ]; then
    xcrun stapler staple "build/Notepad-macOS.dmg" || true
fi

echo -e "📎 Stapling notarization ticket to Notepad.app..."
xcrun stapler staple "$APP_PATH"

# 8. Validate
echo -e "\n🛡️ Validating Gatekeeper and Notarization Staple..."
xcrun stapler validate "$DMG_PATH"
spctl --assess --type open --context context:primary-signature --verbose "$DMG_PATH" || true
spctl --assess --type execute --verbose "$APP_PATH" || true

echo -e "\n${GREEN}======================================================${NC}"
echo -e "${GREEN}🎉 Notarization and Stapling Completed Successfully!  ${NC}"
echo -e "${GREEN}======================================================${NC}"
echo "Ready for distribution without Gatekeeper warnings:"
echo "  • $DMG_PATH"

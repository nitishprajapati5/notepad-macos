# macOS Code Signing & Notarization Guide

This guide explains how to code-sign, notarize, and staple **Notepad for macOS** so that users can download and open the application without macOS Gatekeeper warnings (*"Notepad cannot be opened because the developer cannot be verified"*).

---

## Overview

macOS Gatekeeper requires distributed applications to meet three criteria:
1. **Developer ID Application Signature**: Signed with an official Apple Developer ID certificate.
2. **Hardened Runtime (`--options runtime`)**: Enabled alongside secure timestamps.
3. **Apple Notarization**: Verified by Apple's automated Notary service and stapled to the application and `.dmg`.

---

## Prerequisites

1. An **Apple Developer Account** (enrolled in the Apple Developer Program).
2. Your **Apple Team ID** (a 10-character alphanumeric string, e.g. `55B894539Z`, found in your [Apple Developer Membership](https://developer.apple.com/account)).
3. A **Developer ID Application Certificate** installed in your macOS Keychain:
   - Go to [developer.apple.com/account/resources/certificates/add](https://developer.apple.com/account/resources/certificates/add).
   - Select **Developer ID Application** (not Mac App Distribution or Apple Development).
   - Follow Apple's steps to generate and download the certificate.
   - Double-click the downloaded `.cer` file to add it to your Keychain.
   - Verify by running:
     ```bash
     security find-identity -v -p codesigning
     ```
     You should see:
     ```text
     "Developer ID Application: Your Name (TEAM_ID)"
     ```

---

## Step 1: Configure Notarization Credentials

Apple's modern notarization tool is `xcrun notarytool`. The easiest and most secure method is saving your credentials to the macOS Keychain once.

### Option A: Using App-Specific Password (Recommended)

1. Generate an App-Specific Password at [appleid.apple.com](https://appleid.apple.com) under **Sign-In and Security → App-Specific Passwords**.
2. Save credentials in your Keychain with profile name `notarytool-profile`:
   ```bash
   xcrun notarytool store-credentials "notarytool-profile" \
       --apple-id "your-apple-id@email.com" \
       --team-id "YOUR_TEAM_ID" \
       --password "xxxx-xxxx-xxxx-xxxx"
   ```
   *(You will only ever need to run this command once on your Mac).*

### Option B: Using App Store Connect API Key (For CI/CD)

1. Go to [App Store Connect → Users and Access → Integrations → App Store Connect API](https://appstoreconnect.apple.com/access/integrations/api).
2. Create an API Key with **Developer** access.
3. Download the `.p8` private key file and note the **Key ID** and **Issuer ID**.
4. Save credentials into Keychain:
   ```bash
   xcrun notarytool store-credentials "notarytool-profile" \
       --key "/path/to/AuthKey_XXXXXX.p8" \
       --key-id "XXXXXX" \
       --issuer "YOUR_ISSUER_UUID"
   ```

---

## Step 2: Run the Notarization Pipeline

Once your certificate and keychain profile are set, run:

```bash
make notarize NOTARY_PROFILE="notarytool-profile"
```

Or execute the script directly:
```bash
./scripts/notarize.sh --keychain-profile "notarytool-profile"
```

### What this command does automatically:
1. Compiles a Universal fat binary (`arm64` + `x86_64`) via `make all`.
2. Code-signs `build/Notepad.app` with **Hardened Runtime** and entitlements (`resources/Notepad.entitlements`).
3. Packages the application into an installer disk image (`build/Notepad-macOS.dmg`).
4. Code-signs the `.dmg`.
5. Uploads the `.dmg` to Apple's Notary Service and waits for approval.
6. **Staples** the notarization ticket to both the `.dmg` and `.app`.
7. Performs **Gatekeeper validation** (`spctl` and `stapler validate`).

---

## Step 3: Local Testing / Sign-Only (Without Notarization)

If you only want to sign the binary locally (e.g., using an `Apple Development` certificate):

```bash
make sign
```

Or:
```bash
./scripts/notarize.sh --sign-only
```

To verify the signature integrity on disk:
```bash
make verify-signature
```

---

## Automating Notarization in GitHub Actions CI/CD

To automatically notarize releases published from GitHub Actions:

1. Add the following secrets to your GitHub repository (**Settings → Secrets and variables → Actions**):
   - `APPLE_CERTIFICATE_BASE64`: Export your *Developer ID Application* certificate + private key from Keychain as a `.p12` file, and base64-encode it:
     ```bash
     base64 -i DeveloperID.p12 | pbcopy
     ```
   - `APPLE_CERTIFICATE_PASSWORD`: The password set when exporting the `.p12`.
   - `APPLE_ID`: Your Apple ID email.
   - `APPLE_APP_SPECIFIC_PASSWORD`: Your 16-character app-specific password.
   - `APPLE_TEAM_ID`: Your 10-character Apple Team ID.

2. In `.github/workflows/release.yml`, import the certificate into the runner's temporary keychain and execute `./scripts/notarize.sh`.

---

## Useful Troubleshooting Commands

* **Check available certificates**:
  ```bash
  security find-identity -v -p codesigning
  ```
* **Inspect app signature**:
  ```bash
  codesign --display --verbose=4 build/Notepad.app
  ```
* **Verify Gatekeeper acceptance**:
  ```bash
  spctl --assess --type execute --verbose build/Notepad.app
  ```
* **Check notarization submission history**:
  ```bash
  xcrun notarytool history --keychain-profile "notarytool-profile"
  ```
* **View detailed Apple log for a failed submission**:
  ```bash
  xcrun notarytool log <submission-uuid> --keychain-profile "notarytool-profile"
  ```

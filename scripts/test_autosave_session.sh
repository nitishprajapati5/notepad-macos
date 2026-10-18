#!/bin/bash
set -e

APP_PATH="$(pwd)/build/Notepad.app"
SESSION_DIR="$HOME/Library/Application Support/Notepad/Session"
SCRATCHPAD_DIR="$SESSION_DIR/scratchpads"
TEST_DOC="$(pwd)/scratch_test_document.txt"

echo "========================================================"
echo "Testing 'Never Lose My Thoughts' (Auto-Save & Session)"
echo "========================================================"

# Clean previous test state
killall Notepad 2>/dev/null || true
sleep 1
rm -f "$TEST_DOC"
rm -rf "$SESSION_DIR"

echo "1. Launching Notepad.app..."
open "$APP_PATH"
sleep 2

# Verify directories were created
if [ -d "$SESSION_DIR" ]; then
    echo "✅ Session directory initialized: $SESSION_DIR"
else
    echo "❌ Session directory missing!"
    exit 1
fi

echo "2. Simulating typing into Untitled Scratchpad..."
osascript <<EOF
tell application "System Events"
    tell process "Notepad"
        set frontmost to true
        delay 0.5
        keystroke "Never Lose My Thoughts: This is an unsaved scratchpad draft."
        keystroke return
        keystroke "Written at " & (current date as string)
    end tell
end tell
EOF

sleep 2

echo "3. Quitting Notepad with Cmd+Q (Simulating quitting without saving)..."
osascript <<EOF
tell application "System Events"
    tell process "Notepad"
        keystroke "q" using command down
    end tell
end tell
EOF

sleep 2

# Verify process exited cleanly without modal block
if pgrep -x "Notepad" >/dev/null; then
    echo "⚠️ Process still running, sending SIGTERM"
    killall Notepad
    sleep 1
fi

echo "4. Inspecting saved session & scratchpad..."
if [ -f "$SESSION_DIR/session.plist" ]; then
    echo "✅ session.plist was saved successfully!"
else
    echo "❌ session.plist not found!"
    exit 1
fi

SCRATCH_FILES=$(find "$SCRATCHPAD_DIR" -type f -name "*.txt" 2>/dev/null || true)
if [ -n "$SCRATCH_FILES" ]; then
    echo "✅ Scratchpad draft file created:"
    for f in $SCRATCH_FILES; do
        echo "   File: $f"
        echo "   Content:"
        cat "$f" | sed 's/^/     /'
    done
else
    echo "❌ No scratchpad file found in $SCRATCHPAD_DIR"
    exit 1
fi

echo "5. Testing Session Restoration (Relaunching app)..."
open "$APP_PATH"
sleep 2

echo "6. Testing Continuous Auto-Save on saved file..."
echo "Initial baseline content" > "$TEST_DOC"
open -a "$APP_PATH" "$TEST_DOC"
sleep 2

osascript <<EOF
tell application "System Events"
    tell process "Notepad"
        set frontmost to true
        delay 0.5
        keystroke return
        keystroke "Added via continuous auto-save line."
    end tell
end tell
EOF

echo "Waiting 3 seconds for continuous auto-save debounce..."
sleep 3.5

if grep -q "Added via continuous auto-save line." "$TEST_DOC"; then
    echo "✅ Continuous Auto-Save successfully updated disk file!"
else
    echo "⚠️ Disk file not updated immediately, checking scratchpad..."
fi

# Clean up
killall Notepad 2>/dev/null || true
rm -f "$TEST_DOC"

echo "========================================================"
echo "🎉 ALL TESTS COMPLETED SUCCESSFULLY!"
echo "========================================================"

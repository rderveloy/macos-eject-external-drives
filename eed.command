#! /bin/bash

echo ""
echo "*** External Drive Ejection Utility ***"

# Stop any running Time Machine backup — only intervene if one is running,
# and try without sudo first (admin users may not need it on macOS)
echo -n "Checking for running Time Machine backups..."
if tmutil status 2>/dev/null | grep -q "Running = 1"; then
    echo "backup in progress."
    echo -n "Stopping backup..."
    if ! tmutil stopbackup 2>/dev/null; then
        echo " (requires admin password)"
        sudo tmutil stopbackup
    fi
    echo "Done!"
else
    echo "none running."
fi

# Detect external physical drives (no sudo needed)
echo ""
echo "Scanning for external drives..."
drives=$(diskutil list external physical | grep -E '^/dev/' | grep -Eo 'disk[0-9]+')

if [ -z "$drives" ]; then
    echo "No external drives found."
    echo "Goodbye!"
    exit 0
fi

# Eject each drive and report status (no sudo needed)
echo "Ejecting external drives:"
success=0
failed=0
while IFS= read -r drive; do
    echo -n "  $drive ... "
    if diskutil eject "$drive" >/dev/null 2>&1; then
        echo "ejected"
        ((success++))
    else
        echo "FAILED"
        ((failed++))
    fi
done <<< "$drives"

# Summary
echo ""
if [ $failed -eq 0 ]; then
    echo "All drives ejected successfully ($success total)."
else
    echo "Warning: $failed drive(s) failed to eject. $success ejected successfully."
fi

echo ""
echo "Waiting for drives to be physically disconnected..."
timeout=60
elapsed=0
while true; do
    remaining=$(diskutil list external physical 2>/dev/null | grep -E '^/dev/' | grep -Eo 'disk[0-9]+')
    if [ -z "$remaining" ]; then
        echo "All drives disconnected. Safe to go!"
        break
    fi
    if [ $elapsed -ge $timeout ]; then
        echo "Timed out waiting. The following drives are still connected:"
        echo "$remaining" | sed 's/^/  /'
        break
    fi
    sleep 1
    ((elapsed++))
done

echo "Goodbye!"

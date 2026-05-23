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
drive_count=$(echo "$drives" | wc -l | xargs)
current=$(diskutil list external physical 2>/dev/null | grep -Eo 'disk[0-9]+')

if [ -z "$current" ]; then
    echo "All drives ejected. Safe to go!"
else
    echo "Waiting for drives to be ejected..."
    spinner='|/-\'
    spin_idx=0
    start=$SECONDS

    while IFS= read -r drive; do printf "  %-8s [ ]\n" "$drive"; done <<< "$drives"

    while true; do
        char="${spinner:$((spin_idx % 4)):1}"
        current=$(diskutil list external physical 2>/dev/null | grep -Eo 'disk[0-9]+')
        printf "\033[%dA" "$drive_count"
        still=0
        while IFS= read -r drive; do
            if echo "$current" | grep -q "^${drive}$"; then
                printf "  %-8s %-15s\n" "$drive" "[$char]"
                ((still++))
            else
                printf "  %-8s %-15s\n" "$drive" "[ejected]"
            fi
        done <<< "$drives"
        if [ $still -eq 0 ]; then
            echo ""
            echo "All drives ejected. Safe to go!"
            break
        fi
        if [ $(( SECONDS - start )) -ge 60 ]; then
            echo ""
            echo "Timed out after 60s. Some drives may not have ejected."
            break
        fi
        ((spin_idx++))
        sleep 0.25
    done
fi

echo "Goodbye!"

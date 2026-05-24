#! /bin/bash
VERSION="2.0.2"

# Processes that keep files open on volumes without actively transferring user data
SYSTEM_PROCS="mds mds_stores fseventsd diskarbitrationd kernel_task corestoraged mdflagwriter mdworker mdworker_shared"
EXCLUDE_PATTERN=$(printf '%s|' $SYSTEM_PROCS | sed 's/|$//')

# Returns mounted filesystem paths for a given disk identifier (e.g. disk2)
get_mount_points() {
    mount 2>/dev/null | grep -E "^/dev/${1}([sp][0-9]+)? on " | sed -E 's|^[^ ]+ on (.*) \(.*\)$|\1|'
}

# Returns user-visible processes with open write-mode files under a mount point
check_active_writes() {
    local mp="$1"
    lsof -nPF pcna 2>/dev/null | awk -v mp="$mp" '
        /^p/ { pid=substr($0,2) }
        /^c/ { cmd=substr($0,2) }
        /^a/ { acc=substr($0,2) }
        /^n/ {
            path=substr($0,2)
            if ((acc=="w" || acc=="u") && \
                (path==mp || (index(path,mp)==1 && substr(path,length(mp)+1,1)=="/")))
                print cmd " (PID " pid ")"
        }
    ' | grep -vE "^($EXCLUDE_PATTERN) " | sort -u
}

# Scans all drives for active writes; prints a formatted summary or nothing if clean
collect_transfers() {
    local result="" drive mp writes
    while IFS= read -r drive; do
        while IFS= read -r mp; do
            [ -z "$mp" ] && continue
            writes=$(check_active_writes "$mp")
            [ -z "$writes" ] && continue
            result="${result}  ${drive} (${mp}):"$'\n'
            while IFS= read -r proc; do
                result="${result}    ${proc}"$'\n'
            done <<< "$writes"
        done <<< "$(get_mount_points "$drive")"
    done <<< "$drives"
    printf '%s' "$result"
}


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

# Check for active file transfers before ejecting
echo -n "Checking for active file transfers..."
transfers_found=$(collect_transfers)

if [ -z "$transfers_found" ]; then
    echo "none."
else
    echo ""
    echo ""
    while true; do
        printf "  Warning: Active file writes detected:\n"
        printf '%s' "$transfers_found"
        echo ""
        printf "  [W] Wait 10 seconds and re-check\n"
        printf "  [C] Continue ejecting anyway\n"
        printf "  [A] Abort\n"
        echo ""
        read -r -n 1 -p "  Choice [W/C/A]: " choice
        echo ""
        case "$choice" in
            [Ww])
                echo ""
                printf "  Waiting 10 seconds..."
                sleep 10
                printf "\r  Re-checking for active file transfers..."
                transfers_found=$(collect_transfers)
                if [ -z "$transfers_found" ]; then
                    echo "clear!"
                    echo ""
                    break
                else
                    echo ""
                    echo ""
                fi
                ;;
            [Cc])
                echo ""
                break
                ;;
            [Aa])
                echo ""
                echo "Aborted. No drives were ejected."
                echo "Goodbye!"
                exit 1
                ;;
            *)
                echo "  Please press W, C, or A."
                echo ""
                ;;
        esac
    done
fi

# Eject each drive; spin per-drive while diskutil works in the background
echo "Ejecting external drives:"
success=0
failed=0
spinner='|/-\'
spin_idx=0

while IFS= read -r drive; do
    diskutil eject "$drive" >/dev/null 2>&1 &
    eject_pid=$!
    while kill -0 "$eject_pid" 2>/dev/null; do
        printf "\r  %-8s [%s]" "$drive" "${spinner:$((spin_idx % 4)):1}"
        ((spin_idx++))
        sleep 0.1
    done
    wait "$eject_pid"
    if [ $? -eq 0 ]; then
        printf "\r  %-8s [ejected]\n" "$drive"
        ((success++))
    else
        printf "\r  %-8s [FAILED] \n" "$drive"
        ((failed++))
    fi
done <<< "$drives"

echo ""

# Happy path: diskutil eject returning 0 means the drive is already gone — exit immediately
if [ $failed -eq 0 ]; then
    echo "All $success drive(s) ejected. Safe to go!"
    echo "Goodbye!"
    exit 0
fi

echo "Warning: $failed drive(s) failed to eject. $success ejected successfully."
echo ""

# Some drives failed — poll briefly in case they finish unmounting on their own
drive_count=$(echo "$drives" | wc -l | xargs)
current=$(diskutil list external physical 2>/dev/null | grep -Eo 'disk[0-9]+')

if [ -z "$current" ]; then
    echo "All drives ejected. Safe to go!"
else
    echo "Waiting for remaining drives..."
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
                printf "  %-8s [%s]\n" "$drive" "$char"
                ((still++))
            else
                printf "  %-8s [ejected]\n" "$drive"
            fi
        done <<< "$drives"
        if [ $still -eq 0 ]; then
            echo ""
            echo "All drives ejected. Safe to go!"
            break
        fi
        if [ $(( SECONDS - start )) -ge 15 ]; then
            echo ""
            echo "Timed out. Some drives may not have ejected."
            break
        fi
        ((spin_idx++))
        sleep 0.1
    done
fi

echo "Goodbye!"

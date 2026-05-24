#! /bin/bash
VERSION="2.0.3"

_tty=$(tty 2>/dev/null)
case "$_tty" in /dev/*) _tty="${_tty#/dev/}" ;; *) _tty="" ;; esac
_close_terminal() {
    [ -n "$_tty" ] || return
    (sleep 0.2; osascript -e "tell application \"Terminal\" to close (every window whose (count of tabs) = 1 and tty of tab 1 is \"${_tty}\")") &
    disown $! 2>/dev/null || true
}
trap '_close_terminal' EXIT

# Processes that keep files open on volumes without actively transferring user data
SYSTEM_PROCS="mds mds_stores fseventsd diskarbitrationd kernel_task corestoraged mdflagwriter mdworker mdworker_shared"
EXCLUDE_PATTERN=$(printf '%s|' $SYSTEM_PROCS | sed 's/|$//')

# Returns mounted filesystem paths for a given disk identifier (e.g. disk2)
get_mount_points() {
    mount 2>/dev/null | grep -E "^/dev/${1}([sp][0-9]+)? on " | sed -E 's|^[^ ]+ on (.*) \(.*\)$|\1|'
}

# Runs lsof once and caches output; sets lsof_available (0/1).
# Caching avoids running lsof once per mount point and lets us detect failure.
_lsof_cache=""
lsof_available=0
_run_lsof() {
    _lsof_cache=$(lsof -nPF pcna 2>/dev/null)
    [ -n "$_lsof_cache" ] && lsof_available=1 || lsof_available=0
}

# Returns user-visible processes with open write-mode files under a mount point
check_active_writes() {
    local mp="$1"
    printf '%s\n' "$_lsof_cache" | awk -v mp="$mp" '
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

# Sets transfers_found (display string) and drives_with_transfers (space-separated
# drive identifiers) for any drive with active user-visible writes.
# Refreshes the lsof cache on each call.
detect_transfers() {
    transfers_found=""
    drives_with_transfers=""
    _run_lsof
    [ "$lsof_available" -eq 0 ] && return
    local drive mp writes has_transfer
    while IFS= read -r drive; do
        has_transfer=0
        while IFS= read -r mp; do
            [ -z "$mp" ] && continue
            writes=$(check_active_writes "$mp")
            [ -z "$writes" ] && continue
            has_transfer=1
            transfers_found="${transfers_found}  ${drive} (${mp}):"$'\n'
            while IFS= read -r proc; do
                transfers_found="${transfers_found}    ${proc}"$'\n'
            done <<< "$writes"
        done <<< "$(get_mount_points "$drive")"
        [ "$has_transfer" -eq 1 ] && drives_with_transfers="$drives_with_transfers $drive"
    done <<< "$drives"
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
detect_transfers

force_eject=0

if [ "$lsof_available" -eq 0 ]; then
    echo "unavailable."
    echo ""
    echo "  Warning: Could not verify active file transfers — proceeding without transfer detection."
    echo ""
elif [ -z "$transfers_found" ]; then
    echo "none."
else
    echo ""
    echo ""
    while true; do
        printf "  Warning: Active file writes detected:\n"
        printf '%s' "$transfers_found"
        echo ""
        printf "  [W] Wait 5 seconds and re-check  (default)\n"
        printf "  [C] Continue ejecting anyway\n"
        printf "  [A] Abort\n"
        printf "  [F] Force eject (may leave incomplete files on the drive)\n"
        echo ""
        read -r -n 1 -p "  Choice [W/c/a/f]: " choice
        echo ""
        case "$choice" in
            [Ww]|"")
                echo ""
                printf "  Waiting 5 seconds..."
                sleep 5
                printf "\r  Re-checking for active file transfers..."
                detect_transfers
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
            [Ff])
                echo ""
                printf "  WARNING: Force eject closes all open files immediately.\n"
                printf "           Incomplete transfers may leave corrupt files on the drive.\n"
                echo ""
                read -r -n 1 -p "  Confirm force eject? [y/N]: " confirm
                echo ""
                if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
                    force_eject=1
                    echo ""
                    break
                else
                    echo "  Cancelled."
                    echo ""
                fi
                ;;
            *)
                echo "  Please press W, C, A, or F."
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
    if [ "$force_eject" -eq 1 ] && \
       case " $drives_with_transfers " in *" $drive "*) true ;; *) false ;; esac; then
        diskutil eject force "$drive" >/dev/null 2>&1 &
    else
        diskutil eject "$drive" >/dev/null 2>&1 &
    fi
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

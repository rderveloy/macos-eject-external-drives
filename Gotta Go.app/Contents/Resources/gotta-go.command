#! /bin/bash
VERSION="3.0.0"

_tty=$(tty 2>/dev/null)
case "$_tty" in /dev/*) ;; *) _tty="" ;; esac
_alert_msg=""
_on_exit() {
    [ -n "$_alert_msg" ] && osascript -e "display alert \"Gotta Go\" message \"${_alert_msg}\"" 2>/dev/null
    [ -n "$_tty" ] || return
    local _tty_short="${_tty#/dev/}"
    local _tty_full="$_tty"
    ( trap '' HUP
      sleep 0.3
      osascript -e "
tell application \"Terminal\"
    repeat with w in every window
        repeat with t in every tab of w
            if tty of t is \"${_tty_short}\" or tty of t is \"${_tty_full}\" then
                close t
                return
            end if
        end repeat
    end repeat
end tell" 2>/dev/null
    ) &
    disown $! 2>/dev/null || true
}
trap '_on_exit' EXIT

# Processes that keep files open on volumes without actively transferring user data
SYSTEM_PROCS="mds mds_stores fseventsd diskarbitrationd kernel_task corestoraged mdflagwriter mdworker mdworker_shared"
EXCLUDE_PATTERN=$(printf '%s|' $SYSTEM_PROCS | sed 's/|$//')

# System partition names that are not user-visible in Finder
SYSTEM_PART_NAMES="EFI|Recovery|Preboot|VM|Update|Data"

# Returns mounted filesystem paths for a given disk identifier (e.g. disk2)
get_mount_points() {
    mount 2>/dev/null | grep -E "^/dev/${1}([sp][0-9]+)? on " | sed -E 's|^[^ ]+ on (.*) \(.*\)$|\1|'
}

# Runs lsof once and caches output; sets lsof_available (0/1).
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

# Returns a display name for a disk by collecting user-visible volume names from
# its partitions. Falls back to the disk's Media Name, then the identifier itself.
get_drive_name() {
    local drive="$1"
    local partitions vol_names name info part_name

    # Collect partition identifiers for this disk (e.g. disk2s1, disk2s2, ...)
    partitions=$(diskutil list "$drive" 2>/dev/null \
        | grep -Eo "${drive}s[0-9]+" | sort -u)

    vol_names=""
    while IFS= read -r part; do
        [ -z "$part" ] && continue
        info=$(diskutil info "$part" 2>/dev/null)
        part_name=$(printf '%s\n' "$info" | sed -n 's/^ *Volume Name: *//p' | sed 's/ *$//')
        # Skip blank, "Not applicable*", and known system partition names
        case "$part_name" in
            ""|"Not applicable"*) continue ;;
        esac
        if printf '%s' "$part_name" | grep -qE "^($SYSTEM_PART_NAMES)$"; then
            continue
        fi
        vol_names="${vol_names:+$vol_names / }${part_name}"
    done <<< "$partitions"

    if [ -n "$vol_names" ]; then
        printf '%s' "$vol_names"
        return
    fi

    # Fallback: Media Name from the whole disk
    info=$(diskutil info "$drive" 2>/dev/null)
    name=$(printf '%s\n' "$info" | sed -n 's/^ *Media Name: *//p' | sed 's/ *$//')
    [ -n "$name" ] && printf '%s' "$name" || printf '%s' "$drive"
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
echo "*** Gotta Go v${VERSION} ***"

# Stop any running Time Machine backup
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

# Detect external physical drives
echo ""
echo "Scanning for external drives..."
drives=$(diskutil list external physical | grep -E '^/dev/' | grep -Eo 'disk[0-9]+')

if [ -z "$drives" ]; then
    echo "No external drives found."
    echo "Goodbye!"
    _alert_msg="No external drives found. Safe to go!"
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
                _alert_msg="Aborted. No drives were ejected."
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

# Build parallel arrays: drive identifiers, display names, eject PIDs, statuses
drive_arr=()
name_arr=()
pid_arr=()
status_arr=()   # "spinning" | "ejected" | "failed"

col_width=0
while IFS= read -r d; do
    drive_arr+=("$d")
    raw_name=$(get_drive_name "$d")
    drive_arr_len=${#drive_arr[@]}
    name_arr+=("$raw_name")
    [ ${#raw_name} -gt "$col_width" ] && col_width=${#raw_name}
done <<< "$drives"

# Cap column width and truncate names that exceed it
max_col=35
[ "$col_width" -gt "$max_col" ] && col_width=$max_col
for i in "${!name_arr[@]}"; do
    if [ ${#name_arr[$i]} -gt "$col_width" ]; then
        name_arr[$i]="${name_arr[$i]:0:$(( col_width - 3 ))}..."
    fi
done

drive_count=${#drive_arr[@]}

# Launch all ejects in parallel
echo "Ejecting external drives:"
for i in "${!drive_arr[@]}"; do
    d="${drive_arr[$i]}"
    if [ "$force_eject" -eq 1 ] && \
       case " $drives_with_transfers " in *" $d "*) true ;; *) false ;; esac; then
        diskutil eject force "$d" >/dev/null 2>&1 &
    else
        diskutil eject "$d" >/dev/null 2>&1 &
    fi
    pid_arr+=($!)
    status_arr+=("spinning")
    printf "  %-*s [ ]\n" "$col_width" "${name_arr[$i]}"
done

# Animate all lines simultaneously until all PIDs are done
spinner='|/-\'
spin_idx=0
success=0
failed=0

while true; do
    # Check each drive's PID
    all_done=1
    for i in "${!pid_arr[@]}"; do
        [ "${status_arr[$i]}" != "spinning" ] && continue
        if ! kill -0 "${pid_arr[$i]}" 2>/dev/null; then
            wait "${pid_arr[$i]}"
            if [ $? -eq 0 ]; then
                status_arr[$i]="ejected"
                ((success++))
            else
                status_arr[$i]="failed"
                ((failed++))
            fi
        else
            all_done=0
        fi
    done

    # Redraw all lines
    printf "\033[%dA" "$drive_count"
    char="${spinner:$((spin_idx % 4)):1}"
    for i in "${!drive_arr[@]}"; do
        case "${status_arr[$i]}" in
            spinning) printf "  %-*s [%s]\n" "$col_width" "${name_arr[$i]}" "$char" ;;
            ejected)  printf "  %-*s [ejected]\n" "$col_width" "${name_arr[$i]}" ;;
            failed)   printf "  %-*s [FAILED] \n" "$col_width" "${name_arr[$i]}" ;;
        esac
    done

    [ "$all_done" -eq 1 ] && break
    ((spin_idx++))
    sleep 0.1
done

echo ""

if [ "$failed" -eq 0 ]; then
    echo "All $success drive(s) ejected. Safe to go!"
    echo "Goodbye!"
    _alert_msg="All ${success} drive(s) ejected. Safe to go!"
    exit 0
fi

echo "Warning: $failed drive(s) failed to eject. $success ejected successfully."
echo ""

# Some drives failed — poll briefly in case they finish on their own
current=$(diskutil list external physical 2>/dev/null | grep -Eo 'disk[0-9]+')

if [ -z "$current" ]; then
    echo "All drives ejected. Safe to go!"
    _alert_msg="All drives ejected. Safe to go!"
else
    echo "Waiting for remaining drives..."
    spin_idx=0
    start=$SECONDS

    # Reset statuses for polling display
    for i in "${!drive_arr[@]}"; do
        if ! printf '%s\n' "$current" | grep -q "^${drive_arr[$i]}$"; then
            status_arr[$i]="ejected"
        else
            status_arr[$i]="spinning"
        fi
        case "${status_arr[$i]}" in
            ejected) printf "  %-*s [ejected]\n" "$col_width" "${name_arr[$i]}" ;;
            *)       printf "  %-*s [ ]\n"       "$col_width" "${name_arr[$i]}" ;;
        esac
    done

    while true; do
        current=$(diskutil list external physical 2>/dev/null | grep -Eo 'disk[0-9]+')
        still=0
        char="${spinner:$((spin_idx % 4)):1}"

        printf "\033[%dA" "$drive_count"
        for i in "${!drive_arr[@]}"; do
            if printf '%s\n' "$current" | grep -q "^${drive_arr[$i]}$"; then
                status_arr[$i]="spinning"
                printf "  %-*s [%s]\n" "$col_width" "${name_arr[$i]}" "$char"
                ((still++))
            else
                status_arr[$i]="ejected"
                printf "  %-*s [ejected]\n" "$col_width" "${name_arr[$i]}"
            fi
        done

        if [ "$still" -eq 0 ]; then
            echo ""
            echo "All drives ejected. Safe to go!"
            _alert_msg="All drives ejected. Safe to go!"
            break
        fi
        if [ $(( SECONDS - start )) -ge 15 ]; then
            echo ""
            echo "Timed out. Some drives may not have ejected."
            _alert_msg="Timed out. Some drives may not have ejected."
            break
        fi
        ((spin_idx++))
        sleep 0.1
    done
fi

echo "Goodbye!"

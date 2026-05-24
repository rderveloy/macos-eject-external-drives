# gotta-go
A simple macOS terminal script to safely eject external drives. Useful for when you need
to unplug your MacBook and go.

[![CC BY-SA 4.0][cc-by-sa-shield]][cc-by-sa]

This work is licensed under a
[Creative Commons Attribution-ShareAlike 4.0 International License][cc-by-sa].

[![CC BY-SA 4.0][cc-by-sa-image]][cc-by-sa]

[cc-by-sa]: http://creativecommons.org/licenses/by-sa/4.0/
[cc-by-sa-image]: https://licensebuttons.net/l/by-sa/4.0/88x31.png
[cc-by-sa-shield]: https://img.shields.io/badge/License-CC%20BY--SA%204.0-lightgrey.svg

Have you ever been running late, and you needed to take your MacBook with you, but Time
Machine is taking its sweet time backing up to an external drive?

Need to disconnect your external physical drives, but don't want to accidentally eject
your iPhone because the eject icons in Finder are really small?

Then this simple script is for you!

---

## Install via Homebrew

```sh
brew tap rderveloy/gotta-go https://github.com/rderveloy/gotta-go
brew install --cask gotta-go
```

This will:
1. Install **Gotta Go.app** to `/Applications/` so it appears in Launchpad and can be pinned to the Dock.
2. Place **Gotta Go.command** on your Desktop for double-click access.

To uninstall:

```sh
brew uninstall --cask gotta-go
brew untap rderveloy/gotta-go
```

### First launch: macOS Gatekeeper

macOS will block **Gotta Go.app** on first launch because it is not code-signed. You will see a dialog with only "Move to Trash" or "Done" as options.

To allow it, choose one of:

**Option A — System Settings:**
1. Open **System Settings → Privacy & Security**
2. Scroll down to the Security section
3. Click **Open Anyway** next to the Gotta Go entry

**Option B — Terminal:**
```sh
xattr -dr com.apple.quarantine "/Applications/Gotta Go.app"
```

This only needs to be done once. The **Gotta Go.command** shortcut on your Desktop is not affected by Gatekeeper and works immediately without any extra steps.

---

## Manual Install

1. Download `gotta-go.command` from this repository.
2. Make it executable:
   ```sh
   chmod +x gotta-go.command
   ```
3. Double-click `gotta-go.command` in Finder, or run it directly in Terminal.

---

## Usage

Double-click **Gotta Go** in Launchpad, from the Dock, on your Desktop,
or run `gotta-go.command` directly in Terminal. The script will:

1. Stop any running Time Machine backup (prompts for your password only if needed).
2. Eject all external physical drives, reporting success or failure per drive.
3. Display a live status for each drive and exit once all are ejected.

Note: This script will stop a Time Machine backup in progress, but will **not**
automatically cancel file transfers that are in progress to your external drives.

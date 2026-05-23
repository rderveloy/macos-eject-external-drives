# Changelog

All notable changes to this project are documented in this file.

## [2.0.0] - 2026-05-23

### Added
- macOS `.app` bundle (`Eject External Drives.app`) installable to `/Applications/`
  so the utility appears in Launchpad and can be pinned to the Dock.
- Desktop shortcut (`Eject External Drives.command`) delivered at install time,
  preserving the existing double-click workflow.
- Homebrew Cask formula at `Casks/eject-external-drives.rb` for one-command install.
- `VERSION` variable in `eed.command` for machine-readable version tracking.
- This `CHANGELOG.md`.

## [1.0.0]

### Added
- `eed.command`: bash script to eject all external physical drives.
- Stops a running Time Machine backup before ejecting (tries without sudo first,
  falls back to sudo only if needed).
- Per-drive eject status with a live animated spinner while waiting for drives to eject.
- Prints a success/failure summary.
- `README.md` with manual install and usage instructions.
- CC BY-SA 4.0 license.

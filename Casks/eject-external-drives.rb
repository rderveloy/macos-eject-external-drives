cask "eject-external-drives" do
  version "2.0.6"
  sha256 "5ecc7f8572ca6e287391913eacb770a3b585688bed880c301b8cb6318c9ef9b0"

  url "https://github.com/rderveloy/macos-eject-external-drives/archive/refs/tags/v#{version}.tar.gz"
  name "Eject External Drives"
  desc "Safely eject all external drives on macOS, stopping Time Machine if needed"
  homepage "https://github.com/rderveloy/macos-eject-external-drives"

  app "macos-eject-external-drives-#{version}/Eject External Drives.app"

  artifact "macos-eject-external-drives-#{version}/eed.command",
           target: "#{Dir.home}/Desktop/Eject External Drives.command"

  uninstall delete: "#{Dir.home}/Desktop/Eject External Drives.command"

  caveats <<~EOS
    macOS will block the app on first launch because it is not code-signed.

    To allow it, either:
      • System Settings → Privacy & Security → scroll down → "Open Anyway"
      • Or run: xattr -dr com.apple.quarantine "/Applications/Eject External Drives.app"

    The Desktop shortcut (Eject External Drives.command) works without this step.
  EOS

  zap trash: ["#{Dir.home}/Desktop/Eject External Drives.command"]
end

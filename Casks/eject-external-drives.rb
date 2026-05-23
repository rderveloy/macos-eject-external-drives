cask "eject-external-drives" do
  version "2.0.0"
  sha256 "PLACEHOLDER_REPLACE_AFTER_RELEASE"

  url "https://github.com/rderveloy/macos-eject-external-drives/archive/refs/tags/v#{version}.tar.gz"
  name "Eject External Drives"
  desc "Safely eject all external drives on macOS, stopping Time Machine if needed"
  homepage "https://github.com/rderveloy/macos-eject-external-drives"

  app "Eject External Drives.app"

  artifact "eed.command",
           target: "#{Dir.home}/Desktop/Eject External Drives.command"

  uninstall delete: "#{Dir.home}/Desktop/Eject External Drives.command"

  zap trash: ["#{Dir.home}/Desktop/Eject External Drives.command"]
end

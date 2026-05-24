cask "eject-external-drives" do
  version "2.0.0"
  sha256 "1aa800c99830fcdda87b35f66d2acb4af689c5749ddc9e867c71e3dc030481ef"

  url "https://github.com/rderveloy/macos-eject-external-drives/archive/refs/tags/v#{version}.tar.gz"
  name "Eject External Drives"
  desc "Safely eject all external drives on macOS, stopping Time Machine if needed"
  homepage "https://github.com/rderveloy/macos-eject-external-drives"

  app "macos-eject-external-drives-#{version}/Eject External Drives.app"

  artifact "macos-eject-external-drives-#{version}/eed.command",
           target: "#{Dir.home}/Desktop/Eject External Drives.command"

  uninstall delete: "#{Dir.home}/Desktop/Eject External Drives.command"

  zap trash: ["#{Dir.home}/Desktop/Eject External Drives.command"]
end

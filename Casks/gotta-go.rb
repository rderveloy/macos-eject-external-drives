cask "gotta-go" do
  version "2.0.7"
  sha256 "PLACEHOLDER_REPLACE_AFTER_RELEASE"

  url "https://github.com/rderveloy/gotta-go/archive/refs/tags/v#{version}.tar.gz"
  name "Gotta Go"
  desc "Safely eject all external drives on macOS, stopping Time Machine if needed"
  homepage "https://github.com/rderveloy/gotta-go"

  app "gotta-go-#{version}/Gotta Go.app"

  artifact "gotta-go-#{version}/gotta-go.command",
           target: "#{Dir.home}/Desktop/Gotta Go.command"

  uninstall delete: "#{Dir.home}/Desktop/Gotta Go.command"

  caveats <<~EOS
    macOS will block the app on first launch because it is not code-signed.

    To allow it, either:
      • System Settings → Privacy & Security → scroll down → "Open Anyway"
      • Or run: xattr -dr com.apple.quarantine "/Applications/Gotta Go.app"

    The Desktop shortcut (Gotta Go.command) works without this step.
  EOS

  zap trash: ["#{Dir.home}/Desktop/Gotta Go.command"]
end

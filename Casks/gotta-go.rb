cask "gotta-go" do
  version "2.0.7"
  sha256 "7032157de65cbebcc6394e60ee28610b016d7eb2e8092d51a1438e7f0ca87db0"

  url "https://github.com/rderveloy/gotta-go/archive/refs/tags/v#{version}.tar.gz"
  name "Gotta Go"
  desc "Safely eject all external drives on macOS, stopping Time Machine if needed"
  homepage "https://github.com/rderveloy/gotta-go"

  app "gotta-go-#{version}/Gotta Go.app"

  caveats <<~EOS
    macOS will block the app on first launch because it is not code-signed.

    To allow it, either:
      • System Settings → Privacy & Security → scroll down → "Open Anyway"
      • Or run: xattr -dr com.apple.quarantine "/Applications/Gotta Go.app"
  EOS
end

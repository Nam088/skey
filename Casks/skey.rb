cask "skey" do
  version "1.0.18"
  sha256 "ca038fe9e645b5f5e3a9863aa5e39177a7c873e1fc629f596429fa594746ed1a"

  url "https://github.com/Nam088/skey/releases/download/v#{version}/SKey-Installer.dmg"
  name "SKey"
  desc "Modern, high-performance Vietnamese input engine and utilities"
  homepage "https://github.com/Nam088/skey"

  depends_on macos: :sonoma

  app "SKey.app"

  uninstall quit: "com.nam088.skey"

  zap trash: [
    "~/Library/Application Support/com.nam088.skey",
    "~/Library/Caches/com.nam088.skey",
    "~/Library/Preferences/com.nam088.skey.plist",
    "~/Library/Saved Application State/com.nam088.skey.savedState",
  ]
end

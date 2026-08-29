cask "skey" do
  version "1.0.17"
  sha256 "eef117ebd0afca3e2958a92b40ce2571a33ec46888ea39c5f2a16ef2f305c63f"

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

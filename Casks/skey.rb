cask "skey" do
  version "1.0.19"
  sha256 "c20b44a447158426f00beb4111bb61e8591654f18bdb56fee5584e24ce3bd5e4"

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

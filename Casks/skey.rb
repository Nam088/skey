cask "skey" do
  version "1.0.16"

  # CASK_ARCH_URLS_START
  on_arm do
    sha256 "db3f5e66aa10c71c506a08b1c88d5fc24bbc077b4a5c51611425665e5a24ad77"

    url "https://github.com/Nam088/skey/releases/download/v1.0.16/SKey-Installer.dmg"
  end
  on_intel do
    sha256 "db3f5e66aa10c71c506a08b1c88d5fc24bbc077b4a5c51611425665e5a24ad77"

    url "https://github.com/Nam088/skey/releases/download/v1.0.16/SKey-Installer.dmg"
  end
  # CASK_ARCH_URLS_END

  name "SKey"
  desc "Modern, high-performance Vietnamese input engine & utilities for macOS"
  homepage "https://github.com/Nam088/skey"

  depends_on macos: ">= :sonoma"

  app "SKey.app"

  uninstall quit: "com.nam088.skey"

  zap trash: [
    "~/Library/Application Support/com.nam088.skey",
    "~/Library/Caches/com.nam088.skey",
    "~/Library/Preferences/com.nam088.skey.plist",
    "~/Library/Saved Application State/com.nam088.skey.savedState",
  ]
end

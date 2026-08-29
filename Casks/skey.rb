cask "skey" do
  version "1.0.11"

  # CASK_ARCH_URLS_START
  on_arm do
    sha256 "28cfaafcb6e2c72878b8ab8f98944fb3ccd5e2aa32cc2631258e02834cac70f1"

    url "https://github.com/Nam088/skey/releases/download/v1.0.11/SKey-Installer.dmg"
  end
  on_intel do
    sha256 "28cfaafcb6e2c72878b8ab8f98944fb3ccd5e2aa32cc2631258e02834cac70f1"

    url "https://github.com/Nam088/skey/releases/download/v1.0.11/SKey-Installer.dmg"
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

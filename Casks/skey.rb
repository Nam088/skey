cask "skey" do
  version "1.0.9"

  # CASK_ARCH_URLS_START
  on_arm do
    sha256 "9b2f21b5dfa3e2e112f780edafe86e8107c54a8a59d7fdcffcb6be683b4cd1a6"

    url "https://github.com/Nam088/skey/releases/download/v1.0.9/SKey-Installer.dmg"
  end
  on_intel do
    sha256 "9b2f21b5dfa3e2e112f780edafe86e8107c54a8a59d7fdcffcb6be683b4cd1a6"

    url "https://github.com/Nam088/skey/releases/download/v1.0.9/SKey-Installer.dmg"
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

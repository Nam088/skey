cask "skey" do
  version "1.0.12"

  # CASK_ARCH_URLS_START
  on_arm do
    sha256 "98a1f4ee41f95721a5e4bb976a961136912d3511d4759f4a92ef428c206effab"

    url "https://github.com/Nam088/skey/releases/download/v1.0.12/SKey-Installer.dmg"
  end
  on_intel do
    sha256 "98a1f4ee41f95721a5e4bb976a961136912d3511d4759f4a92ef428c206effab"

    url "https://github.com/Nam088/skey/releases/download/v1.0.12/SKey-Installer.dmg"
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

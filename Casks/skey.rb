cask "skey" do
  version "1.0.11"
  sha256 "1ade0069f5451e2003bff38d4ea1de61c037c4bf94837efdfab8e178f2a862f0"

  # Release tags are platform prefixed (mac-v1.0.10). The previous "v#{version}" form
  # pointed at tags that have never existed, so every brew install fetched a 404.
  url "https://github.com/Nam088/skey/releases/download/mac-v#{version}/SKey-Installer.dmg"
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

---
kind: external_dependency
name: Distribution via Homebrew Cask
slug: homebrew-cask
category: external_dependency
category_hints:
    - vendor_identity
scope:
    - '**'
---

SKey is packaged as a Homebrew Cask (`skey.rb`) that installs `SKey.app` and declares system dependencies (`macos >= :sonoma`). Uninstall/zap targets the app bundle plus user data under `~/Library/Application Support/com.nam088.skey`, `~/Library/Caches/com.nam088.skey`, `~/Library/Preferences/com.nam088.skey.plist`, and saved state. The cask pulls the installer DMG from GitHub Releases, so publishing a new tag triggers a new cask version.
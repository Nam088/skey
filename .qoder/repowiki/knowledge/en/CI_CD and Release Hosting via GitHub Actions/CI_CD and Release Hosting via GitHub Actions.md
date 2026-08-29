---
kind: external_dependency
name: CI/CD and Release Hosting via GitHub Actions
slug: github-actions
category: external_dependency
category_hints:
    - vendor_identity
scope:
    - '**'
---

The project uses GitHub Actions as its CI/CD platform to build universal macOS binaries (Apple Silicon + Intel) on `macos-26` runners, auto-tag semantic versions from commit messages, generate release notes, and publish artifacts (`.dmg`, `.zip`, `SHA256SUMS.txt`) via `softprops/action-gh-release@v2`. The Homebrew cask (`Casks/skey.rb`) points at releases hosted under `https://github.com/Nam088/skey/releases/download/vX.Y.Z/SKey-Installer.dmg`, making GitHub Releases the distribution channel for end users.
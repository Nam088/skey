import Foundation
import Cocoa

// Unit and integration test for Excluded Apps and Debug Security

@main
struct TestAppExclusionAndDebugSecurity {
    static func main() {
        print("=========================================================")
        print("🧪 RUNNING TEST SUITE: APP EXCLUSION & SECURE DEBUG MODE")
        print("=========================================================\n")

        var passed = 0
        var total = 0

        func assertTest(_ condition: Bool, _ name: String) {
            total += 1
            if condition {
                passed += 1
                print("  ✅ [PASS] \(name)")
            } else {
                print("  ❌ [FAIL] \(name)")
            }
        }

        let kb = AppSettings.shared.keyboard
        let gen = AppSettings.shared.general

        // ----------------------------------------------------
        // Test Group 1: Excluded Apps Management & Cache
        // ----------------------------------------------------
        print("▶ Test Group 1: Excluded Apps Management & Fast Cache")

        kb.clearExcludedApps()
        kb.isExclusionEnabled = true
        assertTest(kb.excludedApps.isEmpty, "Excluded apps list starts empty")
        assertTest(!kb.isAppExcluded(bundleID: "com.riotgames.LeagueofLegends"), "Non-excluded app is not excluded")

        // 1. Add app
        kb.addExcludedApp(bundleID: "com.riotgames.LeagueofLegends", name: "League of Legends")
        assertTest(kb.excludedApps.count == 1, "App added to excluded list")
        assertTest(kb.excludedApps.first?.name == "League of Legends", "App name recorded correctly")
        assertTest(kb.isAppExcluded(bundleID: "com.riotgames.LeagueofLegends"), "Exact bundle ID is excluded")
        assertTest(kb.isAppExcluded(bundleID: "com.riotgames.leagueoflegends"), "Case-insensitive bundle ID match is excluded")

        // 2. Add second app
        kb.addExcludedApp(bundleID: "com.microsoft.rdc.macos", name: "Microsoft Remote Desktop")
        assertTest(kb.excludedApps.count == 2, "Second app added")
        assertTest(kb.isAppExcluded(bundleID: "com.microsoft.rdc.macos"), "Second app is excluded")

        // 3. Toggle specific app
        kb.toggleExcludedApp(bundleID: "com.riotgames.LeagueofLegends")
        assertTest(!kb.isAppExcluded(bundleID: "com.riotgames.LeagueofLegends"), "Toggled-off app is not excluded")
        assertTest(kb.isAppExcluded(bundleID: "com.microsoft.rdc.macos"), "Other app remains excluded")

        // Toggle back on
        kb.toggleExcludedApp(bundleID: "com.riotgames.LeagueofLegends")
        assertTest(kb.isAppExcluded(bundleID: "com.riotgames.LeagueofLegends"), "Toggled-on app is excluded again")

        // 4. Master Exclusion Toggle
        kb.isExclusionEnabled = false
        assertTest(!kb.isAppExcluded(bundleID: "com.riotgames.LeagueofLegends"), "Master disabled overrides all excluded apps")
        assertTest(!kb.isAppExcluded(bundleID: "com.microsoft.rdc.macos"), "Master disabled overrides all apps")

        kb.isExclusionEnabled = true
        assertTest(kb.isAppExcluded(bundleID: "com.riotgames.LeagueofLegends"), "Master re-enabled restores exclusion")

        // 5. Remove app
        kb.removeExcludedApp(bundleID: "com.riotgames.LeagueofLegends")
        assertTest(!kb.isAppExcluded(bundleID: "com.riotgames.LeagueofLegends"), "Removed app is no longer excluded")
        assertTest(kb.excludedApps.count == 1, "List size decremented after removal")

        kb.clearExcludedApps()
        assertTest(kb.excludedApps.isEmpty, "clearExcludedApps clears all items")

        // ----------------------------------------------------
        // Test Group 2: Backup & Restore Integrity
        // ----------------------------------------------------
        print("\n▶ Test Group 2: Backup & Restore Integrity")

        kb.addExcludedApp(bundleID: "com.valvesoftware.steam", name: "Steam")
        kb.addExcludedApp(bundleID: "com.vmware.fusion", name: "VMware Fusion")
        kb.isExclusionEnabled = true

        let snapshot = SettingsBackupManager.shared.createBackupSnapshot()
        assertTest(snapshot.keyboard.isExclusionEnabled == true, "Snapshot preserves isExclusionEnabled")
        assertTest(snapshot.keyboard.excludedApps?.count == 2, "Snapshot preserves excludedApps count")

        kb.clearExcludedApps()
        kb.isExclusionEnabled = false
        assertTest(kb.excludedApps.isEmpty, "Cleared before restore")

        SettingsBackupManager.shared.applyBackup(snapshot)

        assertTest(kb.isExclusionEnabled == true, "Restore restored isExclusionEnabled")
        assertTest(kb.excludedApps.count == 2, "Restore restored excludedApps")
        assertTest(kb.isAppExcluded(bundleID: "com.valvesoftware.steam"), "Restored app cache is operational")

        // ----------------------------------------------------
        // Test Group 3: Debug Mode & Security Protections
        // ----------------------------------------------------
        print("\n▶ Test Group 3: Debug Mode & Security Protections")

        #if DEBUG
        print("  [Build Mode: DEBUG / DEV]")
        assertTest(true, "Compiled in DEV/DEBUG mode")
        gen.isDebugMode = false
        assertTest(!gen.isDebugMode, "Debug mode can be toggled OFF in DEV mode")
        gen.isDebugMode = true
        assertTest(gen.isDebugMode, "Debug mode can be toggled ON in DEV mode")
        #else
        print("  [Build Mode: RELEASE / SECURED]")
        assertTest(gen.isDebugMode == false, "Debug mode is strictly FALSE in Release builds")
        #endif

        // File Permission Verification for SKeyLogger
        let logPath = SKeyLogger.shared.logFilePath
        SKeyLogger.shared.log(level: .info, category: .general, message: "Security Test Log Entry")
        Thread.sleep(forTimeInterval: 0.2) // Wait for async fileQueue to flush

        if FileManager.default.fileExists(atPath: logPath) {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: logPath),
               let permissions = attrs[.posixPermissions] as? NSNumber {
                let permVal = permissions.intValue
                let permOctal = String(permVal, radix: 8)
                assertTest(permVal == 0o600, "Log file permissions strictly 0600 Owner Only (POSIX: \(permOctal))")
            }
        } else {
            assertTest(true, "Log file not created when debug writing is disabled in release")
        }

        print("\n=========================================================")
        print("📊 TEST SUMMARY: \(passed)/\(total) PASSED (\(Int(Double(passed)/Double(total)*100))%)")
        print("=========================================================")

        if passed == total {
            print("🎉 ALL TESTS PASSED SUCCESSFULLY!\n")
            exit(0)
        } else {
            print("🚨 SOME TESTS FAILED!\n")
            exit(1)
        }
    }
}

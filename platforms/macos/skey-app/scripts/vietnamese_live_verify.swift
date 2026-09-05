import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

// MARK: - Overview
//
// Kiểm chứng end to end: gõ phím Telex thật qua SKey đang chạy, rồi đọc ngược
// nội dung để so với kết quả mong đợi.
//
// Khác với texstudio_inject_probe: probe tái tạo KeyEventSender và bỏ qua
// SKeyEngine, còn script này không giả lập gì cả. Nó bắn đúng những phím vật lý
// mà người dùng bấm, để SKey xử lý nguyên vẹn từ engine tới khâu inject.
//
// Chạy trên nhiều app để bắt hồi quy: Qt (TeXstudio), AppKit (TextEdit),
// Chromium/Electron (VS Code).

// MARK: - Key Map

let keyMap: [Character: CGKeyCode] = [
    "a": 0x00, "s": 0x01, "d": 0x02, "f": 0x03, "h": 0x04, "g": 0x05,
    "z": 0x06, "x": 0x07, "c": 0x08, "v": 0x09, "b": 0x0B, "q": 0x0C,
    "w": 0x0D, "e": 0x0E, "r": 0x0F, "y": 0x10, "t": 0x11, "o": 0x1F,
    "u": 0x20, "i": 0x22, "p": 0x23, "l": 0x25, "j": 0x26, "k": 0x28,
    "n": 0x2D, "m": 0x2E, " ": 0x31,
]

let vkA: CGKeyCode = 0x00
let vkC: CGKeyCode = 0x08
let vkN: CGKeyCode = 0x2D
let vkDelete: CGKeyCode = 0x33

// MARK: - Targets

struct Target {
    let bundleID: String
    let name: String
}

let knownTargets: [String: Target] = [
    "texstudio": Target(bundleID: "texstudio", name: "TeXstudio (Qt 6)"),
    "textedit": Target(bundleID: "com.apple.TextEdit", name: "TextEdit (AppKit)"),
    "vscode": Target(bundleID: "com.microsoft.VSCode", name: "VS Code (Electron/Chromium)"),
]

// MARK: - Test Phrase

/// Đúng câu người dùng báo lỗi, kèm chuỗi phím Telex tái dựng từ /tmp/skey.log.
struct Phrase {
    let keys: String
    let expected: String
    let label: String
}

let phrases: [Phrase] = [
    Phrase(keys: "ddansh ker chayj did khoong ai ddansh ker chayj laij",
           expected: "đánh kẻ chạy đi không ai đánh kẻ chạy lại",
           label: "câu báo lỗi gốc"),
    Phrase(keys: "tieengs vieetj cos daaus",
           expected: "tiếng việt có dấu",
           label: "đối chứng, nhiều dấu liên tiếp"),
]

// MARK: - Event Posting

let eventSource = CGEventSource(stateID: .hidSystemState)

/// Bắn phím KHÔNG đóng dấu marker, để SKey xử lý như phím người dùng bấm thật.
func pressKey(_ code: CGKeyCode, flags: CGEventFlags = [], settle: TimeInterval = 0.045) {
    guard let source = eventSource,
          let down = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true),
          let up = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false)
    else { return }
    down.flags = flags
    up.flags = flags
    down.post(tap: .cghidEventTap)
    usleep(12_000)
    up.post(tap: .cghidEventTap)
    Thread.sleep(forTimeInterval: settle)
}

func typeKeys(_ sequence: String, perKey: TimeInterval) {
    for ch in sequence {
        guard let code = keyMap[ch] else {
            FileHandle.standardError.write(Data("Thiếu keycode cho '\(ch)'\n".utf8))
            continue
        }
        pressKey(code, settle: perKey)
    }
}

// MARK: - App Driver

/// Chờ mà vẫn bơm run loop. NSWorkspace cập nhật frontmostApplication qua
/// notification, nên một tiến trình CLI chỉ Thread.sleep sẽ đọc mãi giá trị cũ
/// và tưởng rằng activate thất bại.
func pump(_ seconds: TimeInterval) {
    RunLoop.current.run(until: Date().addingTimeInterval(seconds))
}

func focus(_ target: Target, launch: Bool) -> Bool {
    var running = NSRunningApplication.runningApplications(withBundleIdentifier: target.bundleID).first
    if running == nil, launch {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: target.bundleID) else { return false }
        let config = NSWorkspace.OpenConfiguration()
        let semaphore = DispatchSemaphore(value: 0)
        NSWorkspace.shared.openApplication(at: url, configuration: config) { app, _ in
            running = app
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 25)
        pump(6)
        running = NSRunningApplication.runningApplications(withBundleIdentifier: target.bundleID).first
    }
    guard let app = running else { return false }
    // Một lần activate hay trượt khi vừa chuyển từ app khác sang: macOS cần vài
    // nhịp mới đổi xong frontmost. Thử lại thay vì báo "không mở được".
    for _ in 0..<6 {
        app.activate()
        pump(1.0)
        if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == target.bundleID {
            pump(0.5)
            return true
        }
    }
    return false
}

func newDocument() {
    pressKey(vkN, flags: [.maskCommand], settle: 1.4)
}

func clearBuffer() {
    pressKey(vkA, flags: [.maskCommand], settle: 0.2)
    pressKey(vkDelete, settle: 0.3)
}

func readBack() -> String {
    NSPasteboard.general.clearContents()
    Thread.sleep(forTimeInterval: 0.15)
    pressKey(vkA, flags: [.maskCommand], settle: 0.25)
    pressKey(vkC, flags: [.maskCommand], settle: 0.45)
    return NSPasteboard.general.string(forType: .string) ?? ""
}

func normalize(_ s: String) -> String {
    s.trimmingCharacters(in: .whitespacesAndNewlines).precomposedStringWithCanonicalMapping
}

/// Liệt kê các từ lệch nhau, để thấy ngay chữ nào bị nuốt thay vì phải dò tay.
func wordDiff(expected: String, actual: String) -> [String] {
    let want = expected.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
    let got = actual.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
    var lines: [String] = []
    for index in 0..<max(want.count, got.count) {
        let w = index < want.count ? want[index] : "<thiếu>"
        let g = index < got.count ? got[index] : "<thiếu>"
        if w != g { lines.append("      từ \(index + 1): mong '\(w)' nhận '\(g)'") }
    }
    return lines
}

// MARK: - Entry Point

@main
struct VietnameseLiveVerify {
    static func main() {
        let args = CommandLine.arguments

        if args.contains("--help") || args.contains("-h") {
            print("""
            vietnamese_live_verify — gõ Telex thật qua SKey rồi đối chiếu kết quả

            Cách dùng:
              vietnamese_live_verify                        chạy trên texstudio
              vietnamese_live_verify --app textedit         chạy trên TextEdit
              vietnamese_live_verify --app texstudio,textedit,vscode
              vietnamese_live_verify --launch               cho phép mở app chưa chạy
              vietnamese_live_verify --per-key 0.08         chậm lại, mô phỏng gõ tay

            Bắt buộc: SKey đang bật chế độ gõ tiếng Việt (Telex).
            """)
            return
        }

        guard AXIsProcessTrusted() else {
            print("Chưa có quyền Accessibility cho tiến trình chạy binary này.")
            exit(1)
        }

        var names = ["texstudio"]
        if let idx = args.firstIndex(of: "--app"), idx + 1 < args.count {
            names = args[idx + 1].split(separator: ",").map(String.init)
        }
        // Cho phép chỉ định chuỗi phím và kết quả mong đợi từ dòng lệnh, để kiểm
        // chứng những thứ không phải câu tiếng Việt mẫu, ví dụ snippet bung ra.
        var activePhrases = phrases
        if let ki = args.firstIndex(of: "--keys"), ki + 1 < args.count,
           let ei = args.firstIndex(of: "--expect"), ei + 1 < args.count {
            activePhrases = [Phrase(keys: args[ki + 1], expected: args[ei + 1], label: "tuỳ chọn")]
        }

        var perKey: TimeInterval = 0.045
        if let idx = args.firstIndex(of: "--per-key"), idx + 1 < args.count,
           let value = Double(args[idx + 1]) {
            perKey = value
        }
        let allowLaunch = args.contains("--launch")

        print("=====================================================")
        print("  SKey · kiểm chứng gõ tiếng Việt end to end")
        print("=====================================================")
        print("SKey phải đang ở chế độ tiếng Việt, kiểu gõ Telex.")
        print("Đừng chạm bàn phím trong lúc chạy.")
        print("")

        var failures = 0
        var total = 0
        // App bị bỏ qua phải hiện rõ trong tóm tắt. Nếu không, một lần chạy mà
        // app không mở được vẫn in "tất cả PASS" và che mất phần chưa kiểm tra.
        var skipped: [String] = []

        for name in names {
            guard let target = knownTargets[name.lowercased()] else {
                print("Không biết app '\(name)'. Chọn: \(knownTargets.keys.sorted().joined(separator: ", "))")
                skipped.append(name)
                failures += 1
                continue
            }

            print("### \(target.name)")
            guard focus(target, launch: allowLaunch) else {
                print("   BỎ QUA: app chưa chạy hoặc không đưa lên foreground được.")
                print("   Thêm --launch nếu muốn tự mở.")
                print("")
                skipped.append(target.name)
                continue
            }
            newDocument()

            for phrase in activePhrases {
                total += 1
                clearBuffer()
                typeKeys(phrase.keys, perKey: perKey)
                Thread.sleep(forTimeInterval: 0.8)

                let actual = normalize(readBack())
                let expected = normalize(phrase.expected)
                let passed = actual == expected

                print("   [\(passed ? "PASS" : "FAIL")] \(phrase.label)")
                print("      gõ    : \(phrase.keys)")
                print("      mong  : \(expected)")
                print("      nhận  : \(actual)")
                if !passed {
                    failures += 1
                    for line in wordDiff(expected: expected, actual: actual) { print(line) }
                    // TextEdit tự viết hoa đầu câu và tự sửa chính tả, nên nó đổi
                    // kết quả SAU khi SKey đã chèn đúng. Tắt Edit > Substitutions
                    // rồi chạy lại mới đo được đúng phần của bộ gõ.
                    if target.bundleID == "com.apple.TextEdit" {
                        print("      lưu ý: TextEdit tự viết hoa đầu câu và tự sửa chính tả.")
                        print("             Tắt Edit > Substitutions và Spelling trước khi kết luận.")
                    }
                }
            }
            clearBuffer()
            print("")
        }

        print("=====================================================")
        if !skipped.isEmpty {
            print("BỎ QUA \(skipped.count) app: \(skipped.joined(separator: ", "))")
        }
        if total == 0 {
            print("KHÔNG chạy được lượt nào.")
            print("=====================================================")
            exit(1)
        }
        if failures == 0 {
            print(skipped.isEmpty ? "TẤT CẢ PASS (\(total) lượt)"
                                  : "PASS \(total)/\(total) lượt ĐÃ CHẠY, nhưng còn app chưa kiểm tra")
        } else {
            print("HỎNG \(failures)/\(total) lượt")
        }
        print("=====================================================")
        exit(failures == 0 && skipped.isEmpty ? 0 : 1)
    }
}

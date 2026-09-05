import AppKit
import ApplicationServices
import CoreGraphics
import Darwin
import Darwin.sys.sysctl
import Foundation

// MARK: - Overview
//
// Diagnostic probe for the "TeXstudio nuốt mất chữ" bug.
//
// Symptom: gõ "đánh kẻ chạy đi không ai đánh kẻ chạy lại" trong TeXstudio ra
// "đh kẻ ch đi không ai đh kẻ ch l". So với /tmp/skey.log thì backspaces của
// KeyEventSender được TeXstudio áp dụng, nhưng chuỗi thay thế (án, ạy, ại)
// không bao giờ được chèn vào.
//
// Probe này KHÔNG dùng SKeyEngine. Nó tái tạo đúng cách KeyEventSender bắn
// sự kiện (cùng marker, cùng delay, cùng cách gói unicode), rồi đọc ngược nội
// dung editor qua clipboard để biết chính xác lần inject nào rơi mất.
//
// Mỗi case được chạy lại với nhiều biến thể phát sự kiện. Biến thể nào PASS
// trong khi baseline FAIL chính là bản vá cần đưa vào KeyEventSender.
//
// KHÔNG thêm chế độ benchmark bắn event không giới hạn vào đây. Bản trước có
// --bench chạy 40 lần x 7 độ dài x 4 cách phát, riêng mẫu 400 ký tự đã là hơn
// 100.000 CGEvent tổng hợp dồn vào WindowServer, và nó treo cả máy tới mức phải
// tắt cứng. Mọi phép đo về sau phải chặn trần số event và nghỉ giữa các vòng.

// MARK: - Constants

enum VK {
    static let a: CGKeyCode = 0x00
    static let c: CGKeyCode = 0x08
    static let v: CGKeyCode = 0x09
    static let n: CGKeyCode = 0x2D
    static let f17: CGKeyCode = 0x40
    static let delete: CGKeyCode = 0x33
}

/// Marker "SKEY" mà EventTapManager dùng để bỏ qua sự kiện do chính app sinh ra.
/// Probe cũng đóng dấu này để SKey không xử lý lại các sự kiện của probe.
let skeyMarker: Int64 = 0x534B_4559

/// Delay hiện tại trong KeyConstants.swift.
let interBackspaceDelayUs: useconds_t = 1_200
let settleDelayUs: useconds_t = 2_000

/// App đích. Mặc định TeXstudio, đổi được bằng --app để chạy A/B thuật toán cũ
/// và mới trên app khác, phục vụ kiểm tra hồi quy.
var targetBundleID = "texstudio"
var targetName = "TeXstudio (Qt 6)"

let knownTargets: [String: (id: String, name: String)] = [
    "texstudio": ("texstudio", "TeXstudio (Qt 6)"),
    "textedit": ("com.apple.TextEdit", "TextEdit (AppKit)"),
    "vscode": ("com.microsoft.VSCode", "VS Code (Electron/Chromium)"),
    "notes": ("com.apple.Notes", "Notes (AppKit)"),
]

// MARK: - Case Model

struct ProbeCase {
    /// Nội dung editor ngay trước khi inject (đúng buffer thật lúc gõ).
    let seed: String
    let backspaces: Int
    let text: String
    let label: String

    var expected: String { String(seed.dropLast(backspaces)) + text }
}

/// Các case rút từ /tmp/skey.log của phiên gõ bị lỗi, kèm case đối chứng đã chạy đúng.
let defaultCases: [ProbeCase] = [
    ProbeCase(seed: "d",    backspaces: 1, text: "đ",  label: "đánh  · dd  → đ   (log 09:53:49.544, OK trên máy user)"),
    ProbeCase(seed: "đan",  backspaces: 2, text: "án", label: "đánh  · s   → án  (log 09:53:49.879, MẤT trên máy user)"),
    ProbeCase(seed: "ke",   backspaces: 1, text: "ẻ",  label: "kẻ    · r   → ẻ   (log 09:53:50.562, OK)"),
    ProbeCase(seed: "chay", backspaces: 2, text: "ạy", label: "chạy  · j   → ạy  (log 09:53:51.336, MẤT)"),
    ProbeCase(seed: "di",   backspaces: 2, text: "đi", label: "đi    · d   → đi  (log 09:53:51.755, OK)"),
    ProbeCase(seed: "khoo", backspaces: 1, text: "ô",  label: "không · o   → ô   (log 09:53:52.631, OK)"),
    ProbeCase(seed: "lai",  backspaces: 2, text: "ại", label: "lại   · j   → ại  (log 09:53:56.976, MẤT)"),
]

// MARK: - Variants

/// Một cách phát sự kiện. Trả về true nếu phát được.
struct Variant {
    let id: String
    let detail: String
    let run: (Int, String) -> Void
}

// MARK: - Event Primitives

let eventSource = CGEventSource(stateID: .hidSystemState)

@inline(__always)
func stamp(_ event: CGEvent) {
    event.setIntegerValueField(.eventSourceUserData, value: skeyMarker)
    event.timestamp = mach_absolute_time()
}

/// Gửi một cặp keyDown/keyUp thuần (không unicode string).
func postKey(_ keyCode: CGKeyCode, flags: CGEventFlags = [], tap: CGEventTapLocation = .cgSessionEventTap, marked: Bool = true) {
    guard let source = eventSource,
          let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
          let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
    else { return }
    down.flags = flags.isEmpty ? [.maskNonCoalesced] : flags
    up.flags = flags.isEmpty ? [.maskNonCoalesced] : flags
    if marked { stamp(down); stamp(up) }
    down.post(tap: tap)
    up.post(tap: tap)
}

/// Bản sao nguyên văn `KeyEventSender.sendBackspaces`.
func sendBackspaces(_ count: Int, tap: CGEventTapLocation = .cgSessionEventTap, settleUs: useconds_t = settleDelayUs) {
    guard count > 0 else { return }
    for _ in 0..<count {
        postKey(VK.delete, tap: tap)
        usleep(interBackspaceDelayUs)
    }
    usleep(settleUs)
}

/// Bản sao nguyên văn `KeyEventSender.sendText`, có tham số hoá để thử biến thể.
func sendUnicode(_ text: String,
                 virtualKey: CGKeyCode = 0,
                 tap: CGEventTapLocation = .cgSessionEventTap,
                 unicodeOnKeyUp: Bool = false) {
    let units = Array(text.utf16)
    guard !units.isEmpty, let source = eventSource else { return }
    guard let down = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: true),
          let up = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: false)
    else { return }
    down.flags = [.maskNonCoalesced]
    up.flags = [.maskNonCoalesced]
    units.withUnsafeBufferPointer { buffer in
        guard let base = buffer.baseAddress else { return }
        down.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: base)
        if unicodeOnKeyUp {
            up.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: base)
        }
    }
    stamp(down); stamp(up)
    down.post(tap: tap)
    up.post(tap: tap)
}

// MARK: - Variant Table

let variants: [Variant] = [
    Variant(id: "V0-baseline",
            detail: "Y hệt KeyEventSender hiện tại (vk=0, session tap, settle 2ms, 1 event cho cả chuỗi)",
            run: { bs, text in
                sendBackspaces(bs)
                sendUnicode(text)
            }),
    Variant(id: "V1-settle25ms",
            detail: "Giống baseline nhưng chờ 25ms sau backspaces trước khi chèn",
            run: { bs, text in
                sendBackspaces(bs, settleUs: 25_000)
                sendUnicode(text)
            }),
    Variant(id: "V2-hidtap",
            detail: "Bắn cả backspaces lẫn text vào cghidEventTap thay vì cgSessionEventTap",
            run: { bs, text in
                sendBackspaces(bs, tap: .cghidEventTap)
                sendUnicode(text, tap: .cghidEventTap)
            }),
    Variant(id: "V3-vkF17",
            detail: "Dùng virtualKey 0x40 (F17, phím không sinh ký tự) thay cho virtualKey 0 (phím A)",
            run: { bs, text in
                sendBackspaces(bs)
                sendUnicode(text, virtualKey: VK.f17)
            }),
    Variant(id: "V4-perChar",
            detail: "Mỗi ký tự một CGEvent riêng, cách nhau 1ms",
            run: { bs, text in
                sendBackspaces(bs)
                for ch in text {
                    sendUnicode(String(ch))
                    usleep(1_000)
                }
            }),
    Variant(id: "V5-upAlsoUnicode",
            detail: "Đặt unicodeString lên cả keyUp (cách cũ, gây nhân đôi trên Chromium)",
            run: { bs, text in
                sendBackspaces(bs)
                sendUnicode(text, unicodeOnKeyUp: true)
            }),
    Variant(id: "V6-textOnly",
            detail: "Không backspace, chỉ chèn text — tách bạch lỗi chèn với lỗi thứ tự",
            run: { _, text in
                sendUnicode(text)
            }),
    Variant(id: "V7-bsOnly",
            detail: "Chỉ backspace, không chèn text — xác nhận backspace luôn tới nơi",
            run: { bs, _ in
                sendBackspaces(bs)
            }),
    // V8..V10 dò delay tối thiểu giữa các ký tự. Delay càng nhỏ thì macro và
    // snippet dài càng ít giật, nên cần biết ngưỡng thấp nhất còn chạy đúng.
    Variant(id: "V8-perChar0us",
            detail: "Mỗi ký tự một CGEvent, KHÔNG delay",
            run: { bs, text in
                sendBackspaces(bs)
                for ch in text { sendUnicode(String(ch)) }
            }),
    Variant(id: "V9-perChar200us",
            detail: "Mỗi ký tự một CGEvent, cách nhau 200µs",
            run: { bs, text in
                sendBackspaces(bs)
                for ch in text {
                    sendUnicode(String(ch))
                    usleep(200)
                }
            }),
    Variant(id: "V10-perChar500us",
            detail: "Mỗi ký tự một CGEvent, cách nhau 500µs",
            run: { bs, text in
                sendBackspaces(bs)
                for ch in text {
                    sendUnicode(String(ch))
                    usleep(500)
                }
            }),
]



// MARK: - TCC Attribution

/// macOS gán quyền Accessibility cho "responsible process", không phải cho file
/// binary rời. Một binary chạy từ terminal sẽ được quy về chính app terminal đó.
/// Hàm này leo ngược cây tiến trình để tìm app bundle chịu trách nhiệm, nhờ vậy
/// thông báo lỗi chỉ đúng thứ cần cấp quyền thay vì chỉ vào đường dẫn binary.
func responsibleAppPath() -> String? {
    var pid = getpid()
    for _ in 0..<12 {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        guard sysctl(&mib, 4, &info, &size, nil, 0) == 0, size > 0 else { return nil }
        let parent = info.kp_eproc.e_ppid
        guard parent > 1 else { return nil }

        var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
        guard proc_pidpath(parent, &buffer, UInt32(PATH_MAX)) > 0 else { return nil }
        let path = String(cString: buffer)
        if let range = path.range(of: ".app/Contents/MacOS/") {
            return String(path[path.startIndex..<range.lowerBound]) + ".app"
        }
        pid = parent
    }
    return nil
}

// MARK: - TeXstudio Driver

enum Driver {
    static func focusTeXstudio() -> NSRunningApplication? {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: targetBundleID).first else {
            return nil
        }
        app.activate()
        Thread.sleep(forTimeInterval: 0.6)
        guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == targetBundleID else { return nil }
        return app
    }

    static func newDocument() {
        postKey(VK.n, flags: [.maskCommand])
        Thread.sleep(forTimeInterval: 0.7)
    }

    /// Nạp seed bằng clipboard paste. Paste đi thẳng vào editor, không qua bộ gõ,
    /// nên trạng thái ban đầu của mỗi lần thử luôn sạch và xác định.
    static func loadSeed(_ seed: String) {
        selectAll()
        postKey(VK.delete)
        Thread.sleep(forTimeInterval: 0.15)
        guard !seed.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(seed, forType: .string)
        Thread.sleep(forTimeInterval: 0.12)
        postKey(VK.v, flags: [.maskCommand])
        Thread.sleep(forTimeInterval: 0.35)
    }

    static func selectAll() {
        postKey(VK.a, flags: [.maskCommand])
        Thread.sleep(forTimeInterval: 0.15)
    }

    static func readBack() -> String {
        NSPasteboard.general.clearContents()
        Thread.sleep(forTimeInterval: 0.1)
        selectAll()
        postKey(VK.c, flags: [.maskCommand])
        Thread.sleep(forTimeInterval: 0.35)
        return NSPasteboard.general.string(forType: .string) ?? ""
    }
}

// MARK: - Log Parsing

/// Rút các cặp (backspaces, text) thật từ /tmp/skey.log để replay lại.
func casesFromLog(path: String, limit: Int) -> [ProbeCase] {
    guard let raw = try? String(contentsOfFile: path, encoding: .utf8) else {
        FileHandle.standardError.write(Data("Không đọc được \(path)\n".utf8))
        return []
    }
    var result: [ProbeCase] = []
    for line in raw.split(separator: "\n") {
        guard line.contains("[KeyEventSender] inject called") else { continue }
        guard let bsRange = line.range(of: "backspaces="),
              let textRange = line.range(of: ", text='"),
              let closeRange = line.range(of: "' (count=")
        else { continue }
        let bsString = line[bsRange.upperBound..<textRange.lowerBound]
        guard let bs = Int(bsString) else { continue }
        let text = String(line[textRange.upperBound..<closeRange.lowerBound])
        // Không biết buffer thật, dựng seed trung tính đủ dài để backspace không tràn.
        let seed = "T" + String(repeating: "x", count: max(bs, 1))
        result.append(ProbeCase(seed: seed, backspaces: bs, text: text,
                                label: "log · bs=\(bs) text='\(text)'"))
    }
    return Array(result.suffix(limit))
}

// MARK: - Reporting

struct Trial {
    let caseLabel: String
    let variantID: String
    let expected: String
    let actual: String
    var passed: Bool { actual == expected }
}

func normalize(_ s: String) -> String {
    s.trimmingCharacters(in: .whitespacesAndNewlines).precomposedStringWithCanonicalMapping
}

// MARK: - Entry Point

@main
struct TeXstudioInjectProbe {
    static func main() {
        let args = CommandLine.arguments

        if args.contains("--help") || args.contains("-h") {
            printUsage()
            return
        }

        if let idx = args.firstIndex(of: "--app"), idx + 1 < args.count {
            guard let picked = knownTargets[args[idx + 1].lowercased()] else {
                print("Không biết app '\(args[idx + 1])'. Chọn: \(knownTargets.keys.sorted().joined(separator: ", "))")
                exit(1)
            }
            targetBundleID = picked.id
            targetName = picked.name
        }

        var cases = defaultCases
        if let idx = args.firstIndex(of: "--from-log") {
            let limit = (idx + 1 < args.count ? Int(args[idx + 1]) : nil) ?? 12
            cases = casesFromLog(path: "/tmp/skey.log", limit: limit)
            guard !cases.isEmpty else {
                print("Không tìm thấy dòng inject nào trong /tmp/skey.log.")
                print("Bật Debug Mode trong SKey rồi gõ lại để log được ghi.")
                exit(1)
            }
        }

        // --long đo chi phí của chuỗi dài cỡ macro/snippet, nơi việc tách từng
        // ký tự đắt nhất. Dùng để chọn delay và quyết có cần ngưỡng paste không.
        if args.contains("--long") {
            let short = "Trân trọng cảm ơn quý khách"
            let long = "Kính gửi anh chị, tôi xin xác nhận đã nhận được yêu cầu và sẽ phản hồi trong hôm nay."
            cases = [
                ProbeCase(seed: "Tx", backspaces: 1, text: short,
                          label: "macro ngắn · \(short.count) ký tự"),
                ProbeCase(seed: "Tx", backspaces: 1, text: long,
                          label: "snippet dài · \(long.count) ký tự"),
            ]
        }

        var selectedVariants = variants
        if let idx = args.firstIndex(of: "--variants"), idx + 1 < args.count {
            let wanted = Set(args[idx + 1].split(separator: ",").map(String.init))
            selectedVariants = variants.filter { v in wanted.contains(where: { v.id.hasPrefix($0) }) }
        }
        if args.contains("--baseline-only") {
            selectedVariants = Array(variants.prefix(1))
        }

        // --check chỉ kiểm tra điều kiện, không gõ gì cả. Chạy cái này trước
        // để biết chắc probe sẽ không dừng giữa chừng.
        if args.contains("--check") {
            let trusted = AXIsProcessTrusted()
            let texRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: targetBundleID).isEmpty
            let logExists = FileManager.default.fileExists(atPath: "/tmp/skey.log")
            let owner = responsibleAppPath() ?? args[0]
            print("Quyền Accessibility : \(trusted ? "OK" : "THIẾU")")
            if !trusted {
                print("  Cấp cho          : \(owner)")
                print("  (macOS quy quyền về app chạy binary này, không phải binary)")
            }
            print("App đích            : \(targetName) \(texRunning ? "đang chạy" : "KHÔNG chạy")")
            print("/tmp/skey.log       : \(logExists ? "có" : "chưa có (bật Debug Mode trong SKey)")")
            print("Số case sẽ chạy     : \(cases.count) × \(selectedVariants.count) biến thể")
            exit(trusted && texRunning ? 0 : 1)
        }

        guard AXIsProcessTrusted() else {
            let owner = responsibleAppPath() ?? args[0]
            print("Chưa có quyền Accessibility.")
            print("macOS gán quyền cho app đang chạy binary này, không gán cho binary.")
            print("Mở System Settings > Privacy & Security > Accessibility, bật cho:")
            print("  \(owner)")
            print("Bật xong phải thoát hẳn app đó rồi mở lại thì quyền mới có hiệu lực.")
            exit(1)
        }

        print("=====================================================")
        print("  SKey · TeXstudio inject probe")
        print("=====================================================")
        print("App đích: \(targetName)")
        print("Cases:    \(cases.count)")
        print("Variants: \(selectedVariants.count)")
        print("Tổng số lần thử: \(cases.count * selectedVariants.count)")
        print("")
        print("LƯU Ý: probe mở một tab mới (Cmd+N) trong TeXstudio và chỉ")
        print("gõ trong tab đó. Tài liệu đang mở không bị đụng tới.")
        print("Đừng chạm chuột/bàn phím trong lúc probe chạy.")
        print("")

        guard Driver.focusTeXstudio() != nil else {
            print("\(targetName) chưa chạy hoặc không đưa được lên foreground.")
            print("Mở TeXstudio trước rồi chạy lại.")
            exit(1)
        }
        Driver.newDocument()

        var trials: [Trial] = []

        for probeCase in cases {
            print("── \(probeCase.label)")
            for variant in selectedVariants {
                Driver.loadSeed(probeCase.seed)

                // Đo riêng thời gian phát sự kiện, không tính thời gian chờ app vẽ.
                // Đây là phần độc chiếm luồng gõ, tức phần người dùng cảm nhận là giật.
                let started = DispatchTime.now()
                variant.run(probeCase.backspaces, probeCase.text)
                let injectMs = Double(DispatchTime.now().uptimeNanoseconds - started.uptimeNanoseconds) / 1_000_000
                Thread.sleep(forTimeInterval: 0.45)

                let actual = normalize(Driver.readBack())
                let expected: String
                switch variant.id {
                case "V6-textOnly":
                    expected = normalize(probeCase.seed + probeCase.text)
                case "V7-bsOnly":
                    expected = normalize(String(probeCase.seed.dropLast(probeCase.backspaces)))
                default:
                    expected = normalize(probeCase.expected)
                }

                let trial = Trial(caseLabel: probeCase.label, variantID: variant.id,
                                  expected: expected, actual: actual)
                trials.append(trial)
                let mark = trial.passed ? "PASS" : "FAIL"
                print(String(format: "   %-18@ %@  %6.2fms  mong đợi '%@'  nhận '%@'",
                             variant.id as NSString, mark as NSString, injectMs,
                             expected as NSString, actual as NSString))
            }
            print("")
        }

        printSummary(trials: trials, variants: selectedVariants)
    }

    static func printSummary(trials: [Trial], variants: [Variant]) {
        print("=====================================================")
        print("  TỔNG KẾT THEO BIẾN THỂ")
        print("=====================================================")
        for variant in variants {
            let subset = trials.filter { $0.variantID == variant.id }
            let passed = subset.filter(\.passed).count
            let flag = passed == subset.count ? "✔" : (passed == 0 ? "✘" : "~")
            print("\(flag) \(variant.id): \(passed)/\(subset.count)")
            print("    \(variant.detail)")
            let failures = subset.filter { !$0.passed }
            for failure in failures {
                print("    FAIL: \(failure.caseLabel)")
            }
        }

        print("")
        print("=====================================================")
        print("  ĐỌC KẾT QUẢ")
        print("=====================================================")
        let baseline = trials.filter { $0.variantID == "V0-baseline" }
        let baselineFailures = baseline.filter { !$0.passed }
        if baselineFailures.isEmpty {
            print("Baseline không tái hiện được lỗi trong lần chạy này.")
            print("Thử tăng tốc độ gõ hoặc chạy lại khi TeXstudio đang bận")
            print("(mở file .tex lớn, bật syntax highlight) rồi chạy lại.")
        } else {
            print("Baseline hỏng \(baselineFailures.count)/\(baseline.count) case.")
            let fixes = variants.filter { v in
                v.id != "V0-baseline" && v.id != "V6-textOnly" && v.id != "V7-bsOnly" &&
                trials.filter { $0.variantID == v.id }.allSatisfy(\.passed)
            }
            if fixes.isEmpty {
                print("Chưa biến thể nào sửa được hết. Cần điều tra thêm.")
            } else {
                print("Biến thể sửa được toàn bộ case:")
                for fix in fixes {
                    print("  · \(fix.id) — \(fix.detail)")
                }
                print("")
                print("Đây là thay đổi cần áp vào KeyEventSender.swift.")
            }
        }
        let textOnly = trials.filter { $0.variantID == "V6-textOnly" }
        if !textOnly.isEmpty {
            let failed = textOnly.filter { !$0.passed }.count
            if failed == 0 {
                print("")
                print("V6 (chỉ chèn text, không backspace) PASS toàn bộ:")
                print("  → sự kiện unicode tự nó không có vấn đề, lỗi nằm ở")
                print("    chuỗi backspace ngay trước đó (thứ tự / thời gian).")
            } else {
                print("")
                print("V6 (chỉ chèn text) hỏng \(failed) case:")
                print("  → chính sự kiện unicode bị TeXstudio bỏ, không phải")
                print("    do backspace. Xem V3 (đổi virtualKey) và V4 (tách ký tự).")
            }
        }
    }

    static func printUsage() {
        print("""
        texstudio_inject_probe — dò lỗi mất chữ khi SKey inject vào TeXstudio

        Cách dùng:
          texstudio_inject_probe                     chạy bộ case mặc định (rút từ log lỗi)
          texstudio_inject_probe --baseline-only     chỉ chạy V0, xác nhận có tái hiện lỗi
          texstudio_inject_probe --from-log 12       replay 12 lần inject cuối trong /tmp/skey.log
          texstudio_inject_probe --variants V0,V3    chỉ chạy các biến thể chỉ định
          texstudio_inject_probe --check             chỉ kiểm tra điều kiện, không gõ gì

        Yêu cầu:
          · TeXstudio đang chạy
          · Binary này có quyền Accessibility
          · Không gõ phím / bấm chuột trong lúc probe chạy
        """)
    }
}

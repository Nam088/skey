import Carbon
import CoreGraphics
import Foundation

// MARK: - KeyConstants & Carbon Virtual Key Codes

public enum KeyConstants {
    /// 4-byte ASCII marker "SKEY" written into eventSourceUserData.
    public static let eventMarker: Int64 = 0x534B_4559

    // Standard high-performance timing delays (microseconds) for synthetic event delivery
    public static let interBackspaceDelayUs: useconds_t = 2_000   // 2 ms
    public static let settleDelayUs: useconds_t         = 3_500   // 3.5 ms
    public static let interChunkDelayUs: useconds_t     = 1_500   // 1.5 ms

    // Virtual Keycodes (from Carbon HIToolbox / Events.h)
    public static let kVK_ANSI_A: CGKeyCode = 0x00
    public static let kVK_ANSI_S: CGKeyCode = 0x01
    public static let kVK_ANSI_D: CGKeyCode = 0x02
    public static let kVK_ANSI_F: CGKeyCode = 0x03
    public static let kVK_ANSI_H: CGKeyCode = 0x04
    public static let kVK_ANSI_G: CGKeyCode = 0x05
    public static let kVK_ANSI_Z: CGKeyCode = 0x06
    public static let kVK_ANSI_X: CGKeyCode = 0x07
    public static let kVK_ANSI_C: CGKeyCode = 0x08
    public static let kVK_ANSI_V: CGKeyCode = 0x09
    public static let kVK_ANSI_B: CGKeyCode = 0x0B
    public static let kVK_ANSI_Q: CGKeyCode = 0x0C
    public static let kVK_ANSI_W: CGKeyCode = 0x0D
    public static let kVK_ANSI_E: CGKeyCode = 0x0E
    public static let kVK_ANSI_R: CGKeyCode = 0x0F
    public static let kVK_ANSI_Y: CGKeyCode = 0x10
    public static let kVK_ANSI_T: CGKeyCode = 0x11
    public static let kVK_ANSI_1: CGKeyCode = 0x12
    public static let kVK_ANSI_2: CGKeyCode = 0x13
    public static let kVK_ANSI_3: CGKeyCode = 0x14
    public static let kVK_ANSI_4: CGKeyCode = 0x15
    public static let kVK_ANSI_6: CGKeyCode = 0x16
    public static let kVK_ANSI_5: CGKeyCode = 0x17
    public static let kVK_ANSI_Equal: CGKeyCode = 0x18
    public static let kVK_ANSI_9: CGKeyCode = 0x19
    public static let kVK_ANSI_7: CGKeyCode = 0x1A
    public static let kVK_ANSI_Minus: CGKeyCode = 0x1B
    public static let kVK_ANSI_8: CGKeyCode = 0x1C
    public static let kVK_ANSI_0: CGKeyCode = 0x1D
    public static let kVK_ANSI_RightBracket: CGKeyCode = 0x1E
    public static let kVK_ANSI_O: CGKeyCode = 0x1F
    public static let kVK_ANSI_U: CGKeyCode = 0x20
    public static let kVK_ANSI_LeftBracket: CGKeyCode = 0x21
    public static let kVK_ANSI_I: CGKeyCode = 0x22
    public static let kVK_ANSI_P: CGKeyCode = 0x23
    public static let kVK_ANSI_L: CGKeyCode = 0x25
    public static let kVK_ANSI_J: CGKeyCode = 0x26
    public static let kVK_ANSI_Quote: CGKeyCode = 0x27
    public static let kVK_ANSI_K: CGKeyCode = 0x28
    public static let kVK_ANSI_Semicolon: CGKeyCode = 0x29
    public static let kVK_ANSI_Backslash: CGKeyCode = 0x2A
    public static let kVK_ANSI_Comma: CGKeyCode = 0x2B
    public static let kVK_ANSI_Slash: CGKeyCode = 0x2C
    public static let kVK_ANSI_N: CGKeyCode = 0x2D
    public static let kVK_ANSI_M: CGKeyCode = 0x2E
    public static let kVK_ANSI_Period: CGKeyCode = 0x2F
    public static let kVK_ANSI_Grave: CGKeyCode = 0x32
    public static let kVK_ANSI_KeypadDecimal: CGKeyCode = 0x41
    public static let kVK_ANSI_KeypadMultiply: CGKeyCode = 0x43
    public static let kVK_ANSI_KeypadPlus: CGKeyCode = 0x45
    public static let kVK_ANSI_KeypadClear: CGKeyCode = 0x47
    public static let kVK_ANSI_KeypadDivide: CGKeyCode = 0x4B
    public static let kVK_ANSI_KeypadEnter: CGKeyCode = 0x4C
    public static let kVK_ANSI_KeypadMinus: CGKeyCode = 0x4E
    public static let kVK_ANSI_KeypadEquals: CGKeyCode = 0x51
    public static let kVK_ANSI_Keypad0: CGKeyCode = 0x52
    public static let kVK_ANSI_Keypad1: CGKeyCode = 0x53
    public static let kVK_ANSI_Keypad2: CGKeyCode = 0x54
    public static let kVK_ANSI_Keypad3: CGKeyCode = 0x55
    public static let kVK_ANSI_Keypad4: CGKeyCode = 0x56
    public static let kVK_ANSI_Keypad5: CGKeyCode = 0x57
    public static let kVK_ANSI_Keypad6: CGKeyCode = 0x58
    public static let kVK_ANSI_Keypad7: CGKeyCode = 0x59
    public static let kVK_ANSI_Keypad8: CGKeyCode = 0x5B
    public static let kVK_ANSI_Keypad9: CGKeyCode = 0x5C

    // Keycodes for non-character keys
    public static let kVK_Return: CGKeyCode = 0x24
    public static let kVK_Tab: CGKeyCode = 0x30
    public static let kVK_Space: CGKeyCode = 0x31
    public static let kVK_Delete: CGKeyCode = 0x33
    public static let kVK_Escape: CGKeyCode = 0x35
    public static let kVK_Command: CGKeyCode = 0x37
    public static let kVK_Shift: CGKeyCode = 0x38
    public static let kVK_CapsLock: CGKeyCode = 0x39
    public static let kVK_Option: CGKeyCode = 0x3A
    public static let kVK_Control: CGKeyCode = 0x3B
    public static let kVK_RightShift: CGKeyCode = 0x3C
    public static let kVK_RightOption: CGKeyCode = 0x3D
    public static let kVK_RightControl: CGKeyCode = 0x3E
    public static let kVK_Function: CGKeyCode = 0x3F
    public static let kVK_F17: CGKeyCode = 0x40
    public static let kVK_VolumeUp: CGKeyCode = 0x48
    public static let kVK_VolumeDown: CGKeyCode = 0x49
    public static let kVK_Mute: CGKeyCode = 0x4A
    public static let kVK_F18: CGKeyCode = 0x4F
    public static let kVK_F19: CGKeyCode = 0x50
    public static let kVK_F20: CGKeyCode = 0x5A
    public static let kVK_F5: CGKeyCode = 0x60
    public static let kVK_F6: CGKeyCode = 0x61
    public static let kVK_F7: CGKeyCode = 0x62
    public static let kVK_F3: CGKeyCode = 0x63
    public static let kVK_F8: CGKeyCode = 0x64
    public static let kVK_F9: CGKeyCode = 0x65
    public static let kVK_F11: CGKeyCode = 0x67
    public static let kVK_F13: CGKeyCode = 0x69
    public static let kVK_F16: CGKeyCode = 0x6A
    public static let kVK_F14: CGKeyCode = 0x6B
    public static let kVK_F10: CGKeyCode = 0x6D
    public static let kVK_F12: CGKeyCode = 0x6F
    public static let kVK_F15: CGKeyCode = 0x71
    public static let kVK_Help: CGKeyCode = 0x72
    public static let kVK_Home: CGKeyCode = 0x73
    public static let kVK_PageUp: CGKeyCode = 0x74
    public static let kVK_ForwardDelete: CGKeyCode = 0x75
    public static let kVK_F4: CGKeyCode = 0x76
    public static let kVK_End: CGKeyCode = 0x77
    public static let kVK_F2: CGKeyCode = 0x78
    public static let kVK_PageDown: CGKeyCode = 0x79
    public static let kVK_F1: CGKeyCode = 0x7A
    public static let kVK_LeftArrow: CGKeyCode = 0x7B
    public static let kVK_RightArrow: CGKeyCode = 0x7C
    public static let kVK_DownArrow: CGKeyCode = 0x7D
    public static let kVK_UpArrow: CGKeyCode = 0x7E

    public static let backspaceKeyCode: CGKeyCode = kVK_Delete
}

// MARK: - KeyCategory

public enum KeyCategory: UInt8 {
    case character
    case backspace
    case navigation
    case wordBreak
    case functionOrMedia
    case modifier
}

// MARK: - KeyClassifier

public enum KeyClassifier {
    @inline(__always)
    public static func classify(keyCode: CGKeyCode) -> KeyCategory {
        if keyCode == KeyConstants.kVK_Delete {
            return .backspace
        }

        if keyCode == KeyConstants.kVK_LeftArrow ||
           keyCode == KeyConstants.kVK_RightArrow ||
           keyCode == KeyConstants.kVK_UpArrow ||
           keyCode == KeyConstants.kVK_DownArrow ||
           keyCode == KeyConstants.kVK_Home ||
           keyCode == KeyConstants.kVK_End ||
           keyCode == KeyConstants.kVK_PageUp ||
           keyCode == KeyConstants.kVK_PageDown ||
           keyCode == KeyConstants.kVK_ForwardDelete ||
           keyCode == KeyConstants.kVK_Escape {
            return .navigation
        }

        if keyCode == KeyConstants.kVK_Return ||
           keyCode == KeyConstants.kVK_Tab ||
           keyCode == KeyConstants.kVK_Space ||
           keyCode == KeyConstants.kVK_ANSI_KeypadEnter {
            return .wordBreak
        }

        if keyCode == KeyConstants.kVK_Command ||
           keyCode == KeyConstants.kVK_Shift ||
           keyCode == KeyConstants.kVK_CapsLock ||
           keyCode == KeyConstants.kVK_Option ||
           keyCode == KeyConstants.kVK_Control ||
           keyCode == KeyConstants.kVK_RightShift ||
           keyCode == KeyConstants.kVK_RightOption ||
           keyCode == KeyConstants.kVK_RightControl ||
           keyCode == KeyConstants.kVK_Function {
            return .modifier
        }

        if (keyCode >= 0x40 && keyCode <= 0x7F) {
            // Function keys, media, volume
            if (keyCode >= KeyConstants.kVK_F1 && keyCode <= KeyConstants.kVK_F20) ||
               keyCode == KeyConstants.kVK_VolumeUp ||
               keyCode == KeyConstants.kVK_VolumeDown ||
               keyCode == KeyConstants.kVK_Mute ||
               keyCode == KeyConstants.kVK_Help {
                return .functionOrMedia
            }
        }

        return .character
    }
}

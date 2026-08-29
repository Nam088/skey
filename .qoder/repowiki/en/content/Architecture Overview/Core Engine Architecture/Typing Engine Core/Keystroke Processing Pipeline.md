# Keystroke Processing Pipeline

<cite>
**Referenced Files in This Document**
- [TypingPipeline.swift](file://macos/skey-app/Sources/Features/Keyboard/EventHandling/Pipeline/TypingPipeline.swift)
- [KeyInterceptor.swift](file://macos/skey-app/Sources/Features/Keyboard/EventHandling/Pipeline/KeyInterceptor.swift)
- [SKeyEngine.swift](file://macos/skey-app/Sources/Features/Keyboard/Engine/SKeyEngine.swift)
- [InputMethod.swift](file://macos/skey-app/Sources/Features/Keyboard/Engine/InputMethod.swift)
- [KeyEventSender.swift](file://macos/skey-app/Sources/Features/Keyboard/EventHandling/KeyEventSender.swift)
- [KeyConstants.swift](file://macos/skey-app/Sources/Features/Keyboard/EventHandling/KeyConstants.swift)
- [ContextRecomposer.swift](file://macos/skey-app/Sources/Features/Keyboard/Context/ContextRecomposer.swift)
- [MacroEngine.swift](file://macos/skey-app/Sources/Features/Keyboard/Engine/MacroEngine.swift)
</cite>

## Table of Contents
1. Introduction
2. Project Structure
3. Core Components
4. Architecture Overview
5. Detailed Component Analysis
6. Dependency Analysis
7. Performance Considerations
8. Troubleshooting Guide
9. Conclusion

## Introduction
This document explains the keystroke processing pipeline that captures, transforms, and dispatches input events to produce correctly composed Vietnamese text and other typed content. It focuses on how key events are classified, converted into character codes, processed by the composing engine, and injected back into the system. It also documents specialized processing paths for macros, context recomposition, and navigation/backspace handling.

The pipeline is designed for low latency and high reliability: it avoids heap allocations on hot paths, uses fast classification tables, and coordinates with accessibility features only when necessary.

## Project Structure
At a high level, the pipeline consists of:
- Event interception and routing (pipeline stages)
- Key classification and fast-path decisions
- Composing engine integration (Vietnamese typing rules)
- Macro expansion
- Context-aware recomposition for editing existing words
- Synthetic event injection back to the OS or target app

```mermaid
graph TB
A["CGEvent capture"] --> B["TypingPipeline.process()"]
B --> C["KeyClassifier.classify()"]
B --> D["SKeyEngine.filter()/backspace()"]
B --> E["MacroEngine.evaluateMacroOnSpace()"]
B --> F["ContextRecomposer.tryRecompose()"]
B --> G["KeyEventSender.inject()"]
C --> |fast path| B
D --> G
E --> G
F --> G
```

**Diagram sources**
- [TypingPipeline.swift:31-170](file://macos/skey-app/Sources/Features/Keyboard/EventHandling/Pipeline/TypingPipeline.swift#L31-L170)
- [KeyConstants.swift:148-191](file://macos/skey-app/Sources/Features/Keyboard/EventHandling/KeyConstants.swift#L148-L191)
- [SKeyEngine.swift:133-145](file://macos/skey-app/Sources/Features/Keyboard/Engine/SKeyEngine.swift#L133-L145)
- [MacroEngine.swift:71-109](file://macos/skey-app/Sources/Features/Keyboard/Engine/MacroEngine.swift#L71-L109)
- [ContextRecomposer.swift:40-97](file://macos/skey-app/Sources/Features/Keyboard/Context/ContextRecomposer.swift#L40-L97)
- [KeyEventSender.swift:33-51](file://macos/skey-app/Sources/Features/Keyboard/EventHandling/KeyEventSender.swift#L33-L51)

**Section sources**
- [TypingPipeline.swift:31-170](file://macos/skey-app/Sources/Features/Keyboard/EventHandling/Pipeline/TypingPipeline.swift#L31-L170)
- [KeyConstants.swift:148-191](file://macos/skey-app/Sources/Features/Keyboard/EventHandling/KeyConstants.swift#L148-L191)

## Core Components
- TypingPipeline: Orchestrates event processing stages, classifies keys, decides fast paths, and coordinates with engine, macros, and recomposer.
- SKeyEngine: Thin wrapper around the Rust core engine; provides filter(character:) and backspace(), plus configuration and state reset.
- MacroEngine: Tracks current word buffer and expands shortcuts on space with optional auto-caps behavior.
- ContextRecomposer: Reconstructs full words atomically when editing previously typed words and applies tone/diacritic changes based on the active input method.
- KeyEventSender: Injects synthetic backspaces and Unicode text into the session or via Accessibility APIs for special targets like Spotlight.
- KeyConstants and KeyClassifier: Provide virtual keycodes and a fast lookup table to classify keys into categories (character, backspace, navigation, word break, function/media, modifier).
- InputMethodType: Enumerates supported input methods (Telex, VNI, VIQR, Simple Telex).

**Section sources**
- [TypingPipeline.swift:31-170](file://macos/skey-app/Sources/Features/Keyboard/EventHandling/Pipeline/TypingPipeline.swift#L31-L170)
- [SKeyEngine.swift:6-189](file://macos/skey-app/Sources/Features/Keyboard/Engine/SKeyEngine.swift#L6-L189)
- [MacroEngine.swift:16-111](file://macos/skey-app/Sources/Features/Keyboard/Engine/MacroEngine.swift#L16-L111)
- [ContextRecomposer.swift:9-97](file://macos/skey-app/Sources/Features/Keyboard/Context/ContextRecomposer.swift#L9-L97)
- [KeyEventSender.swift:9-127](file://macos/skey-app/Sources/Features/Keyboard/EventHandling/KeyEventSender.swift#L9-L127)
- [KeyConstants.swift:7-192](file://macos/skey-app/Sources/Features/Keyboard/EventHandling/KeyConstants.swift#L7-L192)
- [InputMethod.swift:5-19](file://macos/skey-app/Sources/Features/Keyboard/Engine/InputMethod.swift#L5-L19)

## Architecture Overview
The pipeline processes each CGEvent through a sequence of stages:
1. Pass-through checks for synthetic events, disabled taps, and mouse clicks.
2. Handle flagsChanged for modifier-only language toggle chords.
3. Match customizable hotkeys (language toggle, clipboard, cleaner, AI).
4. Early exit for command/control/option combinations.
5. Skip keyUp events and excluded applications.
6. For Vietnamese mode:
   - Classify key and apply fast paths (function/media, navigation, backspace, word-break).
   - Extract printable ASCII characters and optionally expand macros on space.
   - Filter through SKeyEngine.filter(character:) to compose Vietnamese text.
   - If unhandled and caret may have moved, attempt ContextRecomposer.tryRecompose().
7. Inject results via KeyEventSender.inject(backspaces:text:).

```mermaid
sequenceDiagram
participant OS as "OS"
participant TP as "TypingPipeline"
participant KC as "KeyClassifier"
participant ME as "MacroEngine"
participant SE as "SKeyEngine"
participant CR as "ContextRecomposer"
participant KS as "KeyEventSender"
OS->>TP : process(event, type)
TP->>KC : classify(keyCode)
alt Function/Media
TP-->>OS : passThrough
else Navigation
TP->>SE : reset()
TP-->>OS : passThrough
else Backspace
TP->>ME : recordBackspace()
TP->>SE : backspace()
alt handled
TP->>KS : inject(backspaces, text)
TP-->>OS : swallowed
else not handled
TP-->>OS : passThrough
end
else Printable char
alt Space + macro enabled
TP->>ME : evaluateMacroOnSpace()
alt matched
TP->>KS : inject(backspaces, replacement+" ")
TP-->>OS : swallowed
else no match
TP->>SE : filter(char)
alt handled
TP->>KS : inject(backspaces, text)
TP-->>OS : swallowed
else not handled
TP->>CR : tryRecompose(char)
alt recomposed
TP-->>OS : swallowed
else not recomposed
TP-->>OS : passThrough
end
end
end
else Not space or macro disabled
TP->>SE : filter(char)
alt handled
TP->>KS : inject(backspaces, text)
TP-->>OS : swallowed
else not handled
TP->>CR : tryRecompose(char)
alt recomposed
TP-->>OS : swallowed
else not recomposed
TP-->>OS : passThrough
end
end
end
end
```

**Diagram sources**
- [TypingPipeline.swift:31-280](file://macos/skey-app/Sources/Features/Keyboard/EventHandling/Pipeline/TypingPipeline.swift#L31-L280)
- [MacroEngine.swift:71-109](file://macos/skey-app/Sources/Features/Keyboard/Engine/MacroEngine.swift#L71-L109)
- [SKeyEngine.swift:133-145](file://macos/skey-app/Sources/Features/Keyboard/Engine/SKeyEngine.swift#L133-L145)
- [ContextRecomposer.swift:40-97](file://macos/skey-app/Sources/Features/Keyboard/Context/ContextRecomposer.swift#L40-L97)
- [KeyEventSender.swift:33-51](file://macos/skey-app/Sources/Features/Keyboard/EventHandling/KeyEventSender.swift#L33-L51)

## Detailed Component Analysis

### TypingPipeline: Event Routing and Composition Control
- Entry point process(event:type:) implements a multi-stage pipeline:
  - Skips synthetic events, disabled taps, and mouse clicks.
  - Handles flagsChanged for modifier-only language toggle chords.
  - Matches configured hotkeys and swallows them.
  - Resets engine state on modifier combinations and navigation keys.
  - Filters printable ASCII characters and delegates to engine/filter or macro expansion.
  - Coordinates with ContextRecomposer when caret movement is detected.
- handleKeyDown(keyCode:flags:event:) performs key classification and fast-path routing:
  - Function/media keys pass through.
  - Navigation keys reset buffers and mark potential caret movement.
  - Backspace triggers engine.backspace() and injects synthetic backspaces/text.
  - Word-break keys (except space) reset buffers and pass through.
  - Space can trigger macro expansion before engine filtering.
  - Printable characters are filtered via SKeyEngine.filter(character:), with optional recomposition.

```mermaid
flowchart TD
Start(["process(event,type)"]) --> CheckSynthetic{"Synthetic or disabled?"}
CheckSynthetic --> |Yes| Pass1["passThrough"]
CheckSynthetic --> |No| Mouse{"Mouse click?"}
Mouse --> |Yes| Reset1["reset engines<br/>caretMayHaveMoved=true"] --> Pass2["passThrough"]
Mouse --> |No| Flags{"flagsChanged?"}
Flags --> |Yes| ModChord["Handle modifier-only chord"] --> Pass3["passThrough"]
Flags --> |No| Hotkeys{"Match hotkeys?"}
Hotkeys --> |Yes| Swallow["swallowed"]
Hotkeys --> |No| Mods{"Command/Control/Option?"}
Mods --> |Yes| Reset2["reset engines"] --> Pass4["passThrough"]
Mods --> |No| Type{"keyDown/keyUp?"}
Type --> |keyUp| Pass5["passThrough"]
Type --> |keyDown| Exclude{"App excluded?"}
Exclude --> |Yes| Pass6["passThrough"]
Exclude --> |No| VN{"Vietnamese mode?"}
VN --> |No| ENMacro{"English macro?"}
ENMacro --> |Yes| ENPath["handleEnglishMacroKeyDown"] --> End
ENMacro --> |No| Pass7["passThrough"]
VN --> |Yes| HandleDown["handleKeyDown(...)"] --> End
```

**Diagram sources**
- [TypingPipeline.swift:31-170](file://macos/skey-app/Sources/Features/Keyboard/EventHandling/Pipeline/TypingPipeline.swift#L31-L170)
- [TypingPipeline.swift:174-280](file://macos/skey-app/Sources/Features/Keyboard/EventHandling/Pipeline/TypingPipeline.swift#L174-L280)

**Section sources**
- [TypingPipeline.swift:31-280](file://macos/skey-app/Sources/Features/Keyboard/EventHandling/Pipeline/TypingPipeline.swift#L31-L280)

### SKeyEngine: Composing Engine Wrapper
- Provides filter(character:) and backspace() which return ProcessResult indicating whether the engine handled the input, how many backspaces to emit, and any resulting text.
- Configures default options, input method, charset, and caps state.
- Uses zero-allocation UTF-8 extraction from the Rust engine output buffer.

```mermaid
classDiagram
class SKeyEngine {
+init()
+setInputMethod(method)
+setCapsState(shiftPressed, capsLockOn)
+filter(character) ProcessResult
+backspace() ProcessResult
+reset()
}
class ProcessResult {
+bool handled
+int backspaces
+string text
}
SKeyEngine --> ProcessResult : "returns"
```

**Diagram sources**
- [SKeyEngine.swift:8-189](file://macos/skey-app/Sources/Features/Keyboard/Engine/SKeyEngine.swift#L8-L189)

**Section sources**
- [SKeyEngine.swift:27-189](file://macos/skey-app/Sources/Features/Keyboard/Engine/SKeyEngine.swift#L27-L189)

### MacroEngine: Shortcut Expansion on Space
- Maintains a sliding buffer of the current word and matches against a map of shortcuts to replacements.
- On space, returns MacroMatchResult with number of backspaces and replacement string (with optional auto-caps transformation).
- Records characters and backspaces to keep the buffer accurate.

```mermaid
flowchart TD
MStart["evaluateMacroOnSpace()"] --> Enabled{"Macro enabled?"}
Enabled --> |No| MReset["reset()"] --> MEnd["unhandled"]
Enabled --> |Yes| Lookup["lookup lowercased(currentWord)"]
Lookup --> Found{"Match found?"}
Found --> |No| MEnd
Found --> |Yes| Transform["Apply auto-caps if enabled"]
Transform --> Return["return handled=true<br/>backspaces=currentWord.count<br/>replacement=raw+' '"]
```

**Diagram sources**
- [MacroEngine.swift:71-109](file://macos/skey-app/Sources/Features/Keyboard/Engine/MacroEngine.swift#L71-L109)

**Section sources**
- [MacroEngine.swift:16-111](file://macos/skey-app/Sources/Features/Keyboard/Engine/MacroEngine.swift#L16-L111)

### ContextRecomposer: Full-Word Recomposition
- Activated when caret may have moved (navigation keys) and an unhandled printable character is received.
- Validates candidate preceding word length and letters, decomposes it into keys, re-runs through a scratch engine with the active input method, then applies the new character.
- Performs atomic replacement of the entire preceding word using either Accessibility API (Spotlight) or KeyEventSender.
- Syncs the main engine state with the newly formed word.

```mermaid
flowchart TD
CStart["tryRecompose(charCode, engine)"] --> Validate{"Trigger key?<br/>No selection?<br/>Preceding word valid?"}
Validate --> |No| CEnd["false"]
Validate --> |Yes| Decompose["Decompose word -> keys"]
Decompose --> Scratch["scratchEngine.setInputMethod()<br/>scratchEngine.reset()"]
Scratch --> Replay["For each key: filter()<br/>build reconstructedWord"]
Replay --> ApplyChar["scratchEngine.filter(charCode)"]
ApplyChar --> Success{"Handled & non-empty?"}
Success --> |No| CEnd
Success --> |Yes| Replace{"Spotlight?"}
Replace --> |Yes| AX["replaceTextViaAX(backspaces, text)"]
Replace --> |No| Inject["KeyEventSender.inject(backspaces, text)"]
AX --> Sync["engine.reset()<br/>replay keys for new word"]
Inject --> Sync
Sync --> CEndTrue["true"]
```

**Diagram sources**
- [ContextRecomposer.swift:40-97](file://macos/skey-app/Sources/Features/Keyboard/Context/ContextRecomposer.swift#L40-L97)
- [KeyEventSender.swift:33-51](file://macos/skey-app/Sources/Features/Keyboard/EventHandling/KeyEventSender.swift#L33-L51)

**Section sources**
- [ContextRecomposer.swift:9-97](file://macos/skey-app/Sources/Features/Keyboard/Context/ContextRecomposer.swift#L9-L97)

### KeyEventSender: Synthetic Event Injection
- Injects backspaces followed by Unicode text.
- Uses direct Accessibility replacement for Spotlight overlay to avoid backspace loss.
- Otherwise posts non-coalesced key down/up events with chunked Unicode strings for reliable delivery.
- Stamps all synthetic events with a marker so they are ignored by the pipeline.

```mermaid
sequenceDiagram
participant TP as "TypingPipeline"
participant KS as "KeyEventSender"
participant AX as "Accessibility"
participant OS as "OS Session"
TP->>KS : inject(backspaces, text)
alt Spotlight active
KS->>AX : replaceTextViaAX(backspaces, text)
AX-->>KS : success/fail
else Normal apps
loop for each backspace
KS->>OS : post backspace down/up (non-coalesced)
end
opt text not empty
KS->>OS : post text chunks down/up (non-coalesced)
end
end
```

**Diagram sources**
- [KeyEventSender.swift:33-127](file://macos/skey-app/Sources/Features/Keyboard/EventHandling/KeyEventSender.swift#L33-L127)

**Section sources**
- [KeyEventSender.swift:9-127](file://macos/skey-app/Sources/Features/Keyboard/EventHandling/KeyEventSender.swift#L9-L127)

### Key Classification and Constants
- KeyConstants defines virtual keycodes and timing constants used for synthetic event delivery.
- KeyClassifier provides a fast lookup table mapping keycodes to categories (character, backspace, navigation, word break, function/media, modifier).

**Section sources**
- [KeyConstants.swift:7-192](file://macos/skey-app/Sources/Features/Keyboard/EventHandling/KeyConstants.swift#L7-L192)

### Input Method Types
- InputMethodType enumerates supported input methods: Telex, VNI, VIQR, Simple Telex.
- The engine’s input method affects how keys are interpreted and composed.

**Section sources**
- [InputMethod.swift:5-19](file://macos/skey-app/Sources/Features/Keyboard/Engine/InputMethod.swift#L5-L19)

## Dependency Analysis
- TypingPipeline depends on:
  - KeyClassifier for fast categorization
  - SKeyEngine for composition
  - MacroEngine for shortcut expansion
  - ContextRecomposer for context-aware recomposition
  - KeyEventSender for injecting results
- SKeyEngine wraps the Rust core engine and exposes filter/backspace operations.
- ContextRecomposer uses a scratch SKeyEngine instance and Accessibility utilities.
- KeyEventSender relies on CoreGraphics and Accessibility APIs.

```mermaid
graph LR
TP["TypingPipeline"] --> KC["KeyClassifier"]
TP --> SE["SKeyEngine"]
TP --> ME["MacroEngine"]
TP --> CR["ContextRecomposer"]
TP --> KS["KeyEventSender"]
CR --> SE
KS --> OS["CoreGraphics/Accessibility"]
```

**Diagram sources**
- [TypingPipeline.swift:31-280](file://macos/skey-app/Sources/Features/Keyboard/EventHandling/Pipeline/TypingPipeline.swift#L31-L280)
- [SKeyEngine.swift:133-145](file://macos/skey-app/Sources/Features/Keyboard/Engine/SKeyEngine.swift#L133-L145)
- [MacroEngine.swift:71-109](file://macos/skey-app/Sources/Features/Keyboard/Engine/MacroEngine.swift#L71-L109)
- [ContextRecomposer.swift:40-97](file://macos/skey-app/Sources/Features/Keyboard/Context/ContextRecomposer.swift#L40-L97)
- [KeyEventSender.swift:33-127](file://macos/skey-app/Sources/Features/Keyboard/EventHandling/KeyEventSender.swift#L33-L127)

**Section sources**
- [TypingPipeline.swift:31-280](file://macos/skey-app/Sources/Features/Keyboard/EventHandling/Pipeline/TypingPipeline.swift#L31-L280)

## Performance Considerations
- Fast-path classification via KeyClassifier reduces branching overhead.
- Zero-heap allocation strategies:
  - SKeyEngine reads engine output into stack buffers.
  - KeyEventSender sends text in chunks using temporary buffers.
- Non-coalesced synthetic events ensure reliable delivery across apps.
- Microsecond delays between synthetic backspaces and text chunks improve compatibility with sensitive targets.
- Modifier-only chord detection avoids unnecessary engine resets.

[No sources needed since this section provides general guidance]

## Troubleshooting Guide
- Events not being transformed:
  - Verify the pipeline is not passing through due to synthetic event markers or disabled taps.
  - Ensure the application is not excluded and that the language provider indicates Vietnamese mode.
- Incorrect composition after navigation:
  - Confirm caretMayHaveMoved is set appropriately and ContextRecomposer.tryRecompose() is invoked.
  - Check that the preceding word meets validity constraints and that the typed character is a trigger key for the active input method.
- Macros not expanding:
  - Ensure macro feature is enabled and the current word matches a configured shortcut.
  - Verify auto-caps settings and that space triggers evaluation.
- Text not appearing in Spotlight:
  - Confirm Accessibility replacement path is taken and succeeds.
- Excessive backspaces or missing characters:
  - Review resolveBackspaces logic for web browsers with active selections.
  - Check inter-chunk and settle delays in KeyEventSender.

**Section sources**
- [TypingPipeline.swift:31-280](file://macos/skey-app/Sources/Features/Keyboard/EventHandling/Pipeline/TypingPipeline.swift#L31-L280)
- [ContextRecomposer.swift:40-97](file://macos/skey-app/Sources/Features/Keyboard/Context/ContextRecomposer.swift#L40-L97)
- [MacroEngine.swift:71-109](file://macos/skey-app/Sources/Features/Keyboard/Engine/MacroEngine.swift#L71-L109)
- [KeyEventSender.swift:33-127](file://macos/skey-app/Sources/Features/Keyboard/EventHandling/KeyEventSender.swift#L33-L127)

## Conclusion
The keystroke processing pipeline integrates event interception, fast classification, composing engine calls, macro expansion, and context-aware recomposition to deliver accurate Vietnamese typing and robust text insertion across diverse applications. Its design emphasizes performance, correctness, and compatibility, with careful handling of edge cases such as navigation, modifiers, and special targets like Spotlight.

[No sources needed since this section summarizes without analyzing specific files]
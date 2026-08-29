# Dispatch Mechanism & Event Routing

<cite>
**Referenced Files in This Document**
- [mod.rs](file://port/skey-core/src/engine/mod.rs)
- [transform.rs](file://port/skey-core/src/engine/transform.rs)
- [append.rs](file://port/skey-core/src/engine/append.rs)
- [shortcuts.rs](file://port/skey-core/src/engine/shortcuts.rs)
- [input/mod.rs](file://port/skey-core/src/input/mod.rs)
</cite>

## Table of Contents
1. [Introduction](#introduction)
2. [Project Structure](#project-structure)
3. [Core Components](#core-components)
4. [Architecture Overview](#architecture-overview)
5. [Detailed Component Analysis](#detailed-component-analysis)
6. [Dependency Analysis](#dependency-analysis)
7. [Performance Considerations](#performance-considerations)
8. [Troubleshooting Guide](#troubleshooting-guide)
9. [Conclusion](#conclusion)

## Introduction
This document explains the event dispatch mechanism that routes keystrokes to appropriate handlers in the SKey engine. It focuses on:
- The main dispatch() method, which applies capitalization and quick Telex shortcuts before delegating to dispatch_inner().
- The dispatch_inner() match statement that categorizes events into specific processors: process_roof(), process_hook(), process_tone(), process_telex_w(), and process_append() as the default handler.
- How KeyEvent types are determined by InputProcessor based on the active input method.
- How the dispatch decision tree optimizes for common cases.
- Examples of different input scenarios and their routing paths through the system.

## Project Structure
The dispatch logic is implemented in the core engine module and related transformation modules:
- Engine orchestration and dispatch methods live in the engine module.
- Transformation logic (roof, hook, tone, d-stroke, Telex w) lives in the transform module.
- Default append behavior and word assembly live in the append module.
- Shortcut features (capitalization, quick Telex) live in the shortcuts module.
- Key classification and mapping to KeyEvent live in the input module.

```mermaid
graph TB
A["Engine::dispatch"] --> B["apply_upper_case_first_char"]
A --> C["apply_quick_telex"]
A --> D["Engine::dispatch_inner"]
D --> E["process_roof"]
D --> F["process_hook"]
D --> G["process_tone"]
D --> H["process_telex_w"]
D --> I["process_map_char / process_esc_char"]
D --> J["process_append (default)"]
K["InputProcessor::key_code_to_event"] --> D
```

**Diagram sources**
- [mod.rs:209-246](file://port/skey-core/src/engine/mod.rs#L209-L246)
- [shortcuts.rs:182-297](file://port/skey-core/src/engine/shortcuts.rs#L182-L297)
- [transform.rs:70-712](file://port/skey-core/src/engine/transform.rs#L70-L712)
- [append.rs:141-196](file://port/skey-core/src/engine/append.rs#L141-L196)
- [input/mod.rs:162-192](file://port/skey-core/src/input/mod.rs#L162-L192)

**Section sources**
- [mod.rs:209-246](file://port/skey-core/src/engine/mod.rs#L209-L246)
- [input/mod.rs:162-192](file://port/skey-core/src/input/mod.rs#L162-L192)

## Core Components
- Engine: Holds state and orchestrates dispatch. Provides key(), dispatch(), dispatch_inner(), and helper methods.
- InputProcessor: Converts raw key codes into KeyEvent with ev_type, ch_type, vn_sym, and tone.
- Transform processors: process_roof(), process_hook(), process_tone(), process_dd(), process_telex_w(), process_map_char(), process_esc_char().
- Append processor: process_append() and supporting vowel/consonant appending logic.
- Shortcuts: apply_upper_case_first_char() and apply_quick_telex() for pre-processing before dispatch.

**Section sources**
- [mod.rs:18-70](file://port/skey-core/src/engine/mod.rs#L18-L70)
- [input/mod.rs:50-92](file://port/skey-core/src/input/mod.rs#L50-L92)
- [transform.rs:70-712](file://port/skey-core/src/engine/transform.rs#L70-L712)
- [append.rs:141-196](file://port/skey-core/src/engine/append.rs#L141-L196)
- [shortcuts.rs:182-297](file://port/skey-core/src/engine/shortcuts.rs#L182-L297)

## Architecture Overview
The dispatch pipeline processes each keystroke as follows:
1. key() prepares buffers and converts the key code to a KeyEvent via InputProcessor.
2. dispatch() applies first-character capitalization and quick Telex shortcuts.
3. dispatch_inner() matches the event type to a specialized processor or falls back to process_append().
4. Processors update the buffer and mark changes; output is written if needed.

```mermaid
sequenceDiagram
participant App as "Caller"
participant Eng as "Engine"
participant IP as "InputProcessor"
participant Proc as "Processors"
App->>Eng : key(key_code)
Eng->>IP : key_code_to_event(key_code)
IP-->>Eng : KeyEvent(ev_type, ch_type, vn_sym, tone)
Eng->>Eng : apply_upper_case_first_char(ev)
Eng->>Eng : apply_quick_telex(ev)?
alt shortcut matched
Eng-->>App : Edit(handled=true)
else no shortcut
Eng->>Eng : dispatch_inner(ev)
Eng->>Proc : route by ev_type
Proc-->>Eng : i32 result
Eng->>Eng : write_output() if needed
Eng-->>App : Edit(backspaces, handled)
end
```

**Diagram sources**
- [mod.rs:248-319](file://port/skey-core/src/engine/mod.rs#L248-L319)
- [input/mod.rs:162-192](file://port/skey-core/src/input/mod.rs#L162-L192)
- [shortcuts.rs:182-297](file://port/skey-core/src/engine/shortcuts.rs#L182-L297)
- [transform.rs:70-712](file://port/skey-core/src/engine/transform.rs#L70-L712)
- [append.rs:98-109](file://port/skey-core/src/engine/append.rs#L98-L109)

## Detailed Component Analysis

### Main dispatch() method
- Applies first-character capitalization when enabled and conditions are met.
- Checks quick Telex shortcuts; if matched, returns immediately without further processing.
- If capitalization was applied, ensures the capital character is emitted even if dispatch_inner() reports no change.
- Delegates to dispatch_inner() for final routing.

```mermaid
flowchart TD
Start(["dispatch(ev)"]) --> Cap["apply_upper_case_first_char(ev)"]
Cap --> Quick{"apply_quick_telex(ev) matched?"}
Quick -- Yes --> ReturnShortcut["return shortcut result"]
Quick -- No --> Capitalized{"capitalised?"}
Capitalized -- Yes --> Inner["dispatch_inner(ev)"]
Inner --> ForceCap{"r == 0 and current >= 0?"}
ForceCap -- Yes --> MarkCap["mark_change(current) return 1"]
ForceCap -- No --> ReturnInner["return inner result"]
Capitalized -- No --> Inner2["dispatch_inner(ev)"]
Inner2 --> End(["done"])
```

**Diagram sources**
- [mod.rs:209-225](file://port/skey-core/src/engine/mod.rs#L209-L225)
- [shortcuts.rs:182-297](file://port/skey-core/src/engine/shortcuts.rs#L182-L297)

**Section sources**
- [mod.rs:209-225](file://port/skey-core/src/engine/mod.rs#L209-L225)
- [shortcuts.rs:182-297](file://port/skey-core/src/engine/shortcuts.rs#L182-L297)

### dispatch_inner() match statement
Categorizes KeyEvent.ev_type into specific processors:
- ROOF_ALL | ROOF_A | ROOF_E | ROOF_O → process_roof()
- HOOK_ALL | HOOK_UO | HOOK_U | HOOK_O | BOWL → process_hook()
- DD → process_dd()
- TONE0..TONE5 → process_tone()
- TELEX_W → process_telex_w()
- MAP_CHAR → process_map_char()
- ESC_CHAR → process_esc_char()
- Default → process_append()

```mermaid
flowchart TD
MStart["dispatch_inner(ev)"] --> Match{"ev_type"}
Match --> |ROOF_*| Roof["process_roof(ev)"]
Match --> |HOOK_*| Hook["process_hook(ev)"]
Match --> |DD| DD["process_dd(ev)"]
Match --> |TONE*| Tone["process_tone(ev)"]
Match --> |TELEX_W| W["process_telex_w(ev)"]
Match --> |MAP_CHAR| Map["process_map_char(ev)"]
Match --> |ESC_CHAR| Esc["process_esc_char(ev)"]
Match --> |else| Append["process_append(ev)"]
Roof --> MEnd["return"]
Hook --> MEnd
DD --> MEnd
Tone --> MEnd
W --> MEnd
Map --> MEnd
Esc --> MEnd
Append --> MEnd
```

**Diagram sources**
- [mod.rs:227-246](file://port/skey-core/src/engine/mod.rs#L227-L246)

**Section sources**
- [mod.rs:227-246](file://port/skey-core/src/engine/mod.rs#L227-L246)

### KeyEvent determination by InputProcessor
- key_code_to_event() maps raw key codes to KeyEvent using per-method key maps.
- For ASCII keys, ev_type is set from the method’s key map; for non-ASCII, it becomes NORMAL.
- Tone events derive tone from ev_type range.
- Character mapping entries (>= EV_COUNT) are converted to MAP_CHAR with corresponding vn_sym.
- ch_type indicates whether the key is Vietnamese, word break, non-Vietnamese, or reset.

```mermaid
flowchart TD
KIn["key_code"] --> Check{"key_code > 255?"}
Check -- Yes --> NonASCII["ev_type = NORMAL<br/>vn_sym = iso_to_lexi(key_code)<br/>ch_type = UKC_VN or UKC_NON_VN"]
Check -- No --> Lookup["ch_type = UKC_MAP[key_code]<br/>ev_type = key_map[key_code]"]
Lookup --> ToneCheck{"ev_type in TONE0..TONE5?"}
ToneCheck -- Yes --> SetTone["tone = ev_type - TONE0"]
ToneCheck -- No --> Next
Next --> MapChar{"ev_type >= EV_COUNT?"}
MapChar -- Yes --> ToMap["ch_type = UKC_VN<br/>vn_sym = ev_type - EV_COUNT<br/>ev_type = MAP_CHAR"]
MapChar -- No --> VNLookup["vn_sym = iso_to_lexi(key_code)"]
NonASCII --> KOut["KeyEvent"]
SetTone --> KOut
ToMap --> KOut
VNLookup --> KOut
```

**Diagram sources**
- [input/mod.rs:162-192](file://port/skey-core/src/input/mod.rs#L162-L192)

**Section sources**
- [input/mod.rs:162-192](file://port/skey-core/src/input/mod.rs#L162-L192)

### Processor: process_roof()
Handles diacritical marks (ROOF_ALL, ROOF_A, ROOF_E, ROOF_O):
- Validates context (Vietnamese mode, current position, vowel offset).
- Determines target roof symbol based on ev_type.
- Computes vowel sequence boundaries and tone position.
- Handles special u+o sequences and toggles roof presence.
- Updates symbols and sub-sequence markers; repositions tone if necessary.
- Falls back to process_append() when rules do not allow roof application.

```mermaid
flowchart TD
RStart["process_roof(ev)"] --> Guard{"viet_key && current >= 0 && v_offset < 0?"}
Guard -- No --> RAppend["process_append(ev)"]
Guard -- Yes --> Target["target = match ev_type"]
Target --> VBounds["v_end, v_start, cur_tone_pos, tone"]
VBounds --> NewVS{"new_vs valid?"}
NewVS -- No --> Undo{"existing roof at roof_pos?"}
Undo -- Yes --> Remove["remove roof, new_vs = v_no_roof(vs)"]
Undo -- No --> RAppend
NewVS -- Yes --> Validate{"target matches expected roof?"}
Validate -- No --> RAppend
Validate --> CVC{"is_valid_cvc(c1, new_vs, c2)?"}
CVC -- No --> RAppend
CVC --> Apply["mark_change(change_pos), update symbols"]
Apply --> UpdateSubs["update sub-sequences"]
UpdateSubs --> ToneMove{"cur_tone_pos != new_tone_pos && tone != 0?"}
ToneMove -- Yes --> MoveTone["move tone to new position"]
ToneMove -- No --> Done["return 1"]
MoveTone --> Done
Remove --> Revert{"roof_removed?"}
Revert -- Yes --> ReAppend["process_append(ev); reverted = true"]
Revert -- No --> Done
```

**Diagram sources**
- [transform.rs:70-189](file://port/skey-core/src/engine/transform.rs#L70-L189)

**Section sources**
- [transform.rs:70-189](file://port/skey-core/src/engine/transform.rs#L70-L189)

### Processor: process_hook()
Handles hook marks (HOOK_ALL, HOOK_UO, HOOK_U, HOOK_O, BOWL):
- Special handling for u+o sequences via process_hook_with_uo().
- Determines whether to add or remove hooks based on existing state.
- Validates context and consonant-vowel constraints.
- Updates symbols and sub-sequence markers; repositions tone if necessary.
- Falls back to process_append() when rules do not allow hook application.

```mermaid
flowchart TD
HStart["process_hook(ev)"] --> UOCheck{"u+o special case?"}
UOCheck -- Yes --> HOU["process_hook_with_uo(ev)"]
UOCheck -- No --> Bounds["v_end, v_start, cur_tone_pos, tone"]
Bounds --> NewHook{"with_hook valid?"}
NewHook -- No --> Undo{"existing hook at hook_pos?"}
Undo -- Yes --> Remove["remove hook, new_vs = v_no_hook(vs)"]
Undo -- No --> HAppend["process_append(ev)"]
NewHook -- Yes --> Validate{"target matches expected hook?"}
Validate -- No --> HAppend
Validate --> CVC{"is_valid_cvc(c1, new_vs, c2)?"}
CVC -- No --> HAppend
CVC --> Apply["mark_change(change_pos), update symbols"]
Apply --> UpdateSubs["update sub-sequences"]
UpdateSubs --> ToneMove{"cur_tone_pos != new_tone_pos && tone != 0?"}
ToneMove -- Yes --> MoveTone["move tone to new position"]
ToneMove -- No --> Done["return 1"]
MoveTone --> Done
Remove --> Revert{"hook_removed?"}
Revert -- Yes --> ReAppend["process_append(ev); reverted = true"]
Revert -- No --> Done
```

**Diagram sources**
- [transform.rs:192-467](file://port/skey-core/src/engine/transform.rs#L192-L467)

**Section sources**
- [transform.rs:192-467](file://port/skey-core/src/engine/transform.rs#L192-L467)

### Processor: process_tone()
Applies tone marks (TONE0–TONE5):
- Handles special cases for g/gi consonants.
- Validates context (Vietnamese mode, current form, spell-check options).
- Computes tone position within the vowel sequence.
- Toggles tone if same tone is reapplied; otherwise sets tone at computed position.
- Falls back to process_append() when tone cannot be applied.

```mermaid
flowchart TD
TStart["process_tone(ev)"] --> ViCheck{"viet_key && current >= 0?"}
ViCheck -- No --> TAppend["process_append(ev)"]
ViCheck -- Yes --> GiCase{"form == VNW_C and cseq == gi/gin?"}
GiCase -- Yes --> GiLogic["handle gi tone toggle/set"]
GiCase -- No --> VOffset{"v_offset < 0?"}
VOffset -- Yes --> TAppend
VOffset -- No --> Spell{"spell_check_enabled && !free_marking && !complete?"}
Spell -- Yes --> TAppend
Spell -- No --> TonePos["compute tone_position(vs, terminated)"]
TonePos --> Toggle{"current tone == ev.tone?"}
Toggle -- Yes --> Clear["clear tone, single_mode=false, revert"]
Toggle -- No --> Set["set tone at tone_pos"]
Clear --> TDone["return 1"]
Set --> TDone
TAppend --> TDone
```

**Diagram sources**
- [transform.rs:469-536](file://port/skey-core/src/engine/transform.rs#L469-L536)

**Section sources**
- [transform.rs:469-536](file://port/skey-core/src/engine/transform.rs#L469-L536)

### Processor: process_telex_w()
Implements Telex 'w' handling:
- If used_as_map_char flag is set, treats 'w' as a mapped character (uh/Uh) and attempts mapping; if mapping fails, falls back to hook.
- Otherwise, tries hook first; if hook fails, treats 'w' as a mapped character and retries mapping.
- Ensures correct case handling and updates used_as_map_char accordingly.

```mermaid
flowchart TD
WStart["process_telex_w(ev)"] --> Viet{"viet_key?"}
Viet -- No --> WAppend["process_append(ev)"]
Viet -- Yes --> MapFlag{"used_as_map_char?"}
MapFlag -- Yes --> TryMap["ev_type=MAP_CHAR, vn_sym=Uh/uh<br/>process_map_char(ev)"]
TryMap --> MapResult{"result == 0?"}
MapResult -- Yes --> Fallback["ev_type=HOOK_ALL<br/>process_hook(ev)"]
MapResult -- No --> WReturn["return result"]
MapFlag -- No --> TryHook["ev_type=HOOK_ALL<br/>process_hook(ev)"]
TryHook --> HookResult{"result == 0?"}
HookResult -- Yes --> UseMap["ev_type=MAP_CHAR, vn_sym=Uh/uh<br/>used_as_map_char=true<br/>process_map_char(ev)"]
HookResult -- No --> WReturn
UseMap --> WReturn
WAppend --> WReturn
Fallback --> WReturn
```

**Diagram sources**
- [transform.rs:675-712](file://port/skey-core/src/engine/transform.rs#L675-L712)

**Section sources**
- [transform.rs:675-712](file://port/skey-core/src/engine/transform.rs#L675-L712)

### Default handler: process_append()
Routes all other events and handles word assembly:
- Resets, word breaks, and non-Vietnamese characters are processed distinctly.
- Vietnamese characters are appended as vowels or consonants with validation.
- Special VIQR escape handling may produce literal output.
- Word boundary logic triggers macro matching and quick consonant shortcuts at word ends.

```mermaid
flowchart TD
AStart["process_append(ev)"] --> ChType{"ch_type"}
ChType -- RESET --> Reset["reset() return 0"]
ChType -- WORD_BREAK --> WordBreak["single_mode=false<br/>process_word_end(ev)"]
ChType -- NON_VN --> NonVN{"viet_key && charset==VIQR && check_escape_viqr?"}
NonVN -- Yes --> Escape["write escape output return 1"]
NonVN -- No --> AppendNonVN["append NON_VN entry"]
ChType -- VN --> IsVowel{"is_vowel(vn_sym)?"}
IsVowel -- Yes --> AppendVowel["append_vowel(ev)"]
IsVowel -- No --> AppendConsonant["append_consonnant(ev)"]
Reset --> AEnd["done"]
WordBreak --> AEnd
Escape --> AEnd
AppendNonVN --> AEnd
AppendVowel --> AEnd
AppendConsonant --> AEnd
```

**Diagram sources**
- [append.rs:141-196](file://port/skey-core/src/engine/append.rs#L141-L196)
- [append.rs:577-586](file://port/skey-core/src/engine/append.rs#L577-L586)

**Section sources**
- [append.rs:141-196](file://port/skey-core/src/engine/append.rs#L141-L196)
- [append.rs:577-586](file://port/skey-core/src/engine/append.rs#L577-L586)

### Capitalization and quick Telex shortcuts
- apply_upper_case_first_char(): Arms capitalization after sentence-ending punctuation or control characters; lowers the next Vietnamese letter and forces uppercase key code.
- apply_quick_telex(): Expands doubled consonants (e.g., “cc” → “ch”) and handles “uu” shortcut to “ư + ơ” with horn marks; bypasses normal dispatch when matched.

```mermaid
flowchart TD
SStart["apply_upper_case_first_char(ev)"] --> Opt{"upper_case_first_char enabled?"}
Opt -- No --> SFalse["return false"]
Opt -- Yes --> Reset{"ch_type == RESET?"}
Reset -- Yes --> Arm["capitalise_next = true return false"]
Reset -- No --> Sentence{"sentence end punctuation?"}
Sentence -- Yes --> Arm2["capitalise_next = true return false"]
Sentence -- No --> Break{"ch_type == WORD_BREAK?"}
Break -- Yes --> SFalse
Break -- No --> Wait{"capitalise_next?"}
Wait -- No --> SFalse
Wait -- Yes --> Lower["lower vn_sym, force uppercase key_code<br/>capitalise_next = false<br/>return changed?"]
```

**Diagram sources**
- [shortcuts.rs:182-229](file://port/skey-core/src/engine/shortcuts.rs#L182-L229)

```mermaid
flowchart TD
QStart["apply_quick_telex(ev)"] --> Enabled{"quick_telex enabled && current >= 0?"}
Enabled -- No --> QNone["return None"]
Enabled -- Yes --> Normal{"ev_type == NORMAL && ch_type == UKC_VN?"}
Normal -- No --> QNone
Normal -- Yes --> UU{"key == 'u' and prev == 'u'?"}
UU -- Yes --> UUApply["convert prev to 'ư', append 'ơ' with horn<br/>mark_change(last) return Some(1)"]
UU -- No --> Doubled{"prev and current are same ASCII letter?"}
Doubled -- No --> QNone
Doubled -- Yes --> Expand["lookup doubled consonant table<br/>replace key_code with expansion<br/>process_append(ev) mark_change(current) return Some(1)"]
```

**Diagram sources**
- [shortcuts.rs:232-297](file://port/skey-core/src/engine/shortcuts.rs#L232-L297)

**Section sources**
- [shortcuts.rs:182-297](file://port/skey-core/src/engine/shortcuts.rs#L182-L297)

## Dependency Analysis
- Engine depends on InputProcessor to classify keys and build KeyEvent.
- dispatch_inner() routes to processors that depend on phonetic tables and rules for validity checks.
- process_append() integrates with word assembly and spell-checking logic.
- Shortcuts modify KeyEvent before dispatch or directly manipulate buffer state.

```mermaid
graph LR
IP["InputProcessor"] --> EV["KeyEvent"]
EV --> DI["dispatch_inner"]
DI --> PR["process_roof"]
DI --> PH["process_hook"]
DI --> PT["process_tone"]
DI --> PW["process_telex_w"]
DI --> PA["process_append"]
SC["Shortcuts"] --> DI
PR --> VT["VSEQ tables / rules"]
PH --> VT
PT --> VT
PW --> PH
PA --> VA["append_vowel / append_consonnant"]
```

**Diagram sources**
- [mod.rs:227-246](file://port/skey-core/src/engine/mod.rs#L227-L246)
- [transform.rs:70-712](file://port/skey-core/src/engine/transform.rs#L70-L712)
- [append.rs:141-196](file://port/skey-core/src/engine/append.rs#L141-L196)
- [shortcuts.rs:182-297](file://port/skey-core/src/engine/shortcuts.rs#L182-L297)
- [input/mod.rs:162-192](file://port/skey-core/src/input/mod.rs#L162-L192)

**Section sources**
- [mod.rs:227-246](file://port/skey-core/src/engine/mod.rs#L227-L246)
- [transform.rs:70-712](file://port/skey-core/src/engine/transform.rs#L70-L712)
- [append.rs:141-196](file://port/skey-core/src/engine/append.rs#L141-L196)
- [shortcuts.rs:182-297](file://port/skey-core/src/engine/shortcuts.rs#L182-L297)
- [input/mod.rs:162-192](file://port/skey-core/src/input/mod.rs#L162-L192)

## Performance Considerations
- dispatch_inner() uses a direct match on ev_type, avoiding an extra compare path that was measured slower than the jump table generated by LLVM.
- Quick Telex shortcuts short-circuit common patterns early, reducing work in the main dispatch path.
- First-character capitalization is applied once per keystroke and avoids redundant processing when disabled.
- Processors validate context quickly and fall back to process_append() when rules do not apply, minimizing unnecessary computation.

[No sources needed since this section provides general guidance]

## Troubleshooting Guide
- If a keystroke does not produce expected output, verify the InputProcessor mapping for the active input method and ensure ev_type/ch_type are set correctly.
- For roof/hook/tone issues, check that the current buffer state satisfies the required forms and that free_marking/spell-check options allow editing at the intended position.
- When quick Telex is enabled, confirm that the previous character meets the conditions for expansion and that the replacement is valid.
- For Telex 'w', inspect used_as_map_char behavior and whether mapping succeeded or fell back to hook.

**Section sources**
- [input/mod.rs:162-192](file://port/skey-core/src/input/mod.rs#L162-L192)
- [transform.rs:70-712](file://port/skey-core/src/engine/transform.rs#L70-L712)
- [shortcuts.rs:182-297](file://port/skey-core/src/engine/shortcuts.rs#L182-L297)

## Conclusion
The dispatch mechanism efficiently routes keystrokes to specialized processors based on KeyEvent classification. Capitalization and quick Telex shortcuts optimize common typing patterns before delegation. The match-based dispatch_inner() ensures clear separation of concerns and fast routing, while process_append() serves as a robust default for word assembly and edge cases. Together, these components provide a responsive and accurate Vietnamese typing experience.

[No sources needed since this section summarizes without analyzing specific files]
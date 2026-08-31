# SKey Core — Rust Vietnamese Input Engine

A complete, zero-heap, memory-safe port of the Vietnamese input method engine to Rust
(serving as the high-performance core of SKey), built parity-first: every optimisation
is applied only after the port reproduces the original byte for byte, and is re-verified
against it afterwards.

## Status

| Component | State |
|---|---|
| `UkEngine` state machine | ported, verified |
| `UkInputProcessor`, all five input methods | ported, verified |
| All 21 output charsets | ported, verified |
| Macro table, file format, expansion | ported, verified |
| User defined key map | ported, verified |
| C ABI (`skey_engine_*` and legacy `UnikeyFilter`) | ported, verified |
| Context C ABI, multi instance | added |
| OpenKey's five engine level typing options | added, all off by default |

Nothing is left stubbed.

## How parity is established

`port/oracle` links the original C++ engine and speaks a line protocol on
stdin, emitting one trace line per keystroke: backspace count, output
byte count, output kind, and the output bytes in hex. `port/difftest`
speaks the same protocol against the Rust engine. Any behavioural
difference shows up as a text diff.

Per keystroke, not per word: the intermediate states are what a typist
actually feels, and a port can produce the right final word through a
wrong sequence of edits.

The same harness source also builds against the Rust library through its
C ABI (`make oracle-rust`), so `oracle` versus `oracle_rust` tests the
ABI end to end rather than just the engine.

    make verify

| Sweep | Coverage | Result |
|---|---|---|
| `sweep` | exhaustive, all sequences of length 1 to 3 over the 22 character core alphabet, plus length 4, plus random sequences with backspace, restore, single mode and caps changes | 2.35 million sequences, no divergence |
| `soak` | 120000 random sequences of length 3 to 25 | 1.8 million trace lines per configuration |
| charset matrix | 21 charsets x 5 input methods x 16 option sets | 1680 configurations, no divergence |
| `macrosweep` | generated macro files, UTF-8 and legacy VIQR, expansion plus the rewritten file compared byte for byte | 216 configurations, no divergence |
| `keymapsweep` | generated user key maps, including comments, odd spacing, duplicate keys, unknown labels and malformed lines | 240 configurations, no divergence |
| `capi-check` | every sweep again, driving Rust through the C ABI | no divergence |
| `test` | frozen corpus replayed against hashes recorded from the C++ engine, no C++ build needed | 328 configurations |

The option matrix is the outer loop, never a separate test: input method
x charset x `freeMarking` x `modernStyle` x `spellCheck` x
`autoNonVnRestore`.

`UnikeySetInputMethod` accepts only Telex, VNI, VIQR and the user map, so
MsVi and simple Telex cannot be selected through the public API even
though the engine implements them. The oracle reaches
`UkInputProcessor::setIM` directly so those two are covered too.

## Bugs found in the original

Two out of bounds reads that the C++ performs silently and Rust refuses
to. Neither can be reproduced faithfully, because the value read depends
on the compiler's data layout, so the port encodes the intended meaning
and the harness confirms nothing observable changed.

1. `appendConsonnant` indexes `CSeqList[cs]` without checking for
   `cs_nil`. Reachable: `processNoSpellCheck` can store any of
   `a e f i j o u w y z` with form `vnw_c` and a nil sequence, and the
   next consonant lands there. Type `z` then `d` to hit it.
2. `processBackspace` reads `m_buffer[m_current - 1].vseq` after a guard
   that lets `vnw_nonVn` and `vnw_empty` through, where that field holds
   a stale value from whatever previously occupied the slot.

And one place where the original is simply unspecified: `macCompare`
compares macro keys case folded, so two keys differing only in case
compare equal. `qsort` is not stable, so their relative order and which
of them `lookup` finds depend on the platform. The port uses a stable
sort, making the tie break insertion order, which is at least
reproducible.

## Deviations the harness caught in the port itself

Worth recording, because each looked like an improvement:

1. `UkInputProcessor::setIM` has no `case UkSimpleTelex`, so it falls
   into the default arm and silently becomes Telex, which makes
   `SimpleTelexMethodMapping` dead data. An early version wired that
   table up. It failed all 32 simple Telex option sets at once. The
   table stays dead.
2. `VIQRCharset::startInput` sets `m_atWordBeginning` to 1. Rust's
   `Default` gave `false`, which silently turned the legacy macro file
   entry `DD` into two plain letters instead of the single character
   d with stroke.

## Aliasing the port has to model, not simplify

`restoreKeyStrokes` takes `int & backs` and `int & outSize`, and its two
callers bind them to different things. That is not a detail, it changes
the output.

* From `processWordEnd`, `backs` is `m_backs` itself, so the bail out
  wipes the engine's accumulated backspace count; and `outSize` is a
  local snapshot of `*m_pOutSize`, so the write bound stays put.
* From `UnikeyRestoreKeyStrokes`, `backs` is a separate variable, so the
  count survives; and `outSize` is `UnikeyBufChars`, which is exactly
  what `m_pOutSize` points at, so the bound is live.

Why live matters: the restore loop feeds key strokes back through
`processAppend`, which can re-enter `checkEscapeVIQR`, which assigns 2 to
`*m_pOutSize`. From `processWordEnd` that shrinks the bound checked
afterwards, so the whole output is discarded. From the public entry point
it truncates the restore mid loop. Both are observable, and both are
reproduced.

`checkEscapeVIQR` also writes buffer positions 0 and 1 directly rather
than through the stream, clobbering the first two bytes the restore loop
had already written while its own cursor keeps running.

## Optimisations applied, each re-verified

| Change | Effect |
|---|---|
| `qsort` at start up plus `bsearch` through a comparator, replaced by compile time sorted packed keys and a plain binary search | no start up cost, no indirect call, one integer compare per step |
| Then the searches themselves, replaced by transition tables | the keystroke path performs no search at all |
| 153 entry sorted `VCPair` array plus `bsearch`, replaced by a 70 entry `u32` bitmap | one AND instead of a search, 280 bytes instead of 1224 |
| The `k` consonant's vowel list, scanned linearly on every call, replaced by a `u128` mask | one AND |
| `getSeqSteps` encoded a range through the virtual `putChar` into a null stream just to count bytes, replaced by a counting sink | backspace counting stores nothing |
| The virtual `VnCharset` hierarchy, replaced by one enum dispatched statically | no vtable on the keystroke path |
| VIQR's eight KMP matchers, replaced by a rolling suffix window | same answer, far less machinery |
| Charset `m_stdMap` tables built in constructors, now `const fn` | computed at compile time |
| Every `lookupVSeq` and `lookupCSeq` call, replaced by compile time transition tables | one array load, no search at all |
| `getTonePosition`, the most called helper, replaced by a table | one load instead of six branches |
| `isValidCV`, replaced by a `u128` bitmap per consonant | one AND |
| `getSeqSteps` fast path extended to the six single byte charsets | no encoding for them either |
| `WordInfo` packed from 36 bytes to 16 | buffer 4608 bytes to 2048 |
| The stroke buffer stores only what is read back | 3072 bytes to 1024 |
| `CMacroTable`'s fixed 136 KB arena, replaced by storage proportional to content | a table with ten macros costs a few hundred bytes |
| `processTelexW`'s function level `static`, now a field | thread safe, and identical for the single engine the original creates |

Measured on an M series Mac, ns per keystroke over a 267000 event corpus,
before and after the table work:

| Configuration | Before | After |
|---|---|---|
| Telex, XUTF8 | 21.1 | 19.1 |
| Telex, Unicode | 29.3 | 19.1 |
| Telex, TCVN3 | 22.6 | 19.0 |
| Telex, VNI Windows | 22.2 | 19.1 |
| Telex, VIQR | 28.4 | 20.7 |
| Telex, CP1258 | 21.7 | 19.2 |
| VNI, XUTF8 | 19.9 | 16.8 |

Memory: 4712 bytes per engine plus the macro table's actual content. The
C++ engine's two buffers alone are 7680 bytes and its `CMacroTable` adds
a fixed 136 KB inside `UkSharedMem`.

### Later round: hot path, portability, and the C ABI

| Change | What it does | Measured |
|---|---|---|
| `macro_match` no longer clones the matched text | the expansion path is allocation free; the match is copied straight into a stack buffer | not resolvable, and it only runs on a macro hit at word end, not on every key |
| `Sink::put2` and `put3` | one bounds check for a multi byte group instead of two or three | 2 to 4 per cent on the multi byte charsets in one stable measurement, inside noise in a later one |
| ASCII straight through in the UTF-8 encoder | skips `to_unicode` for pass through characters | not resolvable; Vietnamese output is never ASCII, so the path is rare |
| VIQR escape window as a `u64` | shift and OR instead of a seven byte `copy_within`, one mask and compare per pattern instead of eight slice comparisons, reset is assigning zero | under a per cent; kept because the code is strictly simpler and the struct shrank |
| Macro table as one flat arena | two allocations for N macros instead of 2N, and the binary search walks adjacent memory | not measured on the keystroke path, which never touches it |

Note on `put2`: writing the group only when all of it fits is **not**
equivalent. With one byte of room left, two `put` calls store the first
byte and then fail, and the reported count is what the caller reads as
the output size. The fast path here falls back to individual `put` calls
at the boundary for exactly that reason.

Note on measurement: the small deltas above sit at the edge of what this
machine resolves. Absolute numbers drifted by 15 per cent between runs
under thermal load, so the table reports what was actually observed
rather than a tidy figure. Only the transition table work above produced
a separation large enough to state without qualification.

### Memory, further

Two more changes that alter no behaviour at all, both verified in a debug
build with their range assertions active:

| Change | Effect |
|---|---|
| `form`, tone level and capitalisation packed into one byte | entry 16 bytes to 12, buffer 2048 to 1536 |
| the key map narrowed to `[u8; 256]` | 512 bytes to 256, because every action fits in a byte: events run to 19 and a character mapping is `EV_COUNT + lexi`, at most 206 |

A third, same kind:

| Change | Effect |
|---|---|
| the stored character type dropped from the key stroke buffer, and the buffer split into two parallel arrays | 1024 bytes to 640 |

`char_type` reads only static tables, so it is a pure function of the key
code, and the buffer stored exactly `char_type(key_code)`. Keeping it was
pure redundancy; the three places that wanted it derive it. Splitting the
remaining `u32` and its flag into parallel arrays then removes the padding
that a struct of the two would carry.

Engine footprint: 4736 bytes to **3584**.

### One behaviour change, and where it deliberately stops

`autoNonVnRestore` restores a word only when the result is
phonotactically invalid. Measured against 567 common English and
programming words, the engine mangles 52 of them anyway, because the
mangled form is perfectly valid Vietnamese and the check cannot see
anything wrong: `test` becomes `tét`, `data` becomes `dât`, `too` becomes
`tô`.

Those 52 split cleanly, and the split is measured rather than guessed:

* **11 where no Vietnamese mark was produced at all**, so a key was
  simply swallowed: `off` to `of`, `pass` to `pas`, `error` to `eror`,
  and likewise `errors`, `guess`, `message`, `offset`, `passed`,
  `password`, `session`, `suffix`. Nobody types those on purpose.
  Restoring the key strokes takes nothing away from anyone, so this is
  the `swallowed_key_restore` option. `autoNonVnRestore` cannot reach
  them: it separately refuses to restore a word with no Vietnamese mark,
  which is exactly this case.
* **41 where the result is valid Vietnamese.** Restoring those would fix
  English by breaking Vietnamese: typing `theme` is how you type `thêm`,
  `did` is `đi`, `its` is `ít`, `too` is `tô`, `test` is `tét`, `list` is
  `lít`. **They are not in the table**, on purpose. A word list that
  contains them is a trade, not a fix.

The option is off by default, and off is byte for byte identical to the
original. `enwords` carries the table, and both C ABIs expose it so a
front end can show the user exactly what the option covers. The table is
one blob plus offsets, 87 bytes, against 239 for a `&[&str]` of the same
words.

Tests pin all of it: every listed word comes through intact with the
option on **and** is verified to be mangled with it off, so no entry is
dead weight; and the thirteen Vietnamese words above are asserted
unchanged either way.

### OpenKey style typing shortcuts

Five options, all off by default, and off is byte for byte identical to the
original. None of them changes the state machine: three rewrite the key
event before dispatch, one replays the word at the break, and one changes
character classification.

| Option | Substitution | Decided |
|---|---|---|
| `quick_telex` | `cc` to `ch`, `gg` `gi`, `kk` `kh`, `nn` `ng`, `qq` `qu`, `pp` `ph`, `tt` `th`, and `uu` to u horn plus o horn | when the second key arrives |
| `quick_start_consonant` | `f` to `ph`, `j` to `gi`, `w` to `qu` | at the word break |
| `quick_end_consonant` | `g` to `ng`, `h` to `nh`, `k` to `ch` | at the word break |
| `upper_case_first_char` | capitalise after a full stop or a new line | when the letter arrives |
| `allow_consonant_zfwj` | classify `z` `f` `w` `j` as Vietnamese | on classification |

**Both consonant shortcuts are deferred, and that is not a convenience.**
For the coda, `g` after `n` is a legitimate ending, so rewriting on sight
turns `hang` into `hanng`. For the onset, Telex already uses `f`, `j` and
`w` as the huyen key, the nang key and the horn key, and `w` alone is how
you type u horn; reinterpreting them the moment they arrive would take that
away. Only at the break is there enough information, and OpenKey reaches
the same conclusion, which is why its `checkQuickConsonant` runs on a break
code rather than on the key.

At the break, when and only when the word is invalid as typed, three
candidates are tried in order, onset, coda, then both. Each runs on a
throwaway engine and is committed only if it rescues the word. That is what
leaves `hang` alone, leaves `zzg` alone, and keeps `w` typing u horn.

What each one takes away:

* `quick_telex`, `quick_start_consonant`, `quick_end_consonant`: nothing.
  A doubled consonant is never valid Vietnamese, `f`, `j` and `w` can never
  begin a Vietnamese word, and the coda rule only fires on a word that was
  already invalid.
* `upper_case_first_char`: the ability to start a sentence in lower case
  without going back to fix it.
* `allow_consonant_zfwj`: this one genuinely changes spell checking, which
  is why it is last and why its parity run covers every sweep rather than
  the matrix alone.

`make quicksweep` checks the shape of their effect on a 20000 sequence
corpus, since there is no reference to compare against: each option must
change something, or it is dead code, and the narrow ones must not change
much, or their guard is reaching ordinary Vietnamese. Measured: 0.15, 0.12,
0.01, 0.45 and 0.36 per cent of trace lines.

Three of OpenKey's options are absent because they already exist here:
`vTempOffSpelling` is `UnikeySetSingleMode`, which the shipped front ends
bind to Ctrl+Shift+Z; `vAutoCapsMacro` is the `VnCase` logic in
`macroMatch`, which turns `btw` into `By the way` and `BTW` into `BY THE
WAY`; and `vUseMacro`, `vFreeMark`, `vCheckSpelling`,
`vUseModernOrthography` and `vRestoreIfWrongSpelling` map onto options
UniKey already had. Seven more are front end concerns: `vSwitchKeyStatus`,
`vFixRecommendBrowser`, `vUseSmartSwitchKey`, `vRememberCode`,
`vOtherLanguage`, `vTempOffOpenKey` and `vUseMacroInEnglishMode`. The engine
has no notion of an application, a hot key or a browser address bar.

### Portability

    make portability

* **No allocator at all.** `--no-default-features` gives a `no_std`
  build with no `alloc`: every input method and all 21 output charsets,
  out of fixed size static memory, which is what a keyboard firmware
  target needs. Macros, the key map parser and the charset decoders need
  `alloc` and are gated behind it; without them `macro_match` never
  matches, which is the engine with macros switched off.
* **WebAssembly.** `wasm32-unknown-unknown` builds.
* **serde.** Optional derives on `Options`, `Charset` and `OutputType`,
  for front ends that keep configuration in JSON, TOML or YAML.

### Two C ABIs

The legacy one is `src/ukinterface` unchanged, process wide globals and
all, because that is what every existing front end is written against.
`static mut` is gone from it: the exported symbols keep the layout C
expects but are wrapped so no Rust reference to a mutable static is ever
taken, which is what the 2024 edition wants.

The context API alongside it has no globals: `skey_engine_create` (with
`unikey_engine_create` alias), `_filter`, `_backspace`, `_restore`, `_free`
and the setters, over an opaque handle. `make ctx-check` drives it from a C
harness speaking the same protocol as the oracle, and that harness keeps a
**second** engine instance busy on every key, so any state shared between
instances would show up as a divergence. It does not: 1680 configurations,
no divergence.

### One proposal that was rejected on design grounds

Sharing the built in key maps by reference so `InputProcessor` does not
carry its own `[u16; 256]`, saving 512 bytes per engine. Not done:

* A `&'static` for the built ins and something owned for user maps needs
  either a lifetime parameter on `Engine`, which infects every signature
  and cannot be expressed as an owned handle across the C ABI, or a
  `Box`, which breaks the allocator free build that was just added.
* It puts an indirection on `key_map[key_code]`, which runs twice per
  keystroke, to save 512 bytes on a per session singleton that already
  carries a 1 KB output buffer.

### Two optimisations that were measured and rejected

Kept here because the negative results are the useful part.

1. **Fusing the whole CVC validity relation into one bitmap.** 31
   consonant slots by 71 vowel slots, each a 31 bit mask over the
   trailing consonant, with the quyn and gieng exceptions folded in at
   generation time: one load and one AND, zero branches. Measured
   identical to the branchy version, because the common path is already
   two well predicted nil tests and one masked load. It cost 8.8 KB of
   tables for nothing, so it is not in the tree.
2. **A fast path for `vneNormal` ahead of the dispatch match.** Plain
   characters are the overwhelming majority of key events, so testing
   for them on a directly predicted branch looked free. It measured
   consistently 0.4 ns per keystroke slower: the jump table LLVM builds
   for the full match is already cheaper than an extra compare on every
   event.

Both are recorded in comments at the sites, so nobody has to rediscover
them.

### Against the original, measured

    make bench-compare

Both engines read the same corpus file, parse it before the clock starts,
run the same warm up and round count, and are built with comparable
optimisation: the C++ at `-O3 -flto -march=native`, Rust's release profile
with `lto` and `target-cpu=native`. Runs are interleaved and the minimum
taken, because absolute numbers on a laptop drift with thermal state while
the ratio between interleaved measurements does not.

| Configuration | C++ | Rust | ratio |
|---|---|---|---|
| Telex, XUTF8 | 27.6 ns | 21.2 ns | 0.77x |
| Telex, Unicode | 30.0 ns | 22.3 ns | 0.74x |
| Telex, VIQR | 32.5 ns | 23.8 ns | 0.73x |
| Telex, TCVN3 | 29.5 ns | 21.9 ns | 0.74x |
| Telex, VNI Windows | 30.0 ns | 21.9 ns | 0.73x |
| VNI, XUTF8 | 25.7 ns | 18.9 ns | 0.74x |

Rust takes 74 per cent of the time, so about 1.35 times the speed.

Most of that is not the language, it is the algorithmic work. Per
keystroke the C++ still pays for `bsearch` through a comparator function
pointer on every sequence lookup, a virtual `putChar` per output
character, and `getSeqSteps` encoding a range into a throwaway stream just
to count bytes. Those are gone here. A literal port with the same
structure would land much closer to even.

### Perspective

Rust does not make this engine meaningfully faster: it already handled a
keystroke in well under a microsecond. What the port buys is memory
safety on a process wide keyboard hook, thread safety, a `no_std` core
that embeds anywhere, and a test suite that makes changing the spelling
rules survivable.

## Layout

    skey-core/           no_std, forbid(unsafe_code)
      src/phonetics/     linguistic rules, lexi symbols, transition & lookup tables
      src/engine/        state machine, transform, append, shortcuts & dispatch
      src/input/         key classification and per-method maps (Telex, VNI, VIQR)
      src/charset/       all 21 charsets, encode and decode
      src/extensions/    swallowed words, quick shortcuts, macro table, user keymaps
      src/out.rs         output sinks
      src/limits.rs      fixed limits, allocator free
      src/testkit.rs     corpus generator and trace hasher, feature gated
    skey-capi/           both C ABIs, cdylib and staticlib (libskey.a)
      include/skey.h     native SKey C header
      include/unikey.h   drop-in compatibility header
    skey-cli/            interactive terminal REPL
    tablegen/            dumps every table straight out of the C++ binary
    oracle/              the reference engine behind a line protocol
    difftest/            the Rust side of the protocol, plus the drivers

Tables are dumped from the compiled C++ rather than parsed from source,
so they cannot drift. `make tables` regenerates them.

The keystroke path allocates nothing and performs no search. `alloc` is
used only by the macro table, the key map parser and the charset
decoders, none of which run while typing.

`src/seq.rs` holds the transition tables, all derived from the dumped
tables by `const fn`, so they cannot drift from the original data. The
search functions they replaced are still in `engine.rs` under
`#[cfg(debug_assertions)]`, and every table use asserts against them in
debug builds. `make verify` runs the whole matrix in a debug build for
exactly that reason: 1680 configurations, no assertion failure, which is
what makes swapping a search for a generated table safe rather than
hopeful.

## What must not be tidied up

`get_tone_position` is called with three different values for
`terminated` (`v_end == current`, `true`, `false`). The five tone
repositioning blocks look like duplicates and are not. Merging them
changes behaviour.

The numeric encoding of `Lexi` is load bearing: even is upper case, odd
is lower, each tone level is plus two, and `StdVnChar` is the index plus
`0x10000` minus one when capitalised. `lexi.rs` asserts this at compile
time. Reordering the enum silently breaks every tone decision.

`used_as_map_char` survives `reset()`, in both engines, because the
original holds it in a function level `static`. It looks like a bug and
may well be one, but it is observable behaviour.

## Not carried over

The `#if defined(_WIN32)` branch in `processAppend` that expands a macro
on Enter. The POSIX build does not compile it, so neither does this port;
it belongs behind a feature flag when a Windows front end needs it.

`UkSharedMem` and the shared memory design. No current front end needs
it, and it is what forced the fixed 136 KB macro arena.

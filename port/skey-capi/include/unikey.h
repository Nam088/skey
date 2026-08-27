/* C interface to the Rust port of the UniKey engine.
 *
 * Deliberately identical to src/ukinterface/unikey.h, so an existing
 * front end links against libunikey instead of the C++ objects with no
 * source change. The declarations below are the original ones; the block
 * at the end is additions the original does not have.
 *
 * Initialisation:
 *   1. UnikeySetup: default options, TELEX input, UTF-8 output
 *   2. UnikeySetInputMethod / UnikeySetOutputCharset / UnikeySetOptions
 *
 * Key handling:
 *   Call UnikeySetCapsState, then UnikeyFilter, then read
 *   UnikeyBackspaces, UnikeyBufChars and UnikeyBuf. Do not call
 *   UnikeyFilter for Enter, Tab, arrows, Delete or Backspace.
 *   UnikeyResetBuf on focus or caret change; UnikeyBackspacePress on
 *   Backspace.
 */
#ifndef __UNIKEY_RS_H
#define __UNIKEY_RS_H

#if defined(__cplusplus)
extern "C" {
#endif

typedef enum { UkTelex, UkVni, UkViqr, UkMsVi, UkUsrIM, UkSimpleTelex } UkInputMethod;
typedef enum { UkCharOutput, UkKeyOutput } UkOutputType;

typedef struct _UnikeyOptions {
    int freeMarking;
    int modernStyle;
    int macroEnabled;
    int useUnicodeClipboard;
    int alwaysMacro;
    int strictSpellCheck;
    int useIME;
    int spellCheckEnabled;
    int autoNonVnRestore;
} UnikeyOptions;

extern unsigned char UnikeyBuf[];
extern int UnikeyBackspaces;
extern int UnikeyBufChars;
extern int UnikeyOutput; /* a UkOutputType value */

void UnikeySetup(void);
void UnikeyCleanup(void);
void UnikeyResetBuf(void);
void UnikeyFilter(unsigned int ch);
void UnikeyPutChar(unsigned int ch);
void UnikeySetCapsState(int shiftPressed, int CapsLockOn);
void UnikeyBackspacePress(void);
void UnikeyRestoreKeyStrokes(void);
void UnikeySetOptions(const UnikeyOptions *pOpt);
void CreateDefaultUnikeyOptions(UnikeyOptions *pOpt);
void UnikeyGetOptions(UnikeyOptions *pOpt);
void UnikeySetInputMethod(int im);
int UnikeySetOutputCharset(int charset);
int UnikeyLoadMacroTable(const char *fileName);
int UnikeyLoadUserKeyMap(const char *fileName);
void UnikeySetSingleMode(void);

/* ---- additions, not present in the original interface ----
 *
 * UnikeySetInputMethod cannot select MsVi or simple Telex, because the
 * original's setter rejects them. These reach the processor directly and
 * let the macro table be read back, which the differential harness needs.
 */
void UnikeySetInputMethodRaw(int im);
int UnikeyMacroCount(void);
int UnikeyMacroGet(int idx, int which, unsigned int *buf, int max);

#if defined(__cplusplus)
}
#endif

#endif

/* ============================== context API ==============================
 *
 * The interface above is process wide globals, which is what the original
 * was and what existing front ends expect. Anything that needs more than
 * one input session, or any thread safety, uses this instead: the engine
 * is an opaque handle and there is no shared state.
 */

typedef struct UnikeyEngine UnikeyEngine;

typedef struct UnikeyEdit {
    int backspaces;   /* backspaces to send before the new bytes  */
    int len;          /* output bytes available from _output      */
    int out_type;     /* 0 UkCharOutput, 1 UkKeyOutput           */
    int handled;      /* 0 means pass the original key through    */
} UnikeyEdit;

UnikeyEngine *unikey_engine_create(void);
void unikey_engine_free(UnikeyEngine *eng);

void unikey_engine_reset(UnikeyEngine *eng);
void unikey_engine_set_single_mode(UnikeyEngine *eng);
void unikey_engine_set_caps_state(UnikeyEngine *eng, int shiftPressed, int capsLockOn);
void unikey_engine_set_input_method(UnikeyEngine *eng, int im);
/* Reaches the processor directly, so MsVi and simple Telex work here. */
void unikey_engine_set_input_method_raw(UnikeyEngine *eng, int im);
int  unikey_engine_set_charset(UnikeyEngine *eng, int charset);
void unikey_engine_set_options(UnikeyEngine *eng, const UnikeyOptions *pOpt);
void unikey_engine_get_options(UnikeyEngine *eng, UnikeyOptions *pOpt);

UnikeyEdit unikey_engine_filter(UnikeyEngine *eng, unsigned int ch);
void       unikey_engine_put_char(UnikeyEngine *eng, unsigned int ch);
UnikeyEdit unikey_engine_backspace(UnikeyEngine *eng);
UnikeyEdit unikey_engine_restore(UnikeyEngine *eng);

/* Copies up to max output bytes into buf, returns how many were written. */
int unikey_engine_output(UnikeyEngine *eng, unsigned char *buf, int max);

int unikey_engine_load_macro_table(UnikeyEngine *eng, const char *fileName);
int unikey_engine_load_user_key_map(UnikeyEngine *eng, const char *fileName);

/* ------------------------ swallowed key restore -------------------------
 *
 * Restores the key strokes when a listed word came out with a key
 * swallowed and no Vietnamese mark produced: off became of, pass became
 * pas, error became eror. autoNonVnRestore cannot cover these, because it
 * only fires on a phonotactically invalid result and separately refuses to
 * restore a word carrying no Vietnamese mark, which is exactly this case.
 *
 * A dedicated setter rather than a new UnikeyOptions field: that struct is
 * part of the original ABI and growing it would break existing binaries.
 *
 * Off by default, and off is byte for byte identical to the original.
 * Words whose mangled form is valid Vietnamese are deliberately not in the
 * table: typing theme is also how you type thêm, did is đi, its is ít.
 */
void UnikeySetSwallowedKeyRestore(int on);
int  UnikeyGetSwallowedKeyRestore(void);
void unikey_engine_set_swallowed_key_restore(UnikeyEngine *eng, int on);

/* The table, so a front end can show what the option covers. */
int unikey_swallowed_word_count(void);
int unikey_swallowed_word(int idx, char *buf, int max);

/* ------------------------- OpenKey style options ------------------------
 *
 * All four default to off, and off is byte for byte identical to the
 * original. Dedicated setters rather than new UnikeyOptions fields,
 * because growing that struct would break existing binaries.
 *
 *   quick telex            cc ch, gg gi, kk kh, nn ng, qq qu, pp ph,
 *                          tt th, uu u-horn o-horn
 *   quick start consonant  f ph, j gi, w qu
 *   quick end consonant    g ng, h nh, k ch, decided at the word break
 *   upper case first char  capitalise after a full stop or a new line
 */
void UnikeySetQuickTelex(int on);
int  UnikeyGetQuickTelex(void);
void unikey_engine_set_quick_telex(UnikeyEngine *eng, int on);

void UnikeySetQuickStartConsonant(int on);
int  UnikeyGetQuickStartConsonant(void);
void unikey_engine_set_quick_start_consonant(UnikeyEngine *eng, int on);

void UnikeySetQuickEndConsonant(int on);
int  UnikeyGetQuickEndConsonant(void);
void unikey_engine_set_quick_end_consonant(UnikeyEngine *eng, int on);

void UnikeySetUpperCaseFirstChar(int on);
int  UnikeyGetUpperCaseFirstChar(void);
void unikey_engine_set_upper_case_first_char(UnikeyEngine *eng, int on);

/* Treat z, f, w and j as ordinary consonants. The riskiest of the five:
 * the only one that changes character classification rather than rewriting
 * a key event. */
void UnikeySetAllowConsonantZFWJ(int on);
int  UnikeyGetAllowConsonantZFWJ(void);
void unikey_engine_set_allow_consonant_zfwj(UnikeyEngine *eng, int on);

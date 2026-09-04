/* SKey - Bộ gõ tiếng Việt macOS
 * C interface to the SKey Vietnamese typing engine.
 */
#ifndef __SKEY_RS_H
#define __SKEY_RS_H

#if defined(__cplusplus)
extern "C" {
#endif

/* ============================== Types & Enums ============================== */

/** Supported input methods. */
typedef enum {
    UkTelex,       /**< Telex input method (default). */
    UkVni,         /**< VNI numeric input method. */
    UkViqr,        /**< VIQR punctuation input method. */
    UkMsVi,        /**< Microsoft Vietnamese layout. */
    UkUsrIM,       /**< User-defined custom input method. */
    UkSimpleTelex  /**< Simple Telex input method. */
} UkInputMethod;

/** Type of output emitted by the engine. */
typedef enum {
    UkCharOutput,  /**< Output is formatted characters (UTF-8 bytes). */
    UkKeyOutput    /**< Output is raw key characters. */
} UkOutputType;

/** Configuration options for the SKey typing engine. */
typedef struct _SKeyOptions {
    int freeMarking;          /**< Allows placing accent marks on vowels anywhere in the word (1=on, 0=off). */
    int modernStyle;          /**< Places tone mark on the second vowel for oa, oe, uy (1=on, 0=off). */
    int macroEnabled;         /**< Enables macro replacement expansion (1=on, 0=off). */
    int useUnicodeClipboard;  /**< Reserved for clipboard operations (1=on, 0=off). */
    int alwaysMacro;          /**< Reserved option for macro execution (1=on, 0=off). */
    int strictSpellCheck;     /**< Strict Vietnamese spelling verification (1=on, 0=off). */
    int useIME;               /**< Reserved IME flag. */
    int spellCheckEnabled;    /**< General Vietnamese spell checking (1=on, 0=off). */
    int autoNonVnRestore;     /**< Automatically restores raw keystrokes for non-Vietnamese words (1=on, 0=off). */
} SKeyOptions;

/* ============================== SKey Context API ============================== */

/** Opaque handle to an isolated SKey typing engine instance. */
typedef struct SKeyEngine SKeyEngine;

/**
 * Result of a keystroke processing operation.
 */
typedef struct SKeyEdit {
    int backspaces;   /**< Number of backspaces the front-end must send before emitting new bytes. */
    int len;          /**< Number of transformed output bytes available via `skey_engine_output`. */
    int out_type;     /**< Output type: 0 (`UkCharOutput`) or 1 (`UkKeyOutput`). */
    int handled;      /**< Non-zero if keystroke was consumed/transformed; 0 means pass original key through. */
} SKeyEdit;

/**
 * Creates a new, isolated `SKeyEngine` instance initialized with default settings.
 *
 * @return Pointer to newly allocated `SKeyEngine`, or NULL on allocation failure.
 *         Must be freed with `skey_engine_free`.
 */
SKeyEngine *skey_engine_create(void);

/**
 * Frees an `SKeyEngine` instance previously allocated by `skey_engine_create`.
 *
 * @param eng Pointer to `SKeyEngine` to free. Safe to pass NULL.
 */
void skey_engine_free(SKeyEngine *eng);

/**
 * Resets the engine state machine and word buffer.
 *
 * @param eng Pointer to an initialized `SKeyEngine`. Must not be NULL.
 */
void skey_engine_reset(SKeyEngine *eng);

/**
 * Temporarily switches off diacritic transformation and spell-checking for the current word.
 *
 * @param eng Pointer to an initialized `SKeyEngine`. Must not be NULL.
 */
void skey_engine_set_single_mode(SKeyEngine *eng);

/**
 * Updates Shift and CapsLock modifier state in the engine.
 *
 * @param eng Pointer to an initialized `SKeyEngine`. Must not be NULL.
 * @param shiftPressed Non-zero if Shift key is currently pressed; 0 otherwise.
 * @param capsLockOn Non-zero if CapsLock is currently active; 0 otherwise.
 */
void skey_engine_set_caps_state(SKeyEngine *eng, int shiftPressed, int capsLockOn);

/**
 * Sets the active input method (Telex, VNI, VIQR, etc.) for this engine instance.
 *
 * @param eng Pointer to an initialized `SKeyEngine`. Must not be NULL.
 * @param im Input method ID (e.g. `UkTelex`, `UkVni`, `UkViqr`, `UkUsrIM`).
 */
void skey_engine_set_input_method(SKeyEngine *eng, int im);

/**
 * Sets the input method directly by raw integer ID for this engine instance.
 *
 * Unlike `skey_engine_set_input_method`, does not validate ID and resets engine state immediately.
 *
 * @param eng Pointer to an initialized `SKeyEngine`. Must not be NULL.
 * @param im Raw input method identifier integer.
 */
void skey_engine_set_input_method_raw(SKeyEngine *eng, int im);

/**
 * Sets the output character encoding (e.g. Unicode UTF-8, VNI, TCVN3).
 *
 * @param eng Pointer to an initialized `SKeyEngine`. Must not be NULL.
 * @param charset Character set ID (e.g. 12 for Unicode UTF-8).
 * @return 1 on success, 0 on failure or NULL engine pointer.
 */
int  skey_engine_set_charset(SKeyEngine *eng, int charset);

/**
 * Applies configuration options to this engine instance.
 *
 * @param eng Pointer to an initialized `SKeyEngine`. Must not be NULL.
 * @param pOpt Pointer to `SKeyOptions` struct to copy settings from. Safe to pass NULL (no-op).
 */
void skey_engine_set_options(SKeyEngine *eng, const SKeyOptions *pOpt);

/**
 * Retrieves current configuration options from this engine instance.
 *
 * @param eng Pointer to an initialized `SKeyEngine`. Must not be NULL.
 * @param pOpt Pointer to writable `SKeyOptions` struct to receive current settings. Safe to pass NULL (no-op).
 */
void skey_engine_get_options(SKeyEngine *eng, SKeyOptions *pOpt);

/**
 * Filters an incoming keystroke through this engine instance.
 *
 * @param eng Pointer to an initialized `SKeyEngine`. Must not be NULL.
 * @param ch Unicode character code / key code to process.
 * @return `SKeyEdit` describing backspaces needed, output length, and whether the key was handled.
 */
SKeyEdit skey_engine_filter(SKeyEngine *eng, unsigned int ch);

/**
 * Passes a raw character code directly into the buffer without transformation.
 *
 * @param eng Pointer to an initialized `SKeyEngine`. Must not be NULL.
 * @param ch Character code to insert.
 */
void     skey_engine_put_char(SKeyEngine *eng, unsigned int ch);

/**
 * Processes a backspace key press in this engine instance.
 *
 * @param eng Pointer to an initialized `SKeyEngine`. Must not be NULL.
 * @return `SKeyEdit` describing backspaces needed and replacement output bytes.
 */
SKeyEdit skey_engine_backspace(SKeyEngine *eng);

/**
 * Restores the raw keystrokes of the current word in this engine instance.
 *
 * @param eng Pointer to an initialized `SKeyEngine`. Must not be NULL.
 * @return `SKeyEdit` describing backspaces and raw keystroke output bytes.
 */
SKeyEdit skey_engine_restore(SKeyEngine *eng);

/**
 * Copies the latest transformed output bytes into `buf` up to `max` bytes.
 *
 * @param eng Pointer to an initialized `SKeyEngine`. Must not be NULL.
 * @param buf Destination buffer to copy output bytes into. Must not be NULL.
 * @param max Maximum number of bytes that can be written to `buf` (must be > 0).
 * @return Number of bytes actually copied into `buf`, or 0 on error.
 */
int skey_engine_output(SKeyEngine *eng, unsigned char *buf, int max);

/**
 * Loads a macro table from a file into this engine instance.
 *
 * @param eng Pointer to an initialized `SKeyEngine`. Must not be NULL.
 * @param fileName Null-terminated UTF-8 filesystem path to macro file.
 * @return 1 on success, 0 on failure or invalid arguments.
 */
int skey_engine_load_macro_table(SKeyEngine *eng, const char *fileName);

/**
 * Loads a user key mapping file into this engine instance.
 *
 * @param eng Pointer to an initialized `SKeyEngine`. Must not be NULL.
 * @param fileName Null-terminated UTF-8 filesystem path to key map file.
 * @return 1 on success, 0 on failure or invalid arguments.
 */
int skey_engine_load_user_key_map(SKeyEngine *eng, const char *fileName);

/**
 * Enables or disables swallowed English word restoration for this engine instance.
 *
 * @param eng Pointer to an initialized `SKeyEngine`. Must not be NULL.
 * @param on Non-zero (1) to enable, 0 to disable.
 */
void skey_engine_set_swallowed_key_restore(SKeyEngine *eng, int on);

/**
 * Returns the total count of swallowed English words recognized by the engine.
 *
 * @return Total word count as integer.
 */
int  skey_swallowed_word_count(void);

/**
 * Copies the swallowed English word at index `idx` into `buf` as a null-terminated string.
 *
 * @param idx Zero-based index of the word.
 * @param buf Output buffer for null-terminated C string. Must not be NULL.
 * @param max Buffer capacity in bytes (must be at least 2).
 * @return Length of string copied in bytes, or 0 on error.
 */
int  skey_swallowed_word(int idx, char *buf, int max);

/**
 * Enables or disables Quick Telex mode for this engine instance.
 *
 * @param eng Pointer to an initialized `SKeyEngine`. Must not be NULL.
 * @param on Non-zero (1) to enable, 0 to disable.
 */
void skey_engine_set_quick_telex(SKeyEngine *eng, int on);

/**
 * Enables or disables quick initial consonant shortcuts for this engine instance.
 *
 * @param eng Pointer to an initialized `SKeyEngine`. Must not be NULL.
 * @param on Non-zero (1) to enable, 0 to disable.
 */
void skey_engine_set_quick_start_consonant(SKeyEngine *eng, int on);

/**
 * Enables or disables quick final consonant shortcuts for this engine instance.
 *
 * @param eng Pointer to an initialized `SKeyEngine`. Must not be NULL.
 * @param on Non-zero (1) to enable, 0 to disable.
 */
void skey_engine_set_quick_end_consonant(SKeyEngine *eng, int on);

/**
 * Enables or disables automatic capitalization of the first character of a sentence.
 *
 * @param eng Pointer to an initialized `SKeyEngine`. Must not be NULL.
 * @param on Non-zero (1) to enable, 0 to disable.
 */
void skey_engine_set_upper_case_first_char(SKeyEngine *eng, int on);

/**
 * Enables or disables allowing non-standard consonants Z, F, W, J.
 *
 * @param eng Pointer to an initialized `SKeyEngine`. Must not be NULL.
 * @param on Non-zero (1) to enable, 0 to disable.
 */
void skey_engine_set_allow_consonant_zfwj(SKeyEngine *eng, int on);

/**
 * Evaluates an inline mathematical expression and formats the result.
 *
 * @param expr Null-terminated mathematical expression string (e.g. "12+34="). Must not be NULL.
 * @param out_buf Buffer to receive null-terminated formatted result string. Must not be NULL.
 * @param max_len Maximum length in bytes of `out_buf` (must be at least 2).
 * @return 1 on success, 0 on failure or invalid expression.
 */
int  skey_calc_evaluate(const char *expr, char *out_buf, int max_len);

#if defined(__cplusplus)
}
#endif

#endif /* __SKEY_RS_H */

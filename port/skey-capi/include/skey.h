/* C interface to the SKey Vietnamese typing engine.
 *
 * Provides both the context-based multi-instance API (SKeyEngine)
 * and legacy UniKey-compatible symbols.
 */
#ifndef __SKEY_RS_H
#define __SKEY_RS_H

#if defined(__cplusplus)
extern "C" {
#endif

typedef enum { UkTelex, UkVni, UkViqr, UkMsVi, UkUsrIM, UkSimpleTelex } UkInputMethod;
typedef enum { UkCharOutput, UkKeyOutput } UkOutputType;

typedef struct _SKeyOptions {
    int freeMarking;
    int modernStyle;
    int macroEnabled;
    int useUnicodeClipboard;
    int alwaysMacro;
    int strictSpellCheck;
    int useIME;
    int spellCheckEnabled;
    int autoNonVnRestore;
} SKeyOptions;

typedef SKeyOptions UnikeyOptions;

/* ============================== SKey Context API ============================== */

typedef struct SKeyEngine SKeyEngine;
typedef struct SKeyEngine UnikeyEngine;

typedef struct SKeyEdit {
    int backspaces;   /* backspaces to send before the new bytes  */
    int len;          /* output bytes available from _output      */
    int out_type;     /* 0 UkCharOutput, 1 UkKeyOutput           */
    int handled;      /* 0 means pass the original key through    */
} SKeyEdit;

typedef SKeyEdit UnikeyEdit;

SKeyEngine *skey_engine_create(void);
void skey_engine_free(SKeyEngine *eng);

void skey_engine_reset(SKeyEngine *eng);
void skey_engine_set_single_mode(SKeyEngine *eng);
void skey_engine_set_caps_state(SKeyEngine *eng, int shiftPressed, int capsLockOn);
void skey_engine_set_input_method(SKeyEngine *eng, int im);
void skey_engine_set_input_method_raw(SKeyEngine *eng, int im);
int  skey_engine_set_charset(SKeyEngine *eng, int charset);
void skey_engine_set_options(SKeyEngine *eng, const SKeyOptions *pOpt);
void skey_engine_get_options(SKeyEngine *eng, SKeyOptions *pOpt);

SKeyEdit skey_engine_filter(SKeyEngine *eng, unsigned int ch);
void     skey_engine_put_char(SKeyEngine *eng, unsigned int ch);
SKeyEdit skey_engine_backspace(SKeyEngine *eng);
SKeyEdit skey_engine_restore(SKeyEngine *eng);

int skey_engine_output(SKeyEngine *eng, unsigned char *buf, int max);

int skey_engine_load_macro_table(SKeyEngine *eng, const char *fileName);
int skey_engine_load_user_key_map(SKeyEngine *eng, const char *fileName);

void skey_engine_set_swallowed_key_restore(SKeyEngine *eng, int on);
int  skey_swallowed_word_count(void);
int  skey_swallowed_word(int idx, char *buf, int max);

void skey_engine_set_quick_telex(SKeyEngine *eng, int on);
void skey_engine_set_quick_start_consonant(SKeyEngine *eng, int on);
void skey_engine_set_quick_end_consonant(SKeyEngine *eng, int on);
void skey_engine_set_upper_case_first_char(SKeyEngine *eng, int on);
void skey_engine_set_allow_consonant_zfwj(SKeyEngine *eng, int on);

/* Unikey aliases for backward compatibility */
#define unikey_engine_create skey_engine_create
#define unikey_engine_free skey_engine_free
#define unikey_engine_reset skey_engine_reset
#define unikey_engine_set_single_mode skey_engine_set_single_mode
#define unikey_engine_set_caps_state skey_engine_set_caps_state
#define unikey_engine_set_input_method skey_engine_set_input_method
#define unikey_engine_set_input_method_raw skey_engine_set_input_method_raw
#define unikey_engine_set_charset skey_engine_set_charset
#define unikey_engine_set_options skey_engine_set_options
#define unikey_engine_get_options skey_engine_get_options
#define unikey_engine_filter skey_engine_filter
#define unikey_engine_put_char skey_engine_put_char
#define unikey_engine_backspace skey_engine_backspace
#define unikey_engine_restore skey_engine_restore
#define unikey_engine_output skey_engine_output
#define unikey_engine_load_macro_table skey_engine_load_macro_table
#define unikey_engine_load_user_key_map skey_engine_load_user_key_map
#define unikey_engine_set_swallowed_key_restore skey_engine_set_swallowed_key_restore
#define unikey_engine_set_quick_telex skey_engine_set_quick_telex
#define unikey_engine_set_quick_start_consonant skey_engine_set_quick_start_consonant
#define unikey_engine_set_quick_end_consonant skey_engine_set_quick_end_consonant
#define unikey_engine_set_upper_case_first_char skey_engine_set_upper_case_first_char
#define unikey_engine_set_allow_consonant_zfwj skey_engine_set_allow_consonant_zfwj

#if defined(__cplusplus)
}
#endif

#endif /* __SKEY_RS_H */

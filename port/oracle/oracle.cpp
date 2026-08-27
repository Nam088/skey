// Oracle harness: drives the original UniKey C++ engine and emits a
// deterministic per-keystroke trace. This is the behavioural contract
// that the Rust port must reproduce byte for byte.
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "unikey.h"
#include "vnconv.h"

// UnikeySetInputMethod only accepts Telex, VNI, VIQR and the user map,
// so MsVi and simple Telex are unreachable through the public API even
// though the engine implements them. Reach the processor directly so
// those two can be verified as well.
//
// The same source builds against the original C++ engine and against the
// Rust library through its C ABI, which is what makes the ABI itself
// testable: RUST_BACKEND selects the exported helpers over the C++
// internals.
#if defined(RUST_BACKEND)
extern "C" {
    void UnikeySetInputMethodRaw(int im);
    int UnikeyMacroCount();
    int UnikeyMacroGet(int idx, int which, unsigned int *buf, int max);
}
#else
#include "ukengine.h"
extern UkSharedMem *pShMem;
extern UkEngine MyKbEngine;
#endif

extern unsigned char UnikeyBuf[];
extern int UnikeyBackspaces;
extern int UnikeyBufChars;
extern UkOutputType UnikeyOutput;

static void emit(const char *tag)
{
    printf("%s b=%d n=%d t=%d o=", tag, UnikeyBackspaces, UnikeyBufChars,
           (int)UnikeyOutput);
    for (int i = 0; i < UnikeyBufChars; i++)
        printf("%02X", UnikeyBuf[i]);
    printf("\n");
}

int main(int argc, char **argv)
{
    // argv: im charset freeMarking modernStyle macroEnabled spellCheck autoRestore
    int im = 0, charset = CONV_CHARSET_XUTF8;
    int freeMarking = 1, modernStyle = 0, macroEnabled = 0;
    int spellCheck = 1, autoRestore = 0;
    if (argc > 1) im = atoi(argv[1]);
    if (argc > 2) charset = atoi(argv[2]);
    if (argc > 3) freeMarking = atoi(argv[3]);
    if (argc > 4) modernStyle = atoi(argv[4]);
    if (argc > 5) macroEnabled = atoi(argv[5]);
    if (argc > 6) spellCheck = atoi(argv[6]);
    if (argc > 7) autoRestore = atoi(argv[7]);

    UnikeySetup();
    if (im == UkMsVi || im == UkSimpleTelex) {
#if defined(RUST_BACKEND)
        UnikeySetInputMethodRaw(im);
#else
        pShMem->input.setIM((UkInputMethod)im);
        MyKbEngine.reset();
#endif
    } else {
        UnikeySetInputMethod((UkInputMethod)im);
    }
    UnikeySetOutputCharset(charset);

    UnikeyOptions opt;
    CreateDefaultUnikeyOptions(&opt);
    opt.freeMarking = freeMarking;
    opt.modernStyle = modernStyle;
    opt.macroEnabled = macroEnabled;
    opt.spellCheckEnabled = spellCheck;
    opt.autoNonVnRestore = autoRestore;
    UnikeySetOptions(&opt);
    UnikeySetCapsState(0, 0);

    // stdin protocol, one command per line:
    //   K <n>   feed key code n
    //   B       backspace
    //   R       restore key strokes
    //   Z       reset buffer
    //   S       set single mode
    //   C <s> <c>  set caps state (shift, capslock)
    //   ---     end of one sequence, reset engine
    char line[256];
    while (fgets(line, sizeof(line), stdin)) {
        if (line[0] == 'K') {
            unsigned int code = (unsigned int)strtoul(line + 1, NULL, 10);
            UnikeyFilter(code);
            emit("K");
        } else if (line[0] == 'B') {
            UnikeyBackspacePress();
            emit("B");
        } else if (line[0] == 'R') {
            UnikeyRestoreKeyStrokes();
            emit("R");
        } else if (line[0] == 'Z') {
            UnikeyResetBuf();
            printf("Z\n");
        } else if (line[0] == 'S') {
            UnikeySetSingleMode();
            printf("S\n");
        } else if (line[0] == 'C') {
            int s = 0, c = 0;
            sscanf(line + 1, "%d %d", &s, &c);
            UnikeySetCapsState(s, c);
            printf("C\n");
        } else if (line[0] == 'L') {
            char *p = line + 1;
            while (*p == ' ') p++;
            char *e = p; while (*e && *e != '\n' && *e != '\r') e++;
            *e = 0;
            printf("L %d\n", UnikeyLoadMacroTable(p));
        } else if (line[0] == 'U') {
            char *p = line + 1;
            while (*p == ' ') p++;
            char *e = p; while (*e && *e != '\n' && *e != '\r') e++;
            *e = 0;
            int ok = UnikeyLoadUserKeyMap(p);
            if (ok) UnikeySetInputMethod(UkUsrIM);
            printf("U %d\n", ok);
        } else if (line[0] == 'T') {
#if defined(RUST_BACKEND)
            int cnt = UnikeyMacroCount();
            printf("T %d\n", cnt);
            unsigned int tmp[2048];
            for (int k = 0; k < cnt; k++) {
                int n = UnikeyMacroGet(k, 0, tmp, 2048);
                printf("  key:");
                for (int j = 0; j < n; j++) printf(" %X", tmp[j]);
                n = UnikeyMacroGet(k, 1, tmp, 2048);
                printf("\n  txt:");
                for (int j = 0; j < n; j++) printf(" %X", tmp[j]);
                printf("\n");
            }
#else
            printf("T %d\n", pShMem->macStore.getCount());
            for (int k = 0; k < pShMem->macStore.getCount(); k++) {
                const StdVnChar *kk = pShMem->macStore.getKey(k);
                const StdVnChar *tt = pShMem->macStore.getText(k);
                printf("  key:");
                for (int j = 0; kk[j]; j++) printf(" %X", (unsigned)kk[j]);
                printf("\n  txt:");
                for (int j = 0; tt[j]; j++) printf(" %X", (unsigned)tt[j]);
                printf("\n");
            }
#endif
        } else if (line[0] == '-') {
            UnikeyResetBuf();
            printf("--\n");
        }
    }
    UnikeyCleanup();
    return 0;
}

/* Drives the context based C ABI with the same line protocol as
 * oracle.cpp, so the multi instance API is held to the same standard as
 * the legacy one. Two engines are created and only the first is driven,
 * which also checks that instances do not share state. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "unikey.h"

static void emit(const char *tag, UnikeyEdit e, UnikeyEngine *eng)
{
    /* Printed unconditionally: the legacy globals are assigned whatever
     * the engine put in them, including for a backspace that reports it
     * did not handle the key. */
    unsigned char buf[4096];
    int n = unikey_engine_output(eng, buf, sizeof buf);
    printf("%s b=%d n=%d t=%d o=", tag, e.backspaces, e.len, e.out_type);
    for (int i = 0; i < n; i++)
        printf("%02X", buf[i]);
    printf("\n");
}

int main(int argc, char **argv)
{
    int im = argc > 1 ? atoi(argv[1]) : 0;
    int charset = argc > 2 ? atoi(argv[2]) : 12;
    UnikeyOptions o;

    UnikeyEngine *eng = unikey_engine_create();
    /* A second instance kept busy on every key: if the two shared state
     * the traces below would drift from the reference. */
    UnikeyEngine *decoy = unikey_engine_create();

    if (im == UkMsVi || im == UkSimpleTelex)
        unikey_engine_set_input_method_raw(eng, im);
    else
        unikey_engine_set_input_method(eng, im);
    unikey_engine_set_charset(eng, charset);

    memset(&o, 0, sizeof o);
    o.freeMarking = argc > 3 ? atoi(argv[3]) : 1;
    o.modernStyle = argc > 4 ? atoi(argv[4]) : 0;
    o.macroEnabled = argc > 5 ? atoi(argv[5]) : 0;
    o.spellCheckEnabled = argc > 6 ? atoi(argv[6]) : 1;
    o.autoNonVnRestore = argc > 7 ? atoi(argv[7]) : 0;
    unikey_engine_set_options(eng, &o);
    unikey_engine_set_caps_state(eng, 0, 0);

    char line[512];
    while (fgets(line, sizeof line, stdin)) {
        if (line[0] == 'K') {
            unsigned int code = (unsigned int)strtoul(line + 1, NULL, 10);
            unikey_engine_filter(decoy, 'x');
            emit("K", unikey_engine_filter(eng, code), eng);
        } else if (line[0] == 'B') {
            emit("B", unikey_engine_backspace(eng), eng);
        } else if (line[0] == 'R') {
            emit("R", unikey_engine_restore(eng), eng);
        } else if (line[0] == 'Z') {
            unikey_engine_reset(eng);
            printf("Z\n");
        } else if (line[0] == 'S') {
            unikey_engine_set_single_mode(eng);
            printf("S\n");
        } else if (line[0] == 'C') {
            int s = 0, c = 0;
            sscanf(line + 1, "%d %d", &s, &c);
            unikey_engine_set_caps_state(eng, s, c);
            printf("C\n");
        } else if (line[0] == 'L') {
            char *p = line + 1, *e;
            while (*p == ' ') p++;
            e = p; while (*e && *e != '\n' && *e != '\r') e++;
            *e = 0;
            printf("L %d\n", unikey_engine_load_macro_table(eng, p));
        } else if (line[0] == 'U') {
            char *p = line + 1, *e;
            while (*p == ' ') p++;
            e = p; while (*e && *e != '\n' && *e != '\r') e++;
            *e = 0;
            int ok = unikey_engine_load_user_key_map(eng, p);
            if (ok) unikey_engine_set_input_method(eng, UkUsrIM);
            printf("U %d\n", ok);
        } else if (line[0] == '-') {
            unikey_engine_reset(eng);
            printf("--\n");
        }
    }
    unikey_engine_free(decoy);
    unikey_engine_free(eng);
    return 0;
}

/* SKey - Bộ gõ tiếng Việt macOS
 * Drives the SKey C ABI with the same line protocol as oracle.cpp.
 * Two engines are created and only the first is driven,
 * which also checks that instances do not share state. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "skey.h"

static void emit(const char *tag, SKeyEdit e, SKeyEngine *eng)
{
    unsigned char buf[4096];
    int n = skey_engine_output(eng, buf, sizeof buf);
    printf("%s b=%d n=%d t=%d o=", tag, e.backspaces, e.len, e.out_type);
    for (int i = 0; i < n; i++)
        printf("%02X", buf[i]);
    printf("\n");
}

int main(int argc, char **argv)
{
    int im = argc > 1 ? atoi(argv[1]) : 0;
    int charset = argc > 2 ? atoi(argv[2]) : 12;
    SKeyOptions o;

    SKeyEngine *eng = skey_engine_create();
    /* A second instance kept busy on every key: if the two shared state
     * the traces below would drift from the reference. */
    SKeyEngine *decoy = skey_engine_create();

    if (im == UkMsVi || im == UkSimpleTelex)
        skey_engine_set_input_method_raw(eng, im);
    else
        skey_engine_set_input_method(eng, im);
    skey_engine_set_charset(eng, charset);

    memset(&o, 0, sizeof o);
    o.freeMarking = argc > 3 ? atoi(argv[3]) : 1;
    o.modernStyle = argc > 4 ? atoi(argv[4]) : 0;
    o.macroEnabled = argc > 5 ? atoi(argv[5]) : 0;
    o.spellCheckEnabled = argc > 6 ? atoi(argv[6]) : 1;
    o.autoNonVnRestore = argc > 7 ? atoi(argv[7]) : 0;
    skey_engine_set_options(eng, &o);
    skey_engine_set_caps_state(eng, 0, 0);

    char line[512];
    while (fgets(line, sizeof line, stdin)) {
        if (line[0] == 'K') {
            unsigned int code = (unsigned int)strtoul(line + 1, NULL, 10);
            skey_engine_filter(decoy, 'x');
            emit("K", skey_engine_filter(eng, code), eng);
        } else if (line[0] == 'B') {
            emit("B", skey_engine_backspace(eng), eng);
        } else if (line[0] == 'R') {
            emit("R", skey_engine_restore(eng), eng);
        } else if (line[0] == 'Z') {
            skey_engine_reset(eng);
            printf("Z\n");
        } else if (line[0] == 'S') {
            skey_engine_set_single_mode(eng);
            printf("S\n");
        } else if (line[0] == 'C') {
            int s = 0, c = 0;
            sscanf(line + 1, "%d %d", &s, &c);
            skey_engine_set_caps_state(eng, s, c);
            printf("C\n");
        } else if (line[0] == 'L') {
            char *p = line + 1, *e;
            while (*p == ' ') p++;
            e = p; while (*e && *e != '\n' && *e != '\r') e++;
            *e = 0;
            printf("L %d\n", skey_engine_load_macro_table(eng, p));
        } else if (line[0] == 'U') {
            char *p = line + 1, *e;
            while (*p == ' ') p++;
            e = p; while (*e && *e != '\n' && *e != '\r') e++;
            *e = 0;
            int ok = skey_engine_load_user_key_map(eng, p);
            if (ok) skey_engine_set_input_method(eng, UkUsrIM);
            printf("U %d\n", ok);
        } else if (line[0] == '-') {
            skey_engine_reset(eng);
            printf("--\n");
        }
    }
    skey_engine_free(decoy);
    skey_engine_free(eng);
    return 0;
}

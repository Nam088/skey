/* In process benchmark of the original C++ engine.
 *
 * Same corpus file, same command mix and same round count as the Rust
 * bench, with the file read and parsed before the clock starts, so what
 * is timed is the engine and nothing else. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <vector>
#include <chrono>
#include "unikey.h"
#include "vnconv.h"

enum Kind { K, B, R, S, Z };
struct Cmd { Kind kind; unsigned int code; };

int main(int argc, char **argv)
{
    const char *path = argc > 1 ? argv[1] : "/tmp/bench_corpus.txt";
    int im = argc > 2 ? atoi(argv[2]) : 0;
    int charset = argc > 3 ? atoi(argv[3]) : 12;
    int rounds = argc > 4 ? atoi(argv[4]) : 20;
    const char *label = argc > 5 ? argv[5] : "cpp";

    FILE *f = fopen(path, "r");
    if (!f) { fprintf(stderr, "cannot open %s\n", path); return 1; }
    std::vector<Cmd> cmds;
    char line[256];
    while (fgets(line, sizeof line, f)) {
        switch (line[0]) {
        case 'K': cmds.push_back({K, (unsigned)strtoul(line + 1, NULL, 10)}); break;
        case 'B': cmds.push_back({B, 0}); break;
        case 'R': cmds.push_back({R, 0}); break;
        case 'S': cmds.push_back({S, 0}); break;
        case '-': cmds.push_back({Z, 0}); break;
        default: break;
        }
    }
    fclose(f);

    size_t keys = 0;
    for (size_t i = 0; i < cmds.size(); i++)
        if (cmds[i].kind == K) keys++;

    UnikeySetup();
    UnikeySetInputMethod((UkInputMethod)im);
    UnikeySetOutputCharset(charset);
    UnikeyOptions o;
    CreateDefaultUnikeyOptions(&o);
    UnikeySetOptions(&o);
    UnikeySetCapsState(0, 0);

    // warm up, exactly as the Rust bench does
    for (int w = 0; w < 2; w++)
        for (size_t i = 0; i < cmds.size(); i++) {
            switch (cmds[i].kind) {
            case K: UnikeyFilter(cmds[i].code); break;
            case B: UnikeyBackspacePress(); break;
            case R: UnikeyRestoreKeyStrokes(); break;
            case S: UnikeySetSingleMode(); break;
            case Z: UnikeyResetBuf(); break;
            }
        }

    auto t0 = std::chrono::steady_clock::now();
    for (int r = 0; r < rounds; r++)
        for (size_t i = 0; i < cmds.size(); i++) {
            switch (cmds[i].kind) {
            case K: UnikeyFilter(cmds[i].code); break;
            case B: UnikeyBackspacePress(); break;
            case R: UnikeyRestoreKeyStrokes(); break;
            case S: UnikeySetSingleMode(); break;
            case Z: UnikeyResetBuf(); break;
            }
        }
    auto dt = std::chrono::steady_clock::now() - t0;

    double ns = (double)std::chrono::duration_cast<std::chrono::nanoseconds>(dt).count();
    double total = (double)keys * rounds;
    printf("%-22s %6.1f ns/key   %5.1f M keys/s\n", label, ns / total, total / (ns / 1e9) / 1e6);
    return 0;
}

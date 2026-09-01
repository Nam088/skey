// Global initializer linked into every test executable. A failed assert()
// must print to stderr and abort; the default modal report dialog would
// block a headless CI session forever instead of failing the test.
#ifdef _WIN32

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include <crtdbg.h>
#include <stdlib.h>

namespace {

struct HeadlessAssertGuard {
    HeadlessAssertGuard() {
        ::SetErrorMode(SEM_FAILCRITICALERRORS | SEM_NOGPFAULTERRORBOX);
        _CrtSetReportMode(_CRT_WARN, _CRTDBG_MODE_FILE);
        _CrtSetReportFile(_CRT_WARN, _CRTDBG_FILE_STDERR);
        _CrtSetReportMode(_CRT_ERROR, _CRTDBG_MODE_FILE);
        _CrtSetReportFile(_CRT_ERROR, _CRTDBG_FILE_STDERR);
        _CrtSetReportMode(_CRT_ASSERT, _CRTDBG_MODE_FILE);
        _CrtSetReportFile(_CRT_ASSERT, _CRTDBG_FILE_STDERR);
        _set_abort_behavior(0, _WRITE_ABORT_MSG | _CALL_REPORTFAULT);
    }
};

const HeadlessAssertGuard headless_assert_guard;

} // namespace

#else // !_WIN32

// Non-Windows builds don't need the guard; keep the TU non-empty.
using HeadlessAssertGuardPlaceholder = int;

#endif // _WIN32

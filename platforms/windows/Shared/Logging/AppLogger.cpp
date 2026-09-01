#include "AppLogger.h"
#include "../Settings/SettingsPaths.h"

#include <chrono>
#include <iomanip>
#include <sstream>
#include <iostream>

#ifdef _WIN32
#include <dbghelp.h>
#pragma comment(lib, "dbghelp.lib")
#endif

namespace skey::windows {

namespace {

const char* level_to_string(LogLevel level) {
    switch (level) {
    case LogLevel::Debug: return "DEBUG";
    case LogLevel::Info:  return "INFO ";
    case LogLevel::Warn:  return "WARN ";
    case LogLevel::Error: return "ERROR";
    case LogLevel::Fatal: return "FATAL";
    default:              return "TRACE";
    }
}

#ifdef _WIN32
LONG WINAPI GlobalUnhandledExceptionFilter(EXCEPTION_POINTERS* ex) {
    static std::atomic<bool> s_crashed{false};
    if (s_crashed.exchange(true)) return EXCEPTION_CONTINUE_SEARCH;

    std::ostringstream ss;
    ss << "\n=======================================================\n";
    ss << "FATAL CRASH DETECTED\n";
    ss << "Exception Code: 0x" << std::hex << (ex ? ex->ExceptionRecord->ExceptionCode : 0) << "\n";
    if (ex && ex->ExceptionRecord) {
        ss << "Exception Address: 0x" << std::hex << reinterpret_cast<uintptr_t>(ex->ExceptionRecord->ExceptionAddress) << "\n";
        if (ex->ExceptionRecord->ExceptionCode == EXCEPTION_ACCESS_VIOLATION && ex->ExceptionRecord->NumberParameters >= 2) {
            ss << "Access Violation: " << (ex->ExceptionRecord->ExceptionInformation[0] == 0 ? "Read" : "Write")
               << " at address 0x" << std::hex << ex->ExceptionRecord->ExceptionInformation[1] << "\n";
        }
    }

    HMODULE hModule = nullptr;
    if (ex && ex->ExceptionRecord && GetModuleHandleExA(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                                                       reinterpret_cast<LPCSTR>(ex->ExceptionRecord->ExceptionAddress), &hModule)) {
        char modName[MAX_PATH] = {0};
        GetModuleFileNameA(hModule, modName, sizeof(modName));
        ss << "Faulting Module: " << modName << "\n";
        ss << "Module Base: 0x" << std::hex << reinterpret_cast<uintptr_t>(hModule) << "\n";
        ss << "Offset: 0x" << std::hex << (reinterpret_cast<uintptr_t>(ex->ExceptionRecord->ExceptionAddress) - reinterpret_cast<uintptr_t>(hModule)) << "\n";
    }
    ss << "=======================================================\n";

    const auto crash_msg = ss.str();
    SKEY_LOG_FATAL(crash_msg);

    // Also write directly to crash log file
    try {
        const auto crash_file = SettingsPaths::data_dir() / "skey-crash.log";
        std::ofstream out(crash_file, std::ios::app);
        out << crash_msg << std::endl;
        out.flush();
    } catch (...) {}

    return EXCEPTION_CONTINUE_SEARCH;
}

LONG WINAPI VectoredCrashHandler(PEXCEPTION_POINTERS ex) {
    if (ex && ex->ExceptionRecord) {
        const auto code = ex->ExceptionRecord->ExceptionCode;
        if (code == EXCEPTION_ACCESS_VIOLATION ||
            code == EXCEPTION_ILLEGAL_INSTRUCTION ||
            code == 0xc000027b) {
            GlobalUnhandledExceptionFilter(ex);
        }
    }
    return EXCEPTION_CONTINUE_SEARCH;
}

struct EarlyLoggerInit {
    EarlyLoggerInit() {
        SetUnhandledExceptionFilter(GlobalUnhandledExceptionFilter);
        AddVectoredExceptionHandler(1, VectoredCrashHandler);
        AppLogger::instance().initialize("skey-app");
        SKEY_LOG_INFO("Early CRT dynamic initializer initialized AppLogger & VectoredCrashHandler.");
    }
};

#pragma warning(disable: 4073)
#pragma init_seg(lib)
static EarlyLoggerInit g_earlyLoggerInit;
#endif

} // namespace

AppLogger& AppLogger::instance() {
    static AppLogger s_instance;
    return s_instance;
}

AppLogger::~AppLogger() {
    if (log_stream_.is_open()) {
        log_stream_.flush();
        log_stream_.close();
    }
}

void AppLogger::initialize(const std::string& app_name) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (initialized_) return;

    app_name_ = app_name;
    try {
        const auto dir = SettingsPaths::data_dir();
        std::error_code ec;
        std::filesystem::create_directories(dir, ec);

        log_file_path_ = dir / "skey.log";
        log_stream_.open(log_file_path_, std::ios::app);
        initialized_ = true;
    } catch (...) {}

    install_crash_handler();
}

void AppLogger::install_crash_handler() {
#ifdef _WIN32
    SetUnhandledExceptionFilter(GlobalUnhandledExceptionFilter);
#endif
}

void AppLogger::log(LogLevel level, const char* file, int line, const std::string& message) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (!initialized_) {
        try {
            const auto dir = SettingsPaths::data_dir();
            std::error_code ec;
            std::filesystem::create_directories(dir, ec);
            log_file_path_ = dir / "skey.log";
            log_stream_.open(log_file_path_, std::ios::app);
            initialized_ = true;
        } catch (...) {}
    }

    const auto now = std::chrono::system_clock::now();
    const auto time_t_now = std::chrono::system_clock::to_time_t(now);
    const auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(now.time_since_epoch()) % 1000;

    std::tm tm_now{};
#ifdef _WIN32
    localtime_s(&tm_now, &time_t_now);
#else
    localtime_r(&time_t_now, &tm_now);
#endif

    // Filename only
    std::string_view fsv(file ? file : "");
    const auto last_slash = fsv.find_last_of("\\/");
    if (last_slash != std::string_view::npos) {
        fsv = fsv.substr(last_slash + 1);
    }

    std::ostringstream ss;
    ss << std::put_time(&tm_now, "%Y-%m-%d %H:%M:%S")
       << '.' << std::setfill('0') << std::setw(3) << ms.count()
       << " [" << level_to_string(level) << "]"
       << " [" << app_name_ << "]"
       << " [" << fsv << ":" << line << "] "
       << message << "\n";

    const auto line_str = ss.str();
    if (log_stream_.is_open()) {
        log_stream_ << line_str;
        log_stream_.flush();
    }
#ifdef _WIN32
    OutputDebugStringA(line_str.c_str());
#endif
}

} // namespace skey::windows

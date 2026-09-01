#pragma once

#include <string>
#include <string_view>
#include <fstream>
#include <mutex>
#include <filesystem>

#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#endif

namespace skey::windows {

enum class LogLevel {
    Debug,
    Info,
    Warn,
    Error,
    Fatal
};

class AppLogger {
public:
    static AppLogger& instance();

    void initialize(const std::string& app_name);
    void log(LogLevel level, const char* file, int line, const std::string& message);
    std::filesystem::path log_path() const { return log_file_path_; }

    static void install_crash_handler();

private:
    AppLogger() = default;
    ~AppLogger();

    std::mutex mutex_;
    std::ofstream log_stream_;
    std::filesystem::path log_file_path_;
    std::string app_name_{"SKey"};
    bool initialized_{false};
};

} // namespace skey::windows

#define SKEY_LOG_DEBUG(msg) skey::windows::AppLogger::instance().log(skey::windows::LogLevel::Debug, __FILE__, __LINE__, (msg))
#define SKEY_LOG_INFO(msg)  skey::windows::AppLogger::instance().log(skey::windows::LogLevel::Info,  __FILE__, __LINE__, (msg))
#define SKEY_LOG_WARN(msg)  skey::windows::AppLogger::instance().log(skey::windows::LogLevel::Warn,  __FILE__, __LINE__, (msg))
#define SKEY_LOG_ERROR(msg) skey::windows::AppLogger::instance().log(skey::windows::LogLevel::Error, __FILE__, __LINE__, (msg))
#define SKEY_LOG_FATAL(msg) skey::windows::AppLogger::instance().log(skey::windows::LogLevel::Fatal, __FILE__, __LINE__, (msg))

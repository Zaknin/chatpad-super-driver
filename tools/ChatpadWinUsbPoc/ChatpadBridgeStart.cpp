#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <Windows.h>
#include <algorithm>
#include <cwchar>
#include <filesystem>
#include <iterator>
#include <string>

namespace {
constexpr wchar_t LauncherMutexName[] = L"Local\\ChatpadBridge.Launcher.v1";
constexpr wchar_t RunnerStopEventName[] = L"Local\\ChatpadBridge.Stop.v1";
constexpr wchar_t LauncherStopEventName[] = L"Local\\ChatpadBridge.LauncherStop.v1";

void LogFailure(const std::wstring& message) {
    wchar_t localAppData[32768]{};
    const DWORD length = GetEnvironmentVariableW(L"LOCALAPPDATA", localAppData, static_cast<DWORD>(std::size(localAppData)));
    if (length == 0 || length >= std::size(localAppData)) return;
    const auto directory = std::filesystem::path(localAppData) / L"ChatpadBridge" / L"logs";
    std::error_code error;
    std::filesystem::create_directories(directory, error);
    if (error) return;
    const auto path = directory / L"launcher.log";
    HANDLE file = CreateFileW(path.c_str(), FILE_APPEND_DATA, FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr, OPEN_ALWAYS,
        FILE_ATTRIBUTE_NORMAL, nullptr);
    if (file == INVALID_HANDLE_VALUE) return;
    SYSTEMTIME now{}; GetSystemTime(&now);
    wchar_t line[2048]{};
    const int count = swprintf_s(line, L"%04u-%02u-%02uT%02u:%02u:%02u.%03uZ %s\r\n",
        now.wYear, now.wMonth, now.wDay, now.wHour, now.wMinute, now.wSecond, now.wMilliseconds, message.c_str());
    if (count > 0) {
        DWORD written{};
        const auto bytes = static_cast<DWORD>(count * sizeof(wchar_t));
        (void)WriteFile(file, line, bytes, &written, nullptr);
    }
    CloseHandle(file);
}

bool ResolveProtectedInstall(std::filesystem::path& root, std::filesystem::path& runner) {
    wchar_t module[32768]{};
    const DWORD moduleLength = GetModuleFileNameW(nullptr, module, static_cast<DWORD>(std::size(module)));
    if (moduleLength == 0 || moduleLength >= std::size(module)) return false;
    root = std::filesystem::path(module).parent_path();
    wchar_t programFiles[32768]{};
    const DWORD rootLength = GetEnvironmentVariableW(L"ProgramFiles", programFiles, static_cast<DWORD>(std::size(programFiles)));
    if (rootLength == 0 || rootLength >= std::size(programFiles)) return false;
    const auto expectedRoot = std::filesystem::path(programFiles) / L"ChatpadBridge";
    if (CompareStringOrdinal(root.c_str(), static_cast<int>(root.native().size()), expectedRoot.c_str(), -1, TRUE) != CSTR_EQUAL)
        return false;
    runner = root / L"ChatpadBridge.exe";
    const DWORD attributes = GetFileAttributesW(runner.c_str());
    return attributes != INVALID_FILE_ATTRIBUTES && !(attributes & FILE_ATTRIBUTE_DIRECTORY) && !(attributes & FILE_ATTRIBUTE_REPARSE_POINT);
}

int Run() {
    HANDLE mutex = CreateMutexW(nullptr, TRUE, LauncherMutexName);
    if (!mutex) return 2;
    if (GetLastError() == ERROR_ALREADY_EXISTS) { CloseHandle(mutex); return 0; }
    HANDLE runnerStop = CreateEventW(nullptr, TRUE, FALSE, RunnerStopEventName);
    HANDLE launcherStop = CreateEventW(nullptr, TRUE, FALSE, LauncherStopEventName);
    if (!runnerStop || !launcherStop) {
        LogFailure(L"Cannot create per-user stop events; Win32=" + std::to_wstring(GetLastError()));
        if (runnerStop) CloseHandle(runnerStop);
        if (launcherStop) CloseHandle(launcherStop);
        CloseHandle(mutex); return 2;
    }
    std::filesystem::path root, runner;
    if (!ResolveProtectedInstall(root, runner)) {
        LogFailure(L"BLOCKED: launcher or runner is not in the protected Program Files\\ChatpadBridge installation.");
        CloseHandle(runnerStop); CloseHandle(launcherStop); CloseHandle(mutex); return 2;
    }

    unsigned backoffSeconds = 2;
    for (;;) {
        if (WaitForSingleObject(launcherStop, 0) == WAIT_OBJECT_0) {
            CloseHandle(runnerStop); CloseHandle(launcherStop); CloseHandle(mutex); return 0;
        }
        // The launcher owns this event's lifecycle and clears it before each
        // child starts. The runner must never reset it after process creation,
        // or a very fast stop request could be lost during startup.
        if (!ResetEvent(runnerStop)) {
            LogFailure(L"Cannot reset per-user runner stop event; Win32=" + std::to_wstring(GetLastError()));
            CloseHandle(runnerStop); CloseHandle(launcherStop); CloseHandle(mutex); return 2;
        }
        std::wstring command = L"\"" + runner.wstring() + L"\" run";
        STARTUPINFOW startup{}; startup.cb = sizeof(startup);
        PROCESS_INFORMATION process{};
        if (!CreateProcessW(runner.c_str(), command.data(), nullptr, nullptr, FALSE, CREATE_NO_WINDOW | CREATE_UNICODE_ENVIRONMENT,
            nullptr, root.c_str(), &startup, &process)) {
            LogFailure(L"Runner launch failed; Win32=" + std::to_wstring(GetLastError()));
        } else {
            CloseHandle(process.hThread);
            HANDLE waits[] = {process.hProcess, launcherStop};
            const DWORD wait = WaitForMultipleObjects(2, waits, FALSE, INFINITE);
            if (wait == WAIT_OBJECT_0 + 1) {
                (void)SetEvent(runnerStop);
                const DWORD graceful = WaitForSingleObject(process.hProcess, 15000);
                if (graceful != WAIT_OBJECT_0) {
                    LogFailure(L"Graceful runner stop exceeded 15 seconds; waiting for its cleanup to finish.");
                    (void)WaitForSingleObject(process.hProcess, INFINITE);
                }
                CloseHandle(process.hProcess);
                CloseHandle(runnerStop); CloseHandle(launcherStop); CloseHandle(mutex); return 0;
            }
            DWORD exitCode = 1;
            if (wait == WAIT_OBJECT_0) (void)GetExitCodeProcess(process.hProcess, &exitCode);
            CloseHandle(process.hProcess);
            if (wait == WAIT_OBJECT_0 && exitCode == 0) { CloseHandle(runnerStop); CloseHandle(launcherStop); CloseHandle(mutex); return 0; }
            LogFailure(L"Runner exited unexpectedly; exit=" + std::to_wstring(exitCode) + L"; restarting with bounded backoff.");
        }
        if (WaitForSingleObject(launcherStop, backoffSeconds * 1000) == WAIT_OBJECT_0) {
            CloseHandle(runnerStop); CloseHandle(launcherStop); CloseHandle(mutex); return 0;
        }
        backoffSeconds = (std::min)(backoffSeconds * 2, 30u);
    }
}
}

int WINAPI wWinMain(HINSTANCE, HINSTANCE, PWSTR, int) {
    try { return Run(); }
    catch (...) { LogFailure(L"Launcher failed with an unhandled native exception."); return 2; }
}

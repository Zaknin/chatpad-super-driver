#include "ChatpadControlCore.h"

#include "ProfileJson.h"

#include <Windows.h>

#include <cstdlib>
#include <cstring>
#include <fstream>
#include <iterator>
#include <sstream>

namespace {

bool IsSafeProfileName(const std::wstring& name)
{
    if (name.empty() || name.size() >= CHATPAD_CONFIGURATION_PROFILE_NAME_LENGTH || name == L"." || name == L"..")
        return false;
    for (wchar_t value : name) {
        if (!((value >= L'A' && value <= L'Z') || (value >= L'a' && value <= L'z') ||
              (value >= L'0' && value <= L'9') || value == L'-' || value == L'_' || value == L'.')) return false;
    }
    return true;
}

bool ReadProfile(const std::filesystem::path& path, ChatpadConfiguration& configuration, std::string& error)
{
    std::error_code ec;
    auto size = std::filesystem::file_size(path, ec);
    if (ec) { error = "unable to read profile size: " + ec.message(); return false; }
    if (size > 65536) { error = "profile exceeds 65536 bytes"; return false; }
    std::ifstream input(path, std::ios::binary);
    if (!input) { error = "unable to open profile"; return false; }
    std::string text(static_cast<size_t>(size), '\0');
    input.read(text.data(), static_cast<std::streamsize>(text.size()));
    if (!input && !text.empty()) { error = "unable to read complete profile"; return false; }
    return ParseChatpadProfileJson(text, configuration, error);
}

bool WriteAtomic(const std::filesystem::path& path, const std::string& text, std::string& error)
{
    std::error_code ec;
    auto parent = path.parent_path();
    if (!parent.empty()) std::filesystem::create_directories(parent, ec);
    if (ec) { error = "unable to create profile directory: " + ec.message(); return false; }
    std::filesystem::path temporary = path;
    temporary += L".tmp";
    {
        std::ofstream output(temporary, std::ios::binary | std::ios::trunc);
        if (!output) { error = "unable to create temporary profile"; return false; }
        output.write(text.data(), static_cast<std::streamsize>(text.size()));
        output.flush();
        if (!output) { error = "unable to write complete profile"; return false; }
    }
    if (!MoveFileExW(temporary.c_str(), path.c_str(), MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH)) {
        error = "unable to atomically replace profile (Win32 error " + std::to_string(GetLastError()) + ")";
        std::filesystem::remove(temporary, ec);
        return false;
    }
    return true;
}

std::filesystem::path StoredProfile(const std::filesystem::path& root, const std::wstring& name)
{
    return root / (name + L".json");
}

int RequireDevice(IChatpadDevice& device, std::ostream& errors)
{
    if (device.IsOpen()) return CHATPAD_CONTROL_EXIT_SUCCESS;
    errors << "Chatpad control interface is not available. The driver may be absent or no controller is connected.\n";
    return CHATPAD_CONTROL_EXIT_DEVICE_UNAVAILABLE;
}

void PrintUsage(std::ostream& output)
{
    output << "Usage:\n"
           << "  ChatpadControl.exe status\n"
           << "  ChatpadControl.exe config show|reset\n"
           << "  ChatpadControl.exe profile list\n"
           << "  ChatpadControl.exe profile apply <name>\n"
           << "  ChatpadControl.exe profile import <path>\n"
           << "  ChatpadControl.exe profile export <name> <path>\n"
           << "  ChatpadControl.exe diagnostics\n";
}

} // namespace

std::filesystem::path GetDefaultProfileRoot()
{
    wchar_t buffer[32768];
    DWORD length = GetEnvironmentVariableW(L"LOCALAPPDATA", buffer, static_cast<DWORD>(std::size(buffer)));
    if (length == 0 || length >= std::size(buffer)) return {};
    return std::filesystem::path(buffer) / L"ChatpadSuperDriver" / L"profiles";
}

int RunChatpadControlCommand(
    const std::vector<std::wstring>& arguments,
    IChatpadDevice& device,
    const std::filesystem::path& profileRoot,
    std::ostream& output,
    std::ostream& errors)
{
    std::string error;
    if (arguments.empty()) { PrintUsage(errors); return CHATPAD_CONTROL_EXIT_USAGE; }

    if (arguments.size() == 1 && arguments[0] == L"status") {
        int availability = RequireDevice(device, errors); if (availability != 0) return availability;
        ChatpadControlStatus status{};
        if (!device.GetStatus(status, error)) { errors << error << '\n'; return CHATPAD_CONTROL_EXIT_IO_ERROR; }
        output << "driver=" << status.DriverVersionMajor << '.' << status.DriverVersionMinor << '.'
               << status.DriverVersionPatch << '.' << status.DriverVersionBuild << '\n'
               << "interfaceVersion=" << status.InterfaceVersion << '\n'
               << "schemaVersion=" << status.ConfigurationSchemaVersion << '\n'
               << "configurationGeneration=" << status.ConfigurationGeneration << '\n'
               << "activeProfile=" << status.ActiveProfile << '\n'
               << "chatpadFeatureAvailable=" << (status.ChatpadFeatureAvailable ? "true" : "false") << '\n';
        return CHATPAD_CONTROL_EXIT_SUCCESS;
    }

    if (arguments.size() == 2 && arguments[0] == L"config" && arguments[1] == L"show") {
        int availability = RequireDevice(device, errors); if (availability != 0) return availability;
        ChatpadConfiguration configuration{};
        if (!device.GetConfiguration(configuration, error)) { errors << error << '\n'; return CHATPAD_CONTROL_EXIT_IO_ERROR; }
        output << SerializeChatpadProfileJson(configuration);
        return CHATPAD_CONTROL_EXIT_SUCCESS;
    }

    if (arguments.size() == 2 && arguments[0] == L"config" && arguments[1] == L"reset") {
        int availability = RequireDevice(device, errors); if (availability != 0) return availability;
        if (!device.ResetConfiguration(error)) { errors << error << '\n'; return CHATPAD_CONTROL_EXIT_DRIVER_REJECTED; }
        output << "Active configuration reset to built-in defaults.\n";
        return CHATPAD_CONTROL_EXIT_SUCCESS;
    }

    if (arguments.size() == 2 && arguments[0] == L"profile" && arguments[1] == L"list") {
        std::error_code ec;
        std::filesystem::create_directories(profileRoot, ec);
        if (ec) { errors << ec.message() << '\n'; return CHATPAD_CONTROL_EXIT_IO_ERROR; }
        for (const auto& entry : std::filesystem::directory_iterator(profileRoot, ec)) {
            if (entry.is_regular_file() && entry.path().extension() == L".json")
                output << entry.path().stem().string() << '\n';
        }
        if (ec) { errors << ec.message() << '\n'; return CHATPAD_CONTROL_EXIT_IO_ERROR; }
        return CHATPAD_CONTROL_EXIT_SUCCESS;
    }

    if (arguments.size() == 3 && arguments[0] == L"profile" && arguments[1] == L"import") {
        ChatpadConfiguration configuration{};
        if (!ReadProfile(arguments[2], configuration, error)) {
            errors << "Invalid profile: " << error << '\n'; return CHATPAD_CONTROL_EXIT_INVALID_PROFILE;
        }
        std::wstring name(configuration.ProfileName, configuration.ProfileName + strlen(configuration.ProfileName));
        if (!IsSafeProfileName(name)) { errors << "Invalid profile name.\n"; return CHATPAD_CONTROL_EXIT_INVALID_PROFILE; }
        if (!WriteAtomic(StoredProfile(profileRoot, name), SerializeChatpadProfileJson(configuration), error)) {
            errors << error << '\n'; return CHATPAD_CONTROL_EXIT_IO_ERROR;
        }
        output << "Imported profile " << configuration.ProfileName << ".\n";
        return CHATPAD_CONTROL_EXIT_SUCCESS;
    }

    if (arguments.size() == 3 && arguments[0] == L"profile" && arguments[1] == L"apply") {
        if (!IsSafeProfileName(arguments[2])) { errors << "Invalid profile name.\n"; return CHATPAD_CONTROL_EXIT_INVALID_PROFILE; }
        ChatpadConfiguration configuration{};
        if (!ReadProfile(StoredProfile(profileRoot, arguments[2]), configuration, error)) {
            errors << "Invalid profile: " << error << '\n'; return CHATPAD_CONTROL_EXIT_INVALID_PROFILE;
        }
        int availability = RequireDevice(device, errors); if (availability != 0) return availability;
        if (!device.SetConfiguration(configuration, error)) { errors << error << '\n'; return CHATPAD_CONTROL_EXIT_DRIVER_REJECTED; }
        output << "Applied profile " << configuration.ProfileName << ".\n";
        return CHATPAD_CONTROL_EXIT_SUCCESS;
    }

    if (arguments.size() == 4 && arguments[0] == L"profile" && arguments[1] == L"export") {
        if (!IsSafeProfileName(arguments[2])) { errors << "Invalid profile name.\n"; return CHATPAD_CONTROL_EXIT_INVALID_PROFILE; }
        ChatpadConfiguration configuration{};
        if (!ReadProfile(StoredProfile(profileRoot, arguments[2]), configuration, error)) {
            errors << "Invalid profile: " << error << '\n'; return CHATPAD_CONTROL_EXIT_INVALID_PROFILE;
        }
        if (!WriteAtomic(arguments[3], SerializeChatpadProfileJson(configuration), error)) {
            errors << error << '\n'; return CHATPAD_CONTROL_EXIT_IO_ERROR;
        }
        output << "Exported profile " << configuration.ProfileName << ".\n";
        return CHATPAD_CONTROL_EXIT_SUCCESS;
    }

    if (arguments.size() == 1 && arguments[0] == L"diagnostics") {
        int availability = RequireDevice(device, errors); if (availability != 0) return availability;
        ChatpadControlDiagnostics diagnostics{};
        if (!device.GetDiagnostics(diagnostics, error)) { errors << error << '\n'; return CHATPAD_CONTROL_EXIT_IO_ERROR; }
        output << "inputPackets=" << diagnostics.InputPacketCount << '\n'
               << "inputReports=" << diagnostics.InputReportCount << '\n'
               << "parseFailures=" << diagnostics.ParseFailureCount << '\n'
               << "configurationApplies=" << diagnostics.ConfigurationApplyCount << '\n'
               << "configurationRejects=" << diagnostics.ConfigurationRejectCount << '\n';
        return CHATPAD_CONTROL_EXIT_SUCCESS;
    }

    PrintUsage(errors);
    return CHATPAD_CONTROL_EXIT_USAGE;
}

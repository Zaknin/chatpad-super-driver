#include "ChatpadControlCore.h"
#include "ProfileJson.h"

#include <cstring>
#include <fstream>
#include <iostream>
#include <sstream>

extern "C" {
#include "ChatpadConfiguration.h"
}

namespace {

unsigned total = 0;
unsigned passed = 0;

void Check(const char* name, bool condition)
{
    ++total;
    if (condition) { ++passed; std::cout << "PASS: " << name << '\n'; }
    else std::cout << "FAIL: " << name << '\n';
}

class MockDevice final : public IChatpadDevice {
public:
    bool open = true;
    bool failSet = false;
    bool setCalled = false;
    bool resetCalled = false;
    ChatpadConfiguration configuration{};
    std::wstring path = L"mock://chatpad";

    MockDevice() { ChatpadBuildDefaultConfiguration(&configuration); }
    bool IsOpen() const override { return open; }
    const std::wstring& Path() const override { return path; }
    bool GetStatus(ChatpadControlStatus& status, std::string&) override {
        status = {}; status.DriverVersionMajor = 1; status.DriverVersionPatch = 14;
        status.InterfaceVersion = 1; status.ConfigurationSchemaVersion = 1;
        status.ConfigurationGeneration = 7; status.ChatpadFeatureAvailable = 1;
        std::memcpy(status.ActiveProfile, configuration.ProfileName, sizeof(status.ActiveProfile));
        return true;
    }
    bool GetConfiguration(ChatpadConfiguration& value, std::string&) override { value = configuration; return true; }
    bool SetConfiguration(const ChatpadConfiguration& value, std::string& error) override {
        setCalled = true;
        if (failSet) { error = "mock rejection"; return false; }
        configuration = value; return true;
    }
    bool ResetConfiguration(std::string&) override { resetCalled = true; ChatpadBuildDefaultConfiguration(&configuration); return true; }
    bool GetDiagnostics(ChatpadControlDiagnostics& value, std::string&) override {
        value = {}; value.InputPacketCount = 5; value.ConfigurationApplyCount = 2; return true;
    }
};

} // namespace

int main()
{
    ChatpadConfiguration original{};
    ChatpadConfiguration parsed{};
    ChatpadBuildDefaultConfiguration(&original);
    std::string json = SerializeChatpadProfileJson(original);
    std::string error;
    Check("default profile serializes", !json.empty() && json.size() < 65536);
    Check("default profile round trips", ParseChatpadProfileJson(json, parsed, error));
    Check("round trip is byte exact", std::memcmp(&original, &parsed, sizeof(original)) == 0);

    std::string duplicate = json;
    duplicate.insert(duplicate.find('{') + 1, "\n  \"schemaVersion\": 1,");
    Check("duplicate JSON property rejected", !ParseChatpadProfileJson(duplicate, parsed, error));
    std::string duplicateMapping = json;
    auto duplicateKey = duplicateMapping.find("    \"0x11\"");
    auto duplicateKeyEnd = duplicateMapping.find('\n', duplicateKey);
    duplicateMapping.insert(
        duplicateKey,
        duplicateMapping.substr(duplicateKey, duplicateKeyEnd - duplicateKey + 1));
    Check("duplicate mapping rejected", !ParseChatpadProfileJson(duplicateMapping, parsed, error));
    std::string unsupported = json;
    auto schema = unsupported.find("\"schemaVersion\": 1");
    unsupported.replace(schema, std::strlen("\"schemaVersion\": 1"), "\"schemaVersion\": 99");
    Check("unsupported schema rejected", !ParseChatpadProfileJson(unsupported, parsed, error));
    std::string partial = json;
    auto key = partial.find("    \"0x11\"");
    auto next = partial.find('\n', key);
    partial.erase(key, next - key + 1);
    Check("partial profile rejected", !ParseChatpadProfileJson(partial, parsed, error));
    Check("oversized input rejected", !ParseChatpadProfileJson(std::string(65537, ' '), parsed, error));
    std::string invalidAction = json;
    auto usage = invalidAction.find("\"usage\": 36");
    invalidAction.replace(usage, std::strlen("\"usage\": 36"), "\"usage\": 255");
    Check("out of range HID action rejected", !ParseChatpadProfileJson(invalidAction, parsed, error));

    auto root = std::filesystem::temp_directory_path() / L"ChatpadControlTests-task8k";
    std::error_code ec;
    std::filesystem::remove_all(root, ec);
    std::filesystem::create_directories(root, ec);
    {
        std::ofstream stored(root / L"built-in-qwerty.json", std::ios::binary);
        stored << json;
    }

    MockDevice device;
    std::ostringstream output;
    std::ostringstream errors;
    int result = RunChatpadControlCommand({ L"status" }, device, root, output, errors);
    Check("mock status succeeds", result == CHATPAD_CONTROL_EXIT_SUCCESS && output.str().find("driver=1.0.14.0") != std::string::npos);
    output.str(""); errors.str("");
    result = RunChatpadControlCommand({ L"profile", L"apply", L"built-in-qwerty" }, device, root, output, errors);
    Check("mock profile apply succeeds", result == CHATPAD_CONTROL_EXIT_SUCCESS && device.setCalled);
    device.failSet = true; device.setCalled = false; output.str(""); errors.str("");
    result = RunChatpadControlCommand({ L"profile", L"apply", L"built-in-qwerty" }, device, root, output, errors);
    Check("mock driver rejection has stable exit code", result == CHATPAD_CONTROL_EXIT_DRIVER_REJECTED && device.setCalled);
    device.failSet = false; output.str(""); errors.str("");
    result = RunChatpadControlCommand({ L"config", L"reset" }, device, root, output, errors);
    Check("mock reset succeeds", result == CHATPAD_CONTROL_EXIT_SUCCESS && device.resetCalled);
    output.str(""); errors.str("");
    result = RunChatpadControlCommand({ L"diagnostics" }, device, root, output, errors);
    Check("mock diagnostics succeeds", result == CHATPAD_CONTROL_EXIT_SUCCESS && output.str().find("inputPackets=5") != std::string::npos);
    device.open = false; output.str(""); errors.str("");
    result = RunChatpadControlCommand({ L"status" }, device, root, output, errors);
    Check("no connected device has stable exit code", result == CHATPAD_CONTROL_EXIT_DEVICE_UNAVAILABLE);

    std::filesystem::remove_all(root, ec);
    std::cout << "Total: " << total << '\n';
    std::cout << "Passed: " << passed << '\n';
    std::cout << "Failed: " << (total - passed) << '\n';
    return total == passed ? 0 : 1;
}

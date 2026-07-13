#include "ChatpadDeviceClient.h"

#include <SetupAPI.h>

#include <sstream>
#include <vector>

#pragma comment(lib, "Setupapi.lib")

namespace {

std::string Win32Error(const char* operation, DWORD error)
{
    std::ostringstream message;
    message << operation << " failed with Win32 error " << error;
    return message.str();
}

} // namespace

ChatpadDeviceClient::ChatpadDeviceClient()
{
    HDEVINFO devices = SetupDiGetClassDevsW(
        &CHATPAD_CONTROL_INTERFACE_GUID, nullptr, nullptr,
        DIGCF_PRESENT | DIGCF_DEVICEINTERFACE);
    if (devices == INVALID_HANDLE_VALUE) return;
    SP_DEVICE_INTERFACE_DATA interfaceData{};
    interfaceData.cbSize = sizeof(interfaceData);
    if (!SetupDiEnumDeviceInterfaces(
            devices, nullptr, &CHATPAD_CONTROL_INTERFACE_GUID, 0, &interfaceData)) {
        SetupDiDestroyDeviceInfoList(devices);
        return;
    }
    SP_DEVICE_INTERFACE_DATA secondInterface{};
    secondInterface.cbSize = sizeof(secondInterface);
    if (SetupDiEnumDeviceInterfaces(
            devices, nullptr, &CHATPAD_CONTROL_INTERFACE_GUID, 1, &secondInterface)) {
        discoveryError_ = "multiple active Chatpad control interfaces; selection is ambiguous";
        SetupDiDestroyDeviceInfoList(devices);
        return;
    }
    if (GetLastError() != ERROR_NO_MORE_ITEMS) {
        discoveryError_ = Win32Error("SetupDiEnumDeviceInterfaces", GetLastError());
        SetupDiDestroyDeviceInfoList(devices);
        return;
    }
    DWORD required = 0;
    (void)SetupDiGetDeviceInterfaceDetailW(
        devices, &interfaceData, nullptr, 0, &required, nullptr);
    if (required < sizeof(SP_DEVICE_INTERFACE_DETAIL_DATA_W) || required > 32768) {
        SetupDiDestroyDeviceInfoList(devices);
        return;
    }
    std::vector<unsigned char> storage(required);
    auto* detail = reinterpret_cast<SP_DEVICE_INTERFACE_DETAIL_DATA_W*>(storage.data());
    detail->cbSize = sizeof(*detail);
    if (SetupDiGetDeviceInterfaceDetailW(
            devices, &interfaceData, detail, required, nullptr, nullptr)) {
        path_ = detail->DevicePath;
    }
    SetupDiDestroyDeviceInfoList(devices);
    if (path_.empty()) return;
    handle_ = CreateFileW(
        path_.c_str(), GENERIC_READ | GENERIC_WRITE,
        FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr, OPEN_EXISTING, 0, nullptr);
}

ChatpadDeviceClient::~ChatpadDeviceClient()
{
    if (handle_ != INVALID_HANDLE_VALUE) CloseHandle(handle_);
}

bool ChatpadDeviceClient::IsOpen() const { return handle_ != INVALID_HANDLE_VALUE; }
const std::wstring& ChatpadDeviceClient::Path() const { return path_; }

bool ChatpadDeviceClient::Invoke(
    ULONG code,
    void* input,
    DWORD inputSize,
    void* output,
    DWORD outputSize,
    std::string& error)
{
    if (!IsOpen()) {
        error = discoveryError_.empty() ? "no active Chatpad control interface" : discoveryError_;
        return false;
    }
    DWORD returned = 0;
    if (!DeviceIoControl(handle_, code, input, inputSize, output, outputSize, &returned, nullptr)) {
        error = Win32Error("DeviceIoControl", GetLastError());
        return false;
    }
    if (returned != outputSize) {
        error = "driver returned an unexpected response size";
        return false;
    }
    error.clear();
    return true;
}

bool ChatpadDeviceClient::GetStatus(ChatpadControlStatus& status, std::string& error)
{
    if (!Invoke(IOCTL_CHATPAD_GET_STATUS, nullptr, 0, &status, sizeof(status), error)) return false;
    if (status.StructureSize != sizeof(status) ||
        status.InterfaceVersion != CHATPAD_CONTROL_INTERFACE_VERSION) {
        error = "driver control-interface version is incompatible";
        return false;
    }
    return true;
}

bool ChatpadDeviceClient::GetConfiguration(ChatpadConfiguration& configuration, std::string& error)
{
    if (!Invoke(IOCTL_CHATPAD_GET_CONFIGURATION, nullptr, 0, &configuration, sizeof(configuration), error)) return false;
    if (ChatpadValidateConfiguration(&configuration) != CHATPAD_CONFIGURATION_VALID) {
        error = "driver returned an invalid configuration";
        return false;
    }
    return true;
}

bool ChatpadDeviceClient::SetConfiguration(const ChatpadConfiguration& configuration, std::string& error)
{
    return Invoke(IOCTL_CHATPAD_SET_CONFIGURATION,
        const_cast<ChatpadConfiguration*>(&configuration), sizeof(configuration), nullptr, 0, error);
}

bool ChatpadDeviceClient::ResetConfiguration(std::string& error)
{
    return Invoke(IOCTL_CHATPAD_RESET_CONFIGURATION, nullptr, 0, nullptr, 0, error);
}

bool ChatpadDeviceClient::GetDiagnostics(ChatpadControlDiagnostics& diagnostics, std::string& error)
{
    if (!Invoke(IOCTL_CHATPAD_GET_DIAGNOSTICS, nullptr, 0, &diagnostics, sizeof(diagnostics), error)) return false;
    if (diagnostics.Status.StructureSize != sizeof(diagnostics.Status) ||
        diagnostics.Status.InterfaceVersion != CHATPAD_CONTROL_INTERFACE_VERSION) {
        error = "driver diagnostics-interface version is incompatible";
        return false;
    }
    return true;
}

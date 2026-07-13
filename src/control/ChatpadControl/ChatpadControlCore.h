#pragma once

#include <filesystem>
#include <ostream>
#include <string>
#include <vector>

#include "ChatpadControlInterface.h"

class IChatpadDevice {
public:
    virtual ~IChatpadDevice() = default;
    virtual bool IsOpen() const = 0;
    virtual const std::wstring& Path() const = 0;
    virtual bool GetStatus(ChatpadControlStatus& status, std::string& error) = 0;
    virtual bool GetConfiguration(ChatpadConfiguration& configuration, std::string& error) = 0;
    virtual bool SetConfiguration(const ChatpadConfiguration& configuration, std::string& error) = 0;
    virtual bool ResetConfiguration(std::string& error) = 0;
    virtual bool GetDiagnostics(ChatpadControlDiagnostics& diagnostics, std::string& error) = 0;
};

enum ChatpadControlExitCode {
    CHATPAD_CONTROL_EXIT_SUCCESS = 0,
    CHATPAD_CONTROL_EXIT_USAGE = 1,
    CHATPAD_CONTROL_EXIT_DEVICE_UNAVAILABLE = 2,
    CHATPAD_CONTROL_EXIT_INVALID_PROFILE = 3,
    CHATPAD_CONTROL_EXIT_IO_ERROR = 4,
    CHATPAD_CONTROL_EXIT_DRIVER_REJECTED = 5
};

int RunChatpadControlCommand(
    const std::vector<std::wstring>& arguments,
    IChatpadDevice& device,
    const std::filesystem::path& profileRoot,
    std::ostream& output,
    std::ostream& errors);

std::filesystem::path GetDefaultProfileRoot();

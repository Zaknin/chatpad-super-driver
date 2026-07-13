#pragma once

#include <Windows.h>

#include "ChatpadControlCore.h"

class ChatpadDeviceClient final : public IChatpadDevice {
public:
    ChatpadDeviceClient();
    ~ChatpadDeviceClient() override;
    ChatpadDeviceClient(const ChatpadDeviceClient&) = delete;
    ChatpadDeviceClient& operator=(const ChatpadDeviceClient&) = delete;

    bool IsOpen() const override;
    const std::wstring& Path() const override;
    bool GetStatus(ChatpadControlStatus& status, std::string& error) override;
    bool GetConfiguration(ChatpadConfiguration& configuration, std::string& error) override;
    bool SetConfiguration(const ChatpadConfiguration& configuration, std::string& error) override;
    bool ResetConfiguration(std::string& error) override;
    bool GetDiagnostics(ChatpadControlDiagnostics& diagnostics, std::string& error) override;

private:
    bool Invoke(ULONG code, void* input, DWORD inputSize, void* output, DWORD outputSize, std::string& error);
    HANDLE handle_ = INVALID_HANDLE_VALUE;
    std::wstring path_;
    std::string discoveryError_;
};

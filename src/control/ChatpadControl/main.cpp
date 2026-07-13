#include "ChatpadControlCore.h"
#include "ChatpadDeviceClient.h"

#include <iostream>

int wmain(int argc, wchar_t** argv)
{
    std::vector<std::wstring> arguments;
    for (int index = 1; index < argc; ++index) arguments.emplace_back(argv[index]);
    std::filesystem::path profileRoot = GetDefaultProfileRoot();
    if (profileRoot.empty()) {
        std::cerr << "LOCALAPPDATA is unavailable; profile storage cannot be resolved.\n";
        return CHATPAD_CONTROL_EXIT_IO_ERROR;
    }
    ChatpadDeviceClient device;
    return RunChatpadControlCommand(arguments, device, profileRoot, std::cout, std::cerr);
}

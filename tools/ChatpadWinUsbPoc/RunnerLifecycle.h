#pragma once
#include <cstdint>
namespace chatpad {
enum class RunnerState : uint8_t {
    WaitingForDevice, Opening, ActivatingChatpad, Running, DeviceLost, Reconnecting, Stopping
};
class RunnerLifecycle final {
public:
    RunnerState State() const { return state_; }
    uint32_t ReconnectCount() const { return reconnectCount_; }
    bool DeviceFound();
    bool Opened();
    bool Activated();
    bool DeviceLost();
    bool BeginReconnect();
    bool Retry();
    void Stop();
private:
    RunnerState state_{RunnerState::WaitingForDevice};
    uint32_t reconnectCount_{};
};
}

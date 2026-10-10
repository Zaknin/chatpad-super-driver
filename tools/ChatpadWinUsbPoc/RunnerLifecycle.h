#pragma once
#include "BridgeCore.h"
#include <cstdint>
namespace chatpad {
bool ShouldSendStartupZeroRumbleRecovery(bool uncleanPreviousSession);
enum class SessionCleanupDisposition : uint8_t { Complete, DeviceRemoved, ReconnectAfterTransportTimeout, Failed };
SessionCleanupDisposition ClassifySessionCleanup(
    bool keysReleased,
    bool virtualNeutral,
    bool virtualReleased,
    const TransferResult& zeroRumbleStop,
    bool physicalDeviceRemovalObserved=false,
    bool physicalTransportTimeoutObserved=false);
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
    bool BackendFailed();
    bool DeviceLost();
    bool BeginReconnect();
    bool Retry();
    void Stop();
private:
    RunnerState state_{RunnerState::WaitingForDevice};
    uint32_t reconnectCount_{};
};
}

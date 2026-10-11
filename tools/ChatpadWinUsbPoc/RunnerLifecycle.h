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
enum class PhysicalRecoveryAction : uint8_t { None, RestartExactTarget, WaitForRecovery };
PhysicalRecoveryAction PlanPhysicalRecovery(
    bool physicalTransportTimeoutObserved,
    bool physicalDeviceRemovalObserved,
    bool cleanupFailure,
    bool backendFailure,
    bool userStop,
    bool restartAlreadyAttempted);
bool IsPhysicalReadinessTimeoutCandidate(uint32_t timedOutReadCount, TransferStatus lastReadStatus, bool userStop);
class RecoveryEpochGate final {
public:
    bool ObserveEpoch(uint64_t epoch);
    uint64_t CurrentEpoch() const { return currentEpoch_; }
    bool RecoveryAttempted() const { return recoveryAttempted_; }
    void MarkRecoveryAttempted() { recoveryAttempted_ = true; }
private:
    uint64_t currentEpoch_{};
    bool initialized_{}, recoveryAttempted_{};
};
class PhysicalReadinessTracker final {
public:
    void Record(TransferStatus status);
    uint32_t TimeoutCount() const;
    TransferStatus LastStatus() const;
    bool RecoveryCandidate(bool userStop) const;
private:
    uint32_t timeoutCount_{};
    TransferStatus lastStatus_{TransferStatus::Error};
};
enum class RunnerState : uint8_t {
    WaitingForDevice, WaitingForRecovery, Opening, ActivatingChatpad, Running, DeviceLost, Reconnecting, Stopping
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
    bool WaitForRecovery();
    bool ResumeRecovery();
    void Stop();
private:
    RunnerState state_{RunnerState::WaitingForDevice};
    uint32_t reconnectCount_{};
};
}

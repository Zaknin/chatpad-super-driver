#include "RunnerLifecycle.h"
namespace chatpad {
bool ShouldSendStartupZeroRumbleRecovery(bool uncleanPreviousSession) {
    return uncleanPreviousSession;
}
SessionCleanupDisposition ClassifySessionCleanup(
    bool keysReleased,
    bool virtualNeutral,
    bool virtualReleased,
    const TransferResult& zeroRumbleStop,
    bool physicalDeviceRemovalObserved,
    bool physicalTransportTimeoutObserved) {
    if(!keysReleased||!virtualNeutral||!virtualReleased)return SessionCleanupDisposition::Failed;
    if(zeroRumbleStop.status==TransferStatus::Ok&&zeroRumbleStop.transferred==8)
        return SessionCleanupDisposition::Complete;
    if(physicalDeviceRemovalObserved||zeroRumbleStop.status==TransferStatus::DeviceNotPresent)
        return SessionCleanupDisposition::DeviceRemoved;
    if(physicalTransportTimeoutObserved&&zeroRumbleStop.status==TransferStatus::Timeout)
        return SessionCleanupDisposition::ReconnectAfterTransportTimeout;
    return SessionCleanupDisposition::Failed;
}
PhysicalRecoveryAction PlanPhysicalRecovery(
    bool physicalTransportTimeoutObserved,
    bool physicalDeviceRemovalObserved,
    bool cleanupFailure,
    bool backendFailure,
    bool userStop,
    bool restartAlreadyAttempted) {
    if(!physicalTransportTimeoutObserved||physicalDeviceRemovalObserved||cleanupFailure||backendFailure||userStop)
        return PhysicalRecoveryAction::None;
    if(restartAlreadyAttempted)return PhysicalRecoveryAction::WaitForRecovery;
    return PhysicalRecoveryAction::RestartExactTarget;
}
bool RecoveryEpochGate::ObserveEpoch(uint64_t epoch) {
    if (!initialized_) {
        initialized_ = true;
        currentEpoch_ = epoch;
        recoveryAttempted_ = false;
        // The broker retains its resume epoch even when no client is connected.
        // A runner launched after wake must therefore treat a nonzero initial
        // value as a new recovery trigger rather than as an already-seen baseline.
        return epoch != 0;
    }
    if (epoch <= currentEpoch_) return false;
    currentEpoch_ = epoch;
    recoveryAttempted_ = false;
    return true;
}
bool IsPhysicalReadinessTimeoutCandidate(uint32_t timedOutReadCount,TransferStatus lastReadStatus,bool userStop) {
    return !userStop&&timedOutReadCount>0&&lastReadStatus==TransferStatus::Timeout;
}
void PhysicalReadinessTracker::Record(TransferStatus status) {
    lastStatus_=status;
    if(status==TransferStatus::Timeout)++timeoutCount_;
}
uint32_t PhysicalReadinessTracker::TimeoutCount() const { return timeoutCount_; }
TransferStatus PhysicalReadinessTracker::LastStatus() const { return lastStatus_; }
bool PhysicalReadinessTracker::RecoveryCandidate(bool userStop) const {
    return IsPhysicalReadinessTimeoutCandidate(timeoutCount_,lastStatus_,userStop);
}
bool RunnerLifecycle::DeviceFound() {
    if(state_!=RunnerState::WaitingForDevice)return false;
    state_=RunnerState::Opening;return true;
}
bool RunnerLifecycle::Opened() {
    if(state_!=RunnerState::Opening)return false;
    state_=RunnerState::ActivatingChatpad;return true;
}
bool RunnerLifecycle::Activated() {
    if(state_!=RunnerState::ActivatingChatpad)return false;
    state_=RunnerState::Running;return true;
}
bool RunnerLifecycle::BackendFailed() {
    if(state_!=RunnerState::ActivatingChatpad&&state_!=RunnerState::Running)return false;
    state_=RunnerState::Stopping;return true;
}
bool RunnerLifecycle::DeviceLost() {
    if(state_!=RunnerState::Running&&state_!=RunnerState::ActivatingChatpad&&state_!=RunnerState::Opening)return false;
    state_=RunnerState::DeviceLost;++reconnectCount_;return true;
}
bool RunnerLifecycle::BeginReconnect() {
    if(state_!=RunnerState::DeviceLost)return false;
    state_=RunnerState::Reconnecting;return true;
}
bool RunnerLifecycle::Retry() {
    if(state_!=RunnerState::Reconnecting)return false;
    state_=RunnerState::WaitingForDevice;return true;
}
bool RunnerLifecycle::WaitForRecovery() {
    if (state_ == RunnerState::Stopping) return false;
    state_ = RunnerState::WaitingForRecovery;
    return true;
}
bool RunnerLifecycle::ResumeRecovery() {
    if (state_ != RunnerState::WaitingForRecovery) return false;
    state_ = RunnerState::WaitingForDevice;
    return true;
}
void RunnerLifecycle::Stop(){state_=RunnerState::Stopping;}
}

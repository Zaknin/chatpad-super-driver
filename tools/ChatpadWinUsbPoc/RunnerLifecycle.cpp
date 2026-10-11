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
    if(restartAlreadyAttempted)return PhysicalRecoveryAction::StopAfterPriorAttempt;
    return PhysicalRecoveryAction::RestartExactTarget;
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
void RunnerLifecycle::Stop(){state_=RunnerState::Stopping;}
}

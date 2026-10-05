#include "RunnerLifecycle.h"
namespace chatpad {
bool ShouldSendStartupZeroRumbleRecovery(bool uncleanPreviousSession) {
    return uncleanPreviousSession;
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

#include "RunnerLifecycle.h"
#include <iostream>
using namespace chatpad;
unsigned checks{}, failed{};
void Check(bool value,const char* name){++checks;if(!value){++failed;std::cerr<<"FAIL: "<<name<<'\n';}}
int main(){
    Check(!ShouldSendStartupZeroRumbleRecovery(false),"clean prior shutdown skips redundant startup rumble write");
    Check(ShouldSendStartupZeroRumbleRecovery(true),"unclean prior shutdown requests startup rumble recovery");
    const TransferResult rumbleStopped{TransferStatus::Ok,0,8};
    const TransferResult deviceRemoved{TransferStatus::DeviceNotPresent,433,0};
    const TransferResult rumbleTimedOut{TransferStatus::Timeout,1460,0};
    const TransferResult shortRumbleWrite{TransferStatus::Ok,0,7};
    const TransferResult badCommand{TransferStatus::Error,22,0};
    Check(ClassifySessionCleanup(true,true,true,rumbleStopped)==SessionCleanupDisposition::Complete,
        "successful motor stop completes session cleanup");
    Check(ClassifySessionCleanup(true,true,true,deviceRemoved)==SessionCleanupDisposition::DeviceRemoved,
        "device removal during zero-rumble cleanup defers recovery to reconnect");
    Check(ClassifySessionCleanup(false,true,true,deviceRemoved)==SessionCleanupDisposition::Failed,
        "device removal does not mask failed key release");
    Check(ClassifySessionCleanup(true,false,true,deviceRemoved)==SessionCleanupDisposition::Failed,
        "device removal does not mask failed virtual neutralization");
    Check(ClassifySessionCleanup(true,true,false,deviceRemoved)==SessionCleanupDisposition::Failed,
        "device removal does not mask failed virtual release");
    Check(ClassifySessionCleanup(true,true,true,rumbleTimedOut)==SessionCleanupDisposition::Failed,
        "zero-rumble timeout remains a fatal cleanup failure");
    Check(ClassifySessionCleanup(true,true,true,rumbleTimedOut,false,true)==SessionCleanupDisposition::ReconnectAfterTransportTimeout,
        "correlated transport and zero-rumble timeouts reconnect after strict cleanup");
    Check(ClassifySessionCleanup(true,true,true,rumbleTimedOut,false,false)==SessionCleanupDisposition::Failed,
        "zero-rumble timeout without an observed transport timeout remains fatal");
    Check(ClassifySessionCleanup(true,true,true,badCommand,false,true)==SessionCleanupDisposition::Failed,
        "generic zero-rumble failure remains fatal despite an observed transport timeout");
    Check(ClassifySessionCleanup(false,true,true,rumbleTimedOut,false,true)==SessionCleanupDisposition::Failed,
        "transport timeout does not mask failed key release");
    Check(ClassifySessionCleanup(true,false,true,rumbleTimedOut,false,true)==SessionCleanupDisposition::Failed,
        "transport timeout does not mask failed virtual neutralization");
    Check(ClassifySessionCleanup(true,true,false,rumbleTimedOut,false,true)==SessionCleanupDisposition::Failed,
        "transport timeout does not mask failed virtual release");
    Check(ClassifySessionCleanup(true,true,true,shortRumbleWrite)==SessionCleanupDisposition::Failed,
        "short zero-rumble write remains a fatal cleanup failure");
    Check(ClassifySessionCleanup(true,true,true,badCommand,true)==SessionCleanupDisposition::DeviceRemoved,
        "confirmed device removal defers a secondary bad-command rumble-stop error");
    Check(ClassifySessionCleanup(true,true,true,badCommand,false)==SessionCleanupDisposition::Failed,
        "bad-command rumble-stop error remains fatal without confirmed device removal");
    Check(PlanPhysicalRecovery(true,false,false,false,false,false)==PhysicalRecoveryAction::RestartExactTarget,
        "persistent physical transport timeout requests one fixed-target recovery");
    Check(PlanPhysicalRecovery(false,false,false,false,false,false)==PhysicalRecoveryAction::None,
        "ordinary interrupt read timeouts alone do not request PnP recovery");
    Check(PlanPhysicalRecovery(true,true,false,false,false,false)==PhysicalRecoveryAction::None,
        "confirmed device removal waits for replug instead of PnP restarting");
    Check(PlanPhysicalRecovery(true,false,true,false,false,false)==PhysicalRecoveryAction::None,
        "failed cleanup prevents physical PnP recovery");
    Check(PlanPhysicalRecovery(true,false,false,true,false,false)==PhysicalRecoveryAction::None,
        "virtual backend failure does not trigger physical PnP recovery");
    Check(PlanPhysicalRecovery(true,false,false,false,true,false)==PhysicalRecoveryAction::None,
        "user stop does not trigger physical PnP recovery");
    Check(PlanPhysicalRecovery(true,false,false,false,false,true)==PhysicalRecoveryAction::StopAfterPriorAttempt,
        "one failed recovery attempt opens a circuit breaker for the current outage");
    Check(IsPhysicalReadinessTimeoutCandidate(10,TransferStatus::Timeout,false),
        "bounded controller readiness timeouts qualify for exact-target recovery");
    Check(!IsPhysicalReadinessTimeoutCandidate(0,TransferStatus::Timeout,false),
        "status-only readiness deadline does not trigger physical restart");
    Check(!IsPhysicalReadinessTimeoutCandidate(10,TransferStatus::Timeout,true),
        "user stop during readiness never triggers physical restart");
    Check(!IsPhysicalReadinessTimeoutCandidate(10,TransferStatus::DeviceNotPresent,false),
        "confirmed physical removal waits for replug instead of restart");
    PhysicalReadinessTracker readinessHistory;
    readinessHistory.Record(TransferStatus::Timeout);
    Check(readinessHistory.RecoveryCandidate(false),
        "last completed WinUSB read timeout qualifies readiness recovery");
    readinessHistory.Record(TransferStatus::Ok);
    Check(!readinessHistory.RecoveryCandidate(false),
        "successful status-packet read after timeout blocks readiness recovery");
    Check(readinessHistory.TimeoutCount()==1&&readinessHistory.LastStatus()==TransferStatus::Ok,
        "readiness tracker retains timeout count and most recent completion separately");
    RunnerLifecycle lifecycle;
    Check(lifecycle.State()==RunnerState::WaitingForDevice,"starts waiting for device");
    Check(lifecycle.DeviceFound()&&lifecycle.State()==RunnerState::Opening,"unplugged startup can discover device later");
    Check(lifecycle.Opened()&&lifecycle.State()==RunnerState::ActivatingChatpad,"open advances to activation");
    Check(lifecycle.Activated()&&lifecycle.State()==RunnerState::Running,"activation advances to running");
    Check(lifecycle.BackendFailed()&&lifecycle.State()==RunnerState::Stopping&&lifecycle.ReconnectCount()==0,
        "virtual backend creation failure stops without counting physical loss");
    Check(!lifecycle.DeviceLost()&&!lifecycle.DeviceFound(),"backend failure is terminal for this runner launch");
    RunnerLifecycle normal;
    Check(normal.DeviceFound()&&normal.Opened()&&normal.Activated(),"physical session reaches running before backend failure test");
    Check(normal.DeviceLost()&&normal.State()==RunnerState::DeviceLost,"running physical device loss is explicit");
    Check(!normal.DeviceLost()&&normal.ReconnectCount()==1,"duplicate loss does not double count");
    Check(normal.BeginReconnect()&&normal.State()==RunnerState::Reconnecting,"loss begins reconnect wait");
    Check(normal.Retry()&&normal.State()==RunnerState::WaitingForDevice,"retry returns to discovery");
    Check(normal.DeviceFound()&&normal.Opened()&&normal.Activated(),"reconnect repeats open and activation");
    Check(normal.State()==RunnerState::Running&&normal.ReconnectCount()==1,"reconnect returns to running once");
    normal.Stop();
    Check(normal.State()==RunnerState::Stopping&&!normal.DeviceFound(),"cancellation is terminal");
    normal.Stop();
    Check(normal.State()==RunnerState::Stopping,"stop is idempotent");
    std::cout<<checks<<" checks, "<<failed<<" failures\n";
    return failed?1:0;
}

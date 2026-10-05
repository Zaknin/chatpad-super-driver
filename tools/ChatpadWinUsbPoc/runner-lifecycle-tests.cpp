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
    Check(ClassifySessionCleanup(true,true,true,shortRumbleWrite)==SessionCleanupDisposition::Failed,
        "short zero-rumble write remains a fatal cleanup failure");
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

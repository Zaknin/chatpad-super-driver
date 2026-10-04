#include "RunnerLifecycle.h"
#include <iostream>
using namespace chatpad;
unsigned checks{}, failed{};
void Check(bool value,const char* name){++checks;if(!value){++failed;std::cerr<<"FAIL: "<<name<<'\n';}}
int main(){
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

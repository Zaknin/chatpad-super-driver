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
    Check(lifecycle.DeviceLost()&&lifecycle.State()==RunnerState::DeviceLost,"running device loss is explicit");
    Check(!lifecycle.DeviceLost()&&lifecycle.ReconnectCount()==1,"duplicate loss does not double count");
    Check(lifecycle.BeginReconnect()&&lifecycle.State()==RunnerState::Reconnecting,"loss begins reconnect wait");
    Check(lifecycle.Retry()&&lifecycle.State()==RunnerState::WaitingForDevice,"retry returns to discovery");
    Check(lifecycle.DeviceFound()&&lifecycle.Opened()&&lifecycle.Activated(),"reconnect repeats open and activation");
    Check(lifecycle.State()==RunnerState::Running&&lifecycle.ReconnectCount()==1,"reconnect returns to running once");
    lifecycle.Stop();
    Check(lifecycle.State()==RunnerState::Stopping&&!lifecycle.DeviceFound(),"cancellation is terminal");
    lifecycle.Stop();
    Check(lifecycle.State()==RunnerState::Stopping,"stop is idempotent");
    std::cout<<checks<<" checks, "<<failed<<" failures\n";
    return failed?1:0;
}

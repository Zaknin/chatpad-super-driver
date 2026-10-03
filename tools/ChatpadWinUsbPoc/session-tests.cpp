#include "SessionPolicy.h"
#include <iostream>
using namespace chatpad;
unsigned checks{},failed{};
void Check(bool value,const char* text){++checks;if(!value){++failed;std::cerr<<"FAIL: "<<text<<'\n';}}
int main(){
    SessionRequest request;
    for(auto value:{SessionCommand::Activate,SessionCommand::CreateVirtual,SessionCommand::EnableMapping,
        SessionCommand::EnableRumble,SessionCommand::EnableKeyboard,SessionCommand::Stop}){
        Check(ParseSessionRequest("{\"id\":1,\"command\":\""+std::string(SessionCommandName(value))+"\"}",request)&&request.id==1&&request.command==value,"strict supported command");
    }
    for(const auto& bad:{"{}","{\"id\":0,\"command\":\"stop\"}","{\"id\":4294967296,\"command\":\"stop\"}",
        "{\"id\":1,\"command\":\"unknown\"}","{\"id\":1,\"command\":\"stop\",\"id\":2}",
        "{\"id\":1,\"command\":\"stop\",\"extra\":true}","{\"id\":-1,\"command\":\"stop\"}",
        "{\"id\":1.0,\"command\":\"stop\"}","{\"id\":1,\"command\":\"stop\"} trailing"})Check(!ParseSessionRequest(bad,request),"malformed unknown duplicate fields refused");
    Check(!ParseSessionRequest(std::string(129,' '),request),"bounded line128");
    SessionPolicy policy;
    Check(!policy.AcceptRequestId(0)&&policy.AcceptRequestId(1)&&!policy.AcceptRequestId(1)&&
          !policy.AcceptRequestId(0)&&policy.AcceptRequestId(3)&&!policy.AcceptRequestId(2),"request correlation refuses zero replay and reorder");
    Check(!policy.Allowed(SessionCommand::Activate)&&policy.Allowed(SessionCommand::Stop),"no activation without controller readiness");
    policy.ObserveFiveBytes(true);policy.ObserveController();
    Check(policy.Allowed(SessionCommand::Activate)&&!policy.Allowed(SessionCommand::CreateVirtual),"preactivation packet cannot arm virtual");
    policy.Commit(SessionCommand::Activate);
    Check(!policy.Allowed(SessionCommand::Activate)&&!policy.Allowed(SessionCommand::CreateVirtual),"activation one shot and wait real packet");
    policy.ObserveFiveBytes(false);Check(!policy.Allowed(SessionCommand::CreateVirtual),"failed001B cannot arm virtual");
    policy.ObserveFiveBytes(true);Check(policy.Allowed(SessionCommand::CreateVirtual),"strict001B plus real five bytes arm virtual");
    policy.Commit(SessionCommand::CreateVirtual);Check(!policy.Allowed(SessionCommand::CreateVirtual)&&policy.Allowed(SessionCommand::EnableMapping),"virtual once before mapping");
    Check(!policy.Allowed(SessionCommand::EnableKeyboard)&&!policy.Allowed(SessionCommand::EnableRumble),"no outputs before mapping");
    policy.Commit(SessionCommand::EnableMapping);Check(policy.Mapping()&&policy.Allowed(SessionCommand::EnableRumble),"mapping before rumble");
    Check(!policy.Allowed(SessionCommand::EnableKeyboard),"no keyboard before rumble stage");
    policy.Commit(SessionCommand::EnableRumble);Check(policy.Rumble()&&policy.Allowed(SessionCommand::EnableKeyboard),"keyboard later than rumble");
    policy.Commit(SessionCommand::EnableKeyboard);Check(policy.Keyboard()&&!policy.Allowed(SessionCommand::EnableKeyboard),"keyboard once");
    policy.Commit(SessionCommand::Stop);Check(!policy.Allowed(SessionCommand::Stop)&&!policy.Allowed(SessionCommand::Activate),"stopped session terminal");
    for(unsigned stage=0;stage<6;++stage){
        SessionPolicy recovery;recovery.ObserveController();
        const SessionCommand order[]{SessionCommand::Activate,SessionCommand::CreateVirtual,SessionCommand::EnableMapping,
            SessionCommand::EnableRumble,SessionCommand::EnableKeyboard};
        for(unsigned i=0;i<stage;++i){recovery.Commit(order[i]);recovery.ObserveFiveBytes(true);}
        Check(recovery.Allowed(SessionCommand::Stop),"stop/cleanup available at every session stage");
    }
    std::cout<<checks<<" checks, "<<failed<<" failures\n";return failed?1:0;
}

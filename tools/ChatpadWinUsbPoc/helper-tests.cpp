#include "VirtualHelper.h"
#include <iostream>
#include <filesystem>
using namespace chatpad;
static unsigned total{},failed{};
static void Check(bool ok,const char* name){++total;if(!ok){++failed;std::cerr<<"FAIL: "<<name<<'\n';}}
int main(int argc,char** argv) {
    HelperMessage m;
    Check(ParseHelperMessage("{\"id\":0,\"ok\":true,\"operation\":\"create\"}",m)&&m.hasId&&m.ok&&m.id==0&&m.operation=="create","create response parsed");
    Check(ParseHelperMessage(" { \"operation\":\"submit\",\"ok\":true,\"id\":2147483647 } ",m)&&m.id==2147483647,"order whitespace and maxid");
    Check(ParseHelperMessage("{\"id\":2,\"ok\":false,\"error\":\"backend_unavailable\",\"detail\":\"quoted \\\" path \\\\ text\"}",m)&&!m.ok&&m.error=="backend_unavailable","escaped error details parsed");
    Check(ParseHelperMessage("{\"id\":null,\"ok\":false,\"error\":\"deadline_or_cancellation\"}",m)&&!m.hasId&&!m.ok,"uncorrelated terminal error parsed");
    Check(ParseHelperMessage("{\"event\":\"rumble\",\"leftMotor\":0,\"rightMotor\":65535}",m)&&m.kind==HelperMessageKind::Rumble&&m.rightMotor==65535,"rumble exact ushort ranges");
    for(const char* bad: {
        "", "[]", "{}", "{\"id\":0,\"ok\":true}",
        "{\"id\":0,\"id\":1,\"ok\":true,\"operation\":\"create\"}",
        "{\"id\":-1,\"ok\":true,\"operation\":\"create\"}",
        "{\"id\":2147483648,\"ok\":true,\"operation\":\"create\"}",
        "{\"id\":0.0,\"ok\":true,\"operation\":\"create\"}",
        "{\"id\":00,\"ok\":true,\"operation\":\"create\"}",
        "{\"id\":0,\"ok\":\"true\",\"operation\":\"create\"}",
        "{\"id\":0,\"ok\":true,\"operation\":\"bogus\"}",
        "{\"id\":null,\"ok\":true,\"operation\":\"create\"}",
        "{\"id\":0,\"ok\":false}",
        "{\"id\":0,\"ok\":true,\"operation\":\"create\",\"error\":\"no\"}",
        "{\"id\":0,\"ok\":true,\"operation\":\"create\",\"extra\":0}",
        "{\"id\":0,\"ok\":true,\"operation\":\"create\"} garbage",
        "{\"id\":0,\"ok\":true,\"operation\":\"create\",}",
        "{\"event\":\"rumble\",\"leftMotor\":65536,\"rightMotor\":0}",
        "{\"event\":\"rumble\",\"leftMotor\":-1,\"rightMotor\":0}",
        "{\"event\":\"rumble\",\"leftMotor\":0}",
        "{\"event\":\"rumble\",\"leftMotor\":0,\"rightMotor\":0,\"id\":0}",
        "{\"event\":\"other\",\"leftMotor\":0,\"rightMotor\":0}",
        "{\"event\":\"rumble\",\"leftMotor\":0,\"rightMotor\":0,\"leftMotor\":1}",
        "{\"id\":0,\"ok\":false,\"error\":\"bad\\x\"}"
    })Check(!ParseHelperMessage(bad,m),"malformed duplicate unknown type or outofrange schema rejected");
    Check(!ParseHelperMessage(std::string(4097,' '),m),"4096-byte line bound");
    Check(ParseHelperMessage("{\"id\":0,\"ok\":false,\"error\":\"error\",\"detail\":\"\\u263A\\uD83D\\uDE00\"}",m),"valid Unicode escapes in details");
    HelperOptions relative;relative.executable=L"relative.exe";relative.backend="mock";VirtualHelperController r(relative);Check(!r.Create(),"relative executable refuses");
    if(argc==2) {
        HelperOptions options;options.executable=std::filesystem::absolute(argv[1]).wstring();options.backend="mock";
        VirtualHelperController mock(options);unsigned callbacks{};mock.SetRumbleCallback([&](uint16_t,uint16_t){++callbacks;});
        Check(mock.Create(),"mock helper child creates");
        Check(!mock.Create(),"duplicate native create refuses");
        Check(mock.SubmitState({0xf7ff,255,0,-32768,32767,-1,1}),"mock full-range state roundtrip");
        Check(mock.SubmitState({}),"mock neutral roundtrip");
        mock.Disconnect();mock.Disconnect();Check(callbacks==0,"shutdown drains without fabricated rumble");
        Check(!mock.SubmitState({}),"submit after disconnect refuses");
        Check(mock.Create(),"mock reconnect launches fresh owned child");mock.Disconnect();
        options.backend="unavailable";VirtualHelperController missing(options);Check(!missing.Create()&&missing.LastError().find("backend_unavailable")!=std::string::npos,"unavailable backend explicit bounded failure");missing.Disconnect();
        options.backend="hidmaestro";VirtualHelperController gated(options);Check(!gated.Create(),"hidmaestro refuses missing explicit live flag before child launch");
    } else {Check(false,"absolute mock helper executable required for integration tests");}
    std::cout<<"{\"suite\":\"NativeVirtualHelper\",\"total\":"<<total<<",\"passed\":"<<total-failed<<",\"failed\":"<<failed<<",\"backend\":\"mock/unavailable\",\"liveMutation\":false}\n";
    return failed?1:0;
}

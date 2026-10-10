#include "BridgeCore.h"
#include "KeyboardOutput.h"
#include <algorithm>
#include <array>
#include <iostream>
#include <limits>
#include <utility>
using namespace chatpad;
static unsigned total{}, failed{};
static void Check(bool condition, const char* name) {
    ++total;
    if (!condition) { ++failed; std::cerr << "FAIL: " << name << '\n'; }
}
struct MockPhysical : IPhysicalTransport {
    std::vector<DeviceInfo> devices{{"mock", "fixture", 0x045e, 0x028e, 1, {}}};
    std::vector<InterfaceInfo> interfaces{{0,0,{{0x81,3,32},{0x01,3,32}}},{2,0,{{0x84,3,32}}}};
    TransferResult open{TransferStatus::Ok,0,0}, read{TransferStatus::Ok,0,20};
    std::vector<TransferResult> results;
    std::vector<ControlRequest> controls;
    unsigned cancels{}, closes{}, reads{};
    std::vector<DeviceInfo> Enumerate() override { return devices; }
    TransferResult Open(const std::string&) override { return open; }
    std::vector<InterfaceInfo> Interfaces() override { return interfaces; }
    TransferResult Control(const ControlRequest& request, std::vector<uint8_t>& inbound, uint32_t timeout) override {
        Check(timeout == 1000, "control bounded to 1000 ms");
        size_t index=controls.size(); controls.push_back(request);
        auto result = index<results.size() ? results[index] : TransferResult{TransferStatus::Ok,0,request.length};
        inbound.assign((request.requestType & 0x80) ? result.transferred : 0,0);
        return result;
    }
    TransferResult Read(uint8_t number,uint8_t endpoint,std::vector<uint8_t>& data,uint32_t timeout) override {
        Check(number==0 && endpoint==0x81 && timeout==1000,"read contract");
        ++reads; data.assign(read.status==TransferStatus::Ok?read.transferred:0,0); return read;
    }
    TransferResult Write(uint8_t,uint8_t,const std::vector<uint8_t>& data,uint32_t) override { return {TransferStatus::Ok,0,data.size()}; }
    void Cancel() override { ++cancels; }
    void Close() override { ++closes; }
};
struct MockVirtual : IVirtualXboxController {
    bool available{true}, submitOk{true}; unsigned creates{}, submits{}, disconnects{};
    XboxState state{}; RumbleCallback callback;
    bool Create() override { ++creates; return available; }
    bool SubmitState(const XboxState& value) override { ++submits; state=value; return submitOk; }
    void SetRumbleCallback(RumbleCallback value) override { callback=std::move(value); }
    void Disconnect() override { ++disconnects; }
};
struct MockKeyboard : IKeyboardOutput {
    std::array<bool,256> held{};
    std::vector<std::pair<uint8_t,bool>> events;
    int failUsage{-1}; bool failDown{}, failRelease{};
    unsigned forceCalls{};
    bool Send(uint8_t usage,bool down) override {
        events.push_back({usage,down});
        if (failUsage==usage && down==failDown) return false;
        held[usage]=down; return true;
    }
    bool ForceRelease() override { ++forceCalls; if(failRelease) return false; held.fill(false); return true; }
};
static std::array<uint8_t,20> Neutral() { std::array<uint8_t,20> p{}; p[1]=20; return p; }
static void PacketHexTests() {
    const std::array<uint8_t,3> packet{{0x01,0x03,0x02}};
    Check(PacketHex(packet.data(),packet.size())=="010302",
        "packet diagnostic hex preserves every byte in order");
}
static void ControllerReadinessTests() {
    XboxState state{};
    const std::array<std::array<uint8_t,3>,4> statuses{{
        {{0x01,0x03,0x02}},{{0x02,0x03,0x00}},{{0x03,0x03,0x03}},{{0x08,0x03,0x00}}
    }};
    for(const auto& packet:statuses)
        Check(ClassifyControllerPacket(packet.data(),packet.size(),state)==ControllerPacketClassification::NonControllerStatus,
            "only documented three-byte status packet signatures are classified as status");

    const auto valid=Neutral();
    ControllerReadiness exactObserved(100,5000);
    Check(exactObserved.Observe(100,{TransferStatus::Ok,0,statuses[2].size()},statuses[2].data(),statuses[2].size(),state)==ControllerReadinessDecision::Waiting,
        "observed 03 03 03 status packet is skipped while readiness remains inside its deadline");
    Check(exactObserved.Observe(101,{TransferStatus::Ok,0,valid.size()},valid.data(),valid.size(),state)==ControllerReadinessDecision::Ready,
        "valid report following exact 03 03 03 status packet completes readiness");

    ControllerReadiness several(200,5000);
    for(size_t i=0;i<statuses.size();++i)
        Check(several.Observe(200+i*10,{TransferStatus::Ok,0,statuses[i].size()},statuses[i].data(),statuses[i].size(),state)==ControllerReadinessDecision::Waiting,
            "multiple known status packets remain non-terminal while readiness deadline is open");
    Check(several.Observe(250,{TransferStatus::Ok,0,valid.size()},valid.data(),valid.size(),state)==ControllerReadinessDecision::Ready,
        "valid report after multiple known status packets completes readiness");

    ControllerReadiness deadline(1000,5000);
    Check(deadline.ReadTimeoutMs(1000,500)==500 && deadline.ReadTimeoutMs(5500,500)==500 &&
        deadline.ReadTimeoutMs(5999,500)==1 && deadline.ReadTimeoutMs(6000,500)==0,
        "per-read timeout shrinks against one fixed overall deadline");
    for(uint64_t now: {1000ull,2500ull,4000ull,5999ull})
        Check(deadline.Observe(now,{TransferStatus::Ok,0,statuses[2].size()},statuses[2].data(),statuses[2].size(),state)==ControllerReadinessDecision::Waiting,
            "status-only traffic never completes readiness before the fixed deadline");
    Check(deadline.Observe(6000,{TransferStatus::Timeout,1460,0},nullptr,0,state)==ControllerReadinessDecision::TimedOut,
        "status-only traffic ends as readiness timeout at the original deadline");
    ControllerReadiness readTimeouts(400,1000);
    Check(readTimeouts.Observe(400,{TransferStatus::Timeout,1460,0},nullptr,0,state)==ControllerReadinessDecision::ReadTimedOut &&
        readTimeouts.Observe(1399,{TransferStatus::Timeout,1460,0},nullptr,0,state)==ControllerReadinessDecision::ReadTimedOut &&
        readTimeouts.Observe(1400,{TransferStatus::Timeout,1460,0},nullptr,0,state)==ControllerReadinessDecision::TimedOut,
        "intermediate Win32 read timeouts stay distinct while the original overall deadline remains fixed");

    std::array<uint8_t,19> malformed{};malformed[1]=20;
    Check(ClassifyControllerPacket(malformed.data(),malformed.size(),state)==ControllerPacketClassification::Invalid &&
        ClassifyControllerProbe({TransferStatus::Ok,0,malformed.size()},malformed.data(),malformed.size(),state)==ControllerProbeClassification::ReportRejected,
        "wrong-length type-zero controller candidate remains rejected");
    ControllerReadiness invalid(300,5000);
    Check(invalid.Observe(300,{TransferStatus::Ok,0,malformed.size()},malformed.data(),malformed.size(),state)==ControllerReadinessDecision::ReportRejected,
        "malformed controller candidate fails readiness instead of being accepted or treated as a status packet");
    Check(invalid.Observe(301,{TransferStatus::Error,31,0},valid.data(),valid.size(),state)==ControllerReadinessDecision::TransferFailed,
        "Win32 transfer failure remains distinct from malformed report and readiness timeout");
}
static void ControllerTests() {
    XboxState s{}; auto p=Neutral();
    Check(ParseController(p.data(),p.size(),s) && !s.buttons && !s.lx && !s.leftTrigger,"neutral controller");
    Check(ClassifyControllerProbe({TransferStatus::Timeout,1460,0},p.data(),p.size(),s)==ControllerProbeClassification::TransferFailed,
        "probe timeout remains transfer failure even with a valid-looking packet buffer");
    Check(ClassifyControllerProbe({TransferStatus::Error,0,0},nullptr,0,s)==ControllerProbeClassification::TransferFailed,
        "probe transfer error is distinct when Win32 code is zero");
    Check(ClassifyControllerProbe({TransferStatus::Ok,0,p.size()},p.data(),p.size(),s)==ControllerProbeClassification::ReportAccepted,
        "probe accepts a valid controller report");
    auto rejectedProbe=Neutral();rejectedProbe[2]=0;rejectedProbe[3]=0x08;
    Check(ClassifyControllerProbe({TransferStatus::Ok,0,rejectedProbe.size()},rejectedProbe.data(),rejectedProbe.size(),s)==ControllerProbeClassification::ReportRejected,
        "probe report parser rejection is distinct from transport failure");
    for(unsigned bit=0;bit<16;++bit) {
        p=Neutral(); unsigned mask=1u<<bit; p[2]=static_cast<uint8_t>(mask); p[3]=static_cast<uint8_t>(mask>>8);
        bool parsed=ParseController(p.data(),p.size(),s);
        Check(bit==11 ? !parsed : parsed && s.buttons==mask,"each controller button and reserved bit");
    }
    for(unsigned dpad=0;dpad<16;++dpad) {
        p=Neutral();p[2]=static_cast<uint8_t>(dpad);
        Check(ParseController(p.data(),p.size(),s) && s.buttons==dpad,"all raw dpad states retained");
    }
    for(unsigned trigger=0;trigger<2;++trigger) for(unsigned boundary: {0u,1u,127u,254u,255u}) {
        p=Neutral();p[4+trigger]=static_cast<uint8_t>(boundary);
        Check(ParseController(p.data(),p.size(),s) && (trigger?s.rightTrigger:s.leftTrigger)==boundary,"trigger boundaries");
    }
    for(unsigned stick=0;stick<4;++stick) for(int value: {-32768,-32767,-1,0,1,32766,32767}) {
        p=Neutral();auto bits=static_cast<uint16_t>(value);p[6+stick*2]=static_cast<uint8_t>(bits);p[7+stick*2]=static_cast<uint8_t>(bits>>8);
        Check(ParseController(p.data(),p.size(),s),"stick report accepted");
        const int16_t values[]{s.lx,s.ly,s.rx,s.ry};Check(values[stick]==value,"signed stick exact extrema and center");
    }
    p=Neutral(); for(size_t length=0;length<20;++length) Check(!ParseController(p.data(),length,s),"every short controller report rejected");
    Check(!ParseController(nullptr,20,s),"null controller rejected");
    Check(!ParseController(p.data(),21,s),"oversized controller rejected before access");
    p[0]=1;Check(!ParseController(p.data(),20,s),"unknown controller type rejected");
    p=Neutral();p[1]=19;Check(!ParseController(p.data(),20,s),"wrong controller declared size rejected");
    Check(s.buttons==0 && s.rx==0,"rejected controller clears output");
    Check(BuildRumble(0,0)==std::vector<uint8_t>({0,8,0,0,0,0,0,0}),"neutral rumble packet");
    Check(BuildRumble(65535,65535)==std::vector<uint8_t>({0,8,0,255,255,0,0,0}),"maximum rumble packet");
    Check(BuildRumble(0x1234,0x9876)==std::vector<uint8_t>({0,8,0,0x12,0x98,0,0,0}),"rumble high-byte quantization");
    for(unsigned pattern=0;pattern<14;++pattern)Check(BuildPlayerLed(static_cast<uint8_t>(pattern))==std::vector<uint8_t>({1,3,static_cast<uint8_t>(pattern)}),"documented LED patterns");
    Check(BuildPlayerLed(14).empty()&&BuildPlayerLed(255).empty(),"unknown LED patterns rejected");
}
static void ActivationTests() {
    MockPhysical p; ActivationRunner runner; std::vector<uint32_t> delays;
    auto a=runner.Run(p,[&](uint32_t ms){delays.push_back(ms);});
    Check(a.success && a.completedSteps==6 && a.events.size()==6,"activation completes exactly six requests");
    const uint8_t types[]{0x40,0x40,0x40,0xc0,0x40,0xc0};
    const uint8_t reqs[]{0xa9,0xa9,0xa9,0xa1,0xa1,0xa1};
    const uint16_t values[]{0xa30c,0x2344,0x5839,0,0,0},indices[]{0x4423,0x7f03,0x6832,0xe416,0xe416,0xe416};
    for(size_t i=0;i<6;++i) Check(p.controls[i].requestType==types[i] && p.controls[i].request==reqs[i] && p.controls[i].value==values[i] && p.controls[i].index==indices[i] && p.controls[i].length==(i<3?0:2),"exact activation setup");
    Check(p.controls[4].payload==std::vector<uint8_t>({9,0}),"exact revision 1.14 activation payload");
    Check(delays==std::vector<uint32_t>(6,12),"six immutable 12ms post delays");
    Check(!runner.Run(p,[](uint32_t){}).success && p.controls.size()==6,"activation instance never retries");
    for(size_t step=0;step<6;++step) {
        MockPhysical stalled;
        for(size_t i=0;i<step;++i) stalled.results.push_back({TransferStatus::Ok,0,i<3?0u:2u});
        stalled.results.push_back({TransferStatus::Stall,31,0});
        auto result=ActivationRunner{}.Run(stalled,[](uint32_t){});
        Check(step<4 ? result.success && result.events[step].expectedStall : !result.success && stalled.controls.size()==step+1,"only steps zero through three accept proven zero-byte stall");
    }
    for(TransferStatus status: {TransferStatus::Timeout,TransferStatus::Cancelled,TransferStatus::AccessDenied,TransferStatus::DeviceNotPresent,TransferStatus::Error}) {
        MockPhysical bad;bad.results.push_back({status,status==TransferStatus::Error?31u:5u,0});
        Check(!ActivationRunner{}.Run(bad,[](uint32_t){}).success && bad.controls.size()==1,"activation fails closed for timeout cancel denied absent and ambiguous31");
    }
    for(size_t step=0;step<6;++step) {
        MockPhysical shortTransfer;
        for(size_t i=0;i<step;++i) shortTransfer.results.push_back({TransferStatus::Ok,0,i<3?0u:2u});
        shortTransfer.results.push_back({TransferStatus::Ok,0,step<3?1u:1u});
        Check(!ActivationRunner{}.Run(shortTransfer,[](uint32_t){}).success,"activation rejects every incorrect count");
    }
    MockPhysical nonzero;nonzero.results.push_back({TransferStatus::Stall,31,1});
    Check(!ActivationRunner{}.Run(nonzero,[](uint32_t){}).success,"nonzero stall fails closed");
    MockPhysical missingDelay;Check(!ActivationRunner{}.Run(missingDelay,{}).success && missingDelay.controls.empty(),"missing scheduler fails before control");
}
static void MaintenanceTests() {
    MockPhysical p;ChatpadMaintenance m(p);
    Check(!m.Tick(0) && !m.OnCompletePacket(5) && p.controls.empty(),"no maintenance before start");
    Check(m.Start(100),"maintenance starts");Check(p.controls[0].value==0x1f,"initial keepalive001F");
    Check(m.Tick(1099) && p.controls.size()==1,"no early keepalive");
    Check(m.Tick(1100) && p.controls[1].value==0x1e,"next keepalive001E");
    Check(m.Tick(5100) && p.controls[2].value==0x1f && p.controls.size()==3,"late scheduler emits one keepalive no burst");
    Check(m.OnCompletePacket(4) && p.controls.size()==3,"short packet does not enable key data");
    Check(m.OnCompletePacket(5) && p.controls[3].value==0x1b && m.KeyDataAttempted(),"first complete packet enables001B");
    Check(m.OnCompletePacket(5) && p.controls.size()==4,"001B never retries");
    for(auto& r:p.controls) Check(r.requestType==0x41 && r.request==0 && r.index==2 && !r.length && r.payload.empty(),"interface maintenance exact setup");
    m.Stop();Check(!m.Tick(10000) && !m.Start(10000) && p.controls.size()==4,"stopped lifecycle cannot restart");
    MockPhysical bad;bad.results={{TransferStatus::Ok,0,0},{TransferStatus::Error,31,0}};ChatpadMaintenance fail(bad);
    Check(fail.Start(0) && !fail.OnCompletePacket(5) && !fail.Active(),"failed001B disables optional path");
    Check(!fail.OnCompletePacket(5) && bad.controls.size()==2,"failed001B not retried");
}
static void KeyboardTests() {
    MockKeyboard out;KeyboardMapper m(out);
    auto packet=[](uint8_t mod,uint8_t a,uint8_t b=0){return std::array<uint8_t,5>{{0,mod,a,b,0}};};
    auto a=packet(0,0x37);Check(m.Process(a.data(),5)&&out.held[4],"base A injected through mock");
    Check(m.Process(a.data(),5)&&out.events.size()==1,"duplicate held report suppressed");
    auto zero=packet(0,0);Check(m.Process(zero.data(),5)&&!out.held[4],"base A released");
    auto shift=packet(1,0x27,0x21);Check(m.Process(shift.data(),5)&&out.held[0xe1]&&out.held[0x14]&&out.held[0x18],"Shift and two-key mapping");
    Check(out.events[out.events.size()-3]==std::make_pair(uint8_t(0xe1),true),"modifier press precedes keys");
    Check(m.Process(zero.data(),5),"two-key Shift release");
    Check(out.events.back()==std::make_pair(uint8_t(0xe1),false),"key releases precede modifier release");
    auto green=packet(2,0x27);Check(m.Process(green.data(),5)&&out.held[0x1e]&&out.held[0xe1],"Green Q chord");
    out.failUsage=0x1e;out.failDown=false;
    Check(!m.Process(a.data(),5)&&out.held[0x1e]&&out.held[0xe1]&&!out.held[4],"failed chord-key release retains modifier and prevents new press");
    out.failUsage=-1;Check(m.Process(zero.data(),5),"cleanup after failed chord release");
    Check(m.Process(green.data(),5),"Green Q restored before latching check");
    auto latched=packet(0,0x27);Check(m.Process(latched.data(),5)&&out.held[0x1e]&&!out.held[0x14],"Green action latches across modifier release");
    Check(m.Process(zero.data(),5)&&!out.held[0x1e]&&!out.held[0xe1],"Green release clears chord");
    auto orange=packet(5,0);Check(m.Process(orange.data(),5)&&out.held[0x39]&&!out.held[0xe1],"Orange Shift CapsLock");
    Check(m.ForceRelease()&&!out.held[0x39],"forced release clears orange pseudo key");
    for(uint8_t mod: {uint8_t(0),uint8_t(2),uint8_t(4)}) for(unsigned raw=1;raw<0xf1;++raw) {
        ChatpadConfiguration cfg{};ChatpadBuildDefaultConfiguration(&cfg);
        if(!ChatpadIsSupportedPhysicalKey(static_cast<uint8_t>(raw)))continue;
        auto p=packet(mod,static_cast<uint8_t>(raw));m.ForceRelease();
        const auto& action=mod==0?cfg.Base[raw]:mod==2?cfg.Green[raw]:cfg.Orange[raw];
        bool result=m.Process(p.data(),5);
        Check(action.Type==CHATPAD_MAPPING_ACTION_KEYBOARD ? result&&out.held[action.Usage] : !result,"each physical key follows Base Green Orange configured action");
    }
    m.ForceRelease();Check(m.Process(a.data(),5),"press before malformed input");
    auto malformed=a;malformed[0]=0xf0;Check(!m.Process(malformed.data(),5)&&!out.held[4],"F0 rejected and held output safely released");
    Check(!m.Process(nullptr,5),"null Chatpad input rejected");Check(!m.Process(a.data(),4),"short Chatpad input rejected");
    malformed=a;malformed[1]=0x10;Check(!m.Process(malformed.data(),5),"unknown modifier rejected");
    auto unsupported=packet(2,0x25);Check(!m.Process(unsupported.data(),5),"deferred layout-dependent legend not emulated");
    Check(!m.LastOutputFailed(),"unsupported mapping is rejected without output failure");
    Check(!m.Process(malformed.data(),5)&&!m.LastOutputFailed(),"malformed packet rejection is not output failure");
    Check(m.Process(a.data(),5),"press before failed release");out.failUsage=4;out.failDown=false;out.failRelease=true;
    Check(!m.ForceRelease()&&out.held[4],"failed keyup retained for later cleanup");
    out.failUsage=-1;out.failRelease=false;Check(m.ForceRelease()&&!out.held[4],"later forced release retries retained held key");
    out.failUsage=4;out.failDown=true;Check(!m.Process(a.data(),5)&&!out.held[4],"failed keydown not recorded held");
    Check(m.LastOutputFailed(),"failed output keydown is fatal to live session");
    out.failUsage=-1;Check(m.Process(a.data(),5)&&out.held[4],"failed keydown retried on next report");m.ForceRelease();
    ScanCode sc;Check(UsageToScanCode(0x04,sc)&&sc.code==0x1e&&!sc.extended,"A scan code");
    Check(UsageToScanCode(0x4f,sc)&&sc.code==0x4d&&sc.extended,"right arrow extended scan");
    Check(UsageToScanCode(0xe4,sc)&&sc.code==0x1d&&sc.extended,"right Control extended scan");
    Check(!UsageToScanCode(0xff,sc),"unknown HID usage rejected");
    ChatpadConfiguration cfg{};ChatpadBuildDefaultConfiguration(&cfg);
    for(unsigned raw=1;raw<256;++raw) for(auto action: {cfg.Base[raw],cfg.Green[raw],cfg.Orange[raw]}) if(action.Type==CHATPAD_MAPPING_ACTION_KEYBOARD)Check(UsageToScanCode(action.Usage,sc),"every configured keyboard usage has scan code");
}
static void LifecycleTests() {
    MockPhysical p;MockVirtual v;MockKeyboard k;BridgeSession s(p,v,k);
    Check(p.Enumerate().size()==1&&p.Interfaces()[1].number==2,"mock enumeration associated actual interface and endpoint discovery");
    Check(s.Start("mock")&&s.Running()&&v.creates==1,"bridge create");
    unsigned rumble{};s.SetPhysicalRumbleHandler([&](uint16_t l,uint16_t r){if(l==123&&r==456)++rumble;});v.callback(123,456);Check(rumble==1,"virtual rumble callback routed without invented output bytes");
    auto n=Neutral();n[4]=255;Check(s.SubmitController(n.data(),20)&&v.submits==1&&v.state.leftTrigger==255,"controller forwarded to replaceable backend");
    Check(!s.SubmitController(n.data(),19)&&v.submits==1,"malformed input never submitted");
    s.Shutdown();Check(!s.Running()&&p.cancels==1&&p.closes==1&&v.disconnects==1&&!v.callback&&k.forceCalls==1,"shutdown cancel release disconnect close");
    s.Shutdown();Check(p.cancels==1&&p.closes==1,"shutdown idempotent");
    Check(s.Start("mock")&&v.creates==2,"reconnect creates new backend");s.Shutdown();
    for(TransferStatus status: {TransferStatus::AccessDenied,TransferStatus::DeviceNotPresent,TransferStatus::Error}) {
        MockPhysical denied;denied.open={status,5,0};MockVirtual unused;MockKeyboard keys;BridgeSession b(denied,unused,keys);
        Check(!b.Start("mock")&&unused.creates==0,"failed physical open never creates virtual");
    }
    MockPhysical missing;missing.interfaces.erase(missing.interfaces.begin()+1);MockVirtual unused;MockKeyboard keys;BridgeSession b(missing,unused,keys);
    Check(!b.Start("mock")&&missing.cancels==1&&missing.closes==1&&unused.creates==0,"missing associated interface closes physical");
    MockPhysical ok;MockVirtual absent;absent.available=false;MockKeyboard keys2;BridgeSession c(ok,absent,keys2);
    Check(!c.Start("mock")&&ok.cancels==1&&ok.closes==1&&absent.disconnects==0,"unavailable backend closes physical");
    MockPhysical badSubmit;MockVirtual badV;MockKeyboard keys3;BridgeSession d(badSubmit,badV,keys3);d.Start("mock");badV.submitOk=false;
    Check(!d.SubmitController(n.data(),20)&&!d.Running()&&badV.disconnects==1,"backend submit failure cleans session");
    for(TransferStatus status: {TransferStatus::Ok,TransferStatus::Timeout,TransferStatus::Cancelled,TransferStatus::DeviceNotPresent}) {
        MockPhysical transport;transport.read={status,0,status==TransferStatus::Ok?20u:0u};std::vector<uint8_t> data;
        auto result=transport.Read(0,0x81,data,1000);Check(result.status==status&&data.size()==result.transferred,"mock read completion timeout cancel disconnect distinct");transport.Cancel();transport.Close();
    }
}
int main() {
    PacketHexTests();ControllerReadinessTests();ControllerTests();ActivationTests();MaintenanceTests();KeyboardTests();LifecycleTests();
    std::cout<<"{\"suite\":\"ChatpadWinUsbPocCore\",\"total\":"<<total<<",\"passed\":"<<total-failed<<",\"failed\":"<<failed<<",\"liveMutation\":false}\n";
    return failed?1:0;
}

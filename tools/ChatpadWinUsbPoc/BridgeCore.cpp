#include "BridgeCore.h"
#include "KeyboardOutput.h"
#include <utility>
extern "C" {
#include "ChatpadActivationSequence.h"
#include "ChatpadLiveTransferPolicy.h"
}
namespace chatpad {
static int16_t SignedLe(const uint8_t* data) {
    const unsigned bits=unsigned(data[0])|(unsigned(data[1])<<8);
    return static_cast<int16_t>(bits<32768?static_cast<int>(bits):static_cast<int>(bits)-65536);
}
bool ParseController(const uint8_t* data,size_t size,XboxState& out) {
    out={};
    if(!data || size!=20 || data[0]!=0 || data[1]!=20) return false;
    const uint16_t buttons=static_cast<uint16_t>(unsigned(data[2])|(unsigned(data[3])<<8));
    if(buttons&0x0800) return false;
    out={buttons,data[4],data[5],SignedLe(data+6),SignedLe(data+8),SignedLe(data+10),SignedLe(data+12)};
    return true;
}
// Source-backed wired Xbox format; uint16 XInput motor values use their high byte.
// This packet encoding is offline-qualified, not a claim of physical rumble acceptance.
std::vector<uint8_t> BuildRumble(uint16_t left,uint16_t right) {
    return {0,8,0,static_cast<uint8_t>(left>>8),static_cast<uint8_t>(right>>8),0,0,0};
}
std::vector<uint8_t> BuildPlayerLed(uint8_t pattern) {
    if(pattern>13) return {};
    return {1,3,pattern};
}
const char* ActivationDisposition(const ActivationEvent& event) {
    if(event.probeRejected)return "PROBE_REJECTED";
    if(event.expectedStall)return "PROVEN_STALL_ACCEPTED";
    return event.accepted?"SUCCESS":"FATAL";
}
ActivationResult ActivationRunner::Run(IPhysicalTransport& transport,
    const std::function<void(uint32_t)>& delay,const std::function<void(const ActivationEvent&)>& observe) {
    ActivationResult output;
    if(consumed_ || !delay) return output;
    consumed_=true;
    for(size_t index=0;index<ChatpadGetActivationSequenceStepCount();++index) {
        ChatpadActivationSequenceStep step{};
        if(ChatpadGetActivationSequenceStep(index,&step)!=CHATPAD_ACTIVATION_SEQUENCE_OK) return output;
        const auto& r=step.Request;
        ControlRequest setup{r.RawBmRequestType,r.RawRequest,r.RawValue,r.RawIndex,r.RawLength,{}};
        setup.payload.assign(r.OutboundPayload,r.OutboundPayload+r.OutboundPayloadLength);
        if(step.DelayBeforeMilliseconds) delay(step.DelayBeforeMilliseconds);
        std::vector<uint8_t> inbound;
        TransferResult result=transport.Control(setup,inbound,1000);
        bool stall=ChatpadIsAcceptedActivationStall(index,result.status==TransferStatus::Ok,
            result.status==TransferStatus::Timeout,result.status==TransferStatus::Cancelled,
            result.status==TransferStatus::Stall,result.transferred,r.RawLength)!=0;
        // Source semantics: immutable ChatpadLiveTransferPolicy.c permits bounded
        // zero-byte rejection only for preambles0..2 and initial read probe3.
        // Native Error31 is not STALL evidence. Never extend this to strict4/5,
        // timeout/cancellation/device loss/access denial or partial transfers.
        const bool optionalProbe=(index<3 && r.RawLength==0) || (index==3 && r.RawLength==2);
        const bool probeRejected=policy_==ActivationPolicy::NativeProbeRejection && optionalProbe &&
            result.status==TransferStatus::Error && result.win32Error==31 && result.transferred==0 && inbound.empty();
        bool accepted=stall || probeRejected || (result.status==TransferStatus::Ok && result.transferred==r.RawLength &&
            (!(r.RawBmRequestType&0x80) || inbound.size()==r.ExpectedInboundDataLength));
        ActivationEvent event{index,setup,result,accepted,stall,optionalProbe,probeRejected};output.events.push_back(event);
        if(observe) observe(event);
        if(!accepted) return output;
        ++output.completedSteps;
        if(step.DelayAfterMilliseconds) delay(step.DelayAfterMilliseconds);
    }
    output.success=true;return output;
}
bool ChatpadMaintenance::Command(uint16_t value) {
    std::vector<uint8_t> input;
    last_=transport_.Control({0x41,0,value,2,0,{}},input,1000);
    if(last_.status!=TransferStatus::Ok || last_.transferred!=0) { active_=false;return false; }
    return true;
}
bool ChatpadMaintenance::Start(uint64_t nowMs) {
    if(started_) return false;
    started_=true;active_=true;due_=nowMs+1000;
    return Command(0x001f);
}
bool ChatpadMaintenance::Tick(uint64_t nowMs) {
    if(!active_) return false;
    if(nowMs<due_) return true;
    if(!Command(next_)) return false;
    next_=next_==0x001e?0x001f:0x001e;due_=nowMs+1000;return true;
}
bool ChatpadMaintenance::OnCompletePacket(size_t size) {
    if(!active_) return false;
    if(size!=5 || keyDataAttempted_) return true;
    keyDataAttempted_=true;return Command(0x001b);
}
BridgeSession::BridgeSession(IPhysicalTransport& physical,IVirtualXboxController& controller,IKeyboardOutput& keyboard)
    :physical_(physical),virtual_(controller),keyboard_(keyboard) {}
BridgeSession::~BridgeSession() { Shutdown(); }
bool BridgeSession::Start(const std::string& path) {
    if(running_ || opened_) return false;
    if(physical_.Open(path).status!=TransferStatus::Ok) return false;
    opened_=true;
    bool controller=false,chatpad=false;
    for(const auto& i:physical_.Interfaces()) for(const auto& ep:i.endpoints) {
        if(i.alternateSetting!=0 || ep.type!=3) continue;
        if(i.number==0 && ep.address==0x81)controller=true;
        if(i.number==2 && ep.address==0x84)chatpad=true;
    }
    if(!controller || !chatpad) { Shutdown();return false; }
    if(!virtual_.Create()) { Shutdown();return false; }
    created_=true;
    virtual_.SetRumbleCallback([this](uint16_t left,uint16_t right){
        RumbleCallback callback;
        {std::lock_guard<std::mutex> lock(rumbleMutex_);callback=physicalRumble_;}
        if(running_.load() && callback)callback(left,right);
    });
    running_=true;return true;
}
bool BridgeSession::SubmitController(const uint8_t* data,size_t size) {
    XboxState state;
    if(!running_ || !ParseController(data,size,state))return false;
    if(!virtual_.SubmitState(state)) { Shutdown();return false; }
    return true;
}
void BridgeSession::Shutdown() {
    if(!opened_ && !created_) return;
    running_=false;
    if(opened_)physical_.Cancel();
    keyboard_.ForceRelease();
    if(created_) { virtual_.SetRumbleCallback({});virtual_.Disconnect();created_=false; }
    if(opened_) { physical_.Close();opened_=false; }
}
}

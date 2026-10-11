#include "ControllerInputPump.h"
#include <utility>

namespace chatpad {
namespace {
bool SameState(const XboxState& left,const XboxState& right){
    return left.buttons==right.buttons&&left.leftTrigger==right.leftTrigger&&left.rightTrigger==right.rightTrigger&&
        left.lx==right.lx&&left.ly==right.ly&&left.rx==right.rx&&left.ry==right.ry;
}
}
ControllerInputPump::ControllerInputPump(IPhysicalTransport& transport,const XboxState& initial)
    :transport_(transport),latest_(initial) {}
ControllerInputPump::~ControllerInputPump(){Stop();}
bool ControllerInputPump::Start(){
    std::lock_guard<std::mutex> guard(mutex_);
    if(started_||failed_)return false;
    started_=true;lastSubmission_=std::chrono::steady_clock::now();
    try{thread_=std::thread(&ControllerInputPump::Run,this);}
    catch(...){started_=false;failed_=true;failureWin32_=8;return false;}
    return true;
}
bool ControllerInputPump::SetStateSink(StateSink sink){
    if(!sink)return false;
    std::lock_guard<std::mutex> guard(mutex_);
    if(!started_||failed_||sink_)return false;
    sink_=std::move(sink);
    if(!SubmitLocked(latest_)){failed_=true;stopping_=true;return false;}
    return true;
}
void ControllerInputPump::Stop(){
    stopping_=true;
    if(thread_.joinable())thread_.join();
}
bool ControllerInputPump::Failed()const{std::lock_guard<std::mutex> guard(mutex_);return failed_;}
uint32_t ControllerInputPump::FailureWin32()const{std::lock_guard<std::mutex> guard(mutex_);return failureWin32_;}
TransferStatus ControllerInputPump::FailureStatus()const{std::lock_guard<std::mutex> guard(mutex_);return failureStatus_;}
uint64_t ControllerInputPump::ReportCount()const{std::lock_guard<std::mutex> guard(mutex_);return reports_;}
uint64_t ControllerInputPump::SubmissionCount()const{std::lock_guard<std::mutex> guard(mutex_);return submissions_;}
ControllerInputPumpDiagnostics ControllerInputPump::Diagnostics()const{std::lock_guard<std::mutex> guard(mutex_);return diagnostics_;}
bool ControllerInputPump::SubmitLocked(const XboxState& state){
    if(!sink_)return true;
    if(!sink_(state)){failed_=true;return false;}
    ++submissions_;lastSubmission_=std::chrono::steady_clock::now();return true;
}
void ControllerInputPump::Run(){
    while(!stopping_){
        std::vector<uint8_t> packet;
        {std::lock_guard<std::mutex> guard(mutex_);++diagnostics_.readAttempts;}
        const auto result=transport_.Read(0,0x81,packet,200);
        if(result.status==TransferStatus::Cancelled&&stopping_)break;
        if(result.status==TransferStatus::Timeout){
            std::lock_guard<std::mutex> guard(mutex_);
            ++diagnostics_.timeoutCompletions;
            diagnostics_.lastTimeoutWin32=result.win32Error;
            if(result.win32Error==1460)++diagnostics_.timeout1460Completions;
            // A timeout is an empty interval on this interrupt endpoint, not
            // evidence that the device was removed or the pipe stalled. Keep
            // listening; only a non-timeout transfer failure ends the pump.
            if(sink_&&std::chrono::steady_clock::now()-lastSubmission_>=std::chrono::seconds(1)&&
                !SubmitLocked(latest_))stopping_=true;
            continue;
        }
        if(result.status!=TransferStatus::Ok){
            std::lock_guard<std::mutex> guard(mutex_);
            ++diagnostics_.transferFailures;
            diagnostics_.lastFailureStatus=result.status;
            diagnostics_.lastFailureWin32=result.win32Error;
            failed_=true;failureStatus_=result.status;failureWin32_=result.win32Error;break;
        }
        {
            std::lock_guard<std::mutex> guard(mutex_);
            ++diagnostics_.successfulReadCompletions;
        }
        XboxState state;
        const auto classification=ClassifyControllerPacket(packet.data(),packet.size(),state);
        std::lock_guard<std::mutex> guard(mutex_);
        if(classification==ControllerPacketClassification::NonControllerStatus){++diagnostics_.nonControllerStatusPackets;continue;}
        if(classification!=ControllerPacketClassification::ControllerReport){++diagnostics_.invalidPackets;continue;}
        if(!SameState(latest_,state))++diagnostics_.changingControllerReports;
        ++diagnostics_.controllerReports;
        ++reports_;latest_=state;
        if(sink_&&!SubmitLocked(latest_)){stopping_=true;break;}
    }
}
}

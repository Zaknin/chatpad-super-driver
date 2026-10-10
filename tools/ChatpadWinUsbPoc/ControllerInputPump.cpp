#include "ControllerInputPump.h"
#include <utility>

namespace chatpad {
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
bool ControllerInputPump::SubmitLocked(const XboxState& state){
    if(!sink_)return true;
    if(!sink_(state)){failed_=true;return false;}
    ++submissions_;lastSubmission_=std::chrono::steady_clock::now();return true;
}
void ControllerInputPump::Run(){
    while(!stopping_){
        std::vector<uint8_t> packet;
        const auto result=transport_.Read(0,0x81,packet,200);
        if(result.status==TransferStatus::Cancelled&&stopping_)break;
        if(result.status==TransferStatus::Timeout){
            std::lock_guard<std::mutex> guard(mutex_);
            if(sink_&&std::chrono::steady_clock::now()-lastSubmission_>=std::chrono::seconds(1)&&!SubmitLocked(latest_))stopping_=true;
            continue;
        }
        if(result.status!=TransferStatus::Ok){
            std::lock_guard<std::mutex> guard(mutex_);failed_=true;failureStatus_=result.status;failureWin32_=result.win32Error;break;
        }
        std::lock_guard<std::mutex> guard(mutex_);
        ++reports_;
        XboxState state;
        if(ParseController(packet.data(),packet.size(),state)){
            latest_=state;
            if(sink_&&!SubmitLocked(latest_)){stopping_=true;break;}
        }
    }
}
}

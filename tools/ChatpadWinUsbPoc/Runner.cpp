#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <Windows.h>
#include <Psapi.h>
#include "Runner.h"
#include "RunnerLifecycle.h"
#include "ControllerInputPump.h"
#include "WinUsbTransport.h"
#include "Topology.h"
#include "KeyboardOutput.h"
#include "VirtualBrokerController.h"
#include <algorithm>
#include <chrono>
#include <deque>
#include <fstream>
#include <iostream>
#include <mutex>
#include <thread>

namespace chatpad {
namespace {
using Clock=std::chrono::steady_clock;
class MonitorOutput final:public IKeyboardOutput {
public:bool Send(uint8_t,bool)override{return true;}bool ForceRelease()override{return true;}
};
struct Log {
    std::mutex mutex;
    std::filesystem::path directory,path;
    bool verbose{};
    explicit Log(bool detail):verbose(detail) {
        wchar_t* local=nullptr;size_t size=0;
        if(_wdupenv_s(&local,&size,L"LOCALAPPDATA")==0&&local){directory=local;free(local);}
        else directory=std::filesystem::temp_directory_path();
        directory/=L"ChatpadBridge";directory/=L"logs";
        std::error_code ec;std::filesystem::create_directories(directory,ec);
        path=directory/L"bridge.log";
        if(std::filesystem::exists(path,ec)&&std::filesystem::file_size(path,ec)>2*1024*1024){
            std::filesystem::remove(directory/L"bridge.log.1",ec);ec.clear();
            std::filesystem::rename(path,directory/L"bridge.log.1",ec);
        }
    }
    void Event(const std::string& value,bool detail=false) {
        if(detail&&!verbose)return;
        SYSTEMTIME now{};GetSystemTime(&now);char stamp[40]{};
        sprintf_s(stamp,"%04u-%02u-%02uT%02u:%02u:%02u.%03uZ",now.wYear,now.wMonth,now.wDay,now.wHour,now.wMinute,now.wSecond,now.wMilliseconds);
        std::lock_guard<std::mutex> guard(mutex);
        std::ofstream file(path,std::ios::app|std::ios::binary);
        if(file)file<<stamp<<" "<<value<<"\n";
        std::cout<<stamp<<" "<<value<<"\n";
    }
};
std::wstring Wide(const std::string& value) {
    int count=MultiByteToWideChar(CP_UTF8,MB_ERR_INVALID_CHARS,value.c_str(),-1,nullptr,0);
    if(count<=0)throw std::runtime_error("invalid UTF-8 instance identifier");
    std::wstring out(static_cast<size_t>(count),L'\0');
    MultiByteToWideChar(CP_UTF8,MB_ERR_INVALID_CHARS,value.c_str(),-1,out.data(),count);out.pop_back();return out;
}
std::string Hex(const std::vector<uint8_t>& bytes) {
    static const char digits[]="0123456789abcdef";std::string out;
    for(uint8_t value:bytes){out.push_back(digits[value>>4]);out.push_back(digits[value&15]);}
    return out;
}
void SleepBounded(const std::atomic<bool>& stop,unsigned milliseconds) {
    const auto end=Clock::now()+std::chrono::milliseconds(milliseconds);
    while(!stop.load()&&Clock::now()<end)std::this_thread::sleep_for(std::chrono::milliseconds(50));
}
uint64_t FileTicks(const FILETIME& time){return (uint64_t(time.dwHighDateTime)<<32)|time.dwLowDateTime;}
bool HasEndpoints(const DeviceInfo& device) {
    bool controller=false,chatpad=false;
    for(const auto& item:device.interfaces)for(const auto& ep:item.endpoints){
        if(item.alternateSetting==0&&ep.type==3&&item.number==0&&ep.address==0x81)controller=true;
        if(item.alternateSetting==0&&ep.type==3&&item.number==2&&ep.address==0x84)chatpad=true;
    }
    return controller&&chatpad;
}
const char* TransferStatusName(TransferStatus status) {
    switch(status) {
    case TransferStatus::Ok:return "Ok";
    case TransferStatus::Stall:return "Stall";
    case TransferStatus::Timeout:return "Timeout";
    case TransferStatus::Cancelled:return "Cancelled";
    case TransferStatus::AccessDenied:return "AccessDenied";
    case TransferStatus::DeviceNotPresent:return "DeviceNotPresent";
    case TransferStatus::Error:return "Error";
    }
    return "Unknown";
}
std::filesystem::path RuntimeLogDirectory() {
    wchar_t* local=nullptr;size_t size=0;std::filesystem::path directory;
    if(_wdupenv_s(&local,&size,L"LOCALAPPDATA")==0&&local){directory=local;free(local);}
    else directory=std::filesystem::temp_directory_path();
    return directory/L"ChatpadBridge"/L"logs";
}
void PrintRuntimeSnapshot() {
    const auto directory=RuntimeLogDirectory();
    HANDLE mutex=OpenMutexW(SYNCHRONIZE,FALSE,L"Local\\ChatpadBridge.Runner.v1");
    const bool active=mutex!=nullptr;if(mutex)CloseHandle(mutex);
    std::error_code ec;const bool marker=std::filesystem::exists(directory/L"session.active.json",ec);
    std::cout<<"runtime_process="<<(active?"ACTIVE":"STOPPED")<<" session_marker="<<(marker?"present":"absent")<<"\n";
    std::ifstream input(directory/L"bridge.log",std::ios::binary);if(!input)return;
    std::deque<std::string> events;std::string line;
    while(std::getline(input,line)){
        if(line.find("state=")!=std::string::npos||line.find("activation ")!=std::string::npos||
           line.find("keepalive")!=std::string::npos||line.find("Chatpad key-data")!=std::string::npos||
           line.find("chatpad_layer")!=std::string::npos||line.find("reconnect")!=std::string::npos||
           line.find("session ended")!=std::string::npos||line.find("unclean_previous_session")!=std::string::npos||
           line.find("failed")!=std::string::npos||line.find("BLOCKED")!=std::string::npos){
            events.push_back(line);if(events.size()>24)events.pop_front();
        }
    }
    std::cout<<"recent_runtime_events="<<events.size()<<"\n";
    for(const auto& event:events)std::cout<<event<<"\n";
}
void ActivationLog(const ActivationEvent& event,Log& log) {
    log.Event("activation stage="+std::to_string(event.step)+" win32="+std::to_string(event.result.win32Error)+
        " bytes="+std::to_string(event.result.transferred)+" disposition="+ActivationDisposition(event));
}
enum class InitialReadinessResult { Ready, Stopped, PhysicalTimeout, DeviceRemoved, Failed };
InitialReadinessResult WaitController(WinUsbTransport& usb,const std::atomic<bool>& stop,XboxState& state,Log& log) {
    constexpr uint64_t readinessWindowMs=5000;
    const auto started=GetTickCount64();ControllerReadiness readiness(started,readinessWindowMs);
    PhysicalReadinessTracker readHistory;uint32_t lastReadWin32{};
    while(!stop.load()){
        const auto now=GetTickCount64();const auto timeout=readiness.ReadTimeoutMs(now,500);
        if(timeout==0){
            const bool recoveryCandidate=readHistory.RecoveryCandidate(stop.load());
            log.Event("controller readiness timed out read_timeout_count="+std::to_string(readHistory.TimeoutCount())+
                " last_read_status="+(readHistory.TimeoutCount()?TransferStatusName(readHistory.LastStatus()):"n/a")+
                " last_read_win32="+(readHistory.TimeoutCount()?std::to_string(lastReadWin32):"n/a")+
                " physical_recovery_candidate="+(recoveryCandidate?"true":"false"));
            return recoveryCandidate?InitialReadinessResult::PhysicalTimeout:InitialReadinessResult::Failed;
        }
        std::vector<uint8_t> packet;auto result=usb.Read(0,0x81,packet,timeout);
        readHistory.Record(result.status);lastReadWin32=result.win32Error;
        const auto decision=readiness.Observe(GetTickCount64(),result,packet.data(),packet.size(),state);
        if(decision==ControllerReadinessDecision::Ready)return InitialReadinessResult::Ready;
        if(decision==ControllerReadinessDecision::ReadTimedOut)continue;
        if(decision==ControllerReadinessDecision::Waiting){
            if(result.status==TransferStatus::Ok&&ClassifyControllerPacket(packet.data(),packet.size(),state)==ControllerPacketClassification::NonControllerStatus)
            log.Event("controller readiness skipped non-controller packet bytes="+std::to_string(packet.size())+" hex="+Hex(packet),true);
            continue;
        }
        if(decision==ControllerReadinessDecision::TimedOut){
            const bool recoveryCandidate=readHistory.RecoveryCandidate(stop.load());
            log.Event("controller readiness timed out read_timeout_count="+std::to_string(readHistory.TimeoutCount())+
                " last_read_status="+(readHistory.TimeoutCount()?TransferStatusName(readHistory.LastStatus()):"n/a")+
                " last_read_win32="+(readHistory.TimeoutCount()?std::to_string(lastReadWin32):"n/a")+
                " physical_recovery_candidate="+(recoveryCandidate?"true":"false"));
            return recoveryCandidate?InitialReadinessResult::PhysicalTimeout:InitialReadinessResult::Failed;
        }
        if(decision==ControllerReadinessDecision::TransferFailed){
            log.Event("device open readiness failed status="+std::string(TransferStatusName(result.status))+" win32="+std::to_string(result.win32Error));
            return result.status==TransferStatus::DeviceNotPresent?InitialReadinessResult::DeviceRemoved:InitialReadinessResult::Failed;
        }
        log.Event("controller readiness invalid report bytes="+std::to_string(packet.size()),true);return InitialReadinessResult::Failed;
    }
    return InitialReadinessResult::Stopped;
}
struct SessionResult { bool lost{},backendFailure{},cleanupFailure{},rumbleRecoveryCompleted{},rumbleRecoveryFailure{},rumbleStopPending{},physicalRecoveryNeeded{},physicalDeviceRemovalObserved{},recoveryQualified{},resumeDetected{};unsigned controllerPackets{},chatpadPackets{},virtualSubmissions{};uint64_t elapsedMs{},resumeEpoch{}; };
SessionResult RunSession(WinUsbTransport& usb,VirtualBrokerController& broker,uint64_t sessionEpoch,const RunnerOptions& options,const std::atomic<bool>& appStop,RunnerLifecycle& lifecycle,Log& log,bool rumbleRecoveryPending) {
    const auto sessionStart=Clock::now();
    const auto sessionStartTick=GetTickCount64();
    SessionResult counts;std::atomic<bool> sessionStop{false};std::atomic<bool> physicalDeviceRemovalObserved{false};
    std::atomic<unsigned> chatpadReportCount{0};
    std::atomic<bool> physicalTransportTimeoutObserved{false};std::atomic<int> failure{0};
    XboxState initial{};
    const auto readinessResult=WaitController(usb,appStop,initial,log);
    if(broker.ResumeEpoch()>sessionEpoch){SessionResult result;result.resumeDetected=true;result.resumeEpoch=broker.ResumeEpoch();return result;}
    if(readinessResult!=InitialReadinessResult::Ready){
        SessionResult result;
        result.lost=readinessResult!=InitialReadinessResult::Stopped;
        result.physicalRecoveryNeeded=readinessResult==InitialReadinessResult::PhysicalTimeout&&!appStop.load();
        result.physicalDeviceRemovalObserved=readinessResult==InitialReadinessResult::DeviceRemoved;
        return result;
    }
    // Keep IF0/81 continuously polled while activation and the broker create
    // operation run. HIDMaestro startup can take seconds; pausing controller
    // reads here can leave the physical output pipe unable to complete writes.
    ControllerInputPump controllerPump(usb,initial);
    if(!controllerPump.Start()){log.Event("controller input pump start failed");return {true};}
    log.Event("controller input polling started before Chatpad activation");
    ActivationRunner activation(ActivationPolicy::NativeProbeRejection);
    auto delay=[&](uint32_t ms){SleepBounded(appStop,ms);};
    const auto activated=activation.Run(usb,delay,[&](const ActivationEvent& e){ActivationLog(e,log);});
    if(!activated.success){log.Event("Chatpad activation failed; session will reopen on reconnect");return {true};}
    if(!lifecycle.Activated())return {true};
    log.Event("state=RUNNING");
    ChatpadMaintenance maintenance(usb);
    if(!maintenance.Start(GetTickCount64())){
        const auto result=maintenance.LastResult();
        log.Event("initial keepalive failed win32="+std::to_string(result.win32Error));
        counts.lost=true;
        counts.physicalRecoveryNeeded=result.status==TransferStatus::Timeout&&!appStop.load();
        return counts;
    }
    log.Event("Chatpad activated; keepalive started; key-data command is gated on first complete five-byte report");
    if(rumbleRecoveryPending){
        const auto initialRumbleStop=usb.Write(0,0x01,BuildRumble(0,0),1000);
        if(initialRumbleStop.status!=TransferStatus::Ok||initialRumbleStop.transferred!=8){
            counts.rumbleStopPending=true;
            if(initialRumbleStop.status==TransferStatus::DeviceNotPresent){
                log.Event("unclean-session zero-rumble recovery deferred device_removed win32="+std::to_string(initialRumbleStop.win32Error));
                counts.lost=true;physicalDeviceRemovalObserved=true;
            }else{
                if(initialRumbleStop.status==TransferStatus::Timeout)physicalTransportTimeoutObserved=true;
                log.Event("unclean-session zero-rumble recovery failed win32="+std::to_string(initialRumbleStop.win32Error));
                counts.rumbleRecoveryFailure=true;
            }
            counts.physicalRecoveryNeeded=physicalTransportTimeoutObserved.load()&&!appStop.load();
            return counts;
        }
        counts.rumbleRecoveryCompleted=true;
        log.Event("unclean-session zero-rumble recovery succeeded");
    }else{
        log.Event("startup zero-rumble recovery skipped previous_session_clean=true");
    }

    bool brokerCreated=false;
    if(options.virtualController){
        if(!broker.Create()){
            log.Event("HIDMaestro broker create failed: "+broker.LastError());
            counts.backendFailure=true;return counts;
        }
        brokerCreated=true;
        if(!controllerPump.SetStateSink([&](const XboxState& state){
            if(!broker.SubmitState(state)){
                log.Event("virtual state submit failed: "+broker.LastError());failure=3;return false;
            }
            return true;
        })){
            log.Event("initial neutral/controller submission failed: "+broker.LastError());
            (void)broker.Destroy();return {true};
        }
        log.Event("virtual Xbox created and initial controller state submitted");
    }
    MonitorOutput monitor;
    SendInputKeyboardOutput keyboardOutput;
    IKeyboardOutput& selectedOutput=options.keyboard?static_cast<IKeyboardOutput&>(keyboardOutput):static_cast<IKeyboardOutput&>(monitor);
    KeyboardMapper mapper(selectedOutput);
    std::mutex motorMutex;bool motorAvailable=true;bool rumbleOutputActive=false;
    if(brokerCreated)broker.SetRumbleCallback([&](uint16_t left,uint16_t right){
        std::lock_guard<std::mutex> guard(motorMutex);
        if(!motorAvailable||sessionStop.load())return;
        const auto result=usb.Write(0,0x01,BuildRumble(left,right),1000);
        if(result.status!=TransferStatus::Ok||result.transferred!=8){
            if(result.status==TransferStatus::Timeout)physicalTransportTimeoutObserved=true;
            log.Event("rumble callback output failed left="+std::to_string(left)+" right="+std::to_string(right)+" win32="+std::to_string(result.win32Error)+" bytes="+std::to_string(result.transferred));
            failure=4;
            return;
        }
        const bool active=left!=0||right!=0;
        if(active!=rumbleOutputActive){
            log.Event("rumble callback output active="+std::string(active?"true":"false")+" left="+std::to_string(left)+" right="+std::to_string(right)+" bytes="+std::to_string(result.transferred));
            rumbleOutputActive=active;
        }
    });

    int lastModifiers=-1;
    bool recoveryQualified=false;
    auto readChatpadLoop=[&]{
        try {
            uint64_t nextMaintenance=GetTickCount64();
            while(!appStop.load()&&!sessionStop.load()&&failure.load()==0){
                if(GetTickCount64()>=nextMaintenance){
                    if(!maintenance.Tick(GetTickCount64())){
                        if(maintenance.LastResult().status==TransferStatus::Timeout)physicalTransportTimeoutObserved=true;
                        log.Event("Chatpad keepalive failed win32="+std::to_string(maintenance.LastResult().win32Error));failure=2;break;
                    }
                    nextMaintenance=GetTickCount64()+200;
                }
                std::vector<uint8_t> packet;auto result=usb.Read(2,0x84,packet,200);
                if(result.status==TransferStatus::Timeout)continue;
                if(result.status==TransferStatus::Cancelled&&(sessionStop.load()||appStop.load()))break;
                if(result.status!=TransferStatus::Ok){
                    if(result.status==TransferStatus::DeviceNotPresent)physicalDeviceRemovalObserved=true;
                    log.Event("Chatpad read lost win32="+std::to_string(result.win32Error));failure=1;break;
                }
                ++chatpadReportCount;
                if(!maintenance.KeyDataAttempted()&&packet.size()==5){
                    if(!maintenance.OnCompletePacket(packet.size())){log.Event("strict key-data enable failed win32="+std::to_string(maintenance.LastResult().win32Error));failure=2;break;}
                    log.Event("Chatpad key-data enable 0x001B succeeded");
                }
                const bool mapped=mapper.Process(packet.data(),packet.size());
                if(mapped){
                    const auto modifiers=static_cast<int>(mapper.LastPacket().RawModifiers);
                    if(options.verbose||modifiers!=lastModifiers){
                        const auto& report=mapper.LastReport();
                        log.Event("chatpad_layer modifiers="+std::to_string(modifiers)+" hid="+
                            std::to_string(report.Bytes[2])+","+std::to_string(report.Bytes[3])+","+
                            std::to_string(report.Bytes[4])+","+std::to_string(report.Bytes[5])+","+
                            std::to_string(report.Bytes[6])+","+std::to_string(report.Bytes[7]),options.verbose&&modifiers==lastModifiers);
                    }
                    lastModifiers=modifiers;
                }else if(mapper.LastOutputFailed()){log.Event("keyboard output failed; session stopping after forced release");failure=5;break;}
                }
        }catch(const std::exception& ex){log.Event(std::string("reader exception: ")+ex.what());failure=6;}
    };
    std::thread chatpadThread;
    chatpadThread=std::thread(readChatpadLoop);
    while(!appStop.load()&&failure.load()==0&&!controllerPump.Failed()&&broker.ResumeEpoch()<=sessionEpoch){
        if(!recoveryQualified&&GetTickCount64()-sessionStartTick>=10000&&controllerPump.ReportCount()>=10&&
            chatpadReportCount.load()>0&&!physicalTransportTimeoutObserved.load())recoveryQualified=true;
        std::this_thread::sleep_for(std::chrono::milliseconds(50));
    }
    if(broker.ResumeEpoch()>sessionEpoch){counts.resumeDetected=true;counts.resumeEpoch=broker.ResumeEpoch();log.Event("state=RESUME_DETECTED epoch="+std::to_string(counts.resumeEpoch));}
    if(controllerPump.Failed()&&failure.load()==0){
        log.Event("controller read lost win32="+std::to_string(controllerPump.FailureWin32()));failure=1;
    }
    sessionStop=true;maintenance.Stop();
    controllerPump.Stop();
    if(controllerPump.FailureStatus()==TransferStatus::DeviceNotPresent)physicalDeviceRemovalObserved=true;
    const auto controllerPumpReports=controllerPump.ReportCount();
    const auto controllerPumpDiagnostics=controllerPump.Diagnostics();
    counts.controllerPackets=static_cast<unsigned>(TotalControllerReports(1,controllerPumpReports));
    counts.virtualSubmissions=static_cast<unsigned>(controllerPump.SubmissionCount());
    TransferResult motorStop{};
    {
        std::lock_guard<std::mutex> guard(motorMutex);
        motorAvailable=false;
        motorStop=usb.Write(0,0x01,BuildRumble(0,0),1000);
    }
    if(motorStop.status==TransferStatus::Timeout)physicalTransportTimeoutObserved=true;
    if(brokerCreated)broker.SetRumbleCallback({});
    usb.Cancel();
    if(chatpadThread.joinable())chatpadThread.join();
    counts.chatpadPackets=chatpadReportCount.load();
    const bool keysReleased=mapper.ForceRelease();if(!keysReleased)log.Event("keyboard forced release failed");
    bool virtualNeutral=true,virtualReleased=true;
    if(brokerCreated){
        virtualReleased=broker.Destroy();
        // The broker's destroy operation submits neutral state before releasing
        // the HIDMaestro backend; it is ordered with lifecycle control messages.
        virtualNeutral=virtualReleased;
        const auto brokerError=broker.LastError();
        if(!virtualReleased)log.Event("virtual broker cleanup failed: "+brokerError);
    }
    // WinUSB may already be gone; still send one bounded zero command while the
    // interface remains available. Device removal defers the zero to reconnect.
    const bool motorsStopped=motorStop.status==TransferStatus::Ok&&motorStop.transferred==8;
    const auto cleanupDisposition=ClassifySessionCleanup(keysReleased,virtualNeutral,virtualReleased,motorStop,
        physicalDeviceRemovalObserved.load(),physicalTransportTimeoutObserved.load());
    counts.cleanupFailure=cleanupDisposition==SessionCleanupDisposition::Failed;
    counts.rumbleStopPending=!motorsStopped;
    counts.physicalDeviceRemovalObserved=physicalDeviceRemovalObserved.load();
    counts.physicalRecoveryNeeded=physicalTransportTimeoutObserved.load()&&!physicalDeviceRemovalObserved.load()&&
        !counts.cleanupFailure&&!counts.backendFailure&&!appStop.load();
    counts.recoveryQualified=recoveryQualified;
    if(!virtualNeutral)log.Event("virtual neutral cleanup failed");
    if(cleanupDisposition==SessionCleanupDisposition::DeviceRemoved)
        log.Event("zero-rumble cleanup deferred device_removed win32="+std::to_string(motorStop.win32Error));
    else if(cleanupDisposition==SessionCleanupDisposition::ReconnectAfterTransportTimeout)
        log.Event("zero-rumble cleanup deferred transport_timeout win32="+std::to_string(motorStop.win32Error));
    else if(!motorsStopped)log.Event("zero-rumble cleanup failed win32="+std::to_string(motorStop.win32Error));
    log.Event(std::string("session cleanup keysReleased=")+(keysReleased?"true":"false")+
        " virtualNeutral="+(virtualNeutral?"true":"false")+" virtualReleased="+(virtualReleased?"true":"false")+
        " motorsStopped="+(motorsStopped?"true":"false"));
    if(counts.cleanupFailure)counts.backendFailure=true;
    counts.lost=failure.load()!=0;
    counts.elapsedMs=static_cast<uint64_t>(std::chrono::duration_cast<std::chrono::milliseconds>(Clock::now()-sessionStart).count());
    const auto seconds=(std::max)(0.001,counts.elapsedMs/1000.0);
    log.Event("session ended controllerReports="+std::to_string(counts.controllerPackets)+
        " readinessControllerReports=1 controllerPumpReports="+std::to_string(controllerPumpReports)+" chatpadReports="+
        std::to_string(counts.chatpadPackets)+" virtualSubmissions="+std::to_string(counts.virtualSubmissions)+
        " controllerRateHz="+std::to_string(counts.controllerPackets/seconds)+" virtualRateHz="+
        std::to_string(counts.virtualSubmissions/seconds)+" elapsedMs="+std::to_string(counts.elapsedMs)+
        " pumpReadAttempts="+std::to_string(controllerPumpDiagnostics.readAttempts)+
        " pumpReadSuccesses="+std::to_string(controllerPumpDiagnostics.successfulReadCompletions)+
        " pumpChangingReports="+std::to_string(controllerPumpDiagnostics.changingControllerReports)+
        " pumpStatusPackets="+std::to_string(controllerPumpDiagnostics.nonControllerStatusPackets)+
        " pumpInvalidPackets="+std::to_string(controllerPumpDiagnostics.invalidPackets)+
        " pumpTimeouts="+std::to_string(controllerPumpDiagnostics.timeoutCompletions)+
        " pumpTimeout1460="+std::to_string(controllerPumpDiagnostics.timeout1460Completions)+
        " pumpLastTimeoutWin32="+std::to_string(controllerPumpDiagnostics.lastTimeoutWin32)+
        " pumpTransferFailures="+std::to_string(controllerPumpDiagnostics.transferFailures)+
        " pumpLastFailureStatus="+(controllerPumpDiagnostics.transferFailures?TransferStatusName(controllerPumpDiagnostics.lastFailureStatus):"none")+
        " pumpLastFailureWin32="+(controllerPumpDiagnostics.transferFailures?std::to_string(controllerPumpDiagnostics.lastFailureWin32):"n/a"));
    return counts;
}
int Inspect(const std::string& command,const RunnerOptions& options) {
    WinUsbTransport transport;auto devices=transport.Enumerate();
    if(!options.instanceId.empty())devices.erase(std::remove_if(devices.begin(),devices.end(),[&](const auto& d){return d.instanceId!=options.instanceId;}),devices.end());
    std::cout<<"mode="<<command<<" target_count="<<devices.size()<<" service=WinUSB expected=true\n";
    PrintRuntimeSnapshot();
    if(devices.empty()){std::cout<<"state=WAITING_FOR_DEVICE detail="<<transport.Error()<<"\n";return 3;}
    if(devices.size()!=1){std::cout<<"state=BLOCKED reason=ambiguous_target\n";return 4;}
    const auto& device=devices.front();
    std::cout<<"state=DEVICE_PRESENT instance="<<device.instanceId<<" vid=045E pid=028E\n";
    if(command=="status")return 0;
    const auto opened=transport.Open(device.path);
    if(opened.status!=TransferStatus::Ok){std::cout<<"state=OPEN_FAILED win32="<<opened.win32Error<<" detail="<<transport.Error()<<"\n";return 5;}
    const auto json=TopologyJson(transport.Device(),transport.RawConfiguration(),"live WinUSB topology; no driver mutation");
    std::cout<<json<<"\n";
    if(command=="diagnostics")return 0;
    XboxState state{};std::vector<uint8_t> packet;constexpr uint64_t readinessWindowMs=5000;
    const auto started=GetTickCount64();ControllerReadiness readiness(started,readinessWindowMs);
    size_t skippedStatuses{},readTimeoutCount{};uint32_t lastReadTimeoutWin32{};
    for(;;){
        const auto now=GetTickCount64();const auto timeout=readiness.ReadTimeoutMs(now,500);
        if(timeout==0){std::cout<<"probe=FAILED reason=readiness_timeout overall_timeout_ms="<<readinessWindowMs
            <<" skipped_status_packets="<<skippedStatuses<<" read_timeout_count="<<readTimeoutCount
            <<" last_read_win32="<<(readTimeoutCount?std::to_string(lastReadTimeoutWin32):"n/a")<<"\n";return 6;}
        const auto read=transport.Read(0,0x81,packet,timeout);
        const auto decision=readiness.Observe(GetTickCount64(),read,packet.data(),packet.size(),state);
        if(decision==ControllerReadinessDecision::Ready){
            std::cout<<"probe=PASS controller_report_bytes="<<packet.size()<<" report_hex="<<Hex(packet)
                <<" skipped_status_packets="<<skippedStatuses<<"\n";return 0;
        }
        if(decision==ControllerReadinessDecision::ReadTimedOut){++readTimeoutCount;lastReadTimeoutWin32=read.win32Error;continue;}
        if(decision==ControllerReadinessDecision::Waiting){
            if(read.status==TransferStatus::Ok&&ClassifyControllerPacket(packet.data(),packet.size(),state)==ControllerPacketClassification::NonControllerStatus){
                ++skippedStatuses;std::cout<<"probe=non_controller_packet skipped=true bytes="<<packet.size()<<" report_hex="<<Hex(packet)<<"\n";
            }
            continue;
        }
        if(decision==ControllerReadinessDecision::TimedOut){std::cout<<"probe=FAILED reason=readiness_timeout overall_timeout_ms="<<readinessWindowMs
            <<" skipped_status_packets="<<skippedStatuses<<" read_timeout_count="<<readTimeoutCount
            <<" last_read_win32="<<(readTimeoutCount?std::to_string(lastReadTimeoutWin32):"n/a")<<"\n";return 6;}
        if(decision==ControllerReadinessDecision::TransferFailed){
            std::cout<<"probe=FAILED reason=transfer status="<<TransferStatusName(read.status)
                <<" controller_win32="<<read.win32Error<<" transferred_bytes="<<read.transferred
                <<" packet_bytes="<<packet.size()<<" skipped_status_packets="<<skippedStatuses<<"\n";return 6;
        }
        std::cout<<"probe=FAILED reason=invalid_controller_report transferred_bytes="<<read.transferred
            <<" packet_bytes="<<packet.size()<<" report_hex="<<PacketHex(packet.data(),packet.size());
        if(packet.size()>=1)std::cout<<" type="<<static_cast<unsigned>(packet[0]);
        else std::cout<<" type=n/a";
        if(packet.size()>=2)std::cout<<" declared_length="<<static_cast<unsigned>(packet[1]);
        else std::cout<<" declared_length=n/a";
        if(packet.size()>=4){const unsigned buttonBits=unsigned(packet[2])|(unsigned(packet[3])<<8);std::cout<<" button_bits="<<buttonBits;}
        else std::cout<<" button_bits=n/a";
        std::cout<<" skipped_status_packets="<<skippedStatuses<<"\n";return 6;
    }
}
}

int RunUserModeBridge(const std::string& command,const RunnerOptions& options,std::atomic<bool>& stop) {
    Log log(options.verbose);
    if(command!="run")return Inspect(command,options);
    SetLastError(ERROR_SUCCESS);
    HANDLE processMutex=CreateMutexW(nullptr,FALSE,L"Local\\ChatpadBridge.Runner.v1");
    if(!processMutex){log.Event("single_instance_mutex_failed win32="+std::to_string(GetLastError()));return 2;}
    if(GetLastError()==ERROR_ALREADY_EXISTS){CloseHandle(processMutex);log.Event("BLOCKED: another ChatpadBridge run session is already active");return 5;}
    struct MutexCleanup {HANDLE handle;~MutexCleanup(){if(handle)CloseHandle(handle);}} mutexCleanup{processMutex};
    HANDLE stopEvent=CreateEventW(nullptr,TRUE,FALSE,L"Local\\ChatpadBridge.Stop.v1");
    if(!stopEvent){log.Event("runner stop event creation failed win32="+std::to_string(GetLastError()));return 2;}
    std::thread stopWatcher([&stop,stopEvent]{if(WaitForSingleObject(stopEvent,INFINITE)==WAIT_OBJECT_0)stop=true;});
    struct StopWatcherCleanup {HANDLE event;std::thread& thread;~StopWatcherCleanup(){SetEvent(event);if(thread.joinable())thread.join();CloseHandle(event);}} stopWatcherCleanup{stopEvent,stopWatcher};
    log.Event("application_start version=1.0.0 mode=run elevation=not_required_by_runner session=foreground");
    const auto marker=log.directory/L"session.active.json";std::error_code markerError;
    const bool uncleanPreviousSession=std::filesystem::exists(marker,markerError);
    if(markerError){log.Event("BLOCKED: process-lifecycle marker query failed: "+markerError.message());return 8;}
    if(uncleanPreviousSession){
        SendInputKeyboardOutput recovery;
        const bool released=recovery.ReleaseAbandonedKeys();
        log.Event(std::string("unclean_previous_session=true stale_keyboard_release=")+(released?"PASS":"FAILED"));
        if(!released)return 7;
    }else log.Event("unclean_previous_session=false");
    {
        std::ofstream state(marker,std::ios::binary|std::ios::trunc);
        state<<"{\"pid\":"<<GetCurrentProcessId()<<",\"startedUtc\":true}\n";
        if(!state){log.Event("BLOCKED: could not create process-lifecycle marker");return 8;}
    }
    struct MarkerCleanup {std::filesystem::path path;bool preserve{};~MarkerCleanup(){if(!preserve){std::error_code ec;std::filesystem::remove(path,ec);}}} markerCleanup{marker};
    FILETIME startCreate{},startExit{},startKernel{},startUser{};GetProcessTimes(GetCurrentProcess(),&startCreate,&startExit,&startKernel,&startUser);
    const auto processStart=Clock::now();
    RunnerLifecycle lifecycle;unsigned backoff=250;
    VirtualBrokerController broker;
    RecoveryEpochGate recoveryEpoch;
    bool fatalBackendFailure=false;
    bool wakePending=false,waitForNextEpoch=false;
    bool rumbleRecoveryPending=ShouldSendStartupZeroRumbleRecovery(uncleanPreviousSession);
    while(!stop.load()){
        if(!broker.ConnectForNotifications()){
            log.Event("state=WAITING_FOR_BROKER detail="+broker.LastError());
            SleepBounded(stop,5000);continue;
        }
        const uint64_t brokerEpoch=broker.ResumeEpoch();
        if(recoveryEpoch.ObserveEpoch(brokerEpoch)){
            wakePending=true;waitForNextEpoch=false;rumbleRecoveryPending=true;backoff=250;
            log.Event("state=RESUME_EPOCH epoch="+std::to_string(brokerEpoch));
            if(lifecycle.State()==RunnerState::WaitingForRecovery)(void)lifecycle.ResumeRecovery();
        }
        if(waitForNextEpoch){
            (void)lifecycle.WaitForRecovery();
            log.Event("state=WAITING_FOR_RECOVERY epoch="+std::to_string(recoveryEpoch.CurrentEpoch())+
                " physical_handle=closed virtual_controller=absent");
            uint64_t observed{};
            if(broker.WaitForResume(recoveryEpoch.CurrentEpoch(),1000,observed)){
                if(recoveryEpoch.ObserveEpoch(observed)){
                    wakePending=true;waitForNextEpoch=false;rumbleRecoveryPending=true;backoff=250;
                    (void)lifecycle.ResumeRecovery();
                    log.Event("state=RESUME_EPOCH epoch="+std::to_string(observed));
                }
            }
            continue;
        }
        WinUsbTransport transport;auto devices=transport.Enumerate();
        if(!options.instanceId.empty())devices.erase(std::remove_if(devices.begin(),devices.end(),[&](const auto& d){return d.instanceId!=options.instanceId;}),devices.end());
        if(devices.size()!=1){
            if(devices.size()>1)log.Event("state=WAITING_FOR_DEVICE reason=ambiguous_target count="+std::to_string(devices.size()));
            else log.Event("state=WAITING_FOR_DEVICE detail="+transport.Error());
            SleepBounded(stop,backoff);backoff=(std::min)(backoff*2,5000u);continue;
        }
        if(!lifecycle.DeviceFound())break;
        log.Event("state=OPENING instance="+devices[0].instanceId);
        const auto opened=transport.Open(devices[0].path);
        if(opened.status!=TransferStatus::Ok||!HasEndpoints(transport.Device())){
            log.Event("open_or_topology_failed win32="+std::to_string(opened.win32Error)+" detail="+transport.Error());
            transport.Close();lifecycle.DeviceLost();lifecycle.BeginReconnect();SleepBounded(stop,backoff);lifecycle.Retry();backoff=(std::min)(backoff*2,5000u);continue;
        }
        backoff=250;lifecycle.Opened();log.Event("WinUSB open PASS interface_topology=qualified");
        log.Event("state=ACTIVATING_CHATPAD");
        const uint64_t sessionEpoch=broker.ResumeEpoch();
        const auto session=RunSession(transport,broker,sessionEpoch,options,stop,lifecycle,log,rumbleRecoveryPending);
        transport.Close();
        if(session.resumeDetected){
            if(recoveryEpoch.ObserveEpoch(session.resumeEpoch)){
                wakePending=true;waitForNextEpoch=false;rumbleRecoveryPending=true;backoff=250;
                log.Event("state=RESUME_EPOCH epoch="+std::to_string(session.resumeEpoch));
            }
            if(lifecycle.DeviceLost())log.Event("state=DEVICE_LOST reconnect_count="+std::to_string(lifecycle.ReconnectCount()));
            (void)lifecycle.BeginReconnect();(void)lifecycle.Retry();
            log.Event("state=RECONNECTING reason=resume backoff_ms=0");
            continue;
        }
        if(session.recoveryQualified){wakePending=false;waitForNextEpoch=false;log.Event("resume recovery qualified with changing controller reports");}
        const auto physicalRecovery=PlanPhysicalRecovery(session.physicalRecoveryNeeded,
            session.physicalDeviceRemovalObserved,session.cleanupFailure,session.backendFailure,stop.load(),recoveryEpoch.RecoveryAttempted());
        if(physicalRecovery==PhysicalRecoveryAction::WaitForRecovery){
            waitForNextEpoch=true;
            log.Event("state=PHYSICAL_RECOVERY_CIRCUIT_OPEN; waiting for a new broker resume epoch");
            continue;
        }
        if(physicalRecovery==PhysicalRecoveryAction::RestartExactTarget){
            recoveryEpoch.MarkRecoveryAttempted();
            rumbleRecoveryPending=true;
            if(!broker.RecoverPhysicalDevice()){
                waitForNextEpoch=true;
                log.Event("state=PHYSICAL_RECOVERY_FAILED; quiet wait for next resume epoch: "+broker.LastError());
                continue;
            }
            log.Event("physical recovery exact USB 045E:028E WinUSB target restarted by broker");
            if(lifecycle.DeviceLost())log.Event("state=DEVICE_LOST reconnect_count="+std::to_string(lifecycle.ReconnectCount()));
            lifecycle.BeginReconnect();log.Event("state=RECONNECTING physical_recovery=true backoff_ms="+std::to_string(backoff));
            SleepBounded(stop,backoff);lifecycle.Retry();backoff=(std::min)(backoff*2,5000u);
            continue;
        }
        if(wakePending&&!session.recoveryQualified&&!session.cleanupFailure&&!session.backendFailure&&!stop.load()){
            waitForNextEpoch=true;
            log.Event("state=WAITING_FOR_RECOVERY; bounded post-resume readiness did not produce changing controller reports");
            continue;
        }
        if(session.rumbleRecoveryFailure){
            markerCleanup.preserve=true;fatalBackendFailure=true;
            log.Event("state=PHYSICAL_OUTPUT_RECOVERY_FAILED; stopping without retrying the zero-rumble write");
            break;
        }
        if(session.rumbleRecoveryCompleted)rumbleRecoveryPending=false;
        if(session.rumbleStopPending)rumbleRecoveryPending=true;
        if(session.cleanupFailure){
            lifecycle.BackendFailed();fatalBackendFailure=true;
            log.Event("state=CLEANUP_FAILED; stopping this run without reopening the physical controller");
            break;
        }
        if(session.backendFailure){
            lifecycle.BackendFailed();fatalBackendFailure=true;
            log.Event("state=VIRTUAL_BACKEND_FAILED; stopping this run without reopening the physical controller");
            break;
        }
        if(stop.load())break;
        if(session.lost){lifecycle.DeviceLost();log.Event("state=DEVICE_LOST reconnect_count="+std::to_string(lifecycle.ReconnectCount()));}
        else {lifecycle.DeviceLost();log.Event("session ended unexpectedly; reopening physical target");}
        lifecycle.BeginReconnect();log.Event("state=RECONNECTING backoff_ms="+std::to_string(backoff));
        SleepBounded(stop,backoff);lifecycle.Retry();backoff=(std::min)(backoff*2,5000u);
    }
    if(rumbleRecoveryPending)markerCleanup.preserve=true;
    broker.Disconnect();
    lifecycle.Stop();
    PROCESS_MEMORY_COUNTERS_EX memory{};memory.cb=sizeof(memory);GetProcessMemoryInfo(GetCurrentProcess(),reinterpret_cast<PROCESS_MEMORY_COUNTERS*>(&memory),sizeof(memory));
    FILETIME endCreate{},endExit{},endKernel{},endUser{};GetProcessTimes(GetCurrentProcess(),&endCreate,&endExit,&endKernel,&endUser);
    const auto elapsedMs=(std::max)(uint64_t(1),static_cast<uint64_t>(std::chrono::duration_cast<std::chrono::milliseconds>(Clock::now()-processStart).count()));
    const auto cpuMs=(FileTicks(endKernel)-FileTicks(startKernel)+FileTicks(endUser)-FileTicks(startUser))/10000;
    SYSTEM_INFO systemInfo{};GetSystemInfo(&systemInfo);const auto cores=(std::max<uint32_t>)(1,systemInfo.dwNumberOfProcessors);
    const auto cpuPercent=100.0*cpuMs/(elapsedMs*cores);
    log.Event("state=STOPPING clean_shutdown="+std::string(fatalBackendFailure?"false":"true")+" reconnect_count="+std::to_string(lifecycle.ReconnectCount())+
        " process_cpu_percent="+std::to_string(cpuPercent)+" working_set_bytes="+std::to_string(memory.WorkingSetSize)+
        " measurement_scope=runner_process_only");
    return fatalBackendFailure?12:0;
}
}

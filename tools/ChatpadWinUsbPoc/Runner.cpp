#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <Windows.h>
#include <Psapi.h>
#include "Runner.h"
#include "RunnerLifecycle.h"
#include "WinUsbTransport.h"
#include "Topology.h"
#include "KeyboardOutput.h"
#include "VirtualHelper.h"
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
bool WaitController(WinUsbTransport& usb,const std::atomic<bool>& stop,XboxState& state,Log& log) {
    const auto deadline=Clock::now()+std::chrono::seconds(5);
    while(!stop.load()&&Clock::now()<deadline){
        std::vector<uint8_t> packet;auto result=usb.Read(0,0x81,packet,500);
        if(result.status==TransferStatus::Timeout)continue;
        if(result.status!=TransferStatus::Ok){log.Event("device open readiness failed win32="+std::to_string(result.win32Error));return false;}
        if(ParseController(packet.data(),packet.size(),state))return true;
        log.Event("controller readiness packet rejected",true);
    }
    return false;
}
struct SessionResult { bool lost{},backendFailure{},cleanupFailure{};unsigned controllerPackets{},chatpadPackets{},virtualSubmissions{};uint64_t elapsedMs{}; };
SessionResult RunSession(WinUsbTransport& usb,const RunnerOptions& options,const std::atomic<bool>& appStop,RunnerLifecycle& lifecycle,Log& log) {
    const auto sessionStart=Clock::now();
    SessionResult counts;std::atomic<bool> sessionStop{false};std::atomic<int> failure{0};
    XboxState initial{};
    if(!WaitController(usb,appStop,initial,log))return {true};
    ActivationRunner activation(ActivationPolicy::NativeProbeRejection);
    auto delay=[&](uint32_t ms){SleepBounded(appStop,ms);};
    const auto activated=activation.Run(usb,delay,[&](const ActivationEvent& e){ActivationLog(e,log);});
    if(!activated.success){log.Event("Chatpad activation failed; session will reopen on reconnect");return {true};}
    if(!lifecycle.Activated())return {true};
    log.Event("state=RUNNING");
    ChatpadMaintenance maintenance(usb);
    if(!maintenance.Start(GetTickCount64())){log.Event("initial keepalive failed win32="+std::to_string(maintenance.LastResult().win32Error));return {true};}
    log.Event("Chatpad activated; keepalive started; key-data command is gated on first complete five-byte report");
    const auto initialRumbleStop=usb.Write(0,0x01,BuildRumble(0,0),1000);
    if(initialRumbleStop.status!=TransferStatus::Ok||initialRumbleStop.transferred!=8){
        log.Event("initial zero-rumble command failed win32="+std::to_string(initialRumbleStop.win32Error));return {true};
    }

    HelperOptions helper;helper.executable=options.helper.wstring();helper.backend="hidmaestro";helper.allowLiveVirtual=true;helper.durationMs=604800000;
    std::unique_ptr<VirtualHelperController> virtualController;
    if(options.virtualController){
        virtualController=std::make_unique<VirtualHelperController>(helper);
        if(!virtualController->Create()){
            log.Event("HIDMaestro create failed: "+virtualController->LastError());
            counts.backendFailure=true;return counts;
        }
        if(!virtualController->SubmitState(initial)){log.Event("initial neutral/controller submission failed: "+virtualController->LastError());virtualController->Disconnect();return {true};}
        log.Event("virtual Xbox created and initial controller state submitted");
    }
    MonitorOutput monitor;
    SendInputKeyboardOutput keyboardOutput;
    IKeyboardOutput& selectedOutput=options.keyboard?static_cast<IKeyboardOutput&>(keyboardOutput):static_cast<IKeyboardOutput&>(monitor);
    KeyboardMapper mapper(selectedOutput);
    std::mutex motorMutex;bool motorAvailable=true;
    if(virtualController)virtualController->SetRumbleCallback([&](uint16_t left,uint16_t right){
        std::lock_guard<std::mutex> guard(motorMutex);
        if(!motorAvailable||sessionStop.load())return;
        const auto result=usb.Write(0,0x01,BuildRumble(left,right),1000);
        if(result.status!=TransferStatus::Ok||result.transferred!=8){log.Event("rumble write failed win32="+std::to_string(result.win32Error));failure=4;}
    });

    int lastModifiers=-1;
    auto readLoop=[&](bool controller){
        try {
            uint64_t nextMaintenance=GetTickCount64(),lastSubmit=GetTickCount64();XboxState last=initial;
            while(!appStop.load()&&!sessionStop.load()&&failure.load()==0){
                if(!controller&&GetTickCount64()>=nextMaintenance){
                    if(!maintenance.Tick(GetTickCount64())){log.Event("Chatpad keepalive failed win32="+std::to_string(maintenance.LastResult().win32Error));failure=2;break;}
                    nextMaintenance=GetTickCount64()+200;
                }
                std::vector<uint8_t> packet;auto result=usb.Read(controller?0:2,controller?0x81:0x84,packet,200);
                if(result.status==TransferStatus::Timeout){
                    if(controller&&virtualController&&GetTickCount64()-lastSubmit>=1000){
                        if(!virtualController->SubmitState(last)){log.Event("virtual keepalive submission failed: "+virtualController->LastError());failure=3;break;}
                        ++counts.virtualSubmissions;lastSubmit=GetTickCount64();
                    }
                    continue;
                }
                if(result.status==TransferStatus::Cancelled&&(sessionStop.load()||appStop.load()))break;
                if(result.status!=TransferStatus::Ok){log.Event(std::string(controller?"controller":"Chatpad")+" read lost win32="+std::to_string(result.win32Error));failure=1;break;}
                if(controller){
                    ++counts.controllerPackets;XboxState state;
                    if(ParseController(packet.data(),packet.size(),state)){
                        last=state;
                        if(virtualController){if(!virtualController->SubmitState(state)){log.Event("virtual state submit failed: "+virtualController->LastError());failure=3;break;}++counts.virtualSubmissions;lastSubmit=GetTickCount64();}
                    }
                }else{
                    ++counts.chatpadPackets;
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
            }
            (void)last;
        }catch(const std::exception& ex){log.Event(std::string("reader exception: ")+ex.what());failure=6;}
    };
    std::thread controllerThread,chatpadThread;
    if(virtualController)controllerThread=std::thread(readLoop,true);
    chatpadThread=std::thread(readLoop,false);
    while(!appStop.load()&&failure.load()==0)std::this_thread::sleep_for(std::chrono::milliseconds(50));
    sessionStop=true;maintenance.Stop();
    TransferResult motorStop{};
    {
        std::lock_guard<std::mutex> guard(motorMutex);
        motorAvailable=false;
        motorStop=usb.Write(0,0x01,BuildRumble(0,0),1000);
    }
    if(virtualController)virtualController->SetRumbleCallback({});
    usb.Cancel();
    if(controllerThread.joinable())controllerThread.join();if(chatpadThread.joinable())chatpadThread.join();
    const bool keysReleased=mapper.ForceRelease();if(!keysReleased)log.Event("keyboard forced release failed");
    bool virtualNeutral=true,virtualReleased=true;
    if(virtualController){
        virtualNeutral=virtualController->SubmitState({});
        virtualController->Disconnect();
        const auto helperError=virtualController->LastError();
        virtualReleased=helperError.empty();
        if(!virtualReleased)log.Event("virtual backend cleanup failed: "+helperError);
    }
    // WinUSB may already be gone; still send one bounded zero command while the
    // interface remains available, and never retry after a disconnect.
    const bool motorsStopped=motorStop.status==TransferStatus::Ok&&motorStop.transferred==8;
    counts.cleanupFailure=!keysReleased||!virtualNeutral||!virtualReleased||!motorsStopped;
    if(!virtualNeutral)log.Event("virtual neutral cleanup failed");
    if(!motorsStopped)log.Event("zero-rumble cleanup failed win32="+std::to_string(motorStop.win32Error));
    log.Event(std::string("session cleanup keysReleased=")+(keysReleased?"true":"false")+
        " virtualNeutral="+(virtualNeutral?"true":"false")+" virtualReleased="+(virtualReleased?"true":"false")+
        " motorsStopped="+(motorsStopped?"true":"false"));
    if(counts.cleanupFailure)counts.backendFailure=true;
    counts.lost=failure.load()!=0;
    counts.elapsedMs=static_cast<uint64_t>(std::chrono::duration_cast<std::chrono::milliseconds>(Clock::now()-sessionStart).count());
    const auto seconds=(std::max)(0.001,counts.elapsedMs/1000.0);
    log.Event("session ended controllerReports="+std::to_string(counts.controllerPackets)+" chatpadReports="+
        std::to_string(counts.chatpadPackets)+" virtualSubmissions="+std::to_string(counts.virtualSubmissions)+
        " controllerRateHz="+std::to_string(counts.controllerPackets/seconds)+" virtualRateHz="+
        std::to_string(counts.virtualSubmissions/seconds)+" elapsedMs="+std::to_string(counts.elapsedMs));
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
    XboxState state{};std::vector<uint8_t> packet;
    const auto read=transport.Read(0,0x81,packet,1000);
    if(read.status!=TransferStatus::Ok||!ParseController(packet.data(),packet.size(),state)){std::cout<<"probe=FAILED controller_win32="<<read.win32Error<<"\n";return 6;}
    std::cout<<"probe=PASS controller_report_bytes="<<packet.size()<<" report_hex="<<Hex(packet)<<"\n";return 0;
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
    if(options.virtualController&&(options.helper.empty()||!options.helper.is_absolute()||!std::filesystem::exists(options.helper))) {
        log.Event("BLOCKED: absolute HIDMaestro helper executable not found; pass --backend-helper or package it beside the runner");return 2;
    }
    log.Event("application_start version=1.0.0 mode=run elevation=not_required_by_runner session=foreground");
    const auto marker=log.directory/L"session.active.json";std::error_code markerError;
    if(std::filesystem::exists(marker,markerError)){
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
    struct MarkerCleanup {std::filesystem::path path;~MarkerCleanup(){std::error_code ec;std::filesystem::remove(path,ec);}} markerCleanup{marker};
    FILETIME startCreate{},startExit{},startKernel{},startUser{};GetProcessTimes(GetCurrentProcess(),&startCreate,&startExit,&startKernel,&startUser);
    const auto processStart=Clock::now();
    RunnerLifecycle lifecycle;unsigned backoff=250;
    bool fatalBackendFailure=false;
    while(!stop.load()){
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
        const auto session=RunSession(transport,options,stop,lifecycle,log);
        transport.Close();
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

#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <Windows.h>
#include "WinUsbTransport.h"
#include "Topology.h"
#include "KeyboardOutput.h"
#include "VirtualHelper.h"
#include "C3Session.h"
#include "Runner.h"
#include <atomic>
#include <chrono>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <iterator>
#include <mutex>
#include <sstream>
#include <thread>
#include <stdexcept>
#include <filesystem>
#include <memory>
using namespace chatpad;
namespace {
std::atomic<bool> stopped{false};
std::mutex printMutex;
BOOL WINAPI ConsoleHandler(DWORD event) {
    if(event==CTRL_C_EVENT || event==CTRL_BREAK_EVENT || event==CTRL_CLOSE_EVENT || event==CTRL_SHUTDOWN_EVENT) {
        stopped=true;return TRUE;
    }
    return FALSE;
}
uint64_t Now(){return GetTickCount64();}
std::string Timestamp() {
    SYSTEMTIME now{};GetSystemTime(&now);char result[40]{};
    sprintf_s(result,"%04u-%02u-%02uT%02u:%02u:%02u.%03uZ",now.wYear,now.wMonth,now.wDay,now.wHour,now.wMinute,now.wSecond,now.wMilliseconds);
    return result;
}
std::string Hex(const std::vector<uint8_t>& data) {
    std::ostringstream text;text<<std::hex<<std::setfill('0');
    for(auto b:data)text<<std::setw(2)<<static_cast<unsigned>(b)<<' ';return text.str();
}
void Print(const std::string& text){std::lock_guard<std::mutex> guard(printMutex);std::cout<<Timestamp()<<' '<<text<<'\n';}
class MonitorOutput final : public IKeyboardOutput {
public:bool Send(uint8_t,bool)override{return true;}bool ForceRelease()override{return true;}
};
void HumanTopology(const DeviceInfo& device) {
    std::cout<<"VID=045E PID=028E instance="<<device.instanceId<<" configuration="<<static_cast<unsigned>(device.configuration)<<'\n';
    for(const auto& interface:device.interfaces) {
        std::cout<<"Interface "<<static_cast<unsigned>(interface.number)<<" alternate "<<static_cast<unsigned>(interface.alternateSetting)<<'\n';
        for(const auto& endpoint:interface.endpoints)
            std::cout<<"  endpoint 0x"<<std::hex<<static_cast<unsigned>(endpoint.address)<<std::dec
                     <<" type="<<(endpoint.type==3?"interrupt":endpoint.type==2?"bulk":endpoint.type==1?"isochronous":"control")
                     <<" maxPacket="<<endpoint.maxPacketSize<<'\n';
    }
}
void ControllerLine(const std::vector<uint8_t>& data) {
    XboxState state;std::ostringstream text;text<<"IF0 IN81 raw="<<Hex(data);
    if(ParseController(data.data(),data.size(),state)) {
        text<<"buttons=0x"<<std::hex<<state.buttons<<std::dec;
        const char* names[]={"Up","Down","Left","Right","Start","Back","LS","RS","LB","RB","Guide","Reserved","A","B","X","Y"};
        for(unsigned i=0;i<16;++i)if(state.buttons&(1u<<i))text<<' '<<names[i];
        text<<" LT="<<static_cast<unsigned>(state.leftTrigger)<<" RT="<<static_cast<unsigned>(state.rightTrigger)
            <<" L=("<<state.lx<<','<<state.ly<<") R=("<<state.rx<<','<<state.ry<<')';
    } else text<<"rejected controller type/length";
    Print(text.str());
}
bool ChatpadLine(const std::vector<uint8_t>& data,KeyboardMapper& mapper) {
    std::ostringstream text;text<<"IF2 IN84 raw="<<Hex(data);
    const bool mapped=mapper.Process(data.data(),data.size());
    if(mapped) {
        const auto& packet=mapper.LastPacket();const auto& report=mapper.LastReport();
        text<<"layer="<<((packet.RawModifiers&4)?"Orange":(packet.RawModifiers&2)?"Green":"Base")
            <<" Shift="<<((packet.RawModifiers&1)!=0)<<" HID=";
        for(auto b:report.Bytes)text<<std::hex<<static_cast<unsigned>(b)<<' ';
    } else text<<"rejected Chatpad type/length/modifier or mapper output";
    Print(text.str());return mapped;
}
void ActivationLine(const ActivationEvent& event) {
    const auto& setup=event.setup;std::ostringstream text;
    text<<"activation stage="<<event.step<<" setup=("<<std::hex<<static_cast<unsigned>(setup.requestType)<<','
        <<static_cast<unsigned>(setup.request)<<','<<setup.value<<','<<setup.index<<','<<setup.length<<std::dec
        <<") payload="<<Hex(setup.payload)<<" Win32="<<event.result.win32Error<<" transferred="<<event.result.transferred
        <<" status="<<static_cast<unsigned>(event.result.status)<<" accepted="<<event.accepted
        <<" stagePolicy="<<(event.optionalProbe?"OPTIONAL_PROBE":"STRICT")
        <<" disposition="<<ActivationDisposition(event)<<" provenStall="<<event.expectedStall;
    Print(text.str());
}
void MaintenanceLine(const char* stage,const ChatpadMaintenance& maintenance,bool success) {
    const auto result=maintenance.LastResult();std::ostringstream text;
    text<<stage<<" stagePolicy=STRICT status="<<static_cast<unsigned>(result.status)
        <<" Win32="<<result.win32Error<<" transferred="<<result.transferred
        <<" expectedLength=0 disposition="<<(success?"SUCCESS":"FATAL")<<" noRetry=true";
    Print(text.str());
}
bool Ready(WinUsbTransport& usb,uint64_t deadline,XboxState& initial) {
    while(!stopped && Now()<deadline) {
        std::vector<uint8_t> data;auto result=usb.Read(0,0x81,data,500);
        if(result.status==TransferStatus::Timeout)continue;
        if(result.status!=TransferStatus::Ok) {Print("controller readiness failed Win32="+std::to_string(result.win32Error));return false;}
        ControllerLine(data);XboxState state;
        if(ParseController(data.data(),data.size(),state)){initial=state;return true;}
    }
    Print("controller readiness deadline expired; activation not attempted");return false;
}
}
int main(int argc,char** argv) {
    try {
        if(argc<2)throw std::runtime_error("command required: run|status|diagnostics|probe|enumerate|descriptors|monitor-controller|monitor-chatpad|activate-chatpad|monitor-all|bridge");
        std::string command=argv[1],instance,jsonFile,fixture,helperPath,backend="hidmaestro";
        bool bridge=command=="bridge",session=command=="c3-session",allowBridge=false;
        bool verbose=false,noKeyboard=false,noVirtualController=false;
        unsigned seconds=15;bool activate=command=="activate-chatpad" || bridge,jsonOnly=false;
        for(int index=2;index<argc;++index) {
            std::string option=argv[index];
            auto argument=[&](){if(index+1>=argc)throw std::runtime_error("missing value for "+option);return std::string(argv[++index]);};
            if(option=="--seconds") {auto value=argument();size_t consumed=0;seconds=static_cast<unsigned>(std::stoul(value,&consumed));if(consumed!=value.size() || seconds<1 || seconds>120)throw std::runtime_error("seconds must be 1..120");}
            else if(option=="--instance")instance=argument();
            else if(option=="--json-out")jsonFile=argument();
            else if(option=="--fixture")fixture=argument();
            else if(option=="--backend-helper")helperPath=argument();
            else if(option=="--backend")backend=argument();
            else if(option=="--verbose")verbose=true;
            else if(option=="--no-keyboard")noKeyboard=true;
            else if(option=="--no-virtual-controller")noVirtualController=true;
            else if(option=="--allow-live-bridge")allowBridge=true;
            else if(option=="--activate")activate=true;
            else if(option=="--json-only")jsonOnly=true;
            else throw std::runtime_error("unknown option "+option);
        }
        if(command=="run" || command=="status" || command=="diagnostics" || command=="probe") {
            RunnerOptions options;options.executable=std::filesystem::absolute(std::filesystem::path(argv[0]));
            options.helper=helperPath.empty()?options.executable.parent_path()/L"ChatpadVirtualXbox.exe":std::filesystem::absolute(std::filesystem::path(helperPath));
            options.instanceId=instance;options.verbose=verbose;options.keyboard=!noKeyboard;options.virtualController=!noVirtualController;
            if(command=="run" && backend!="hidmaestro")throw std::runtime_error("normal run requires the installed HIDMaestro backend");
            if(command!="run" && (!helperPath.empty() || noKeyboard || noVirtualController))throw std::runtime_error("runtime options apply to run only");
            if(command=="run" && !SetConsoleCtrlHandler(ConsoleHandler,TRUE))throw std::runtime_error("console handler unavailable");
            const int result=RunUserModeBridge(command,options,stopped);
            if(command=="run")SetConsoleCtrlHandler(ConsoleHandler,FALSE);
            return result;
        }
        bool descriptor=command=="descriptors" || command=="enumerate";
        bool readController=command=="monitor-controller" || command=="monitor-all" || bridge;
        bool readChatpad=command=="monitor-chatpad" || command=="monitor-all" || command=="activate-chatpad" || bridge;
        if(bridge && (!allowBridge || helperPath.empty() || !std::filesystem::path(helperPath).is_absolute()))
            throw std::runtime_error("bridge requires explicit --allow-live-bridge and absolute --backend-helper; no implicit virtual creation/input injection");
        if(session&&(helperPath.empty()||!std::filesystem::path(helperPath).is_absolute()||activate||allowBridge))
            throw std::runtime_error("c3-session requires absolute backend-helper and staged stdin commands; no upfront activation/bridge option");
        if(!bridge && !session && (allowBridge || !helperPath.empty()))throw std::runtime_error("backend options require bridge or c3-session command");
        if(backend!="hidmaestro" && backend!="mock" && backend!="unavailable")throw std::runtime_error("unknown virtual backend");
        if(!descriptor && !readController && !readChatpad && !session)throw std::runtime_error("unknown command "+command);
        if(activate && (descriptor || command=="monitor-controller"))throw std::runtime_error("--activate requires Chatpad monitor mode");
        if(!fixture.empty()) {
            if(command!="descriptors" || activate)throw std::runtime_error("--fixture only for offline descriptors");
            std::ifstream file(fixture,std::ios::binary);if(!file)throw std::runtime_error("cannot open descriptor fixture");
            std::vector<uint8_t> raw((std::istreambuf_iterator<char>(file)),{});
            DeviceInfo device;device.vid=0x045e;device.pid=0x028e;device.instanceId="redacted; offline fixture";std::string error;
            if(!ParseConfiguration(raw,device.configuration,device.interfaces,error))throw std::runtime_error(error);
            if(!jsonOnly)HumanTopology(device);
            auto json=TopologyJson(device,raw,"offline descriptor fixture; not live WinUSB");
            std::cout<<json<<'\n';if(!jsonFile.empty()){std::ofstream out(jsonFile);out<<json<<'\n';if(!out)throw std::runtime_error("JSON write failed");}return 0;
        }
        WinUsbTransport usb;auto devices=usb.Enumerate();
        if(!instance.empty())devices.erase(std::remove_if(devices.begin(),devices.end(),[&](const auto& d){return d.instanceId!=instance;}),devices.end());
        if(devices.empty()){std::cerr<<"BLOCKED: "<<usb.Error()<<'\n';return 3;}
        if(devices.size()!=1)throw std::runtime_error("ambiguous physical targets; select exact --instance");
        auto opened=usb.Open(devices[0].path);
        if(opened.status!=TransferStatus::Ok){std::cerr<<"Open failed: "<<usb.Error()<<'\n';return 4;}
        if(descriptor) {
            if(!jsonOnly)HumanTopology(usb.Device());
            auto json=TopologyJson(usb.Device(),usb.RawConfiguration(),"live WinUSB queried descriptors");std::cout<<json<<'\n';
            if(!jsonFile.empty()){std::ofstream out(jsonFile);out<<json<<'\n';if(!out)throw std::runtime_error("JSON write failed");}return 0;
        }
        if(!SetConsoleCtrlHandler(ConsoleHandler,TRUE))throw std::runtime_error("console handler unavailable");
        if(session){
            HelperOptions options;options.executable=std::filesystem::path(helperPath).wstring();options.backend=backend;
            options.allowLiveVirtual=true;options.durationMs=seconds*1000;
            return RunC3Session(usb,options,seconds,stopped);
        }
        auto deadline=Now()+static_cast<uint64_t>(seconds)*1000;
        XboxState initialState;
        // Independent controller read completes before exact activation; no speculative payloads/retries.
        if(activate) {
            if(!Ready(usb,(std::min)(deadline,Now()+3000),initialState))return 5;
            ActivationRunner runner{ActivationPolicy::NativeProbeRejection};
            auto result=runner.Run(usb,[](uint32_t delay){std::this_thread::sleep_for(std::chrono::milliseconds(delay));},ActivationLine);
            if(!result.success){Print("activation stopped at fatal stage; Error31 is permitted only for zero-byte optional probes0..3, never USB STALL evidence; no retry");return 6;}
            Print("activation complete: strict write4 and final read5 succeeded with exact lengths; rejected optional probes are not hardware acceptance evidence");
        }
        std::atomic<int> failure{0};std::atomic<unsigned> controllerReports{0},chatpadReports{0};
        std::mutex motorMutex;
        std::unique_ptr<VirtualHelperController> virtualController;
        std::unique_ptr<IKeyboardOutput> output;
        if(bridge) {
            HelperOptions options;options.executable=std::filesystem::path(helperPath).wstring();options.backend=backend;options.allowLiveVirtual=true;
            virtualController=std::make_unique<VirtualHelperController>(options);
            if(!virtualController->Create()){Print("virtual backend unavailable: "+virtualController->LastError());return 12;}
            if(!virtualController->SubmitState(initialState)){Print("initial virtual submit failed: "+virtualController->LastError());return 12;}
            virtualController->SetRumbleCallback([&](uint16_t left,uint16_t right){
                std::lock_guard<std::mutex> lock(motorMutex);
                auto result=usb.Write(0,1,BuildRumble(left,right),1000);
                if(result.status!=TransferStatus::Ok || result.transferred!=8){Print("rumble write failed Win32="+std::to_string(result.win32Error));failure=13;}
            });
            output=std::make_unique<SendInputKeyboardOutput>();
        }else output=std::make_unique<MonitorOutput>();
        KeyboardMapper mapper(*output);ChatpadMaintenance maintenance(usb);
        struct OutputCleanup {
            std::function<void()> action;bool active=true;
            void Run(){if(active){active=false;action();}}
            ~OutputCleanup(){if(active){try{Run();}catch(...){std::cerr<<"output cleanup failed during unwinding\n";}}}
        } outputCleanup{[&]{
            maintenance.Stop();if(!mapper.ForceRelease()){Print("keyboard forced release failed");failure=11;}
            if(virtualController){
                virtualController->SetRumbleCallback({});virtualController->SubmitState({});virtualController->Disconnect();
                std::lock_guard<std::mutex> lock(motorMutex);
                auto motorStop=usb.Write(0,1,BuildRumble(0,0),1000);
                if(motorStop.status!=TransferStatus::Ok || motorStop.transferred!=8){Print("zero-rumble cleanup failed");failure=13;}
            }
        }};
        if(activate){
            const bool started=maintenance.Start(Now());MaintenanceLine("initial keepalive001F",maintenance,started);
            if(!started)return 7;
        }
        auto worker=[&](bool controller) {
            try {
                XboxState lastState=initialState;uint64_t submittedAt=Now();
                while(!stopped && Now()<deadline && failure==0) {
                    if(!controller && activate && !maintenance.Tick(Now())) {
                        MaintenanceLine("alternating keepalive001E/001F",maintenance,false);failure=7;break;
                    }
                    std::vector<uint8_t> data;
                    auto result=usb.Read(controller?0:2,controller?0x81:0x84,data,200);
                    if(result.status==TransferStatus::Timeout){
                        // Preserve current state and helper liveness when the USB
                        // controller sends only changes. No fabricated transition.
                        if(controller && virtualController && Now()-submittedAt>=1000){
                            if(!virtualController->SubmitState(lastState)){failure=12;break;}submittedAt=Now();
                        }
                        continue;
                    }
                    if(result.status==TransferStatus::Cancelled && stopped)break;
                    if(result.status!=TransferStatus::Ok){Print("read failed Win32="+std::to_string(result.win32Error));failure=8;break;}
                    if(controller){
                        ++controllerReports;ControllerLine(data);
                        XboxState state;
                        if(virtualController && ParseController(data.data(),data.size(),state)) {
                            lastState=state;
                            if(!virtualController->SubmitState(state)){Print("virtual submit failed: "+virtualController->LastError());failure=12;}
                            submittedAt=Now();
                        }
                    }
                    else {
                        ++chatpadReports;
                        if(activate){
                            const bool previous=maintenance.KeyDataAttempted();
                            const bool accepted=maintenance.OnCompletePacket(data.size());
                            if(!previous&&maintenance.KeyDataAttempted())MaintenanceLine("key-data enable001B",maintenance,accepted);
                            if(!accepted){failure=7;break;}
                        }
                        if(!ChatpadLine(data,mapper) && bridge && mapper.LastOutputFailed()){failure=11;}
                    }
                }
            }catch(const std::exception& e){Print(std::string("reader error: ")+e.what());failure=9;}
        };
        std::thread controllerThread,chatpadThread;
        struct ReaderCleanup {
            std::thread& controller;std::thread& chatpad;bool active=true;
            ~ReaderCleanup(){if(active){stopped=true;if(controller.joinable())controller.join();if(chatpad.joinable())chatpad.join();}}
        } readerCleanup{controllerThread,chatpadThread};
        if(readController)controllerThread=std::thread(worker,true);
        if(readChatpad)chatpadThread=std::thread(worker,false);
        while(!stopped && Now()<deadline && failure==0)std::this_thread::sleep_for(std::chrono::milliseconds(10));
        stopped=true;
        // Readers have finite 200ms requests (with cancellation/drain on timeout).
        // Join before disconnecting the backend so SubmitState cannot race teardown.
        if(virtualController)virtualController->SetRumbleCallback({});
        if(controllerThread.joinable())controllerThread.join();if(chatpadThread.joinable())chatpadThread.join();
        readerCleanup.active=false;
        outputCleanup.Run();
        usb.Cancel();
        usb.Close();SetConsoleCtrlHandler(ConsoleHandler,FALSE);
        Print("capture complete controllerReports="+std::to_string(controllerReports)+" chatpadReports="+std::to_string(chatpadReports)+(bridge?" injection=explicit bridge":" injection=disabled"));
        if(failure!=0)return failure;
        // A silent monitor window is not transport acceptance.
        if((readController && controllerReports==0)||(readChatpad && chatpadReports==0))return 10;
        return 0;
    }catch(const std::exception& e){std::cerr<<"ERROR: "<<e.what()<<'\n';return 2;}
}

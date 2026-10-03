#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <Windows.h>
#include "C3Session.h"
#include "SessionPolicy.h"
#include "KeyboardOutput.h"
#include <algorithm>
#include <chrono>
#include <iostream>
#include <mutex>
#include <sstream>
#include <thread>
#include <memory>
namespace chatpad {
namespace {
std::string Quoted(const std::string& value){
    std::string out="\"";for(unsigned char c:value){if(c=='"'||c=='\\'){out+='\\';out+=static_cast<char>(c);}
        else if(c>=32&&c<127)out+=static_cast<char>(c);else out+='?';}return out+'"';
}
std::string RawHex(const std::vector<uint8_t>& data){
    const char* digits="0123456789ABCDEF";std::string result;
    for(auto b:data){result+=digits[b>>4];result+=digits[b&15];}return result;
}
class GatedKeyboard final:public IKeyboardOutput{
public:
    bool enabled{};
    bool Send(uint8_t usage,bool down)override{return !enabled||output_.Send(usage,down);}
    bool ForceRelease()override{return output_.ForceRelease();}
private:SendInputKeyboardOutput output_;
};
class DeadlineTransport final:public IPhysicalTransport{
public:
    DeadlineTransport(IPhysicalTransport& source,uint64_t deadline,std::atomic<bool>& stop):source_(source),deadline_(deadline),stop_(stop){}
    std::vector<DeviceInfo> Enumerate()override{return source_.Enumerate();}
    TransferResult Open(const std::string& path)override{return source_.Open(path);}
    std::vector<InterfaceInfo> Interfaces()override{return source_.Interfaces();}
    TransferResult Control(const ControlRequest& setup,std::vector<uint8_t>& bytes,uint32_t timeout)override{
        const auto now=GetTickCount64();
        if(stop_){bytes.clear();return {TransferStatus::Cancelled,ERROR_OPERATION_ABORTED,0};}
        if(now>=deadline_){bytes.clear();return {TransferStatus::Timeout,ERROR_TIMEOUT,0};}
        const auto remaining=static_cast<uint32_t>((std::min)(deadline_-now,static_cast<uint64_t>(timeout)));
        return source_.Control(setup,bytes,remaining);
    }
    TransferResult Read(uint8_t number,uint8_t endpoint,std::vector<uint8_t>& data,uint32_t timeout)override{return source_.Read(number,endpoint,data,timeout);}
    TransferResult Write(uint8_t number,uint8_t endpoint,const std::vector<uint8_t>& data,uint32_t timeout)override{return source_.Write(number,endpoint,data,timeout);}
    void Cancel()override{source_.Cancel();}
    void Close()override{source_.Close();}
private:IPhysicalTransport& source_;uint64_t deadline_;std::atomic<bool>& stop_;
};
}
int RunC3Session(IPhysicalTransport& usb,const HelperOptions& options,unsigned seconds,std::atomic<bool>& stop){
    HANDLE input=GetStdHandle(STD_INPUT_HANDLE);
    if(GetFileType(input)!=FILE_TYPE_PIPE){std::cerr<<"c3-session requires redirected stdin command pipe\n";return 2;}
    bool controllerIn{},controllerOut{},chatpadIn{};
    for(const auto& interface:usb.Interfaces())for(const auto& endpoint:interface.endpoints){
        if(interface.alternateSetting!=0||endpoint.type!=3||endpoint.maxPacketSize!=32)continue;
        if(interface.number==0&&endpoint.address==0x81)controllerIn=true;
        if(interface.number==0&&endpoint.address==0x01)controllerOut=true;
        if(interface.number==2&&endpoint.address==0x84)chatpadIn=true;
    }
    if(!controllerIn||!controllerOut||!chatpadIn){
        std::cout<<"{\"event\":\"fatal\",\"ok\":false,\"reason\":\"session interfaces/interrupt pipes not verified\"}\n"<<std::flush;return 4;
    }
    const uint64_t deadline=GetTickCount64()+static_cast<uint64_t>(seconds)*1000;
    std::mutex mutex,eventMutex,motorMutex;
    SessionPolicy policy;XboxState lastState;GatedKeyboard keyboard;KeyboardMapper mapper(keyboard);
    DeadlineTransport bounded(usb,deadline,stop);
    ChatpadMaintenance maintenance(bounded);ActivationRunner activation{ActivationPolicy::NativeProbeRejection};
    std::unique_ptr<VirtualHelperController> backend;
    std::atomic<int> failure{0};std::atomic<bool> rumbleEnabled{false};
    uint64_t controllers{},chatpads{},lastSubmit{},activatedAt{};bool requestedStop{},keyEnabled{};
    auto emit=[&](const std::string& fields){std::lock_guard<std::mutex> guard(eventMutex);
        std::cout<<"{\"timeMs\":"<<GetTickCount64()<<','<<fields<<"}\n"<<std::flush;};
    auto fatal=[&](int code,const char* reason){
        int expected=0;if(failure.compare_exchange_strong(expected,code))emit("\"event\":\"fatal\",\"ok\":false,\"reason\":"+Quoted(reason));
        stop=true;
    };
    auto transferFields=[](const TransferResult& result){return "\"status\":"+std::to_string(static_cast<unsigned>(result.status))+
        ",\"win32\":"+std::to_string(result.win32Error)+",\"transferred\":"+std::to_string(result.transferred);};
    std::thread controllerThread,chatpadThread;
    struct Cleanup{
        std::function<void()> action;bool active=true;
        void Run(){if(active){active=false;action();}}
        ~Cleanup(){if(active){try{Run();}catch(...){std::cerr<<"c3-session cleanup exception\n";}}}
    } cleanup{[&]{
        stop=true;if(controllerThread.joinable())controllerThread.join();if(chatpadThread.joinable())chatpadThread.join();
        maintenance.Stop();if(!mapper.ForceRelease())fatal(11,"keyboard release failed");
        const bool motorWasEnabled=rumbleEnabled.exchange(false);
        if(backend){backend->SetRumbleCallback({});if(policy.VirtualCreated()&&!backend->SubmitState({}))fatal(12,"virtual neutral cleanup failed");backend->Disconnect();}
        if(motorWasEnabled){std::lock_guard<std::mutex> guard(motorMutex);
            const auto result=usb.Write(0,1,BuildRumble(0,0),1000);
            if(result.status!=TransferStatus::Ok||result.transferred!=8)fatal(13,"zero-rumble cleanup failed");}
        usb.Cancel();usb.Close();
        emit("\"event\":\"closed\",\"ok\":"+std::string(failure==0?"true":"false")+
             ",\"controllerReports\":"+std::to_string(controllers)+",\"chatpadReports\":"+std::to_string(chatpads));
    }};
    auto reader=[&](bool controller){
        try{
            while(!stop&&GetTickCount64()<deadline&&failure==0){
                std::vector<uint8_t> data;auto result=usb.Read(controller?0:2,controller?0x81:0x84,data,100);
                if(result.status==TransferStatus::Timeout)continue;
                if(result.status==TransferStatus::Cancelled&&stop)break;
                if(result.status!=TransferStatus::Ok){emit("\"event\":\"transfer-failure\","+transferFields(result));fatal(8,"physical read failed");break;}
                const auto receivedAt=GetTickCount64();
                std::lock_guard<std::mutex> guard(mutex);
                if(controller){
                    XboxState state;const bool valid=ParseController(data.data(),data.size(),state);++controllers;
                    if(valid){lastState=state;policy.ObserveController();
                        if(policy.Mapping()&&backend&&!backend->SubmitState(state)){fatal(12,"mapping submit failed");break;}}
                    emit("\"event\":\"controller\",\"valid\":"+std::string(valid?"true":"false")+
                         ",\"bytes\":"+std::to_string(data.size())+",\"raw\":"+Quoted(RawHex(data)));
                }else{
                    ++chatpads;
                    if(policy.Activated()&&receivedAt>=activatedAt){
                        const bool before=maintenance.KeyDataAttempted();const bool accepted=maintenance.OnCompletePacket(data.size());
                        if(!before&&maintenance.KeyDataAttempted()){
                            keyEnabled=accepted;emit("\"event\":\"key-data\",\"ok\":"+std::string(accepted?"true":"false")+
                                ",\"value\":27,"+transferFields(maintenance.LastResult()));}
                        if(!accepted){fatal(7,"strict001B failed");break;}
                    }
                    const bool valid=mapper.Process(data.data(),data.size());
                    if(valid&&data.size()==5&&receivedAt>=activatedAt)policy.ObserveFiveBytes(keyEnabled);
                    if(!valid&&keyboard.enabled&&data.size()==5&&data[0]==0){fatal(11,"keyboard mapping/output failed");break;}
                    emit("\"event\":\"chatpad\",\"valid\":"+std::string(valid?"true":"false")+
                         ",\"bytes\":"+std::to_string(data.size())+",\"keyDataEnabled\":"+(keyEnabled?"true":"false")+
                         ",\"raw\":"+Quoted(RawHex(data)));
                }
            }
        }catch(const std::exception&){fatal(9,"physical reader exception");}
    };
    try{
        controllerThread=std::thread(reader,true);chatpadThread=std::thread(reader,false);
        emit("\"event\":\"session\",\"ok\":true,\"schema\":1,\"interfacesVerified\":true,\"readersStarted\":true,"
             "\"controllerInterface\":0,\"controllerIn\":129,\"controllerOut\":1,\"chatpadInterface\":2,\"chatpadIn\":132,"
             "\"physicalOutputsEnabled\":false,\"maximumSeconds\":"+std::to_string(seconds));
        std::string line;size_t lineBytes{};
        while(!stop&&GetTickCount64()<deadline&&failure==0){
            DWORD available{};
            if(!PeekNamedPipe(input,nullptr,0,nullptr,&available,nullptr)){fatal(8,"command pipe closed without stop");break;}
            while(available--&&!stop&&GetTickCount64()<deadline){
                char c{};DWORD read{};if(!ReadFile(input,&c,1,&read,nullptr)||read!=1){fatal(8,"command pipe read failed");break;}
                if(c!='\n'&&++lineBytes>128){fatal(2,"command line exceeds128bytes");break;}
                if(c=='\r')continue;
                if(c!='\n'){line+=c;if(line.size()>128){fatal(2,"command line exceeds128bytes");break;}continue;}
                SessionRequest request;
                if(!ParseSessionRequest(line,request)){fatal(2,"invalid session command");break;}
                line.clear();lineBytes=0;
                std::lock_guard<std::mutex> guard(mutex);
                if(!policy.AcceptRequestId(request.id)){fatal(2,"replayed or reordered session command");break;}
                bool ok=policy.Allowed(request.command);
                if(ok){
                    switch(request.command){
                    case SessionCommand::Activate:{
                        auto result=activation.Run(bounded,[](uint32_t ms){std::this_thread::sleep_for(std::chrono::milliseconds(ms));},
                            [&](const ActivationEvent& event){emit("\"event\":\"activation-stage\",\"stage\":"+std::to_string(event.step)+
                                ",\"ok\":"+(event.accepted?"true":"false")+",\"disposition\":"+Quoted(ActivationDisposition(event))+
                                ",\"provenStall\":"+(event.expectedStall?"true":"false")+","+transferFields(event.result));});
                        ok=result.success&&maintenance.Start(GetTickCount64());
                        if(ok)activatedAt=GetTickCount64();
                        emit("\"event\":\"activation\",\"ok\":"+std::string(ok?"true":"false")+",\"keyDataEnabled\":false");break;}
                    case SessionCommand::CreateVirtual:
                        backend=std::make_unique<VirtualHelperController>(options);ok=backend->Create();
                        if(ok){backend->SetRumbleCallback([&](uint16_t left,uint16_t right){
                            emit("\"event\":\"rumble-callback\",\"left\":"+std::to_string(left)+",\"right\":"+std::to_string(right));
                            if(!rumbleEnabled)return;std::lock_guard<std::mutex> motor(motorMutex);
                            if(!rumbleEnabled)return;const auto result=usb.Write(0,1,BuildRumble(left,right),1000);
                            if(result.status!=TransferStatus::Ok||result.transferred!=8)fatal(13,"physical rumble write failed");
                            else emit("\"event\":\"rumble-output\",\"ok\":true,"+transferFields(result));});
                            ok=backend->SubmitState({});lastSubmit=GetTickCount64();}
                        emit("\"event\":\"virtual-created\",\"ok\":"+std::string(ok?"true":"false"));break;
                    case SessionCommand::EnableMapping:ok=backend&&backend->SubmitState(lastState);lastSubmit=GetTickCount64();break;
                    case SessionCommand::EnableRumble:rumbleEnabled=true;break;
                    case SessionCommand::EnableKeyboard:ok=mapper.ForceRelease();if(ok)keyboard.enabled=true;break;
                    case SessionCommand::Stop:requestedStop=true;stop=true;break;
                    }
                }
                if(ok)policy.Commit(request.command);
                emit("\"event\":\"command\",\"id\":"+std::to_string(request.id)+",\"command\":"+Quoted(SessionCommandName(request.command))+
                     ",\"ok\":"+(ok?"true":"false"));
                if(!ok){fatal(6,"session command failed or out of order");break;}
            }
            if(!stop){
                std::lock_guard<std::mutex> guard(mutex);
                if(policy.Activated()&&!maintenance.Tick(GetTickCount64())){fatal(7,"strict keepalive failed");break;}
                if(backend&&policy.VirtualCreated()&&GetTickCount64()-lastSubmit>=1000){
                    if(!backend->SubmitState(policy.Mapping()?lastState:XboxState{})){fatal(12,"virtual heartbeat failed");break;}
                    lastSubmit=GetTickCount64();}
            }
            std::this_thread::sleep_for(std::chrono::milliseconds(10));
        }
        if(!requestedStop&&failure==0)fatal(10,"session deadline expired");
    }catch(const std::exception&){fatal(9,"session command/worker exception");}
    cleanup.Run();return failure.load();
}
}

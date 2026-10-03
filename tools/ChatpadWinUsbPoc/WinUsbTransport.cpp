#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <Windows.h>
#include <SetupAPI.h>
#include <winusb.h>
#include <usb.h>
#include "WinUsbTransport.h"
#include "Topology.h"
#include "CompletionPolicy.h"
#include <algorithm>
#include <map>
#include <mutex>
#include <stdexcept>
#include <iostream>
#include <cctype>
#include <cstdlib>

namespace chatpad {
namespace {
const GUID InterfaceGuid={0xb6a5d05e,0x7e18,0x4df1,{0x8e,0x47,0x12,0xf0,0x72,0xde,0x2c,0x36}};
const GUID GenericUsbGuid={0xa5dcbf10,0x6530,0x11d2,{0x90,0x1f,0x00,0xc0,0x4f,0xb9,0x51,0xed}};
std::string Utf8(const wchar_t* text) {
    int size=WideCharToMultiByte(CP_UTF8,0,text,-1,nullptr,0,nullptr,nullptr);
    if(size<=0)return {};
    std::string result(static_cast<size_t>(size),'\0');
    WideCharToMultiByte(CP_UTF8,0,text,-1,result.data(),size,nullptr,nullptr);result.pop_back();return result;
}
std::wstring Wide(const std::string& text) {
    int size=MultiByteToWideChar(CP_UTF8,MB_ERR_INVALID_CHARS,text.c_str(),-1,nullptr,0);
    if(size<=0)throw std::runtime_error("invalid UTF-8 path");
    std::wstring result(static_cast<size_t>(size),L'\0');
    MultiByteToWideChar(CP_UTF8,MB_ERR_INVALID_CHARS,text.c_str(),-1,result.data(),size);result.pop_back();return result;
}
TransferResult Result(DWORD error,size_t bytes=0) {
    TransferStatus status=TransferStatus::Error;
    switch(error) {case ERROR_SUCCESS:status=TransferStatus::Ok;break;
    case ERROR_OPERATION_ABORTED:status=TransferStatus::Cancelled;break;
    case ERROR_SEM_TIMEOUT:case ERROR_TIMEOUT:status=TransferStatus::Timeout;break;
    case ERROR_ACCESS_DENIED:status=TransferStatus::AccessDenied;break;
    case ERROR_FILE_NOT_FOUND:case ERROR_DEVICE_NOT_CONNECTED:case ERROR_NO_SUCH_DEVICE:
        status=TransferStatus::DeviceNotPresent;break;
    default:break;}
    // ERROR_GEN_FAILURE (31) does not establish USBD_STATUS_STALL_PID.
    // WinUSB's Win32 surface cannot safely reproduce kernel-only STALL evidence.
    return {status,error,bytes};
}
class NativeCompletion final : public IAsyncCompletion {
public:
    NativeCompletion(HANDLE file,OVERLAPPED& operation,HANDLE cancel):file_(file),operation_(operation),cancel_(cancel){}
    WaitOutcome Wait(uint32_t timeout)override{
        HANDLE events[]={operation_.hEvent,cancel_};DWORD waited=WaitForMultipleObjects(2,events,FALSE,timeout);
        if(waited==WAIT_OBJECT_0)return WaitOutcome::Complete;
        if(waited==WAIT_TIMEOUT)return WaitOutcome::Timeout;
        if(waited==WAIT_OBJECT_0+1)return WaitOutcome::Cancelled;
        return WaitOutcome::Failed;
    }
    void Cancel()override{CancelIoEx(file_,&operation_);}
    bool Drain(uint32_t timeout)override{return WaitForSingleObject(operation_.hEvent,timeout)==WAIT_OBJECT_0;}
    TransferResult Result()override{DWORD bytes=0;BOOL ok=GetOverlappedResult(file_,&operation_,&bytes,FALSE);return chatpad::Result(ok?0:GetLastError(),bytes);}
private:
    HANDLE file_;OVERLAPPED& operation_;HANDLE cancel_;
};
struct InterfaceCandidate {DeviceInfo info;std::string service;};
std::vector<InterfaceCandidate> Candidates(const GUID& guid) {
    std::vector<InterfaceCandidate> found;
    HDEVINFO set=SetupDiGetClassDevsW(&guid,nullptr,nullptr,DIGCF_PRESENT|DIGCF_DEVICEINTERFACE);
    if(set==INVALID_HANDLE_VALUE)throw std::runtime_error("SetupDiGetClassDevs Win32="+std::to_string(GetLastError()));
    struct Cleanup {HDEVINFO set;~Cleanup(){SetupDiDestroyDeviceInfoList(set);}} cleanup{set};
    for(DWORD index=0;;++index) {
        SP_DEVICE_INTERFACE_DATA interfaceData{};interfaceData.cbSize=sizeof(interfaceData);
        if(!SetupDiEnumDeviceInterfaces(set,nullptr,&guid,index,&interfaceData)) {
            DWORD error=GetLastError();if(error==ERROR_NO_MORE_ITEMS)break;
            throw std::runtime_error("SetupDiEnumDeviceInterfaces Win32="+std::to_string(error));
        }
        DWORD bytes=0;SetupDiGetDeviceInterfaceDetailW(set,&interfaceData,nullptr,0,&bytes,nullptr);
        if(bytes<sizeof(SP_DEVICE_INTERFACE_DETAIL_DATA_W))throw std::runtime_error("invalid interface detail size");
        std::vector<uint8_t> storage(bytes);
        auto detail=reinterpret_cast<SP_DEVICE_INTERFACE_DETAIL_DATA_W*>(storage.data());detail->cbSize=sizeof(*detail);
        SP_DEVINFO_DATA node{};node.cbSize=sizeof(node);
        if(!SetupDiGetDeviceInterfaceDetailW(set,&interfaceData,detail,bytes,nullptr,&node))
            throw std::runtime_error("SetupDiGetDeviceInterfaceDetail Win32="+std::to_string(GetLastError()));
        wchar_t instance[1024]{};
        if(!SetupDiGetDeviceInstanceIdW(set,&node,instance,1024,nullptr))throw std::runtime_error("cannot obtain device instance");
        std::string id=Utf8(instance),upper=id;
        std::transform(upper.begin(),upper.end(),upper.begin(),[](unsigned char c){return static_cast<char>(toupper(c));});
        // Exact whole-device instance prefix excludes MI/IG and unrelated products.
        if(upper.rfind("USB\\VID_045E&PID_028E\\",0)!=0)continue;
        wchar_t service[256]{};DWORD type=0;
        if(!SetupDiGetDeviceRegistryPropertyW(set,&node,SPDRP_SERVICE,&type,reinterpret_cast<PBYTE>(service),sizeof(service),nullptr))
            throw std::runtime_error("cannot query selected device service");
        DeviceInfo info;info.path=Utf8(detail->DevicePath);info.instanceId=id;info.vid=0x045e;info.pid=0x028e;
        found.push_back({std::move(info),Utf8(service)});
    }
    return found;
}
}

struct WinUsbTransport::Impl {
    struct Operation {
        OVERLAPPED overlapped{};
        std::vector<uint8_t> buffer;
        Operation(){overlapped.hEvent=CreateEventW(nullptr,TRUE,FALSE,nullptr);}
        ~Operation(){if(overlapped.hEvent)CloseHandle(overlapped.hEvent);}
    };
    HANDLE file=INVALID_HANDLE_VALUE,cancelEvent=nullptr;
    WINUSB_INTERFACE_HANDLE first=nullptr;
    std::map<uint8_t,WINUSB_INTERFACE_HANDLE> handles;
    std::mutex gate;
    bool cancelled=false;
    std::vector<std::unique_ptr<Operation>> undrained;
    DeviceInfo info;std::vector<uint8_t> raw;std::string error;
    Impl(){cancelEvent=CreateEventW(nullptr,TRUE,FALSE,nullptr);if(!cancelEvent)throw std::runtime_error("cancel event creation failed");}
    ~Impl(){CloseHandle(cancelEvent);}
    WINUSB_INTERFACE_HANDLE Handle(uint8_t number) const {
        auto i=handles.find(number);return i==handles.end()?nullptr:i->second;
    }
    template<class Start> TransferResult Transfer(std::vector<uint8_t>& buffer,uint32_t timeout,Start start) {
        if(timeout==0 || timeout>5000)return Result(ERROR_INVALID_PARAMETER);
        auto storage=std::make_unique<Operation>();
        if(!storage->overlapped.hEvent)return Result(GetLastError());
        storage->buffer=buffer;
        OVERLAPPED& operation=storage->overlapped;
        BOOL immediate=FALSE;DWORD initialError=0;
        {
            // No new I/O can be issued after Cancel has signaled the lifetime gate.
            std::lock_guard<std::mutex> guard(gate);
            if(cancelled || file==INVALID_HANDLE_VALUE)return Result(ERROR_OPERATION_ABORTED);
            immediate=start(&operation,storage->buffer.data(),static_cast<ULONG>(storage->buffer.size()));
            initialError=immediate?0:GetLastError();
        }
        if(!immediate && initialError!=ERROR_IO_PENDING)return Result(initialError);
        NativeCompletion completion(file,operation,cancelEvent);
        auto outcome=immediate?CompletionOutcome{completion.Result(),true}:CompletePending(completion,timeout);
        if(!outcome.storageSafe) {
            // Preserve request storage while owner releases outputs before Close.
            std::lock_guard<std::mutex> guard(gate);
            cancelled=true;SetEvent(cancelEvent);undrained.push_back(std::move(storage));
            std::cerr<<"FATAL: WinUSB cancellation did not drain; owner must release outputs before Close\n";
            return outcome.result;
        }
        if(outcome.result.transferred>buffer.size())return Result(ERROR_INVALID_DATA);
        buffer=std::move(storage->buffer);
        return outcome.result;
    }
};
WinUsbTransport::WinUsbTransport():impl_(std::make_unique<Impl>()){}
WinUsbTransport::~WinUsbTransport(){Close();}
std::vector<DeviceInfo> WinUsbTransport::Enumerate() {
    std::vector<DeviceInfo> found;impl_->error.clear();
    for(auto& device:Candidates(InterfaceGuid)) {
        std::string service=device.service;std::transform(service.begin(),service.end(),service.begin(),[](unsigned char c){return static_cast<char>(tolower(c));});
        if(service!="winusb") {impl_->error="advertised POC interface selected service="+device.service+"; WinUSB required";continue;}
        found.push_back(std::move(device.info));
    }
    if(found.empty() && impl_->error.empty()) {
        auto current=Candidates(GenericUsbGuid);
        impl_->error=current.empty()?"No present 045E:028E physical target with POC WinUSB GUID":"045E:028E is still bound to "+current.front().service+"; no POC WinUSB interface. C2 never binds it.";
    }
    return found;
}
TransferResult WinUsbTransport::Open(const std::string& path) {
    Close();auto candidates=Enumerate();
    auto device=std::find_if(candidates.begin(),candidates.end(),[&](const auto& d){return d.path==path;});
    if(device==candidates.end())return Result(ERROR_FILE_NOT_FOUND);
    impl_->info=*device;impl_->cancelled=false;ResetEvent(impl_->cancelEvent);
    auto fail=[&](DWORD error,const std::string& detail){Close();impl_->error=detail+"; Win32="+std::to_string(error);return Result(error);};
    impl_->file=CreateFileW(Wide(path).c_str(),GENERIC_READ|GENERIC_WRITE,FILE_SHARE_READ|FILE_SHARE_WRITE,nullptr,OPEN_EXISTING,FILE_FLAG_OVERLAPPED,nullptr);
    if(impl_->file==INVALID_HANDLE_VALUE)return fail(GetLastError(),"CreateFile");
    if(!WinUsb_Initialize(impl_->file,&impl_->first))return fail(GetLastError(),"WinUsb_Initialize");
    USB_DEVICE_DESCRIPTOR descriptor{};ULONG bytes=0;
    if(!WinUsb_GetDescriptor(impl_->first,USB_DEVICE_DESCRIPTOR_TYPE,0,0,reinterpret_cast<PUCHAR>(&descriptor),sizeof(descriptor),&bytes) || bytes!=sizeof(descriptor))
        return fail(ERROR_INVALID_DATA,"device descriptor unavailable");
    if(descriptor.idVendor!=0x045e || descriptor.idProduct!=0x028e || descriptor.bNumConfigurations!=1)
        return fail(ERROR_INVALID_DATA,"unexpected physical identity/configurations");
    USB_CONFIGURATION_DESCRIPTOR config{};
    if(!WinUsb_GetDescriptor(impl_->first,USB_CONFIGURATION_DESCRIPTOR_TYPE,0,0,reinterpret_cast<PUCHAR>(&config),sizeof(config),&bytes) || bytes!=sizeof(config) || config.wTotalLength<9 || config.wTotalLength>4096)
        return fail(ERROR_INVALID_DATA,"configuration header unavailable");
    impl_->raw.resize(config.wTotalLength);
    if(!WinUsb_GetDescriptor(impl_->first,USB_CONFIGURATION_DESCRIPTOR_TYPE,0,0,impl_->raw.data(),config.wTotalLength,&bytes) || bytes!=config.wTotalLength)
        return fail(ERROR_INVALID_DATA,"configuration descriptor truncated");
    std::string parseError;
    if(!ParseConfiguration(impl_->raw,impl_->info.configuration,impl_->info.interfaces,parseError))return fail(ERROR_INVALID_DATA,parseError);
    USB_INTERFACE_DESCRIPTOR settings{};
    if(!WinUsb_QueryInterfaceSettings(impl_->first,0,&settings) || settings.bInterfaceNumber!=0)
        return fail(ERROR_INVALID_DATA,"default interface must be 0");
    impl_->handles.emplace(static_cast<uint8_t>(0),impl_->first);
    for(UCHAR index=0;index<static_cast<UCHAR>(config.bNumInterfaces-1);++index) {
        WINUSB_INTERFACE_HANDLE associated=nullptr;
        if(!WinUsb_GetAssociatedInterface(impl_->first,index,&associated))return fail(GetLastError(),"associated interface lookup");
        if(!WinUsb_QueryInterfaceSettings(associated,0,&settings) || impl_->handles.count(settings.bInterfaceNumber)) {
            WinUsb_Free(associated);return fail(ERROR_INVALID_DATA,"invalid/duplicate associated interface number");
        }
        impl_->handles.emplace(settings.bInterfaceNumber,associated);
    }
    for(const auto& interface:impl_->info.interfaces) {
        auto handle=impl_->Handle(interface.number);if(!handle)return fail(ERROR_INVALID_DATA,"descriptor interface missing handle");
        USB_INTERFACE_DESCRIPTOR actual{};
        if(!WinUsb_QueryInterfaceSettings(handle,interface.alternateSetting,&actual) || actual.bInterfaceNumber!=interface.number || actual.bNumEndpoints!=interface.endpoints.size())
            return fail(ERROR_INVALID_DATA,"queried interface disagrees with descriptor");
        UCHAR active=0;if(!WinUsb_GetCurrentAlternateSetting(handle,&active) || active!=0)return fail(ERROR_INVALID_DATA,"nonzero alternate setting unsupported");
        for(UCHAR index=0;index<actual.bNumEndpoints;++index) {
            WINUSB_PIPE_INFORMATION pipe{};
            if(!WinUsb_QueryPipe(handle,interface.alternateSetting,index,&pipe))return fail(GetLastError(),"endpoint query");
            const auto& expected=interface.endpoints[index];
            if(pipe.PipeId!=expected.address || static_cast<uint8_t>(pipe.PipeType)!=expected.type || pipe.MaximumPacketSize!=expected.maxPacketSize)
                return fail(ERROR_INVALID_DATA,"endpoint query disagrees with descriptor");
            ULONG timeout=1000;
            if(!WinUsb_SetPipePolicy(handle,pipe.PipeId,PIPE_TRANSFER_TIMEOUT,sizeof(timeout),&timeout))return fail(GetLastError(),"pipe timeout policy");
        }
    }
    if(!RequiredTopology(impl_->info.interfaces))return fail(ERROR_INVALID_DATA,"required IF0 81/01 IF2 84 interrupt/32 topology absent");
    ULONG timeout=1000;
    if(!WinUsb_SetPipePolicy(impl_->first,0,PIPE_TRANSFER_TIMEOUT,sizeof(timeout),&timeout))return fail(GetLastError(),"EP0 timeout policy");
    std::vector<uint8_t> current;
    auto state=Control({0x80,8,0,0,1,{}},current,1000);
    if(state.status!=TransferStatus::Ok || state.transferred!=1 || current[0]!=impl_->info.configuration)
        return fail(ERROR_INVALID_DATA,"active configuration mismatch");
    return Result(0);
}
std::vector<InterfaceInfo> WinUsbTransport::Interfaces(){return impl_->info.interfaces;}
TransferResult WinUsbTransport::Control(const ControlRequest& request,std::vector<uint8_t>& inbound,uint32_t timeout) {
    inbound.clear();bool isIn=(request.requestType&0x80)!=0;
    if(request.length>4096 || (!isIn && request.payload.size()!=request.length))return Result(ERROR_INVALID_PARAMETER);
    auto handle=(request.requestType&0x1f)==1?impl_->Handle(static_cast<uint8_t>(request.index&0xff)):impl_->first;
    if(!handle)return Result(ERROR_DEVICE_NOT_CONNECTED);
    std::vector<uint8_t> buffer=isIn?std::vector<uint8_t>(request.length):request.payload;
    WINUSB_SETUP_PACKET setup{request.requestType,request.request,request.value,request.index,request.length};
    auto result=impl_->Transfer(buffer,timeout,[&](OVERLAPPED* operation,PUCHAR data,ULONG length){return WinUsb_ControlTransfer(handle,setup,data,length,nullptr,operation);});
    if(isIn) {buffer.resize(result.transferred);inbound=std::move(buffer);}return result;
}
TransferResult WinUsbTransport::Read(uint8_t number,uint8_t endpoint,std::vector<uint8_t>& output,uint32_t timeout) {
    output.clear();auto handle=impl_->Handle(number);
    if(!handle || (number!=0 && number!=2) || endpoint!=(number==0?0x81:0x84))return Result(ERROR_INVALID_PARAMETER);
    std::vector<uint8_t> buffer(32);
    auto result=impl_->Transfer(buffer,timeout,[&](OVERLAPPED* operation,PUCHAR data,ULONG length){return WinUsb_ReadPipe(handle,endpoint,data,length,nullptr,operation);});
    buffer.resize(result.transferred);output=std::move(buffer);return result;
}
TransferResult WinUsbTransport::Write(uint8_t number,uint8_t endpoint,const std::vector<uint8_t>& input,uint32_t timeout) {
    auto handle=impl_->Handle(number);
    if(!handle || number!=0 || endpoint!=1 || input.empty() || input.size()>32)return Result(ERROR_INVALID_PARAMETER);
    std::vector<uint8_t> buffer=input;
    return impl_->Transfer(buffer,timeout,[&](OVERLAPPED* operation,PUCHAR data,ULONG length){return WinUsb_WritePipe(handle,endpoint,data,length,nullptr,operation);});
}
void WinUsbTransport::Cancel(){std::lock_guard<std::mutex> guard(impl_->gate);impl_->cancelled=true;SetEvent(impl_->cancelEvent);if(impl_->file!=INVALID_HANDLE_VALUE)CancelIoEx(impl_->file,nullptr);}
void WinUsbTransport::Close(){
    Cancel();
    if(!impl_->undrained.empty()) {
        std::cerr<<"FATAL: undrained native I/O; terminating POC with exit70 after output cleanup\n";
        TerminateProcess(GetCurrentProcess(),70);
        std::abort();
    }
    for(auto& handle:impl_->handles)if(handle.second!=impl_->first)WinUsb_Free(handle.second);
    impl_->handles.clear();if(impl_->first)WinUsb_Free(impl_->first);impl_->first=nullptr;
    if(impl_->file!=INVALID_HANDLE_VALUE)CloseHandle(impl_->file);impl_->file=INVALID_HANDLE_VALUE;
    impl_->info={};impl_->raw.clear();
}
const DeviceInfo& WinUsbTransport::Device()const{return impl_->info;}
const std::vector<uint8_t>& WinUsbTransport::RawConfiguration()const{return impl_->raw;}
const std::string& WinUsbTransport::Error()const{return impl_->error;}
}

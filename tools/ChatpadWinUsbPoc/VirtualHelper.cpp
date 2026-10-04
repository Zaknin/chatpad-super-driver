#include "VirtualHelper.h"
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <atomic>
#include <chrono>
#include <condition_variable>
#include <filesystem>
#include <map>
#include <mutex>
#include <sstream>
#include <thread>

namespace chatpad {
namespace {
struct Value { enum Type { String,Number,Boolean,Null } type{Null};std::string string;uint32_t number{};bool boolean{}; };
class Parser {
public:
    explicit Parser(const std::string& input):s(input){}
    bool Object(std::map<std::string,Value>& fields) {
        Space();if(!Take('{'))return false;Space();if(Take('}'))return End();
        while(true) {
            std::string key;Value value;if(!String(key))return false;Space();if(!Take(':'))return false;Space();
            if(pos<s.size()&&s[pos]=='"'){value.type=Value::String;if(!String(value.string))return false;}
            else if(Token("true")){value.type=Value::Boolean;value.boolean=true;}
            else if(Token("false")){value.type=Value::Boolean;}
            else if(Token("null")){value.type=Value::Null;}
            else {value.type=Value::Number;if(!Number(value.number))return false;}
            if(!fields.emplace(key,std::move(value)).second)return false;
            Space();if(Take('}'))return End();if(!Take(','))return false;Space();
        }
    }
private:
    const std::string& s;size_t pos{};
    void Space(){while(pos<s.size()&&(s[pos]==' '||s[pos]=='\t'||s[pos]=='\r'||s[pos]=='\n'))++pos;}
    bool End(){Space();return pos==s.size();}
    bool Take(char c){if(pos<s.size()&&s[pos]==c){++pos;return true;}return false;}
    bool Token(const char* text){size_t n=std::char_traits<char>::length(text);if(s.compare(pos,n,text)!=0)return false;pos+=n;return true;}
    bool Number(uint32_t& value) {
        if(pos==s.size()||s[pos]<'0'||s[pos]>'9')return false;
        bool zero=s[pos]=='0';uint64_t n=0;size_t begin=pos;
        while(pos<s.size()&&s[pos]>='0'&&s[pos]<='9'){n=n*10+unsigned(s[pos++]-'0');if(n>UINT32_MAX)return false;}
        if(zero&&pos-begin>1)return false;value=static_cast<uint32_t>(n);return true;
    }
    bool Hex(uint32_t& result) {
        result=0;for(unsigned i=0;i<4;++i){if(pos==s.size())return false;unsigned char c=static_cast<unsigned char>(s[pos++]);unsigned v;
            if(c>='0'&&c<='9')v=c-'0';else if(c>='a'&&c<='f')v=c-'a'+10;else if(c>='A'&&c<='F')v=c-'A'+10;else return false;
            result=result*16+v;}return true;
    }
    static void Utf8(std::string& result,uint32_t rune) {
        if(rune<0x80)result.push_back(static_cast<char>(rune));
        else if(rune<0x800){result.push_back(static_cast<char>(0xc0|(rune>>6)));result.push_back(static_cast<char>(0x80|(rune&63)));}
        else if(rune<0x10000){result.push_back(static_cast<char>(0xe0|(rune>>12)));result.push_back(static_cast<char>(0x80|((rune>>6)&63)));result.push_back(static_cast<char>(0x80|(rune&63)));}
        else {result.push_back(static_cast<char>(0xf0|(rune>>18)));result.push_back(static_cast<char>(0x80|((rune>>12)&63)));result.push_back(static_cast<char>(0x80|((rune>>6)&63)));result.push_back(static_cast<char>(0x80|(rune&63)));}
    }
    bool String(std::string& result) {
        if(!Take('"'))return false;
        while(pos<s.size()) {
            unsigned char c=static_cast<unsigned char>(s[pos++]);if(c=='"')return true;if(c<0x20)return false;
            if(c=='\\') {
                if(pos==s.size())return false;char esc=s[pos++];
                switch(esc){case '"':case '\\':case '/':result.push_back(esc);break;
                case 'b':result.push_back('\b');break;case 'f':result.push_back('\f');break;case 'n':result.push_back('\n');break;case 'r':result.push_back('\r');break;case 't':result.push_back('\t');break;
                case 'u':{uint32_t rune;if(!Hex(rune))return false;if(rune>=0xd800&&rune<=0xdbff){uint32_t low;if(!Take('\\')||!Take('u')||!Hex(low)||low<0xdc00||low>0xdfff)return false;rune=0x10000+((rune-0xd800)<<10)+(low-0xdc00);}else if(rune>=0xdc00&&rune<=0xdfff)return false;Utf8(result,rune);break;}
                default:return false;}
            } else if(c>=0x80) {
                unsigned extra;uint32_t rune,minimum;
                if(c>=0xc2&&c<=0xdf){extra=1;rune=c&31;minimum=0x80;}else if(c>=0xe0&&c<=0xef){extra=2;rune=c&15;minimum=0x800;}else if(c>=0xf0&&c<=0xf4){extra=3;rune=c&7;minimum=0x10000;}else return false;
                for(unsigned n=0;n<extra;++n){if(pos==s.size())return false;unsigned char tail=static_cast<unsigned char>(s[pos++]);if((tail&0xc0)!=0x80)return false;rune=(rune<<6)|(tail&63);}
                if(rune<minimum||rune>0x10ffff||(rune>=0xd800&&rune<=0xdfff))return false;Utf8(result,rune);
            } else result.push_back(static_cast<char>(c));
        }
        return false;
    }
};
bool GetString(const std::map<std::string,Value>& fields,const char* key,std::string& out) {
    auto it=fields.find(key);if(it==fields.end()||it->second.type!=Value::String)return false;out=it->second.string;return true;
}
bool Motor(const std::map<std::string,Value>& fields,const char* key,uint16_t& out) {
    auto it=fields.find(key);if(it==fields.end()||it->second.type!=Value::Number||it->second.number>65535)return false;out=static_cast<uint16_t>(it->second.number);return true;
}
bool Operation(const std::string& op){return op=="create"||op=="submit"||op=="disconnect"||op=="quit";}
void Close(HANDLE& handle){if(handle&&handle!=INVALID_HANDLE_VALUE)CloseHandle(handle);handle=nullptr;}
}
bool ParseHelperMessage(const std::string& json,HelperMessage& out) {
    out={};if(json.size()>4096)return false;std::map<std::string,Value> fields;Parser parser(json);if(!parser.Object(fields))return false;
    if(fields.count("event")) {
        std::string event;if(fields.size()!=3||!GetString(fields,"event",event)||event!="rumble"||!Motor(fields,"leftMotor",out.leftMotor)||!Motor(fields,"rightMotor",out.rightMotor))return false;
        out.kind=HelperMessageKind::Rumble;return true;
    }
    for(const auto& field:fields)if(field.first!="id"&&field.first!="ok"&&field.first!="operation"&&field.first!="error"&&field.first!="detail")return false;
    auto id=fields.find("id"),ok=fields.find("ok");if(id==fields.end()||ok==fields.end()||ok->second.type!=Value::Boolean)return false;
    if(id->second.type==Value::Number&&id->second.number<=INT32_MAX){out.hasId=true;out.id=id->second.number;}
    else if(id->second.type!=Value::Null)return false;
    out.ok=ok->second.boolean;
    if(out.ok) {if(!out.hasId||fields.size()!=3||!GetString(fields,"operation",out.operation)||!Operation(out.operation))return false;}
    else {if(fields.count("operation")||!GetString(fields,"error",out.error)||out.error.empty())return false;
        if(fields.count("detail")&&!GetString(fields,"detail",out.detail))return false;}
    return true;
}
struct VirtualHelperController::Impl {
    explicit Impl(HelperOptions value):options(std::move(value)){}
    HelperOptions options;
    HANDLE process{},input{},output{};
    std::thread reader;
    std::atomic<bool> stop{};
    std::mutex mutex,requestMutex;
    std::condition_variable condition;
    std::string error;
    RumbleCallback callback;
    HelperMessage response;
    bool gotResponse{},fault{},connected{};
    uint32_t nextId{};
    void Fail(const std::string& value){std::lock_guard<std::mutex> lock(mutex);if(!fault)error=value;fault=true;condition.notify_all();}
    void ReadLoop() {
        std::string line;
        while(!stop.load()) {
            DWORD available{};
            if(!PeekNamedPipe(output,nullptr,0,nullptr,&available,nullptr)){if(!stop.load())Fail("helper_output_closed:"+std::to_string(GetLastError()));return;}
            if(!available){std::this_thread::sleep_for(std::chrono::milliseconds(5));continue;}
            char bytes[4096];DWORD read{};
            if(!ReadFile(output,bytes,(std::min)(available,DWORD(sizeof(bytes))),&read,nullptr)||!read){Fail("helper_read_failed:"+std::to_string(GetLastError()));return;}
            for(DWORD i=0;i<read;++i) {
                if(bytes[i]!='\n'){line.push_back(bytes[i]);if(line.size()>4096){Fail("helper_line_too_long");return;}continue;}
                if(!line.empty()&&line.back()=='\r')line.pop_back();HelperMessage message;
                if(!ParseHelperMessage(line,message)){Fail("invalid_helper_response");return;}line.clear();
                if(message.kind==HelperMessageKind::Rumble) {
                    RumbleCallback copied;{std::lock_guard<std::mutex> lock(mutex);copied=callback;}
                    if(copied&&!stop.load()) {try{copied(message.leftMotor,message.rightMotor);}catch(...){Fail("rumble_callback_failed");return;}}
                } else {
                    std::lock_guard<std::mutex> lock(mutex);
                    if(!message.hasId){error=message.error;fault=true;}else if(gotResponse){error="duplicate_helper_response";fault=true;}else{response=std::move(message);gotResponse=true;}
                    condition.notify_all();
                }
            }
        }
    }
    bool Launch() {
        {std::lock_guard<std::mutex> lock(mutex);error.clear();fault=false;gotResponse=false;}
        if(options.requestTimeoutMs<1||options.requestTimeoutMs>1000||options.createTimeoutMs<1||options.createTimeoutMs>30000||options.durationMs<1||options.durationMs>604800000||
            (options.backend!="mock"&&options.backend!="unavailable"&&options.backend!="hidmaestro")||
            (options.backend=="hidmaestro"&&!options.allowLiveVirtual)||options.executable.find(L'"')!=std::wstring::npos||
            options.executable.find(L'\n')!=std::wstring::npos||options.executable.find(L'\r')!=std::wstring::npos||
            !std::filesystem::path(options.executable).is_absolute()) {Fail("invalid_or_unauthorized_helper_options");return false;}
        SECURITY_ATTRIBUTES security{sizeof(security),nullptr,TRUE};HANDLE childInput{},childOutput{},childError{};
        if(!CreatePipe(&childInput,&input,&security,4096)||!CreatePipe(&output,&childOutput,&security,4096)) {
            Fail("helper_pipe_create_failed:"+std::to_string(GetLastError()));Close(childInput);Close(childOutput);Close(input);Close(output);return false;
        }
        SetHandleInformation(input,HANDLE_FLAG_INHERIT,0);SetHandleInformation(output,HANDLE_FLAG_INHERIT,0);
        // Retain SDK/helper diagnostics on the parent's stderr; JSON remains stdout-only.
        if(!DuplicateHandle(GetCurrentProcess(),GetStdHandle(STD_ERROR_HANDLE),GetCurrentProcess(),&childError,0,TRUE,DUPLICATE_SAME_ACCESS)) {
            Fail("helper_stderr_handle_failed:"+std::to_string(GetLastError()));Close(childInput);Close(childOutput);Close(input);Close(output);return false;
        }
        STARTUPINFOW startup{};startup.cb=sizeof(startup);startup.dwFlags=STARTF_USESTDHANDLES;startup.hStdInput=childInput;startup.hStdOutput=childOutput;startup.hStdError=childError;
        std::wstring backend(options.backend.begin(),options.backend.end());
        std::wstring command=L"\""+options.executable+L"\" helper --backend "+backend+L" --duration-ms "+std::to_wstring(options.durationMs)+L" --idle-ms "+std::to_wstring((std::min)(options.durationMs,5000u));
        if(options.backend=="hidmaestro")command+=L" --allow-live-virtual";
        PROCESS_INFORMATION child{};
        BOOL launched=CreateProcessW(options.executable.c_str(),command.data(),nullptr,nullptr,TRUE,CREATE_NO_WINDOW,nullptr,nullptr,&startup,&child);
        DWORD err=GetLastError();Close(childInput);Close(childOutput);Close(childError);
        if(!launched){Fail("helper_launch_failed:"+std::to_string(err));Close(input);Close(output);return false;}
        CloseHandle(child.hThread);process=child.hProcess;stop=false;nextId=0;reader=std::thread([this]{ReadLoop();});return true;
    }
    bool Request(const std::string& operation,const std::string& fields={},uint32_t timeoutMs=0) {
        std::lock_guard<std::mutex> requestLock(requestMutex);
        if(!process)return false;
        uint32_t id=nextId++;
        {std::lock_guard<std::mutex> lock(mutex);if(fault)return false;gotResponse=false;}
        std::string request="{\"id\":"+std::to_string(id)+",\"op\":\""+operation+"\""+fields+"}\n";
        // One small request is outstanding. The 4096-byte pipe can always hold this
        // <=256-byte request; a failed/timed-out session accepts no further writes.
        if(request.size()>256){Fail("helper_request_too_long");return false;}
        DWORD written{};if(!WriteFile(input,request.data(),static_cast<DWORD>(request.size()),&written,nullptr)||written!=request.size()){Fail("helper_write_failed:"+std::to_string(GetLastError()));return false;}
        std::unique_lock<std::mutex> lock(mutex);
        const uint32_t effectiveTimeout=timeoutMs?timeoutMs:options.requestTimeoutMs;
        if(!condition.wait_for(lock,std::chrono::milliseconds(effectiveTimeout),[this]{return gotResponse||fault;})){error="helper_request_timeout";fault=true;return false;}
        if(fault)return false;
        if(!response.hasId||response.id!=id||(response.ok&&response.operation!=operation)){error="helper_response_correlation_failed";fault=true;return false;}
        if(!response.ok){error=response.error+(response.detail.empty()?"":":"+response.detail);return false;}
        return true;
    }
    void DisposeProcess() {
        stop=true;
        {std::lock_guard<std::mutex> lock(mutex);callback={};}
        Close(input);
        if(process&&WaitForSingleObject(process,250)==WAIT_TIMEOUT){TerminateProcess(process,4);WaitForSingleObject(process,1000);}
        if(reader.joinable())reader.join();
        Close(output);Close(process);connected=false;
    }
};
VirtualHelperController::VirtualHelperController(HelperOptions options):impl_(std::make_unique<Impl>(std::move(options))){}
VirtualHelperController::~VirtualHelperController(){Disconnect();}
bool VirtualHelperController::Create() {
    if(impl_->connected)return false;
    if(impl_->process)impl_->DisposeProcess();
    if(!impl_->Launch())return false;
    if(!impl_->Request("create",{},impl_->options.createTimeoutMs)){impl_->DisposeProcess();return false;}
    impl_->connected=true;return true;
}
bool VirtualHelperController::SubmitState(const XboxState& state) {
    if(!impl_->connected)return false;
    std::ostringstream fields;
    fields<<",\"buttons\":"<<state.buttons<<",\"leftTrigger\":"<<unsigned(state.leftTrigger)<<",\"rightTrigger\":"<<unsigned(state.rightTrigger)
        <<",\"lx\":"<<state.lx<<",\"ly\":"<<state.ly<<",\"rx\":"<<state.rx<<",\"ry\":"<<state.ry;
    return impl_->Request("submit",fields.str());
}
void VirtualHelperController::SetRumbleCallback(RumbleCallback callback){std::lock_guard<std::mutex> lock(impl_->mutex);impl_->callback=std::move(callback);}
void VirtualHelperController::Disconnect() {
    if(!impl_->process)return;
    SetRumbleCallback({});
    if(impl_->connected)impl_->Request("disconnect");
    impl_->Request("quit");impl_->DisposeProcess();
}
std::string VirtualHelperController::LastError() const {std::lock_guard<std::mutex> lock(impl_->mutex);return impl_->error;}
}

#pragma once
#include <cstdint>
#include <string>
namespace chatpad {
enum class SessionCommand { Activate, CreateVirtual, EnableMapping, EnableRumble, EnableKeyboard, Stop };
struct SessionRequest { uint32_t id{}; SessionCommand command{}; };
bool ParseSessionRequest(const std::string&,SessionRequest&);
const char* SessionCommandName(SessionCommand);
class SessionPolicy {
public:
    void ObserveController(){controller_=true;}
    void ObserveFiveBytes(bool keyEnableSucceeded){if(activated_&&keyEnableSucceeded)fiveBytes_=true;}
    bool Allowed(SessionCommand)const;
    bool AcceptRequestId(uint32_t id){if(!id||id<=previousId_)return false;previousId_=id;return true;}
    void Commit(SessionCommand);
    bool Activated()const{return activated_;}
    bool Mapping()const{return mapping_;}
    bool VirtualCreated()const{return virtual_;}
    bool Rumble()const{return rumble_;}
    bool Keyboard()const{return keyboard_;}
private:
    uint32_t previousId_{};
    bool controller_{},activated_{},fiveBytes_{},virtual_{},mapping_{},rumble_{},keyboard_{},stopped_{};
};
}

#include "SessionPolicy.h"
#include <regex>
#include <limits>
namespace chatpad {
const char* SessionCommandName(SessionCommand value){
    switch(value){case SessionCommand::Activate:return "activate";case SessionCommand::CreateVirtual:return "create-virtual";
    case SessionCommand::EnableMapping:return "enable-mapping";case SessionCommand::EnableRumble:return "enable-rumble";
    case SessionCommand::EnableKeyboard:return "enable-keyboard";case SessionCommand::Stop:return "stop";}return "invalid";
}
bool ParseSessionRequest(const std::string& text,SessionRequest& out){
    out={};if(text.size()>128)return false;
    static const std::regex shape(R"re(^\s*\{\s*"id"\s*:\s*([1-9][0-9]{0,9})\s*,\s*"command"\s*:\s*"([a-z-]+)"\s*\}\s*$)re");
    std::smatch match;if(!std::regex_match(text,match,shape))return false;
    const auto id=std::stoull(match[1].str());if(id>std::numeric_limits<uint32_t>::max())return false;
    for(auto command:{SessionCommand::Activate,SessionCommand::CreateVirtual,SessionCommand::EnableMapping,
        SessionCommand::EnableRumble,SessionCommand::EnableKeyboard,SessionCommand::Stop}){
        if(match[2].str()==SessionCommandName(command)){out={static_cast<uint32_t>(id),command};return true;}
    }return false;
}
bool SessionPolicy::Allowed(SessionCommand value)const{
    if(stopped_)return false;
    if(value==SessionCommand::Stop)return true;
    if(value==SessionCommand::Activate)return controller_&&!activated_;
    if(value==SessionCommand::CreateVirtual)return activated_&&fiveBytes_&&!virtual_;
    if(value==SessionCommand::EnableMapping)return virtual_&&!mapping_;
    if(value==SessionCommand::EnableRumble)return mapping_&&!rumble_;
    if(value==SessionCommand::EnableKeyboard)return rumble_&&!keyboard_;
    return false;
}
void SessionPolicy::Commit(SessionCommand value){
    if(!Allowed(value))return;
    switch(value){case SessionCommand::Activate:activated_=true;break;case SessionCommand::CreateVirtual:virtual_=true;break;
    case SessionCommand::EnableMapping:mapping_=true;break;case SessionCommand::EnableRumble:rumble_=true;break;
    case SessionCommand::EnableKeyboard:keyboard_=true;break;case SessionCommand::Stop:stopped_=true;break;}
}
}

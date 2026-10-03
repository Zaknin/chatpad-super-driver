#include "KeyboardOutput.h"
#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#endif
namespace chatpad {
bool UsageToScanCode(uint8_t usage,ScanCode& out) {
    out={};
    static constexpr uint8_t letters[]{0x1e,0x30,0x2e,0x20,0x12,0x21,0x22,0x23,0x17,0x24,0x25,0x26,0x32,0x31,0x18,0x19,0x10,0x13,0x1f,0x14,0x16,0x2f,0x11,0x2d,0x15,0x2c};
    if(usage>=4 && usage<=0x1d) {out.code=letters[usage-4];return true;}
    if(usage>=0x1e && usage<=0x27) {out.code=static_cast<uint16_t>(usage-0x1e+2);return true;}
    if(usage>=0x3a && usage<=0x43) {out.code=static_cast<uint16_t>(usage-0x3a+0x3b);return true;}
    switch(usage) {
    case 0x28:out={0x1c,false};break;
    case 0x29:out={0x01,false};break;
    case 0x2a:out={0x0e,false};break;
    case 0x2b:out={0x0f,false};break;
    case 0x2c:out={0x39,false};break;
    case 0x2d:out={0x0c,false};break;
    case 0x2e:out={0x0d,false};break;
    case 0x2f:out={0x1a,false};break;
    case 0x30:out={0x1b,false};break;
    case 0x31:out={0x2b,false};break;
    case 0x33:out={0x27,false};break;
    case 0x34:out={0x28,false};break;
    case 0x35:out={0x29,false};break;
    case 0x36:out={0x33,false};break;
    case 0x37:out={0x34,false};break;
    case 0x38:out={0x35,false};break;
    case 0x39:out={0x3a,false};break;
    case 0x44:out={0x57,false};break;
    case 0x45:out={0x58,false};break;
    case 0x49:out={0x52,true};break;
    case 0x4a:out={0x47,true};break;
    case 0x4b:out={0x49,true};break;
    case 0x4c:out={0x53,true};break;
    case 0x4d:out={0x4f,true};break;
    case 0x4e:out={0x51,true};break;
    case 0x4f:out={0x4d,true};break;
    case 0x50:out={0x4b,true};break;
    case 0x51:out={0x50,true};break;
    case 0x52:out={0x48,true};break;
    case 0x64:out={0x56,false};break;
    case 0x65:out={0x5d,true};break;
    case 0xe0:out={0x1d,false};break;
    case 0xe1:out={0x2a,false};break;
    case 0xe2:out={0x38,false};break;
    case 0xe3:out={0x5b,true};break;
    case 0xe4:out={0x1d,true};break;
    case 0xe5:out={0x36,false};break;
    case 0xe6:out={0x38,true};break;
    case 0xe7:out={0x5c,true};break;
    default:return false;
    }
    return true;
}
SendInputKeyboardOutput::~SendInputKeyboardOutput() { ForceRelease(); }
bool SendInputKeyboardOutput::Send(uint8_t usage,bool down) {
    ScanCode scan;if(!UsageToScanCode(usage,scan))return false;
#ifdef _WIN32
    INPUT input{};input.type=INPUT_KEYBOARD;input.ki.wScan=scan.code;
    input.ki.dwFlags=KEYEVENTF_SCANCODE|(scan.extended?KEYEVENTF_EXTENDEDKEY:0)|(down?0:KEYEVENTF_KEYUP);
    if(SendInput(1,&input,sizeof(input))!=1)return false;
    held_[usage]=down;return true;
#else
    (void)down;return false;
#endif
}
bool SendInputKeyboardOutput::ForceRelease() {
    bool success=true;
    for(unsigned usage=1;usage<0xe0;++usage)if(held_[usage]&&!Send(static_cast<uint8_t>(usage),false))success=false;
    for(unsigned usage=0xe0;usage<256;++usage)if(held_[usage]&&!Send(static_cast<uint8_t>(usage),false))success=false;
    return success;
}
KeyboardMapper::KeyboardMapper(IKeyboardOutput& output):output_(output) {
    ChatpadBuildDefaultConfiguration(&configuration_);ChatpadInitializeLayeredMappingState(&state_);
}
KeyboardMapper::~KeyboardMapper() { ForceRelease(); }
bool KeyboardMapper::Apply(const ChatpadHidKeyboardReport& report) {
    std::array<bool,256> wanted{};
    for(unsigned bit=0;bit<8;++bit)if(report.Bytes[0]&(1u<<bit))wanted[0xe0+bit]=true;
    for(unsigned byte=2;byte<8;++byte)if(report.Bytes[byte])wanted[report.Bytes[byte]]=true;
    // Release ordinary keys before their modifier chord. Stop new presses if any release fails.
    for(unsigned pass=0;pass<2;++pass) {
        bool released=true;
        const unsigned begin=pass==0?1:0xe0,end=pass==0?0xe0:256;
        for(unsigned usage=begin;usage<end;++usage)if(held_[usage]&&!wanted[usage]) {
            if(output_.Send(static_cast<uint8_t>(usage),false))held_[usage]=false;
            else released=false;
        }
        if(!released)return false;
    }
    for(unsigned pass=0;pass<2;++pass) {
        unsigned begin=pass==0?0xe0:1,end=pass==0?256:0xe0;
        for(unsigned usage=begin;usage<end;++usage)if(wanted[usage]&&!held_[usage]) {
            if(!output_.Send(static_cast<uint8_t>(usage),true))return false;
            held_[usage]=true;
        }
    }
    report_=report;return true;
}
bool KeyboardMapper::Process(const uint8_t* data,size_t size) {
    if(ChatpadParseKeyboardPacket(data,size,&packet_)!=CHATPAD_PARSE_OK) { ForceRelease();return false; }
    ChatpadHidKeyboardReport target{};
    if(ChatpadMapKeyboardPacketWithConfiguration(&packet_,&configuration_,&state_,&target)!=CHATPAD_HID_MAP_OK) { ForceRelease();return false; }
    return Apply(target);
}
bool KeyboardMapper::ForceRelease() {
    ChatpadInitializeLayeredMappingState(&state_);report_={};
    bool released=true;
    for(unsigned usage=1;usage<256;++usage)if(held_[usage]) {
        if(output_.Send(static_cast<uint8_t>(usage),false))held_[usage]=false;
        else released=false;
    }
    const bool underlying=output_.ForceRelease();
    // A successful output-level release also covers any locally failed key-up.
    if(underlying)held_.fill(false);
    return released&&underlying;
}
}

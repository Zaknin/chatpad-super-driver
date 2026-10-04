#include "KeyboardOutput.h"
#include <iostream>
#include <set>
using namespace chatpad;
int main(){
    const auto scans=SupportedChatpadScanCodes();
    std::set<unsigned> unique;
    for(const auto& scan:scans)unique.insert((unsigned(scan.code)<<1)|(scan.extended?1u:0u));
    const bool passed=scans.size()>50&&scans.size()==unique.size()&&
        unique.count((unsigned(0x1e)<<1))==1&&unique.count((unsigned(0x2a)<<1))==1;
    std::cout<<"supported_scancodes="<<scans.size()<<" unique="<<unique.size()<<"\n";
    return passed?0:1;
}

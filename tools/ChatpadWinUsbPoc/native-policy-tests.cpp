#include "BridgeCore.h"
#include <cstring>
#include <iostream>
using namespace chatpad;
namespace {
unsigned checks{}, failed{};
void Check(bool value,const char* label) {
    ++checks;if(!value){++failed;std::cerr<<"FAIL: "<<label<<'\n';}
}
class Transport final : public IPhysicalTransport {
public:
    size_t rejectAt{99}, calls{};
    TransferResult rejection{TransferStatus::Error,31,0};
    std::vector<DeviceInfo> Enumerate() override {return {};}
    TransferResult Open(const std::string&) override {return {};}
    std::vector<InterfaceInfo> Interfaces() override {return {};}
    TransferResult Control(const ControlRequest& setup,std::vector<uint8_t>& input,uint32_t timeout) override {
        Check(timeout==1000,"finite 1000ms control");
        auto value=calls++==rejectAt?rejection:TransferResult{TransferStatus::Ok,0,setup.length};
        input.assign((setup.requestType&0x80)?value.transferred:0,0);return value;
    }
    TransferResult Read(uint8_t,uint8_t,std::vector<uint8_t>&,uint32_t) override {return {};}
    TransferResult Write(uint8_t,uint8_t,const std::vector<uint8_t>&,uint32_t) override {return {};}
    void Cancel() override {}
    void Close() override {}
};
ActivationResult Run(Transport& transport) {
    return ActivationRunner{ActivationPolicy::NativeProbeRejection}.Run(transport,[](uint32_t){});
}
void ActivationCases() {
    Transport success;auto ok=Run(success);
    Check(ok.success&&ok.completedSteps==6,"successful probe and strict stages");
    Check(std::strcmp(ActivationDisposition(ok.events[0]),"SUCCESS")==0&&ok.events[0].optionalProbe&&
          !ok.events[4].optionalProbe&&!ok.events[5].optionalProbe,"stage metadata preserves strict boundary");
    for(size_t step=0;step<4;++step){
        Transport probe;probe.rejectAt=step;auto result=Run(probe);
        Check(result.success&&result.events[step].probeRejected&&!result.events[step].expectedStall,
              "optional probe31 continues without STALL claim");
        Check(result.events[step].result.status==TransferStatus::Error&&result.events[step].result.win32Error==31,
              "retain raw Error31 evidence");
        Check(std::strcmp(ActivationDisposition(result.events[step]),"PROBE_REJECTED")==0,
              "human disposition explicitly says PROBE_REJECTED");
    }
    for(size_t step=0;step<6;++step){
        for(auto status:{TransferStatus::DeviceNotPresent,TransferStatus::AccessDenied,TransferStatus::Timeout,TransferStatus::Cancelled}){
            Transport failure;failure.rejectAt=step;failure.rejection={status,31,0};auto result=Run(failure);
            Check(!result.success&&failure.calls==step+1,"removed denied timeout cancelled always fatal");
        }
    }
    for(size_t step:{size_t(4),size_t(5)}){
        Transport strict;strict.rejectAt=step;auto result=Run(strict);
        Check(!result.success&&strict.calls==step+1,"strict write and final probe31 fatal");
        Check(std::strcmp(ActivationDisposition(result.events.back()),"FATAL")==0,"strict rejection logs FATAL");
    }
    for(size_t step=0;step<4;++step){
        Transport partial;partial.rejectAt=step;partial.rejection.transferred=1;
        Check(!Run(partial).success,"probe31 with transferred bytes fatal");
        Transport other;other.rejectAt=step;other.rejection.win32Error=87;
        Check(!Run(other).success,"other probe rejection is not permitted");
    }
    Transport retained;retained.rejectAt=0;
    Check(!ActivationRunner{}.Run(retained,[](uint32_t){}).success,"portable default remains strict on ambiguous31");
    Transport oneShot;ActivationRunner runner{ActivationPolicy::NativeProbeRejection};
    Check(runner.Run(oneShot,[](uint32_t){}).success&&!runner.Run(oneShot,[](uint32_t){}).success&&oneShot.calls==6,
          "native policy never retries");
}
void KeyDataCases() {
    Transport success;ChatpadMaintenance ready(success);
    Check(ready.Start(0)&&ready.OnCompletePacket(5)&&ready.Active(),"key enable succeeds only exact zero-byte success");
    for(auto value:{TransferResult{TransferStatus::Error,31,0},TransferResult{TransferStatus::Timeout,121,0},
                   TransferResult{TransferStatus::DeviceNotPresent,1167,0},TransferResult{TransferStatus::AccessDenied,5,0},
                   TransferResult{TransferStatus::Ok,0,1}}){
        Transport failure;failure.rejectAt=1;failure.rejection=value;ChatpadMaintenance maintenance(failure);
        Check(maintenance.Start(0)&&!maintenance.OnCompletePacket(5)&&!maintenance.Active()&&maintenance.KeyDataAttempted(),
              "key enable failure strict and disables maintenance");
        Check(!maintenance.OnCompletePacket(5)&&failure.calls==2,"key enable failure never retries");
    }
}
}
int main(){ActivationCases();KeyDataCases();std::cout<<checks<<" checks, "<<failed<<" failures\n";return failed?1:0;}

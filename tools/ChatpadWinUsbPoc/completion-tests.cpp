#include "CompletionPolicy.h"
#include <iostream>
using namespace chatpad;
struct Fake final:IAsyncCompletion {
    WaitOutcome wait{WaitOutcome::Complete};bool drains{true};unsigned cancelled{},drainCalls{};
    TransferResult result{TransferStatus::Ok,0,20};
    WaitOutcome Wait(uint32_t)override{return wait;}void Cancel()override{++cancelled;}
    bool Drain(uint32_t)override{++drainCalls;return drains;}TransferResult Result()override{return result;}
};
int main(){unsigned passed=0,failed=0;auto check=[&](bool b){++(b?passed:failed);};
    Fake f;auto r=CompletePending(f,1000);check(r.result.status==TransferStatus::Ok && r.result.transferred==20 && f.cancelled==0 && r.storageSafe);
    f.wait=WaitOutcome::Timeout;r=CompletePending(f,1000);check(r.result.status==TransferStatus::Timeout && f.cancelled==1 && f.drainCalls==1 && r.storageSafe);
    f.wait=WaitOutcome::Cancelled;r=CompletePending(f,1000);check(r.result.status==TransferStatus::Cancelled && r.storageSafe);
    f.wait=WaitOutcome::Failed;r=CompletePending(f,1000);check(r.result.status==TransferStatus::Error && r.storageSafe);
    f.drains=false; r=CompletePending(f,1000);check(!r.storageSafe && r.result.status==TransferStatus::Error);
    f.wait=WaitOutcome::Complete;f.result={TransferStatus::DeviceNotPresent,1167,0};r=CompletePending(f,1000);check(r.storageSafe && r.result.status==TransferStatus::DeviceNotPresent);
    f.result={TransferStatus::Cancelled,995,0};r=CompletePending(f,1000);check(r.result.status==TransferStatus::Cancelled);
    f.result={TransferStatus::AccessDenied,5,0};r=CompletePending(f,1000);check(r.result.status==TransferStatus::AccessDenied);
    std::cout<<"{\"suite\":\"NativeCompletion\",\"passed\":"<<passed<<",\"failed\":"<<failed<<"}\n";return failed?1:0;
}

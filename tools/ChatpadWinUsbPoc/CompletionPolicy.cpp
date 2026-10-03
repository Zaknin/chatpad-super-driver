#include "CompletionPolicy.h"
namespace chatpad {
CompletionOutcome CompletePending(IAsyncCompletion& io,uint32_t timeoutMs){
    const auto waited=io.Wait(timeoutMs);
    if(waited==WaitOutcome::Complete)return {io.Result(),true};
    io.Cancel();
    if(!io.Drain(2000))return {{TransferStatus::Error,1460,0},false};
    auto result=io.Result();
    if(waited==WaitOutcome::Timeout){result.status=TransferStatus::Timeout;result.win32Error=1460;}
    else if(waited==WaitOutcome::Cancelled){result.status=TransferStatus::Cancelled;result.win32Error=995;}
    else {result.status=TransferStatus::Error;if(result.win32Error==0)result.win32Error=6;}
    return {result,true};
}
}

#pragma once
#include "BridgeCore.h"
namespace chatpad {
enum class WaitOutcome { Complete, Timeout, Cancelled, Failed };
class IAsyncCompletion {
public:
    virtual ~IAsyncCompletion()=default;
    virtual WaitOutcome Wait(uint32_t timeoutMs)=0;
    virtual void Cancel()=0;
    virtual bool Drain(uint32_t timeoutMs)=0;
    virtual TransferResult Result()=0;
};
struct CompletionOutcome { TransferResult result; bool storageSafe{true}; };
CompletionOutcome CompletePending(IAsyncCompletion&,uint32_t timeoutMs);
}

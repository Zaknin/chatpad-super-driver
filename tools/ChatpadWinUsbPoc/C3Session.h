#pragma once
#include "BridgeCore.h"
#include "VirtualHelper.h"
#include <atomic>
namespace chatpad {
// Future C3 only. stdin/stdout are bounded command/evidence pipes; no C2R1 invocation.
int RunC3Session(IPhysicalTransport&,const HelperOptions&,unsigned seconds,std::atomic<bool>& stop);
}

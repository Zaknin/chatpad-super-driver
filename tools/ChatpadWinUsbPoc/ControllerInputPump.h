#pragma once
#include "BridgeCore.h"
#include <chrono>
#include <functional>
#include <mutex>
#include <thread>

namespace chatpad {
class ControllerInputPump final {
public:
    using StateSink=std::function<bool(const XboxState&)>;
    ControllerInputPump(IPhysicalTransport& transport,const XboxState& initial);
    ~ControllerInputPump();
    ControllerInputPump(const ControllerInputPump&)=delete;
    ControllerInputPump& operator=(const ControllerInputPump&)=delete;
    bool Start();
    bool SetStateSink(StateSink sink);
    void Stop();
    bool Failed() const;
    uint32_t FailureWin32() const;
    uint64_t ReportCount() const;
    uint64_t SubmissionCount() const;
private:
    void Run();
    bool SubmitLocked(const XboxState& state);
    IPhysicalTransport& transport_;
    mutable std::mutex mutex_;
    XboxState latest_{};
    StateSink sink_;
    std::thread thread_;
    std::atomic<bool> stopping_{false};
    bool started_{},failed_{};
    uint32_t failureWin32_{};
    uint64_t reports_{},submissions_{};
    std::chrono::steady_clock::time_point lastSubmission_{};
};
}

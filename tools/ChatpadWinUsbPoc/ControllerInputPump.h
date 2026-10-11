#pragma once
#include "BridgeCore.h"
#include <chrono>
#include <functional>
#include <mutex>
#include <thread>

namespace chatpad {
struct ControllerInputPumpDiagnostics {
    uint64_t readAttempts{}, successfulReadCompletions{}, controllerReports{}, changingControllerReports{};
    uint64_t nonControllerStatusPackets{}, invalidPackets{}, timeoutCompletions{}, timeout1460Completions{}, transferFailures{};
    uint32_t lastTimeoutWin32{}, lastFailureWin32{};
    TransferStatus lastFailureStatus{TransferStatus::Error};
};
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
    TransferStatus FailureStatus() const;
    uint64_t ReportCount() const;
    uint64_t SubmissionCount() const;
    ControllerInputPumpDiagnostics Diagnostics() const;
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
    TransferStatus failureStatus_{TransferStatus::Error};
    uint32_t failureWin32_{};
    uint64_t reports_{},submissions_{};
    ControllerInputPumpDiagnostics diagnostics_{};
    std::chrono::steady_clock::time_point lastSubmission_{};
};
}

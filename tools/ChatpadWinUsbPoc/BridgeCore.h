#pragma once
#include <cstddef>
#include <atomic>
#include <cstdint>
#include <functional>
#include <string>
#include <mutex>
#include <utility>
#include <vector>

namespace chatpad {
struct XboxState {
    uint16_t buttons{};
    uint8_t leftTrigger{}, rightTrigger{};
    int16_t lx{}, ly{}, rx{}, ry{};
};
bool ParseController(const uint8_t* data, size_t size, XboxState& out);
std::vector<uint8_t> BuildRumble(uint16_t left, uint16_t right);
std::vector<uint8_t> BuildPlayerLed(uint8_t pattern);
enum class TransferStatus { Ok, Stall, Timeout, Cancelled, AccessDenied, DeviceNotPresent, Error };
struct TransferResult {
    TransferStatus status{TransferStatus::Error};
    uint32_t win32Error{};
    size_t transferred{};
};
struct EndpointInfo { uint8_t address{}, type{}; uint16_t maxPacketSize{}; };
struct InterfaceInfo { uint8_t number{}, alternateSetting{}; std::vector<EndpointInfo> endpoints; };
struct DeviceInfo {
    std::string path, instanceId;
    uint16_t vid{}, pid{};
    uint8_t configuration{};
    std::vector<InterfaceInfo> interfaces;
};
struct ControlRequest {
    uint8_t requestType{}, request{};
    uint16_t value{}, index{}, length{};
    std::vector<uint8_t> payload;
};
class IPhysicalTransport {
public:
    virtual ~IPhysicalTransport() = default;
    virtual std::vector<DeviceInfo> Enumerate() = 0;
    virtual TransferResult Open(const std::string& path) = 0;
    virtual std::vector<InterfaceInfo> Interfaces() = 0;
    virtual TransferResult Control(const ControlRequest&, std::vector<uint8_t>& inbound, uint32_t timeoutMs) = 0;
    virtual TransferResult Read(uint8_t interfaceNumber, uint8_t endpoint, std::vector<uint8_t>& data, uint32_t timeoutMs) = 0;
    virtual TransferResult Write(uint8_t interfaceNumber, uint8_t endpoint, const std::vector<uint8_t>& data, uint32_t timeoutMs) = 0;
    virtual void Cancel() = 0;
    virtual void Close() = 0;
};
struct ActivationEvent {
    size_t step{};
    ControlRequest setup;
    TransferResult result;
    bool accepted{}, expectedStall{};
    bool optionalProbe{}, probeRejected{};
};
enum class ActivationPolicy { ProvenStallOnly, NativeProbeRejection };
// A rejection is protocol-stage evidence, never inferred USB STALL evidence.
const char* ActivationDisposition(const ActivationEvent&);
struct ActivationResult { bool success{}; size_t completedSteps{}; std::vector<ActivationEvent> events; };
class ActivationRunner {
public:
    explicit ActivationRunner(ActivationPolicy policy = ActivationPolicy::ProvenStallOnly) : policy_(policy) {}
    // Caller must first observe a successful non-empty controller report in this open lifetime.
    // One instance permits one attempt only. Construct anew only after a genuine reconnect.
    ActivationResult Run(IPhysicalTransport&, const std::function<void(uint32_t)>& delay,
                         const std::function<void(const ActivationEvent&)>& observe = {});
private:
    bool consumed_{};
    ActivationPolicy policy_{};
};
class ChatpadMaintenance {
public:
    explicit ChatpadMaintenance(IPhysicalTransport& transport) : transport_(transport) {}
    bool Start(uint64_t nowMs);
    bool Tick(uint64_t nowMs);
    bool OnCompletePacket(size_t size);
    bool Active() const { return active_; }
    bool KeyDataAttempted() const { return keyDataAttempted_; }
    TransferResult LastResult() const { return last_; }
    void Stop() { active_ = false; }
private:
    bool Command(uint16_t value);
    IPhysicalTransport& transport_;
    bool started_{}, active_{}, keyDataAttempted_{};
    uint16_t next_{0x001e};
    uint64_t due_{};
    TransferResult last_{};
};
using RumbleCallback = std::function<void(uint16_t, uint16_t)>;
class IVirtualXboxController {
public:
    virtual ~IVirtualXboxController() = default;
    virtual bool Create() = 0;
    virtual bool SubmitState(const XboxState&) = 0;
    virtual void SetRumbleCallback(RumbleCallback) = 0;
    // Stop and drain outstanding callbacks before returning.
    virtual void Disconnect() = 0;
};
class IKeyboardOutput;
class BridgeSession {
public:
    BridgeSession(IPhysicalTransport&, IVirtualXboxController&, IKeyboardOutput&);
    ~BridgeSession();
    bool Start(const std::string& path);
    bool SubmitController(const uint8_t*, size_t);
    void Shutdown();
    bool Running() const { return running_.load(); }
    // Consumer serializes these callbacks into Write(0, 0x01, BuildRumble(...), 1000).
    void SetPhysicalRumbleHandler(RumbleCallback callback) {
        std::lock_guard<std::mutex> lock(rumbleMutex_);physicalRumble_ = std::move(callback);
    }
private:
    IPhysicalTransport& physical_;
    IVirtualXboxController& virtual_;
    IKeyboardOutput& keyboard_;
    RumbleCallback physicalRumble_;
    std::mutex rumbleMutex_;
    bool opened_{}, created_{};
    std::atomic<bool> running_{};
};
}

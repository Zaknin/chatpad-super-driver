#pragma once
#include "BridgeCore.h"
#include <condition_variable>
#include <deque>
#include <memory>
#include <mutex>
#include <string>

namespace chatpad {
struct BrokerStateFrame { uint64_t sequence{}; XboxState state{}; };
class BrokerStateMailbox final {
public:
    explicit BrokerStateMailbox(uint64_t initialSequence = 0) : lastSequence_(initialSequence) {}
    bool Publish(const XboxState&, BrokerStateFrame& published);
    bool TryTake(BrokerStateFrame& result);
    bool HasPending() const;
    void Close();
    void Reset();
private:
    mutable std::mutex mutex_;
    uint64_t lastSequence_{};
    bool hasPending_{}, closed_{};
    BrokerStateFrame pending_{};
};

enum class BrokerServerMessageKind { ControlResponse, Rumble, Fault };
struct BrokerServerMessage {
    BrokerServerMessageKind kind{BrokerServerMessageKind::ControlResponse};
    uint32_t id{}, leftMotor{}, rightMotor{};
    bool ok{};
    std::string error, detail;
};
bool ParseBrokerServerMessage(const std::string&, BrokerServerMessage&);

struct BrokerServerIdentitySnapshot {
    std::string userSid;
    uint32_t pipeServerPid{}, servicePid{}, tokenSessionId{};
    std::string serviceName;
    bool serviceRunning{};
    std::wstring imagePath, expectedImagePath;
};
bool ValidateBrokerServerIdentity(const BrokerServerIdentitySnapshot&);

class VirtualBrokerController final : public IVirtualXboxController {
public:
    VirtualBrokerController();
    ~VirtualBrokerController() override;
    bool Create() override;
    bool SubmitState(const XboxState&) override;
    void SetRumbleCallback(RumbleCallback) override;
    void Disconnect() override;
    std::string LastError() const;
private:
    struct Impl;
    std::unique_ptr<Impl> impl_;
};
}

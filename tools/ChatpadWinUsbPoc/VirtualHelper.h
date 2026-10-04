#pragma once
#include "BridgeCore.h"
#include <memory>
namespace chatpad {
enum class HelperMessageKind { Response, Rumble };
struct HelperMessage {
    HelperMessageKind kind{HelperMessageKind::Response};
    bool hasId{}, ok{};
    uint32_t id{};
    std::string operation,error,detail;
    uint16_t leftMotor{},rightMotor{};
};
bool ParseHelperMessage(const std::string& json,HelperMessage& out);
struct HelperOptions {
    std::wstring executable;
    std::string backend{"unavailable"};
    bool allowLiveVirtual{};
    uint32_t requestTimeoutMs{1000};
    uint32_t createTimeoutMs{30000};
    uint32_t shutdownTimeoutMs{30000};
    uint32_t durationMs{120000};
};
class VirtualHelperController final : public IVirtualXboxController {
public:
    explicit VirtualHelperController(HelperOptions);
    ~VirtualHelperController() override;
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

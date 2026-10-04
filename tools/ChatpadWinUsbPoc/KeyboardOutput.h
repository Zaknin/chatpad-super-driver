#pragma once
#include <array>
#include <cstddef>
#include <cstdint>
#include <vector>
extern "C" {
#include "ChatpadConfiguration.h"
#include "ChatpadKeyboardParser.h"
}
namespace chatpad {
struct ScanCode { uint16_t code{}; bool extended{}; };
bool UsageToScanCode(uint8_t usage, ScanCode& out);
std::vector<ScanCode> SupportedChatpadScanCodes();
class IKeyboardOutput {
public:
    virtual ~IKeyboardOutput() = default;
    virtual bool Send(uint8_t hidUsage, bool down) = 0;
    virtual bool ForceRelease() = 0;
};
class SendInputKeyboardOutput final : public IKeyboardOutput {
public:
    ~SendInputKeyboardOutput() override;
    bool Send(uint8_t hidUsage, bool down) override;
    bool ForceRelease() override;
    bool ReleaseAbandonedKeys();
private:
    std::array<bool,256> held_{};
};
class KeyboardMapper {
public:
    explicit KeyboardMapper(IKeyboardOutput&);
    ~KeyboardMapper();
    bool Process(const uint8_t*, size_t);
    bool ForceRelease();
    const ChatpadHidKeyboardReport& LastReport() const { return report_; }
    const ChatpadKeyboardPacket& LastPacket() const { return packet_; }
    bool LastOutputFailed() const { return lastOutputFailed_; }
private:
    bool Apply(const ChatpadHidKeyboardReport&);
    IKeyboardOutput& output_;
    ChatpadConfiguration configuration_{};
    ChatpadLayeredMappingState state_{};
    ChatpadHidKeyboardReport report_{};
    ChatpadKeyboardPacket packet_{};
    std::array<bool,256> held_{};
    bool lastOutputFailed_{};
};
}

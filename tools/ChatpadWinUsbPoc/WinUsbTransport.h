#pragma once
#include "BridgeCore.h"
#include <memory>
namespace chatpad {
inline constexpr const char* WinUsbInterfaceGuid="{B6A5D05E-7E18-4DF1-8E47-12F072DE2C36}";
class WinUsbTransport final : public IPhysicalTransport {
public:
    WinUsbTransport();
    ~WinUsbTransport() override;
    std::vector<DeviceInfo> Enumerate() override;
    TransferResult Open(const std::string&) override;
    std::vector<InterfaceInfo> Interfaces() override;
    TransferResult Control(const ControlRequest&, std::vector<uint8_t>&, uint32_t) override;
    TransferResult Read(uint8_t,uint8_t,std::vector<uint8_t>&,uint32_t) override;
    TransferResult Write(uint8_t,uint8_t,const std::vector<uint8_t>&,uint32_t) override;
    void Cancel() override;
    // Close only after all reader threads have returned; Cancel is thread-safe.
    void Close() override;
    const DeviceInfo& Device() const;
    const std::vector<uint8_t>& RawConfiguration() const;
    const std::string& Error() const;
private:
    struct Impl;
    std::unique_ptr<Impl> impl_;
};
}

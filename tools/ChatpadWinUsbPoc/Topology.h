#pragma once
#include "BridgeCore.h"
#include <string>
namespace chatpad {
bool ParseConfiguration(const std::vector<uint8_t>& raw, uint8_t& configuration,
                        std::vector<InterfaceInfo>& interfaces, std::string& error);
bool RequiredTopology(const std::vector<InterfaceInfo>& interfaces);
std::string JsonString(const std::string& value);
std::string TopologyJson(const DeviceInfo& device, const std::vector<uint8_t>& raw,
                         const std::string& provenance);
}

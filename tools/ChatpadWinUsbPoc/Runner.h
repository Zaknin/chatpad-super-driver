#pragma once
#include <atomic>
#include <filesystem>
#include <string>
namespace chatpad {
struct RunnerOptions {
    std::filesystem::path executable;
    std::string instanceId;
    bool verbose{};
    bool keyboard{true};
    bool virtualController{true};
};
int RunUserModeBridge(const std::string& command,const RunnerOptions&,std::atomic<bool>& stop);
}

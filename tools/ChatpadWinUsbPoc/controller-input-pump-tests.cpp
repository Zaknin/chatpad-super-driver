#include "ControllerInputPump.h"
#include <chrono>
#include <condition_variable>
#include <iostream>
#include <mutex>
#include <queue>
#include <thread>
using namespace chatpad;

namespace {
class QueuedTransport final : public IPhysicalTransport {
public:
    std::vector<DeviceInfo> Enumerate() override { return {}; }
    TransferResult Open(const std::string&) override { return {}; }
    std::vector<InterfaceInfo> Interfaces() override { return {}; }
    TransferResult Control(const ControlRequest&, std::vector<uint8_t>&, uint32_t) override { return {}; }
    TransferResult Read(uint8_t interfaceNumber,uint8_t endpoint,std::vector<uint8_t>& data,uint32_t) override {
        if(interfaceNumber!=0||endpoint!=0x81)return {TransferStatus::Error,87,0};
        std::unique_lock<std::mutex> lock(mutex_);
        if(!ready_.wait_for(lock,std::chrono::milliseconds(10),[&]{return !packets_.empty();}))return {TransferStatus::Timeout,1460,0};
        data=std::move(packets_.front());packets_.pop();return {TransferStatus::Ok,0,data.size()};
    }
    TransferResult Write(uint8_t,uint8_t,const std::vector<uint8_t>& data,uint32_t) override { return {TransferStatus::Ok,0,data.size()}; }
    void Cancel() override {}
    void Close() override {}
    void Push(uint16_t buttons) {
        std::vector<uint8_t> packet(20);packet[1]=20;packet[2]=static_cast<uint8_t>(buttons);packet[3]=static_cast<uint8_t>(buttons>>8);
        {std::lock_guard<std::mutex> lock(mutex_);packets_.push(std::move(packet));}
        ready_.notify_one();
    }
private:
    std::mutex mutex_;
    std::condition_variable ready_;
    std::queue<std::vector<uint8_t>> packets_;
};
bool WaitUntil(const std::function<bool()>& predicate) {
    const auto deadline=std::chrono::steady_clock::now()+std::chrono::seconds(2);
    while(std::chrono::steady_clock::now()<deadline){if(predicate())return true;std::this_thread::sleep_for(std::chrono::milliseconds(1));}
    return predicate();
}
}

int main(){
    unsigned failed{};
    auto check=[&](bool value,const char* name){if(!value){++failed;std::cerr<<"FAIL: "<<name<<'\n';}};
    QueuedTransport transport;ControllerInputPump pump(transport,{});
    transport.Push(1);transport.Push(4);
    check(pump.Start(),"controller polling starts");
    check(WaitUntil([&]{return pump.ReportCount()>=2;}),"controller reports keep flowing before virtual backend exists");
    std::mutex statesMutex;std::vector<XboxState> states;
    const bool sinkAccepted=pump.SetStateSink([&](const XboxState& state){std::lock_guard<std::mutex> lock(statesMutex);states.push_back(state);return true;});
    check(sinkAccepted,"virtual state sink attaches");
    {
        std::lock_guard<std::mutex> lock(statesMutex);
        check(!states.empty()&&states.front().buttons==4,"sink starts from latest startup report");
    }
    transport.Push(8);
    check(WaitUntil([&]{std::lock_guard<std::mutex> lock(statesMutex);return states.size()>=2;}),"post-create controller report reaches virtual sink");
    {
        std::lock_guard<std::mutex> lock(statesMutex);
        check(states.size()>=2&&states.back().buttons==8,"newest report follows initial state");
    }
    pump.Stop();
    check(!pump.Failed(),"normal pump stop is clean");
    std::cout<<(7-failed)<<" checks, "<<failed<<" failures\n";
    return failed?1:0;
}

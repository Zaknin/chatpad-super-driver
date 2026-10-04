#include "VirtualBrokerController.h"
#include <chrono>
#include <iostream>

using namespace chatpad;
unsigned checks{}, failed{};
void Check(bool value, const char* name) { ++checks; if (!value) { ++failed; std::cerr << "FAIL: " << name << '\n'; } }

int main() {
    BrokerStateMailbox mailbox;
    BrokerStateFrame first{}, second{}, newest{};
    Check(mailbox.Publish(XboxState{1}, first) && first.sequence == 1, "first streamed state receives uint64 sequence one");
    Check(mailbox.Publish(XboxState{2}, second) && second.sequence == 2, "second streamed state increments sequence");
    Check(mailbox.Publish(XboxState{3}, newest) && newest.sequence == 3, "new state replaces pending state without waiting for writer");
    BrokerStateFrame taken{};
    Check(mailbox.TryTake(taken) && taken.sequence == 3 && taken.state.buttons == 3, "bounded mailbox coalesces to the newest state");
    Check(!mailbox.TryTake(taken), "mailbox does not retain an unbounded state backlog");
    BrokerServerMessage response{};
    Check(ParseBrokerServerMessage("{\"version\":1,\"id\":42,\"ok\":true}", response) && response.id == 42 && response.ok, "strict correlated control response parses");
    BrokerServerMessage rumble{};
    Check(ParseBrokerServerMessage("{\"version\":1,\"op\":\"rumble\",\"leftMotor\":321,\"rightMotor\":654}", rumble) && rumble.kind == BrokerServerMessageKind::Rumble && rumble.leftMotor == 321 && rumble.rightMotor == 654, "rumble callback frame is separate from control responses");
    Check(ParseBrokerServerMessage("{\"version\":1,\"op\":\"fault\",\"error\":\"state_failed\",\"detail\":\"backend closed\"}", rumble) && rumble.kind == BrokerServerMessageKind::Fault && rumble.error == "state_failed", "asynchronous broker fault is distinct from callbacks and responses");
    for (const char* bad : {
        "{\"version\":2,\"id\":1,\"ok\":true}",
        "{\"version\":1,\"id\":1,\"id\":2,\"ok\":true}",
        "{\"version\":1,\"id\":1,\"ok\":true,\"extra\":1}",
        "{\"version\":1,\"op\":\"rumble\",\"leftMotor\":65536,\"rightMotor\":0}"
    }) Check(!ParseBrokerServerMessage(bad, rumble), "unknown, duplicate, wrong-version and out-of-range server frame rejected");
    BrokerServerIdentitySnapshot systemPeer{"S-1-5-18", 80, 80, 0, "ChatpadHidMaestroBroker", true,
        LR"(C:\Program Files\ChatpadBridge\ChatpadVirtualXbox.exe)", LR"(C:\Program Files\ChatpadBridge\ChatpadVirtualXbox.exe)"};
    Check(ValidateBrokerServerIdentity(systemPeer), "expected running LocalSystem service process accepted");
    auto wrongIdentity = systemPeer; wrongIdentity.userSid = "S-1-5-21-1-2-3-1001";
    Check(!ValidateBrokerServerIdentity(wrongIdentity), "non-LocalSystem pipe server rejected");
    auto wrongPid = systemPeer; wrongPid.servicePid++;
    Check(!ValidateBrokerServerIdentity(wrongPid), "pipe process not owned by named service rejected");
    auto wrongPath = systemPeer; wrongPath.imagePath = LR"(C:\Users\Public\ChatpadVirtualXbox.exe)";
    Check(!ValidateBrokerServerIdentity(wrongPath), "service executable outside protected expected image path rejected");
    auto notRunning = systemPeer; notRunning.serviceRunning = false;
    Check(!ValidateBrokerServerIdentity(notRunning), "non-running SCM service identity rejected");
    BrokerStateMailbox lastSequence(UINT64_MAX - 1);
    Check(lastSequence.Publish(XboxState{}, taken) && taken.sequence == UINT64_MAX, "uint64 maximum sequence is valid once");
    Check(!lastSequence.Publish(XboxState{}, taken), "uint64 sequence exhaustion fails closed without wraparound");
    std::cout << checks << " checks, " << failed << " failures\n";
    return failed ? 1 : 0;
}

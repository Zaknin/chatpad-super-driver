#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include "VirtualBrokerController.h"
#include <Windows.h>
#include <ShlObj.h>
#include <shellapi.h>
#include <winsvc.h>
#include <algorithm>
#include <array>
#include <atomic>
#include <charconv>
#include <filesystem>
#include <map>
#include <sstream>
#include <vector>

namespace chatpad {
namespace {
constexpr wchar_t PipePath[] = LR"(\\.\pipe\ChatpadHidMaestroBroker.v1)";
constexpr char ServiceName[] = "ChatpadHidMaestroBroker";
constexpr uint32_t MaximumFrameBytes = 4096;
constexpr uint32_t RequestTimeoutMs = 5000;
constexpr uint32_t CreateTimeoutMs = 30000;
constexpr uint32_t DestroyTimeoutMs = 30000;

struct JsonValue {
    enum class Kind { String, Number, Boolean } kind{Kind::String};
    std::string string;
    uint64_t number{};
    bool boolean{};
};

class JsonObjectParser final {
public:
    explicit JsonObjectParser(const std::string& input) : input_(input) {}
    bool Parse(std::map<std::string, JsonValue>& fields) {
        Space(); if (!Take('{')) return false; Space();
        if (Take('}')) return End();
        while (true) {
            std::string key; JsonValue value;
            if (!String(key)) return false;
            Space(); if (!Take(':')) return false; Space();
            if (position_ < input_.size() && input_[position_] == '"') {
                value.kind = JsonValue::Kind::String; if (!String(value.string)) return false;
            } else if (Token("true")) { value.kind = JsonValue::Kind::Boolean; value.boolean = true; }
            else if (Token("false")) { value.kind = JsonValue::Kind::Boolean; }
            else { value.kind = JsonValue::Kind::Number; if (!Number(value.number)) return false; }
            if (!fields.emplace(std::move(key), std::move(value)).second) return false;
            Space(); if (Take('}')) return End(); if (!Take(',')) return false; Space();
        }
    }
private:
    const std::string& input_;
    size_t position_{};
    void Space() { while (position_ < input_.size() && (input_[position_] == ' ' || input_[position_] == '\t' || input_[position_] == '\r' || input_[position_] == '\n')) ++position_; }
    bool End() { Space(); return position_ == input_.size(); }
    bool Take(char value) { if (position_ < input_.size() && input_[position_] == value) { ++position_; return true; } return false; }
    bool Token(const char* value) { const size_t length = std::char_traits<char>::length(value); if (input_.compare(position_, length, value) != 0) return false; position_ += length; return true; }
    bool Number(uint64_t& result) {
        if (position_ == input_.size() || input_[position_] < '0' || input_[position_] > '9') return false;
        const bool leadingZero = input_[position_] == '0'; size_t digits{}; uint64_t value{};
        while (position_ < input_.size() && input_[position_] >= '0' && input_[position_] <= '9') {
            const uint64_t digit = static_cast<uint64_t>(input_[position_++] - '0');
            if (value > (UINT64_MAX - digit) / 10) return false;
            value = value * 10 + digit; ++digits;
        }
        if (leadingZero && digits > 1) return false;
        result = value; return true;
    }
    bool Hex(uint32_t& value) {
        value = 0;
        for (unsigned i = 0; i < 4; ++i) {
            if (position_ == input_.size()) return false;
            const char c = input_[position_++]; unsigned digit{};
            if (c >= '0' && c <= '9') digit = static_cast<unsigned>(c - '0');
            else if (c >= 'a' && c <= 'f') digit = static_cast<unsigned>(c - 'a' + 10);
            else if (c >= 'A' && c <= 'F') digit = static_cast<unsigned>(c - 'A' + 10);
            else return false;
            value = value * 16 + digit;
        }
        return true;
    }
    static void Utf8(std::string& output, uint32_t rune) {
        if (rune < 0x80) output.push_back(static_cast<char>(rune));
        else if (rune < 0x800) { output.push_back(static_cast<char>(0xc0 | (rune >> 6))); output.push_back(static_cast<char>(0x80 | (rune & 63))); }
        else if (rune < 0x10000) { output.push_back(static_cast<char>(0xe0 | (rune >> 12))); output.push_back(static_cast<char>(0x80 | ((rune >> 6) & 63))); output.push_back(static_cast<char>(0x80 | (rune & 63))); }
        else { output.push_back(static_cast<char>(0xf0 | (rune >> 18))); output.push_back(static_cast<char>(0x80 | ((rune >> 12) & 63))); output.push_back(static_cast<char>(0x80 | ((rune >> 6) & 63))); output.push_back(static_cast<char>(0x80 | (rune & 63))); }
    }
    bool String(std::string& output) {
        if (!Take('"')) return false;
        while (position_ < input_.size()) {
            const unsigned char c = static_cast<unsigned char>(input_[position_++]);
            if (c == '"') return true;
            if (c < 0x20) return false;
            if (c == '\\') {
                if (position_ == input_.size()) return false;
                const char escaped = input_[position_++];
                switch (escaped) {
                case '"': case '\\': case '/': output.push_back(escaped); break;
                case 'b': output.push_back('\b'); break; case 'f': output.push_back('\f'); break;
                case 'n': output.push_back('\n'); break; case 'r': output.push_back('\r'); break; case 't': output.push_back('\t'); break;
                case 'u': {
                    uint32_t rune{}; if (!Hex(rune)) return false;
                    if (rune >= 0xd800 && rune <= 0xdbff) {
                        uint32_t low{}; if (!Take('\\') || !Take('u') || !Hex(low) || low < 0xdc00 || low > 0xdfff) return false;
                        rune = 0x10000 + ((rune - 0xd800) << 10) + (low - 0xdc00);
                    } else if (rune >= 0xdc00 && rune <= 0xdfff) return false;
                    Utf8(output, rune); break;
                }
                default: return false;
                }
            } else output.push_back(static_cast<char>(c));
        }
        return false;
    }
};

bool Exact(const std::map<std::string, JsonValue>& fields, std::initializer_list<const char*> names) {
    if (fields.size() != names.size()) return false;
    for (const char* name : names) if (fields.find(name) == fields.end()) return false;
    return true;
}
bool UInt(const std::map<std::string, JsonValue>& fields, const char* name, uint64_t maximum, uint64_t& value) {
    const auto found = fields.find(name);
    if (found == fields.end() || found->second.kind != JsonValue::Kind::Number || found->second.number > maximum) return false;
    value = found->second.number; return true;
}
bool Text(const std::map<std::string, JsonValue>& fields, const char* name, std::string& value) {
    const auto found = fields.find(name);
    if (found == fields.end() || found->second.kind != JsonValue::Kind::String) return false;
    value = found->second.string; return true;
}
bool Bool(const std::map<std::string, JsonValue>& fields, const char* name, bool& value) {
    const auto found = fields.find(name);
    if (found == fields.end() || found->second.kind != JsonValue::Kind::Boolean) return false;
    value = found->second.boolean; return true;
}
bool ProtocolVersion(const std::map<std::string, JsonValue>& fields) {
    uint64_t version{}; return UInt(fields, "version", 1, version) && version == 1;
}
std::wstring ProgramFilesPath() {
    static const GUID folderId = {0x905e63b6, 0xc1bf, 0x494e, {0xb2, 0x9c, 0x65, 0xb7, 0x32, 0xd3, 0xd2, 0x1a}};
    PWSTR path{};
    if (FAILED(SHGetKnownFolderPath(folderId, 0, nullptr, &path))) return {};
    std::wstring result(path); CoTaskMemFree(path); return result;
}
std::wstring ExpectedServiceImage() { return (std::filesystem::path(ProgramFilesPath()) / L"ChatpadBridge" / L"ChatpadVirtualXbox.exe").wstring(); }
std::wstring ExpectedServiceCommandLine() { return L"\"" + ExpectedServiceImage() + L"\" service"; }
void CloseHandleIfValid(HANDLE& handle) { if (handle && handle != INVALID_HANDLE_VALUE) CloseHandle(handle); handle = nullptr; }

bool ReadPipe(HANDLE pipe, void* buffer, DWORD capacity, DWORD& transferred, const std::atomic<bool>& stopping) {
    OVERLAPPED operation{}; operation.hEvent = CreateEventW(nullptr, TRUE, FALSE, nullptr);
    if (!operation.hEvent) return false;
    BOOL result = ReadFile(pipe, buffer, capacity, &transferred, &operation);
    if (!result && GetLastError() == ERROR_IO_PENDING) {
        while (!stopping.load()) {
            const DWORD waited = WaitForSingleObject(operation.hEvent, 100);
            if (waited == WAIT_OBJECT_0) { result = GetOverlappedResult(pipe, &operation, &transferred, FALSE); break; }
            if (waited != WAIT_TIMEOUT) break;
        }
        if (!result && stopping.load()) {
            CancelIoEx(pipe, &operation);
            WaitForSingleObject(operation.hEvent, INFINITE);
            result = GetOverlappedResult(pipe, &operation, &transferred, FALSE);
        }
    }
    const DWORD error = result ? ERROR_SUCCESS : GetLastError();
    CloseHandle(operation.hEvent);
    if (!result && error == ERROR_OPERATION_ABORTED && stopping.load()) return false;
    return result != FALSE;
}
bool WritePipe(HANDLE pipe, const std::string& frame, const std::atomic<bool>& stopping) {
    if (frame.empty() || frame.size() > MaximumFrameBytes) return false;
    size_t offset{};
    while (offset < frame.size() && !stopping.load()) {
        OVERLAPPED operation{}; operation.hEvent = CreateEventW(nullptr, TRUE, FALSE, nullptr);
        if (!operation.hEvent) return false;
        DWORD written{};
        BOOL result = WriteFile(pipe, frame.data() + offset, static_cast<DWORD>(frame.size() - offset), &written, &operation);
        if (!result && GetLastError() == ERROR_IO_PENDING) {
            while (!stopping.load()) {
                const DWORD waited = WaitForSingleObject(operation.hEvent, 100);
                if (waited == WAIT_OBJECT_0) { result = GetOverlappedResult(pipe, &operation, &written, FALSE); break; }
                if (waited != WAIT_TIMEOUT) break;
            }
            if (!result && stopping.load()) {
                CancelIoEx(pipe, &operation);
                WaitForSingleObject(operation.hEvent, INFINITE);
                result = GetOverlappedResult(pipe, &operation, &written, FALSE);
            }
        }
        const DWORD error = result ? ERROR_SUCCESS : GetLastError();
        CloseHandle(operation.hEvent);
        if (!result || written == 0) return false;
        offset += written;
        if (error != ERROR_SUCCESS) return false;
    }
    return offset == frame.size();
}
}

bool BrokerStateMailbox::Publish(const XboxState& state, BrokerStateFrame& published) {
    std::lock_guard<std::mutex> guard(mutex_);
    if (closed_ || lastSequence_ == UINT64_MAX) return false;
    pending_ = BrokerStateFrame{++lastSequence_, state};
    published = pending_; hasPending_ = true; return true;
}
bool BrokerStateMailbox::TryTake(BrokerStateFrame& result) {
    std::lock_guard<std::mutex> guard(mutex_);
    if (!hasPending_) return false;
    result = pending_; hasPending_ = false; return true;
}
bool BrokerStateMailbox::HasPending() const { std::lock_guard<std::mutex> guard(mutex_); return hasPending_; }
void BrokerStateMailbox::Close() { std::lock_guard<std::mutex> guard(mutex_); closed_ = true; hasPending_ = false; }
void BrokerStateMailbox::Reset() { std::lock_guard<std::mutex> guard(mutex_); lastSequence_ = 0; hasPending_ = false; closed_ = false; pending_ = {}; }

bool ParseBrokerServerMessage(const std::string& json, BrokerServerMessage& out) {
    out = {};
    if (json.size() > MaximumFrameBytes) return false;
    std::map<std::string, JsonValue> fields; JsonObjectParser parser(json);
    if (!parser.Parse(fields) || !ProtocolVersion(fields)) return false;
    uint64_t version{}, id{}, left{}, right{};
    if (Text(fields, "op", out.error)) {
        if (out.error == "rumble") {
            if (!Exact(fields, {"version", "op", "leftMotor", "rightMotor"}) ||
                !UInt(fields, "leftMotor", UINT16_MAX, left) || !UInt(fields, "rightMotor", UINT16_MAX, right)) return false;
            out.kind = BrokerServerMessageKind::Rumble; out.leftMotor = static_cast<uint32_t>(left); out.rightMotor = static_cast<uint32_t>(right); return true;
        }
        if (out.error == "fault" &&
            (Exact(fields, {"version", "op", "error"}) || Exact(fields, {"version", "op", "error", "detail"})) &&
            Text(fields, "error", out.error) && !out.error.empty()) {
            if (fields.find("detail") != fields.end() && !Text(fields, "detail", out.detail)) return false;
            out.kind = BrokerServerMessageKind::Fault; return true;
        }
        return false;
    }
    if (!UInt(fields, "id", INT32_MAX, id) || !Bool(fields, "ok", out.ok)) return false;
    if (out.ok) {
        if (!Exact(fields, {"version", "id", "ok"})) return false;
    } else {
        if (fields.find("operation") != fields.end() ||
            !(Exact(fields, {"version", "id", "ok", "error"}) || Exact(fields, {"version", "id", "ok", "error", "detail"})) ||
            !Text(fields, "error", out.error) || out.error.empty()) return false;
        if (fields.find("detail") != fields.end() && !Text(fields, "detail", out.detail)) return false;
    }
    out.kind = BrokerServerMessageKind::ControlResponse; out.id = static_cast<uint32_t>(id); (void)version; return true;
}

bool ValidateBrokerServerIdentity(const BrokerServerIdentitySnapshot& snapshot) {
    const auto expected = std::filesystem::path(ExpectedServiceImage());
    const auto root = expected.parent_path();
    if (snapshot.pipeServerPid == 0 || snapshot.pipeServerPid != snapshot.servicePid ||
        snapshot.serviceName != ServiceName || !snapshot.serviceRunning ||
        CompareStringOrdinal(snapshot.serviceStartName.c_str(), static_cast<int>(snapshot.serviceStartName.size()), L"LocalSystem", -1, TRUE) != CSTR_EQUAL ||
        !expected.is_absolute() || expected.filename() != L"ChatpadVirtualXbox.exe" || root.filename() != L"ChatpadBridge" ||
        CompareStringOrdinal(snapshot.serviceBinaryPathName.c_str(), static_cast<int>(snapshot.serviceBinaryPathName.size()),
            ExpectedServiceCommandLine().c_str(), -1, TRUE) != CSTR_EQUAL) return false;
    return true;
}

struct VirtualBrokerController::Impl {
    HANDLE pipe{INVALID_HANDLE_VALUE};
    HANDLE wakeEvent{};
    std::atomic<bool> stopping{}, failed{}, connected{}, created{};
    mutable std::mutex errorMutex, callbackMutex, outputMutex, responseMutex;
    std::mutex controlCallMutex;
    std::condition_variable outputCondition, responseCondition;
    std::deque<std::string> controlQueue;
    BrokerStateMailbox states;
    std::thread writer, reader;
    std::string error;
    RumbleCallback callback;
    uint32_t nextControlId{1}, waitingId{};
    bool awaitingResponse{}, responseReceived{}, responseOk{};

    void Fail(const std::string& message) {
        bool expected = false;
        if (failed.compare_exchange_strong(expected, true)) { std::lock_guard<std::mutex> lock(errorMutex); error = message; }
        connected = false; outputCondition.notify_all(); responseCondition.notify_all();
        if (pipe != INVALID_HANDLE_VALUE) CancelIoEx(pipe, nullptr);
        if (wakeEvent) SetEvent(wakeEvent);
    }
    std::string Error() const { std::lock_guard<std::mutex> lock(errorMutex); return error; }

    bool VerifyServer() {
        ULONG serverPid{};
        if (!GetNamedPipeServerProcessId(pipe, &serverPid)) { Fail("pipe_server_pid_unavailable:" + std::to_string(GetLastError())); return false; }
        SC_HANDLE manager = OpenSCManagerW(nullptr, nullptr, SC_MANAGER_CONNECT);
        if (!manager) { Fail("broker_scm_open_failed:" + std::to_string(GetLastError())); return false; }
        SC_HANDLE service = OpenServiceW(manager, L"ChatpadHidMaestroBroker", SERVICE_QUERY_STATUS | SERVICE_QUERY_CONFIG);
        if (!service) {
            const DWORD errorCode = GetLastError(); CloseServiceHandle(manager);
            Fail("broker_service_open_failed:" + std::to_string(errorCode)); return false;
        }
        SERVICE_STATUS_PROCESS status{}; DWORD statusBytes{};
        if (!QueryServiceStatusEx(service, SC_STATUS_PROCESS_INFO,
            reinterpret_cast<LPBYTE>(&status), sizeof(status), &statusBytes)) {
            const DWORD errorCode = GetLastError(); CloseServiceHandle(service); CloseServiceHandle(manager);
            Fail("broker_service_status_query_failed:" + std::to_string(errorCode)); return false;
        }
        DWORD configBytes{};
        QueryServiceConfigW(service, nullptr, 0, &configBytes);
        const DWORD configError = GetLastError();
        if (configError != ERROR_INSUFFICIENT_BUFFER || configBytes < sizeof(QUERY_SERVICE_CONFIGW) || configBytes > 65536) {
            CloseServiceHandle(service); CloseServiceHandle(manager);
            Fail("broker_service_config_size_failed:" + std::to_string(configError)); return false;
        }
        std::vector<uint8_t> configBuffer(configBytes);
        auto* config = reinterpret_cast<QUERY_SERVICE_CONFIGW*>(configBuffer.data());
        if (!QueryServiceConfigW(service, config, configBytes, &configBytes)) {
            const DWORD errorCode = GetLastError(); CloseServiceHandle(service); CloseServiceHandle(manager);
            Fail("broker_service_config_query_failed:" + std::to_string(errorCode)); return false;
        }
        const std::wstring startName = config->lpServiceStartName ? config->lpServiceStartName : L"";
        const std::wstring binaryPathName = config->lpBinaryPathName ? config->lpBinaryPathName : L"";
        CloseServiceHandle(service); CloseServiceHandle(manager);
        const bool running = status.dwCurrentState == SERVICE_RUNNING;
        BrokerServerIdentitySnapshot identity{serverPid, running ? status.dwProcessId : 0,
            ServiceName, running, startName, binaryPathName};
        if (!ValidateBrokerServerIdentity(identity)) { Fail("pipe_server_identity_mismatch"); return false; }
        return true;
    }
    bool OpenPipe() {
        const auto deadline = GetTickCount64() + 15000;
        while (!stopping.load() && GetTickCount64() < deadline) {
            pipe = CreateFileW(PipePath, GENERIC_READ | GENERIC_WRITE, 0, nullptr, OPEN_EXISTING, FILE_FLAG_OVERLAPPED, nullptr);
            if (pipe != INVALID_HANDLE_VALUE) return VerifyServer();
            const DWORD errorCode = GetLastError();
            if (errorCode == ERROR_PIPE_BUSY) WaitNamedPipeW(PipePath, 500);
            else if (errorCode != ERROR_FILE_NOT_FOUND && errorCode != ERROR_PATH_NOT_FOUND) { Fail("broker_pipe_open_failed:" + std::to_string(errorCode)); return false; }
            Sleep(250);
        }
        Fail("broker_service_pipe_not_available"); return false;
    }

    bool WriteFrame(const std::string& payload) {
        std::string frame = payload + "\n";
        return frame.size() <= MaximumFrameBytes + 1 && WritePipe(pipe, frame, stopping);
    }

    void WriterLoop() {
        while (!stopping.load() && !failed.load()) {
            std::string control;
            {
                std::unique_lock<std::mutex> lock(outputMutex);
                outputCondition.wait(lock, [this] { return stopping.load() || failed.load() || !controlQueue.empty() || states.HasPending(); });
                if (stopping.load() || failed.load()) break;
                if (!controlQueue.empty()) { control = std::move(controlQueue.front()); controlQueue.pop_front(); }
            }
            if (!control.empty()) { if (!WriteFrame(control)) { Fail("broker_control_write_failed:" + std::to_string(GetLastError())); break; } continue; }
            BrokerStateFrame state{};
            if (states.TryTake(state)) {
                std::ostringstream frame;
                frame << "{\"version\":1,\"sequence\":" << state.sequence << ",\"op\":\"submit-state\",\"buttons\":"
                    << state.state.buttons << ",\"leftTrigger\":" << static_cast<unsigned>(state.state.leftTrigger)
                    << ",\"rightTrigger\":" << static_cast<unsigned>(state.state.rightTrigger)
                    << ",\"lx\":" << state.state.lx << ",\"ly\":" << state.state.ly
                    << ",\"rx\":" << state.state.rx << ",\"ry\":" << state.state.ry << '}';
                if (!WriteFrame(frame.str())) { Fail("broker_state_write_failed:" + std::to_string(GetLastError())); break; }
            }
        }
    }

    void ReaderLoop() {
        std::string line; std::array<char, 2048> buffer{};
        while (!stopping.load() && !failed.load()) {
            DWORD count{};
            if (!ReadPipe(pipe, buffer.data(), static_cast<DWORD>(buffer.size()), count, stopping)) {
                if (!stopping.load()) Fail("broker_pipe_closed:" + std::to_string(GetLastError()));
                return;
            }
            for (DWORD i = 0; i < count; ++i) {
                if (buffer[i] != '\n') {
                    line.push_back(buffer[i]);
                    if (line.size() > MaximumFrameBytes) { Fail("broker_server_frame_too_large"); return; }
                    continue;
                }
                if (!line.empty() && line.back() == '\r') line.pop_back();
                BrokerServerMessage message{};
                if (!ParseBrokerServerMessage(line, message)) { Fail("invalid_broker_server_frame"); return; }
                line.clear();
                if (message.kind == BrokerServerMessageKind::Rumble) {
                    RumbleCallback copied;
                    { std::lock_guard<std::mutex> lock(callbackMutex); copied = callback; }
                    if (copied && !stopping.load()) {
                        try { copied(static_cast<uint16_t>(message.leftMotor), static_cast<uint16_t>(message.rightMotor)); }
                        catch (...) { Fail("physical_rumble_callback_failed"); return; }
                    }
                } else if (message.kind == BrokerServerMessageKind::Fault) {
                    Fail("broker_service_fault:" + message.error + (message.detail.empty() ? "" : ":" + message.detail));
                    return;
                } else {
                    std::lock_guard<std::mutex> lock(responseMutex);
                    if (!awaitingResponse || message.id != waitingId || responseReceived) { Fail("broker_response_correlation_failed"); return; }
                    responseReceived = true; responseOk = message.ok;
                    if (!message.ok) { std::lock_guard<std::mutex> errorLock(errorMutex); error = message.error + (message.detail.empty() ? "" : ":" + message.detail); }
                    responseCondition.notify_all();
                }
            }
        }
    }

    bool Request(const char* operation, uint32_t timeoutMs) {
        std::lock_guard<std::mutex> callLock(controlCallMutex);
        if (failed.load() || stopping.load() || pipe == INVALID_HANDLE_VALUE || nextControlId > INT32_MAX) return false;
        const uint32_t id = nextControlId++;
        {
            std::lock_guard<std::mutex> lock(responseMutex);
            waitingId = id; awaitingResponse = true; responseReceived = false; responseOk = false;
        }
        const std::string request = "{\"version\":1,\"id\":" + std::to_string(id) + ",\"op\":\"" + operation + "\"}";
        {
            std::lock_guard<std::mutex> lock(outputMutex);
            if (controlQueue.size() >= 4) { Fail("broker_control_queue_full"); return false; }
            controlQueue.push_back(request);
        }
        outputCondition.notify_one();
        std::unique_lock<std::mutex> lock(responseMutex);
        if (!responseCondition.wait_for(lock, std::chrono::milliseconds(timeoutMs), [this] { return responseReceived || failed.load() || stopping.load(); })) {
            awaitingResponse = false; Fail(std::string("broker_") + operation + "_timeout"); return false;
        }
        if (!responseReceived || !responseOk) { awaitingResponse = false; return false; }
        awaitingResponse = false; return true;
    }

    void StopTransport() {
        stopping = true; states.Close(); outputCondition.notify_all(); responseCondition.notify_all();
        if (pipe != INVALID_HANDLE_VALUE) CancelIoEx(pipe, nullptr);
        if (reader.joinable() && reader.get_id() != std::this_thread::get_id()) reader.join();
        if (writer.joinable() && writer.get_id() != std::this_thread::get_id()) writer.join();
        CloseHandleIfValid(pipe); CloseHandleIfValid(wakeEvent);
    }

    bool Create() {
        if (connected.load()) { Fail("broker_already_connected"); return false; }
        failed = false; stopping = false; created = false; nextControlId = 1;
        { std::lock_guard<std::mutex> lock(errorMutex); error.clear(); }
        states.Reset();
        { std::lock_guard<std::mutex> lock(outputMutex); controlQueue.clear(); }
        if (!OpenPipe()) { StopTransport(); return false; }
        writer = std::thread([this] { WriterLoop(); }); reader = std::thread([this] { ReaderLoop(); });
        if (!Request("ping", RequestTimeoutMs)) { StopTransport(); return false; }
        if (!Request("create", CreateTimeoutMs)) { StopTransport(); return false; }
        created = true; connected = true; return true;
    }

    bool Submit(const XboxState& state) {
        if (!connected.load() || !created.load() || failed.load()) return false;
        BrokerStateFrame published{};
        if (!states.Publish(state, published)) { Fail("broker_state_sequence_exhausted_or_closed"); return false; }
        outputCondition.notify_one(); return true;
    }

    void Disconnect() {
        if (pipe == INVALID_HANDLE_VALUE) { connected = false; created = false; return; }
        if (created.load() && !failed.load()) {
            if (!Request("destroy", DestroyTimeoutMs) && Error().empty()) Fail("broker_destroy_failed");
        }
        connected = false; created = false;
        { std::lock_guard<std::mutex> lock(callbackMutex); callback = {}; }
        StopTransport();
    }
};

VirtualBrokerController::VirtualBrokerController() : impl_(std::make_unique<Impl>()) {}
VirtualBrokerController::~VirtualBrokerController() { Disconnect(); }
bool VirtualBrokerController::Create() { return impl_->Create(); }
bool VirtualBrokerController::SubmitState(const XboxState& state) { return impl_->Submit(state); }
void VirtualBrokerController::SetRumbleCallback(RumbleCallback callback) { std::lock_guard<std::mutex> lock(impl_->callbackMutex); impl_->callback = std::move(callback); }
void VirtualBrokerController::Disconnect() { impl_->Disconnect(); }
std::string VirtualBrokerController::LastError() const { return impl_->Error(); }
}

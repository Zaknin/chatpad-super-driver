#include "ProfileJson.h"

#include <cctype>
#include <iomanip>
#include <map>
#include <sstream>
#include <stdexcept>

namespace {

struct JsonValue {
    enum class Kind { Object, String, Number } kind = Kind::Object;
    std::map<std::string, JsonValue> object;
    std::string string;
    unsigned long number = 0;
};

class Parser {
public:
    explicit Parser(const std::string& text) : text_(text) {}

    JsonValue Parse()
    {
        if (text_.size() > 65536) Fail("profile exceeds 65536 bytes");
        SkipSpace();
        JsonValue value = ParseValue(0);
        SkipSpace();
        if (position_ != text_.size()) Fail("trailing data");
        return value;
    }

private:
    JsonValue ParseValue(unsigned depth)
    {
        if (depth > 8) Fail("JSON nesting is too deep");
        SkipSpace();
        if (Peek() == '{') return ParseObject(depth + 1);
        if (Peek() == '"') {
            JsonValue value;
            value.kind = JsonValue::Kind::String;
            value.string = ParseString();
            return value;
        }
        if (std::isdigit(static_cast<unsigned char>(Peek()))) {
            JsonValue value;
            value.kind = JsonValue::Kind::Number;
            value.number = ParseNumber();
            return value;
        }
        Fail("expected object, string, or unsigned integer");
    }

    JsonValue ParseObject(unsigned depth)
    {
        JsonValue value;
        value.kind = JsonValue::Kind::Object;
        Expect('{');
        SkipSpace();
        if (Peek() == '}') { ++position_; return value; }
        for (;;) {
            SkipSpace();
            std::string key = ParseString();
            SkipSpace();
            Expect(':');
            JsonValue child = ParseValue(depth);
            if (!value.object.emplace(key, std::move(child)).second) {
                Fail("duplicate object property: " + key);
            }
            SkipSpace();
            if (Peek() == '}') { ++position_; break; }
            Expect(',');
        }
        return value;
    }

    std::string ParseString()
    {
        std::string result;
        Expect('"');
        while (position_ < text_.size()) {
            unsigned char value = static_cast<unsigned char>(text_[position_++]);
            if (value == '"') return result;
            if (value < 0x20 || value > 0x7E) Fail("only printable ASCII strings are supported");
            if (value == '\\') {
                if (position_ >= text_.size()) Fail("unterminated escape");
                char escaped = text_[position_++];
                switch (escaped) {
                case '"': result.push_back('"'); break;
                case '\\': result.push_back('\\'); break;
                case '/': result.push_back('/'); break;
                case 'b': result.push_back('\b'); break;
                case 'f': result.push_back('\f'); break;
                case 'n': result.push_back('\n'); break;
                case 'r': result.push_back('\r'); break;
                case 't': result.push_back('\t'); break;
                default: Fail("unsupported string escape");
                }
            } else {
                result.push_back(static_cast<char>(value));
            }
            if (result.size() > 255) Fail("string exceeds 255 bytes");
        }
        Fail("unterminated string");
    }

    unsigned long ParseNumber()
    {
        unsigned long value = 0;
        size_t start = position_;
        while (position_ < text_.size() && std::isdigit(static_cast<unsigned char>(text_[position_]))) {
            unsigned digit = static_cast<unsigned>(text_[position_++] - '0');
            if (value > (0xFFFFFFFFul - digit) / 10ul) Fail("integer overflow");
            value = value * 10ul + digit;
        }
        if (position_ - start > 1 && text_[start] == '0') Fail("leading zero in integer");
        return value;
    }

    void SkipSpace()
    {
        while (position_ < text_.size() &&
               std::isspace(static_cast<unsigned char>(text_[position_]))) ++position_;
    }

    char Peek() const { return position_ < text_.size() ? text_[position_] : '\0'; }

    void Expect(char expected)
    {
        if (Peek() != expected) Fail(std::string("expected '") + expected + "'");
        ++position_;
    }

    [[noreturn]] void Fail(const std::string& message) const
    {
        throw std::runtime_error(message + " at byte " + std::to_string(position_));
    }

    const std::string& text_;
    size_t position_ = 0;
};

const JsonValue& Require(const JsonValue& object, const std::string& key, JsonValue::Kind kind)
{
    if (object.kind != JsonValue::Kind::Object) throw std::runtime_error("expected JSON object");
    auto found = object.object.find(key);
    if (found == object.object.end()) throw std::runtime_error("missing property: " + key);
    if (found->second.kind != kind) throw std::runtime_error("wrong type for property: " + key);
    return found->second;
}

void RequireExactProperties(const JsonValue& object, const std::initializer_list<const char*>& names)
{
    if (object.kind != JsonValue::Kind::Object) throw std::runtime_error("expected JSON object");
    if (object.object.size() != names.size()) throw std::runtime_error("unexpected or missing object property");
    for (const char* name : names) (void)Require(object, name, object.object.at(name).kind);
}

ChatpadUInt8 LayoutFromString(const std::string& value)
{
    if (value == "qwerty") return CHATPAD_PROFILE_LAYOUT_QWERTY;
    if (value == "qwertz") return CHATPAD_PROFILE_LAYOUT_QWERTZ;
    if (value == "azerty") return CHATPAD_PROFILE_LAYOUT_AZERTY;
    throw std::runtime_error("unsupported layout");
}

const char* LayoutToString(ChatpadUInt8 value)
{
    switch (value) {
    case CHATPAD_PROFILE_LAYOUT_QWERTY: return "qwerty";
    case CHATPAD_PROFILE_LAYOUT_QWERTZ: return "qwertz";
    case CHATPAD_PROFILE_LAYOUT_AZERTY: return "azerty";
    default: return "invalid";
    }
}

std::string KeyName(unsigned rawKey)
{
    std::ostringstream output;
    output << "0x" << std::uppercase << std::hex << std::setw(2) << std::setfill('0') << rawKey;
    return output.str();
}

ChatpadMappingAction ParseAction(const JsonValue& value)
{
    RequireExactProperties(value, { "type", "usage", "modifiers" });
    const std::string& type = Require(value, "type", JsonValue::Kind::String).string;
    unsigned long usage = Require(value, "usage", JsonValue::Kind::Number).number;
    unsigned long modifiers = Require(value, "modifiers", JsonValue::Kind::Number).number;
    if (usage > 255 || modifiers > 255) throw std::runtime_error("action byte out of range");
    ChatpadMappingAction action{};
    if (type == "disabled") action.Type = CHATPAD_MAPPING_ACTION_DISABLED;
    else if (type == "keyboard") action.Type = CHATPAD_MAPPING_ACTION_KEYBOARD;
    else throw std::runtime_error("unsupported action type");
    action.Usage = static_cast<ChatpadUInt8>(usage);
    action.Modifiers = static_cast<ChatpadUInt8>(modifiers);
    return action;
}

void ParseLayer(const JsonValue& value, ChatpadMappingAction* layer)
{
    size_t requiredCount = 0;
    for (unsigned rawKey = 0; rawKey < 256; ++rawKey) {
        if (!ChatpadIsSupportedPhysicalKey(static_cast<ChatpadUInt8>(rawKey))) continue;
        ++requiredCount;
        std::string name = KeyName(rawKey);
        layer[rawKey] = ParseAction(Require(value, name, JsonValue::Kind::Object));
    }
    if (value.object.size() != requiredCount) throw std::runtime_error("mapping layer has duplicate, unknown, or missing keys");
}

void WriteAction(std::ostringstream& output, const ChatpadMappingAction& action)
{
    output << "{ \"type\": \""
           << (action.Type == CHATPAD_MAPPING_ACTION_KEYBOARD ? "keyboard" : "disabled")
           << "\", \"usage\": " << static_cast<unsigned>(action.Usage)
           << ", \"modifiers\": " << static_cast<unsigned>(action.Modifiers) << " }";
}

void WriteLayer(std::ostringstream& output, const ChatpadMappingAction* layer, const char* indent)
{
    bool first = true;
    output << "{\n";
    for (unsigned rawKey = 0; rawKey < 256; ++rawKey) {
        if (!ChatpadIsSupportedPhysicalKey(static_cast<ChatpadUInt8>(rawKey))) continue;
        if (!first) output << ",\n";
        first = false;
        output << indent << "  \"" << KeyName(rawKey) << "\": ";
        WriteAction(output, layer[rawKey]);
    }
    output << "\n" << indent << "}";
}

} // namespace

bool ParseChatpadProfileJson(
    const std::string& text,
    ChatpadConfiguration& configuration,
    std::string& error)
{
    try {
        JsonValue root = Parser(text).Parse();
        RequireExactProperties(root, {
            "schemaVersion", "profileName", "layout", "peopleAction", "base", "green", "orange"
        });
        ChatpadConfiguration candidate{};
        unsigned long schema = Require(root, "schemaVersion", JsonValue::Kind::Number).number;
        if (schema > 255) throw std::runtime_error("schema version out of range");
        candidate.SchemaVersion = static_cast<ChatpadUInt8>(schema);
        candidate.AbiVersion = CHATPAD_CONFIGURATION_ABI_VERSION;
        candidate.Layout = LayoutFromString(Require(root, "layout", JsonValue::Kind::String).string);
        if (Require(root, "peopleAction", JsonValue::Kind::String).string != "disabled")
            throw std::runtime_error("only Disabled People action is supported");
        candidate.PeopleAction = CHATPAD_PEOPLE_ACTION_DISABLED;
        const std::string& name = Require(root, "profileName", JsonValue::Kind::String).string;
        if (name.size() >= CHATPAD_CONFIGURATION_PROFILE_NAME_LENGTH)
            throw std::runtime_error("profile name is too long");
        for (size_t index = 0; index < name.size(); ++index) candidate.ProfileName[index] = name[index];
        ParseLayer(Require(root, "base", JsonValue::Kind::Object), candidate.Base);
        ParseLayer(Require(root, "green", JsonValue::Kind::Object), candidate.Green);
        ParseLayer(Require(root, "orange", JsonValue::Kind::Object), candidate.Orange);
        ChatpadConfigurationValidationResult validation = ChatpadValidateConfiguration(&candidate);
        if (validation != CHATPAD_CONFIGURATION_VALID)
            throw std::runtime_error("configuration validation failed with code " + std::to_string(validation));
        configuration = candidate;
        error.clear();
        return true;
    } catch (const std::exception& exception) {
        error = exception.what();
        return false;
    }
}

std::string SerializeChatpadProfileJson(const ChatpadConfiguration& configuration)
{
    std::ostringstream output;
    output << "{\n"
           << "  \"schemaVersion\": " << static_cast<unsigned>(configuration.SchemaVersion) << ",\n"
           << "  \"profileName\": \"" << configuration.ProfileName << "\",\n"
           << "  \"layout\": \"" << LayoutToString(configuration.Layout) << "\",\n"
           << "  \"peopleAction\": \"disabled\",\n"
           << "  \"base\": ";
    WriteLayer(output, configuration.Base, "  ");
    output << ",\n  \"green\": ";
    WriteLayer(output, configuration.Green, "  ");
    output << ",\n  \"orange\": ";
    WriteLayer(output, configuration.Orange, "  ");
    output << "\n}\n";
    return output.str();
}

#pragma once

#include <string>

extern "C" {
#include "ChatpadConfiguration.h"
}

bool ParseChatpadProfileJson(
    const std::string& text,
    ChatpadConfiguration& configuration,
    std::string& error);

std::string SerializeChatpadProfileJson(const ChatpadConfiguration& configuration);

#ifndef CHATPAD_ACTIVATION_REQUEST_FIXTURES_H
#define CHATPAD_ACTIVATION_REQUEST_FIXTURES_H

#include <stddef.h>
#include <stdint.h>

#include "ChatpadActivationRequests.h"

/*
 * Reconstructed from confirmed legacy-source evidence in
 * docs/CHATPAD-INIT-STATUS-EVIDENCE.md. These are not hardware captures and
 * do not describe acknowledgement, ready-state, retry, timeout, or response
 * semantics.
 */

typedef struct ChatpadActivationRequestFixture {
    uint8_t RawBmRequestType;
    uint8_t RawRequest;
    uint16_t RawValue;
    uint16_t RawIndex;
    uint16_t RawLength;
    ChatpadControlDirection Direction;
    uint16_t OutboundPayloadLength;
    uint16_t ExpectedInboundDataLength;
    uint8_t OutboundPayload[CHATPAD_ACTIVATION_MAX_PAYLOAD_LENGTH];
} ChatpadActivationRequestFixture;

static const ChatpadActivationRequestFixture ConfirmedActivationRequests[CHATPAD_ACTIVATION_REQUEST_COUNT] = {
    { 0x40u, 0xA9u, 0xA30Cu, 0x4423u, 0x0000u, CHATPAD_CONTROL_DIRECTION_HOST_TO_DEVICE, 0x0000u, 0x0000u, { 0x00u, 0x00u } },
    { 0x40u, 0xA9u, 0x2344u, 0x7F03u, 0x0000u, CHATPAD_CONTROL_DIRECTION_HOST_TO_DEVICE, 0x0000u, 0x0000u, { 0x00u, 0x00u } },
    { 0x40u, 0xA9u, 0x5839u, 0x6832u, 0x0000u, CHATPAD_CONTROL_DIRECTION_HOST_TO_DEVICE, 0x0000u, 0x0000u, { 0x00u, 0x00u } },
    { 0xC0u, 0xA1u, 0x0000u, 0xE416u, 0x0002u, CHATPAD_CONTROL_DIRECTION_DEVICE_TO_HOST, 0x0000u, 0x0002u, { 0x00u, 0x00u } },
    { 0x40u, 0xA1u, 0x0000u, 0xE416u, 0x0002u, CHATPAD_CONTROL_DIRECTION_HOST_TO_DEVICE, 0x0002u, 0x0000u, { 0x09u, 0x00u } },
    { 0xC0u, 0xA1u, 0x0000u, 0xE416u, 0x0002u, CHATPAD_CONTROL_DIRECTION_DEVICE_TO_HOST, 0x0000u, 0x0002u, { 0x00u, 0x00u } }
};

#endif

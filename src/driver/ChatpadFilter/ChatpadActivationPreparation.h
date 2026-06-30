#ifndef CHATPAD_ACTIVATION_PREPARATION_H
#define CHATPAD_ACTIVATION_PREPARATION_H

#include "ChatpadActivationSequence.h"
#include "ChatpadWdfControlSetupFormatter.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef enum ChatpadActivationPreparationResult {
    CHATPAD_ACTIVATION_PREPARATION_OK = 0,
    CHATPAD_ACTIVATION_PREPARATION_NULL_OUTPUT,
    CHATPAD_ACTIVATION_PREPARATION_INVALID_STEP_INDEX,
    CHATPAD_ACTIVATION_PREPARATION_MODEL_FAILED,
    CHATPAD_ACTIVATION_PREPARATION_TRANSLATION_FAILED,
    CHATPAD_ACTIVATION_PREPARATION_WDF_FORMATTING_FAILED,
    CHATPAD_ACTIVATION_PREPARATION_PAYLOAD_CAPACITY_EXCEEDED,
    CHATPAD_ACTIVATION_PREPARATION_METADATA_INCONSISTENT
} ChatpadActivationPreparationResult;

typedef struct ChatpadActivationPreparation {
    WDF_USB_CONTROL_SETUP_PACKET SetupPacket;
    ChatpadControlDataDirection DataDirection;
    uint16_t TransferLength;
    uint16_t OutboundPayloadLength;
    uint8_t OutboundPayload[CHATPAD_ACTIVATION_MAX_PAYLOAD_LENGTH];
    uint16_t ExpectedInboundLength;
    size_t SequenceIndex;
    size_t RequestIndex;
    uint16_t DelayBeforeMilliseconds;
    uint16_t DelayAfterMilliseconds;
} ChatpadActivationPreparation;

/*
 * Prepares caller-owned data only. A non-null output is cleared before every
 * validation step and remains completely cleared on every failure.
 */
ChatpadActivationPreparationResult ChatpadPrepareActivationStep(
    size_t stepIndex,
    ChatpadActivationPreparation *output);

#ifdef __cplusplus
}
#endif

#endif

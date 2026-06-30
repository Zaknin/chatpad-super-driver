#include "ChatpadActivationRequests.h"
#include "ChatpadActivationPreparation.h"
#include "ChatpadControlSetup.h"
#include "ChatpadWdfControlSetupFormatter.h"

typedef char ChatpadWdfSetupPacketIsEightBytes[
    (sizeof(WDF_USB_CONTROL_SETUP_PACKET) == CHATPAD_CONTROL_SETUP_PACKET_LENGTH) ? 1 : -1];
typedef char ChatpadWdfSetupGenericMemberIsEightBytes[
    (sizeof(((WDF_USB_CONTROL_SETUP_PACKET *)0)->Generic.Bytes) == CHATPAD_CONTROL_SETUP_PACKET_LENGTH) ? 1 : -1];

ChatpadWdfControlSetupResult ChatpadWdfControlSetupCompileCheckAllTranslations(void)
{
    size_t requestIndex;

    for (requestIndex = 0; requestIndex < ChatpadGetActivationRequestCount(); ++requestIndex) {
        ChatpadActivationRequest request;
        ChatpadControlSetupTranslation translation;
        WDF_USB_CONTROL_SETUP_PACKET packet;

        if (ChatpadBuildActivationRequest(requestIndex, &request) != CHATPAD_ACTIVATION_BUILD_OK) {
            return CHATPAD_WDF_CONTROL_SETUP_UNSUPPORTED_REPRESENTATION;
        }
        if (ChatpadTranslateActivationRequest(&request, &translation) != CHATPAD_CONTROL_SETUP_OK) {
            return CHATPAD_WDF_CONTROL_SETUP_UNSUPPORTED_REPRESENTATION;
        }
        if (ChatpadFormatWdfControlSetupPacket(&translation, &packet) != CHATPAD_WDF_CONTROL_SETUP_OK) {
            return CHATPAD_WDF_CONTROL_SETUP_UNSUPPORTED_REPRESENTATION;
        }
    }

    return CHATPAD_WDF_CONTROL_SETUP_OK;
}

ChatpadActivationPreparationResult ChatpadDriverActivationPlanCompileCheckAllSteps(void)
{
    size_t stepIndex;

    if (ChatpadGetActivationSequenceStepCount() !=
        CHATPAD_ACTIVATION_SEQUENCE_STEP_COUNT) {
        return CHATPAD_ACTIVATION_PREPARATION_MODEL_FAILED;
    }

    for (stepIndex = 0;
        stepIndex < ChatpadGetActivationSequenceStepCount();
        ++stepIndex) {
        ChatpadActivationPreparation preparation;
        ChatpadActivationPreparation repeatedPreparation;
        ChatpadActivationPreparationResult result;
        ChatpadActivationSequenceStep step;
        ChatpadControlSetupTranslation translation;
        uint16_t expectedTransferLength;
        uint16_t payloadIndex;
        size_t byteIndex;

        result = ChatpadPrepareActivationStep(stepIndex, &preparation);
        if (result != CHATPAD_ACTIVATION_PREPARATION_OK) {
            return result;
        }
        if (ChatpadGetActivationSequenceStep(stepIndex, &step) !=
            CHATPAD_ACTIVATION_SEQUENCE_OK) {
            return CHATPAD_ACTIVATION_PREPARATION_MODEL_FAILED;
        }
        if (ChatpadTranslateActivationRequest(&step.Request, &translation) !=
            CHATPAD_CONTROL_SETUP_OK) {
            return CHATPAD_ACTIVATION_PREPARATION_TRANSLATION_FAILED;
        }

        if (translation.DataDirection ==
            CHATPAD_CONTROL_DATA_DIRECTION_HOST_TO_DEVICE) {
            expectedTransferLength = translation.OutboundPayloadLength;
        }
        else if (translation.DataDirection ==
            CHATPAD_CONTROL_DATA_DIRECTION_DEVICE_TO_HOST) {
            expectedTransferLength = translation.ExpectedInboundLength;
        }
        else {
            expectedTransferLength = 0u;
        }

        if (preparation.SequenceIndex != stepIndex ||
            preparation.RequestIndex != stepIndex ||
            preparation.DelayBeforeMilliseconds != step.DelayBeforeMilliseconds ||
            preparation.DelayAfterMilliseconds != step.DelayAfterMilliseconds ||
            preparation.DataDirection != translation.DataDirection ||
            preparation.TransferLength != expectedTransferLength ||
            preparation.OutboundPayloadLength !=
                translation.OutboundPayloadLength ||
            preparation.ExpectedInboundLength !=
                translation.ExpectedInboundLength) {
            return CHATPAD_ACTIVATION_PREPARATION_METADATA_INCONSISTENT;
        }

        for (byteIndex = 0;
            byteIndex < CHATPAD_CONTROL_SETUP_PACKET_LENGTH;
            ++byteIndex) {
            if (preparation.SetupPacket.Generic.Bytes[byteIndex] !=
                translation.SetupPacketBytes[byteIndex]) {
                return CHATPAD_ACTIVATION_PREPARATION_METADATA_INCONSISTENT;
            }
        }
        for (payloadIndex = 0;
            payloadIndex < CHATPAD_ACTIVATION_MAX_PAYLOAD_LENGTH;
            ++payloadIndex) {
            if (preparation.OutboundPayload[payloadIndex] !=
                translation.OutboundPayload[payloadIndex]) {
                return CHATPAD_ACTIVATION_PREPARATION_METADATA_INCONSISTENT;
            }
        }

        result = ChatpadPrepareActivationStep(
            stepIndex,
            &repeatedPreparation);
        if (result != CHATPAD_ACTIVATION_PREPARATION_OK) {
            return result;
        }
        for (byteIndex = 0;
            byteIndex < sizeof(preparation);
            ++byteIndex) {
            if (((const uint8_t *)&preparation)[byteIndex] !=
                ((const uint8_t *)&repeatedPreparation)[byteIndex]) {
                return CHATPAD_ACTIVATION_PREPARATION_METADATA_INCONSISTENT;
            }
        }
    }

    return CHATPAD_ACTIVATION_PREPARATION_OK;
}

ChatpadActivationPreparationResult ChatpadDriverActivationPlanCompileCheckFailures(void)
{
    ChatpadActivationPreparation preparation;
    ChatpadActivationPreparationResult result;
    const uint8_t *bytes;
    size_t byteIndex;

    result = ChatpadPrepareActivationStep(0u, 0);
    if (result != CHATPAD_ACTIVATION_PREPARATION_NULL_OUTPUT) {
        return CHATPAD_ACTIVATION_PREPARATION_METADATA_INCONSISTENT;
    }

    result = ChatpadPrepareActivationStep(0u, &preparation);
    if (result != CHATPAD_ACTIVATION_PREPARATION_OK) {
        return result;
    }

    result = ChatpadPrepareActivationStep(
        CHATPAD_ACTIVATION_SEQUENCE_STEP_COUNT,
        &preparation);
    if (result != CHATPAD_ACTIVATION_PREPARATION_INVALID_STEP_INDEX) {
        return CHATPAD_ACTIVATION_PREPARATION_METADATA_INCONSISTENT;
    }

    bytes = (const uint8_t *)&preparation;
    for (byteIndex = 0; byteIndex < sizeof(preparation); ++byteIndex) {
        if (bytes[byteIndex] != 0u) {
            return CHATPAD_ACTIVATION_PREPARATION_METADATA_INCONSISTENT;
        }
    }

    result = ChatpadPrepareActivationStep((size_t)-1, &preparation);
    if (result != CHATPAD_ACTIVATION_PREPARATION_INVALID_STEP_INDEX) {
        return CHATPAD_ACTIVATION_PREPARATION_METADATA_INCONSISTENT;
    }
    bytes = (const uint8_t *)&preparation;
    for (byteIndex = 0; byteIndex < sizeof(preparation); ++byteIndex) {
        if (bytes[byteIndex] != 0u) {
            return CHATPAD_ACTIVATION_PREPARATION_METADATA_INCONSISTENT;
        }
    }

    return CHATPAD_ACTIVATION_PREPARATION_OK;
}

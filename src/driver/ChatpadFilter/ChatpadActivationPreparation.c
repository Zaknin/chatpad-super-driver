#include "ChatpadActivationPreparation.h"

static void ChatpadClearActivationPreparation(ChatpadActivationPreparation *output)
{
    uint8_t *bytes;
    size_t index;

    if (output == 0) {
        return;
    }

    bytes = (uint8_t *)output;
    for (index = 0; index < sizeof(*output); ++index) {
        bytes[index] = 0;
    }
}

ChatpadActivationPreparationResult ChatpadPrepareActivationStep(
    size_t stepIndex,
    ChatpadActivationPreparation *output)
{
    ChatpadActivationSequenceStep step;
    ChatpadActivationSequenceResult sequenceResult;
    ChatpadControlSetupTranslation translation;
    ChatpadControlSetupResult translationResult;
    WDF_USB_CONTROL_SETUP_PACKET setupPacket;
    ChatpadWdfControlSetupResult formatterResult;
    uint16_t transferLength;
    uint16_t payloadIndex;

    if (output == 0) {
        return CHATPAD_ACTIVATION_PREPARATION_NULL_OUTPUT;
    }
    ChatpadClearActivationPreparation(output);

    if (stepIndex >= ChatpadGetActivationSequenceStepCount()) {
        return CHATPAD_ACTIVATION_PREPARATION_INVALID_STEP_INDEX;
    }

    sequenceResult = ChatpadGetActivationSequenceStep(stepIndex, &step);
    if (sequenceResult != CHATPAD_ACTIVATION_SEQUENCE_OK) {
        return CHATPAD_ACTIVATION_PREPARATION_MODEL_FAILED;
    }

    translationResult = ChatpadTranslateActivationRequest(&step.Request, &translation);
    if (translationResult != CHATPAD_CONTROL_SETUP_OK) {
        return CHATPAD_ACTIVATION_PREPARATION_TRANSLATION_FAILED;
    }

    if (translation.OutboundPayloadLength > CHATPAD_ACTIVATION_MAX_PAYLOAD_LENGTH) {
        return CHATPAD_ACTIVATION_PREPARATION_PAYLOAD_CAPACITY_EXCEEDED;
    }

    switch (translation.DataDirection) {
    case CHATPAD_CONTROL_DATA_DIRECTION_NONE:
        if (translation.OutboundPayloadLength != 0 ||
            translation.ExpectedInboundLength != 0) {
            return CHATPAD_ACTIVATION_PREPARATION_METADATA_INCONSISTENT;
        }
        transferLength = 0;
        break;

    case CHATPAD_CONTROL_DATA_DIRECTION_HOST_TO_DEVICE:
        if (translation.ExpectedInboundLength != 0) {
            return CHATPAD_ACTIVATION_PREPARATION_METADATA_INCONSISTENT;
        }
        transferLength = translation.OutboundPayloadLength;
        break;

    case CHATPAD_CONTROL_DATA_DIRECTION_DEVICE_TO_HOST:
        if (translation.OutboundPayloadLength != 0) {
            return CHATPAD_ACTIVATION_PREPARATION_METADATA_INCONSISTENT;
        }
        transferLength = translation.ExpectedInboundLength;
        break;

    default:
        return CHATPAD_ACTIVATION_PREPARATION_METADATA_INCONSISTENT;
    }

    formatterResult = ChatpadFormatWdfControlSetupPacket(&translation, &setupPacket);
    if (formatterResult != CHATPAD_WDF_CONTROL_SETUP_OK) {
        return CHATPAD_ACTIVATION_PREPARATION_WDF_FORMATTING_FAILED;
    }

    output->SetupPacket = setupPacket;
    output->DataDirection = translation.DataDirection;
    output->TransferLength = transferLength;
    output->OutboundPayloadLength = translation.OutboundPayloadLength;
    for (payloadIndex = 0;
        payloadIndex < translation.OutboundPayloadLength;
        ++payloadIndex) {
        output->OutboundPayload[payloadIndex] =
            translation.OutboundPayload[payloadIndex];
    }
    output->ExpectedInboundLength = translation.ExpectedInboundLength;
    output->SequenceIndex = step.SequenceIndex;
    output->RequestIndex = step.RequestIndex;
    output->DelayBeforeMilliseconds = step.DelayBeforeMilliseconds;
    output->DelayAfterMilliseconds = step.DelayAfterMilliseconds;

    return CHATPAD_ACTIVATION_PREPARATION_OK;
}

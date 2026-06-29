#include "ChatpadActivationRequests.h"
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

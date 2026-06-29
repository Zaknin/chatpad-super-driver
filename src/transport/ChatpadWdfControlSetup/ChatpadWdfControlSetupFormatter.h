#ifndef CHATPAD_WDF_CONTROL_SETUP_FORMATTER_H
#define CHATPAD_WDF_CONTROL_SETUP_FORMATTER_H

#include <ntddk.h>
#include <wdf.h>
#include <usb.h>
#include <usbdlib.h>
#include <wdfusb.h>

#include "ChatpadControlSetup.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef enum ChatpadWdfControlSetupResult {
    CHATPAD_WDF_CONTROL_SETUP_OK = 0,
    CHATPAD_WDF_CONTROL_SETUP_NULL_TRANSLATION,
    CHATPAD_WDF_CONTROL_SETUP_NULL_OUTPUT,
    CHATPAD_WDF_CONTROL_SETUP_INVALID_DIRECTION,
    CHATPAD_WDF_CONTROL_SETUP_LENGTH_MISMATCH,
    CHATPAD_WDF_CONTROL_SETUP_UNSUPPORTED_REPRESENTATION
} ChatpadWdfControlSetupResult;

ChatpadWdfControlSetupResult ChatpadFormatWdfControlSetupPacket(
    const ChatpadControlSetupTranslation *translation,
    WDF_USB_CONTROL_SETUP_PACKET *output);

#ifdef __cplusplus
}
#endif

#endif

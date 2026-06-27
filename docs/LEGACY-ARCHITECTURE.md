# Legacy Architecture

This document describes the historical package as preserved. It is not a design endorsement for a Windows 11 implementation.

## Components

| Component | Historical target | Evidence |
| --- | --- | --- |
| USB lower filter | `chatpad_filter` KMDF driver | `legacy/source_release_0_0_4a/filter/sources:1-18` declares `TARGETTYPE=DRIVER`, KMDF 1.9, and `chatpad_filter.cpp`. |
| Virtual keyboard KMDF layer | `chatpad_keyboard_kmdf` KMDF driver | `legacy/source_release_0_0_4a/chatpad_keyboard_kmdf/sources:1-22` declares a KMDF 1.9 driver linked with `hidclass.lib`, `ntstrsafe.lib`, and `wdmsec.lib`. |
| Virtual mouse KMDF layer | `chatpad_mouse_kmdf` KMDF driver | `legacy/source_release_0_0_4a/chatpad_mouse_kmdf/sources:1-22` mirrors the keyboard KMDF target. |
| HID keyboard minidriver | `chatpad_keyboard` WDM/HID driver | `legacy/source_release_0_0_4a/hid_keyboard_interface/sources:1-14` declares a driver target; `legacy/source_release_0_0_4a/hid_keyboard_interface/chatpad_keyboard.c:50-92` registers with hidclass. |
| HID mouse minidriver | `chatpad_mouse` WDM/HID driver | `legacy/source_release_0_0_4a/hid_mouse_interface/sources:1-14` declares a driver target; `legacy/source_release_0_0_4a/hid_mouse_interface/chatpad_mouse.c:50-92` registers with hidclass. |
| User-mode control utility | `chatpad_control` console program | `legacy/source_release_0_0_4a/chatpad_control/sources:1-22` declares a console program that includes shared IOCTL headers. |
| Installer utility | `chatpad_installer` Windows program | `legacy/source_release_0_0_4a/installer/sources:1-22` declares a Windows program using `setupapi.lib`. |

## Filter Driver Flow

The filter driver marks itself as a KMDF filter and registers PnP/power callbacks at `legacy/source_release_0_0_4a/filter/chatpad_filter.cpp:272-300`. It creates the framework device at `legacy/source_release_0_0_4a/filter/chatpad_filter.cpp:302-307`, initializes a `DEVICE_CONTEXT` at `legacy/source_release_0_0_4a/filter/chatpad_filter.cpp:315-335`, and stores lower-target and USB state in that context.

The filter allocates one 32-byte controls write buffer and URB at `legacy/source_release_0_0_4a/filter/chatpad_filter.cpp:366-431`. It also allocates two pending controls reads and two pending chatpad reads using the fixed buffer sizes and request count declared at `legacy/source_release_0_0_4a/filter/chatpad_filter.h:66-76`, with per-request state stored in `legacy/source_release_0_0_4a/filter/chatpad_filter.h:147-174`.

The filter creates a default internal-device-control queue for `IOCTL_INTERNAL_USB_SUBMIT_URB` at `legacy/source_release_0_0_4a/filter/chatpad_filter.cpp:585-612`. It also creates manual queues for parked controls requests from the upper driver, controls requests from user mode, and chatpad requests from user mode at `legacy/source_release_0_0_4a/filter/chatpad_filter.cpp:614-684`.

The user-mode control device is a sideband KMDF control device. Its extension stores a raw `PDEVICE_CONTEXT` back-pointer at `legacy/source_release_0_0_4a/filter/chatpad_filter.h:183-193`; the pointer is initialized at `legacy/source_release_0_0_4a/filter/chatpad_filter.cpp:1392-1403`.

## IOCTL Surface

The filter exposes IOCTLs for initialization status, synchronous control transfers, controls endpoint writes, controls endpoint reads, chatpad endpoint reads, controls mappings, and controls filter mode at `legacy/source_release_0_0_4a/include/chatpad_filter_ioctl.h:21-75`. Filter modes are declared at `legacy/source_release_0_0_4a/include/chatpad_filter_ioctl.h:79-90`.

The filter IOCTL handler locates the first device context from the global collection if the control device is marked available at `legacy/source_release_0_0_4a/filter/chatpad_filter.cpp:2882-2904`. If unavailable, it fails the request at `legacy/source_release_0_0_4a/filter/chatpad_filter.cpp:2906-2910`.

The virtual keyboard and mouse KMDF layers expose enable and send-data IOCTLs through shared headers. The keyboard handler covers `IOCTL_CHATPAD_KEYBOARD_KMDF_SET_ENABLED` and `IOCTL_CHATPAD_KEYBOARD_KMDF_SEND_DATA` at `legacy/source_release_0_0_4a/chatpad_keyboard_kmdf/chatpad_keyboard_kmdf.cpp:1428-1558`; the mouse handler covers matching mouse IOCTLs at `legacy/source_release_0_0_4a/chatpad_mouse_kmdf/chatpad_mouse_kmdf.cpp:1436-1557`.

## Historical Installation Metadata

The package retains INF metadata for XP, Vista, and Windows 7. These files are preserved only as source documentation for historical driver stack shape. The snapshot intentionally omits the driver binaries and coinstallers those INFs originally referenced.

## Windows 11 Implication

The preserved design assumes legacy KMDF 1.9, sideband control devices with raw context back-pointers, fixed-size USB buffers, and legacy install-era packaging. A Windows 11 port should treat this as protocol and behavior evidence only, not as a codebase to load or trust.

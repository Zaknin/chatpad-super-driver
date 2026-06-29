# Windows 11 Blockers

These blockers are based on source review only. No legacy driver binary was loaded, installed, executed, or tested.

## Critical Findings

1. Unchecked 32-byte controls write-buffer copy.

   The controls write buffer length is fixed at 32 bytes in `legacy/source_release_0_0_4a/filter/chatpad_filter.h:66-67`. The IOCTL path accepts any positive input length at `legacy/source_release_0_0_4a/filter/chatpad_filter.cpp:3077-3099` and passes `inputBufferLength` to `SendControlsWriteRequest` at `legacy/source_release_0_0_4a/filter/chatpad_filter.cpp:3101-3106`. Inside `SendControlsWriteRequest`, the URB buffer is initialized to `CONTROLS_WRITE_BUFFER_LENGTH` at `legacy/source_release_0_0_4a/filter/chatpad_filter.cpp:745-770`, then `RtlCopyMemory` copies `bytesToWrite` into that buffer without bounding `bytesToWrite` to 32 at `legacy/source_release_0_0_4a/filter/chatpad_filter.cpp:772-777`.

2. Two unchecked copies into 80-byte stack buffers.

   The completion path declares `UCHAR bufferData[80]` and copies `existingURB->UrbBulkOrInterruptTransfer.TransferBufferLength` bytes into it without checking that the transfer length is no greater than 80 at `legacy/source_release_0_0_4a/filter/chatpad_filter.cpp:2093-2099`. The internal IOCTL path repeats the same stack-buffer pattern at `legacy/source_release_0_0_4a/filter/chatpad_filter.cpp:2757-2766`.

3. Null dereference in set-filter-mode IOCTL.

   The set-filter-mode handler checks `inputBufferLength != 1` and sets `apiStatus = STATUS_INTERNAL_ERROR`, but then unconditionally calls `WdfRequestRetrieveInputBuffer` and casts the result at `legacy/source_release_0_0_4a/filter/chatpad_filter.cpp:3214-3226`. Even if retrieval fails or returns NULL, the code only logs at `legacy/source_release_0_0_4a/filter/chatpad_filter.cpp:3227-3230`, then dereferences `dataFromUser[0]` at `legacy/source_release_0_0_4a/filter/chatpad_filter.cpp:3232-3236`.

4. Control-device raw-context use-after-free risk on unplug or close in filter, keyboard, and mouse components.

   The filter control-device extension stores a raw `PDEVICE_CONTEXT` at `legacy/source_release_0_0_4a/filter/chatpad_filter.h:183-193`, initializes it at `legacy/source_release_0_0_4a/filter/chatpad_filter.cpp:1392-1403`, and later dereferences it from the close path at `legacy/source_release_0_0_4a/filter/chatpad_filter.cpp:1132-1170`. During device cleanup, the code can leave the control device alive while open handles remain, marks it unavailable, removes the framework device from the collection, and releases the lock at `legacy/source_release_0_0_4a/filter/chatpad_filter.cpp:1267-1302`. That leaves the sideband object holding a pointer into a device context whose lifetime is tied to the removed device.

   The same pattern exists in the virtual keyboard component: the control extension stores `keyboardDeviceContext` at `legacy/source_release_0_0_4a/chatpad_keyboard_kmdf/chatpad_keyboard_kmdf.h:79-90`, initializes it at `legacy/source_release_0_0_4a/chatpad_keyboard_kmdf/chatpad_keyboard_kmdf.cpp:921-932`, dereferences it in open and close paths at `legacy/source_release_0_0_4a/chatpad_keyboard_kmdf/chatpad_keyboard_kmdf.cpp:598-624` and `legacy/source_release_0_0_4a/chatpad_keyboard_kmdf/chatpad_keyboard_kmdf.cpp:663-704`, and can leave the control device alive while removing the framework device at `legacy/source_release_0_0_4a/chatpad_keyboard_kmdf/chatpad_keyboard_kmdf.cpp:802-830`.

   The mouse component mirrors the risk: it stores `mouseDeviceContext` at `legacy/source_release_0_0_4a/chatpad_mouse_kmdf/chatpad_mouse_kmdf.h:79-90`, initializes it at `legacy/source_release_0_0_4a/chatpad_mouse_kmdf/chatpad_mouse_kmdf.cpp:929-940`, dereferences it in open and close paths at `legacy/source_release_0_0_4a/chatpad_mouse_kmdf/chatpad_mouse_kmdf.cpp:608-634` and `legacy/source_release_0_0_4a/chatpad_mouse_kmdf/chatpad_mouse_kmdf.cpp:673-714`, and can leave the control device alive while removing the framework device at `legacy/source_release_0_0_4a/chatpad_mouse_kmdf/chatpad_mouse_kmdf.cpp:810-838`.

5. Unchecked copy into the original upper driver's URB buffer.

   When a controls read completes, the filter retrieves the parked upper-driver request and copies `bytesTransferred` into `topLevelUrb->UrbBulkOrInterruptTransfer.TransferBuffer` at `legacy/source_release_0_0_4a/filter/chatpad_filter.cpp:1588-1606`. There is no visible check that the upper driver's original transfer buffer length is at least `bytesTransferred` before the copy.

6. Unconditional success return from filter `EvtDeviceAdd`.

   `ChatpadFilterEvtDeviceAdd` creates queues and the control device under `retStatus`, but ignores the control-device creation result at `legacy/source_release_0_0_4a/filter/chatpad_filter.cpp:712-718`. The function then always returns `STATUS_SUCCESS` at `legacy/source_release_0_0_4a/filter/chatpad_filter.cpp:720-721`, masking earlier failure paths in the add-device sequence.

## Additional Porting Blockers

- Legacy targets use KMDF 1.9 in the source metadata at `legacy/source_release_0_0_4a/filter/sources:1-18`, `legacy/source_release_0_0_4a/chatpad_keyboard_kmdf/sources:1-22`, and `legacy/source_release_0_0_4a/chatpad_mouse_kmdf/sources:1-22`.
- The WDM HID minidrivers clear `DO_DEVICE_INITIALIZING` and return success in AddDevice with minimal setup at `legacy/source_release_0_0_4a/hid_keyboard_interface/chatpad_keyboard.c:105-115` and `legacy/source_release_0_0_4a/hid_mouse_interface/chatpad_mouse.c:105-115`.
- The filter globally selects the first device context from a collection for user IOCTLs at `legacy/source_release_0_0_4a/filter/chatpad_filter.cpp:2882-2894`, which is not a robust multi-device model.
- The historical notes already mention driver-verifier pool-tracking concerns at `legacy/source_release_0_0_4a/notes.txt:4-10`.

## Package and installation blockers

- The offline extension INF passes WDK declarative static validation, but no
  catalog or complete package layout has been generated or validated.
- The declared `ChatpadFilterExtension.cat` does not exist and no package or
  binary is signed.
- Static `AddFilter`/`FilterPosition=Lower` metadata does not prove effective
  placement beneath `xusb22` or preservation of ordinary controller behavior.
- No package has been staged, installed, loaded, removed, or recovery-tested.
- Gate F remains blocked on independent review against an actual signed package
  and a noncritical-system recovery demonstration.

## Required Resolution Before Any Windows 11 Driver Work

- Replace raw sideband context pointers with lifetime-safe references or per-file context ownership.
- Add strict input and output length validation before every kernel copy.
- Fail IOCTL paths immediately after failed buffer retrieval.
- Return real failure status from device-add paths.
- Build a protocol parser and packet fixture suite in user mode before writing modern kernel code.
- Treat all preserved legacy binaries as untrusted and excluded from this repository.

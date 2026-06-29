# Chatpad Protocol Evidence Document

## Scope and Safety

This document contains ONLY confirmed protocol evidence extracted from the immutable legacy codebase at `legacy/source_release_0_0_4a/`. All information is sourced from actual code, constants, and data structures—no speculative interpretations.

**Safety restrictions enforced:**
- No hardware access attempted
- No device enumeration performed
- No IOCTLs issued
- No driver loaded
- No build configurations modified
- No binaries or generated files created

---

## Evidence Sources

| Source | Path | Lines | Type |
|--------|------|-------|------|
| Chatpad Filter IOCTL Header | `legacy/source_release_0_0_4a/include/chatpad_filter_ioctl.h` | Full | Constants/Structures |
| Chatpad Control Code | `legacy/source_release_0_0_4a/chatpad_control/chatpad_control_code.cpp` | 3370-4854 | Implementation |
| Chatpad Control Header | `legacy/source_release_0_0_4a/chatpad_control/chatpad_control.h` | Full | Constants |
| Chatpad Filter Header | `legacy/source_release_0_0_4a/filter/chatpad_filter.h` | 67-73 | Constants |

---

## A. Device or Wire-Format Evidence

Packets or bytes actually received from or sent to the Chatpad/device transport endpoint.

### 1. Chatpad Keyboard Packet (5 bytes)

**Confirmed from:** `HandleChatpadData` function, lines 3370-3600

This is the packet as processed by the filter driver when reading from the chatpad endpoint. The 5-byte form is the meaningful payload extracted from the 32-byte buffer.

| Byte | Description | Value Range | Notes |
|------|-------------|-------------|-------|
| Byte0 | Type/Prefix | 0x00 (data), 0xF0 (unsupported meaning) | 0xF0 packets are ignored per line 3419; exact meaning is not established |
| Byte1 | Modifier Bits | 0x00-0x0F | 4-bit field for SHIFT/GREEN/ORANGE/PEOPLE |
| Byte2 | Raw Key Slot 1 | 0x00-0xFF | 0x00 = no key, otherwise scan code index |
| Byte3 | Raw Key Slot 2 | 0x00-0xFF | 0x00 = no key, otherwise scan code index |
| Byte4 | Unknown Field | 0x00-0xFF | Used in state comparison at line 3499; purpose not confirmed |

**Buffer size:** 32 bytes allocated (`CHATPAD_READ_BUFFER_LENGTH`, line 73, chatpad_filter.h), but only 5 bytes are meaningful.

---

## B. Internal Software Structures

Data passed between legacy components. These are NOT confirmed as Chatpad wire packets unless legacy evidence directly proves they are transmitted unchanged on the device endpoint.

**Label convention:** Internal transport structure — not confirmed as Chatpad wire format.

### 1. Virtual Mouse Message (4 bytes)

**Source:** `mouseDataBuffer` usage, lines 1803-1839

**NOT a Chatpad wire packet.** This is the message constructed by the driver to emulate a virtual mouse device to Windows. The chatpad has no physical mouse. The document's own note (line 249) states: "This is a VIRTUAL mouse device sent to Windows, NOT the chatpad itself."

| Byte | Description | Value Range | Notes |
|------|-------------|-------------|-------|
| Byte0 | High state byte | 0x00-0xFF | Contains button state from `uVirtualMouseState` |
| Byte1 | X offset | -128 to 127 | Signed byte, shifted from `nScaledXValue` |
| Byte2 | Y offset | -128 to 127 | Signed byte, shifted from `nScaledYValue` |
| Byte3 | Wheel delta | 0x01 (up) or 0xFF (down) | 0x00 = no wheel movement |

**Buffer size:** 4 bytes (`VIRTUAL_MOUSE_MESSAGE_NUM_BYTES`, line 37, chatpad_control.h)

**State accumulation:** `uVirtualMouseState` is a 32-bit value where:
- Bits 24-31: Button state (byte0)
- Bits 16-23: X offset
- Bits 8-15: Y offset
- Bits 0-7: Unknown (cleared with `& 0xFF0000FF` at line 3010)

### 2. USB Control Transfer Parameters (9 bytes base)

**Source:** `SendControlRequest` function, lines 748-839

**NOT a Chatpad wire packet.** These are the parameters used to construct a USB control request (setup packet fields), not a serialized wire frame from the device.

| Offset | Field | Size | Notes |
|--------|-------|------|-------|
| 0x00 | Interface | 1 byte | 0=MAIN, 1=CONTROLS, 2=CHATPAD (XBOX_CONTROLLER_INTERFACE enum) |
| 0x01 | Request Type | 1 byte | e.g., 0x41 for chatpad commands |
| 0x02 | Request | 1 byte | e.g., 0x00 |
| 0x03 | Value (low) | 1 byte | Lower 8 bits of 16-bit value |
| 0x04 | Value (high) | 1 byte | Upper 8 bits of 16-bit value |
| 0x05 | Index (low) | 1 byte | Lower 8 bits of 16-bit index |
| 0x06 | Index (high) | 1 byte | Upper 8 bits of 16-bit index |
| 0x07 | Length (low) | 1 byte | Lower 8 bits of 16-bit length |
| 0x08 | Length (high) | 1 byte | Upper 8 bits of 16-bit length |
| 0x09+ | Extra Data | variable | Additional payload bytes |

**Total control request:** 9 bytes base + extra data length

### 3. IOCTL Transport Structures

**Source:** `chatpad_filter_ioctl.h`, lines 24-75

Internal kernel-mode IOCTL definitions. Not wire format.

| IOCTL | Code | Direction |
|-------|------|-----------|
| IOCTL_CHATPAD_IS_MS_INIT_DONE | CTL_CODE(41000, 2049, ...) | Read/Write |
| IOCTL_CHATPAD_SEND_CONTROL_TRANSFER | CTL_CODE(41000, 2050, ...) | Read/Write |
| IOCTL_CHATPAD_WRITE_TO_CONTROLS_ENDPOINT | CTL_CODE(41000, 2051, ...) | Read/Write |
| IOCTL_CHATPAD_READ_FROM_CONTROLS_ENDPOINT | CTL_CODE(41000, 2052, ...) | Read/Write |
| IOCTL_CHATPAD_READ_FROM_CHATPAD_ENDPOINT | CTL_CODE(41000, 2053, ...) | Read/Write |
| IOCTL_CHATPAD_SET_CONTROLS_MAPPINGS | CTL_CODE(41000, 2054, ...) | Read/Write |
| IOCTL_CHATPAD_SET_CONTROLS_FILTER_MODE | CTL_CODE(41000, 2055, ...) | Read/Write |

**Device type:** 41000 (FILE_DEVICE_CHATPAD_FILTER)
**Transfer method:** METHOD_BUFFERED

### 4. Filter Mode Enum

**Source:** `chatpad_filter_ioctl.h`, lines 80-90

| Mode | Value | Description |
|------|-------|-------------|
| FILTER_MODE_UNFILTERED | 0 | No mapping, passthrough |
| FILTER_MODE_FILTERED | 1 | Allows guide button mapping |
| FILTER_MODE_INTERCEPTED | 2 | Windows Mode, thumbsticks control mouse |

**Usage:** Set via IOCTL_CHATPAD_SET_CONTROLS_FILTER_MODE

**Windows Mode toggle:** Lines 2200-2275 show:
- On: Set FILTER_MODE_INTERCEPTED, turn on People light
- Off: Set FILTER_MODE_FILTERED (or UNFILTERED if disabled), turn off People light, clear all state

### 5. Request Buffer Structure

**Source:** `chatpad_filter_ioctl.h`, lines 127-159

```c
typedef struct _CHATPAD_REQUEST_ENTRY_HEADER {
    REQUEST_TYPE requestType;  // 2 bytes
} CHATPAD_REQUEST_ENTRY_HEADER, *PCHATPAD_REQUEST_ENTRY_HEADER;

typedef struct _CHATPAD_INIT_REQUEST {
    UCHAR initCode[2];  // 2 bytes (0x90, 0x00)
} CHATPAD_INIT_REQUEST, *PCHATPAD_INIT_REQUEST;

typedef struct _CHATPAD_REQUEST : CHATPAD_REQUEST_ENTRY_HEADER {
    union {
        CHATPAD_INIT_REQUEST initRequest;
        // TODO: add read, write, maybe others
    };
} CHATPAD_REQUEST, *PCHATPAD_REQUEST;

#define MAX_CHATPAD_REQUESTS_PER_BUFFER   0x0200  // 512

typedef struct _CHATPAD_REQUEST_BUFFER {
    LIST_ENTRY listEntry;
    ULONG validRequestCount;
    CHATPAD_REQUEST chatpadRequests[MAX_CHATPAD_REQUESTS_PER_BUFFER];
} CHATPAD_REQUEST_BUFFER, *PCHATPAD_REQUEST_BUFFER;
```

**REQUEST_TYPE values:**
- ControlsWriteRequest = 0x3000
- ControlsReadRequest = 0x3001
- ChatpadReadRequest = 0x3002
- ChatpadMaxRequestType = 0x3003

---

## Control Request Examples

**Source:** `SendControlRequest` calls, lines 1744, 1749, 1923, 1932, 2130, 2136, 2157, 2163, 2184, 2190, 2211, 2232

| Purpose | Interface | Type | Value | Index | Length | Notes |
|---------|-----------|------|-------|-------|--------|-------|
| Caps Lock On | CHATPAD (2) | 0x41 | 0x0008 | 0x0002 | 0x0000 | Turns on caps lock LED |
| Caps Lock Off | CHATPAD (2) | 0x41 | 0x0000 | 0x0002 | 0x0000 | Turns off caps lock LED |
| Green Square On | CHATPAD (2) | 0x41 | 0x0009 | 0x0002 | 0x0000 | Turns on green LED |
| Green Square Off | CHATPAD (2) | 0x41 | 0x0001 | 0x0002 | 0x0000 | Turns off green LED |
| Orange Circle On | CHATPAD (2) | 0x41 | 0x000A | 0x0002 | 0x0000 | Turns on orange LED |
| Orange Circle Off | CHATPAD (2) | 0x41 | 0x0002 | 0x0002 | 0x0000 | Turns off orange LED |
| People Light On | CHATPAD (2) | 0x41 | 0x000B | 0x0002 | 0x0000 | Turns on people LED |
| People Light Off | CHATPAD (2) | 0x41 | 0x0003 | 0x0002 | 0x0000 | Turns off people LED |
| Backlight Off | CHATPAD (2) | 0x41 | 0x0004 | 0x0002 | 0x0000 | Turns off backlight |

**Pattern:** All LED control commands use interface 2 (CHATPAD), type 0x41, value 0x0002 for index.

**Timing constraint:** 12ms delay between control requests (line 838)

---

## Initialization Code

The focused audit in `docs/CHATPAD-INIT-STATUS-EVIDENCE.md` supersedes the
earlier interpretation of this declaration.

**Source:** `CHATPAD_INIT_REQUEST` structure, lines 132-137,
`chatpad_filter_ioctl.h`

The header contains a tentative comment saying a 16-bit init code is “like
`0x90 0x00`” and immediately questions whether it is correct. The declaration
only creates `UCHAR initCode[2]`; it does not assign either byte. Targeted
legacy-tree searches find no use of `CHATPAD_INIT_REQUEST`, `initRequest`, or
`initCode` outside the declarations.

**Corrected classification:** `0x90 0x00` is a comment-only claim attached to
an unused internal structure. It is not proven payload or a USB setup field.
The executable legacy activation path instead supplies confirmed two-byte
payload `0x09 0x00` in `InitChatpad` at
`chatpad_control_code.cpp:4209-4212`. The surrounding setup fields, response
handling, status loop, and unresolved semantics are documented in the focused
audit.

### Declarative Activation Request Builder

**Classification:** Offline declarative representation of confirmed USB setup
fields and payload bytes. It is not transport code and does not send requests.

`src/protocol/ChatpadProtocol/ChatpadActivationRequests.h` and `.c` expose
exactly six activation request descriptors reconstructed from
`docs/CHATPAD-INIT-STATUS-EVIDENCE.md`. The descriptors preserve raw setup
fields, direction, outbound payload length, expected device-to-host data-stage
length, and embedded outbound payload bytes. They do not represent a complete
initialization success condition.

| Index | Direction | `bmRequestType` | `bRequest` | `wValue` | `wIndex` | `wLength` | Outbound payload | Expected inbound data |
|---:|---|---:|---:|---:|---:|---:|---|---:|
| 0 | host to device | `40` | `a9` | `a30c` | `4423` | `0000` | none | `0000` |
| 1 | host to device | `40` | `a9` | `2344` | `7f03` | `0000` | none | `0000` |
| 2 | host to device | `40` | `a9` | `5839` | `6832` | `0000` | none | `0000` |
| 3 | device to host | `c0` | `a1` | `0000` | `e416` | `0002` | none | `0002` |
| 4 | host to device | `40` | `a1` | `0000` | `e416` | `0002` | `09 00` | `0000` |
| 5 | device to host | `c0` | `a1` | `0000` | `e416` | `0002` | none | `0002` |

`09 00` is the only confirmed outbound payload. `90 00` is deliberately absent
from request descriptors, fixtures, payloads, and tests. Device-to-host
descriptors request two bytes by setup `wLength` only; no response bytes,
acknowledgement schema, ready state, retry policy, timeout behavior, or status
meaning is fabricated.

### Offline State-Machine Classification Boundary

**Classification:** Project abstraction — not wire-format evidence.

The portable offline state machine does not decode initialization or status
bytes. It accepts neutral caller-provided events for accepted keyboard data,
unsupported input, policy-rejected input, and unresolved control/status input.
These events are classifications supplied by a caller or derived from an
existing keyboard parser result; they are not claimed to be packets, status
codes, transport events, or proof that a device is initialized or ready.

Parser argument/length failures remain unclassified and cause no state
transition. The unresolved control/status event deliberately preserves the
evidence boundary around `0x90, 0x00` and every undocumented status form.

---

## Keyboard Data Interpretation

### Modifier Bit Mapping

**Source:** `chatpadModifierMaskTable`, lines 303-309

| Modifier Mask | Key Constant | LED |
|---------------|--------------|-----|
| CHATPAD_MODIFIER_SHIFT (likely 0x01) | CHATPAD_KEY_SHIFT | Caps Lock |
| CHATPAD_MODIFIER_GREEN (likely 0x02) | CHATPAD_KEY_GREEN | Green Square |
| CHATPAD_MODIFIER_ORANGE (likely 0x04) | CHATPAD_KEY_ORANGE | Orange Circle |
| CHATPAD_MODIFIER_PEOPLE (likely 0x08) | CHATPAD_KEY_PEOPLE | People |

**Note:** Exact bit values not confirmed, but standard bitmask pattern (0x01, 0x02, 0x04, 0x08) strongly inferred from usage pattern at line 3455.

### Scan Code Table

**Source:** `chatpadScanCodeTable`, lines 41-299

**Confirmed mappings (partial):**

| Raw Code | Key | Raw Code | Key |
|----------|-----|----------|-----|
| 0x11 | 7 | 0x21 | u |
| 0x12 | 6 | 0x22 | y |
| 0x13 | 5 | 0x23 | t |
| 0x14 | 4 | 0x24 | r |
| 0x15 | 3 | 0x25 | e |
| 0x16 | 2 | 0x26 | w |
| 0x17 | 1 | 0x27 | q |
| 0x31 | j | 0x32 | h |
| 0x33 | g | 0x34 | f |
| 0x35 | d | 0x36 | s |
| 0x37 | a | 0x41 | n |
| 0x42 | b | 0x43 | v |
| 0x44 | c | 0x45 | x |
| 0x46 | z | 0x51 | Right Arrow |
| 0x52 | m | 0x53 | . |
| 0x54 | Spacebar | 0x55 | Left Arrow |
| 0x62 | , | 0x63 | Enter |
| 0x64 | p | 0x65 | 0 |
| 0x66 | 9 | 0x67 | 8 |
| 0x71 | Backspace | 0x72 | l |
| 0x75 | o | 0x76 | i |
| 0x77 | k | - | - |

**Layout:** QWERTY keyboard layout, standard US layout.

**Unknown codes:** All values not listed above map to CHATPAD_KEY_NONE (0x00).

---

## Modifier and Key-Field Evidence

### Modifier State Machine

**Source:** `HandleChatpadData`, lines 3449-3492

The code processes modifiers and keys in two separate loops:

1. **Modifier loop** (4 iterations, lines 3453-3471):
   - Checks if modifier bit is set in Byte1
   - Maps to CHATPAD_KEY_ constant
   - Stores in `newKeysDown[0]` or `newKeysDown[1]`

2. **Key loop** (2 iterations, lines 3474-3492):
   - Checks if scan code byte is non-zero
   - Maps through `chatpadScanCodeTable`
   - Stores in `newKeysDown[0]` or `newKeysDown[1]`

**Constraint:** Maximum 2 keys held simultaneously (line 3439).

### Key State Tracking

**Source:** `HandleChatpadData`, lines 3494-3600

State variables:
- `previousChatpadRawData[5]` - Previous packet (compared byte-by-byte)
- `currentKeysDown[2]` - Last processed keys
- `newKeysDown[2]` - Current packet's keys
- `ignoreNextRepeatedData` - Flag to prevent double processing

**Logic flow:**
1. If packet matches previous AND `ignoreNextRepeatedData == true` → skip, clear flag
2. Else → set `ignoreNextRepeatedData = true`, process packet
3. Compare `currentKeysDown` with `newKeysDown` to detect press/release
4. Send stop actions for released keys
5. Send start actions for pressed keys

---

## Confirmed Validation Rules

### Packet Length Validation

**Source:** Buffer definitions, lines 67-73, chatpad_filter.h

- All chatpad buffers are 32 bytes (`#define CONTROLS_WRITE_BUFFER_LENGTH 32`)
- Actual data payload is smaller (5 bytes for keyboard, 4 bytes for mouse)
- No validation checks observed—raw buffer passed to endpoint

### Repeated Packet Handling

**Source:** `HandleChatpadData`, lines 3494-3504

**Rule:** 
- If current packet matches previous packet AND `ignoreNextRepeatedData == true`:
  - Skip processing
  - Clear `ignoreNextRepeatedData`
- Else:
  - Set `ignoreNextRepeatedData = true`
  - Process packet

**Purpose:** Prevent double-processing of identical packets

### Maximum Key Constraint

**Source:** Line 3439 comment

"No more than any two keys are registered at a time by the chatpad, apparently."

**Implementation:** `newKeysDown[2]` array with maximum 2 slots

---

## Inferred Behavior

### 1. USB HID Protocol

**Inferred from:** Control transfer structure and endpoint usage

The chatpad uses standard USB HID control transfers:
- Interface 2 (CHATPAD_INTERFACE) for chatpad-specific commands
- Request type 0x41 for chatpad LED control
- Index 0x0002 for LED command parameter

**Confidence:** HIGH (based on consistent usage pattern)

### 2. Keypress Debouncing

**Inferred from:** State machine at lines 3494-3600

The `ignoreNextRepeatedData` flag suggests the device sends repeated identical packets. The driver debounces by:
1. First occurrence: Process normally
2. Second consecutive occurrence: Skip
3. New packet: Process normally

**Confidence:** MEDIUM (implementation pattern is clear, but protocol specification is not explicit)

### 3. LED Control Protocol

**Inferred from:** Control request examples, lines 1744-2232

**Pattern:**
- All LED commands use interface 2, type 0x41
- Value byte encodes LED ID and on/off state
- Index 0x0002 is constant for LED commands

**Hypothesized LED mapping:**
- 0x0008: Caps Lock (value 8 = on, 0 = off)
- 0x0009: Green Square (value 9 = on, 1 = off)
- 0x000A: Orange Circle (value 10 = on, 2 = off)
- 0x000B: People (value 11 = on, 3 = off)
- 0x0004: Backlight (value 4 = off only)

**Confidence:** LOW-MEDIUM (values observed, but full encoding scheme not documented)

---

## Conflicts and Unresolved Questions

### 1. Modifier Bit Values

**Unresolved:** Exact bit positions for SHIFT, GREEN, ORANGE, PEOPLE modifiers

**Evidence:** 
- Table at line 303-309 shows mapping but not bit values
- Usage at line 3455 suggests bitmask pattern
- Standard practice implies 0x01, 0x02, 0x04, 0x08

**Required:** Reverse engineer from device behavior or find undocumented constants

### 2. Byte4 Purpose

**Unresolved:** Function of Byte4 in 5-byte keyboard packet

**Evidence:**
- Used in state comparison at line 3499
- Never directly accessed for key processing
- Present in `previousChatpadRawData[5]` array

**Classification:** Byte 4 is part of the packet received on the wire endpoint (it occupies slot 4 in the 5-byte keyboard packet processed by `HandleChatpadData`), but its semantic purpose is unknown. It is preserved in comparison state but not interpreted.

**Hypotheses:**
- Reserved/padding
- Secondary modifier field
- Checksum or validation byte

**Confidence:** LOW

### 3. Initialization Sequence

**Unresolved:** Complete initialization sequence beyond 0x90, 0x00

**Evidence:**
- Only `CHATPAD_INIT_REQUEST` structure observed (line 132-137)
- Comment suggests "16-bit init code" (line 134)
- No other init commands found in code

**Confidence:** LOW (incomplete evidence)

### 4. Controls Endpoint Format

**Unresolved:** Structure of controls data read from thumbsticks/buttons

**Evidence:**
- `CONTROLS_READ_BUFFER_LENGTH` is 32 bytes (line 70)
- `HandleControlsButtonPress` processes readBuffer[2] and readBuffer[3] (lines 3041-3140)
- Button masks observed:
  - LB: bit 0 of byte3
  - RB: bit 1 of byte3
  - Guide: bit 2 of byte3
  - A: bit 4 of byte3
  - Back: bit 5 of byte2
  - Start: bit 4 of byte2
  - L Stick Click: bit 6 of byte2
  - R Stick Click: bit 7 of byte2

**Confidence:** MEDIUM (button bits confirmed, full structure not)

---

## Intentionally Unsupported Forms

### Forms Not Implemented in Legacy Code

The following protocol forms are NOT supported by the legacy implementation:

1. **Firmware updates** - No update protocol observed
2. **Device configuration** - No user-configurable parameters beyond filter mode
3. **Multiple device instances** - Single device assumption throughout
4. **Error recovery** - No retry logic for failed control transfers
5. **Power management** - No sleep/wake protocols
6. **Firmware version query** - No version reporting

---

## Legacy Defects Not to Reproduce

### 1. Buffer Size Mismatch

**Defect:** 32-byte buffers used for 5-byte payloads (lines 67-73, chatpad_filter.h)

**Risk:** Wasted memory, potential confusion about actual data size

**Fix:** Use exact payload sizes (5 bytes for keyboard, 4 bytes for mouse)

### 2. Hardcoded Timing

**Defect:** 12ms delay hardcoded (line 838)

**Risk:** Suboptimal performance, platform-specific behavior

**Fix:** Make timing configurable or calculate dynamically

### 3. Missing Error Handling

**Defect:** No validation of control transfer results (lines 819-826)

**Risk:** Silent failures, undefined behavior on device errors

**Fix:** Check bytesTransferred and return codes

### 4. Global State

**Defect:** Many global variables (lines 320-340, chatpad_control_code.cpp)

**Risk:** Thread safety issues, difficult to test

**Fix:** Use state structures, pass via parameters

### 5. Incomplete State Machine

**Defect:** `CHATPAD_REQUEST` union only implements `initRequest` (line 143-150)

**Risk:** Other request types (read, write) not implemented

**Fix:** Complete union implementation or document as TODO

---

## Proposed Phase 1 Parser Boundary

**Classification:** Project policy — not proven device requirements. These are conservative implementation choices for the first parser, clearly labeled as policy decisions rather than confirmed protocol validation rules.

### Minimum Viable Parser

Based on confirmed evidence, Phase 1 should handle:

**Supported Packet Types:**
1. Keyboard packet: 5 bytes, Byte0 = 0x00

**Required Fields:**
- Byte0: Packet type discriminator
- Byte1: Modifier bits (4-bit field)
- Byte2-3: Raw scan codes (2 bytes)
- Byte4: Unknown (preserve as raw)

**Reject:**
- Packets with Byte0 = 0xF0 (unsupported; exact meaning unresolved) — legacy code ignores this form at source line 3419
- Packets shorter than 5 bytes — conservative policy
- Packets with invalid modifier values (bits 4-7 should be 0) — **Proposed Phase 1 policy**, not confirmed protocol requirement

**Postpone:**
- Controls endpoint data (thumbsticks/buttons)
- Initialization sequences
- LED control commands
- Virtual mouse messages (separate subsystem)

---

## Proposed Fixture Inventory

### Phase 1 Fixture Set

**Keyboard Packets (5 bytes each):**

1. **No keys pressed:**
   - 0x00, 0x00, 0x00, 0x00, 0x00

2. **Single modifier (SHIFT):**
   - 0x00, 0x01, 0x00, 0x00, 0x00 (assuming 0x01 = SHIFT)

3. **Single key (letter 'a'):**
   - 0x00, 0x00, 0x37, 0x00, 0x00 (0x37 = 'a')

4. **Modifier + key (SHIFT + 'a'):**
   - 0x00, 0x01, 0x37, 0x00, 0x00

5. **Two keys (simultaneous):**
   - 0x00, 0x00, 0x37, 0x21, 0x00 ('a' + 'u')

6. **Unknown Byte4 values:**
   - 0x00, 0x00, 0x00, 0x00, 0x01
   - 0x00, 0x00, 0x00, 0x00, 0xFF

**Edge Cases:**

7. **Unsupported type form (Byte0 = 0xF0; exact meaning unresolved):**
   - 0xF0, 0x00, 0x00, 0x00, 0x00

8. **Short packet (invalid):**
   - 0x00, 0x00, 0x00 (only 3 bytes)

9. **Invalid modifier (high bits set):**
   - 0x00, 0x10, 0x00, 0x00, 0x00 (bit 4 set)

---

## Evidence Table

| # | Evidence | Source | Confidence | Notes |
|---|----------|--------|------------|-------|
| 1 | Keyboard packet is 5 bytes | HandleChatpadData, line 3370-3600 | HIGH | Confirmed by buffer size and processing |
| 2 | Byte0 = 0x00 for data; 0xF0 is ignored with exact meaning unresolved | HandleChatpadData, line 3419 | HIGH | Explicit check, neutral semantic classification |
| 3 | Byte1 contains 4 modifier bits | chatpadModifierMaskTable, lines 303-309 | MEDIUM | 4 modifiers, standard bitmask pattern |
| 4 | Byte2-3 are raw scan codes | HandleChatpadData, lines 3474-3492 | HIGH | Used in `chatpadScanCodeTable` lookup |
| 5 | Byte4 purpose unknown | HandleChatpadData, line 3499 | LOW | Used in comparison but not interpreted; present in wire packet |
| 6 | Mouse message is 4 bytes | VIRTUAL_MOUSE_MESSAGE_NUM_BYTES, line 37 | HIGH | Explicit constant; internal virtual device, NOT wire format |
| 7 | Control transfer is 9 bytes base | SendControlRequest, lines 799-810 | HIGH | USB control request parameters — internal, NOT chatpad wire format |
| 8 | LED commands use interface 2, type 0x41 | Lines 1744, 1749, etc. | HIGH | Consistent pattern |
| 9 | Initialization code is 0x90, 0x00 | CHATPAD_INIT_REQUEST, line 134 | MEDIUM | From C header struct; whether it is a complete command, partial payload, or isolated constants is unresolved |
| 10 | Max 2 simultaneous keys | HandleChatpadData, line 3439 | HIGH | Comment and array size |
| 11 | Filter modes: 0=UNFILTERED, 1=FILTERED, 2=INTERCEPTED | chatpad_filter_ioctl.h, lines 80-90 | HIGH | Explicit enum |
| 12 | Button masks for controls data | Lines 3041-3140 | MEDIUM | Bits extracted from byte2/byte3 |
| 13 | 12ms delay between control requests | SendControlRequest, line 838 | HIGH | Hardcoded Sleep(12) |
| 14 | 32-byte buffer size | chatpad_filter.h, lines 67-73 | HIGH | Explicit #define |
| 15 | Scan code table is 256 entries | chatpadScanCodeTable, lines 41-299 | HIGH | Array declaration |
| 16 | QWERTY layout confirmed | chatpadScanCodeTable, lines 60-299 | HIGH | Keys mapped in QWERTY order |
| 17 | Repeated packet handling | HandleChatpadData, lines 3494-3504 | HIGH | State machine observed |
| 18 | uVirtualMouseState bit layout | Lines 1804-1809, 3010-3012 | MEDIUM | Extracted from code, not documented |
| 19 | IOCTL device type = 41000 | chatpad_filter_ioctl.h, line 19 | HIGH | Explicit #define |
| 20 | IOCTL codes 2049-2055 | chatpad_filter_ioctl.h, lines 24-75 | HIGH | Explicit #define |

---

## Conclusion

This document captures all confirmed protocol evidence from the legacy codebase, clearly separated into:

- **Section A: Device or Wire-Format Evidence** — Only the 5-byte keyboard packet processed by `HandleChatpadData` is confirmed as a chatpad wire packet.
- **Section B: Internal Software Structures** — Virtual mouse messages, USB control transfer parameters, IOCTL definitions, filter modes, and request buffer structures. These are NOT confirmed as chatpad wire format.

The most critical findings are:

1. **Keyboard packets are 5 bytes** with a clear structure for modifiers and scan codes — confirmed wire evidence
2. **Virtual mouse messages (4 bytes)** are internal software constructs, not chatpad wire data
3. **USB control transfer parameters (9 bytes base)** are USB setup packet fields, not a chatpad wire frame
4. **State machine handles repeated packets** via `ignoreNextRepeatedData` flag
5. **Maximum 2 simultaneous keys** enforced by array size
6. **Byte 4** is part of the wire packet but its purpose is unresolved
7. **Initialization bytes 0x90, 0x00** come from a C header struct; whether they form a complete command, partial payload, or are isolated constants is unresolved

**Recommendation:** Phase 1 parser should focus on keyboard packets (5 bytes) with validation for Byte0 type, modifier bits, and scan code ranges. Controls data and mouse messages are separate subsystems that can be implemented later. Validation choices in the parser boundary are project policy, not proven device requirements.

---

*Document generated from legacy source_release_0_0_4a analysis. All information is evidence-based and traceable to source code.*

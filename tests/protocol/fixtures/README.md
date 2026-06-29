# Chatpad Protocol Fixtures

`ChatpadKeyboardFixtures.h` contains neutral synthetic byte arrays for the
Phase 1 parser. They preserve the five-byte shape documented in
`docs/CHATPAD-PROTOCOL.md`, Section A, but are not device captures and are not
represented as observed hardware traffic.

`ChatpadProtocolStateMachineFixtures.h` contains neutral synthetic abstract
events. They are caller classifications for offline testing, not raw
initialization/status frames, transport events, or hardware observations.

`ChatpadActivationRequestFixtures.h` contains the six activation request
descriptors reconstructed from confirmed legacy-source evidence in
`docs/CHATPAD-INIT-STATUS-EVIDENCE.md`. They are not hardware captures and do
not describe acknowledgement, ready-state, retry, timeout, or response
semantics.

`ChatpadActivationSequenceFixtures.h` contains only the timing metadata used by
offline activation-sequence tests. It records zero before-delay metadata and
12 ms post-request metadata for each step, derived from the legacy
`SendControlRequest` post-call sleep evidence. It does not represent active
sleeping, timeout policy, retry policy, acknowledgement, readiness, or a
device-required delay.

## Provenance and Naming

The arrays use raw field and boundary names only. They do not label a modifier
bit as Shift, assign a key name to a raw byte, or claim a scan-code meaning.
Activation fixtures use raw setup-field names and explicit payload length
fields only; they do not label the sequence as successful initialization.
Sequence fixtures use timing metadata names only and do not duplicate request
tuples.

| Fixture | Purpose |
| --- | --- |
| `ValidNoKeys` | Supported type with all remaining raw bytes zero. |
| `ValidRawModifierBit0` | Synthetic accepted raw modifier bit. |
| `ValidRawModifierBoundary` | Maximum modifier value accepted by Phase 1 policy. |
| `ValidRawKey0Nonzero` | Synthetic nonzero first raw key byte. |
| `ValidTwoRawKeys` | Synthetic nonzero values in both raw key slots. |
| `ValidRawBoundary` | Accepted raw boundary values, including unresolved Byte 4. |
| `ValidRawByte4Nonzero` | Nonzero unresolved Byte 4 value. |
| `ValidRawByte4Boundary` | Maximum unresolved Byte 4 value. |
| `UnsupportedTypeF0` | Documented `0xF0` form rejected neutrally as unsupported. |
| `UnsupportedTypeOther` | Another synthetic unsupported raw type. |
| `PolicyRejectedModifierBit4` | First modifier value rejected by Phase 1 policy. |
| `PolicyRejectedModifierBoundary` | Synthetic upper-bit rejection boundary. |
| `OversizedPacket` | Six-byte synthetic length boundary. |
| `LargerOversizedPacket` | Larger synthetic oversized input. |

| Activation fixture | Purpose |
| --- | --- |
| `ConfirmedActivationRequests[0]` | First confirmed no-payload host-to-device `40 a9 a30c 4423 0000` setup tuple. |
| `ConfirmedActivationRequests[1]` | Second confirmed no-payload host-to-device `40 a9 2344 7f03 0000` setup tuple. |
| `ConfirmedActivationRequests[2]` | Third confirmed no-payload host-to-device `40 a9 5839 6832 0000` setup tuple. |
| `ConfirmedActivationRequests[3]` | Confirmed device-to-host `c0 a1 0000 e416 0002` setup tuple with no outbound payload or fabricated response bytes. |
| `ConfirmedActivationRequests[4]` | Confirmed host-to-device `40 a1 0000 e416 0002` setup tuple with the only outbound payload, `09 00`. |
| `ConfirmedActivationRequests[5]` | Second confirmed device-to-host `c0 a1 0000 e416 0002` setup tuple with no outbound payload or fabricated response bytes. |

| Activation sequence fixture | Purpose |
| --- | --- |
| `ConfirmedActivationSequenceTiming[0..5]` | Declarative timing metadata: before-delay `0 ms` because no pre-request delay metadata is confirmed; after-delay `12 ms` because the legacy executable path slept after each `SendControlRequest` call returned. |

The fixtures contain no executable legacy code and no unsupported `90 00`
payload. Include the headers only in offline tests and run them with:

```powershell
.\tools\Test-ChatpadProtocolParser.ps1
```

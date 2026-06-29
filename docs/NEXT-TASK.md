# Next Task

## Exact current state

- **Completed branch:** `analysis/connected-device-inventory`.
- **Completed task starting commit:**
  `1159adc49e50d694186da67ce105fa07d81f7987`.
- **Inventory checkpoint:** commit named
  `docs: inventory connected xbox chatpad device stack`; verify its full hash
  with `git rev-parse HEAD` before beginning the next task.
- Authoritative result:
  `docs/CONNECTED-CHATPAD-DEVICE-INVENTORY.md`.
- The controller is USB `045E:028E`, revision `0114`, class `XnaComposite`,
  service `xusb22`, and Microsoft `xusb22.inf` version `10.0.26100.8521` owns
  the node.
- No separately identifiable Chatpad node was observed. One related USB HID
  function and HID game-controller collection are present but are not proven
  Chatpad transports.
- Controller interface registrations include
  `GUID_DEVINTERFACE_USB_DEVICE` and opaque class GUID
  `{EC87F1E3-C13B-4100-B5F7-8B84D54260CB}`. A related HID interface is visible.
- No target device/class filters are currently configured.
- Endpoint layout and the activation transport target remain unresolved.

## Next recommended objective

Create a documentation-only Windows 11 attachment-point and transport
architecture design. Compare a device-specific lower filter at the
USB/XnaComposite controller node with the HID and opaque interface boundaries,
identify the smallest evidence gap for each option, and define hard stop gates
before any runtime implementation.

## Required branch and starting commit

- Create `design/windows11-attachment-architecture` from the exact pushed
  inventory checkpoint named above.
- Require the full `git rev-parse HEAD` value to match
  `origin/analysis/connected-device-inventory` and require a clean tree before
  editing.

## Preconditions

1. Read `AGENTS.md` and all continuity documents.
2. Read `docs/CONNECTED-CHATPAD-DEVICE-INVENTORY.md` and the two final raw
   inventories if they remain available locally.
3. Read `docs/LEGACY-ARCHITECTURE.md`, `docs/WIN11-BLOCKERS.md`, and
   `docs/CHATPAD-INIT-STATUS-EVIDENCE.md`.
4. Verify repository safety, legacy immutability, and prohibited ancestry.

## Safety restrictions

- Documentation and source inspection only.
- Do not open a device/interface handle or query live USB/HID descriptors.
- Do not send USB, HID, IOCTL, URB, activation, status, or keepalive traffic.
- Do not install, bind, replace, package, sign, deploy, load, unload, or modify
  any driver or device.
- Do not modify protocol/runtime/driver source or build projects.
- Keep `legacy/` immutable and keep machine-specific inventory under ignored
  artifacts only.

## Acceptance criteria

- The design compares attachment options against observed device topology and
  explicitly rejects class-wide impact where a device-specific scope exists.
- Every proposed boundary identifies what Windows evidence supports it and
  what remains unproven.
- No interface/endpoint access is assumed from service names or class GUIDs.
- The design defines the smallest separately authorized observation required
  before transport implementation and includes abort criteria.
- Repository safety passes and only documentation/continuity files change.

## Inspect first

1. `docs/CONNECTED-CHATPAD-DEVICE-INVENTORY.md`
2. `tools/Get-ConnectedChatpadInventory.ps1`
3. `docs/LEGACY-ARCHITECTURE.md`
4. `docs/WIN11-BLOCKERS.md`
5. `docs/CHATPAD-INIT-STATUS-EVIDENCE.md`
6. `docs/DECISIONS.md`

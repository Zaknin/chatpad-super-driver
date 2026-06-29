# Project State

*Last updated: 2026-06-29T18:40+04:00*

## Current state

- **Branch:** `analysis/connected-device-inventory`.
- **Starting checkpoint:** `1159adc49e50d694186da67ce105fa07d81f7987`.
- **Expected task commit:** `docs: inventory connected xbox chatpad device stack`.
- **Connected-device inventory:** complete and authoritative at
  `docs/CONNECTED-CHATPAD-DEVICE-INVENTORY.md`.
- **Repeatable collector:** `tools/Get-ConnectedChatpadInventory.ps1`; raw
  machine-specific output remains ignored beneath
  `artifacts/device-inventory/<UTC timestamp>/`.
- **Observed controller:** USB `VID_045E&PID_028E`, revision `0114`, class
  `XnaComposite`, service `xusb22`, bound to Microsoft `xusb22.inf` version
  `10.0.26100.8521` dated 2026-05-16 and signed by Microsoft Windows.
- **Chatpad visibility:** no separately identifiable Chatpad PnP node or
  interface was observed. A related `IG_01` USB HID function and HID
  game-controller collection are present, but inventory does not prove either
  represents the Chatpad.
- **Transport evidence:** cached inventory does not expose USB endpoint layout
  and does not identify the activation transport target.
- **Filter evidence:** no device-level filters on target nodes and no
  class-level filters on `XnaComposite` or `HIDClass`. The controller's physical
  USB/XnaComposite node is only a plausible device-specific future attachment
  point, not a proven transport path.
- **Inventory validation:** PowerShell 7.6.3 and Windows PowerShell
  5.1.26100.8655 both exit 0, stable identity/binding fields match, and each
  baseline/final comparison reports no target state change.
- **Runtime source/build state:** parser, state machine, activation request
  builder, planner, executor, driver source, and all project files are
  unchanged. No build was required; the previous 610/610 protocol and
  Debug/Release compile checkpoints remain the latest build evidence.
- **Unresolved blockers:** endpoint/interface selection, opaque controller
  interface semantics, response bytes, `f0` meaning, mystery setup requests,
  periodic-request semantics, and objective ready conditions remain unresolved.
- **Safety:** repository safety PASS; `legacy/` unchanged; prohibited commit
  absent; artifacts ignored; no device handle, request, HID operation, IOCTL,
  capture, device-state change, driver operation, elevation, network request,
  runtime source edit, project edit, or external-skill modification occurred
  during inventory. The required Git push is the only authorized network action.

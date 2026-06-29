# Project State

*Last updated: 2026-06-29T18:55+04:00*

## Current state

- **Branch:** `analysis/windows11-transport-architecture`.
- **Starting checkpoint:** `6881fc492af50b7f28977d306fad369a2f6a309f`.
- **Expected task commit:**
  `docs: design windows 11 chatpad transport architecture`.
- **Windows 11 architecture:** complete and authoritative at
  `docs/WINDOWS11-CHATPAD-TRANSPORT-ARCHITECTURE.md`.
- **Recommended attachment direction:** physical
  `USB\VID_045E&PID_028E`/`XnaComposite` controller devnode, as a
  device-specific lower filter beneath Microsoft `xusb22`; do not install a
  class-wide XNA or HID filter.
- **Recommendation status:** unresolved for implementation. Legacy evidence
  supports this architecture direction, but current Windows 11 default-control
  access and Chatpad input-transfer visibility are not proven, so no candidate
  is yet preferred.
- **Activation path:** the six portable descriptors, order, executor seam, and
  12 ms evidence metadata are confirmed. Translation to a WDF request,
  default-control-pipe access, response semantics, acknowledgement, and
  readiness are unresolved.
- **Input path:** the portable five-byte parser boundary and legacy own-reader
  design are confirmed evidence. Current endpoint/pipe identity, ownership,
  transfer observation, and coexistence with `xusb22` are unresolved.
- **Lifetime direction:** one parented per-`WDFDEVICE` context and generation;
  stop admission, cancel requests/readers/scheduling, drain callbacks, then
  release pipes/targets/context. No global first-device pointer or work after
  removal.
- **Keyboard direction:** keep output separate from controller transport. The
  installed WDK 10.0.26100.0 exposes VHF as one supported option, but no output
  technology is selected pending isolated lifecycle, signing, and HVCI
  validation.
- **Required stop gates:** exact attachment, `xusb22` preservation, transport
  visibility, endpoint/input evidence, mocked safe lifecycle, recovery plan,
  and later explicit authorization must all pass before any hardware request.
- **Runtime source/build state:** parser, state machine, activation components,
  driver skeleton, solution, and project files are unchanged. No build was
  required; the previous 610/610 and Debug/Release compile checkpoints remain
  the latest build evidence.
- **Safety:** repository safety PASS before editing; `legacy/` unchanged; no
  device/interface handle, live enumeration, USB/HID/IOCTL/URB request,
  activation, read/write, physical reconnect, driver operation, capture,
  elevation, runtime/project edit, or external-skill modification occurred.
  The required Git push is the only authorized network action.

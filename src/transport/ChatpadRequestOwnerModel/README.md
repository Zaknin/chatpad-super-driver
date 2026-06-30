# Chatpad request-owner model

`ChatpadRequestOwnerModel` is a pure C state machine for the future per-device
activation request owner. It contains caller-owned bookkeeping only. It emits
typed effects for lifecycle admission/release, hypothetical send/cancel calls,
terminal ownership, sequence disposition, and reuse eligibility; it executes
none of those effects.

The model reuses `ChatpadTransportOperationToken` as its operation identity.
It does not call the transport adapter or lifecycle core and contains no WDF,
WDM, kernel, USB, HID, PnP, allocation, synchronization, timing, I/O, device,
or hardware dependency. It is not compiled into `ChatpadFilter`.

The primary state enum maps directly to the authoritative design. Draining,
cancellation, terminal processing, and send/cancel call ownership also use
orthogonal flags so race states do not require a combinatorial enum.

Run the dedicated host-side tests with:

```powershell
.\tools\Test-ChatpadRequestOwnerModel.ps1 -Configuration Debug -Platform x64
.\tools\Test-ChatpadRequestOwnerModel.ps1 -Configuration Release -Platform x64
```

All outputs remain beneath ignored `artifacts/`.

# Source Directory

Modern implementation code lives here.

The preserved files under `legacy/source_release_0_0_4a/` are historical
reference material only. No legacy binary is trusted, shipped, installed,
loaded, or executed by this repository.

Current source layers:

- `protocol/ChatpadProtocol`: portable protocol, activation request, sequence,
  and executor logic.
- `transport/ChatpadTransport`: portable generation-bound transport adapter
  contract.
- `transport/ChatpadRequestOwnerModel`: portable request-owner state model for
  one future activation request slot. It emits effects only and contains no
  WDF, WDM, USB, HID, SetupAPI, installation, driver-load, or hardware
  behavior.
- `transport/ChatpadControlSetup`: portable control-setup translation.
- `transport/ChatpadWdfControlSetup`: compile-only WDK value formatter.
- `driver/ChatpadKmdfRequestOwnerContext`: compile-only KMDF context and
  future owner layout declarations for the activation request owner. It is not
  linked into `ChatpadFilter` and creates no WDF object.
- `driver/ChatpadFilter`: non-installable KMDF driver scaffold with dormant
  activation preparation compiled in and uncalled by runtime callbacks.

# Legacy feature inventory

This inventory records the read-only references used for TASK 8K. The active
Windows 11 driver does not copy either legacy architecture.

## References and licensing

- `GAFBlizzard/chatpad-super-driver` at
  `cb8c52533f5b4383e9127098c35b07b038518161`. Its archived
  `source_release_0_0_4a` is MIT-licensed (GAFBlizzard, 2010-2015). Standard
  HID mapping behavior is re-expressed with attribution; the old parser,
  installers, filter, and virtual HID drivers are not reused.
- `Kytech/xbox360wirelesschatpad` at
  `934ae73f569efe7706b84edd16473252ea4d800d`. Its `license.md` contains a
  warranty disclaimer but no affirmative redistribution grant. No code,
  SendKeys strings, or mapping tables are copied from it.

## Wired project

The main sources are `chatpad_control/chatpad_config.txt` (defaults and
human-readable mappings), `chatpad_control/chatpad_config.cpp` and `.h`
(parser, tokens, settings), and `chatpad_control/chatpad_control_code.cpp`
(modifier latches, People actions, controller mouse mode, and USB runtime).
The text format uses comments plus `left = right` mappings and accepts later
duplicates. It exposes base, Shift, Green, Orange, People, controller,
deadzone, and mouse-sensitivity concepts. Example UK and German configurations
are in `Downloads/uk_config.txt` and `Downloads/chatpad_config_ger_ver2.txt`.

The deterministic US-HID Green subset covers the punctuation keys recorded in
the mapping table below. The Orange subset covers `$ = \ " ; _ +` and
Orange+Shift Caps Lock. Several printed accented/Unicode legends are absent or
replaced by author convenience mappings; those substitutions are not carried
into the modern defaults. People can toggle Windows mode, latch a modifier, or
emit Left GUI. Windows mode remaps/suppresses normal controller behavior and
drives a separate virtual mouse.

Dependencies are old WDK/KMDF components plus separate virtual keyboard and
mouse drivers. The project does not use libusb, vJoy, or SendKeys.

## Wireless project

`src/Xbox 360 Wireless Chatpad/Controller.cs` contains QWERTY, QWERTZ, and
AZERTY tables, Green/Orange SendKeys strings, People/Tab behavior, and mouse
mode. `Properties/Settings.settings` stores per-controller keyboard type,
deadzones, trigger, and mouse-mode settings; `Window_Main.cs` exposes the UI.
It uses .NET Framework/WinForms, LibUsbDotNet, InputManager, vJoy, and
SendKeys. Mouse mode changes the controller path. These implementation details
are incompatible with the modern KMDF/VHF boundary and are not reused.

## TASK 8K classification

- Re-express now: MIT wired standard-HID Green/Orange behavior, built-in base
  mapping, profile/layout labels, and a Disabled People action.
- Implement cleanly: fixed-size versioned kernel contract, strict JSON,
  atomic application, held-key layer state, and a native CLI.
- Defer: layout-dependent Unicode legends, People actions beyond Disabled,
  modifier LEDs/latches, controller remapping, and mouse mode. A future mouse
  design should observe XInput in user mode and must not suppress Xbox input.

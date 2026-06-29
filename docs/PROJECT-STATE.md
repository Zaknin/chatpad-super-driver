# Project State

*Last updated: 2026-06-29T16:01+04:00*

## Current state

- **Branch:** `feature/kernel-safe-protocol-interface`, tracking
  `origin/feature/kernel-safe-protocol-interface`.
- **Checkpoint:** implementation and continuity updates are committed together
  as the task commit named `build: add kernel-safe protocol interface check`,
  based on `c18b40b2c66ec9c529567ae2df3d01e3a233b6b8`.
- **Shared protocol boundary:** `ChatpadProtocolTypes.h` provides portable
  fixed-width byte and size types, raw packet output, and parse results;
  `ChatpadKeyboardParser.h` provides the C/C++ callable parser declaration.
- **Parser behavior:** unchanged Phase 1 raw five-byte parser; unresolved fields
  remain raw and policy rejection remains distinct from protocol evidence.
- **User-mode regression:** direct 85/85; integrated Debug 85/85; integrated
  Release 85/85, all exit 0.
- **WDK compatibility:** isolated Debug and Release x64 static-library builds
  exit 0 under Windows PowerShell 5.1. No `.sys` or signing/package output.
  - Debug: `804A41BFF6CC57F980A7E35950091E0599B821C370EAB152EBA0ECE452079FA5`
  - Release: `848AE61D1B9F27F49E9F0AC51E94DF804AB0D5D059977A1DB7938AEC8B9DEE33`
- **Driver regression:** Debug and Release exit 0 and remain NotSigned with no
  SignTool execution.
- **Driver isolation:** `ChatpadFilter.vcxproj` contains only `driver.c` and
  `device.c`, has no project reference, and its linker command contains only
  WDK/kernel libraries plus those two objects. Neither protocol library is
  linked. The solution has no dependency section.
- **Toolchain:** Visual Studio 2022 17.14.35; MSVC v143 14.44.35207; SDK and
  WDK 10.0.26100.0; x64 Spectre libraries 14.44.35207; latest installed KMDF
  1.35. `ChatpadFilter` retains the WDK default KMDF target/link version 1.15.
- **Unresolved blockers:** None.
- **Safety:** repository safety PASS; `legacy/` unchanged; prohibited commit
  `6502452` is not an ancestor; generated files remain ignored under
  `artifacts/`; no runtime driver behavior was added.

## Runtime boundary

The kernel compatibility project is a compile-time proof only. It has no
entry point, device, callback, transport, USB, HID, IOCTL, PnP, power,
registry, service, install, signing, package, deployment, or hardware path.
Nothing was installed, loaded, executed as a driver, signed, packaged,
deployed, or tested against hardware.

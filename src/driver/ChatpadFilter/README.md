# ChatpadFilter Build Skeleton

`ChatpadFilter` is a compile-only, nonfunctional x64 KMDF skeleton for the Windows 11 port. It creates only a basic filter `WDFDEVICE` and provides no chatpad, USB, HID, keyboard, mouse, IOCTL, control-device, device-interface, or user-visible behavior.

The project sets WDK `SignMode` to `Off` for Debug x64 and Release x64. Builds are intentionally unsigned: no certificate is created and no SignTool operation runs. All outputs and intermediates are routed beneath repository-root `artifacts/` by `tools/Build-Driver.ps1`.

The project has no INF, CAT, package, installer, or deployment configuration, so no installable driver package exists. The generated `.sys` must not be installed or loaded on any Windows system.

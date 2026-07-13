# ChatpadControl

`ChatpadControl.exe` is a native x64 command-line companion for driver version
1.0.14.0. The driver always starts with complete built-in QWERTY defaults, so
the utility is optional.

Profiles live under `%LOCALAPPDATA%\ChatpadSuperDriver\profiles\` and use
strict JSON schema version 1. Each profile contains a name, a QWERTY/QWERTZ/
AZERTY layout label, Disabled People action, and complete Base, Green, and
Orange maps. Actions are limited to `disabled` or a bounded HID keyboard usage
plus modifier byte. Missing keys, duplicate properties, unknown keys/actions,
unsupported versions, nonzero reserved fields, and files over 64 KiB are
rejected. Driver application is atomic; a rejection preserves the active map.

Commands:

```text
ChatpadControl.exe status
ChatpadControl.exe config show
ChatpadControl.exe config reset
ChatpadControl.exe profile list
ChatpadControl.exe profile apply <name>
ChatpadControl.exe profile import <path>
ChatpadControl.exe profile export <name> <path>
ChatpadControl.exe diagnostics
```

`config show` prints a complete profile suitable for redirection and editing.
`profile import` validates and atomically normalizes a file into profile
storage. `profile apply` validates again before sending the fixed-size profile
to the driver. `config reset` restores compiled defaults. Import, export, and
list work without a connected device; device commands return exit code 2 when
the interface is absent.

Exit codes are 0 success, 1 usage, 2 device unavailable, 3 invalid profile,
4 local I/O error, and 5 driver rejection. The utility never installs a
driver, restarts a device, changes trust, BCD, Secure Boot, HVCI, VBS, USB
power settings, or launches arbitrary profile commands.

The driver exposes only five METHOD_BUFFERED IOCTLs with fixed input/output
sizes and read/write access bits. Unknown device-control requests are forwarded
unchanged to xusb22. The configuration surface cannot select USB targets,
restart the stack, pass pointers, allocate based on user lengths, or affect the
Xbox forwarding path.

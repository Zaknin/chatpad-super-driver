# Source Inventory

This repository now preserves a source-only snapshot of the historical `source_release_0_0_4a` package under `legacy/source_release_0_0_4a/`.

No legacy `.sys`, `.exe`, `.dll`, `.cat`, `.cab`, `.msi`, `.pdb`, `.lib`, or `WdfCoInstaller*` file is part of the snapshot.

## Snapshot Scope

- Source root: `legacy/source_release_0_0_4a/`
- File count: 68 files
- Text/source/config extensions copied: `.c`, `.cpp`, `.h`, `.inf`, `.manifest`, `.rc`, `.TXT`
- Extensionless build metadata copied: `sources` and `makefile`
- License copied: `legacy/source_release_0_0_4a/LICENSE.TXT`

The original package license notes that the WDF coinstaller files came from the WinDDK redistributable and that the rest of the package is MIT licensed at `legacy/source_release_0_0_4a/LICENSE.TXT:1-19`. The coinstaller binaries themselves are not copied.

## Copied File Classes

| Class | Count | Evidence |
| --- | ---: | --- |
| Extensionless `sources` and `makefile` files | 14 | Build targets are declared in `legacy/source_release_0_0_4a/filter/sources:1-18`, `legacy/source_release_0_0_4a/chatpad_keyboard_kmdf/sources:1-22`, `legacy/source_release_0_0_4a/chatpad_mouse_kmdf/sources:1-22`, `legacy/source_release_0_0_4a/hid_keyboard_interface/sources:1-14`, `legacy/source_release_0_0_4a/hid_mouse_interface/sources:1-14`, `legacy/source_release_0_0_4a/chatpad_control/sources:1-22`, and `legacy/source_release_0_0_4a/installer/sources:1-22`. |
| C source files | 2 | HID minidrivers register with hidclass in `legacy/source_release_0_0_4a/hid_keyboard_interface/chatpad_keyboard.c:50-92` and `legacy/source_release_0_0_4a/hid_mouse_interface/chatpad_mouse.c:50-92`. |
| C++ source files | 8 | The filter driver starts in `legacy/source_release_0_0_4a/filter/chatpad_filter.cpp:247-330`; KMDF virtual keyboard and mouse IOCTL handlers are in `legacy/source_release_0_0_4a/chatpad_keyboard_kmdf/chatpad_keyboard_kmdf.cpp:1428-1558` and `legacy/source_release_0_0_4a/chatpad_mouse_kmdf/chatpad_mouse_kmdf.cpp:1436-1557`. |
| Headers | 10 | Filter IOCTL definitions are in `legacy/source_release_0_0_4a/include/chatpad_filter_ioctl.h:21-90`; control-device raw context storage is declared in `legacy/source_release_0_0_4a/filter/chatpad_filter.h:183-193`, `legacy/source_release_0_0_4a/chatpad_keyboard_kmdf/chatpad_keyboard_kmdf.h:79-90`, and `legacy/source_release_0_0_4a/chatpad_mouse_kmdf/chatpad_mouse_kmdf.h:79-90`. |
| INF files | 18 | Installer data INFs are retained for Windows XP, Vista, and 7 package history, for example `legacy/source_release_0_0_4a/installer/install/win7/data/chatpad_filter.inf`. |
| Manifests | 2 | User-mode program manifests are retained as text metadata, including `legacy/source_release_0_0_4a/chatpad_control/chatpad_control.exe.manifest` and `legacy/source_release_0_0_4a/installer/chatpad_installer.exe.manifest`. |
| Resource script | 1 | `legacy/source_release_0_0_4a/installer/chatpad_installer.rc` is retained as installer source. |
| Text documentation and configuration | 13 | Package notes include unresolved driver-verifier and pool-tracking concerns at `legacy/source_release_0_0_4a/notes.txt:4-10`; user configuration strings are documented at `legacy/source_release_0_0_4a/installer/install/win7/README.TXT:13-25`. |

## Excluded Inputs

The input package contained 61 forbidden binary payloads: 40 `.sys`, 14 `.exe`, and 7 `.dll` files. It also contained 8 `testbuild.bat` scripts. Those files were not copied into `legacy/source_release_0_0_4a/`.

No `.cat`, `.cab`, `.msi`, `.pdb`, or `.lib` files were present in the inspected input package.

## Baseline Boundary

This baseline is historical source preservation and audit documentation only. It does not claim that the legacy driver builds, loads, signs, installs, or works on any supported Windows version.

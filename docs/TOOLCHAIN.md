# Driver Build Toolchain

## Requirements

The compile-only x64 KMDF project requires:

- x64 Windows 10 or Windows 11;
- Visual Studio 2022 or Visual Studio 2022 Build Tools with MSBuild;
- MSVC v143 x64/x86 build tools;
- MSVC v143 Spectre-mitigated libraries for x64;
- a Windows 10 or Windows 11 SDK;
- a matching Windows Driver Kit version;
- WDK integration for Visual Studio 2022, including the `WindowsKernelModeDriver10.0` platform toolset;
- KMDF headers, x64 libraries, and WDK MSBuild targets;
- PowerShell 5.1 or later and Git.

WDK project templates are detected and reported when available, but they are not required for command-line builds of the checked-in project.

Run read-only detection from the repository root:

```powershell
.\tools\Get-DriverBuildEnvironment.ps1 -OutputPath .\artifacts\environment\driver-build-environment.txt
```

The generated report may contain local installation paths and is therefore stored under the ignored `artifacts/` directory.

## Current Machine Status

The validation machine is **ready** for KMDF compilation. Detection found Visual Studio 2022 version 17.14.35, MSVC v143 version 14.44.35207, Windows SDK 10.0.26100.0, and matching WDK 10.0.26100.0. KMDF headers and x64 libraries through version 1.35 are installed, together with WDK MSBuild targets and Visual Studio integration. The x64 Spectre-mitigated libraries are installed under the MSVC 14.44.35207 toolset.

The detector reports the installed KMDF range; the current `ChatpadFilter`
project continues to use the WDK default target and links KMDF 1.15. The
kernel protocol compatibility project contains no WDF calls, so its result is
independent of a KMDF runtime version. This distinction corrects the prior
continuity shorthand that reported only KMDF 1.15 as if it were the latest
installed toolchain version.

With this toolchain, the repository wrapper completes Debug x64 and Release x64 builds with MSBuild exit code 0. The project explicitly uses WDK `SignMode=Off`; the resulting `.sys` files are intentionally unsigned and no signing task runs.

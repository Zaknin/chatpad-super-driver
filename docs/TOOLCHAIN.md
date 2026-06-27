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

The validation machine is **not ready** for KMDF compilation. Detection found Visual Studio 2022 version 17.14.34, MSVC v143 version 14.44.35207, and Windows SDK 10.0.26100.0. It did not find a WDK, KMDF headers or libraries, WDK MSBuild targets, WDK Visual Studio integration, or v143 x64 Spectre-mitigated libraries.

No SDK/WDK version match can be established until the matching WDK and its Visual Studio integration are installed. The detection script returns a nonzero exit code in this state.

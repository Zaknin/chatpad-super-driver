# Building the Compile-Only Skeleton

This build creates only an ignored `.sys` compiler output. It does not install, sign, package, deploy, start, or load a driver.

## Prerequisites

Install the Visual Studio 2022, MSVC v143, Spectre library, Windows SDK, WDK, KMDF, and WDK integration components listed in [TOOLCHAIN.md](TOOLCHAIN.md). The SDK and WDK versions must match.

Check the environment without changing system configuration:

```powershell
.\tools\Get-DriverBuildEnvironment.ps1 -OutputPath .\artifacts\environment\driver-build-environment.txt
```

The detector exits nonzero and identifies missing components when the toolchain is incomplete.

## Build Commands

Debug x64 clean build:

```powershell
.\tools\Build-Driver.ps1 -Configuration Debug -Platform x64
```

Release x64 clean build:

```powershell
.\tools\Build-Driver.ps1 -Configuration Release -Platform x64
```

Compiled files are written below `artifacts/bin/x64/`, intermediate files below `artifacts/obj/x64/`, environment reports below `artifacts/environment/`, and logs below `artifacts/logs/`. All of these paths are ignored by Git.

Building does not install the driver. There is no INF, catalog, signing configuration, or usable driver package in this repository.

## Troubleshooting

- **Visual Studio 2022 not detected:** install Visual Studio 2022 or Build Tools 2022 with MSBuild and the MSVC v143 x64/x86 tools.
- **MSBuild not detected:** add the MSBuild component through Visual Studio Installer.
- **SDK/WDK mismatch:** install the WDK release matching an installed Windows SDK version.
- **WDK not detected:** install the Windows Driver Kit; the SDK alone does not provide kernel headers and libraries.
- **Spectre libraries missing:** add the MSVC v143 Spectre-mitigated libraries for x64/x86 through Visual Studio Installer.
- **WDK integration missing:** install or repair the WDK Visual Studio extension so `WindowsKernelModeDriver10.0` is available to VS 2022 MSBuild.
- **KMDF files or targets missing:** repair the WDK installation and rerun environment detection before attempting another build.

Never load this skeleton on the main Windows installation. It is nonfunctional, has no installable package, and has not passed runtime validation.

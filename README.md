#### Original Project Information

>This project aims to provide drivers and utilities to provide unofficial support for the Microsoft XBox 360 controller chatpad under various Windows operating systems.  The chatpad is a small keyboard that attaches to a controller, but Microsoft has not released Windows drivers.  Thus, this project exists to provide a solution.
>
>Currently, only wired controllers are supported.  Future plans include investigating support for wireless XBox 360 controllers.

#### Windows 11 Port

Windows 11 port work is isolated on the `win11-port`, `analysis/source-audit`, and `build/modern-wdk` branches. The modern project is currently a compile-only, nonfunctional skeleton and must not be installed.

- [Legacy architecture](docs/LEGACY-ARCHITECTURE.md)
- [Windows 11 blockers](docs/WIN11-BLOCKERS.md)
- [Porting plan](docs/PORTING-PLAN.md)
- [Building](docs/BUILDING.md)
- [Toolchain requirements](docs/TOOLCHAIN.md)

#### ThisCodedBox Goals and Additions

Configured driver package to function on **Windows 10 x64**
- Small changes to .inf files to allow catalog files to be built
- Instructions for driver signing

# CAUTION

This will tell you to create your own signed drivers and install them - if you don't understand why this is sketchy, look into it before attempting to follow these instructions.

#### Quick and Dirty How-To

Basic instructions [per each release](https://github.com/thiscodedbox/chatpad-super-driver/releases).

For more detail, review the legacy docs [here](https://github.com/thiscodedbox/chatpad-super-driver/wiki/LEGACY-Getting-Started) and [here](https://github.com/thiscodedbox/chatpad-super-driver/wiki/LEGACY-ReadMe).

#### Credit

Thank you to @GAFBlizzard for the original project.

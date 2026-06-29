# ChatpadFilter extension INF prototype

## OFFLINE PROTOTYPE — DO NOT INSTALL

`ChatpadFilterExtension.inf` is source for static WDK `InfVerif` analysis. It
is isolated from the driver project, solution build, package output, and every
installation path.

The prototype models one AMD64 Windows 11 extension INF:

- class `Extension` with stable `ExtensionId`
  `{69E7CCD7-7011-4059-95D4-618974E126DD}`;
- minimum decorated target `NTamd64.10.0...22000`;
- exact hardware ID `USB\VID_045E&PID_028E`;
- non-associated demand-start kernel service `ChatpadFilter`;
- `ChatpadFilter.sys` copied conceptually to Driver Store isolation DIRID 13;
- KMDF `1.15`;
- declarative `AddFilter` registration with `FilterPosition=Lower`.
- future catalog identity `ChatpadFilterExtension.cat`, declared because
  `InfVerif` requires `CatalogFile`; no catalog file is created.

The extension association and lower-filter role are statically represented.
There is no named filter level because the inspected Microsoft base package
does not expose a project-owned ordering level. Exact effective ordering,
attachment beneath `xusb22`, Microsoft function-driver preservation, service
creation, binary availability, signature acceptance, recovery, and runtime
behavior remain unproven until separately authorized installation work.

No catalog or package is generated. The declared catalog filename is package
metadata only. The INF is intentionally valid source, not an install blocker.
Safety comes from repository isolation, the validation wrapper, repository
guards, and explicit authorization gates.

Validate without elevation:

```powershell
.\tools\Test-ChatpadFilterInfPrototype.ps1
```

The wrapper writes only ignored logs beneath `artifacts/inf-validation/`. It
does not invoke installation, signing, catalog, device, or network tooling.

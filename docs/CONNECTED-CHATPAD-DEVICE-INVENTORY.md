# Connected Chatpad Device Inventory

## 1. Scope and safety boundary

This document records a strictly read-only Windows inventory of one connected
original Xbox 360 controller with an attached original Chatpad. Collection used
PnP properties, CIM driver metadata, and cached registry metadata only. No
device or interface handle was opened; no request, report, IOCTL, URB, trace,
driver operation, or device-state change was performed.

## 2. Inventory date and operating environment

- Date: 2026-06-29.
- Operating system: Microsoft Windows 11 Pro, 64-bit, version `10.0.26200`,
  build `26200`.
- PowerShell validation: PowerShell `7.6.3` and Windows PowerShell
  `5.1.26100.8655`.
- Raw outputs: ignored directories matching
  `artifacts/device-inventory/<UTC timestamp>/`.

## 3. Discovery method

The inventory correlated present `Get-PnpDevice` nodes with
`Win32_PnPEntity`, then selected candidates from multiple signals: Xbox/XUSB
names, `VID_045E&PID_028E`, XUSB compatible IDs, `xusb22`, PnP class,
manufacturer, parent/child relationships, and container identity. Detailed
properties came from `Get-PnpDeviceProperty`; signed-driver and service
metadata came from `Win32_PnPSignedDriver` and `Win32_SystemDriver`. Interface
registrations and filters came from read-only registry metadata.

A minimal target snapshot was taken before detailed collection and repeated
afterward. Status, problem code, service, INF, and present state were unchanged
in both PowerShell runs.

## 4. Identified Xbox controller device node

Directly observed:

- Friendly name: `Xbox 360 Controller for Windows`.
- Redacted instance pattern: `USB\VID_045E&PID_028E\<device instance>`.
- VID/PID: `045E:028E`.
- Revision: `0114`.
- Enumerator: `USB`.
- PnP status: `OK`; present: true; Configuration Manager problem code: `0`.
- Bus-reported description: `Controller`.

The exact instance ID is retained in raw artifacts because its final component
may be device-specific.

## 5. Chatpad visibility conclusion

No separately Chatpad-labeled PnP node, child function, HID collection, or
interface registration was observed. Windows exposes the controller plus one
`IG_01` HID branch. Cached inventory does not identify that HID branch as the
Chatpad, so it must not be treated as a proven Chatpad transport.

Conclusion: the attached Chatpad is **not separately identifiable through the
selected cached Windows inventory sources**. This does not prove that the
physical Chatpad lacks a distinct endpoint behind the controller.

## 6. Hardware and compatible IDs

Complete controller hardware-ID set:

- `USB\VID_045E&PID_028E&REV_0114`
- `USB\VID_045E&PID_028E`

Complete controller compatible-ID set:

- `USB\MS_COMP_XUSB10`
- `USB\COMPAT_VID_045E&Class_FF&SubClass_5D&Prot_01`
- `USB\COMPAT_VID_045E&Class_FF&SubClass_5D`
- `USB\COMPAT_VID_045E&Class_FF`
- `USB\Class_FF&SubClass_5D&Prot_01`
- `USB\Class_FF&SubClass_5D`
- `USB\Class_FF`

## 7. PnP class and device class

- Controller class: `XnaComposite`.
- Controller class GUID: `{D61CA365-5AF4-4486-998B-9DB4734C6CA3}`.
- Related USB HID function and HID collection class: `HIDClass`.
- HID class GUID: `{745A17A0-74D3-11D0-B6FE-00A0C90F57DA}`.

## 8. Driver and service binding

Controller binding, directly observed:

- Service: `xusb22`.
- INF: `xusb22.inf`.
- Provider: Microsoft.
- Version: `10.0.26100.8521`.
- Date: 2026-05-16.
- Signer: Microsoft Windows; signed: true.
- Matching device ID: `USB\VID_045E&PID_028E`.
- Driver file: `xusb22.sys`.

The USB HID child uses service `HidUsb`, `input.inf`, provider Microsoft,
version `10.0.26100.8521`, date 2006-06-21, signer Microsoft Windows, and
`hidusb.sys`. The terminal HID game-controller collection also binds through
`input.inf`; no separate service is reported on that collection node.

## 9. Parent, child, and container topology

Directly observed topology, with machine-specific instance suffixes redacted:

```text
USB hub VID_1A40 PID_0201
`-- USB\VID_045E&PID_028E\<device instance>                 controller
    `-- USB\VID_045E&PID_028E&IG_01\<instance>              HID USB function
        `-- HID\VID_045E&PID_028E&IG_01\<collection>        game-controller collection
```

The controller, HID USB function, and HID collection share one container. The
exact container GUID, parent/sibling instance IDs, physical USB-port path, and
full root-hub/PCI ancestor chain remain only in raw artifacts. Two unrelated
devices share the controller's immediate external hub parent; they are not
controller functions.

## 10. Related HID, USB, and XUSB nodes

Related nodes are visible:

- the `XnaComposite` controller node owned by `xusb22`;
- one USB `IG_01` HID function owned by `HidUsb`;
- one HID game-controller collection under that USB function.

The shared VID/PID, parent chain, and container prove that the HID branch is
related to this controller. They do not prove that it represents the Chatpad.

## 11. Exposed interface classes

Cached registrations for present target nodes show:

- controller: `GUID_DEVINTERFACE_USB_DEVICE`,
  `{A5DCBF10-6530-11D2-901F-00C04FB951ED}`;
- controller: opaque interface class
  `{EC87F1E3-C13B-4100-B5F7-8B84D54260CB}`;
- HID collection: `GUID_DEVINTERFACE_HID`,
  `{4D1E55B2-F16F-11CF-88CB-001111000030}`.

Exact symbolic paths are retained only in raw artifacts and were never opened.
The opaque controller interface registration is observed metadata; its
semantics and supported operations are unresolved.

## 12. Cached descriptor-like properties

Cached PnP metadata supplies VID/PID, revision, USB-compatible class/subclass/
protocol values, bus-reported description, address, bus number, location,
capabilities, removal policy, stack names, and ancestor relations. Exact
address and location values are machine/port-specific and remain in artifacts.

These are not live USB descriptors. No configuration, interface, endpoint, or
string descriptor was queried from the device.

## 13. Filter bindings

No device-level `UpperFilters` or `LowerFilters` were observed on the three
target nodes. No class-level `UpperFilters` or `LowerFilters` were observed on
the `XnaComposite` or `HIDClass` class keys.

## 14. Stable facts suitable for driver design

- The physical controller enumerates as USB `045E:028E`, revision `0114`.
- Microsoft `xusb22` owns the `XnaComposite` controller node.
- The controller has a related HID branch, but no inventory property identifies
  it as the Chatpad.
- The controller node exposes USB-device and opaque controller interface-class
  registrations; the HID collection exposes a HID interface registration.
- The current target and target classes have no configured filters.
- A device-specific filter at the physical USB/XnaComposite controller node is
  the narrowest plausible future attachment point suggested by inventory.

The last item is an architecture inference, not proof that a filter can safely
access a specific endpoint or reproduce the legacy transport.

## 15. Machine-specific facts retained only in artifacts

Raw artifacts retain exact instance IDs, container GUID, symbolic interface
paths, location information and paths, ancestor/sibling IDs, full driver paths,
and repository/output paths. None is committed here. The script intentionally
does not collect or emit a computer name or user name.

## 16. What cannot be determined without opening the device

Cached inventory does not establish:

- USB configuration, interface, alternate-setting, or endpoint descriptors;
- endpoint addresses, transfer types, maximum packet sizes, or polling periods;
- whether the Chatpad uses the related HID branch, another interface, or a
  controller-internal/proprietary path;
- which interface or endpoint carried legacy reads and control transfers;
- whether the opaque interface permits safe transport access;
- response bytes, readiness, activation success, or keepalive semantics.

Therefore the USB endpoint layout and activation transport target cannot be
identified from this inventory alone.

## 17. Implications for Windows 11 driver architecture

The observed `xusb22` stack makes the physical `XnaComposite` USB node a more
defensible design target than the generic HID collection. If a later driver is
needed, a device-specific lower-filter design restricted to hardware ID
`USB\VID_045E&PID_028E` is safer than a class-wide XNA or HID filter because a
class-wide filter would affect unrelated devices.

This inventory does not authorize or justify implementation yet. A service
binding or interface class does not prove an endpoint or control-request path.

## 18. Unresolved questions

- What operation class is associated with
  `{EC87F1E3-C13B-4100-B5F7-8B84D54260CB}`?
- Which USB interface and endpoint expose Chatpad input?
- Is the related `IG_01` HID branch controller input only, or does it contain
  any Chatpad-visible collection?
- Can a supported Windows filter position observe the required traffic without
  replacing `xusb22` or affecting controller behavior?
- What separately authorized observation can prove the transport target while
  preserving device state?

## 19. Recommended next bounded task

Produce a documentation-only Windows 11 attachment-point and transport
architecture design. Compare a device-specific lower filter at the
USB/XnaComposite node with the visible HID and opaque interface boundaries,
define the evidence still required before any real transport implementation,
and keep all runtime, installation, descriptor-query, request-sending, and
device-handle work out of scope.

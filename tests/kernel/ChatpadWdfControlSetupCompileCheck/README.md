# Chatpad WDF Control Setup Compile Check

This isolated WDK static-library project compiles a consumer of the exact
`WDF_USB_CONTROL_SETUP_PACKET` formatter API. Its compile-only function obtains
all six descriptors through `ChatpadBuildActivationRequest`, passes each
through `ChatpadTranslateActivationRequest`, and passes each pure translation
to `ChatpadFormatWdfControlSetupPacket`.

Compile-time checks verify that the installed WDF setup union and its public
`Generic.Bytes` member both expose the required eight-byte setup
representation. No assertion is made about undocumented packing.

The project has no entry point and creates no device, target, request, memory,
queue, interface, timer, work item, callback, payload buffer, response buffer,
transfer, driver, package, or runtime integration. Both this project and its
formatter dependency produce only static libraries beneath `artifacts/`.

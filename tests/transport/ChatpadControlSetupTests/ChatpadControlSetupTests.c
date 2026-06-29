#include <stdio.h>
#include <string.h>

#include "ChatpadControlSetup.h"
#include "ChatpadControlSetupFixtures.h"

static int TotalAssertions;
static int FailedAssertions;

static void AssertTrue(int condition, const char *name)
{
    ++TotalAssertions;
    if (condition) {
        printf("PASS: %s\n", name);
    }
    else {
        ++FailedAssertions;
        printf("FAIL: %s\n", name);
    }
}

static int TranslationIsZero(const ChatpadControlSetupTranslation *translation)
{
    ChatpadControlSetupTranslation zero;
    memset(&zero, 0, sizeof(zero));
    return memcmp(translation, &zero, sizeof(zero)) == 0;
}

static ChatpadActivationRequest BuildRequest(size_t index)
{
    ChatpadActivationRequest request;
    ChatpadActivationBuildResult result = ChatpadBuildActivationRequest(index, &request);
    AssertTrue(result == CHATPAD_ACTIVATION_BUILD_OK, "fixture request builds through authoritative builder");
    return request;
}

static void TestConfirmedTranslations(void)
{
    size_t index;
    int unsupportedPayloadCount = 0;

    AssertTrue(ChatpadGetActivationRequestCount() == 6u, "confirmed request count remains six");
    for (index = 0; index < ChatpadGetActivationRequestCount(); ++index) {
        ChatpadActivationRequest request = BuildRequest(index);
        ChatpadControlSetupTranslation output;
        ChatpadControlSetupResult result = ChatpadTranslateActivationRequest(&request, &output);
        uint16_t expectedOutbound = index == 4u ? 2u : 0u;
        uint16_t expectedInbound = (index == 3u || index == 5u) ? 2u : 0u;
        ChatpadControlDataDirection expectedDirection = CHATPAD_CONTROL_DATA_DIRECTION_NONE;

        if (index == 4u) {
            expectedDirection = CHATPAD_CONTROL_DATA_DIRECTION_HOST_TO_DEVICE;
        }
        else if (index == 3u || index == 5u) {
            expectedDirection = CHATPAD_CONTROL_DATA_DIRECTION_DEVICE_TO_HOST;
        }

        AssertTrue(result == CHATPAD_CONTROL_SETUP_OK, "confirmed request translates");
        AssertTrue(memcmp(output.SetupPacketBytes, ChatpadExpectedSetupPackets[index], 8u) == 0, "exact confirmed setup bytes");
        AssertTrue(output.DataDirection == expectedDirection, "exact confirmed data direction");
        AssertTrue(output.OutboundPayloadLength == expectedOutbound, "exact confirmed outbound length");
        AssertTrue(output.ExpectedInboundLength == expectedInbound, "exact confirmed inbound length");
        AssertTrue(output.OutboundPayload[0] == (index == 4u ? 0x09u : 0x00u), "confirmed payload byte zero");
        AssertTrue(output.OutboundPayload[1] == 0x00u, "confirmed payload byte one");
        AssertTrue(!(output.OutboundPayloadLength == 2u && output.OutboundPayload[0] == 0x90u && output.OutboundPayload[1] == 0x00u), "unsupported 90 00 absent from confirmed output");
        AssertTrue(request.RawBmRequestType == ChatpadExpectedSetupPackets[index][0], "builder order matches setup fixture order");
        AssertTrue((index == 3u || index == 5u) ? output.OutboundPayloadLength == 0u : 1, "device-to-host output has no outbound data");
        AssertTrue((index == 3u || index == 5u) ? output.OutboundPayload[0] == 0u && output.OutboundPayload[1] == 0u : 1, "device-to-host output fabricates no response bytes");
        AssertTrue(output.OutboundPayload[output.OutboundPayloadLength < 2u ? output.OutboundPayloadLength : 1u] == 0u, "unused outbound payload byte is zero");

        if (output.OutboundPayloadLength == 2u && output.OutboundPayload[0] == 0x90u && output.OutboundPayload[1] == 0x00u) {
            ++unsupportedPayloadCount;
        }
    }
    AssertTrue(unsupportedPayloadCount == 0, "no confirmed translation contains unsupported 90 00 payload");
}

static void TestEncodingAndDeterminism(void)
{
    ChatpadActivationRequest request = BuildRequest(4u);
    ChatpadControlSetupTranslation first;
    ChatpadControlSetupTranslation second;

    request.RawValue = 0x1234u;
    request.RawIndex = 0x5678u;
    request.RawLength = 2u;
    AssertTrue(ChatpadTranslateActivationRequest(&request, &first) == CHATPAD_CONTROL_SETUP_OK, "synthetic encoding translates");
    AssertTrue(first.SetupPacketBytes[2] == 0x34u && first.SetupPacketBytes[3] == 0x12u, "wValue is little endian");
    AssertTrue(first.SetupPacketBytes[4] == 0x78u && first.SetupPacketBytes[5] == 0x56u, "wIndex is little endian");
    AssertTrue(first.SetupPacketBytes[6] == 0x02u && first.SetupPacketBytes[7] == 0x00u, "wLength is little endian");
    AssertTrue(ChatpadTranslateActivationRequest(&request, &second) == CHATPAD_CONTROL_SETUP_OK, "repeated synthetic encoding translates");
    AssertTrue(memcmp(&first, &second, sizeof(first)) == 0, "full translation is deterministic");
    AssertTrue(CHATPAD_CONTROL_SETUP_PACKET_LENGTH == 8u, "setup representation is exactly eight explicit bytes");

    first.SetupPacketBytes[0] = 0u;
    first.OutboundPayload[0] = 0u;
    AssertTrue(ChatpadTranslateActivationRequest(&request, &second) == CHATPAD_CONTROL_SETUP_OK, "translation after output mutation succeeds");
    AssertTrue(second.SetupPacketBytes[0] == request.RawBmRequestType, "output mutation does not affect later setup");
    AssertTrue(second.OutboundPayload[0] == request.OutboundPayload[0], "output mutation does not affect later payload");

    request.OutboundPayload[0] = 0x90u;
    request.OutboundPayload[1] = 0x00u;
    AssertTrue(ChatpadTranslateActivationRequest(&request, &second) == CHATPAD_CONTROL_SETUP_OK, "synthetic 90 00 payload is structurally accepted");
    AssertTrue(second.OutboundPayload[0] == 0x90u && second.OutboundPayload[1] == 0x00u, "translator applies no semantic payload policy");
}

static void AssertFailureClears(
    ChatpadActivationRequest *request,
    ChatpadControlSetupResult expected,
    const char *name)
{
    ChatpadControlSetupTranslation output;
    memset(&output, 0xA5, sizeof(output));
    AssertTrue(ChatpadTranslateActivationRequest(request, &output) == expected, name);
    AssertTrue(TranslationIsZero(&output), "failure clears output deterministically");
}

static void TestInvalidDescriptors(void)
{
    ChatpadActivationRequest request = BuildRequest(4u);
    ChatpadActivationRequest before;
    ChatpadControlSetupTranslation output;

    AssertFailureClears(0, CHATPAD_CONTROL_SETUP_NULL_REQUEST, "null request rejected");
    AssertTrue(ChatpadTranslateActivationRequest(&request, 0) == CHATPAD_CONTROL_SETUP_NULL_OUTPUT, "null output rejected");

    request.Direction = (ChatpadControlDirection)99;
    AssertFailureClears(&request, CHATPAD_CONTROL_SETUP_INVALID_DIRECTION, "invalid direction enum rejected");

    request = BuildRequest(4u);
    request.RawBmRequestType |= 0x80u;
    AssertFailureClears(&request, CHATPAD_CONTROL_SETUP_DIRECTION_MISMATCH, "host-to-device enum with device-to-host bit rejected");

    request = BuildRequest(3u);
    request.RawBmRequestType &= 0x7Fu;
    AssertFailureClears(&request, CHATPAD_CONTROL_SETUP_DIRECTION_MISMATCH, "device-to-host enum with host-to-device bit rejected");

    request = BuildRequest(4u);
    request.OutboundPayloadLength = 1u;
    AssertFailureClears(&request, CHATPAD_CONTROL_SETUP_LENGTH_MISMATCH, "host-to-device payload shorter than wLength rejected");

    request = BuildRequest(4u);
    request.RawLength = 1u;
    AssertFailureClears(&request, CHATPAD_CONTROL_SETUP_LENGTH_MISMATCH, "host-to-device payload longer than wLength rejected");

    request = BuildRequest(3u);
    request.OutboundPayloadLength = 1u;
    request.OutboundPayload[0] = 0x90u;
    AssertFailureClears(&request, CHATPAD_CONTROL_SETUP_INVALID_PAYLOAD_LENGTH, "device-to-host outbound payload rejected");

    request = BuildRequest(4u);
    request.RawLength = 3u;
    request.OutboundPayloadLength = 3u;
    AssertFailureClears(&request, CHATPAD_CONTROL_SETUP_PAYLOAD_CAPACITY_EXCEEDED, "payload capacity overflow rejected");

    request = BuildRequest(3u);
    request.ExpectedInboundDataLength = 1u;
    AssertFailureClears(&request, CHATPAD_CONTROL_SETUP_LENGTH_MISMATCH, "device-to-host inbound length mismatch rejected");

    request = BuildRequest(4u);
    request.ExpectedInboundDataLength = 1u;
    AssertFailureClears(&request, CHATPAD_CONTROL_SETUP_INVALID_PAYLOAD_LENGTH, "host-to-device inbound expectation rejected");

    request = BuildRequest(4u);
    before = request;
    memset(&output, 0x5A, sizeof(output));
    AssertTrue(ChatpadTranslateActivationRequest(&request, &output) == CHATPAD_CONTROL_SETUP_OK, "valid input for immutability check translates");
    AssertTrue(memcmp(&request, &before, sizeof(request)) == 0, "translation does not mutate caller input");
}

static void TestStateAndSentinels(void)
{
    struct GuardedInput {
        uint32_t Before;
        ChatpadActivationRequest Value;
        uint32_t After;
    } input;
    struct GuardedOutput {
        uint32_t Before;
        ChatpadControlSetupTranslation Value;
        uint32_t After;
    } output;
    ChatpadControlSetupTranslation independent;
    ChatpadControlSetupTranslation repeated;

    input.Before = 0x11223344u;
    input.Value = BuildRequest(4u);
    input.After = 0x55667788u;
    output.Before = 0x99AABBCCu;
    memset(&output.Value, 0xA5, sizeof(output.Value));
    output.After = 0xDDEEFF00u;

    AssertTrue(ChatpadTranslateActivationRequest(&input.Value, &output.Value) == CHATPAD_CONTROL_SETUP_OK, "guarded translation succeeds");
    AssertTrue(input.Before == 0x11223344u && input.After == 0x55667788u, "input sentinels unchanged");
    AssertTrue(output.Before == 0x99AABBCCu && output.After == 0xDDEEFF00u, "output sentinels unchanged");

    AssertTrue(ChatpadTranslateActivationRequest(&input.Value, &independent) == CHATPAD_CONTROL_SETUP_OK, "second caller output succeeds");
    AssertTrue(memcmp(&output.Value, &independent, sizeof(independent)) == 0, "two caller outputs begin identical");
    independent.SetupPacketBytes[0] ^= 0xFFu;
    AssertTrue(output.Value.SetupPacketBytes[0] != independent.SetupPacketBytes[0], "two caller outputs share no state");

    AssertTrue(ChatpadTranslateActivationRequest(&input.Value, &repeated) == CHATPAD_CONTROL_SETUP_OK, "repeated translation succeeds");
    AssertTrue(memcmp(&output.Value, &repeated, sizeof(repeated)) == 0, "repeated translation is identical");

    input.Value = BuildRequest(0u);
    AssertTrue(ChatpadTranslateActivationRequest(&input.Value, &independent) == CHATPAD_CONTROL_SETUP_OK, "sequential first request translates");
    input.Value = BuildRequest(5u);
    AssertTrue(ChatpadTranslateActivationRequest(&input.Value, &repeated) == CHATPAD_CONTROL_SETUP_OK, "sequential second request translates");
    AssertTrue(independent.SetupPacketBytes[0] == 0x40u && repeated.SetupPacketBytes[0] == 0xC0u, "sequential translations retain no state");

    AssertTrue(sizeof(ChatpadControlSetupTranslation) < 64u, "translation is a bounded value without retained storage");
}

int main(void)
{
    TestConfirmedTranslations();
    TestEncodingAndDeterminism();
    TestInvalidDescriptors();
    TestStateAndSentinels();

    printf("Total: %d\n", TotalAssertions);
    printf("Passed: %d\n", TotalAssertions - FailedAssertions);
    printf("Failed: %d\n", FailedAssertions);
    return FailedAssertions == 0 ? 0 : 1;
}

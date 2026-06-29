#include <stdint.h>
#include <stdio.h>

#include "ChatpadActivationRequests.h"
#include "ChatpadActivationRequestFixtures.h"
#include "ChatpadActivationRequestsTests.h"

static ChatpadActivationRequestTestSummary Summary;

static void AssertTrue(const char *name, int condition)
{
    ++Summary.Total;
    if (condition != 0) {
        ++Summary.Passed;
        printf("PASS: %s\n", name);
    }
    else {
        ++Summary.Failed;
        printf("FAIL: %s\n", name);
    }
}

static void AssertBuildResult(
    const char *name,
    ChatpadActivationBuildResult expected,
    ChatpadActivationBuildResult actual)
{
    ++Summary.Total;
    if (expected == actual) {
        ++Summary.Passed;
        printf("PASS: %s\n", name);
    }
    else {
        ++Summary.Failed;
        printf("FAIL: %s expected=%d actual=%d\n", name, (int)expected, (int)actual);
    }
}

static void PoisonRequest(ChatpadActivationRequest *request)
{
    request->RawBmRequestType = 0xA5u;
    request->RawRequest = 0xA5u;
    request->RawValue = 0xA5A5u;
    request->RawIndex = 0xA5A5u;
    request->RawLength = 0xA5A5u;
    request->Direction = (ChatpadControlDirection)0xA5;
    request->OutboundPayloadLength = 0xA5A5u;
    request->ExpectedInboundDataLength = 0xA5A5u;
    request->OutboundPayload[0] = 0xA5u;
    request->OutboundPayload[1] = 0xA5u;
}

static void AssertRequestCleared(const char *name, const ChatpadActivationRequest *request)
{
    AssertTrue(
        name,
        request->RawBmRequestType == 0 &&
        request->RawRequest == 0 &&
        request->RawValue == 0 &&
        request->RawIndex == 0 &&
        request->RawLength == 0 &&
        request->Direction == CHATPAD_CONTROL_DIRECTION_HOST_TO_DEVICE &&
        request->OutboundPayloadLength == 0 &&
        request->ExpectedInboundDataLength == 0 &&
        request->OutboundPayload[0] == 0 &&
        request->OutboundPayload[1] == 0);
}

static void AssertFixtureRequest(
    const char *prefix,
    size_t index,
    const ChatpadActivationRequest *request)
{
    char name[128];
    const ChatpadActivationRequestFixture *fixture = &ConfirmedActivationRequests[index];

    (void)sprintf_s(name, sizeof(name), "%s bmRequestType", prefix);
    AssertTrue(name, request->RawBmRequestType == fixture->RawBmRequestType);
    (void)sprintf_s(name, sizeof(name), "%s bRequest", prefix);
    AssertTrue(name, request->RawRequest == fixture->RawRequest);
    (void)sprintf_s(name, sizeof(name), "%s wValue", prefix);
    AssertTrue(name, request->RawValue == fixture->RawValue);
    (void)sprintf_s(name, sizeof(name), "%s wIndex", prefix);
    AssertTrue(name, request->RawIndex == fixture->RawIndex);
    (void)sprintf_s(name, sizeof(name), "%s wLength", prefix);
    AssertTrue(name, request->RawLength == fixture->RawLength);
    (void)sprintf_s(name, sizeof(name), "%s direction", prefix);
    AssertTrue(name, request->Direction == fixture->Direction);
    (void)sprintf_s(name, sizeof(name), "%s outbound length", prefix);
    AssertTrue(name, request->OutboundPayloadLength == fixture->OutboundPayloadLength);
    (void)sprintf_s(name, sizeof(name), "%s inbound length", prefix);
    AssertTrue(name, request->ExpectedInboundDataLength == fixture->ExpectedInboundDataLength);
    (void)sprintf_s(name, sizeof(name), "%s payload byte 0", prefix);
    AssertTrue(name, request->OutboundPayload[0] == fixture->OutboundPayload[0]);
    (void)sprintf_s(name, sizeof(name), "%s payload byte 1", prefix);
    AssertTrue(name, request->OutboundPayload[1] == fixture->OutboundPayload[1]);
}

static void TestCountAndInvalidArguments(void)
{
    ChatpadActivationRequest request;
    ChatpadActivationBuildResult result;

    AssertTrue(
        "activation request count is exactly six",
        ChatpadGetActivationRequestCount() == CHATPAD_ACTIVATION_REQUEST_COUNT &&
        CHATPAD_ACTIVATION_REQUEST_COUNT == 6u);

    result = ChatpadBuildActivationRequest(0, 0);
    AssertBuildResult(
        "activation null output result",
        CHATPAD_ACTIVATION_BUILD_NULL_OUTPUT,
        result);

    PoisonRequest(&request);
    result = ChatpadBuildActivationRequest(CHATPAD_ACTIVATION_REQUEST_COUNT, &request);
    AssertBuildResult(
        "activation invalid index at count result",
        CHATPAD_ACTIVATION_BUILD_INVALID_INDEX,
        result);
    AssertRequestCleared("activation invalid index at count clears output", &request);

    PoisonRequest(&request);
    result = ChatpadBuildActivationRequest((size_t)-1, &request);
    AssertBuildResult(
        "activation invalid large index result",
        CHATPAD_ACTIVATION_BUILD_INVALID_INDEX,
        result);
    AssertRequestCleared("activation invalid large index clears output", &request);
}

static void TestExactRequestFields(void)
{
    size_t index;

    for (index = 0; index < CHATPAD_ACTIVATION_REQUEST_COUNT; ++index) {
        ChatpadActivationRequest request;
        ChatpadActivationBuildResult result;
        char prefix[64];
        char resultName[96];

        PoisonRequest(&request);
        result = ChatpadBuildActivationRequest(index, &request);
        (void)sprintf_s(resultName, sizeof(resultName), "activation request %u builds", (unsigned int)index);
        AssertBuildResult(resultName, CHATPAD_ACTIVATION_BUILD_OK, result);
        (void)sprintf_s(prefix, sizeof(prefix), "activation request %u", (unsigned int)index);
        AssertFixtureRequest(prefix, index, &request);
    }
}

static void TestPayloadBoundaries(void)
{
    size_t index;
    unsigned int payload0900Count = 0;
    unsigned int outboundPayloadCount = 0;

    for (index = 0; index < CHATPAD_ACTIVATION_REQUEST_COUNT; ++index) {
        ChatpadActivationRequest request;
        char name[128];

        (void)ChatpadBuildActivationRequest(index, &request);
        (void)sprintf_s(name, sizeof(name), "activation request %u payload capacity", (unsigned int)index);
        AssertTrue(name, request.OutboundPayloadLength <= CHATPAD_ACTIVATION_MAX_PAYLOAD_LENGTH);

        if (request.OutboundPayloadLength == 0) {
            (void)sprintf_s(name, sizeof(name), "activation request %u no outbound byte 0", (unsigned int)index);
            AssertTrue(name, request.OutboundPayload[0] == 0);
            (void)sprintf_s(name, sizeof(name), "activation request %u no outbound byte 1", (unsigned int)index);
            AssertTrue(name, request.OutboundPayload[1] == 0);
        }
        else {
            ++outboundPayloadCount;
            (void)sprintf_s(name, sizeof(name), "activation request %u confirmed payload length", (unsigned int)index);
            AssertTrue(name, request.OutboundPayloadLength == 2u);
        }

        if (request.OutboundPayloadLength == 2u &&
            request.OutboundPayload[0] == 0x09u &&
            request.OutboundPayload[1] == 0x00u) {
            ++payload0900Count;
            AssertTrue("activation confirmed 09 00 payload index", index == 4u);
        }

        if (request.Direction == CHATPAD_CONTROL_DIRECTION_DEVICE_TO_HOST) {
            (void)sprintf_s(name, sizeof(name), "activation request %u device-to-host outbound length", (unsigned int)index);
            AssertTrue(name, request.OutboundPayloadLength == 0);
            (void)sprintf_s(name, sizeof(name), "activation request %u device-to-host expected length", (unsigned int)index);
            AssertTrue(name, request.ExpectedInboundDataLength == request.RawLength);
        }
        else {
            (void)sprintf_s(name, sizeof(name), "activation request %u host-to-device inbound length", (unsigned int)index);
            AssertTrue(name, request.ExpectedInboundDataLength == 0);
        }
    }

    AssertTrue("activation confirmed 09 00 payload appears once", payload0900Count == 1u);
    AssertTrue("activation unsupported comment payload absent", outboundPayloadCount == payload0900Count);
}

static void TestDeterminismAndCopyIsolation(void)
{
    ChatpadActivationRequest first;
    ChatpadActivationRequest second;
    ChatpadActivationRequest third;
    ChatpadActivationBuildResult result;

    result = ChatpadBuildActivationRequest(4u, &first);
    AssertBuildResult("activation first copy result", CHATPAD_ACTIVATION_BUILD_OK, result);
    result = ChatpadBuildActivationRequest(4u, &second);
    AssertBuildResult("activation second copy result", CHATPAD_ACTIVATION_BUILD_OK, result);
    AssertTrue("activation repeated bmRequestType identical", first.RawBmRequestType == second.RawBmRequestType);
    AssertTrue("activation repeated bRequest identical", first.RawRequest == second.RawRequest);
    AssertTrue("activation repeated wValue identical", first.RawValue == second.RawValue);
    AssertTrue("activation repeated wIndex identical", first.RawIndex == second.RawIndex);
    AssertTrue("activation repeated wLength identical", first.RawLength == second.RawLength);
    AssertTrue("activation repeated payload byte 0 identical", first.OutboundPayload[0] == second.OutboundPayload[0]);
    AssertTrue("activation repeated payload byte 1 identical", first.OutboundPayload[1] == second.OutboundPayload[1]);

    (void)ChatpadBuildActivationRequest(0u, &first);
    (void)ChatpadBuildActivationRequest(1u, &second);
    (void)ChatpadBuildActivationRequest(0u, &third);
    AssertTrue("activation sequential construction is stateless", first.RawValue == third.RawValue);
    AssertTrue("activation sequential construction differs when evidence differs", first.RawValue != second.RawValue);

    (void)ChatpadBuildActivationRequest(4u, &first);
    first.OutboundPayload[0] = 0xAAu;
    first.OutboundPayload[1] = 0xBBu;
    (void)ChatpadBuildActivationRequest(4u, &second);
    AssertTrue("activation mutation does not affect later payload byte 0", second.OutboundPayload[0] == 0x09u);
    AssertTrue("activation mutation does not affect later payload byte 1", second.OutboundPayload[1] == 0x00u);
}

static void TestSentinelProtectionAndSemanticAbsence(void)
{
    typedef struct GuardedActivationRequest {
        uint32_t Before;
        ChatpadActivationRequest Request;
        uint32_t After;
    } GuardedActivationRequest;

    GuardedActivationRequest guarded;
    ChatpadActivationBuildResult result;
    size_t index;

    guarded.Before = UINT32_C(0x11223344);
    guarded.After = UINT32_C(0x55667788);
    PoisonRequest(&guarded.Request);
    result = ChatpadBuildActivationRequest(4u, &guarded.Request);
    AssertBuildResult("activation sentinel success result", CHATPAD_ACTIVATION_BUILD_OK, result);
    AssertTrue("activation sentinel before success unchanged", guarded.Before == UINT32_C(0x11223344));
    AssertTrue("activation sentinel after success unchanged", guarded.After == UINT32_C(0x55667788));

    PoisonRequest(&guarded.Request);
    result = ChatpadBuildActivationRequest(CHATPAD_ACTIVATION_REQUEST_COUNT, &guarded.Request);
    AssertBuildResult("activation sentinel failure result", CHATPAD_ACTIVATION_BUILD_INVALID_INDEX, result);
    AssertTrue("activation sentinel before failure unchanged", guarded.Before == UINT32_C(0x11223344));
    AssertTrue("activation sentinel after failure unchanged", guarded.After == UINT32_C(0x55667788));
    AssertRequestCleared("activation sentinel failure clears request only", &guarded.Request);

    for (index = 0; index < CHATPAD_ACTIVATION_REQUEST_COUNT; ++index) {
        ChatpadActivationRequest request;
        char name[128];

        (void)ChatpadBuildActivationRequest(index, &request);
        (void)sprintf_s(name, sizeof(name), "activation request %u no ack ready retry timeout fields", (unsigned int)index);
        AssertTrue(
            name,
            request.OutboundPayloadLength <= CHATPAD_ACTIVATION_MAX_PAYLOAD_LENGTH &&
            (request.Direction == CHATPAD_CONTROL_DIRECTION_HOST_TO_DEVICE ||
             request.Direction == CHATPAD_CONTROL_DIRECTION_DEVICE_TO_HOST));
    }
}

ChatpadActivationRequestTestSummary RunChatpadActivationRequestTests(void)
{
    Summary.Total = 0;
    Summary.Passed = 0;
    Summary.Failed = 0;

    TestCountAndInvalidArguments();
    TestExactRequestFields();
    TestPayloadBoundaries();
    TestDeterminismAndCopyIsolation();
    TestSentinelProtectionAndSemanticAbsence();

    return Summary;
}

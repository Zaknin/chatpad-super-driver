#include <stdint.h>
#include <stdio.h>

#include "ChatpadTransportAdapter.h"
#include "ChatpadTransportMock.h"

static unsigned int AssertionsTotal = 0;
static unsigned int AssertionsPassed = 0;
static unsigned int AssertionsFailed = 0;

static void AssertTrue(const char *name, int condition)
{
    ++AssertionsTotal;
    if (condition != 0) {
        ++AssertionsPassed;
        printf("PASS: %s\n", name);
    }
    else {
        ++AssertionsFailed;
        printf("FAIL: %s\n", name);
    }
}

static void AssertTransportResult(
    const char *name,
    ChatpadTransportResult expected,
    ChatpadTransportResult actual)
{
    ++AssertionsTotal;
    if (expected == actual) {
        ++AssertionsPassed;
        printf("PASS: %s\n", name);
    }
    else {
        ++AssertionsFailed;
        printf("FAIL: %s expected=%d actual=%d\n", name, (int)expected, (int)actual);
    }
}

static void AssertDisposition(
    const char *name,
    ChatpadTransportCompletionDisposition expected,
    ChatpadTransportCompletionDisposition actual)
{
    ++AssertionsTotal;
    if (expected == actual) {
        ++AssertionsPassed;
        printf("PASS: %s\n", name);
    }
    else {
        ++AssertionsFailed;
        printf("FAIL: %s expected=%d actual=%d\n", name, (int)expected, (int)actual);
    }
}

static void PoisonOperation(ChatpadTransportOperation *operation)
{
    operation->Type = CHATPAD_TRANSPORT_OPERATION_DELAY_METADATA;
    operation->DeviceGeneration = UINT64_C(0xAAAAAAAAAAAAAAAA);
    operation->ActivationStepIndex = UINT32_C(0xBBBBBBBB);
    operation->Token.DeviceGeneration = UINT64_C(0xCCCCCCCCCCCCCCCC);
    operation->Token.OperationSequence = UINT32_C(0xDDDDDDDD);
    operation->Request.RawBmRequestType = 0xEEu;
    operation->Request.RawRequest = 0xEEu;
    operation->Request.RawValue = 0xEEEEu;
    operation->Request.RawIndex = 0xEEEEu;
    operation->Request.RawLength = 0xEEEEu;
    operation->Request.Direction = CHATPAD_CONTROL_DIRECTION_DEVICE_TO_HOST;
    operation->Request.OutboundPayloadLength = 2u;
    operation->Request.ExpectedInboundDataLength = 2u;
    operation->Request.OutboundPayload[0] = 0xEEu;
    operation->Request.OutboundPayload[1] = 0xEEu;
    operation->DelayMilliseconds = 0xEEEEu;
}

static void AssertOperationCleared(const char *name, const ChatpadTransportOperation *operation)
{
    AssertTrue(
        name,
        operation->Type == CHATPAD_TRANSPORT_OPERATION_INVALID &&
        operation->DeviceGeneration == CHATPAD_TRANSPORT_INVALID_GENERATION &&
        operation->Token.DeviceGeneration == CHATPAD_TRANSPORT_INVALID_GENERATION &&
        operation->Token.OperationSequence == CHATPAD_TRANSPORT_INVALID_OPERATION_SEQUENCE &&
        operation->Request.RawBmRequestType == 0u &&
        operation->Request.OutboundPayload[0] == 0u &&
        operation->Request.OutboundPayload[1] == 0u &&
        operation->DelayMilliseconds == 0u);
}

static void AssertRequestEquals(
    const char *name,
    const ChatpadActivationRequest *expected,
    const ChatpadActivationRequest *actual)
{
    AssertTrue(
        name,
        expected->RawBmRequestType == actual->RawBmRequestType &&
        expected->RawRequest == actual->RawRequest &&
        expected->RawValue == actual->RawValue &&
        expected->RawIndex == actual->RawIndex &&
        expected->RawLength == actual->RawLength &&
        expected->Direction == actual->Direction &&
        expected->OutboundPayloadLength == actual->OutboundPayloadLength &&
        expected->ExpectedInboundDataLength == actual->ExpectedInboundDataLength &&
        expected->OutboundPayload[0] == actual->OutboundPayload[0] &&
        expected->OutboundPayload[1] == actual->OutboundPayload[1]);
}

static void TestInvalidArguments(void)
{
    ChatpadTransportAdapterState state;
    ChatpadTransportSnapshot snapshot;
    ChatpadTransportOperation operation;
    ChatpadTransportCompletionDisposition disposition;
    ChatpadActivationRequest request;

    AssertTransportResult("transport initialize null state", CHATPAD_TRANSPORT_NULL_STATE, ChatpadTransportInitialize(0));
    AssertTransportResult("transport snapshot null output", CHATPAD_TRANSPORT_NULL_OUTPUT, ChatpadTransportGetSnapshot(0, 0));
    AssertTransportResult("transport begin null state", CHATPAD_TRANSPORT_NULL_STATE, ChatpadTransportBeginGeneration(0, 1u));
    AssertTransportResult("transport cancel null state", CHATPAD_TRANSPORT_NULL_STATE, ChatpadTransportCancelGeneration(0, 1u));
    AssertTransportResult("transport close null state", CHATPAD_TRANSPORT_NULL_STATE, ChatpadTransportCloseGeneration(0, 1u));

    snapshot.CurrentGeneration = 7u;
    snapshot.LifecycleState = CHATPAD_TRANSPORT_LIFECYCLE_ACTIVE;
    AssertTransportResult("transport snapshot null state", CHATPAD_TRANSPORT_NULL_STATE, ChatpadTransportGetSnapshot(0, &snapshot));
    AssertTrue("transport snapshot cleared on null state", snapshot.CurrentGeneration == 0u && snapshot.LifecycleState == CHATPAD_TRANSPORT_LIFECYCLE_INVALID);

    PoisonOperation(&operation);
    AssertTransportResult(
        "transport submit request null state",
        CHATPAD_TRANSPORT_NULL_STATE,
        ChatpadTransportSubmitActivationRequest(0, 1u, 0u, &request, &operation));
    AssertOperationCleared("transport submit request null state clears output", &operation);
    AssertTransportResult(
        "transport submit request null output",
        CHATPAD_TRANSPORT_NULL_OUTPUT,
        ChatpadTransportSubmitActivationRequest(&state, 1u, 0u, &request, 0));
    PoisonOperation(&operation);
    AssertTransportResult(
        "transport submit request null request",
        CHATPAD_TRANSPORT_NULL_OPERATION,
        ChatpadTransportSubmitActivationRequest(&state, 1u, 0u, 0, &operation));
    AssertOperationCleared("transport submit request null request clears output", &operation);
    AssertTransportResult(
        "transport submit delay null output",
        CHATPAD_TRANSPORT_NULL_OUTPUT,
        ChatpadTransportSubmitDelayMetadata(&state, 1u, 0u, 12u, 0));
    AssertTransportResult(
        "transport complete null state",
        CHATPAD_TRANSPORT_NULL_STATE,
        ChatpadTransportCompleteOperation(0, 1u, operation.Token, &disposition));
    AssertTransportResult(
        "transport complete null disposition",
        CHATPAD_TRANSPORT_NULL_OUTPUT,
        ChatpadTransportCompleteOperation(&state, 1u, operation.Token, 0));
    AssertTransportResult(
        "transport emit null state",
        CHATPAD_TRANSPORT_NULL_STATE,
        ChatpadTransportEmitActivationPlan(0, 1u, 0, 0));
}

static void TestGenerationLifecycle(void)
{
    ChatpadTransportAdapterState state;
    ChatpadTransportSnapshot snapshot;

    AssertTransportResult("transport initialize result", CHATPAD_TRANSPORT_OK, ChatpadTransportInitialize(&state));
    AssertTrue("transport initialize generation", state.CurrentGeneration == CHATPAD_TRANSPORT_INVALID_GENERATION);
    AssertTrue("transport initialize lifecycle", state.LifecycleState == CHATPAD_TRANSPORT_LIFECYCLE_INACTIVE);
    AssertTrue("transport initialize next sequence", state.NextOperationSequence == 1u);
    AssertTransportResult("transport begin zero generation", CHATPAD_TRANSPORT_INVALID_GENERATION_ID, ChatpadTransportBeginGeneration(&state, 0u));
    AssertTransportResult("transport begin generation result", CHATPAD_TRANSPORT_OK, ChatpadTransportBeginGeneration(&state, 100u));
    AssertTrue("transport begin generation stored", state.CurrentGeneration == 100u);
    AssertTrue("transport begin active", state.LifecycleState == CHATPAD_TRANSPORT_LIFECYCLE_ACTIVE);
    AssertTrue("transport begin clears cancellation", state.CancellationRequested == 0u);
    AssertTransportResult("transport duplicate begin rejected", CHATPAD_TRANSPORT_ACTIVE_GENERATION_EXISTS, ChatpadTransportBeginGeneration(&state, 101u));
    AssertTransportResult("transport snapshot active result", CHATPAD_TRANSPORT_OK, ChatpadTransportGetSnapshot(&state, &snapshot));
    AssertTrue("transport snapshot active generation", snapshot.CurrentGeneration == 100u);
    AssertTrue("transport snapshot active state", snapshot.LifecycleState == CHATPAD_TRANSPORT_LIFECYCLE_ACTIVE);
    AssertTransportResult("transport close active result", CHATPAD_TRANSPORT_OK, ChatpadTransportCloseGeneration(&state, 100u));
    AssertTrue("transport close state", state.LifecycleState == CHATPAD_TRANSPORT_LIFECYCLE_CLOSED);
    AssertTrue("transport close cancellation", state.CancellationRequested == 1u);
    AssertTransportResult("transport begin after close result", CHATPAD_TRANSPORT_OK, ChatpadTransportBeginGeneration(&state, 101u));
    AssertTrue("transport begin after close generation", state.CurrentGeneration == 101u);
    AssertTrue("transport begin after close counters reset", state.AcceptedOperationCount == 0u && state.CompletedOperationCount == 0u);
    AssertTransportResult("transport stale close rejected", CHATPAD_TRANSPORT_STALE_GENERATION, ChatpadTransportCloseGeneration(&state, 100u));
    AssertTrue("transport stale close counted", state.RejectedStaleOperationCount == 1u);
    AssertTransportResult("transport reset result", CHATPAD_TRANSPORT_OK, ChatpadTransportReset(&state));
    AssertTrue("transport reset inactive", state.LifecycleState == CHATPAD_TRANSPORT_LIFECYCLE_INACTIVE);
}

static void TestSubmissionCompletionAndCancellation(void)
{
    ChatpadTransportAdapterState state;
    ChatpadTransportOperation requestOperation;
    ChatpadTransportOperation delayOperation;
    ChatpadTransportOperationToken pendingDelayToken;
    ChatpadTransportCompletionDisposition disposition;
    ChatpadActivationRequest request;
    ChatpadTransportOperationToken unknownToken;

    AssertTransportResult("transport init for submission", CHATPAD_TRANSPORT_OK, ChatpadTransportInitialize(&state));
    AssertTransportResult("transport begin for submission", CHATPAD_TRANSPORT_OK, ChatpadTransportBeginGeneration(&state, 200u));
    AssertTrue("transport request build for submission", ChatpadBuildActivationRequest(4u, &request) == CHATPAD_ACTIVATION_BUILD_OK);
    AssertTransportResult(
        "transport submit request result",
        CHATPAD_TRANSPORT_OK,
        ChatpadTransportSubmitActivationRequest(&state, 200u, 4u, &request, &requestOperation));
    AssertTrue("transport request operation kind", requestOperation.Type == CHATPAD_TRANSPORT_OPERATION_ACTIVATION_REQUEST);
    AssertTrue("transport request operation generation", requestOperation.DeviceGeneration == 200u);
    AssertTrue("transport request operation step", requestOperation.ActivationStepIndex == 4u);
    AssertTrue("transport request token sequence", requestOperation.Token.OperationSequence == 1u);
    AssertRequestEquals("transport request value copy", &request, &requestOperation.Request);
    request.OutboundPayload[0] = 0xAAu;
    AssertTrue("transport request independent copy", requestOperation.Request.OutboundPayload[0] == 0x09u);

    AssertTransportResult(
        "transport submit delay result",
        CHATPAD_TRANSPORT_OK,
        ChatpadTransportSubmitDelayMetadata(&state, 200u, 4u, 12u, &delayOperation));
    AssertTrue("transport delay operation kind", delayOperation.Type == CHATPAD_TRANSPORT_OPERATION_DELAY_METADATA);
    AssertTrue("transport delay operation value", delayOperation.DelayMilliseconds == 12u);
    AssertTrue("transport delay token sequence", delayOperation.Token.OperationSequence == 2u);
    AssertTrue("transport accepted count after two", state.AcceptedOperationCount == 2u);

    AssertTransportResult(
        "transport complete request result",
        CHATPAD_TRANSPORT_OK,
        ChatpadTransportCompleteOperation(&state, 200u, requestOperation.Token, &disposition));
    AssertDisposition("transport complete request disposition", CHATPAD_TRANSPORT_COMPLETION_ACCEPTED, disposition);
    AssertTrue("transport completed count one", state.CompletedOperationCount == 1u);
    AssertTransportResult(
        "transport duplicate completion result",
        CHATPAD_TRANSPORT_DUPLICATE_COMPLETION,
        ChatpadTransportCompleteOperation(&state, 200u, requestOperation.Token, &disposition));
    AssertDisposition("transport duplicate completion disposition", CHATPAD_TRANSPORT_COMPLETION_DUPLICATE, disposition);
    unknownToken.DeviceGeneration = 200u;
    unknownToken.OperationSequence = 63u;
    AssertTransportResult(
        "transport unknown completion result",
        CHATPAD_TRANSPORT_UNKNOWN_COMPLETION,
        ChatpadTransportCompleteOperation(&state, 200u, unknownToken, &disposition));
    AssertDisposition("transport unknown completion disposition", CHATPAD_TRANSPORT_COMPLETION_UNKNOWN, disposition);
    AssertTransportResult(
        "transport stale completion result",
        CHATPAD_TRANSPORT_STALE_COMPLETION,
        ChatpadTransportCompleteOperation(&state, 199u, delayOperation.Token, &disposition));
    AssertDisposition("transport stale completion disposition", CHATPAD_TRANSPORT_COMPLETION_STALE, disposition);
    AssertTrue("transport stale completion counted", state.RejectedStaleOperationCount == 1u);

    pendingDelayToken = delayOperation.Token;
    AssertTransportResult("transport cancel result", CHATPAD_TRANSPORT_OK, ChatpadTransportCancelGeneration(&state, 200u));
    AssertTrue("transport cancel state", state.LifecycleState == CHATPAD_TRANSPORT_LIFECYCLE_CANCELLING);
    AssertTransportResult(
        "transport submit after cancel result",
        CHATPAD_TRANSPORT_GENERATION_CANCELLED,
        ChatpadTransportSubmitDelayMetadata(&state, 200u, 5u, 12u, &delayOperation));
    AssertTransportResult(
        "transport complete after cancel result",
        CHATPAD_TRANSPORT_GENERATION_CANCELLED,
        ChatpadTransportCompleteOperation(&state, 200u, pendingDelayToken, &disposition));
    AssertDisposition("transport complete after cancel disposition", CHATPAD_TRANSPORT_COMPLETION_CANCELLED, disposition);
    AssertTrue("transport cancel leaves completion count", state.CompletedOperationCount == 1u);
}

static void TestActivationPlanEmission(void)
{
    ChatpadTransportAdapterState state;
    ChatpadTransportMockSink mock;
    ChatpadTransportOperationSink sink;
    ChatpadActivationExecutionSummary summary;
    ChatpadTransportCompletionDisposition disposition;
    uint32_t index;
    uint32_t payload0900Count = 0;
    uint32_t payload9000Count = 0;

    AssertTransportResult("transport init for plan", CHATPAD_TRANSPORT_OK, ChatpadTransportInitialize(&state));
    AssertTransportResult("transport begin for plan", CHATPAD_TRANSPORT_OK, ChatpadTransportBeginGeneration(&state, 300u));
    ChatpadTransportMockInitialize(&mock);
    sink = ChatpadTransportMockCreateSink(&mock);
    AssertTransportResult("transport emit plan result", CHATPAD_TRANSPORT_OK, ChatpadTransportEmitActivationPlan(&state, 300u, &sink, &summary));
    AssertTrue("transport plan mock count", mock.OperationCount == 12u);
    AssertTrue("transport plan accepted count", state.AcceptedOperationCount == 12u);
    AssertTrue("transport plan next sequence", state.NextOperationSequence == 13u);
    AssertTrue("transport plan summary steps", summary.PlannedStepCount == 6u);
    AssertTrue("transport plan summary requests", summary.EmittedRequestCount == 6u);
    AssertTrue("transport plan summary delay metadata", summary.EmittedDelayMetadataCount == 6u);
    AssertTrue("transport plan summary last step", summary.LastCompletedStepIndex == 5u);

    for (index = 0; index < mock.OperationCount; ++index) {
        const ChatpadTransportOperation *operation = &mock.Operations[index];
        char name[160];
        uint32_t expectedStep = index / 2u;

        (void)sprintf_s(name, sizeof(name), "transport plan operation %u generation", (unsigned int)index);
        AssertTrue(name, operation->DeviceGeneration == 300u);
        (void)sprintf_s(name, sizeof(name), "transport plan operation %u sequence", (unsigned int)index);
        AssertTrue(name, operation->Token.OperationSequence == index + 1u);
        (void)sprintf_s(name, sizeof(name), "transport plan operation %u step", (unsigned int)index);
        AssertTrue(name, operation->ActivationStepIndex == expectedStep);

        if ((index % 2u) == 0u) {
            (void)sprintf_s(name, sizeof(name), "transport plan operation %u request type", (unsigned int)index);
            AssertTrue(name, operation->Type == CHATPAD_TRANSPORT_OPERATION_ACTIVATION_REQUEST);
            if (operation->Request.OutboundPayloadLength == 2u &&
                operation->Request.OutboundPayload[0] == 0x09u &&
                operation->Request.OutboundPayload[1] == 0x00u) {
                ++payload0900Count;
                AssertTrue("transport plan 09 00 step", operation->ActivationStepIndex == 4u);
            }
            if (operation->Request.OutboundPayloadLength == 2u &&
                operation->Request.OutboundPayload[0] == 0x90u &&
                operation->Request.OutboundPayload[1] == 0x00u) {
                ++payload9000Count;
            }
        }
        else {
            (void)sprintf_s(name, sizeof(name), "transport plan operation %u metadata type", (unsigned int)index);
            AssertTrue(name, operation->Type == CHATPAD_TRANSPORT_OPERATION_DELAY_METADATA);
            (void)sprintf_s(name, sizeof(name), "transport plan operation %u metadata value", (unsigned int)index);
            AssertTrue(name, operation->DelayMilliseconds == 12u);
        }

        AssertTransportResult(
            "transport plan completion result",
            CHATPAD_TRANSPORT_OK,
            ChatpadTransportCompleteOperation(&state, 300u, operation->Token, &disposition));
        AssertDisposition("transport plan completion disposition", CHATPAD_TRANSPORT_COMPLETION_ACCEPTED, disposition);
    }

    AssertTrue("transport plan 09 00 exactly once", payload0900Count == 1u);
    AssertTrue("transport plan unsupported 90 00 absent", payload9000Count == 0u);
    AssertTrue("transport plan completed all", state.CompletedOperationCount == 12u);
}

static void TestActivationPlanRejection(void)
{
    ChatpadTransportAdapterState state;
    ChatpadTransportMockSink mock;
    ChatpadTransportOperationSink sink;
    ChatpadActivationExecutionSummary summary;
    ChatpadTransportResult result;

    AssertTransportResult("transport init for rejection", CHATPAD_TRANSPORT_OK, ChatpadTransportInitialize(&state));
    AssertTransportResult("transport begin for rejection", CHATPAD_TRANSPORT_OK, ChatpadTransportBeginGeneration(&state, 400u));
    ChatpadTransportMockInitialize(&mock);
    mock.Capacity = 5u;
    sink = ChatpadTransportMockCreateSink(&mock);
    result = ChatpadTransportEmitActivationPlan(&state, 400u, &sink, &summary);
    AssertTransportResult("transport capacity rejection result", CHATPAD_TRANSPORT_SINK_REJECTED_OPERATION, result);
    AssertTrue("transport capacity records five", mock.OperationCount == 5u);
    AssertTrue("transport capacity accepted six", state.AcceptedOperationCount == 6u);
    AssertTrue("transport capacity summary requests", summary.EmittedRequestCount == 3u);
    AssertTrue("transport capacity summary delay metadata", summary.EmittedDelayMetadataCount == 2u);
    AssertTrue("transport capacity rejected metadata", summary.RejectedOperation == CHATPAD_ACTIVATION_EXECUTION_OPERATION_DELAY_METADATA);
    AssertTrue("transport capacity rejected step", summary.RejectedStepIndex == 2u);

    AssertTransportResult("transport reset after rejection", CHATPAD_TRANSPORT_OK, ChatpadTransportReset(&state));
    AssertTransportResult("transport begin explicit rejection", CHATPAD_TRANSPORT_OK, ChatpadTransportBeginGeneration(&state, 401u));
    ChatpadTransportMockInitialize(&mock);
    mock.RejectAtSequence = 1u;
    sink = ChatpadTransportMockCreateSink(&mock);
    result = ChatpadTransportEmitActivationPlan(&state, 401u, &sink, &summary);
    AssertTransportResult("transport explicit rejection result", CHATPAD_TRANSPORT_SINK_REJECTED_OPERATION, result);
    AssertTrue("transport explicit rejection records zero", mock.OperationCount == 0u);
    AssertTrue("transport explicit rejection accepted one", state.AcceptedOperationCount == 1u);
    AssertTrue("transport explicit rejection request", summary.RejectedOperation == CHATPAD_ACTIVATION_EXECUTION_OPERATION_REQUEST);
    AssertTrue("transport explicit rejection step", summary.RejectedStepIndex == 0u);
}

static void TestSentinels(void)
{
    typedef struct GuardedState {
        uint32_t Before;
        ChatpadTransportAdapterState State;
        uint32_t After;
    } GuardedState;
    typedef struct GuardedOperation {
        uint32_t Before;
        ChatpadTransportOperation Operation;
        uint32_t After;
    } GuardedOperation;

    GuardedState guardedState;
    GuardedOperation guardedOperation;
    ChatpadActivationRequest request;

    guardedState.Before = UINT32_C(0x11223344);
    guardedState.After = UINT32_C(0x55667788);
    guardedOperation.Before = UINT32_C(0x99AABBCC);
    guardedOperation.After = UINT32_C(0xDDEEFF00);

    AssertTransportResult("transport guarded init", CHATPAD_TRANSPORT_OK, ChatpadTransportInitialize(&guardedState.State));
    AssertTransportResult("transport guarded begin", CHATPAD_TRANSPORT_OK, ChatpadTransportBeginGeneration(&guardedState.State, 500u));
    AssertTrue("transport guarded request build", ChatpadBuildActivationRequest(0u, &request) == CHATPAD_ACTIVATION_BUILD_OK);
    AssertTransportResult(
        "transport guarded submit",
        CHATPAD_TRANSPORT_OK,
        ChatpadTransportSubmitActivationRequest(&guardedState.State, 500u, 0u, &request, &guardedOperation.Operation));
    AssertTrue("transport guarded state before", guardedState.Before == UINT32_C(0x11223344));
    AssertTrue("transport guarded state after", guardedState.After == UINT32_C(0x55667788));
    AssertTrue("transport guarded operation before", guardedOperation.Before == UINT32_C(0x99AABBCC));
    AssertTrue("transport guarded operation after", guardedOperation.After == UINT32_C(0xDDEEFF00));
}

int main(void)
{
    TestInvalidArguments();
    TestGenerationLifecycle();
    TestSubmissionCompletionAndCancellation();
    TestActivationPlanEmission();
    TestActivationPlanRejection();
    TestSentinels();

    printf("Total: %u\n", AssertionsTotal);
    printf("Passed: %u\n", AssertionsPassed);
    printf("Failed: %u\n", AssertionsFailed);

    return AssertionsFailed == 0 ? 0 : 1;
}

#include <stdint.h>
#include <stdio.h>

#include "ChatpadActivationExecutor.h"
#include "ChatpadActivationExecutionFixtures.h"
#include "ChatpadActivationExecutorTests.h"

static ChatpadActivationExecutorTestSummary Summary;

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

static void AssertExecutionResult(
    const char *name,
    ChatpadActivationExecutionResult expected,
    ChatpadActivationExecutionResult actual)
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

static void PoisonSummary(ChatpadActivationExecutionSummary *summary)
{
    summary->PlannedStepCount = (size_t)-1;
    summary->EmittedRequestCount = (size_t)-1;
    summary->EmittedDelayMetadataCount = (size_t)-1;
    summary->LastCompletedStepIndex = (size_t)-2;
    summary->RejectedOperation = CHATPAD_ACTIVATION_EXECUTION_OPERATION_PLANNER;
    summary->RejectedStepIndex = (size_t)-3;
}

static void AssertSummaryCleared(const char *name, const ChatpadActivationExecutionSummary *summary)
{
    AssertTrue(
        name,
        summary->PlannedStepCount == 0 &&
        summary->EmittedRequestCount == 0 &&
        summary->EmittedDelayMetadataCount == 0 &&
        summary->LastCompletedStepIndex == CHATPAD_ACTIVATION_EXECUTION_NO_STEP &&
        summary->RejectedOperation == CHATPAD_ACTIVATION_EXECUTION_OPERATION_NONE &&
        summary->RejectedStepIndex == CHATPAD_ACTIVATION_EXECUTION_NO_STEP);
}

static int RequestEquals(const ChatpadActivationRequest *left, const ChatpadActivationRequest *right)
{
    return left->RawBmRequestType == right->RawBmRequestType &&
        left->RawRequest == right->RawRequest &&
        left->RawValue == right->RawValue &&
        left->RawIndex == right->RawIndex &&
        left->RawLength == right->RawLength &&
        left->Direction == right->Direction &&
        left->OutboundPayloadLength == right->OutboundPayloadLength &&
        left->ExpectedInboundDataLength == right->ExpectedInboundDataLength &&
        left->OutboundPayload[0] == right->OutboundPayload[0] &&
        left->OutboundPayload[1] == right->OutboundPayload[1];
}

static ChatpadActivationExecutionResult ExecuteWithRecorder(
    ChatpadActivationExecutionRecorder *recorder,
    ChatpadActivationExecutionSummary *summary)
{
    ChatpadActivationExecutionSink sink;

    sink = ChatpadActivationExecutionRecorderCreateSink(recorder);
    return ChatpadExecuteActivationPlan(&sink, summary);
}

static void TestInvalidArguments(void)
{
    ChatpadActivationExecutionSummary summary;
    ChatpadActivationExecutionSink sink;
    ChatpadActivationExecutionRecorder recorder;
    ChatpadActivationExecutionResult result;

    PoisonSummary(&summary);
    result = ChatpadExecuteActivationPlan(0, &summary);
    AssertExecutionResult("activation executor null sink", CHATPAD_ACTIVATION_EXECUTION_NULL_SINK, result);
    AssertSummaryCleared("activation executor null sink clears summary", &summary);

    ChatpadActivationExecutionRecorderInitialize(&recorder);
    sink = ChatpadActivationExecutionRecorderCreateSink(&recorder);
    sink.OnRequest = 0;
    PoisonSummary(&summary);
    result = ChatpadExecuteActivationPlan(&sink, &summary);
    AssertExecutionResult(
        "activation executor missing request callback",
        CHATPAD_ACTIVATION_EXECUTION_MISSING_REQUEST_CALLBACK,
        result);
    AssertSummaryCleared("activation executor missing request clears summary", &summary);
    AssertTrue("activation executor missing request invokes no callback", recorder.CallbackAttemptCount == 0);

    sink = ChatpadActivationExecutionRecorderCreateSink(&recorder);
    sink.OnDelayMetadata = 0;
    PoisonSummary(&summary);
    result = ChatpadExecuteActivationPlan(&sink, &summary);
    AssertExecutionResult(
        "activation executor missing delay callback",
        CHATPAD_ACTIVATION_EXECUTION_MISSING_DELAY_CALLBACK,
        result);
    AssertSummaryCleared("activation executor missing delay clears summary", &summary);
    AssertTrue("activation executor missing delay invokes no callback", recorder.CallbackAttemptCount == 0);

    sink = ChatpadActivationExecutionRecorderCreateSink(&recorder);
    result = ChatpadExecuteActivationPlan(&sink, 0);
    AssertExecutionResult("activation executor null summary", CHATPAD_ACTIVATION_EXECUTION_NULL_SUMMARY, result);
    AssertTrue("activation executor null summary invokes no callback", recorder.CallbackAttemptCount == 0);
}

static void TestSuccessfulExecution(void)
{
    ChatpadActivationExecutionRecorder recorder;
    ChatpadActivationExecutionSummary summary;
    ChatpadActivationExecutionResult result;
    size_t index;
    size_t requestCount = 0;
    size_t delayCount = 0;
    size_t payload0900Count = 0;
    size_t payload9000Count = 0;

    ChatpadActivationExecutionRecorderInitialize(&recorder);
    PoisonSummary(&summary);
    result = ExecuteWithRecorder(&recorder, &summary);
    AssertExecutionResult("activation executor successful execution result", CHATPAD_ACTIVATION_EXECUTION_OK, result);

    AssertTrue("activation executor exactly six request ops", recorder.RequestAttemptCount == 6u);
    AssertTrue("activation executor exactly six delay ops", recorder.DelayAttemptCount == 6u);
    AssertTrue("activation executor exactly twelve total ops", recorder.AcceptedOperationCount == 12u);
    AssertTrue("activation executor planner count exactly six", ChatpadGetActivationSequenceStepCount() == 6u);
    AssertTrue("activation executor request count exactly six", ChatpadGetActivationRequestCount() == 6u);

    for (index = 0; index < recorder.AcceptedOperationCount; ++index) {
        const ChatpadActivationRecordedOperation *record = &recorder.Records[index];
        char name[192];

        (void)sprintf_s(name, sizeof(name), "activation executor op %u sequence position", (unsigned int)index);
        AssertTrue(name, record->SequencePosition == index);

        if ((index % 2u) == 0u) {
            ChatpadActivationSequenceStep plannerStep;
            ChatpadActivationRequest builderRequest;
            size_t stepIndex = index / 2u;

            (void)sprintf_s(name, sizeof(name), "activation executor op %u request kind", (unsigned int)index);
            AssertTrue(name, record->Kind == CHATPAD_ACTIVATION_RECORDER_OPERATION_REQUEST);
            (void)sprintf_s(name, sizeof(name), "activation executor request op %u exact step", (unsigned int)stepIndex);
            AssertTrue(name, record->StepIndex == stepIndex);
            AssertTrue(
                "activation executor planner step retrieval succeeds",
                ChatpadGetActivationSequenceStep(stepIndex, &plannerStep) == CHATPAD_ACTIVATION_SEQUENCE_OK);
            AssertTrue(
                "activation executor builder request retrieval succeeds",
                ChatpadBuildActivationRequest(stepIndex, &builderRequest) == CHATPAD_ACTIVATION_BUILD_OK);
            (void)sprintf_s(name, sizeof(name), "activation executor request %u matches planner", (unsigned int)stepIndex);
            AssertTrue(name, RequestEquals(&record->Request, &plannerStep.Request));
            (void)sprintf_s(name, sizeof(name), "activation executor request %u setup matches builder", (unsigned int)stepIndex);
            AssertTrue(name, RequestEquals(&record->Request, &builderRequest));
            (void)sprintf_s(name, sizeof(name), "activation executor request %u payload bytes match planner", (unsigned int)stepIndex);
            AssertTrue(
                name,
                record->Request.OutboundPayload[0] == plannerStep.Request.OutboundPayload[0] &&
                record->Request.OutboundPayload[1] == plannerStep.Request.OutboundPayload[1]);

            if (record->Request.OutboundPayloadLength == 2u &&
                record->Request.OutboundPayload[0] == 0x09u &&
                record->Request.OutboundPayload[1] == 0x00u) {
                ++payload0900Count;
                AssertTrue("activation executor 09 00 only request step 4", record->StepIndex == 4u);
            }
            if (record->Request.OutboundPayloadLength == 2u &&
                record->Request.OutboundPayload[0] == 0x90u &&
                record->Request.OutboundPayload[1] == 0x00u) {
                ++payload9000Count;
            }
            ++requestCount;
        }
        else {
            size_t stepIndex = index / 2u;

            (void)sprintf_s(name, sizeof(name), "activation executor op %u delay kind", (unsigned int)index);
            AssertTrue(name, record->Kind == CHATPAD_ACTIVATION_RECORDER_OPERATION_DELAY_METADATA);
            (void)sprintf_s(name, sizeof(name), "activation executor delay op %u exact step", (unsigned int)stepIndex);
            AssertTrue(name, record->StepIndex == stepIndex);
            (void)sprintf_s(name, sizeof(name), "activation executor delay op %u exact value", (unsigned int)stepIndex);
            AssertTrue(name, record->DelayAfterMilliseconds == 12u);
            ++delayCount;
        }
    }

    AssertTrue("activation executor alternating request delay order", requestCount == 6u && delayCount == 6u);
    AssertTrue("activation executor confirmed 09 00 appears once", payload0900Count == 1u);
    AssertTrue("activation executor unsupported 90 00 absent", payload9000Count == 0u);
    AssertTrue("activation executor success summary planned steps", summary.PlannedStepCount == 6u);
    AssertTrue("activation executor success summary request count", summary.EmittedRequestCount == 6u);
    AssertTrue("activation executor success summary delay count", summary.EmittedDelayMetadataCount == 6u);
    AssertTrue("activation executor success summary last completed", summary.LastCompletedStepIndex == 5u);
    AssertTrue("activation executor success summary no rejected operation", summary.RejectedOperation == CHATPAD_ACTIVATION_EXECUTION_OPERATION_NONE);
    AssertTrue("activation executor success summary no rejected step", summary.RejectedStepIndex == CHATPAD_ACTIVATION_EXECUTION_NO_STEP);
    AssertTrue(
        "activation executor no active wait or elapsed-time field",
        summary.LastCompletedStepIndex == 5u &&
        summary.RejectedOperation == CHATPAD_ACTIVATION_EXECUTION_OPERATION_NONE &&
        summary.RejectedStepIndex == CHATPAD_ACTIVATION_EXECUTION_NO_STEP);
    AssertTrue(
        "activation executor no response ack ready timeout retry fields",
        summary.PlannedStepCount == ChatpadGetActivationSequenceStepCount() &&
        summary.EmittedRequestCount == recorder.RequestAttemptCount &&
        summary.EmittedDelayMetadataCount == recorder.DelayAttemptCount);
}

static void AssertRejectedRun(
    const char *prefix,
    ChatpadActivationRecorderOperationKind rejectKind,
    size_t rejectStep,
    ChatpadActivationExecutionResult expectedResult,
    ChatpadActivationExecutionOperationKind expectedRejectedOperation)
{
    ChatpadActivationExecutionRecorder recorder;
    ChatpadActivationExecutionSummary summary;
    ChatpadActivationExecutionResult result;
    char name[192];
    size_t expectedAcceptedRequests;
    size_t expectedAcceptedDelays;
    size_t expectedAcceptedOperations;

    ChatpadActivationExecutionRecorderInitialize(&recorder);
    recorder.RejectKind = rejectKind;
    recorder.RejectStepIndex = rejectStep;
    PoisonSummary(&summary);
    result = ExecuteWithRecorder(&recorder, &summary);

    (void)sprintf_s(name, sizeof(name), "%s result", prefix);
    AssertExecutionResult(name, expectedResult, result);

    if (rejectKind == CHATPAD_ACTIVATION_RECORDER_OPERATION_REQUEST) {
        expectedAcceptedRequests = rejectStep;
        expectedAcceptedDelays = rejectStep;
        expectedAcceptedOperations = rejectStep * 2u;
    }
    else {
        expectedAcceptedRequests = rejectStep + 1u;
        expectedAcceptedDelays = rejectStep;
        expectedAcceptedOperations = (rejectStep * 2u) + 1u;
    }

    (void)sprintf_s(name, sizeof(name), "%s no callback after rejection", prefix);
    AssertTrue(name, recorder.CallbackAttemptCount == expectedAcceptedOperations + 1u);
    (void)sprintf_s(name, sizeof(name), "%s accepted operation count", prefix);
    AssertTrue(name, recorder.AcceptedOperationCount == expectedAcceptedOperations);
    (void)sprintf_s(name, sizeof(name), "%s accepted request count", prefix);
    AssertTrue(name, summary.EmittedRequestCount == expectedAcceptedRequests);
    (void)sprintf_s(name, sizeof(name), "%s accepted delay count", prefix);
    AssertTrue(name, summary.EmittedDelayMetadataCount == expectedAcceptedDelays);
    (void)sprintf_s(name, sizeof(name), "%s rejected operation kind", prefix);
    AssertTrue(name, summary.RejectedOperation == expectedRejectedOperation);
    (void)sprintf_s(name, sizeof(name), "%s rejected step index", prefix);
    AssertTrue(name, summary.RejectedStepIndex == rejectStep);
    (void)sprintf_s(name, sizeof(name), "%s no retry", prefix);
    AssertTrue(name, recorder.LastRejectedSequencePosition == expectedAcceptedOperations);
}

static void TestRejectionStopsExecution(void)
{
    AssertRejectedRun(
        "activation executor request rejection step 0",
        CHATPAD_ACTIVATION_RECORDER_OPERATION_REQUEST,
        0u,
        CHATPAD_ACTIVATION_EXECUTION_REQUEST_REJECTED,
        CHATPAD_ACTIVATION_EXECUTION_OPERATION_REQUEST);
    AssertRejectedRun(
        "activation executor request rejection middle",
        CHATPAD_ACTIVATION_RECORDER_OPERATION_REQUEST,
        3u,
        CHATPAD_ACTIVATION_EXECUTION_REQUEST_REJECTED,
        CHATPAD_ACTIVATION_EXECUTION_OPERATION_REQUEST);
    AssertRejectedRun(
        "activation executor request rejection step 5",
        CHATPAD_ACTIVATION_RECORDER_OPERATION_REQUEST,
        5u,
        CHATPAD_ACTIVATION_EXECUTION_REQUEST_REJECTED,
        CHATPAD_ACTIVATION_EXECUTION_OPERATION_REQUEST);
    AssertRejectedRun(
        "activation executor delay rejection step 0",
        CHATPAD_ACTIVATION_RECORDER_OPERATION_DELAY_METADATA,
        0u,
        CHATPAD_ACTIVATION_EXECUTION_DELAY_METADATA_REJECTED,
        CHATPAD_ACTIVATION_EXECUTION_OPERATION_DELAY_METADATA);
    AssertRejectedRun(
        "activation executor delay rejection middle",
        CHATPAD_ACTIVATION_RECORDER_OPERATION_DELAY_METADATA,
        3u,
        CHATPAD_ACTIVATION_EXECUTION_DELAY_METADATA_REJECTED,
        CHATPAD_ACTIVATION_EXECUTION_OPERATION_DELAY_METADATA);
    AssertRejectedRun(
        "activation executor delay rejection step 5",
        CHATPAD_ACTIVATION_RECORDER_OPERATION_DELAY_METADATA,
        5u,
        CHATPAD_ACTIVATION_EXECUTION_DELAY_METADATA_REJECTED,
        CHATPAD_ACTIVATION_EXECUTION_OPERATION_DELAY_METADATA);
}

static void TestDeterminismAndIsolation(void)
{
    ChatpadActivationExecutionRecorder firstRecorder;
    ChatpadActivationExecutionRecorder secondRecorder;
    ChatpadActivationExecutionSummary firstSummary;
    ChatpadActivationExecutionSummary secondSummary;
    ChatpadActivationExecutionResult result;

    ChatpadActivationExecutionRecorderInitialize(&firstRecorder);
    result = ExecuteWithRecorder(&firstRecorder, &firstSummary);
    AssertExecutionResult("activation executor first deterministic run result", CHATPAD_ACTIVATION_EXECUTION_OK, result);

    ChatpadActivationExecutionRecorderInitialize(&secondRecorder);
    result = ExecuteWithRecorder(&secondRecorder, &secondSummary);
    AssertExecutionResult("activation executor second deterministic run result", CHATPAD_ACTIVATION_EXECUTION_OK, result);
    AssertTrue(
        "activation executor repeated successful execution deterministic",
        firstRecorder.AcceptedOperationCount == secondRecorder.AcceptedOperationCount &&
        firstRecorder.Records[8].Request.OutboundPayload[0] == secondRecorder.Records[8].Request.OutboundPayload[0] &&
        firstRecorder.Records[8].Request.OutboundPayload[1] == secondRecorder.Records[8].Request.OutboundPayload[1] &&
        firstSummary.LastCompletedStepIndex == secondSummary.LastCompletedStepIndex);

    ChatpadActivationExecutionRecorderInitialize(&firstRecorder);
    firstRecorder.RejectKind = CHATPAD_ACTIVATION_RECORDER_OPERATION_REQUEST;
    firstRecorder.RejectStepIndex = 2u;
    result = ExecuteWithRecorder(&firstRecorder, &firstSummary);
    AssertExecutionResult("activation executor rejected run before later success", CHATPAD_ACTIVATION_EXECUTION_REQUEST_REJECTED, result);

    ChatpadActivationExecutionRecorderInitialize(&firstRecorder);
    result = ExecuteWithRecorder(&firstRecorder, &firstSummary);
    AssertExecutionResult("activation executor successful after prior rejected run", CHATPAD_ACTIVATION_EXECUTION_OK, result);
    AssertTrue("activation executor independent recorder contexts", secondRecorder.AcceptedOperationCount == 12u);

    firstRecorder.Records[8].Request.OutboundPayload[0] = 0xAAu;
    firstRecorder.Records[8].Request.OutboundPayload[1] = 0xBBu;
    ChatpadActivationExecutionRecorderInitialize(&secondRecorder);
    result = ExecuteWithRecorder(&secondRecorder, &secondSummary);
    AssertExecutionResult("activation executor future run after recorded mutation", CHATPAD_ACTIVATION_EXECUTION_OK, result);
    AssertTrue(
        "activation executor mutation of recorded request data does not affect future runs",
        secondRecorder.Records[8].Request.OutboundPayload[0] == 0x09u &&
        secondRecorder.Records[8].Request.OutboundPayload[1] == 0x00u);
}

static void TestSentinelsCapacityAndPointerLifetime(void)
{
    typedef struct GuardedSummary {
        uint32_t Before;
        ChatpadActivationExecutionSummary SummaryValue;
        uint32_t After;
    } GuardedSummary;
    typedef struct GuardedRecorder {
        uint32_t Before;
        ChatpadActivationExecutionRecorder Recorder;
        uint32_t After;
    } GuardedRecorder;

    GuardedSummary guardedSummary;
    GuardedRecorder guardedRecorder;
    ChatpadActivationExecutionSummary summary;
    ChatpadActivationExecutionResult result;

    guardedSummary.Before = UINT32_C(0x11223344);
    guardedSummary.After = UINT32_C(0x55667788);
    guardedRecorder.Before = UINT32_C(0x99AABBCC);
    guardedRecorder.After = UINT32_C(0xDDEEFF00);
    ChatpadActivationExecutionRecorderInitialize(&guardedRecorder.Recorder);
    result = ExecuteWithRecorder(&guardedRecorder.Recorder, &guardedSummary.SummaryValue);
    AssertExecutionResult("activation executor guarded success result", CHATPAD_ACTIVATION_EXECUTION_OK, result);
    AssertTrue("activation executor sentinel protection around summary before", guardedSummary.Before == UINT32_C(0x11223344));
    AssertTrue("activation executor sentinel protection around summary after", guardedSummary.After == UINT32_C(0x55667788));
    AssertTrue("activation executor sentinel protection around recorder before", guardedRecorder.Before == UINT32_C(0x99AABBCC));
    AssertTrue("activation executor sentinel protection around recorder after", guardedRecorder.After == UINT32_C(0xDDEEFF00));

    ChatpadActivationExecutionRecorderInitialize(&guardedRecorder.Recorder);
    guardedRecorder.Recorder.Capacity = 5u;
    result = ExecuteWithRecorder(&guardedRecorder.Recorder, &summary);
    AssertExecutionResult(
        "activation executor fixed capacity exhaustion deterministic result",
        CHATPAD_ACTIVATION_EXECUTION_DELAY_METADATA_REJECTED,
        result);
    AssertTrue("activation executor fixed capacity exhaustion accepted count", guardedRecorder.Recorder.AcceptedOperationCount == 5u);
    AssertTrue("activation executor fixed capacity exhaustion rejected step", summary.RejectedStepIndex == 2u);

    ChatpadActivationExecutionRecorderInitialize(&guardedRecorder.Recorder);
    result = ExecuteWithRecorder(&guardedRecorder.Recorder, &summary);
    AssertExecutionResult("activation executor pointer lifetime first run result", CHATPAD_ACTIVATION_EXECUTION_OK, result);
    guardedRecorder.Recorder.Capacity = 0u;
    guardedRecorder.Recorder.Records[0].StepIndex = 99u;
    ChatpadActivationExecutionRecorderInitialize(&guardedRecorder.Recorder);
    result = ExecuteWithRecorder(&guardedRecorder.Recorder, &summary);
    AssertExecutionResult("activation executor retains no caller pointer after return", CHATPAD_ACTIVATION_EXECUTION_OK, result);
    AssertTrue("activation executor retained pointer run remains deterministic", guardedRecorder.Recorder.Records[0].StepIndex == 0u);
}

ChatpadActivationExecutorTestSummary RunChatpadActivationExecutorTests(void)
{
    Summary.Total = 0;
    Summary.Passed = 0;
    Summary.Failed = 0;

    TestInvalidArguments();
    TestSuccessfulExecution();
    TestRejectionStopsExecution();
    TestDeterminismAndIsolation();
    TestSentinelsCapacityAndPointerLifetime();

    return Summary;
}

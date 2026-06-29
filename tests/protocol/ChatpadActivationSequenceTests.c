#include <stdint.h>
#include <stdio.h>

#include "ChatpadActivationSequence.h"
#include "ChatpadActivationSequenceFixtures.h"
#include "ChatpadActivationSequenceTests.h"

static ChatpadActivationSequenceTestSummary Summary;

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

static void AssertSequenceResult(
    const char *name,
    ChatpadActivationSequenceResult expected,
    ChatpadActivationSequenceResult actual)
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

static void PoisonStep(ChatpadActivationSequenceStep *step)
{
    step->SequenceIndex = (size_t)-1;
    step->RequestIndex = (size_t)-1;
    step->Request.RawBmRequestType = 0xA5u;
    step->Request.RawRequest = 0xA5u;
    step->Request.RawValue = 0xA5A5u;
    step->Request.RawIndex = 0xA5A5u;
    step->Request.RawLength = 0xA5A5u;
    step->Request.Direction = (ChatpadControlDirection)0xA5;
    step->Request.OutboundPayloadLength = 0xA5A5u;
    step->Request.ExpectedInboundDataLength = 0xA5A5u;
    step->Request.OutboundPayload[0] = 0xA5u;
    step->Request.OutboundPayload[1] = 0xA5u;
    step->DelayBeforeMilliseconds = 0xA5A5u;
    step->DelayAfterMilliseconds = 0xA5A5u;
}

static void AssertStepCleared(const char *name, const ChatpadActivationSequenceStep *step)
{
    AssertTrue(
        name,
        step->SequenceIndex == 0 &&
        step->RequestIndex == 0 &&
        step->Request.RawBmRequestType == 0 &&
        step->Request.RawRequest == 0 &&
        step->Request.RawValue == 0 &&
        step->Request.RawIndex == 0 &&
        step->Request.RawLength == 0 &&
        step->Request.Direction == CHATPAD_CONTROL_DIRECTION_HOST_TO_DEVICE &&
        step->Request.OutboundPayloadLength == 0 &&
        step->Request.ExpectedInboundDataLength == 0 &&
        step->Request.OutboundPayload[0] == 0 &&
        step->Request.OutboundPayload[1] == 0 &&
        step->DelayBeforeMilliseconds == 0 &&
        step->DelayAfterMilliseconds == 0);
}

static void AssertRequestMatchesBuilder(
    const char *prefix,
    size_t index,
    const ChatpadActivationRequest *actual)
{
    char name[160];
    ChatpadActivationRequest expected;
    ChatpadActivationBuildResult buildResult;

    buildResult = ChatpadBuildActivationRequest(index, &expected);
    (void)sprintf_s(name, sizeof(name), "%s matching builder result", prefix);
    AssertTrue(name, buildResult == CHATPAD_ACTIVATION_BUILD_OK);
    (void)sprintf_s(name, sizeof(name), "%s bmRequestType matches builder", prefix);
    AssertTrue(name, actual->RawBmRequestType == expected.RawBmRequestType);
    (void)sprintf_s(name, sizeof(name), "%s bRequest matches builder", prefix);
    AssertTrue(name, actual->RawRequest == expected.RawRequest);
    (void)sprintf_s(name, sizeof(name), "%s wValue matches builder", prefix);
    AssertTrue(name, actual->RawValue == expected.RawValue);
    (void)sprintf_s(name, sizeof(name), "%s wIndex matches builder", prefix);
    AssertTrue(name, actual->RawIndex == expected.RawIndex);
    (void)sprintf_s(name, sizeof(name), "%s wLength matches builder", prefix);
    AssertTrue(name, actual->RawLength == expected.RawLength);
    (void)sprintf_s(name, sizeof(name), "%s direction matches builder", prefix);
    AssertTrue(name, actual->Direction == expected.Direction);
    (void)sprintf_s(name, sizeof(name), "%s outbound length matches builder", prefix);
    AssertTrue(name, actual->OutboundPayloadLength == expected.OutboundPayloadLength);
    (void)sprintf_s(name, sizeof(name), "%s inbound length matches builder", prefix);
    AssertTrue(name, actual->ExpectedInboundDataLength == expected.ExpectedInboundDataLength);
    (void)sprintf_s(name, sizeof(name), "%s payload byte 0 matches builder", prefix);
    AssertTrue(name, actual->OutboundPayload[0] == expected.OutboundPayload[0]);
    (void)sprintf_s(name, sizeof(name), "%s payload byte 1 matches builder", prefix);
    AssertTrue(name, actual->OutboundPayload[1] == expected.OutboundPayload[1]);
}

static void TestCountAndInvalidArguments(void)
{
    ChatpadActivationSequenceStep step;
    ChatpadActivationSequenceResult result;

    AssertTrue(
        "activation sequence count is exactly six",
        ChatpadGetActivationSequenceStepCount() == CHATPAD_ACTIVATION_SEQUENCE_STEP_COUNT &&
        CHATPAD_ACTIVATION_SEQUENCE_STEP_COUNT == 6u);
    AssertTrue(
        "activation sequence count equals request builder count",
        ChatpadGetActivationSequenceStepCount() == ChatpadGetActivationRequestCount());

    result = ChatpadGetActivationSequenceStep(0, 0);
    AssertSequenceResult(
        "activation sequence null output result",
        CHATPAD_ACTIVATION_SEQUENCE_NULL_OUTPUT,
        result);

    PoisonStep(&step);
    result = ChatpadGetActivationSequenceStep(CHATPAD_ACTIVATION_SEQUENCE_STEP_COUNT, &step);
    AssertSequenceResult(
        "activation sequence invalid index at count result",
        CHATPAD_ACTIVATION_SEQUENCE_INVALID_STEP_INDEX,
        result);
    AssertStepCleared("activation sequence invalid index at count clears output", &step);

    PoisonStep(&step);
    result = ChatpadGetActivationSequenceStep((size_t)-1, &step);
    AssertSequenceResult(
        "activation sequence invalid large index result",
        CHATPAD_ACTIVATION_SEQUENCE_INVALID_STEP_INDEX,
        result);
    AssertStepCleared("activation sequence invalid large index clears output", &step);
}

static void TestAllStepsMatchBuilderAndTiming(void)
{
    size_t index;
    unsigned int payload0900Count = 0;
    unsigned int payload9000Count = 0;
    unsigned int zeroBeforeCount = 0;

    for (index = 0; index < CHATPAD_ACTIVATION_SEQUENCE_STEP_COUNT; ++index) {
        ChatpadActivationSequenceStep step;
        ChatpadActivationSequenceResult result;
        char prefix[96];
        char name[160];

        PoisonStep(&step);
        result = ChatpadGetActivationSequenceStep(index, &step);
        (void)sprintf_s(name, sizeof(name), "activation sequence step %u builds", (unsigned int)index);
        AssertSequenceResult(name, CHATPAD_ACTIVATION_SEQUENCE_OK, result);

        (void)sprintf_s(name, sizeof(name), "activation sequence step %u sequence index", (unsigned int)index);
        AssertTrue(name, step.SequenceIndex == index);
        (void)sprintf_s(name, sizeof(name), "activation sequence step %u request index", (unsigned int)index);
        AssertTrue(name, step.RequestIndex == index);

        (void)sprintf_s(prefix, sizeof(prefix), "activation sequence step %u", (unsigned int)index);
        AssertRequestMatchesBuilder(prefix, index, &step.Request);

        (void)sprintf_s(name, sizeof(name), "activation sequence step %u delay before metadata", (unsigned int)index);
        AssertTrue(name, step.DelayBeforeMilliseconds == ConfirmedActivationSequenceTiming[index].DelayBeforeMilliseconds);
        (void)sprintf_s(name, sizeof(name), "activation sequence step %u delay after metadata", (unsigned int)index);
        AssertTrue(name, step.DelayAfterMilliseconds == ConfirmedActivationSequenceTiming[index].DelayAfterMilliseconds);
        if (step.DelayBeforeMilliseconds == 0u) {
            ++zeroBeforeCount;
        }

        (void)sprintf_s(name, sizeof(name), "activation sequence step %u no executable timing state", (unsigned int)index);
        AssertTrue(name, step.DelayAfterMilliseconds == 12u && step.DelayBeforeMilliseconds == 0u);

        if (step.Request.OutboundPayloadLength == 2u &&
            step.Request.OutboundPayload[0] == 0x09u &&
            step.Request.OutboundPayload[1] == 0x00u) {
            ++payload0900Count;
            AssertTrue("activation sequence confirmed 09 00 payload index", index == 4u);
        }

        if (step.Request.OutboundPayloadLength == 2u &&
            step.Request.OutboundPayload[0] == 0x90u &&
            step.Request.OutboundPayload[1] == 0x00u) {
            ++payload9000Count;
        }
    }

    AssertTrue("activation sequence confirmed 09 00 payload appears once", payload0900Count == 1u);
    AssertTrue("activation sequence unsupported 90 00 payload absent", payload9000Count == 0u);
    AssertTrue("activation sequence zero before metadata where unconfirmed", zeroBeforeCount == CHATPAD_ACTIVATION_SEQUENCE_STEP_COUNT);
}

static void TestDeterminismAndCopyIsolation(void)
{
    ChatpadActivationSequenceStep first;
    ChatpadActivationSequenceStep second;
    ChatpadActivationSequenceStep third;
    ChatpadActivationSequenceResult result;

    result = ChatpadGetActivationSequenceStep(4u, &first);
    AssertSequenceResult("activation sequence first copy result", CHATPAD_ACTIVATION_SEQUENCE_OK, result);
    result = ChatpadGetActivationSequenceStep(4u, &second);
    AssertSequenceResult("activation sequence second copy result", CHATPAD_ACTIVATION_SEQUENCE_OK, result);

    AssertTrue("activation sequence repeated sequence index identical", first.SequenceIndex == second.SequenceIndex);
    AssertTrue("activation sequence repeated request index identical", first.RequestIndex == second.RequestIndex);
    AssertTrue("activation sequence repeated bmRequestType identical", first.Request.RawBmRequestType == second.Request.RawBmRequestType);
    AssertTrue("activation sequence repeated payload byte 0 identical", first.Request.OutboundPayload[0] == second.Request.OutboundPayload[0]);
    AssertTrue("activation sequence repeated payload byte 1 identical", first.Request.OutboundPayload[1] == second.Request.OutboundPayload[1]);
    AssertTrue("activation sequence repeated delay before identical", first.DelayBeforeMilliseconds == second.DelayBeforeMilliseconds);
    AssertTrue("activation sequence repeated delay after identical", first.DelayAfterMilliseconds == second.DelayAfterMilliseconds);

    (void)ChatpadGetActivationSequenceStep(0u, &first);
    (void)ChatpadGetActivationSequenceStep(1u, &second);
    (void)ChatpadGetActivationSequenceStep(0u, &third);
    AssertTrue("activation sequence sequential construction is stateless", first.Request.RawValue == third.Request.RawValue);
    AssertTrue("activation sequence sequential construction differs when evidence differs", first.Request.RawValue != second.Request.RawValue);

    (void)ChatpadGetActivationSequenceStep(4u, &first);
    first.SequenceIndex = 99u;
    first.RequestIndex = 99u;
    first.Request.OutboundPayload[0] = 0xAAu;
    first.Request.OutboundPayload[1] = 0xBBu;
    first.DelayBeforeMilliseconds = 99u;
    first.DelayAfterMilliseconds = 99u;
    (void)ChatpadGetActivationSequenceStep(4u, &second);
    AssertTrue("activation sequence mutation does not affect later sequence index", second.SequenceIndex == 4u);
    AssertTrue("activation sequence mutation does not affect later request index", second.RequestIndex == 4u);
    AssertTrue("activation sequence mutation does not affect later payload byte 0", second.Request.OutboundPayload[0] == 0x09u);
    AssertTrue("activation sequence mutation does not affect later payload byte 1", second.Request.OutboundPayload[1] == 0x00u);
    AssertTrue("activation sequence mutation does not affect later delay before", second.DelayBeforeMilliseconds == 0u);
    AssertTrue("activation sequence mutation does not affect later delay after", second.DelayAfterMilliseconds == 12u);
}

static void TestSentinelsAndSemanticAbsence(void)
{
    typedef struct GuardedActivationSequenceStep {
        uint32_t Before;
        ChatpadActivationSequenceStep Step;
        uint32_t After;
    } GuardedActivationSequenceStep;

    GuardedActivationSequenceStep guarded;
    ChatpadActivationSequenceResult result;
    size_t index;

    guarded.Before = UINT32_C(0x11223344);
    guarded.After = UINT32_C(0x55667788);
    PoisonStep(&guarded.Step);
    result = ChatpadGetActivationSequenceStep(4u, &guarded.Step);
    AssertSequenceResult("activation sequence sentinel success result", CHATPAD_ACTIVATION_SEQUENCE_OK, result);
    AssertTrue("activation sequence sentinel before success unchanged", guarded.Before == UINT32_C(0x11223344));
    AssertTrue("activation sequence sentinel after success unchanged", guarded.After == UINT32_C(0x55667788));

    PoisonStep(&guarded.Step);
    result = ChatpadGetActivationSequenceStep(CHATPAD_ACTIVATION_SEQUENCE_STEP_COUNT, &guarded.Step);
    AssertSequenceResult(
        "activation sequence sentinel failure result",
        CHATPAD_ACTIVATION_SEQUENCE_INVALID_STEP_INDEX,
        result);
    AssertTrue("activation sequence sentinel before failure unchanged", guarded.Before == UINT32_C(0x11223344));
    AssertTrue("activation sequence sentinel after failure unchanged", guarded.After == UINT32_C(0x55667788));
    AssertStepCleared("activation sequence sentinel failure clears step only", &guarded.Step);

    for (index = 0; index < CHATPAD_ACTIVATION_SEQUENCE_STEP_COUNT; ++index) {
        ChatpadActivationSequenceStep step;
        char name[160];

        (void)ChatpadGetActivationSequenceStep(index, &step);
        (void)sprintf_s(name, sizeof(name), "activation sequence step %u no ack ready retry timeout statuses", (unsigned int)index);
        AssertTrue(
            name,
            step.DelayBeforeMilliseconds <= 12u &&
            step.DelayAfterMilliseconds == 12u &&
            (step.Request.Direction == CHATPAD_CONTROL_DIRECTION_HOST_TO_DEVICE ||
             step.Request.Direction == CHATPAD_CONTROL_DIRECTION_DEVICE_TO_HOST));
    }
}

ChatpadActivationSequenceTestSummary RunChatpadActivationSequenceTests(void)
{
    Summary.Total = 0;
    Summary.Passed = 0;
    Summary.Failed = 0;

    TestCountAndInvalidArguments();
    TestAllStepsMatchBuilderAndTiming();
    TestDeterminismAndCopyIsolation();
    TestSentinelsAndSemanticAbsence();

    return Summary;
}

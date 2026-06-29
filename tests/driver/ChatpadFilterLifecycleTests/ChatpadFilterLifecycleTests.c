#include "ChatpadFilterLifecycle.h"

#include <stdio.h>

static unsigned int g_totalAssertions = 0u;
static unsigned int g_failedAssertions = 0u;

static void
RecordAssertion(
    const char *name,
    int condition
    )
{
    g_totalAssertions += 1u;
    if (condition) {
        (void)printf("PASS: %s\n", name);
        return;
    }

    g_failedAssertions += 1u;
    (void)printf("FAIL: %s\n", name);
}

static void
ExpectResult(
    const char *name,
    ChatpadFilterLifecycleResult actual,
    ChatpadFilterLifecycleResult expected
    )
{
    RecordAssertion(name, actual == expected);
}

static void
ExpectPhase(
    const char *name,
    ChatpadFilterLifecyclePhase actual,
    ChatpadFilterLifecyclePhase expected
    )
{
    RecordAssertion(name, actual == expected);
}

static void
ExpectU8(
    const char *name,
    uint8_t actual,
    uint8_t expected
    )
{
    RecordAssertion(name, actual == expected);
}

static void
ExpectU32(
    const char *name,
    uint32_t actual,
    uint32_t expected
    )
{
    RecordAssertion(name, actual == expected);
}

static void
ExpectU64(
    const char *name,
    uint64_t actual,
    uint64_t expected
    )
{
    RecordAssertion(name, actual == expected);
}

static void
TestInitialAndCreatedPhases(void)
{
    ChatpadFilterLifecycleState state = {0};
    ChatpadFilterLifecycleSnapshot snapshot = {0};
    uint64_t generation = 123u;

    ExpectResult("initialize null state", ChatpadFilterLifecycleInitialize(0), CHATPAD_FILTER_LIFECYCLE_NULL_STATE);
    ExpectResult("snapshot null output", ChatpadFilterLifecycleGetSnapshot(&state, 0), CHATPAD_FILTER_LIFECYCLE_NULL_OUTPUT);
    ExpectResult("zero state before initialize rejected", ChatpadFilterLifecycleGetSnapshot(&state, &snapshot), CHATPAD_FILTER_LIFECYCLE_NOT_MARKED);
    ExpectPhase("zero state snapshot phase cleared", snapshot.Phase, CHATPAD_FILTER_LIFECYCLE_PHASE_UNSET);
    ExpectResult("mark created before initialize rejected", ChatpadFilterLifecycleMarkDeviceCreated(&state), CHATPAD_FILTER_LIFECYCLE_NOT_MARKED);
    ExpectResult("prepare before initialize rejected", ChatpadFilterLifecyclePrepareHardware(&state), CHATPAD_FILTER_LIFECYCLE_NOT_MARKED);
    ExpectResult("enter D0 before initialize rejected", ChatpadFilterLifecycleEnterD0(&state, &generation), CHATPAD_FILTER_LIFECYCLE_NOT_MARKED);
    ExpectU64("failed enter D0 clears generation", generation, CHATPAD_FILTER_LIFECYCLE_INVALID_GENERATION);

    ExpectResult("initialize result", ChatpadFilterLifecycleInitialize(&state), CHATPAD_FILTER_LIFECYCLE_OK);
    ExpectU32("initialize signature", state.Signature, CHATPAD_FILTER_LIFECYCLE_SIGNATURE);
    ExpectU32("initialize version", state.Version, CHATPAD_FILTER_LIFECYCLE_VERSION);
    ExpectPhase("initialize phase unset", state.Phase, CHATPAD_FILTER_LIFECYCLE_PHASE_UNSET);
    ExpectU64("initialize current generation zero", state.CurrentGeneration, CHATPAD_FILTER_LIFECYCLE_INVALID_GENERATION);
    ExpectU64("initialize next generation one", state.NextGeneration, 1u);
    ExpectU32("initialize outstanding zero", state.OutstandingOperationCount, 0u);
    ExpectU8("initialize admission closed", state.OperationAdmissionOpen, 0u);
    ExpectResult("mark created result", ChatpadFilterLifecycleMarkDeviceCreated(&state), CHATPAD_FILTER_LIFECYCLE_OK);
    ExpectPhase("created phase", state.Phase, CHATPAD_FILTER_LIFECYCLE_PHASE_CREATED);
    ExpectResult("duplicate created rejected", ChatpadFilterLifecycleMarkDeviceCreated(&state), CHATPAD_FILTER_LIFECYCLE_INVALID_PHASE);
    ExpectPhase("duplicate created preserves phase", state.Phase, CHATPAD_FILTER_LIFECYCLE_PHASE_CREATED);
}

static void
TestPrepareAndD0Generations(void)
{
    ChatpadFilterLifecycleState state;
    ChatpadFilterLifecycleSnapshot snapshot;
    uint64_t generation = 0u;

    (void)ChatpadFilterLifecycleInitialize(&state);
    (void)ChatpadFilterLifecycleMarkDeviceCreated(&state);

    ExpectResult("prepare result", ChatpadFilterLifecyclePrepareHardware(&state), CHATPAD_FILTER_LIFECYCLE_OK);
    ExpectPhase("prepare phase", state.Phase, CHATPAD_FILTER_LIFECYCLE_PHASE_PREPARED);
    ExpectResult("duplicate prepare rejected", ChatpadFilterLifecyclePrepareHardware(&state), CHATPAD_FILTER_LIFECYCLE_INVALID_PHASE);
    ExpectResult("enter D0 null output", ChatpadFilterLifecycleEnterD0(&state, 0), CHATPAD_FILTER_LIFECYCLE_NULL_OUTPUT);
    ExpectPhase("enter D0 null output preserves phase", state.Phase, CHATPAD_FILTER_LIFECYCLE_PHASE_PREPARED);
    ExpectResult("first enter D0 result", ChatpadFilterLifecycleEnterD0(&state, &generation), CHATPAD_FILTER_LIFECYCLE_OK);
    ExpectU64("first D0 generation one", generation, 1u);
    ExpectPhase("first D0 phase active", state.Phase, CHATPAD_FILTER_LIFECYCLE_PHASE_D0_ACTIVE);
    ExpectU64("first D0 current generation", state.CurrentGeneration, 1u);
    ExpectU64("first D0 next generation two", state.NextGeneration, 2u);
    ExpectU8("first D0 admission open", state.OperationAdmissionOpen, 1u);
    ExpectU32("first D0 outstanding zero", state.OutstandingOperationCount, 0u);
    ExpectResult("duplicate enter D0 rejected", ChatpadFilterLifecycleEnterD0(&state, &generation), CHATPAD_FILTER_LIFECYCLE_INVALID_PHASE);
    ExpectU64("duplicate enter D0 clears generation", generation, CHATPAD_FILTER_LIFECYCLE_INVALID_GENERATION);
    ExpectResult("snapshot active result", ChatpadFilterLifecycleGetSnapshot(&state, &snapshot), CHATPAD_FILTER_LIFECYCLE_OK);
    ExpectPhase("snapshot active phase", snapshot.Phase, CHATPAD_FILTER_LIFECYCLE_PHASE_D0_ACTIVE);
    ExpectU64("snapshot active generation", snapshot.CurrentGeneration, 1u);
    ExpectU64("snapshot active next generation", snapshot.NextGeneration, 2u);
}

static void
TestAdmissionAndRundown(void)
{
    ChatpadFilterLifecycleState state;
    uint64_t generation = 0u;

    (void)ChatpadFilterLifecycleInitialize(&state);
    (void)ChatpadFilterLifecycleMarkDeviceCreated(&state);
    (void)ChatpadFilterLifecyclePrepareHardware(&state);
    (void)ChatpadFilterLifecycleEnterD0(&state, &generation);

    ExpectResult("acquire zero generation rejected", ChatpadFilterLifecycleTryAcquireOperation(&state, 0u), CHATPAD_FILTER_LIFECYCLE_INVALID_GENERATION_ID);
    ExpectU32("zero generation leaves outstanding", state.OutstandingOperationCount, 0u);
    ExpectResult("acquire current generation result", ChatpadFilterLifecycleTryAcquireOperation(&state, generation), CHATPAD_FILTER_LIFECYCLE_OK);
    ExpectU32("first acquire outstanding one", state.OutstandingOperationCount, 1u);
    ExpectResult("second acquire result", ChatpadFilterLifecycleTryAcquireOperation(&state, generation), CHATPAD_FILTER_LIFECYCLE_OK);
    ExpectU32("second acquire outstanding two", state.OutstandingOperationCount, 2u);
    ExpectResult("stale acquire rejected", ChatpadFilterLifecycleTryAcquireOperation(&state, generation + 1u), CHATPAD_FILTER_LIFECYCLE_STALE_GENERATION);
    ExpectU32("stale acquire leaves outstanding two", state.OutstandingOperationCount, 2u);
    ExpectResult("release stale rejected", ChatpadFilterLifecycleReleaseOperation(&state, generation + 1u), CHATPAD_FILTER_LIFECYCLE_STALE_GENERATION);
    ExpectU32("release stale leaves outstanding two", state.OutstandingOperationCount, 2u);
    ExpectResult("release current result", ChatpadFilterLifecycleReleaseOperation(&state, generation), CHATPAD_FILTER_LIFECYCLE_OK);
    ExpectU32("release current outstanding one", state.OutstandingOperationCount, 1u);
    ExpectResult("begin rundown stale rejected", ChatpadFilterLifecycleBeginD0Rundown(&state, generation + 1u), CHATPAD_FILTER_LIFECYCLE_STALE_GENERATION);
    ExpectPhase("stale rundown keeps active", state.Phase, CHATPAD_FILTER_LIFECYCLE_PHASE_D0_ACTIVE);
    ExpectU8("stale rundown keeps admission open", state.OperationAdmissionOpen, 1u);
    ExpectResult("begin rundown current result", ChatpadFilterLifecycleBeginD0Rundown(&state, generation), CHATPAD_FILTER_LIFECYCLE_OK);
    ExpectPhase("rundown phase", state.Phase, CHATPAD_FILTER_LIFECYCLE_PHASE_RUNDOWN_REQUESTED);
    ExpectU8("rundown closes admission", state.OperationAdmissionOpen, 0u);
    ExpectResult("acquire after rundown rejected", ChatpadFilterLifecycleTryAcquireOperation(&state, generation), CHATPAD_FILTER_LIFECYCLE_INVALID_PHASE);
    ExpectU32("acquire after rundown leaves outstanding one", state.OutstandingOperationCount, 1u);
    ExpectResult("complete D0 busy result", ChatpadFilterLifecycleCompleteD0Exit(&state, generation), CHATPAD_FILTER_LIFECYCLE_RUNDOWN_INCOMPLETE);
    ExpectPhase("busy D0 completion keeps rundown", state.Phase, CHATPAD_FILTER_LIFECYCLE_PHASE_RUNDOWN_REQUESTED);
    ExpectU64("busy D0 completion keeps generation", state.CurrentGeneration, generation);
    ExpectResult("release during rundown result", ChatpadFilterLifecycleReleaseOperation(&state, generation), CHATPAD_FILTER_LIFECYCLE_OK);
    ExpectU32("release during rundown outstanding zero", state.OutstandingOperationCount, 0u);
    ExpectResult("release underflow rejected", ChatpadFilterLifecycleReleaseOperation(&state, generation), CHATPAD_FILTER_LIFECYCLE_NO_OUTSTANDING_OPERATION);
    ExpectResult("complete D0 result", ChatpadFilterLifecycleCompleteD0Exit(&state, generation), CHATPAD_FILTER_LIFECYCLE_OK);
    ExpectPhase("complete D0 stopped phase", state.Phase, CHATPAD_FILTER_LIFECYCLE_PHASE_D0_STOPPED);
    ExpectU64("complete D0 clears current generation", state.CurrentGeneration, CHATPAD_FILTER_LIFECYCLE_INVALID_GENERATION);
    ExpectU8("complete D0 admission closed", state.OperationAdmissionOpen, 0u);
    ExpectResult("duplicate complete D0 stale", ChatpadFilterLifecycleCompleteD0Exit(&state, generation), CHATPAD_FILTER_LIFECYCLE_STALE_GENERATION);
}

static void
TestSecondGenerationAndStaleProtection(void)
{
    ChatpadFilterLifecycleState state;
    uint64_t firstGeneration = 0u;
    uint64_t secondGeneration = 0u;

    (void)ChatpadFilterLifecycleInitialize(&state);
    (void)ChatpadFilterLifecycleMarkDeviceCreated(&state);
    (void)ChatpadFilterLifecyclePrepareHardware(&state);
    (void)ChatpadFilterLifecycleEnterD0(&state, &firstGeneration);
    (void)ChatpadFilterLifecycleBeginD0Rundown(&state, firstGeneration);
    (void)ChatpadFilterLifecycleCompleteD0Exit(&state, firstGeneration);

    ExpectResult("enter second generation result", ChatpadFilterLifecycleEnterD0(&state, &secondGeneration), CHATPAD_FILTER_LIFECYCLE_OK);
    ExpectU64("second generation increments", secondGeneration, 2u);
    ExpectU64("second generation current", state.CurrentGeneration, secondGeneration);
    ExpectU64("second generation next", state.NextGeneration, 3u);
    ExpectResult("old generation acquire stale", ChatpadFilterLifecycleTryAcquireOperation(&state, firstGeneration), CHATPAD_FILTER_LIFECYCLE_STALE_GENERATION);
    ExpectU32("old generation acquire leaves count", state.OutstandingOperationCount, 0u);
    ExpectResult("current generation acquire result", ChatpadFilterLifecycleTryAcquireOperation(&state, secondGeneration), CHATPAD_FILTER_LIFECYCLE_OK);
    ExpectU32("current generation outstanding one", state.OutstandingOperationCount, 1u);
    ExpectResult("old generation release stale", ChatpadFilterLifecycleReleaseOperation(&state, firstGeneration), CHATPAD_FILTER_LIFECYCLE_STALE_GENERATION);
    ExpectU32("old generation release leaves count", state.OutstandingOperationCount, 1u);
    ExpectResult("old generation rundown stale", ChatpadFilterLifecycleBeginD0Rundown(&state, firstGeneration), CHATPAD_FILTER_LIFECYCLE_STALE_GENERATION);
    ExpectPhase("old generation rundown preserves active", state.Phase, CHATPAD_FILTER_LIFECYCLE_PHASE_D0_ACTIVE);
    ExpectResult("current generation release result", ChatpadFilterLifecycleReleaseOperation(&state, secondGeneration), CHATPAD_FILTER_LIFECYCLE_OK);
    ExpectResult("current generation rundown result", ChatpadFilterLifecycleBeginD0Rundown(&state, secondGeneration), CHATPAD_FILTER_LIFECYCLE_OK);
    ExpectResult("current generation complete result", ChatpadFilterLifecycleCompleteD0Exit(&state, secondGeneration), CHATPAD_FILTER_LIFECYCLE_OK);
}

static void
TestReleaseHardwareAndTerminalRules(void)
{
    ChatpadFilterLifecycleState state;
    uint64_t generation = 0u;

    (void)ChatpadFilterLifecycleInitialize(&state);
    (void)ChatpadFilterLifecycleMarkDeviceCreated(&state);
    ExpectResult("release before prepare rejected", ChatpadFilterLifecycleReleaseHardware(&state), CHATPAD_FILTER_LIFECYCLE_INVALID_PHASE);
    (void)ChatpadFilterLifecyclePrepareHardware(&state);
    ExpectResult("release from prepared result", ChatpadFilterLifecycleReleaseHardware(&state), CHATPAD_FILTER_LIFECYCLE_OK);
    ExpectPhase("release from prepared phase", state.Phase, CHATPAD_FILTER_LIFECYCLE_PHASE_RELEASED);
    ExpectResult("duplicate release rejected", ChatpadFilterLifecycleReleaseHardware(&state), CHATPAD_FILTER_LIFECYCLE_INVALID_PHASE);

    (void)ChatpadFilterLifecycleInitialize(&state);
    (void)ChatpadFilterLifecycleMarkDeviceCreated(&state);
    (void)ChatpadFilterLifecyclePrepareHardware(&state);
    (void)ChatpadFilterLifecycleEnterD0(&state, &generation);
    ExpectResult("release while active rejected", ChatpadFilterLifecycleReleaseHardware(&state), CHATPAD_FILTER_LIFECYCLE_INVALID_PHASE);
    ExpectPhase("release while active preserves active", state.Phase, CHATPAD_FILTER_LIFECYCLE_PHASE_D0_ACTIVE);
    (void)ChatpadFilterLifecycleBeginD0Rundown(&state, generation);
    ExpectResult("release during rundown rejected", ChatpadFilterLifecycleReleaseHardware(&state), CHATPAD_FILTER_LIFECYCLE_INVALID_PHASE);
    (void)ChatpadFilterLifecycleCompleteD0Exit(&state, generation);
    ExpectResult("release after D0 exit result", ChatpadFilterLifecycleReleaseHardware(&state), CHATPAD_FILTER_LIFECYCLE_OK);
    ExpectPhase("release after D0 exit phase", state.Phase, CHATPAD_FILTER_LIFECYCLE_PHASE_RELEASED);
    ExpectResult("enter D0 after release rejected", ChatpadFilterLifecycleEnterD0(&state, &generation), CHATPAD_FILTER_LIFECYCLE_INVALID_PHASE);
}

static void
TestOverflowAndStructuralRules(void)
{
    ChatpadFilterLifecycleState state;
    ChatpadFilterLifecycleSnapshot snapshot;
    uint64_t generation = 0u;

    (void)ChatpadFilterLifecycleInitialize(&state);
    (void)ChatpadFilterLifecycleMarkDeviceCreated(&state);
    (void)ChatpadFilterLifecyclePrepareHardware(&state);
    state.NextGeneration = CHATPAD_FILTER_UINT64_MAX;
    ExpectResult("generation exhaustion rejected", ChatpadFilterLifecycleEnterD0(&state, &generation), CHATPAD_FILTER_LIFECYCLE_GENERATION_EXHAUSTED);
    ExpectU64("generation exhaustion clears output", generation, CHATPAD_FILTER_LIFECYCLE_INVALID_GENERATION);
    ExpectPhase("generation exhaustion keeps prepared", state.Phase, CHATPAD_FILTER_LIFECYCLE_PHASE_PREPARED);

    state.NextGeneration = 1u;
    ExpectResult("enter D0 after exhaustion reset", ChatpadFilterLifecycleEnterD0(&state, &generation), CHATPAD_FILTER_LIFECYCLE_OK);
    state.OutstandingOperationCount = CHATPAD_FILTER_UINT32_MAX;
    ExpectResult("outstanding overflow rejected", ChatpadFilterLifecycleTryAcquireOperation(&state, generation), CHATPAD_FILTER_LIFECYCLE_OUTSTANDING_OVERFLOW);
    ExpectU32("outstanding overflow preserves max", state.OutstandingOperationCount, CHATPAD_FILTER_UINT32_MAX);
    state.OutstandingOperationCount = 0u;

    ExpectResult("snapshot final active result", ChatpadFilterLifecycleGetSnapshot(&state, &snapshot), CHATPAD_FILTER_LIFECYCLE_OK);
    ExpectPhase("snapshot final active phase", snapshot.Phase, CHATPAD_FILTER_LIFECYCLE_PHASE_D0_ACTIVE);
    ExpectU64("snapshot final current generation", snapshot.CurrentGeneration, generation);
    ExpectU32("snapshot final outstanding", snapshot.OutstandingOperationCount, 0u);
    ExpectU8("snapshot final admission", snapshot.OperationAdmissionOpen, 1u);

    ExpectU32("state signature is fixed", CHATPAD_FILTER_LIFECYCLE_SIGNATURE, 0x464C4350u);
    ExpectU32("state version is one", CHATPAD_FILTER_LIFECYCLE_VERSION, 1u);
    RecordAssertion("state stores no caller pointer-sized field", sizeof(ChatpadFilterLifecycleState) <= 40u);
    RecordAssertion("snapshot stores no caller pointer-sized field", sizeof(ChatpadFilterLifecycleSnapshot) <= 32u);
}

int
main(void)
{
    TestInitialAndCreatedPhases();
    TestPrepareAndD0Generations();
    TestAdmissionAndRundown();
    TestSecondGenerationAndStaleProtection();
    TestReleaseHardwareAndTerminalRules();
    TestOverflowAndStructuralRules();

    (void)printf("Total: %u\n", g_totalAssertions);
    (void)printf("Passed: %u\n", g_totalAssertions - g_failedAssertions);
    (void)printf("Failed: %u\n", g_failedAssertions);

    return g_failedAssertions == 0u ? 0 : 1;
}

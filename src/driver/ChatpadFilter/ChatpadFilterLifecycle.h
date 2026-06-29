#ifndef CHATPAD_FILTER_LIFECYCLE_H
#define CHATPAD_FILTER_LIFECYCLE_H

#if defined(_MSC_VER) && defined(_KERNEL_MODE)
typedef unsigned __int8 uint8_t;
typedef unsigned __int32 uint32_t;
typedef unsigned __int64 uint64_t;
#define CHATPAD_FILTER_UINT32_MAX ((uint32_t)0xffffffffui32)
#define CHATPAD_FILTER_UINT64_MAX ((uint64_t)0xffffffffffffffffui64)
#else
#include <stdint.h>
#define CHATPAD_FILTER_UINT32_MAX UINT32_MAX
#define CHATPAD_FILTER_UINT64_MAX UINT64_MAX
#endif

#ifdef __cplusplus
extern "C" {
#endif

#define CHATPAD_FILTER_LIFECYCLE_SIGNATURE ((uint32_t)0x464C4350u)
#define CHATPAD_FILTER_LIFECYCLE_VERSION ((uint32_t)1u)
#define CHATPAD_FILTER_LIFECYCLE_INVALID_GENERATION ((uint64_t)0u)

typedef enum ChatpadFilterLifecyclePhase {
    CHATPAD_FILTER_LIFECYCLE_PHASE_UNSET = 0,
    CHATPAD_FILTER_LIFECYCLE_PHASE_CREATED,
    CHATPAD_FILTER_LIFECYCLE_PHASE_PREPARED,
    CHATPAD_FILTER_LIFECYCLE_PHASE_D0_ACTIVE,
    CHATPAD_FILTER_LIFECYCLE_PHASE_RUNDOWN_REQUESTED,
    CHATPAD_FILTER_LIFECYCLE_PHASE_D0_STOPPED,
    CHATPAD_FILTER_LIFECYCLE_PHASE_RELEASED
} ChatpadFilterLifecyclePhase;

typedef enum ChatpadFilterLifecycleResult {
    CHATPAD_FILTER_LIFECYCLE_OK = 0,
    CHATPAD_FILTER_LIFECYCLE_NULL_STATE,
    CHATPAD_FILTER_LIFECYCLE_NULL_OUTPUT,
    CHATPAD_FILTER_LIFECYCLE_NOT_MARKED,
    CHATPAD_FILTER_LIFECYCLE_INVALID_PHASE,
    CHATPAD_FILTER_LIFECYCLE_INVALID_GENERATION_ID,
    CHATPAD_FILTER_LIFECYCLE_GENERATION_EXHAUSTED,
    CHATPAD_FILTER_LIFECYCLE_ADMISSION_CLOSED,
    CHATPAD_FILTER_LIFECYCLE_OUTSTANDING_OVERFLOW,
    CHATPAD_FILTER_LIFECYCLE_NO_OUTSTANDING_OPERATION,
    CHATPAD_FILTER_LIFECYCLE_STALE_GENERATION,
    CHATPAD_FILTER_LIFECYCLE_RUNDOWN_INCOMPLETE
} ChatpadFilterLifecycleResult;

typedef struct ChatpadFilterLifecycleState {
    uint32_t Signature;
    uint32_t Version;
    ChatpadFilterLifecyclePhase Phase;
    uint64_t CurrentGeneration;
    uint64_t NextGeneration;
    uint32_t OutstandingOperationCount;
    uint8_t OperationAdmissionOpen;
} ChatpadFilterLifecycleState;

typedef struct ChatpadFilterLifecycleSnapshot {
    ChatpadFilterLifecyclePhase Phase;
    uint64_t CurrentGeneration;
    uint64_t NextGeneration;
    uint32_t OutstandingOperationCount;
    uint8_t OperationAdmissionOpen;
} ChatpadFilterLifecycleSnapshot;

ChatpadFilterLifecycleResult ChatpadFilterLifecycleInitialize(
    ChatpadFilterLifecycleState *state);

ChatpadFilterLifecycleResult ChatpadFilterLifecycleMarkDeviceCreated(
    ChatpadFilterLifecycleState *state);

ChatpadFilterLifecycleResult ChatpadFilterLifecyclePrepareHardware(
    ChatpadFilterLifecycleState *state);

ChatpadFilterLifecycleResult ChatpadFilterLifecycleEnterD0(
    ChatpadFilterLifecycleState *state,
    uint64_t *generation);

ChatpadFilterLifecycleResult ChatpadFilterLifecycleTryAcquireOperation(
    ChatpadFilterLifecycleState *state,
    uint64_t generation);

ChatpadFilterLifecycleResult ChatpadFilterLifecycleReleaseOperation(
    ChatpadFilterLifecycleState *state,
    uint64_t generation);

ChatpadFilterLifecycleResult ChatpadFilterLifecycleBeginD0Rundown(
    ChatpadFilterLifecycleState *state,
    uint64_t generation);

ChatpadFilterLifecycleResult ChatpadFilterLifecycleCompleteD0Exit(
    ChatpadFilterLifecycleState *state,
    uint64_t generation);

ChatpadFilterLifecycleResult ChatpadFilterLifecycleReleaseHardware(
    ChatpadFilterLifecycleState *state);

ChatpadFilterLifecycleResult ChatpadFilterLifecycleGetSnapshot(
    const ChatpadFilterLifecycleState *state,
    ChatpadFilterLifecycleSnapshot *snapshot);

#ifdef __cplusplus
}
#endif

#endif

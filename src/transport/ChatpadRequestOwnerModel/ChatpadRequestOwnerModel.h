#ifndef CHATPAD_REQUEST_OWNER_MODEL_H
#define CHATPAD_REQUEST_OWNER_MODEL_H

#include "ChatpadTransportAdapter.h"

#if defined(_MSC_VER) && defined(_KERNEL_MODE) && !defined(UINT32_MAX)
#define UINT32_MAX ((uint32_t)0xffffffffu)
#endif

#ifdef __cplusplus
extern "C" {
#endif

#define CHATPAD_REQUEST_OWNER_SIGNATURE ((uint32_t)0x524F4350u)
#define CHATPAD_REQUEST_OWNER_VERSION ((uint32_t)1u)
#define CHATPAD_REQUEST_OWNER_INVALID_GENERATION CHATPAD_TRANSPORT_INVALID_GENERATION
#define CHATPAD_REQUEST_OWNER_INVALID_OPERATION_SEQUENCE CHATPAD_TRANSPORT_INVALID_OPERATION_SEQUENCE
#define CHATPAD_REQUEST_OWNER_INVALID_STEP ((uint32_t)0xffffffffu)

typedef enum ChatpadRequestOwnerState {
    CHATPAD_REQUEST_OWNER_STATE_UNAVAILABLE = 0,
    CHATPAD_REQUEST_OWNER_STATE_IDLE,
    CHATPAD_REQUEST_OWNER_STATE_PREPARING,
    CHATPAD_REQUEST_OWNER_STATE_READY,
    CHATPAD_REQUEST_OWNER_STATE_FORMATTED,
    CHATPAD_REQUEST_OWNER_STATE_SUBMITTING,
    CHATPAD_REQUEST_OWNER_STATE_IN_FLIGHT,
    CHATPAD_REQUEST_OWNER_STATE_CANCEL_CALLING,
    CHATPAD_REQUEST_OWNER_STATE_CANCEL_PENDING,
    CHATPAD_REQUEST_OWNER_STATE_COMPLETING,
    CHATPAD_REQUEST_OWNER_STATE_AWAITING_CALL_RETURN,
    CHATPAD_REQUEST_OWNER_STATE_RETIRING,
    CHATPAD_REQUEST_OWNER_STATE_DRAINING,
    CHATPAD_REQUEST_OWNER_STATE_FAULTED,
    CHATPAD_REQUEST_OWNER_STATE_COUNT
} ChatpadRequestOwnerState;

typedef enum ChatpadRequestOwnerEventType {
    CHATPAD_REQUEST_OWNER_EVENT_MAKE_AVAILABLE = 0,
    CHATPAD_REQUEST_OWNER_EVENT_MAKE_UNAVAILABLE,
    CHATPAD_REQUEST_OWNER_EVENT_REQUEST_ADMISSION,
    CHATPAD_REQUEST_OWNER_EVENT_BEGIN_OPERATION,
    CHATPAD_REQUEST_OWNER_EVENT_PREPARATION_SUCCEEDED,
    CHATPAD_REQUEST_OWNER_EVENT_PREPARATION_FAILED,
    CHATPAD_REQUEST_OWNER_EVENT_FORMATTING_SUCCEEDED,
    CHATPAD_REQUEST_OWNER_EVENT_FORMATTING_FAILED,
    CHATPAD_REQUEST_OWNER_EVENT_SEND_CALL_BEGINS,
    CHATPAD_REQUEST_OWNER_EVENT_SEND_RETURNED_ACCEPTED,
    CHATPAD_REQUEST_OWNER_EVENT_SEND_RETURNED_FALSE,
    CHATPAD_REQUEST_OWNER_EVENT_REQUEST_CANCELLATION,
    CHATPAD_REQUEST_OWNER_EVENT_CANCEL_CALL_BEGINS,
    CHATPAD_REQUEST_OWNER_EVENT_CANCEL_CALL_RETURNED,
    CHATPAD_REQUEST_OWNER_EVENT_COMPLETION_BEGINS,
    CHATPAD_REQUEST_OWNER_EVENT_COMPLETION_FINISHES,
    CHATPAD_REQUEST_OWNER_EVENT_RETIREMENT_COMPLETES,
    CHATPAD_REQUEST_OWNER_EVENT_BEGIN_DRAIN,
    CHATPAD_REQUEST_OWNER_EVENT_FAULT,
    CHATPAD_REQUEST_OWNER_EVENT_COUNT
} ChatpadRequestOwnerEventType;

typedef enum ChatpadRequestOwnerCompletionClass {
    CHATPAD_REQUEST_OWNER_COMPLETION_NONE = 0,
    CHATPAD_REQUEST_OWNER_COMPLETION_SUCCESS,
    CHATPAD_REQUEST_OWNER_COMPLETION_REQUEST_FAILED,
    CHATPAD_REQUEST_OWNER_COMPLETION_CANCELLED,
    CHATPAD_REQUEST_OWNER_COMPLETION_STALE_GENERATION,
    CHATPAD_REQUEST_OWNER_COMPLETION_INVALID_TRANSFER_LENGTH,
    CHATPAD_REQUEST_OWNER_COMPLETION_OWNER_FAULT
} ChatpadRequestOwnerCompletionClass;

typedef enum ChatpadRequestOwnerRetirementOwner {
    CHATPAD_REQUEST_OWNER_RETIREMENT_NONE = 0,
    CHATPAD_REQUEST_OWNER_RETIREMENT_INITIATOR,
    CHATPAD_REQUEST_OWNER_RETIREMENT_COMPLETION
} ChatpadRequestOwnerRetirementOwner;

typedef enum ChatpadRequestOwnerResult {
    CHATPAD_REQUEST_OWNER_OK = 0,
    CHATPAD_REQUEST_OWNER_ACCEPTED_IDEMPOTENTLY,
    CHATPAD_REQUEST_OWNER_TERMINAL_PENDING_EXTERNAL_CALL_RETURN,
    CHATPAD_REQUEST_OWNER_INVALID_ARGUMENT,
    CHATPAD_REQUEST_OWNER_INVALID_STATE,
    CHATPAD_REQUEST_OWNER_GENERATION_MISMATCH,
    CHATPAD_REQUEST_OWNER_OPERATION_MISMATCH,
    CHATPAD_REQUEST_OWNER_ALREADY_DRAINING,
    CHATPAD_REQUEST_OWNER_ALREADY_CANCELLED,
    CHATPAD_REQUEST_OWNER_DUPLICATE_COMPLETION,
    CHATPAD_REQUEST_OWNER_NO_LIFECYCLE_OBLIGATION,
    CHATPAD_REQUEST_OWNER_SEND_CALL_ALREADY_PINNED,
    CHATPAD_REQUEST_OWNER_CANCEL_CALL_ALREADY_PINNED,
    CHATPAD_REQUEST_OWNER_OWNER_FAULTED,
    CHATPAD_REQUEST_OWNER_TRANSITION_FAULTED,
    CHATPAD_REQUEST_OWNER_INVARIANT_FAILED
} ChatpadRequestOwnerResult;

typedef enum ChatpadRequestOwnerTransitionClass {
    CHATPAD_REQUEST_OWNER_TRANSITION_ACCEPTED = 0,
    CHATPAD_REQUEST_OWNER_TRANSITION_IDEMPOTENT,
    CHATPAD_REQUEST_OWNER_TRANSITION_REJECTED,
    CHATPAD_REQUEST_OWNER_TRANSITION_TO_FAULTED
} ChatpadRequestOwnerTransitionClass;

typedef enum ChatpadRequestOwnerInvariantResult {
    CHATPAD_REQUEST_OWNER_INVARIANT_OK = 0,
    CHATPAD_REQUEST_OWNER_INVARIANT_NULL_OWNER,
    CHATPAD_REQUEST_OWNER_INVARIANT_INVALID_SIGNATURE,
    CHATPAD_REQUEST_OWNER_INVARIANT_INVALID_STATE,
    CHATPAD_REQUEST_OWNER_INVARIANT_AVAILABILITY_MISMATCH,
    CHATPAD_REQUEST_OWNER_INVARIANT_IDLE_OWNS_OPERATION,
    CHATPAD_REQUEST_OWNER_INVARIANT_ACTIVE_MISSING_IDENTITY,
    CHATPAD_REQUEST_OWNER_INVARIANT_ACTIVE_MISSING_GENERATION,
    CHATPAD_REQUEST_OWNER_INVARIANT_OBLIGATION_WITHOUT_OPERATION,
    CHATPAD_REQUEST_OWNER_INVARIANT_RELEASE_DUPLICATION,
    CHATPAD_REQUEST_OWNER_INVARIANT_REUSABLE_WITH_PIN,
    CHATPAD_REQUEST_OWNER_INVARIANT_REUSABLE_WITH_OBLIGATION,
    CHATPAD_REQUEST_OWNER_INVARIANT_REUSABLE_WITH_OPERATION,
    CHATPAD_REQUEST_OWNER_INVARIANT_ADVANCE_WITHOUT_SUCCESS,
    CHATPAD_REQUEST_OWNER_INVARIANT_SUBMITTING_WITHOUT_SEND_PIN,
    CHATPAD_REQUEST_OWNER_INVARIANT_CANCEL_CALLING_WITHOUT_PIN,
    CHATPAD_REQUEST_OWNER_INVARIANT_COMPLETING_WITHOUT_COMPLETION,
    CHATPAD_REQUEST_OWNER_INVARIANT_AWAITING_WITHOUT_PIN,
    CHATPAD_REQUEST_OWNER_INVARIANT_RETIRING_NOT_TERMINAL,
    CHATPAD_REQUEST_OWNER_INVARIANT_RETIREMENT_OWNER_MISMATCH
} ChatpadRequestOwnerInvariantResult;

typedef struct ChatpadRequestOwnerEffects {
    uint8_t AcquireLifecycleAdmission;
    uint8_t ReleaseLifecycleAdmission;
    uint8_t CallerMayPrepare;
    uint8_t CallerMayFormat;
    uint8_t CallerMayBeginSendCall;
    uint8_t CallerMayBeginCancelCall;
    uint8_t CompletionOwnsTerminalRetirement;
    uint8_t InitiatorOwnsTerminalRetirement;
    uint8_t SequenceMayAdvance;
    uint8_t SequenceMustAbort;
    uint8_t OwnerMayBeReused;
    uint8_t WaitForSendCallReturn;
    uint8_t WaitForCancelCallReturn;
    uint8_t StaleCompletionConsumed;
    uint8_t RecordDiagnosticFault;
} ChatpadRequestOwnerEffects;

typedef struct ChatpadRequestOwnerEvent {
    ChatpadRequestOwnerEventType Type;
    uint64_t CurrentLifecycleGeneration;
    ChatpadTransportOperationToken OperationToken;
    uint32_t ActivationStepIndex;
    ChatpadRequestOwnerCompletionClass CompletionClass;
} ChatpadRequestOwnerEvent;

typedef struct ChatpadActivationRequestOwner {
    uint32_t Signature;
    uint32_t Version;
    ChatpadRequestOwnerState State;
    uint64_t LifecycleGeneration;
    ChatpadTransportOperationToken OperationToken;
    uint32_t ActivationStepIndex;
    uint32_t TransitionCount;
    ChatpadRequestOwnerCompletionClass TerminalClass;
    ChatpadRequestOwnerRetirementOwner RetirementOwner;
    uint8_t Available;
    uint8_t DrainingRequested;
    uint8_t OperationActive;
    uint8_t LifecycleObligationHeld;
    uint8_t SubmissionPublished;
    uint8_t SendAccepted;
    uint8_t CompletionObserved;
    uint8_t CancellationRequested;
    uint8_t CancellationCallPublished;
    uint8_t SendCallPinned;
    uint8_t CancelCallPinned;
    uint8_t TerminalProcessed;
    uint8_t SequenceAdvanceEligible;
    uint8_t ReuseEligible;
    uint8_t ReleaseEffectEmitted;
    uint8_t StaleCompletionObserved;
} ChatpadActivationRequestOwner;

typedef struct ChatpadRequestOwnerSnapshot {
    ChatpadRequestOwnerState State;
    uint64_t LifecycleGeneration;
    ChatpadTransportOperationToken OperationToken;
    uint32_t ActivationStepIndex;
    uint32_t TransitionCount;
    ChatpadRequestOwnerCompletionClass TerminalClass;
    ChatpadRequestOwnerRetirementOwner RetirementOwner;
    uint8_t Available;
    uint8_t DrainingRequested;
    uint8_t OperationActive;
    uint8_t LifecycleObligationHeld;
    uint8_t SubmissionPublished;
    uint8_t SendAccepted;
    uint8_t CompletionObserved;
    uint8_t CancellationRequested;
    uint8_t CancellationCallPublished;
    uint8_t SendCallPinned;
    uint8_t CancelCallPinned;
    uint8_t TerminalProcessed;
    uint8_t SequenceAdvanceEligible;
    uint8_t ReuseEligible;
    uint8_t ReleaseEffectEmitted;
    uint8_t StaleCompletionObserved;
} ChatpadRequestOwnerSnapshot;

void ChatpadRequestOwnerEventInitialize(
    ChatpadRequestOwnerEvent *event,
    ChatpadRequestOwnerEventType type);

ChatpadRequestOwnerResult ChatpadRequestOwnerInitialize(
    ChatpadActivationRequestOwner *owner);

ChatpadRequestOwnerResult ChatpadRequestOwnerDispatch(
    ChatpadActivationRequestOwner *owner,
    const ChatpadRequestOwnerEvent *event,
    ChatpadRequestOwnerEffects *effects);

ChatpadRequestOwnerResult ChatpadRequestOwnerGetSnapshot(
    const ChatpadActivationRequestOwner *owner,
    ChatpadRequestOwnerSnapshot *snapshot);

ChatpadRequestOwnerInvariantResult ChatpadRequestOwnerValidateInvariant(
    const ChatpadActivationRequestOwner *owner);

ChatpadRequestOwnerTransitionClass ChatpadRequestOwnerGetExpectedTransitionClass(
    ChatpadRequestOwnerState state,
    ChatpadRequestOwnerEventType eventType);

ChatpadRequestOwnerTransitionClass ChatpadRequestOwnerClassifyResult(
    ChatpadRequestOwnerResult result);

#ifdef __cplusplus
}
#endif

#endif

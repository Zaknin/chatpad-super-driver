#ifndef CHATPAD_ACTIVATION_SEQUENCE_FIXTURES_H
#define CHATPAD_ACTIVATION_SEQUENCE_FIXTURES_H

#include <stddef.h>
#include <stdint.h>

#include "ChatpadActivationSequence.h"

/*
 * Timing metadata reconstructed from docs/CHATPAD-INIT-STATUS-EVIDENCE.md
 * section 9. The legacy executable path slept after each SendControlRequest
 * call. These values are declarative metadata only and are not timers,
 * timeouts, retry policy, readiness deadlines, or device requirements.
 */

typedef struct ChatpadActivationSequenceTimingFixture {
    uint16_t DelayBeforeMilliseconds;
    uint16_t DelayAfterMilliseconds;
} ChatpadActivationSequenceTimingFixture;

static const ChatpadActivationSequenceTimingFixture ConfirmedActivationSequenceTiming[CHATPAD_ACTIVATION_SEQUENCE_STEP_COUNT] = {
    { 0u, 12u },
    { 0u, 12u },
    { 0u, 12u },
    { 0u, 12u },
    { 0u, 12u },
    { 0u, 12u }
};

#endif

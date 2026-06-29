#include <stdint.h>
#include <stdio.h>

#include "ChatpadKeyboardParser.h"
#include "ChatpadKeyboardFixtures.h"

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

static void AssertResult(
    const char *name,
    ChatpadParseResult expected,
    ChatpadParseResult actual)
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

static void PoisonPacket(ChatpadKeyboardPacket *packet)
{
    packet->RawType = 0xA5;
    packet->RawModifiers = 0xA5;
    packet->RawKey0 = 0xA5;
    packet->RawKey1 = 0xA5;
    packet->RawByte4 = 0xA5;
}

static void AssertCleared(const char *name, const ChatpadKeyboardPacket *packet)
{
    AssertTrue(
        name,
        packet->RawType == 0 &&
        packet->RawModifiers == 0 &&
        packet->RawKey0 == 0 &&
        packet->RawKey1 == 0 &&
        packet->RawByte4 == 0);
}

static void AssertPacket(
    const char *typeName,
    const char *modifierName,
    const char *key0Name,
    const char *key1Name,
    const char *byte4Name,
    const ChatpadKeyboardPacket *packet,
    const uint8_t expected[5])
{
    AssertTrue(typeName, packet->RawType == expected[0]);
    AssertTrue(modifierName, packet->RawModifiers == expected[1]);
    AssertTrue(key0Name, packet->RawKey0 == expected[2]);
    AssertTrue(key1Name, packet->RawKey1 == expected[3]);
    AssertTrue(byte4Name, packet->RawByte4 == expected[4]);
}

static void CheckTruncatedLength(
    const char *resultName,
    const char *clearName,
    size_t length)
{
    ChatpadKeyboardPacket output;
    ChatpadParseResult result;

    PoisonPacket(&output);
    result = ChatpadParseKeyboardPacket(ValidNoKeys, length, &output);
    AssertResult(resultName, CHATPAD_PARSE_TRUNCATED, result);
    AssertCleared(clearName, &output);
}

static void TestArgumentAndLengthValidation(void)
{
    ChatpadKeyboardPacket output;
    ChatpadParseResult result;

    result = ChatpadParseKeyboardPacket(
        ValidNoKeys,
        CHATPAD_KEYBOARD_PACKET_LENGTH,
        NULL);
    AssertResult("null output", CHATPAD_PARSE_NULL_OUTPUT, result);

    PoisonPacket(&output);
    result = ChatpadParseKeyboardPacket(NULL, CHATPAD_KEYBOARD_PACKET_LENGTH, &output);
    AssertResult("null input with nonzero length", CHATPAD_PARSE_NULL_INPUT, result);
    AssertCleared("null input clears output", &output);

    PoisonPacket(&output);
    result = ChatpadParseKeyboardPacket(NULL, 0, &output);
    AssertResult("zero length is truncated", CHATPAD_PARSE_TRUNCATED, result);
    AssertCleared("zero length clears output", &output);

    CheckTruncatedLength("truncated length 1", "length 1 clears output", 1);
    CheckTruncatedLength("truncated length 2", "length 2 clears output", 2);
    CheckTruncatedLength("truncated length 3", "length 3 clears output", 3);
    CheckTruncatedLength("truncated length 4", "length 4 clears output", 4);

    PoisonPacket(&output);
    result = ChatpadParseKeyboardPacket(OversizedPacket, sizeof(OversizedPacket), &output);
    AssertResult("oversized length 6", CHATPAD_PARSE_OVERSIZED, result);
    AssertCleared("oversized length 6 clears output", &output);

    PoisonPacket(&output);
    result = ChatpadParseKeyboardPacket(
        LargerOversizedPacket,
        sizeof(LargerOversizedPacket),
        &output);
    AssertResult("larger oversized length", CHATPAD_PARSE_OVERSIZED, result);
    AssertCleared("larger oversized clears output", &output);
}

static void TestValidPackets(void)
{
    ChatpadKeyboardPacket output;
    ChatpadParseResult result;

    PoisonPacket(&output);
    result = ChatpadParseKeyboardPacket(ValidNoKeys, sizeof(ValidNoKeys), &output);
    AssertResult("valid exact length", CHATPAD_PARSE_OK, result);
    AssertPacket(
        "valid neutral raw type",
        "valid neutral raw modifiers",
        "valid neutral raw key 0",
        "valid neutral raw key 1",
        "valid neutral raw byte 4",
        &output,
        ValidNoKeys);

    PoisonPacket(&output);
    result = ChatpadParseKeyboardPacket(ValidRawBoundary, sizeof(ValidRawBoundary), &output);
    AssertResult("valid raw boundary", CHATPAD_PARSE_OK, result);
    AssertPacket(
        "boundary raw type",
        "boundary raw modifiers",
        "boundary raw key 0",
        "boundary raw key 1",
        "boundary raw byte 4",
        &output,
        ValidRawBoundary);

    PoisonPacket(&output);
    result = ChatpadParseKeyboardPacket(
        ValidRawKey0Nonzero,
        sizeof(ValidRawKey0Nonzero),
        &output);
    AssertResult("supported Phase 1 type", CHATPAD_PARSE_OK, result);
    AssertTrue("supported type preserved", output.RawType == 0x00);
    AssertTrue("raw key 0 preserved", output.RawKey0 == 0x37);
}

static void TestTypeAndModifierPolicy(void)
{
    ChatpadKeyboardPacket output;
    ChatpadParseResult result;

    PoisonPacket(&output);
    result = ChatpadParseKeyboardPacket(
        UnsupportedTypeF0,
        sizeof(UnsupportedTypeF0),
        &output);
    AssertResult("unsupported type F0", CHATPAD_PARSE_UNSUPPORTED_TYPE, result);
    AssertCleared("unsupported type F0 clears output", &output);

    PoisonPacket(&output);
    result = ChatpadParseKeyboardPacket(
        UnsupportedTypeOther,
        sizeof(UnsupportedTypeOther),
        &output);
    AssertResult("other unsupported type", CHATPAD_PARSE_UNSUPPORTED_TYPE, result);
    AssertCleared("other unsupported type clears output", &output);

    PoisonPacket(&output);
    result = ChatpadParseKeyboardPacket(
        ValidRawModifierBit0,
        sizeof(ValidRawModifierBit0),
        &output);
    AssertResult("modifier policy accepts raw bit 0", CHATPAD_PARSE_OK, result);
    AssertTrue("raw modifier bit 0 preserved", output.RawModifiers == 0x01);

    PoisonPacket(&output);
    result = ChatpadParseKeyboardPacket(
        ValidRawModifierBoundary,
        sizeof(ValidRawModifierBoundary),
        &output);
    AssertResult("modifier policy accepts 0F", CHATPAD_PARSE_OK, result);
    AssertTrue("raw modifier 0F preserved", output.RawModifiers == 0x0F);

    PoisonPacket(&output);
    result = ChatpadParseKeyboardPacket(
        PolicyRejectedModifierBit4,
        sizeof(PolicyRejectedModifierBit4),
        &output);
    AssertResult(
        "modifier policy rejects bit 4",
        CHATPAD_PARSE_POLICY_REJECTED_MODIFIER,
        result);
    AssertCleared("modifier bit 4 rejection clears output", &output);

    PoisonPacket(&output);
    result = ChatpadParseKeyboardPacket(
        PolicyRejectedModifierBoundary,
        sizeof(PolicyRejectedModifierBoundary),
        &output);
    AssertResult(
        "modifier policy rejects upper boundary",
        CHATPAD_PARSE_POLICY_REJECTED_MODIFIER,
        result);
    AssertCleared("modifier upper boundary clears output", &output);
}

static void TestRawByte4(void)
{
    ChatpadKeyboardPacket output;
    ChatpadParseResult result;

    result = ChatpadParseKeyboardPacket(
        ValidRawByte4Nonzero,
        sizeof(ValidRawByte4Nonzero),
        &output);
    AssertResult("raw byte 4 nonzero packet", CHATPAD_PARSE_OK, result);
    AssertTrue("raw byte 4 nonzero preserved", output.RawByte4 == 0x01);

    result = ChatpadParseKeyboardPacket(
        ValidRawByte4Boundary,
        sizeof(ValidRawByte4Boundary),
        &output);
    AssertResult("raw byte 4 boundary packet", CHATPAD_PARSE_OK, result);
    AssertTrue("raw byte 4 boundary preserved", output.RawByte4 == 0xFF);
}

static void AssertRepeatedValidParse(
    const char *resultName,
    const char *typeName,
    const char *modifierName,
    const char *key0Name,
    const char *key1Name,
    const char *byte4Name)
{
    ChatpadKeyboardPacket output;
    ChatpadParseResult result;

    PoisonPacket(&output);
    result = ChatpadParseKeyboardPacket(ValidNoKeys, sizeof(ValidNoKeys), &output);
    AssertResult(resultName, CHATPAD_PARSE_OK, result);
    AssertPacket(
        typeName,
        modifierName,
        key0Name,
        key1Name,
        byte4Name,
        &output,
        ValidNoKeys);
}

static void TestRepeatabilityAndSequence(void)
{
    ChatpadKeyboardPacket output;
    ChatpadParseResult result;

    AssertRepeatedValidParse(
        "repeated valid parse 1 result",
        "repeated valid parse 1 type",
        "repeated valid parse 1 modifiers",
        "repeated valid parse 1 key 0",
        "repeated valid parse 1 key 1",
        "repeated valid parse 1 byte 4");
    AssertRepeatedValidParse(
        "repeated valid parse 2 result",
        "repeated valid parse 2 type",
        "repeated valid parse 2 modifiers",
        "repeated valid parse 2 key 0",
        "repeated valid parse 2 key 1",
        "repeated valid parse 2 byte 4");
    AssertRepeatedValidParse(
        "repeated valid parse 3 result",
        "repeated valid parse 3 type",
        "repeated valid parse 3 modifiers",
        "repeated valid parse 3 key 0",
        "repeated valid parse 3 key 1",
        "repeated valid parse 3 byte 4");

    result = ChatpadParseKeyboardPacket(
        ValidRawModifierBit0,
        sizeof(ValidRawModifierBit0),
        &output);
    AssertResult("sequential first result", CHATPAD_PARSE_OK, result);
    AssertPacket(
        "sequential first type",
        "sequential first modifiers",
        "sequential first key 0",
        "sequential first key 1",
        "sequential first byte 4",
        &output,
        ValidRawModifierBit0);

    result = ChatpadParseKeyboardPacket(
        ValidTwoRawKeys,
        sizeof(ValidTwoRawKeys),
        &output);
    AssertResult("sequential second result", CHATPAD_PARSE_OK, result);
    AssertPacket(
        "sequential second type",
        "sequential second modifiers",
        "sequential second key 0",
        "sequential second key 1",
        "sequential second byte 4",
        &output,
        ValidTwoRawKeys);
}

typedef struct GuardedPacket {
    uint32_t Before;
    ChatpadKeyboardPacket Packet;
    uint32_t After;
} GuardedPacket;

static void TestSentinels(void)
{
    GuardedPacket guarded;
    ChatpadParseResult result;

    guarded.Before = UINT32_C(0x11223344);
    guarded.After = UINT32_C(0x55667788);
    PoisonPacket(&guarded.Packet);

    result = ChatpadParseKeyboardPacket(
        ValidRawBoundary,
        sizeof(ValidRawBoundary),
        &guarded.Packet);
    AssertResult("sentinel valid parse result", CHATPAD_PARSE_OK, result);
    AssertTrue("sentinel before unchanged after valid parse", guarded.Before == UINT32_C(0x11223344));
    AssertTrue("sentinel after unchanged after valid parse", guarded.After == UINT32_C(0x55667788));

    PoisonPacket(&guarded.Packet);
    result = ChatpadParseKeyboardPacket(
        PolicyRejectedModifierBit4,
        sizeof(PolicyRejectedModifierBit4),
        &guarded.Packet);
    AssertResult(
        "sentinel failure parse result",
        CHATPAD_PARSE_POLICY_REJECTED_MODIFIER,
        result);
    AssertTrue("sentinel before unchanged after failure", guarded.Before == UINT32_C(0x11223344));
    AssertTrue("sentinel after unchanged after failure", guarded.After == UINT32_C(0x55667788));
    AssertCleared("sentinel failure clears packet only", &guarded.Packet);
}

int main(void)
{
    TestArgumentAndLengthValidation();
    TestValidPackets();
    TestTypeAndModifierPolicy();
    TestRawByte4();
    TestRepeatabilityAndSequence();
    TestSentinels();

    printf("Total: %u\n", AssertionsTotal);
    printf("Passed: %u\n", AssertionsPassed);
    printf("Failed: %u\n", AssertionsFailed);

    return AssertionsFailed == 0 ? 0 : 1;
}

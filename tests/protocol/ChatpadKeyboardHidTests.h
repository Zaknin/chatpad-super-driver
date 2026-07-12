#ifndef CHATPAD_KEYBOARD_HID_TESTS_H
#define CHATPAD_KEYBOARD_HID_TESTS_H

typedef struct ChatpadKeyboardHidTestSummary {
    unsigned int Total;
    unsigned int Passed;
    unsigned int Failed;
} ChatpadKeyboardHidTestSummary;

ChatpadKeyboardHidTestSummary RunChatpadKeyboardHidTests(void);

#endif

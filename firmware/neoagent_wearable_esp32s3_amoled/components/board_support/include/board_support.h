#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "esp_err.h"
#include "mascot.h"
#include "neoagent_wearable_types.h"

typedef struct {
    bool display_ready;
    bool touch_ready;
    bool audio_ready;
} board_support_t;

typedef struct {
    uint32_t sample_rate_hz;
    uint8_t channels;
    uint8_t bits_per_sample;
} board_audio_format_t;

typedef struct {
    bool tapped;
    bool pressed;
    bool released;
    bool swipe_up;
    bool swipe_down;
    bool swipe_left;
    bool swipe_right;
    uint16_t x;
    uint16_t y;
} board_touch_event_t;

typedef struct {
    bool power_pressed;
    bool power_released;
    bool power_short_press;
    bool power_long_press;
    bool boot_pressed;
    bool boot_released;
    bool boot_short_press;
    bool boot_long_press;
} board_button_event_t;

// What a touch landed on. Screens tag their controls, so hit testing always
// matches what is drawn.
typedef enum {
    BOARD_TARGET_NONE = 0,
    BOARD_TARGET_MASCOT,
    BOARD_TARGET_CALL,
    BOARD_TARGET_END_CALL,
    BOARD_TARGET_TALK,
    BOARD_TARGET_OPEN_SETTINGS,
    BOARD_TARGET_BACK,
    BOARD_TARGET_SETTINGS_NETWORK,
    BOARD_TARGET_SETTINGS_UPDATE,
    BOARD_TARGET_SETTINGS_DEVICE,
    BOARD_TARGET_SETTINGS_FORGET,
    BOARD_TARGET_CHANNEL_STABLE,
    BOARD_TARGET_CHANNEL_BETA,
    BOARD_TARGET_UPDATE_NOW,
    BOARD_TARGET_SETUP_MODE,
    BOARD_TARGET_FORGET_CONFIRM,
} board_target_t;

typedef enum {
    BOARD_CALL_IDLE = 0,
    BOARD_CALL_DIALING,
    BOARD_CALL_ACTIVE,
} board_call_phase_t;

// The home screen, laid out like the app's phone call: the mascot and who you
// are talking to, the call state, live captions and the call controls.
typedef struct {
    mascot_mood_t mood;
    board_call_phase_t phase;
    bool hands_free;
    bool capturing;
    bool speaking;
    const char *name;
    const char *status;
    const char *caption;
    bool caption_from_assistant;
    const char *task;  // The request of a hand-off still running, or NULL.
} board_call_view_t;

typedef enum {
    BOARD_SETTINGS_ROOT = 0,
    BOARD_SETTINGS_NETWORK,
    BOARD_SETTINGS_UPDATE,
    BOARD_SETTINGS_DEVICE,
    BOARD_SETTINGS_FORGET,
} board_settings_page_t;

typedef struct {
    board_settings_page_t page;
    const char *headline;  // Network and device pages.
    const char *body;
    const char *channel;   // Update page: "stable" or "beta".
} board_settings_view_t;

esp_err_t board_support_init(board_support_t *board);
esp_err_t board_support_set_display_awake(board_support_t *board, bool awake);
esp_err_t board_support_set_chrome(board_support_t *board, const neoagent_status_chrome_t *status, const char *time_text);
esp_err_t board_support_show_message(board_support_t *board, mascot_mood_t mood, const char *title, const char *line1, const char *line2);
esp_err_t board_support_show_qr(board_support_t *board, const char *title, const char *subtitle, const char *qr_payload);
esp_err_t board_support_show_call(board_support_t *board, const board_call_view_t *view);
esp_err_t board_support_show_settings(board_support_t *board, const board_settings_view_t *view);
board_target_t board_support_hit_test(board_support_t *board, uint16_t x, uint16_t y);
esp_err_t board_support_poll_touch(board_support_t *board, board_touch_event_t *event);
bool board_support_touch_is_active(const board_support_t *board);
esp_err_t board_support_poll_buttons(board_support_t *board, board_button_event_t *event);
const board_audio_format_t *board_support_audio_format(const board_support_t *board);
esp_err_t board_support_audio_read(board_support_t *board, void *buffer, size_t buffer_size, size_t *bytes_read, int timeout_ms);
// Plays 16-bit mono PCM at the codec's sample rate.
esp_err_t board_support_audio_write(board_support_t *board, const void *pcm, size_t length, int timeout_ms);
esp_err_t board_support_read_battery_status(board_support_t *board, int *battery_percent, bool *charging);

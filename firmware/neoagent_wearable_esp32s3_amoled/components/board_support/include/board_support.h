#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "esp_err.h"
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

typedef enum {
    BOARD_ASSISTANT_STATE_IDLE = 0,
    BOARD_ASSISTANT_STATE_LISTENING = 1,
    BOARD_ASSISTANT_STATE_TRANSCRIBING = 2,
    BOARD_ASSISTANT_STATE_THINKING = 3,
    BOARD_ASSISTANT_STATE_SPEAKING = 4,
    BOARD_ASSISTANT_STATE_ERROR = 5,
} board_assistant_state_t;

esp_err_t board_support_init(board_support_t *board);
esp_err_t board_support_show_boot_screen(board_support_t *board);
esp_err_t board_support_set_display_awake(board_support_t *board, bool awake);
esp_err_t board_support_set_chrome(board_support_t *board, const neoagent_status_chrome_t *status, const char *time_text);
esp_err_t board_support_show_message(board_support_t *board, const char *title, const char *line1, const char *line2);
esp_err_t board_support_show_qr(board_support_t *board, const char *title, const char *subtitle, const char *qr_payload);
esp_err_t board_support_show_assistant(board_support_t *board, const char *status, const char *hint, bool mic_active, board_assistant_state_t state);
esp_err_t board_support_show_widget_card(board_support_t *board, const char *title, const char *metric, const char *detail, const char *footer, size_t index, size_t total);
esp_err_t board_support_show_recording(board_support_t *board, const char *status, const char *headline, const char *detail, bool active, bool busy, const char *timer_text);
esp_err_t board_support_show_settings(board_support_t *board, const char *section_title, const char *headline, const char *body, const char *selected_value, bool show_reset);
esp_err_t board_support_poll_touch(board_support_t *board, board_touch_event_t *event);
esp_err_t board_support_poll_buttons(board_support_t *board, board_button_event_t *event);
bool board_support_audio_is_ready(const board_support_t *board);
const board_audio_format_t *board_support_audio_format(const board_support_t *board);
esp_err_t board_support_audio_read(board_support_t *board, void *buffer, size_t buffer_size, size_t *bytes_read, int timeout_ms);
esp_err_t board_support_audio_play_wav(board_support_t *board, const uint8_t *wav_bytes, size_t wav_length, int timeout_ms);
esp_err_t board_support_read_battery_status(board_support_t *board, int *battery_percent, bool *charging);

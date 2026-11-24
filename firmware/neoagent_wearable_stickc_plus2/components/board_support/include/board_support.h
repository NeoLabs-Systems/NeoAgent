#pragma once
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include "esp_err.h"

typedef struct { bool audio_ready; } board_support_t;
typedef struct { uint32_t sample_rate_hz; uint8_t channels; uint8_t bits_per_sample; } board_audio_format_t;

esp_err_t board_support_init(board_support_t *board);
const board_audio_format_t *board_support_audio_format(const board_support_t *board);
esp_err_t board_support_audio_read(board_support_t *board, void *buffer, size_t size, size_t *read, int timeout_ms);
esp_err_t board_support_audio_write(board_support_t *board, const void *buffer, size_t size, int timeout_ms);
esp_err_t board_microphone_active(bool active);
void board_display_message(const char *title, const char *body);
void board_display_idle(bool connected);
esp_err_t board_display_qr(const char *title, const char *payload);
void board_display_scroll(int direction);
void board_display_awake(bool awake);
void board_display_tick(void);
void board_beep(void);
bool board_button_a(void);
bool board_button_b(void);
bool board_button_c(void);
esp_err_t board_prepare_deep_sleep(void);

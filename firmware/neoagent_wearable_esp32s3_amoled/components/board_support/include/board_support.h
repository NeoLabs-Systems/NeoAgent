#pragma once

#include <stdbool.h>

#include "esp_err.h"

typedef struct {
    bool display_ready;
    bool touch_ready;
    bool audio_ready;
} board_support_t;

esp_err_t board_support_init(board_support_t *board);
esp_err_t board_support_show_message(board_support_t *board, const char *title, const char *line1, const char *line2);
esp_err_t board_support_show_qr(board_support_t *board, const char *title, const char *subtitle, const char *qr_payload);

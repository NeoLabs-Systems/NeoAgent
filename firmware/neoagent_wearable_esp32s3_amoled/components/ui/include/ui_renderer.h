#pragma once

#include "esp_err.h"
#include "board_support.h"
#include "neoagent_wearable_types.h"

typedef struct {
    board_support_t *board;
    neoagent_status_chrome_t chrome;
    neoagent_screen_id_t visible_screen;
} ui_renderer_t;

esp_err_t ui_renderer_init(ui_renderer_t *renderer, board_support_t *board);
esp_err_t ui_renderer_set_screen(ui_renderer_t *renderer, neoagent_screen_id_t screen_id);
esp_err_t ui_renderer_show_provisioning(ui_renderer_t *renderer, const char *ssid, const char *password);
esp_err_t ui_renderer_show_pairing_qr(ui_renderer_t *renderer, const char *qr_payload);

#include "ui_renderer.h"

#include <stdio.h>
#include <string.h>

esp_err_t ui_renderer_init(ui_renderer_t *renderer, board_support_t *board) {
    if (renderer == NULL || board == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    memset(renderer, 0, sizeof(*renderer));
    renderer->board = board;
    return ESP_OK;
}

esp_err_t ui_renderer_set_screen(ui_renderer_t *renderer, neoagent_screen_id_t screen_id) {
    if (renderer == NULL || renderer->board == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    renderer->visible_screen = screen_id;
    switch (screen_id) {
        case NEOAGENT_SCREEN_PROVISIONING:
            return board_support_show_message(renderer->board, "NeoAgent Setup", "Preparing the setup hotspot...", "Your phone should open the setup page automatically.");
        case NEOAGENT_SCREEN_PAIRING:
            return board_support_show_message(renderer->board, "Ready To Pair", "Setup is saved.", "Next step is QR approval from an existing NeoAgent session.");
        case NEOAGENT_SCREEN_ASSISTANT:
            return board_support_show_message(renderer->board, "NeoAgent Ready", "Device is configured.", "Assistant mode wiring is next after provisioning.");
        default:
            return board_support_show_message(renderer->board, "NeoAgent", "Screen not implemented yet.", "");
    }
}

esp_err_t ui_renderer_show_provisioning(ui_renderer_t *renderer, const char *ssid, const char *password) {
    if (renderer == NULL || renderer->board == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    char line1[160];
    char line2[200];
    if (password != NULL && password[0] != '\0') {
        snprintf(line1, sizeof(line1), "Join %s\nPassword %s", ssid != NULL ? ssid : "NeoAgent Setup", password);
    } else {
        snprintf(line1, sizeof(line1), "Join %s\nNo password needed", ssid != NULL ? ssid : "NeoAgent Setup");
    }
    snprintf(line2, sizeof(line2), "If the page does not open, visit http://192.168.4.1\nThen enter your Wi-Fi and NeoAgent server.");
    renderer->visible_screen = NEOAGENT_SCREEN_PROVISIONING;
    return board_support_show_message(renderer->board, "NeoAgent Setup", line1, line2);
}

esp_err_t ui_renderer_show_pairing_qr(ui_renderer_t *renderer, const char *qr_payload) {
    if (renderer == NULL || renderer->board == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    renderer->visible_screen = NEOAGENT_SCREEN_PAIRING;
    return board_support_show_qr(
        renderer->board,
        "Scan To Pair",
        "Approve this wearable from an existing NeoAgent session.",
        qr_payload
    );
}

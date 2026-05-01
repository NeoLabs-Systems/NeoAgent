#include "ui_renderer.h"

#include <stdio.h>
#include <string.h>

static void append_text(char *destination, size_t destination_size, const char *text) {
    if (destination == NULL || destination_size == 0 || text == NULL) {
        return;
    }
    size_t used = strlen(destination);
    if (used >= destination_size - 1) {
        return;
    }
    size_t available = destination_size - used - 1;
    size_t text_length = strlen(text);
    size_t to_copy = text_length < available ? text_length : available;
    if (to_copy == 0) {
        return;
    }
    memcpy(destination + used, text, to_copy);
    destination[used + to_copy] = '\0';
}

esp_err_t ui_renderer_init(ui_renderer_t *renderer, board_support_t *board) {
    if (renderer == NULL || board == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    memset(renderer, 0, sizeof(*renderer));
    renderer->board = board;
    return ESP_OK;
}

esp_err_t ui_renderer_show_status_card(ui_renderer_t *renderer, neoagent_screen_id_t screen_id, const char *title, const char *line1, const char *line2) {
    if (renderer == NULL || renderer->board == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    renderer->visible_screen = screen_id;
    return board_support_show_message(renderer->board, title != NULL ? title : "NeoAgent", line1 != NULL ? line1 : "", line2 != NULL ? line2 : "");
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
            return board_support_show_message(renderer->board, "NeoAgent Ready", "Pairing completed.", "Loading assistant home...");
        case NEOAGENT_SCREEN_RECORDER:
            return board_support_show_recording(renderer->board, "Recording ready", "Background capture", "Loading recorder.", false, false, "00:00");
        case NEOAGENT_SCREEN_SETTINGS:
            return board_support_show_settings(renderer->board, "Settings", "Preparing controls", "Loading device settings.", NULL, false);
        default:
            return board_support_show_message(renderer->board, "NeoAgent", "Screen not implemented yet.", "");
    }
}

esp_err_t ui_renderer_show_assistant_home(
    ui_renderer_t *renderer,
    const char *status,
    const char *hint,
    bool mic_active,
    board_assistant_state_t state
) {
    if (renderer == NULL || renderer->board == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    renderer->visible_screen = NEOAGENT_SCREEN_ASSISTANT;
    return board_support_show_assistant(renderer->board, status, hint, mic_active, state);
}

esp_err_t ui_renderer_show_widget(ui_renderer_t *renderer, const neoagent_widget_snapshot_t *snapshot, size_t index, size_t total) {
    if (renderer == NULL || renderer->board == NULL || snapshot == NULL) {
        return ESP_ERR_INVALID_ARG;
    }

    char detail[192];
    const char *metric = snapshot->metric[0] != '\0' ? snapshot->metric : snapshot->subtitle;
    renderer->visible_screen = NEOAGENT_SCREEN_WIDGETS;

    detail[0] = '\0';
    if (snapshot->body[0] != '\0') {
        append_text(detail, sizeof(detail), snapshot->body);
    } else if (snapshot->rows[0].value[0] != '\0') {
        append_text(detail, sizeof(detail), snapshot->rows[0].value);
    } else if (snapshot->metric_label[0] != '\0') {
        append_text(detail, sizeof(detail), snapshot->metric_label);
    }

    return board_support_show_widget_card(renderer->board, snapshot->title, metric, detail, NULL, index, total);
}

esp_err_t ui_renderer_show_recording(
    ui_renderer_t *renderer,
    const char *status,
    const char *headline,
    const char *detail,
    bool active,
    bool busy,
    const char *timer_text
) {
    if (renderer == NULL || renderer->board == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    renderer->visible_screen = NEOAGENT_SCREEN_RECORDER;
    return board_support_show_recording(renderer->board, status, headline, detail, active, busy, timer_text);
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
    return ui_renderer_show_status_card(renderer, NEOAGENT_SCREEN_PROVISIONING, "NeoAgent Setup", line1, line2);
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

esp_err_t ui_renderer_show_settings(ui_renderer_t *renderer, const char *section_title, const char *headline, const char *body, const char *selected_value, bool show_reset) {
    if (renderer == NULL || renderer->board == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    renderer->visible_screen = NEOAGENT_SCREEN_SETTINGS;
    return board_support_show_settings(renderer->board, section_title, headline, body, selected_value, show_reset);
}

#include "wearable_voice_client.h"

#include <string.h>

esp_err_t wearable_voice_client_init(wearable_voice_client_t *client, const char *websocket_url) {
    if (client == NULL || websocket_url == NULL || websocket_url[0] == '\0') {
        return ESP_ERR_INVALID_ARG;
    }
    memset(client, 0, sizeof(*client));
    strncpy(client->websocket_url, websocket_url, sizeof(client->websocket_url) - 1);
    return ESP_OK;
}

esp_err_t wearable_voice_client_open_session(wearable_voice_client_t *client, const char *session_id) {
    if (client == NULL || session_id == NULL || session_id[0] == '\0') {
        return ESP_ERR_INVALID_ARG;
    }
    strncpy(client->active_session_id, session_id, sizeof(client->active_session_id) - 1);
    client->connected = true;
    client->next_sequence = 0;
    return ESP_OK;
}

esp_err_t wearable_voice_client_start_turn(wearable_voice_client_t *client, const char *turn_id) {
    if (client == NULL || turn_id == NULL || turn_id[0] == '\0' || !client->connected) {
        return ESP_ERR_INVALID_STATE;
    }
    strncpy(client->active_turn_id, turn_id, sizeof(client->active_turn_id) - 1);
    client->next_sequence = 0;
    return ESP_OK;
}

esp_err_t wearable_voice_client_mark_chunk_sent(wearable_voice_client_t *client) {
    if (client == NULL || !client->connected) {
        return ESP_ERR_INVALID_STATE;
    }
    client->next_sequence += 1;
    return ESP_OK;
}

esp_err_t wearable_voice_client_interrupt(wearable_voice_client_t *client) {
    if (client == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    client->active_turn_id[0] = '\0';
    client->next_sequence = 0;
    return ESP_OK;
}

#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "esp_err.h"
#include "neoagent_wearable_types.h"

typedef struct {
    bool connected;
    char websocket_url[NEOAGENT_WS_URL_MAX];
    char active_session_id[NEOAGENT_VOICE_SESSION_ID_MAX];
    char active_turn_id[NEOAGENT_VOICE_TURN_ID_MAX];
    uint32_t next_sequence;
} wearable_voice_client_t;

esp_err_t wearable_voice_client_init(wearable_voice_client_t *client, const char *websocket_url);
esp_err_t wearable_voice_client_open_session(wearable_voice_client_t *client, const char *session_id);
esp_err_t wearable_voice_client_start_turn(wearable_voice_client_t *client, const char *turn_id);
esp_err_t wearable_voice_client_mark_chunk_sent(wearable_voice_client_t *client);
esp_err_t wearable_voice_client_interrupt(wearable_voice_client_t *client);

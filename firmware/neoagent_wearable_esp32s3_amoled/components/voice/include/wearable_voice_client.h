#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "esp_err.h"
#include "board_support.h"
#include "neoagent_wearable_types.h"

#define NEOAGENT_VOICE_STATUS_TEXT_MAX 160
#define NEOAGENT_VOICE_ERROR_TEXT_MAX 160
#define NEOAGENT_VOICE_COOKIE_MAX NEOAGENT_SESSION_COOKIE_MAX

typedef struct {
    bool transport_available;
    bool websocket_connected;
    bool session_ready;
    bool recording;
    bool assistant_speaking;
    char session_id[NEOAGENT_VOICE_SESSION_ID_MAX];
    char turn_id[NEOAGENT_VOICE_TURN_ID_MAX];
    char state[32];
    char transcript[NEOAGENT_VOICE_STATUS_TEXT_MAX];
    char assistant_text[NEOAGENT_VOICE_STATUS_TEXT_MAX];
    char last_error[NEOAGENT_VOICE_ERROR_TEXT_MAX];
} wearable_voice_snapshot_t;

typedef struct {
    board_support_t *board;
    bool transport_available;
    bool websocket_connected;
    bool hello_complete;
    bool session_ready;
    bool recording;
    bool assistant_speaking;
    bool playback_active;
    uint32_t next_sequence;
    char websocket_url[NEOAGENT_WS_URL_MAX];
    char session_cookie[NEOAGENT_VOICE_COOKIE_MAX];
    char device_label[NEOAGENT_DEVICE_LABEL_MAX];
    char device_id[48];
    char firmware_version[64];
    char active_session_id[NEOAGENT_VOICE_SESSION_ID_MAX];
    char active_turn_id[NEOAGENT_VOICE_TURN_ID_MAX];
    char current_state[32];
    char latest_transcript[NEOAGENT_VOICE_STATUS_TEXT_MAX];
    char latest_assistant_text[NEOAGENT_VOICE_STATUS_TEXT_MAX];
    char last_error[NEOAGENT_VOICE_ERROR_TEXT_MAX];
    void *websocket;
    void *state_lock;
    void *capture_task;
    void *playback_task;
    void *playback_queue;
    void *pending_audio_head;
    void *pending_audio_tail;
    char *message_buffer;
    size_t message_length;
    size_t message_capacity;
    int64_t last_hello_at_us;
    int64_t last_message_at_us;
    int64_t last_connect_attempt_at_us;
} wearable_voice_client_t;

esp_err_t wearable_voice_client_init(
    wearable_voice_client_t *client,
    board_support_t *board,
    const char *websocket_url,
    const char *session_cookie,
    const char *device_label
);
esp_err_t wearable_voice_client_deinit(wearable_voice_client_t *client);
esp_err_t wearable_voice_client_start_ptt(wearable_voice_client_t *client);
esp_err_t wearable_voice_client_stop_ptt(wearable_voice_client_t *client);
esp_err_t wearable_voice_client_interrupt(wearable_voice_client_t *client);
esp_err_t wearable_voice_client_snapshot(wearable_voice_client_t *client, wearable_voice_snapshot_t *snapshot);
esp_err_t wearable_voice_client_poll(wearable_voice_client_t *client);

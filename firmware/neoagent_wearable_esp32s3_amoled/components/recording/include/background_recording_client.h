#pragma once

#include <stdbool.h>
#include <stdint.h>

#include "board_support.h"
#include "esp_err.h"
#include "neoagent_wearable_types.h"

#define NEOAGENT_RECORDING_STATUS_TEXT_MAX 128
#define NEOAGENT_RECORDING_DETAIL_TEXT_MAX 160
#define NEOAGENT_RECORDING_SESSION_ID_MAX 96

typedef struct {
    bool active;
    bool starting;
    bool stopping;
    bool upload_pending;
    bool session_ready;
    char session_id[NEOAGENT_RECORDING_SESSION_ID_MAX];
    char state[24];
    char status[NEOAGENT_RECORDING_STATUS_TEXT_MAX];
    char detail[NEOAGENT_RECORDING_DETAIL_TEXT_MAX];
    uint32_t uploaded_chunks;
    uint32_t failed_uploads;
    int64_t started_at_ms;
} background_recording_snapshot_t;

typedef struct {
    board_support_t *board;
    bool active;
    bool starting;
    bool stopping;
    bool session_ready;
    bool upload_pending;
    char server_url[NEOAGENT_SERVER_URL_MAX];
    char session_cookie[NEOAGENT_SESSION_COOKIE_MAX];
    char device_label[NEOAGENT_DEVICE_LABEL_MAX];
    char session_id[NEOAGENT_RECORDING_SESSION_ID_MAX];
    char state[24];
    char status[NEOAGENT_RECORDING_STATUS_TEXT_MAX];
    char detail[NEOAGENT_RECORDING_DETAIL_TEXT_MAX];
    char stop_reason[32];
    uint32_t next_sequence;
    uint32_t uploaded_chunks;
    uint32_t failed_uploads;
    int64_t started_at_ms;
    void *state_lock;
    void *upload_queue;
    void *capture_task;
    void *upload_task;
} background_recording_client_t;

esp_err_t background_recording_client_init(background_recording_client_t *client, board_support_t *board);
esp_err_t background_recording_client_start(
    background_recording_client_t *client,
    const char *server_url,
    const neoagent_session_state_t *session,
    const char *device_label
);
esp_err_t background_recording_client_stop(background_recording_client_t *client, const char *stop_reason);
esp_err_t background_recording_client_snapshot(background_recording_client_t *client, background_recording_snapshot_t *snapshot);
bool background_recording_client_is_active(background_recording_client_t *client);

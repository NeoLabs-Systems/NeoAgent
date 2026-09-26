#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "esp_err.h"
#include "board_support.h"
#include "neoagent_wearable_types.h"

// A live voice call over the wearable socket (/api/wearable/ws). The server
// bridges it to the live speech-to-speech model and hands requests to the
// agent as runs (server/services/voice/live/). Audio is 16-bit mono PCM both
// ways, at the rates the server names when the session is ready.

#define NEOAGENT_VOICE_TEXT_MAX 240
#define NEOAGENT_VOICE_ERROR_TEXT_MAX 160
#define NEOAGENT_VOICE_RUN_ID_MAX 64

typedef enum {
    WEARABLE_CALL_IDLE = 0,
    WEARABLE_CALL_CONNECTING,
    WEARABLE_CALL_ACTIVE,
} wearable_call_state_t;

typedef struct {
    bool server_connected;      // Socket open and the server answered the hello.
    bool authentication_rejected;
    wearable_call_state_t call;
    int64_t call_started_at_us;
    bool hands_free;            // Otherwise push-to-talk.
    bool capturing;             // The microphone is streaming to the call.
    bool speaking;              // The assistant is talking or its audio still plays.
    bool reconnecting;          // The server is re-establishing the live model.
    char caption[NEOAGENT_VOICE_TEXT_MAX];  // Latest turn of either speaker.
    bool caption_from_assistant;
    bool task_running;
    char task_request[NEOAGENT_VOICE_TEXT_MAX];
    // The last hand-off that ended; the id tells one outcome from the next.
    uint32_t task_outcome_seq;
    bool task_outcome_ok;
    char last_error[NEOAGENT_VOICE_ERROR_TEXT_MAX];
    uint32_t error_seq;
} wearable_voice_snapshot_t;

typedef struct wearable_voice_client wearable_voice_client_t;

esp_err_t wearable_voice_client_init(
    wearable_voice_client_t **client,
    board_support_t *board,
    const char *websocket_url,
    const char *session_cookie,
    const char *device_label
);
void wearable_voice_client_deinit(wearable_voice_client_t *client);

// Places a call. Hands-free calls open the microphone once the session is
// ready; push-to-talk calls wait for talk_start.
esp_err_t wearable_voice_client_call_start(wearable_voice_client_t *client);
esp_err_t wearable_voice_client_call_end(wearable_voice_client_t *client);

// Push-to-talk hold, or unmuting a hands-free call.
esp_err_t wearable_voice_client_talk_start(wearable_voice_client_t *client);
// Push-to-talk release, or muting a hands-free call.
esp_err_t wearable_voice_client_talk_stop(wearable_voice_client_t *client);

// Silences the assistant mid-sentence.
esp_err_t wearable_voice_client_stop_speaking(wearable_voice_client_t *client);

// Expires a call that never became ready; call from the main loop.
void wearable_voice_client_poll(wearable_voice_client_t *client);

void wearable_voice_client_snapshot(wearable_voice_client_t *client, wearable_voice_snapshot_t *snapshot);

#include "wearable_voice_client.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "cJSON.h"
#include "esp_app_desc.h"
#include "esp_crt_bundle.h"
#include "esp_heap_caps.h"
#include "esp_log.h"
#include "esp_mac.h"
#include "esp_timer.h"
#include "esp_websocket_client.h"
#include "freertos/FreeRTOS.h"
#include "freertos/ringbuf.h"
#include "freertos/semphr.h"
#include "freertos/task.h"
#include "mbedtls/base64.h"
#include "pcm_resampler.h"

static const char *TAG = "WearableVoice";

// Enough queued reply for a long answer: live models stream faster than real time.
#define VOICE_PLAYBACK_BUFFER_SECONDS 20
// Playback writes in short slices so an interruption silences it quickly.
#define VOICE_PLAYBACK_SLICE_MS 20
#define VOICE_CAPTURE_CHUNK_MS 60
#define VOICE_CAPTURE_TIMEOUT_MS 200
#define VOICE_SEND_TIMEOUT_TICKS pdMS_TO_TICKS(2000)
// The speaker sits next to the microphone and the board has no echo
// cancellation: while a reply is audible a hands-free call sends no audio, or
// the live model would hear itself and cut its own reply off.
#define VOICE_ECHO_GUARD_US (300LL * 1000LL)
#define VOICE_CONNECT_TIMEOUT_US (20LL * 1000LL * 1000LL)
#define VOICE_SESSION_ID_MAX 96
#define VOICE_MAX_INPUT_RATE 48000

struct wearable_voice_client {
    board_support_t *board;
    esp_websocket_client_handle_t websocket;
    SemaphoreHandle_t lock;
    RingbufHandle_t playback;
    size_t playback_capacity;
    TaskHandle_t capture_task;
    TaskHandle_t playback_task;
    uint32_t codec_rate;
    // Uplink buffers, touched only by the capture task.
    int16_t *captured;
    size_t captured_samples;
    int16_t *converted;
    char *uplink_message;
    size_t uplink_message_capacity;
    char device_id[16];
    char device_label[NEOAGENT_DEVICE_LABEL_MAX];
    char firmware_version[32];

    // Touched only by the websocket task.
    char *message;
    size_t message_length;
    size_t message_capacity;
    pcm_resampler_t downlink;
    uint32_t downlink_rate;

    // Everything below is guarded by `lock`.
    bool server_connected;
    bool authentication_rejected;
    wearable_call_state_t call;
    int64_t call_requested_at_us;
    int64_t call_started_at_us;
    char session_id[VOICE_SESSION_ID_MAX];
    bool session_requested;  // A session_open is out on this connection.
    bool hands_free;
    bool open_mic_when_ready;
    bool talk_engaged;
    bool streaming;
    uint32_t input_rate;
    uint32_t output_rate;
    bool server_speaking;
    bool reconnecting;
    int64_t last_playback_at_us;
    uint32_t playback_generation;
    char caption[NEOAGENT_VOICE_TEXT_MAX];
    bool caption_from_assistant;
    char task_run_id[NEOAGENT_VOICE_RUN_ID_MAX];
    char task_request[NEOAGENT_VOICE_TEXT_MAX];
    uint32_t task_outcome_seq;
    bool task_outcome_ok;
    char last_error[NEOAGENT_VOICE_ERROR_TEXT_MAX];
    uint32_t error_seq;
};

static void lock(wearable_voice_client_t *client) {
    xSemaphoreTake(client->lock, portMAX_DELAY);
}

static void unlock(wearable_voice_client_t *client) {
    xSemaphoreGive(client->lock);
}

static void copy_text(char *destination, size_t size, const char *value) {
    strlcpy(destination, value != NULL ? value : "", size);
}

static void set_error_locked(wearable_voice_client_t *client, const char *message) {
    copy_text(client->last_error, sizeof(client->last_error), message);
    client->error_seq += 1;
}

static void set_error(wearable_voice_client_t *client, const char *message) {
    lock(client);
    set_error_locked(client, message);
    unlock(client);
}

static const char *json_string(const cJSON *object, const char *key) {
    const cJSON *item = cJSON_GetObjectItemCaseSensitive(object, key);
    return cJSON_IsString(item) ? item->valuestring : NULL;
}

static bool json_true(const cJSON *object, const char *key) {
    return cJSON_IsTrue(cJSON_GetObjectItemCaseSensitive(object, key));
}

static uint32_t json_rate(const cJSON *object, const char *key) {
    const cJSON *item = cJSON_GetObjectItemCaseSensitive(object, key);
    return cJSON_IsNumber(item) && item->valuedouble >= 8000 && item->valuedouble <= VOICE_MAX_INPUT_RATE
        ? (uint32_t)item->valuedouble
        : 24000;
}

// Session ids go back to the server inside hand-built JSON, so only plain
// id characters are accepted.
static bool is_plain_id(const char *value) {
    if (value == NULL || value[0] == '\0' || strlen(value) >= VOICE_SESSION_ID_MAX) {
        return false;
    }
    for (const char *cursor = value; *cursor != '\0'; ++cursor) {
        const char c = *cursor;
        const bool plain = (c >= '0' && c <= '9') || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '-' || c == '_';
        if (!plain) {
            return false;
        }
    }
    return true;
}

static esp_err_t send_text(wearable_voice_client_t *client, const char *text) {
    if (!esp_websocket_client_is_connected(client->websocket)) {
        return ESP_ERR_INVALID_STATE;
    }
    const int sent = esp_websocket_client_send_text(client->websocket, text, (int)strlen(text), VOICE_SEND_TIMEOUT_TICKS);
    return sent >= 0 ? ESP_OK : ESP_FAIL;
}

static esp_err_t send_json(wearable_voice_client_t *client, cJSON *message) {
    char *text = cJSON_PrintUnformatted(message);
    cJSON_Delete(message);
    if (text == NULL) {
        return ESP_ERR_NO_MEM;
    }
    const esp_err_t err = send_text(client, text);
    cJSON_free(text);
    return err;
}

// {"type": type, "sessionId": session_id}, the shape of every call control.
static esp_err_t send_control(wearable_voice_client_t *client, const char *type, const char *session_id) {
    cJSON *message = cJSON_CreateObject();
    if (message == NULL) {
        return ESP_ERR_NO_MEM;
    }
    cJSON_AddStringToObject(message, "type", type);
    if (session_id != NULL && session_id[0] != '\0') {
        cJSON_AddStringToObject(message, "sessionId", session_id);
    }
    return send_json(client, message);
}

static esp_err_t send_hello(wearable_voice_client_t *client) {
    cJSON *message = cJSON_CreateObject();
    cJSON *device = cJSON_CreateObject();
    if (message == NULL || device == NULL) {
        cJSON_Delete(message);
        cJSON_Delete(device);
        return ESP_ERR_NO_MEM;
    }
    cJSON_AddStringToObject(message, "type", "wearable:hello");
    cJSON_AddStringToObject(device, "deviceId", client->device_id);
    cJSON_AddStringToObject(device, "platform", "esp32-s3-amoled");
    cJSON_AddStringToObject(device, "firmwareVersion", client->firmware_version);
    cJSON_AddStringToObject(device, "deviceLabel", client->device_label);
    cJSON_AddItemToObject(message, "device", device);
    return send_json(client, message);
}

// Asks for the call's session once per connection, reattaching to it when the
// socket came back mid-call. A second open would start a second billed session.
static void request_session(wearable_voice_client_t *client) {
    char session_id[VOICE_SESSION_ID_MAX];
    lock(client);
    const bool wanted = client->call != WEARABLE_CALL_IDLE && client->server_connected && !client->session_requested;
    client->session_requested = client->session_requested || wanted;
    copy_text(session_id, sizeof(session_id), client->session_id);
    unlock(client);
    if (wanted && send_control(client, "voice:session_open", session_id) != ESP_OK) {
        set_error(client, "Could not reach the voice service");
    }
}

static bool playback_audible(wearable_voice_client_t *client, int64_t last_playback_at_us) {
    const bool queued = xRingbufferGetCurFreeSize(client->playback) < client->playback_capacity;
    return queued || (esp_timer_get_time() - last_playback_at_us) < VOICE_ECHO_GUARD_US;
}

// Drops every reply sample not yet played. The playback task drains the
// buffer itself, since it is the buffer's only reader.
static void flush_playback(wearable_voice_client_t *client) {
    lock(client);
    client->playback_generation += 1;
    unlock(client);
}

static void end_call_locked(wearable_voice_client_t *client) {
    client->call = WEARABLE_CALL_IDLE;
    client->session_id[0] = '\0';
    client->session_requested = false;
    client->talk_engaged = false;
    client->open_mic_when_ready = false;
    client->server_speaking = false;
    client->reconnecting = false;
    client->call_started_at_us = 0;
    client->task_run_id[0] = '\0';
    client->task_request[0] = '\0';
}

static void queue_reply_audio(wearable_voice_client_t *client, const char *audio_base64, uint32_t output_rate) {
    const size_t encoded_length = strlen(audio_base64);
    const size_t decoded_capacity = (encoded_length / 4) * 3 + 3;
    int16_t *pcm = malloc(decoded_capacity);
    if (pcm == NULL) {
        return;
    }
    size_t decoded_length = 0;
    if (mbedtls_base64_decode((unsigned char *)pcm, decoded_capacity, &decoded_length, (const unsigned char *)audio_base64, encoded_length) != 0) {
        free(pcm);
        return;
    }
    const size_t samples = decoded_length / sizeof(int16_t);
    const int16_t *out = pcm;
    size_t out_samples = samples;
    int16_t *converted = NULL;
    if (output_rate != client->codec_rate) {
        if (client->downlink_rate != output_rate) {
            pcm_resampler_init(&client->downlink, output_rate, client->codec_rate);
            client->downlink_rate = output_rate;
        }
        converted = malloc(pcm_resampler_max_output(output_rate, client->codec_rate, samples) * sizeof(int16_t));
        if (converted == NULL) {
            free(pcm);
            return;
        }
        out_samples = pcm_resampler_process(&client->downlink, pcm, samples, converted);
        out = converted;
    }
    if (out_samples > 0 && xRingbufferSend(client->playback, out, out_samples * sizeof(int16_t), 0) != pdTRUE) {
        ESP_LOGW(TAG, "reply buffer full; dropped %u samples", (unsigned)out_samples);
    }
    free(converted);
    free(pcm);
}

// Events of an earlier call (its closing, its last audio) must not touch this one.
static bool for_current_session(wearable_voice_client_t *client, const cJSON *root) {
    const char *session_id = json_string(root, "sessionId");
    lock(client);
    const bool current = session_id != NULL && client->session_id[0] != '\0' && strcmp(session_id, client->session_id) == 0;
    unlock(client);
    return current;
}

static void handle_session_ready(wearable_voice_client_t *client, const cJSON *root) {
    const char *session_id = json_string(root, "sessionId");
    if (!is_plain_id(session_id)) {
        return;
    }
    const char *input_mode = json_string(root, "inputMode");
    const char *active_run_id = json_string(root, "activeRunId");
    lock(client);
    if (client->call == WEARABLE_CALL_IDLE) {
        // The call was hung up while the session was opening.
        unlock(client);
        send_control(client, "voice:session_close", session_id);
        return;
    }
    copy_text(client->session_id, sizeof(client->session_id), session_id);
    client->session_requested = false;
    client->call = WEARABLE_CALL_ACTIVE;
    client->hands_free = input_mode == NULL || strcmp(input_mode, "ptt") != 0;
    client->input_rate = json_rate(root, "inputSampleRate");
    client->output_rate = json_rate(root, "outputSampleRate");
    client->reconnecting = false;
    if (client->call_started_at_us == 0) {
        client->call_started_at_us = esp_timer_get_time();
    }
    // A hands-free call is a phone call: the microphone opens right away.
    if (client->open_mic_when_ready && client->hands_free) {
        client->talk_engaged = true;
    }
    client->open_mic_when_ready = false;
    if (active_run_id != NULL && active_run_id[0] != '\0') {
        copy_text(client->task_run_id, sizeof(client->task_run_id), active_run_id);
    }
    unlock(client);
    xTaskNotifyGive(client->capture_task);
}

static void handle_state(wearable_voice_client_t *client, const cJSON *root) {
    const char *state = json_string(root, "state");
    if (state == NULL) {
        return;
    }
    if (strcmp(state, "closed") == 0) {
        lock(client);
        end_call_locked(client);
        unlock(client);
        flush_playback(client);
        return;
    }
    lock(client);
    client->server_speaking = strcmp(state, "speaking") == 0;
    client->reconnecting = strcmp(state, "reconnecting") == 0 || strcmp(state, "connecting") == 0;
    unlock(client);
}

static void handle_task(wearable_voice_client_t *client, const cJSON *root) {
    const char *run_id = json_string(root, "runId");
    const char *status = json_string(root, "status");
    if (run_id == NULL || status == NULL) {
        return;
    }
    lock(client);
    if (strcmp(status, "running") == 0) {
        copy_text(client->task_run_id, sizeof(client->task_run_id), run_id);
        copy_text(client->task_request, sizeof(client->task_request), json_string(root, "request"));
    } else {
        if (strcmp(client->task_run_id, run_id) == 0) {
            client->task_run_id[0] = '\0';
            client->task_request[0] = '\0';
        }
        client->task_outcome_seq += 1;
        client->task_outcome_ok = strcmp(status, "completed") == 0;
    }
    unlock(client);
}

static void handle_message(wearable_voice_client_t *client, const char *text) {
    cJSON *root = cJSON_Parse(text);
    if (root == NULL) {
        return;
    }
    const char *type = json_string(root, "type");
    if (type == NULL) {
        cJSON_Delete(root);
        return;
    }
    const bool session_event = strcmp(type, "voice:audio") == 0 || strcmp(type, "voice:transcript") == 0 ||
        strcmp(type, "voice:state") == 0 || strcmp(type, "voice:interrupted") == 0 || strcmp(type, "voice:task") == 0;
    if (session_event && !for_current_session(client, root)) {
        cJSON_Delete(root);
        return;
    }

    if (strcmp(type, "voice:audio") == 0) {
        const char *audio = json_string(root, "audioBase64");
        lock(client);
        const uint32_t output_rate = client->output_rate;
        unlock(client);
        if (audio != NULL && audio[0] != '\0') {
            queue_reply_audio(client, audio, output_rate);
        }
    } else if (strcmp(type, "voice:transcript") == 0) {
        const char *content = json_string(root, "content");
        const char *role = json_string(root, "role");
        if (content != NULL && content[0] != '\0') {
            lock(client);
            copy_text(client->caption, sizeof(client->caption), content);
            client->caption_from_assistant = role != NULL && strcmp(role, "assistant") == 0;
            unlock(client);
        }
    } else if (strcmp(type, "voice:state") == 0) {
        handle_state(client, root);
    } else if (strcmp(type, "voice:interrupted") == 0) {
        flush_playback(client);
    } else if (strcmp(type, "voice:task") == 0) {
        handle_task(client, root);
    } else if (strcmp(type, "voice:session_ready") == 0) {
        handle_session_ready(client, root);
    } else if (strcmp(type, "voice:error") == 0) {
        const char *error = json_string(root, "error");
        const bool recoverable = json_true(root, "recoverable");
        lock(client);
        set_error_locked(client, error != NULL ? error : "Live voice failed");
        const bool abandon = !recoverable && client->call == WEARABLE_CALL_CONNECTING;
        if (abandon) {
            end_call_locked(client);
        }
        unlock(client);
    } else if (strcmp(type, "wearable:hello") == 0) {
        lock(client);
        client->server_connected = true;
        unlock(client);
        request_session(client);
    }
    cJSON_Delete(root);
}

static void on_socket_data(wearable_voice_client_t *client, const esp_websocket_event_data_t *data) {
    if (data->op_code != 0x1 && data->op_code != 0x0) {
        return;
    }
    if (data->payload_offset == 0) {
        client->message_length = 0;
    }
    const size_t needed = client->message_length + (size_t)data->data_len + 1;
    if (needed > client->message_capacity) {
        char *grown = realloc(client->message, needed + 1024);
        if (grown == NULL) {
            client->message_length = 0;
            return;
        }
        client->message = grown;
        client->message_capacity = needed + 1024;
    }
    memcpy(client->message + client->message_length, data->data_ptr, (size_t)data->data_len);
    client->message_length += (size_t)data->data_len;
    client->message[client->message_length] = '\0';
    if (data->payload_offset + data->data_len >= data->payload_len) {
        handle_message(client, client->message);
        client->message_length = 0;
    }
}

static void websocket_event_handler(void *handler_args, esp_event_base_t base, int32_t event_id, void *event_data) {
    (void)base;
    wearable_voice_client_t *client = (wearable_voice_client_t *)handler_args;
    const esp_websocket_event_data_t *data = (const esp_websocket_event_data_t *)event_data;

    switch (event_id) {
        case WEBSOCKET_EVENT_CONNECTED:
            lock(client);
            client->server_connected = false;
            client->session_requested = false;
            client->authentication_rejected = false;
            unlock(client);
            if (send_hello(client) != ESP_OK) {
                set_error(client, "Could not greet the server");
            }
            break;
        case WEBSOCKET_EVENT_DISCONNECTED:
        case WEBSOCKET_EVENT_CLOSED:
            // A call survives the socket dropping: the session is reopened
            // under its id once the socket is back.
            lock(client);
            client->server_connected = false;
            if (client->call == WEARABLE_CALL_ACTIVE) {
                client->reconnecting = true;
                client->server_speaking = false;
            }
            unlock(client);
            flush_playback(client);
            break;
        case WEBSOCKET_EVENT_DATA:
            if (data != NULL && data->data_ptr != NULL && data->data_len > 0) {
                on_socket_data(client, data);
            }
            break;
        case WEBSOCKET_EVENT_ERROR:
            if (data != NULL &&
                (data->error_handle.esp_ws_handshake_status_code == 401 ||
                 data->error_handle.esp_ws_handshake_status_code == 403)) {
                lock(client);
                client->authentication_rejected = true;
                unlock(client);
            }
            break;
        default:
            break;
    }
}

static void playback_task(void *arg) {
    wearable_voice_client_t *client = (wearable_voice_client_t *)arg;
    const size_t slice_bytes = client->codec_rate * sizeof(int16_t) * VOICE_PLAYBACK_SLICE_MS / 1000;
    uint32_t played_generation = 0;

    while (true) {
        lock(client);
        const uint32_t generation = client->playback_generation;
        unlock(client);
        if (generation != played_generation) {
            size_t length = 0;
            void *stale = NULL;
            while ((stale = xRingbufferReceiveUpTo(client->playback, &length, 0, client->playback_capacity)) != NULL) {
                vRingbufferReturnItem(client->playback, stale);
            }
            played_generation = generation;
        }

        size_t length = 0;
        void *slice = xRingbufferReceiveUpTo(client->playback, &length, pdMS_TO_TICKS(100), slice_bytes);
        if (slice == NULL) {
            continue;
        }
        const esp_err_t err = board_support_audio_write(client->board, slice, length, 200);
        vRingbufferReturnItem(client->playback, slice);
        if (err != ESP_OK) {
            ESP_LOGW(TAG, "reply playback failed: %s", esp_err_to_name(err));
            continue;
        }
        lock(client);
        client->last_playback_at_us = esp_timer_get_time();
        unlock(client);
    }
}

// The capture task owns the uplink, so input_start, the audio and input_end
// always reach the server in that order.
static void capture_task(void *arg) {
    wearable_voice_client_t *client = (wearable_voice_client_t *)arg;
    int16_t *captured = client->captured;
    int16_t *converted = client->converted;
    char *message = client->uplink_message;
    const size_t message_capacity = client->uplink_message_capacity;
    pcm_resampler_t uplink = {0};
    char session_id[VOICE_SESSION_ID_MAX] = {0};
    bool streaming = false;

    while (true) {
        lock(client);
        const bool want = client->call == WEARABLE_CALL_ACTIVE && client->talk_engaged &&
            client->server_connected && client->session_id[0] != '\0';
        const bool hands_free = client->hands_free;
        const uint32_t input_rate = client->input_rate;
        const int64_t last_playback_at_us = client->last_playback_at_us;
        const bool session_changed = streaming && strcmp(session_id, client->session_id) != 0;
        if (want && !streaming) {
            copy_text(session_id, sizeof(session_id), client->session_id);
        }
        unlock(client);

        if (streaming && (!want || session_changed)) {
            if (!session_changed) {
                send_control(client, "voice:input_end", session_id);
            }
            streaming = false;
        }
        if (want && !streaming) {
            if (send_control(client, "voice:input_start", session_id) == ESP_OK) {
                pcm_resampler_init(&uplink, client->codec_rate, input_rate);
                streaming = true;
            }
        }
        lock(client);
        client->streaming = streaming;
        unlock(client);
        if (!streaming) {
            ulTaskNotifyTake(pdTRUE, pdMS_TO_TICKS(250));
            continue;
        }

        size_t bytes_read = 0;
        const esp_err_t read_err = board_support_audio_read(client->board, captured, client->captured_samples * sizeof(int16_t), &bytes_read, VOICE_CAPTURE_TIMEOUT_MS);
        if (read_err != ESP_OK || bytes_read == 0) {
            if (read_err != ESP_ERR_TIMEOUT) {
                ESP_LOGW(TAG, "microphone read failed: %s", esp_err_to_name(read_err));
                set_error(client, "Microphone capture failed");
                vTaskDelay(pdMS_TO_TICKS(100));
            }
            continue;
        }
        if (hands_free && playback_audible(client, last_playback_at_us)) {
            continue;
        }

        const size_t samples = pcm_resampler_process(&uplink, captured, bytes_read / sizeof(int16_t), converted);
        const int prefix = snprintf(message, message_capacity, "{\"type\":\"voice:audio\",\"sessionId\":\"%s\",\"audioBase64\":\"", session_id);
        size_t encoded_length = 0;
        if (mbedtls_base64_encode((unsigned char *)message + prefix, message_capacity - (size_t)prefix - 3, &encoded_length, (const unsigned char *)converted, samples * sizeof(int16_t)) != 0) {
            continue;
        }
        memcpy(message + prefix + encoded_length, "\"}", 3);
        if (send_text(client, message) != ESP_OK) {
            ESP_LOGW(TAG, "microphone audio not sent");
        }
    }
}

static void free_client(wearable_voice_client_t *client) {
    if (client->websocket != NULL) {
        esp_websocket_client_destroy(client->websocket);
    }
    if (client->playback != NULL) {
        vRingbufferDeleteWithCaps(client->playback);
    }
    if (client->lock != NULL) {
        vSemaphoreDelete(client->lock);
    }
    free(client->message);
    free(client->captured);
    free(client->converted);
    free(client->uplink_message);
    free(client);
}

esp_err_t wearable_voice_client_init(
    wearable_voice_client_t **out,
    board_support_t *board,
    const char *websocket_url,
    const char *session_cookie,
    const char *device_label
) {
    if (out == NULL || board == NULL || websocket_url == NULL || websocket_url[0] == '\0' ||
        session_cookie == NULL || session_cookie[0] == '\0') {
        return ESP_ERR_INVALID_ARG;
    }
    const board_audio_format_t *format = board_support_audio_format(board);
    if (format == NULL) {
        return ESP_ERR_NOT_SUPPORTED;
    }

    wearable_voice_client_t *client = calloc(1, sizeof(*client));
    if (client == NULL) {
        return ESP_ERR_NO_MEM;
    }
    client->board = board;
    client->codec_rate = format->sample_rate_hz;
    client->input_rate = client->codec_rate;
    client->output_rate = client->codec_rate;
    copy_text(client->device_label, sizeof(client->device_label), device_label != NULL && device_label[0] != '\0' ? device_label : "NeoAgent wearable");
    const esp_app_desc_t *app = esp_app_get_description();
    copy_text(client->firmware_version, sizeof(client->firmware_version), app != NULL ? app->version : "unknown");
    uint8_t mac[6] = {0};
    esp_read_mac(mac, ESP_MAC_WIFI_STA);
    snprintf(client->device_id, sizeof(client->device_id), "%02X%02X%02X%02X%02X%02X", mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);

    client->lock = xSemaphoreCreateMutex();
    client->playback_capacity = client->codec_rate * sizeof(int16_t) * VOICE_PLAYBACK_BUFFER_SECONDS;
    client->playback = xRingbufferCreateWithCaps(client->playback_capacity, RINGBUF_TYPE_BYTEBUF, MALLOC_CAP_SPIRAM);
    client->captured_samples = client->codec_rate * VOICE_CAPTURE_CHUNK_MS / 1000;
    client->captured = malloc(client->captured_samples * sizeof(int16_t));
    // Room for the largest live-model input rate the server may name.
    const size_t converted_samples = pcm_resampler_max_output(client->codec_rate, VOICE_MAX_INPUT_RATE, client->captured_samples);
    client->converted = malloc(converted_samples * sizeof(int16_t));
    client->uplink_message_capacity = ((converted_samples * sizeof(int16_t) + 2) / 3) * 4 + 64 + VOICE_SESSION_ID_MAX;
    client->uplink_message = malloc(client->uplink_message_capacity);
    if (client->lock == NULL || client->playback == NULL || client->captured == NULL ||
        client->converted == NULL || client->uplink_message == NULL) {
        free_client(client);
        return ESP_ERR_NO_MEM;
    }

    const esp_websocket_client_config_t websocket_config = {
        .uri = websocket_url,
        .disable_auto_reconnect = false,
        .buffer_size = 8192,
        .task_stack = 8192,
        .network_timeout_ms = 10000,
        .reconnect_timeout_ms = 3000,
        .ping_interval_sec = 20,
        .pingpong_timeout_sec = 45,
        .crt_bundle_attach = esp_crt_bundle_attach,
        .user_agent = "NeoAgentWearable/voice",
    };
    client->websocket = esp_websocket_client_init(&websocket_config);
    if (client->websocket == NULL ||
        esp_websocket_client_append_header(client->websocket, "Cookie", session_cookie) != ESP_OK ||
        esp_websocket_register_events(client->websocket, WEBSOCKET_EVENT_ANY, websocket_event_handler, client) != ESP_OK) {
        free_client(client);
        return ESP_FAIL;
    }

    if (xTaskCreate(playback_task, "voice_playback", 4096, client, 6, &client->playback_task) != pdPASS) {
        free_client(client);
        return ESP_ERR_NO_MEM;
    }
    if (xTaskCreate(capture_task, "voice_capture", 6144, client, 5, &client->capture_task) != pdPASS) {
        vTaskDelete(client->playback_task);
        free_client(client);
        return ESP_ERR_NO_MEM;
    }
    const esp_err_t start_err = esp_websocket_client_start(client->websocket);
    if (start_err != ESP_OK) {
        // The capture and playback tasks stay parked; without a socket nothing wakes them.
        ESP_LOGW(TAG, "voice socket did not start: %s", esp_err_to_name(start_err));
    }
    *out = client;
    return ESP_OK;
}

esp_err_t wearable_voice_client_call_start(wearable_voice_client_t *client) {
    lock(client);
    if (client->call != WEARABLE_CALL_IDLE) {
        unlock(client);
        return ESP_OK;
    }
    end_call_locked(client);
    client->call = WEARABLE_CALL_CONNECTING;
    client->call_requested_at_us = esp_timer_get_time();
    client->open_mic_when_ready = true;
    client->caption[0] = '\0';
    client->last_error[0] = '\0';
    unlock(client);
    request_session(client);
    return ESP_OK;
}

esp_err_t wearable_voice_client_call_end(wearable_voice_client_t *client) {
    char session_id[VOICE_SESSION_ID_MAX];
    lock(client);
    if (client->call == WEARABLE_CALL_IDLE) {
        unlock(client);
        return ESP_OK;
    }
    copy_text(session_id, sizeof(session_id), client->session_id);
    end_call_locked(client);
    unlock(client);
    xTaskNotifyGive(client->capture_task);
    flush_playback(client);
    // Running hand-offs keep going on the server; their result lands in chat.
    return session_id[0] != '\0' ? send_control(client, "voice:session_close", session_id) : ESP_OK;
}

esp_err_t wearable_voice_client_talk_start(wearable_voice_client_t *client) {
    lock(client);
    if (client->call == WEARABLE_CALL_IDLE) {
        unlock(client);
        return ESP_ERR_INVALID_STATE;
    }
    client->talk_engaged = true;
    const bool push_to_talk = client->call == WEARABLE_CALL_ACTIVE && !client->hands_free;
    unlock(client);
    if (push_to_talk) {
        // Talking over the assistant stops it right away.
        flush_playback(client);
    }
    xTaskNotifyGive(client->capture_task);
    return ESP_OK;
}

esp_err_t wearable_voice_client_talk_stop(wearable_voice_client_t *client) {
    lock(client);
    client->talk_engaged = false;
    client->open_mic_when_ready = false;
    unlock(client);
    xTaskNotifyGive(client->capture_task);
    return ESP_OK;
}

esp_err_t wearable_voice_client_stop_speaking(wearable_voice_client_t *client) {
    char session_id[VOICE_SESSION_ID_MAX];
    lock(client);
    copy_text(session_id, sizeof(session_id), client->session_id);
    unlock(client);
    flush_playback(client);
    return session_id[0] != '\0' ? send_control(client, "voice:interrupt", session_id) : ESP_OK;
}

void wearable_voice_client_poll(wearable_voice_client_t *client) {
    char session_id[VOICE_SESSION_ID_MAX] = {0};
    lock(client);
    const bool expired = client->call == WEARABLE_CALL_CONNECTING &&
        esp_timer_get_time() - client->call_requested_at_us > VOICE_CONNECT_TIMEOUT_US;
    if (expired) {
        copy_text(session_id, sizeof(session_id), client->session_id);
        end_call_locked(client);
        set_error_locked(client, client->server_connected ? "The live voice model did not answer" : "The server is not reachable");
    }
    unlock(client);
    if (expired && session_id[0] != '\0') {
        send_control(client, "voice:session_close", session_id);
    }
}

void wearable_voice_client_snapshot(wearable_voice_client_t *client, wearable_voice_snapshot_t *snapshot) {
    memset(snapshot, 0, sizeof(*snapshot));
    lock(client);
    snapshot->server_connected = client->server_connected;
    snapshot->authentication_rejected = client->authentication_rejected;
    snapshot->call = client->call;
    snapshot->call_started_at_us = client->call_started_at_us;
    snapshot->hands_free = client->hands_free;
    snapshot->capturing = client->streaming;
    snapshot->reconnecting = client->reconnecting || (client->call == WEARABLE_CALL_ACTIVE && !client->server_connected);
    const bool server_speaking = client->server_speaking;
    const int64_t last_playback_at_us = client->last_playback_at_us;
    copy_text(snapshot->caption, sizeof(snapshot->caption), client->caption);
    snapshot->caption_from_assistant = client->caption_from_assistant;
    snapshot->task_running = client->task_run_id[0] != '\0';
    copy_text(snapshot->task_request, sizeof(snapshot->task_request), client->task_request);
    snapshot->task_outcome_seq = client->task_outcome_seq;
    snapshot->task_outcome_ok = client->task_outcome_ok;
    copy_text(snapshot->last_error, sizeof(snapshot->last_error), client->last_error);
    snapshot->error_seq = client->error_seq;
    unlock(client);
    snapshot->speaking = server_speaking || playback_audible(client, last_playback_at_us);
}

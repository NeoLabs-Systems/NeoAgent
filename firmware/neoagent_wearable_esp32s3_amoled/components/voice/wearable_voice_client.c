#include "wearable_voice_client.h"

#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "cJSON.h"
#include "esp_app_desc.h"
#include "esp_check.h"
#include "esp_crt_bundle.h"
#include "esp_log.h"
#include "esp_mac.h"
#include "esp_system.h"
#include "esp_timer.h"
#include "esp_websocket_client.h"
#include "freertos/FreeRTOS.h"
#include "freertos/queue.h"
#include "freertos/semphr.h"
#include "freertos/task.h"
#include "mbedtls/base64.h"

static const char *TAG = "WearableVoice";

#define VOICE_CAPTURE_CHUNK_BYTES 4096
#define VOICE_CAPTURE_TIMEOUT_MS 250
#define VOICE_CONNECT_TIMEOUT_MS 12000
#define VOICE_SESSION_TIMEOUT_MS 12000
#define VOICE_MESSAGE_TIMEOUT_TICKS pdMS_TO_TICKS(3000)
#define VOICE_PLAYBACK_QUEUE_DEPTH 6
#define VOICE_HELLO_STALE_TIMEOUT_US (90LL * 1000LL * 1000LL)
#define VOICE_RECONNECT_BACKOFF_US (5LL * 1000LL * 1000LL)

typedef struct {
    uint8_t *bytes;
    size_t length;
} playback_item_t;

static esp_err_t wait_for_connected(wearable_voice_client_t *client, int timeout_ms, bool require_session);
static esp_err_t ensure_session_ready(wearable_voice_client_t *client);
static void websocket_event_handler(void *handler_args, esp_event_base_t base, int32_t event_id, void *event_data);

static void voice_client_lock(wearable_voice_client_t *client) {
    if (client != NULL && client->state_lock != NULL) {
        xSemaphoreTake((SemaphoreHandle_t)client->state_lock, portMAX_DELAY);
    }
}

static void voice_client_unlock(wearable_voice_client_t *client) {
    if (client != NULL && client->state_lock != NULL) {
        xSemaphoreGive((SemaphoreHandle_t)client->state_lock);
    }
}

static void copy_bounded(char *destination, size_t destination_size, const char *value) {
    if (destination == NULL || destination_size == 0) {
        return;
    }
    destination[0] = '\0';
    if (value == NULL) {
        return;
    }
    strncpy(destination, value, destination_size - 1);
    destination[destination_size - 1] = '\0';
}

static void set_last_error(wearable_voice_client_t *client, const char *message) {
    voice_client_lock(client);
    copy_bounded(client->last_error, sizeof(client->last_error), message);
    copy_bounded(client->current_state, sizeof(client->current_state), "error");
    voice_client_unlock(client);
}

static bool json_escape_append(char *destination, size_t destination_size, const char *source) {
    size_t used = strlen(destination);
    if (used >= destination_size) {
        return false;
    }
    for (const char *cursor = source != NULL ? source : ""; *cursor != '\0'; ++cursor) {
        const char *replacement = NULL;
        char single[2] = {*cursor, '\0'};
        switch (*cursor) {
            case '"':
                replacement = "\\\"";
                break;
            case '\\':
                replacement = "\\\\";
                break;
            case '\n':
                replacement = "\\n";
                break;
            case '\r':
                replacement = "\\r";
                break;
            case '\t':
                replacement = "\\t";
                break;
            default:
                replacement = single;
                break;
        }
        size_t replacement_len = strlen(replacement);
        if (used + replacement_len + 1 >= destination_size) {
            return false;
        }
        memcpy(destination + used, replacement, replacement_len);
        used += replacement_len;
        destination[used] = '\0';
    }
    return true;
}

static esp_err_t ensure_message_capacity(wearable_voice_client_t *client, size_t needed) {
    if (client->message_capacity >= needed) {
        return ESP_OK;
    }
    size_t next_capacity = needed + 256;
    char *next = realloc(client->message_buffer, next_capacity);
    if (next == NULL) {
        return ESP_ERR_NO_MEM;
    }
    client->message_buffer = next;
    client->message_capacity = next_capacity;
    return ESP_OK;
}

static esp_err_t websocket_send_text(wearable_voice_client_t *client, const char *message) {
    if (client == NULL || message == NULL || client->websocket == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    if (!esp_websocket_client_is_connected((esp_websocket_client_handle_t)client->websocket)) {
        return ESP_ERR_INVALID_STATE;
    }
    int sent = esp_websocket_client_send_text(
        (esp_websocket_client_handle_t)client->websocket,
        message,
        (int)strlen(message),
        VOICE_MESSAGE_TIMEOUT_TICKS
    );
    return sent >= 0 ? ESP_OK : ESP_FAIL;
}

static void reset_connection_state(wearable_voice_client_t *client) {
    if (client == NULL) {
        return;
    }
    voice_client_lock(client);
    client->websocket_connected = false;
    client->hello_complete = false;
    client->session_ready = false;
    client->recording = false;
    client->assistant_speaking = false;
    client->active_session_id[0] = '\0';
    client->active_turn_id[0] = '\0';
    copy_bounded(client->current_state, sizeof(client->current_state), "idle");
    voice_client_unlock(client);
}

static esp_err_t restart_transport(wearable_voice_client_t *client) {
    if (client == NULL || client->websocket == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    esp_websocket_client_handle_t websocket = (esp_websocket_client_handle_t)client->websocket;
    reset_connection_state(client);
    esp_websocket_client_stop(websocket);
    client->last_connect_attempt_at_us = esp_timer_get_time();
    ESP_RETURN_ON_ERROR(esp_websocket_client_start(websocket), TAG, "websocket restart failed");
    return wait_for_connected(client, VOICE_CONNECT_TIMEOUT_MS, false);
}

static esp_err_t send_hello(wearable_voice_client_t *client) {
    char payload[512];
    char escaped_label[128] = {0};
    json_escape_append(escaped_label, sizeof(escaped_label), client->device_label);
    snprintf(
        payload,
        sizeof(payload),
        "{\"type\":\"wearable:hello\",\"device\":{\"deviceId\":\"%s\",\"platform\":\"esp32-s3-amoled\",\"firmwareVersion\":\"%s\",\"deviceLabel\":\"%s\"}}",
        client->device_id,
        client->firmware_version,
        escaped_label
    );
    return websocket_send_text(client, payload);
}

static esp_err_t queue_playback(wearable_voice_client_t *client, playback_item_t *item) {
    if (client == NULL || item == NULL || client->playback_queue == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    if (xQueueSend((QueueHandle_t)client->playback_queue, &item, pdMS_TO_TICKS(1000)) != pdTRUE) {
        return ESP_ERR_TIMEOUT;
    }
    return ESP_OK;
}

static void playback_task(void *arg) {
    wearable_voice_client_t *client = (wearable_voice_client_t *)arg;
    QueueHandle_t queue = (QueueHandle_t)client->playback_queue;
    playback_item_t *item = NULL;
    while (true) {
        if (xQueueReceive(queue, &item, portMAX_DELAY) != pdTRUE || item == NULL) {
            continue;
        }
        voice_client_lock(client);
        client->playback_active = true;
        voice_client_unlock(client);
        esp_err_t play_err = board_support_audio_play_wav(client->board, item->bytes, item->length, 3000);
        if (play_err != ESP_OK) {
            ESP_LOGW(TAG, "audio playback failed: %s", esp_err_to_name(play_err));
            set_last_error(client, "Audio playback failed");
        }
        free(item->bytes);
        free(item);
        voice_client_lock(client);
        client->playback_active = false;
        voice_client_unlock(client);
    }
}

static esp_err_t wait_for_connected(wearable_voice_client_t *client, int timeout_ms, bool require_session) {
    const int64_t deadline = esp_timer_get_time() + ((int64_t)timeout_ms * 1000);
    while (esp_timer_get_time() < deadline) {
        bool ready = false;
        voice_client_lock(client);
        ready = client->websocket_connected && client->hello_complete && (!require_session || client->session_ready);
        voice_client_unlock(client);
        if (ready) {
            return ESP_OK;
        }
        vTaskDelay(pdMS_TO_TICKS(100));
    }
    return ESP_ERR_TIMEOUT;
}

static esp_err_t ensure_transport_ready(wearable_voice_client_t *client) {
    if (client == NULL || client->websocket == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    bool connected = false;
    bool hello_complete = false;
    int64_t last_hello_at_us = 0;
    voice_client_lock(client);
    connected = client->websocket_connected;
    hello_complete = client->hello_complete;
    last_hello_at_us = client->last_hello_at_us;
    const int64_t last_connect_attempt_at_us = client->last_connect_attempt_at_us;
    voice_client_unlock(client);

    const int64_t now_us = esp_timer_get_time();
    const bool hello_stale = hello_complete && last_hello_at_us > 0 && (now_us - last_hello_at_us) > VOICE_HELLO_STALE_TIMEOUT_US;
    if (connected && hello_complete && !hello_stale && esp_websocket_client_is_connected((esp_websocket_client_handle_t)client->websocket)) {
        return ESP_OK;
    }
    if ((now_us - last_connect_attempt_at_us) < VOICE_RECONNECT_BACKOFF_US && connected) {
        return wait_for_connected(client, VOICE_CONNECT_TIMEOUT_MS, false);
    }
    return restart_transport(client);
}

static esp_err_t ensure_session_ready(wearable_voice_client_t *client) {
    ESP_RETURN_ON_ERROR(ensure_transport_ready(client), TAG, "transport not ready");

    voice_client_lock(client);
    bool already_ready = client->session_ready && client->active_session_id[0] != '\0';
    voice_client_unlock(client);
    if (already_ready) {
        return ESP_OK;
    }

    ESP_RETURN_ON_ERROR(websocket_send_text(client, "{\"type\":\"voice:session_open\"}"), TAG, "session open failed");
    return wait_for_connected(client, VOICE_SESSION_TIMEOUT_MS, true);
}

static esp_err_t send_input_start(wearable_voice_client_t *client, const char *turn_id) {
    char payload[320];
    snprintf(
        payload,
        sizeof(payload),
        "{\"type\":\"voice:input_start\",\"sessionId\":\"%s\",\"turnId\":\"%s\",\"mimeType\":\"audio/pcm;rate=24000;channels=1\"}",
        client->active_session_id,
        turn_id
    );
    esp_err_t send_err = websocket_send_text(client, payload);
    if (send_err != ESP_OK) {
        ESP_RETURN_ON_ERROR(restart_transport(client), TAG, "transport restart after input_start failed");
        ESP_RETURN_ON_ERROR(ensure_session_ready(client), TAG, "session recovery after input_start failed");
        snprintf(
            payload,
            sizeof(payload),
            "{\"type\":\"voice:input_start\",\"sessionId\":\"%s\",\"turnId\":\"%s\",\"mimeType\":\"audio/pcm;rate=24000;channels=1\"}",
            client->active_session_id,
            turn_id
        );
        return websocket_send_text(client, payload);
    }
    return ESP_OK;
}

static esp_err_t send_input_commit(wearable_voice_client_t *client, const char *turn_id, uint32_t final_sequence) {
    char payload[320];
    snprintf(
        payload,
        sizeof(payload),
        "{\"type\":\"voice:input_commit\",\"sessionId\":\"%s\",\"turnId\":\"%s\",\"finalSequence\":%" PRIu32 "}",
        client->active_session_id,
        turn_id,
        final_sequence
    );
    esp_err_t send_err = websocket_send_text(client, payload);
    if (send_err != ESP_OK) {
        ESP_RETURN_ON_ERROR(restart_transport(client), TAG, "transport restart after input_commit failed");
        ESP_RETURN_ON_ERROR(ensure_session_ready(client), TAG, "session recovery after input_commit failed");
        snprintf(
            payload,
            sizeof(payload),
            "{\"type\":\"voice:input_commit\",\"sessionId\":\"%s\",\"turnId\":\"%s\",\"finalSequence\":%" PRIu32 "}",
            client->active_session_id,
            turn_id,
            final_sequence
        );
        return websocket_send_text(client, payload);
    }
    return ESP_OK;
}

static esp_err_t send_interrupt(wearable_voice_client_t *client) {
    char payload[256];
    snprintf(payload, sizeof(payload), "{\"type\":\"voice:interrupt\",\"sessionId\":\"%s\"}", client->active_session_id);
    esp_err_t send_err = websocket_send_text(client, payload);
    if (send_err != ESP_OK) {
        ESP_RETURN_ON_ERROR(restart_transport(client), TAG, "transport restart after interrupt failed");
        ESP_RETURN_ON_ERROR(ensure_session_ready(client), TAG, "session recovery after interrupt failed");
        snprintf(payload, sizeof(payload), "{\"type\":\"voice:interrupt\",\"sessionId\":\"%s\"}", client->active_session_id);
        return websocket_send_text(client, payload);
    }
    return ESP_OK;
}

static void wearable_voice_client_cleanup_resources(wearable_voice_client_t *client) {
    if (client == NULL) {
        return;
    }
    if (client->capture_task != NULL) {
        vTaskDelete((TaskHandle_t)client->capture_task);
        client->capture_task = NULL;
    }
    if (client->playback_task != NULL) {
        vTaskDelete((TaskHandle_t)client->playback_task);
        client->playback_task = NULL;
    }
    if (client->websocket != NULL) {
        esp_websocket_client_handle_t websocket = (esp_websocket_client_handle_t)client->websocket;
        esp_websocket_unregister_events(websocket, WEBSOCKET_EVENT_ANY, websocket_event_handler);
        esp_websocket_client_stop(websocket);
        esp_websocket_client_destroy(websocket);
        client->websocket = NULL;
    }
    if (client->playback_queue != NULL) {
        playback_item_t *item = NULL;
        while (xQueueReceive((QueueHandle_t)client->playback_queue, &item, 0) == pdTRUE) {
            if (item != NULL) {
                free(item->bytes);
                free(item);
            }
        }
        vQueueDelete((QueueHandle_t)client->playback_queue);
        client->playback_queue = NULL;
    }
    free(client->message_buffer);
    client->message_buffer = NULL;
    client->message_length = 0;
    client->message_capacity = 0;
    client->pending_audio_head = NULL;
    client->pending_audio_tail = NULL;
    if (client->state_lock != NULL) {
        vSemaphoreDelete((SemaphoreHandle_t)client->state_lock);
        client->state_lock = NULL;
    }
}

static esp_err_t send_audio_chunk(wearable_voice_client_t *client, const char *turn_id, const uint8_t *audio_bytes, size_t audio_length) {
    size_t encoded_capacity = (4 * ((audio_length + 2) / 3)) + 4;
    char *encoded = malloc(encoded_capacity);
    if (encoded == NULL) {
        return ESP_ERR_NO_MEM;
    }
    size_t encoded_length = 0;
    int base64_err = mbedtls_base64_encode((unsigned char *)encoded, encoded_capacity, &encoded_length, audio_bytes, audio_length);
    if (base64_err != 0) {
        free(encoded);
        return ESP_FAIL;
    }

    size_t payload_capacity = encoded_length + 384;
    char *payload = malloc(payload_capacity);
    if (payload == NULL) {
        free(encoded);
        return ESP_ERR_NO_MEM;
    }
    snprintf(
        payload,
        payload_capacity,
        "{\"type\":\"voice:audio_chunk\",\"sessionId\":\"%s\",\"turnId\":\"%s\",\"sequence\":%" PRIu32 ",\"mimeType\":\"audio/pcm;rate=24000;channels=1\",\"audioBase64\":\"%s\"}",
        client->active_session_id,
        turn_id,
        client->next_sequence,
        encoded
    );
    esp_err_t send_err = websocket_send_text(client, payload);
    if (send_err != ESP_OK) {
        ESP_LOGW(TAG, "audio chunk write failed, restarting transport");
        restart_transport(client);
    }
    free(payload);
    free(encoded);
    if (send_err == ESP_OK) {
        client->next_sequence += 1;
    }
    return send_err;
}

static void capture_task(void *arg) {
    wearable_voice_client_t *client = (wearable_voice_client_t *)arg;
    uint8_t *capture_buffer = malloc(VOICE_CAPTURE_CHUNK_BYTES);
    if (capture_buffer == NULL) {
        set_last_error(client, "Mic capture buffer alloc failed");
        voice_client_lock(client);
        client->recording = false;
        client->capture_task = NULL;
        voice_client_unlock(client);
        vTaskDelete(NULL);
        return;
    }

    while (true) {
        voice_client_lock(client);
        bool should_continue = client->recording;
        char turn_id[NEOAGENT_VOICE_TURN_ID_MAX];
        copy_bounded(turn_id, sizeof(turn_id), client->active_turn_id);
        voice_client_unlock(client);
        if (!should_continue) {
            break;
        }

        size_t bytes_read = 0;
        esp_err_t read_err = board_support_audio_read(client->board, capture_buffer, VOICE_CAPTURE_CHUNK_BYTES, &bytes_read, VOICE_CAPTURE_TIMEOUT_MS);
        if (read_err == ESP_OK && bytes_read > 0) {
            esp_err_t send_err = send_audio_chunk(client, turn_id, capture_buffer, bytes_read);
            if (send_err != ESP_OK) {
                ESP_LOGW(TAG, "audio chunk send failed: %s", esp_err_to_name(send_err));
                set_last_error(client, "Voice uplink failed");
            }
        } else if (read_err != ESP_ERR_TIMEOUT && read_err != ESP_OK) {
            ESP_LOGW(TAG, "audio capture failed: %s", esp_err_to_name(read_err));
            set_last_error(client, "Mic capture failed");
            vTaskDelay(pdMS_TO_TICKS(50));
        }
    }

    free(capture_buffer);
    voice_client_lock(client);
    client->capture_task = NULL;
    voice_client_unlock(client);
    vTaskDelete(NULL);
}

static esp_err_t handle_incoming_json(wearable_voice_client_t *client, const char *message) {
    cJSON *root = cJSON_Parse(message);
    if (root == NULL) {
        return ESP_ERR_INVALID_RESPONSE;
    }
    cJSON *type = cJSON_GetObjectItemCaseSensitive(root, "type");
    if (!cJSON_IsString(type)) {
        cJSON_Delete(root);
        return ESP_ERR_INVALID_RESPONSE;
    }

    const char *message_type = type->valuestring;
    if (strcmp(message_type, "wearable:hello") == 0) {
        voice_client_lock(client);
        client->hello_complete = true;
        client->transport_available = true;
        client->last_hello_at_us = esp_timer_get_time();
        client->last_message_at_us = client->last_hello_at_us;
        copy_bounded(client->current_state, sizeof(client->current_state), "idle");
        client->last_error[0] = '\0';
        voice_client_unlock(client);
    } else if (strcmp(message_type, "voice:session_ready") == 0) {
        cJSON *session_id = cJSON_GetObjectItemCaseSensitive(root, "sessionId");
        if (cJSON_IsString(session_id)) {
            voice_client_lock(client);
            copy_bounded(client->active_session_id, sizeof(client->active_session_id), session_id->valuestring);
            client->session_ready = true;
            client->last_message_at_us = esp_timer_get_time();
            copy_bounded(client->current_state, sizeof(client->current_state), "idle");
            client->last_error[0] = '\0';
            voice_client_unlock(client);
        }
    } else if (strcmp(message_type, "voice:assistant_state") == 0) {
        cJSON *state = cJSON_GetObjectItemCaseSensitive(root, "state");
        if (cJSON_IsString(state)) {
            voice_client_lock(client);
            copy_bounded(client->current_state, sizeof(client->current_state), state->valuestring);
            client->assistant_speaking = strcmp(state->valuestring, "speaking") == 0;
            client->last_message_at_us = esp_timer_get_time();
            if (strcmp(state->valuestring, "closed") == 0) {
                client->session_ready = false;
                client->active_session_id[0] = '\0';
            }
            voice_client_unlock(client);
        }
    } else if (strcmp(message_type, "voice:transcript_partial") == 0 || strcmp(message_type, "voice:transcript_final") == 0) {
        cJSON *content = cJSON_GetObjectItemCaseSensitive(root, "content");
        if (cJSON_IsString(content)) {
            voice_client_lock(client);
            copy_bounded(client->latest_transcript, sizeof(client->latest_transcript), content->valuestring);
            client->last_message_at_us = esp_timer_get_time();
            voice_client_unlock(client);
        }
    } else if (strcmp(message_type, "voice:assistant_text") == 0) {
        cJSON *content = cJSON_GetObjectItemCaseSensitive(root, "content");
        if (cJSON_IsString(content)) {
            voice_client_lock(client);
            copy_bounded(client->latest_assistant_text, sizeof(client->latest_assistant_text), content->valuestring);
            client->last_message_at_us = esp_timer_get_time();
            voice_client_unlock(client);
        }
    } else if (strcmp(message_type, "voice:audio_chunk") == 0) {
        cJSON *audio_base64 = cJSON_GetObjectItemCaseSensitive(root, "audioBase64");
        if (cJSON_IsString(audio_base64) && audio_base64->valuestring[0] != '\0') {
            size_t decoded_capacity = strlen(audio_base64->valuestring) * 3 / 4 + 8;
            uint8_t *decoded = malloc(decoded_capacity);
            if (decoded != NULL) {
                size_t decoded_length = 0;
                int decode_err = mbedtls_base64_decode(decoded, decoded_capacity, &decoded_length, (const unsigned char *)audio_base64->valuestring, strlen(audio_base64->valuestring));
                if (decode_err == 0 && decoded_length > 0) {
                    playback_item_t *item = malloc(sizeof(*item));
                    if (item != NULL) {
                        item->bytes = decoded;
                        item->length = decoded_length;
                        if (queue_playback(client, item) != ESP_OK) {
                            free(item->bytes);
                            free(item);
                        }
                    } else {
                        free(decoded);
                    }
                } else {
                    free(decoded);
                }
            }
        }
    } else if (strcmp(message_type, "voice:error") == 0) {
        cJSON *error = cJSON_GetObjectItemCaseSensitive(root, "error");
        if (cJSON_IsString(error)) {
            set_last_error(client, error->valuestring);
        }
        voice_client_lock(client);
        client->last_message_at_us = esp_timer_get_time();
        voice_client_unlock(client);
    }

    cJSON_Delete(root);
    return ESP_OK;
}

static void websocket_event_handler(void *handler_args, esp_event_base_t base, int32_t event_id, void *event_data) {
    (void)base;
    wearable_voice_client_t *client = (wearable_voice_client_t *)handler_args;
    esp_websocket_event_data_t *data = (esp_websocket_event_data_t *)event_data;

    switch (event_id) {
        case WEBSOCKET_EVENT_CONNECTED:
            voice_client_lock(client);
            client->websocket_connected = true;
            client->hello_complete = false;
            client->session_ready = false;
            client->active_session_id[0] = '\0';
            client->last_connect_attempt_at_us = esp_timer_get_time();
            voice_client_unlock(client);
            if (send_hello(client) != ESP_OK) {
                set_last_error(client, "Wearable hello failed");
            }
            break;
        case WEBSOCKET_EVENT_DISCONNECTED:
            reset_connection_state(client);
            break;
        case WEBSOCKET_EVENT_DATA:
            if (data != NULL && data->op_code == 0x1 && data->data_ptr != NULL && data->data_len > 0) {
                if (data->payload_offset == 0) {
                    client->message_length = 0;
                }
                if (ensure_message_capacity(client, client->message_length + data->data_len + 1) == ESP_OK) {
                    memcpy(client->message_buffer + client->message_length, data->data_ptr, data->data_len);
                    client->message_length += data->data_len;
                    client->message_buffer[client->message_length] = '\0';
                    if (data->fin && (data->payload_offset + data->data_len) >= data->payload_len) {
                        handle_incoming_json(client, client->message_buffer);
                        client->message_length = 0;
                    }
                }
            }
            break;
        case WEBSOCKET_EVENT_ERROR:
            if (data != NULL) {
                char message[160];
                snprintf(
                    message,
                    sizeof(message),
                    "WebSocket error type=%d status=%d errno=%d",
                    data->error_handle.error_type,
                    data->error_handle.esp_ws_handshake_status_code,
                    data->error_handle.esp_transport_sock_errno
                );
                set_last_error(client, message);
            }
            break;
        default:
            break;
    }
}

esp_err_t wearable_voice_client_init(
    wearable_voice_client_t *client,
    board_support_t *board,
    const char *websocket_url,
    const char *session_cookie,
    const char *device_label
) {
    if (client == NULL || board == NULL || websocket_url == NULL || websocket_url[0] == '\0' || session_cookie == NULL || session_cookie[0] == '\0') {
        return ESP_ERR_INVALID_ARG;
    }

    memset(client, 0, sizeof(*client));
    client->board = board;
    copy_bounded(client->websocket_url, sizeof(client->websocket_url), websocket_url);
    copy_bounded(client->session_cookie, sizeof(client->session_cookie), session_cookie);
    copy_bounded(client->device_label, sizeof(client->device_label), device_label != NULL ? device_label : "NeoAgent wearable");

    const esp_app_desc_t *app_desc = esp_app_get_description();
    copy_bounded(client->firmware_version, sizeof(client->firmware_version), app_desc != NULL ? app_desc->version : "unknown");
    uint8_t mac[6] = {0};
    esp_read_mac(mac, ESP_MAC_WIFI_STA);
    snprintf(client->device_id, sizeof(client->device_id), "%02X%02X%02X%02X%02X%02X", mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);

    client->state_lock = xSemaphoreCreateMutex();
    if (client->state_lock == NULL) {
        return ESP_ERR_NO_MEM;
    }
    client->playback_queue = xQueueCreate(VOICE_PLAYBACK_QUEUE_DEPTH, sizeof(playback_item_t *));
    if (client->playback_queue == NULL) {
        return ESP_ERR_NO_MEM;
    }

    const esp_websocket_client_config_t websocket_cfg = {
        .uri = client->websocket_url,
        .disable_auto_reconnect = false,
        .enable_close_reconnect = true,
        .buffer_size = 4096,
        .task_stack = 8192,
        .network_timeout_ms = 10000,
        .reconnect_timeout_ms = 3000,
        .ping_interval_sec = 30,
        .pingpong_timeout_sec = 45,
        .crt_bundle_attach = esp_crt_bundle_attach,
        .user_agent = "NeoAgentWearable/voice",
    };
    esp_websocket_client_handle_t websocket = esp_websocket_client_init(&websocket_cfg);
    if (websocket == NULL) {
        wearable_voice_client_cleanup_resources(client);
        return ESP_FAIL;
    }
    ESP_ERROR_CHECK(esp_websocket_client_append_header(websocket, "Cookie", client->session_cookie));
    ESP_ERROR_CHECK(esp_websocket_register_events(websocket, WEBSOCKET_EVENT_ANY, websocket_event_handler, client));
    client->websocket = websocket;

    TaskHandle_t playback_handle = NULL;
    if (xTaskCreate(playback_task, "voice_playback", 8192, client, 4, &playback_handle) != pdPASS) {
        wearable_voice_client_cleanup_resources(client);
        return ESP_ERR_NO_MEM;
    }
    client->playback_task = playback_handle;

    client->transport_available = board_support_audio_is_ready(board);
    if (!client->transport_available) {
        set_last_error(client, "Audio hardware unavailable");
        wearable_voice_client_cleanup_resources(client);
        return ESP_ERR_NOT_SUPPORTED;
    }
    return ensure_transport_ready(client);
}

esp_err_t wearable_voice_client_deinit(wearable_voice_client_t *client) {
    if (client == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    wearable_voice_client_cleanup_resources(client);
    memset(client, 0, sizeof(*client));
    return ESP_OK;
}

esp_err_t wearable_voice_client_start_ptt(wearable_voice_client_t *client) {
    if (client == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    if (!client->transport_available) {
        return ESP_ERR_NOT_SUPPORTED;
    }
    ESP_RETURN_ON_ERROR(ensure_session_ready(client), TAG, "voice session not ready");

    int64_t now_us = esp_timer_get_time();
    char turn_id[NEOAGENT_VOICE_TURN_ID_MAX];
    snprintf(turn_id, sizeof(turn_id), "turn-%" PRIi64, now_us);

    voice_client_lock(client);
    copy_bounded(client->active_turn_id, sizeof(client->active_turn_id), turn_id);
    client->next_sequence = 0;
    client->recording = true;
    copy_bounded(client->current_state, sizeof(client->current_state), "listening");
    client->latest_transcript[0] = '\0';
    client->latest_assistant_text[0] = '\0';
    client->last_error[0] = '\0';
    voice_client_unlock(client);

    ESP_RETURN_ON_ERROR(send_input_start(client, turn_id), TAG, "input start failed");
    voice_client_lock(client);
    if (client->capture_task != NULL) {
        voice_client_unlock(client);
        return ESP_OK;
    }
    client->capture_task = (TaskHandle_t)1;
    voice_client_unlock(client);

    TaskHandle_t capture_handle = NULL;
    if (xTaskCreate(capture_task, "voice_capture", 8192, client, 5, &capture_handle) != pdPASS) {
        voice_client_lock(client);
        client->capture_task = NULL;
        client->recording = false;
        voice_client_unlock(client);
        return ESP_ERR_NO_MEM;
    }
    voice_client_lock(client);
    client->capture_task = capture_handle;
    voice_client_unlock(client);
    return ESP_OK;
}

esp_err_t wearable_voice_client_poll(wearable_voice_client_t *client) {
    if (client == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    if (!client->transport_available) {
        return ESP_ERR_NOT_SUPPORTED;
    }
    return ensure_transport_ready(client);
}

esp_err_t wearable_voice_client_stop_ptt(wearable_voice_client_t *client) {
    if (client == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    voice_client_lock(client);
    bool was_recording = client->recording;
    client->recording = false;
    uint32_t final_sequence = client->next_sequence;
    if (was_recording) {
        copy_bounded(client->current_state, sizeof(client->current_state), "transcribing");
    }
    char turn_id[NEOAGENT_VOICE_TURN_ID_MAX];
    copy_bounded(turn_id, sizeof(turn_id), client->active_turn_id);
    voice_client_unlock(client);

    if (!was_recording) {
        return ESP_OK;
    }
    for (int attempt = 0; attempt < 20; ++attempt) {
        if (client->capture_task == NULL) {
            break;
        }
        vTaskDelay(pdMS_TO_TICKS(25));
    }

    if (final_sequence == 0) {
        return send_interrupt(client);
    }
    return send_input_commit(client, turn_id, final_sequence - 1);
}

esp_err_t wearable_voice_client_interrupt(wearable_voice_client_t *client) {
    if (client == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    voice_client_lock(client);
    client->recording = false;
    voice_client_unlock(client);
    return client->active_session_id[0] != '\0' ? send_interrupt(client) : ESP_OK;
}

esp_err_t wearable_voice_client_snapshot(wearable_voice_client_t *client, wearable_voice_snapshot_t *snapshot) {
    if (client == NULL || snapshot == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    memset(snapshot, 0, sizeof(*snapshot));
    voice_client_lock(client);
    snapshot->transport_available = client->transport_available;
    snapshot->websocket_connected = client->websocket_connected;
    snapshot->session_ready = client->session_ready;
    snapshot->recording = client->recording;
    snapshot->assistant_speaking = client->assistant_speaking || client->playback_active;
    copy_bounded(snapshot->session_id, sizeof(snapshot->session_id), client->active_session_id);
    copy_bounded(snapshot->turn_id, sizeof(snapshot->turn_id), client->active_turn_id);
    copy_bounded(snapshot->state, sizeof(snapshot->state), client->current_state);
    copy_bounded(snapshot->transcript, sizeof(snapshot->transcript), client->latest_transcript);
    copy_bounded(snapshot->assistant_text, sizeof(snapshot->assistant_text), client->latest_assistant_text);
    copy_bounded(snapshot->last_error, sizeof(snapshot->last_error), client->last_error);
    voice_client_unlock(client);
    return ESP_OK;
}

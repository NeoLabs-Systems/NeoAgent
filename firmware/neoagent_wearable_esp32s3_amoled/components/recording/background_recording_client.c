#include "background_recording_client.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "cJSON.h"
#include "esp_check.h"
#include "esp_crt_bundle.h"
#include "esp_http_client.h"
#include "esp_log.h"
#include "esp_timer.h"
#include "freertos/FreeRTOS.h"
#include "freertos/queue.h"
#include "freertos/semphr.h"
#include "freertos/task.h"

static const char *TAG = "RecordingClient";

#define RECORDING_SOURCE_KEY "microphone"
#define RECORDING_CAPTURE_FRAME_BYTES 9600
#define RECORDING_CHUNK_PCM_BYTES 96000
#define RECORDING_UPLOAD_QUEUE_DEPTH 4
#define RECORDING_HTTP_TIMEOUT_MS 20000

typedef struct {
    uint8_t *wav_bytes;
    size_t wav_length;
    uint32_t sequence_index;
    uint32_t start_ms;
    uint32_t end_ms;
    bool finalize_after_upload;
    char stop_reason[32];
} recording_upload_item_t;

typedef struct {
    char body[2048];
    size_t body_length;
} http_capture_t;

static bool url_is_https(const char *url) {
    return url != NULL && strncmp(url, "https://", 8) == 0;
}

static void build_endpoint_url(const char *base_url, const char *path, char *output, size_t output_size) {
    if (output == NULL || output_size == 0) {
        return;
    }
    output[0] = '\0';
    if (base_url == NULL || path == NULL) {
        return;
    }
    size_t base_length = strlen(base_url);
    while (base_length > 0 && base_url[base_length - 1] == '/') {
        base_length--;
    }
    if (base_length + strlen(path) + 1 > output_size) {
        return;
    }
    memcpy(output, base_url, base_length);
    output[base_length] = '\0';
    strncat(output, path, output_size - strlen(output) - 1);
}

static SemaphoreHandle_t client_lock(background_recording_client_t *client) {
    return (SemaphoreHandle_t)client->state_lock;
}

static QueueHandle_t client_queue(background_recording_client_t *client) {
    return (QueueHandle_t)client->upload_queue;
}

static void client_set_state_locked(background_recording_client_t *client, const char *state, const char *status, const char *detail) {
    if (state != NULL) {
        snprintf(client->state, sizeof(client->state), "%s", state);
    }
    if (status != NULL) {
        snprintf(client->status, sizeof(client->status), "%s", status);
    }
    if (detail != NULL) {
        snprintf(client->detail, sizeof(client->detail), "%s", detail);
    }
}

static void client_set_state(background_recording_client_t *client, const char *state, const char *status, const char *detail) {
    SemaphoreHandle_t lock = client_lock(client);
    if (lock != NULL && xSemaphoreTake(lock, pdMS_TO_TICKS(1000)) == pdTRUE) {
        client_set_state_locked(client, state, status, detail);
        xSemaphoreGive(lock);
    }
}

static esp_err_t http_event_handler(esp_http_client_event_t *event) {
    http_capture_t *capture = (http_capture_t *)event->user_data;
    if (capture == NULL) {
        return ESP_OK;
    }
    if (event->event_id == HTTP_EVENT_ON_DATA && event->data != NULL && event->data_len > 0) {
        size_t writable = sizeof(capture->body) - capture->body_length - 1;
        size_t to_copy = (size_t)event->data_len < writable ? (size_t)event->data_len : writable;
        if (to_copy > 0) {
            memcpy(capture->body + capture->body_length, event->data, to_copy);
            capture->body_length += to_copy;
            capture->body[capture->body_length] = '\0';
        }
    }
    return ESP_OK;
}

static esp_err_t perform_json_request(
    esp_http_client_method_t method,
    const char *url,
    const char *cookie,
    const char *content_type,
    const void *body,
    int body_length,
    http_capture_t *capture,
    int *status_code,
    void (*header_fn)(esp_http_client_handle_t client, void *context),
    void *header_context
) {
    if (url == NULL || capture == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    memset(capture, 0, sizeof(*capture));

    esp_http_client_config_t config = {
        .url = url,
        .method = method,
        .event_handler = http_event_handler,
        .user_data = capture,
        .timeout_ms = RECORDING_HTTP_TIMEOUT_MS,
        .buffer_size = 2048,
    };
    if (url_is_https(url)) {
        config.crt_bundle_attach = esp_crt_bundle_attach;
    }

    esp_http_client_handle_t client = esp_http_client_init(&config);
    if (client == NULL) {
        return ESP_ERR_NO_MEM;
    }
    if (cookie != NULL && cookie[0] != '\0') {
        esp_http_client_set_header(client, "Cookie", cookie);
    }
    if (content_type != NULL && content_type[0] != '\0') {
        esp_http_client_set_header(client, "Content-Type", content_type);
    }
    if (header_fn != NULL) {
        header_fn(client, header_context);
    }
    if (body != NULL && body_length > 0) {
        esp_http_client_set_post_field(client, (const char *)body, body_length);
    }
    esp_err_t err = esp_http_client_perform(client);
    if (status_code != NULL) {
        *status_code = esp_http_client_get_status_code(client);
    }
    esp_http_client_cleanup(client);
    return err;
}

static esp_err_t parse_create_session_response(const char *json_body, char *session_id, size_t session_id_size) {
    cJSON *root = cJSON_Parse(json_body);
    if (root == NULL) {
        return ESP_ERR_INVALID_RESPONSE;
    }
    cJSON *session = cJSON_GetObjectItemCaseSensitive(root, "session");
    cJSON *id = session != NULL ? cJSON_GetObjectItemCaseSensitive(session, "id") : NULL;
    if (!cJSON_IsString(id) || id->valuestring == NULL || id->valuestring[0] == '\0') {
        cJSON_Delete(root);
        return ESP_ERR_INVALID_RESPONSE;
    }
    snprintf(session_id, session_id_size, "%s", id->valuestring);
    cJSON_Delete(root);
    return ESP_OK;
}

static void recording_chunk_headers(esp_http_client_handle_t client, void *context) {
    const recording_upload_item_t *item = (const recording_upload_item_t *)context;
    char sequence_text[16];
    char start_text[16];
    char end_text[16];
    snprintf(sequence_text, sizeof(sequence_text), "%u", (unsigned)item->sequence_index);
    snprintf(start_text, sizeof(start_text), "%u", (unsigned)item->start_ms);
    snprintf(end_text, sizeof(end_text), "%u", (unsigned)item->end_ms);
    esp_http_client_set_header(client, "x-recording-source-key", RECORDING_SOURCE_KEY);
    esp_http_client_set_header(client, "x-recording-sequence", sequence_text);
    esp_http_client_set_header(client, "x-recording-start-ms", start_text);
    esp_http_client_set_header(client, "x-recording-end-ms", end_text);
}

static size_t write_le16(uint8_t *buffer, size_t offset, uint16_t value) {
    buffer[offset] = (uint8_t)(value & 0xffU);
    buffer[offset + 1] = (uint8_t)((value >> 8) & 0xffU);
    return offset + 2;
}

static size_t write_le32(uint8_t *buffer, size_t offset, uint32_t value) {
    buffer[offset] = (uint8_t)(value & 0xffU);
    buffer[offset + 1] = (uint8_t)((value >> 8) & 0xffU);
    buffer[offset + 2] = (uint8_t)((value >> 16) & 0xffU);
    buffer[offset + 3] = (uint8_t)((value >> 24) & 0xffU);
    return offset + 4;
}

static uint8_t *build_wav_chunk(background_recording_client_t *client, const uint8_t *pcm_bytes, size_t pcm_length, size_t *wav_length_out) {
    const board_audio_format_t *format = board_support_audio_format(client->board);
    if (format == NULL || pcm_bytes == NULL || pcm_length == 0 || wav_length_out == NULL) {
        return NULL;
    }
    const uint32_t byte_rate = format->sample_rate_hz * format->channels * (format->bits_per_sample / 8U);
    const uint16_t block_align = (uint16_t)(format->channels * (format->bits_per_sample / 8U));
    const size_t wav_length = 44 + pcm_length;
    uint8_t *wav_bytes = calloc(1, wav_length);
    if (wav_bytes == NULL) {
        return NULL;
    }

    memcpy(wav_bytes, "RIFF", 4);
    write_le32(wav_bytes, 4, (uint32_t)(wav_length - 8));
    memcpy(wav_bytes + 8, "WAVEfmt ", 8);
    write_le32(wav_bytes, 16, 16);
    write_le16(wav_bytes, 20, 1);
    write_le16(wav_bytes, 22, format->channels);
    write_le32(wav_bytes, 24, format->sample_rate_hz);
    write_le32(wav_bytes, 28, byte_rate);
    write_le16(wav_bytes, 32, block_align);
    write_le16(wav_bytes, 34, format->bits_per_sample);
    memcpy(wav_bytes + 36, "data", 4);
    write_le32(wav_bytes, 40, (uint32_t)pcm_length);
    memcpy(wav_bytes + 44, pcm_bytes, pcm_length);
    *wav_length_out = wav_length;
    return wav_bytes;
}

static esp_err_t create_recording_session(background_recording_client_t *client) {
    char url[NEOAGENT_SERVER_URL_MAX + 32];
    http_capture_t capture = {0};
    int status_code = 0;
    static const char request_body[] =
        "{\"platform\":\"wearable\",\"screenAnalysisReady\":false,"
        "\"sources\":[{\"sourceKey\":\"microphone\",\"sourceKind\":\"microphone\","
        "\"mediaKind\":\"audio\",\"mimeType\":\"audio/wav\","
        "\"metadata\":{\"backgroundCapable\":true}}],"
        "\"capturePlan\":\"wearable-background-mic\"}";
    build_endpoint_url(client->server_url, "/api/recordings", url, sizeof(url));
    esp_err_t err = perform_json_request(
        HTTP_METHOD_POST,
        url,
        client->session_cookie,
        "application/json",
        request_body,
        (int)strlen(request_body),
        &capture,
        &status_code,
        NULL,
        NULL
    );
    if (err != ESP_OK) {
        return err;
    }
    if (status_code < 200 || status_code >= 300) {
        ESP_LOGW(TAG, "recording session create failed status=%d body=%s", status_code, capture.body);
        return ESP_FAIL;
    }
    return parse_create_session_response(capture.body, client->session_id, sizeof(client->session_id));
}

static esp_err_t upload_chunk(background_recording_client_t *client, const recording_upload_item_t *item) {
    char path[NEOAGENT_RECORDING_SESSION_ID_MAX + 32];
    char url[NEOAGENT_SERVER_URL_MAX + NEOAGENT_RECORDING_SESSION_ID_MAX + 32];
    http_capture_t capture = {0};
    int status_code = 0;
    snprintf(path, sizeof(path), "/api/recordings/%s/chunks", client->session_id);
    build_endpoint_url(client->server_url, path, url, sizeof(url));
    esp_err_t err = perform_json_request(
        HTTP_METHOD_POST,
        url,
        client->session_cookie,
        "audio/wav",
        item->wav_bytes,
        (int)item->wav_length,
        &capture,
        &status_code,
        recording_chunk_headers,
        (void *)item
    );
    if (err != ESP_OK) {
        return err;
    }
    if (status_code != 200 && status_code != 201) {
        ESP_LOGW(TAG, "recording chunk upload failed status=%d body=%s", status_code, capture.body);
        return ESP_FAIL;
    }
    return ESP_OK;
}

static esp_err_t finalize_session(background_recording_client_t *client, const char *stop_reason) {
    char path[NEOAGENT_RECORDING_SESSION_ID_MAX + 36];
    char url[NEOAGENT_SERVER_URL_MAX + NEOAGENT_RECORDING_SESSION_ID_MAX + 36];
    char *body = NULL;
    http_capture_t capture = {0};
    int status_code = 0;
    snprintf(path, sizeof(path), "/api/recordings/%s/finalize", client->session_id);
    build_endpoint_url(client->server_url, path, url, sizeof(url));
    cJSON *root = cJSON_CreateObject();
    if (root == NULL) {
        return ESP_ERR_NO_MEM;
    }
    cJSON_AddStringToObject(root, "stopReason", stop_reason != NULL && stop_reason[0] != '\0' ? stop_reason : "ended");
    body = cJSON_PrintUnformatted(root);
    cJSON_Delete(root);
    if (body == NULL) {
        return ESP_ERR_NO_MEM;
    }
    esp_err_t err = perform_json_request(
        HTTP_METHOD_POST,
        url,
        client->session_cookie,
        "application/json",
        body,
        (int)strlen(body),
        &capture,
        &status_code,
        NULL,
        NULL
    );
    free(body);
    if (err != ESP_OK) {
        return err;
    }
    if (status_code < 200 || status_code >= 300) {
        ESP_LOGW(TAG, "recording finalize failed status=%d body=%s", status_code, capture.body);
        return ESP_FAIL;
    }
    return ESP_OK;
}

static void reset_runtime_state_locked(background_recording_client_t *client) {
    client->active = false;
    client->starting = false;
    client->stopping = false;
    client->session_ready = false;
    client->upload_pending = false;
    client->session_id[0] = '\0';
    client->stop_reason[0] = '\0';
    client->next_sequence = 0;
    client->started_at_ms = 0;
}

static void recording_capture_task(void *arg) {
    background_recording_client_t *client = (background_recording_client_t *)arg;
    QueueHandle_t queue = client_queue(client);
    uint8_t *pcm_chunk = calloc(1, RECORDING_CHUNK_PCM_BYTES);
    uint8_t *frame = calloc(1, RECORDING_CAPTURE_FRAME_BYTES);
    size_t pcm_used = 0;
    uint32_t chunk_start_ms = 0;
    if (pcm_chunk == NULL || frame == NULL || queue == NULL) {
        client_set_state(client, "error", "Recording unavailable", "Capture memory allocation failed.");
        SemaphoreHandle_t update_lock = client_lock(client);
        if (update_lock != NULL && xSemaphoreTake(update_lock, pdMS_TO_TICKS(1000)) == pdTRUE) {
            client->active = false;
            xSemaphoreGive(update_lock);
        }
        goto done;
    }

    while (true) {
        bool should_continue = false;
        bool should_stop = false;
        SemaphoreHandle_t lock = client_lock(client);
        if (lock != NULL && xSemaphoreTake(lock, pdMS_TO_TICKS(1000)) == pdTRUE) {
            should_continue = client->active;
            should_stop = client->stopping;
            xSemaphoreGive(lock);
        }
        if (!should_continue) {
            break;
        }

        size_t bytes_read = 0;
        esp_err_t read_err = board_support_audio_read(client->board, frame, RECORDING_CAPTURE_FRAME_BYTES, &bytes_read, 250);
        if (read_err != ESP_OK) {
            if (read_err == ESP_ERR_TIMEOUT) {
                continue;
            }
            client_set_state(client, "error", "Recording error", "Microphone capture stopped unexpectedly.");
            SemaphoreHandle_t update_lock = client_lock(client);
            if (update_lock != NULL && xSemaphoreTake(update_lock, pdMS_TO_TICKS(1000)) == pdTRUE) {
                client->failed_uploads += 1;
                client->active = false;
                client->stopping = true;
                xSemaphoreGive(update_lock);
            }
            break;
        }
        if (bytes_read == 0) {
            continue;
        }
        if (pcm_used == 0) {
            chunk_start_ms = (uint32_t)((esp_timer_get_time() / 1000LL) - client->started_at_ms);
        }
        if (pcm_used + bytes_read > RECORDING_CHUNK_PCM_BYTES) {
            bytes_read = RECORDING_CHUNK_PCM_BYTES - pcm_used;
        }
        memcpy(pcm_chunk + pcm_used, frame, bytes_read);
        pcm_used += bytes_read;

        if (pcm_used >= RECORDING_CHUNK_PCM_BYTES || (should_stop && pcm_used > 0)) {
            size_t wav_length = 0;
            uint8_t *wav_bytes = build_wav_chunk(client, pcm_chunk, pcm_used, &wav_length);
            if (wav_bytes == NULL) {
                client_set_state(client, "error", "Recording error", "Chunk encoding failed.");
                break;
            }
            recording_upload_item_t item = {0};
            SemaphoreHandle_t sequence_lock = client_lock(client);
            if (sequence_lock != NULL && xSemaphoreTake(sequence_lock, pdMS_TO_TICKS(1000)) == pdTRUE) {
                item.sequence_index = client->next_sequence++;
                item.start_ms = chunk_start_ms;
                item.end_ms = (uint32_t)((esp_timer_get_time() / 1000LL) - client->started_at_ms);
                item.finalize_after_upload = should_stop;
                snprintf(item.stop_reason, sizeof(item.stop_reason), "%s", should_stop && client->stop_reason[0] != '\0' ? client->stop_reason : "ended");
                client->upload_pending = true;
                xSemaphoreGive(sequence_lock);
            }
            item.wav_bytes = wav_bytes;
            item.wav_length = wav_length;
            if (xQueueSend(queue, &item, pdMS_TO_TICKS(1500)) != pdTRUE) {
                free(wav_bytes);
                client_set_state(client, "error", "Recording backlog", "Upload queue is full.");
                break;
            }
            pcm_used = 0;
            if (should_stop) {
                break;
            }
        }
    }

done:
    if (frame != NULL) {
        free(frame);
    }
    if (pcm_chunk != NULL) {
        free(pcm_chunk);
    }
    TaskHandle_t self = xTaskGetCurrentTaskHandle();
    SemaphoreHandle_t lock = client_lock(client);
    if (lock != NULL && xSemaphoreTake(lock, pdMS_TO_TICKS(1000)) == pdTRUE) {
        client->capture_task = NULL;
        xSemaphoreGive(lock);
    }
    vTaskDelete(self);
}

static void recording_upload_task(void *arg) {
    background_recording_client_t *client = (background_recording_client_t *)arg;
    QueueHandle_t queue = client_queue(client);
    if (queue == NULL) {
        client_set_state(client, "error", "Recording unavailable", "Upload queue failed.");
        vTaskDelete(NULL);
        return;
    }

    while (true) {
        recording_upload_item_t item = {0};
        if (xQueueReceive(queue, &item, pdMS_TO_TICKS(400)) != pdTRUE) {
            bool should_exit = false;
            SemaphoreHandle_t lock = client_lock(client);
            if (lock != NULL && xSemaphoreTake(lock, pdMS_TO_TICKS(1000)) == pdTRUE) {
                should_exit = !client->active && uxQueueMessagesWaiting(queue) == 0;
                xSemaphoreGive(lock);
            }
            if (should_exit) {
                break;
            }
            continue;
        }

        client_set_state(client, "uploading", "Syncing recording", "Uploading encrypted audio chunks.");
        esp_err_t upload_err = upload_chunk(client, &item);
        if (upload_err != ESP_OK) {
            ESP_LOGW(TAG, "chunk upload failed: %s", esp_err_to_name(upload_err));
            SemaphoreHandle_t lock = client_lock(client);
            if (lock != NULL && xSemaphoreTake(lock, pdMS_TO_TICKS(1000)) == pdTRUE) {
                client->failed_uploads += 1;
                client->active = false;
                client->stopping = true;
                client->upload_pending = false;
                client_set_state_locked(client, "error", "Recording sync failed", "Could not upload audio to NeoAgent.");
                xSemaphoreGive(lock);
            }
            free(item.wav_bytes);
            break;
        }
        free(item.wav_bytes);

        SemaphoreHandle_t lock = client_lock(client);
        if (lock != NULL && xSemaphoreTake(lock, pdMS_TO_TICKS(1000)) == pdTRUE) {
            client->uploaded_chunks += 1;
            client->upload_pending = uxQueueMessagesWaiting(queue) > 0;
            client_set_state_locked(client, item.finalize_after_upload ? "stopping" : "recording", item.finalize_after_upload ? "Finishing recording" : "Recording active", item.finalize_after_upload ? "Wrapping up the final chunk." : "Background capture is running.");
            xSemaphoreGive(lock);
        }

        if (item.finalize_after_upload) {
            esp_err_t finalize_err = finalize_session(client, item.stop_reason);
            lock = client_lock(client);
            if (lock != NULL && xSemaphoreTake(lock, pdMS_TO_TICKS(1000)) == pdTRUE) {
                if (finalize_err == ESP_OK) {
                    client_set_state_locked(client, "idle", "Recording ready", "Tap to start a new background capture.");
                    reset_runtime_state_locked(client);
                } else {
                    client->failed_uploads += 1;
                    client_set_state_locked(client, "error", "Finalize failed", "Audio uploaded, but the session could not be finalized.");
                    reset_runtime_state_locked(client);
                }
                xSemaphoreGive(lock);
            }
            while (xQueueReceive(queue, &item, 0) == pdTRUE) {
                free(item.wav_bytes);
            }
            break;
        }
    }

    SemaphoreHandle_t lock = client_lock(client);
    if (lock != NULL && xSemaphoreTake(lock, pdMS_TO_TICKS(1000)) == pdTRUE) {
        client->upload_task = NULL;
        if (!client->active && !client->stopping && strcmp(client->state, "idle") != 0 && strcmp(client->state, "error") != 0) {
            client_set_state_locked(client, "idle", "Recording ready", "Tap to start a new background capture.");
        }
        xSemaphoreGive(lock);
    }
    vTaskDelete(NULL);
}

esp_err_t background_recording_client_init(background_recording_client_t *client, board_support_t *board) {
    if (client == NULL || board == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    memset(client, 0, sizeof(*client));
    client->board = board;
    client->state_lock = xSemaphoreCreateMutex();
    if (client->state_lock == NULL) {
        return ESP_ERR_NO_MEM;
    }
    client->upload_queue = xQueueCreate(RECORDING_UPLOAD_QUEUE_DEPTH, sizeof(recording_upload_item_t));
    if (client->upload_queue == NULL) {
        vSemaphoreDelete((SemaphoreHandle_t)client->state_lock);
        client->state_lock = NULL;
        return ESP_ERR_NO_MEM;
    }
    snprintf(client->state, sizeof(client->state), "idle");
    snprintf(client->status, sizeof(client->status), "Recording ready");
    snprintf(client->detail, sizeof(client->detail), "Tap to start a new background capture.");
    client->stop_reason[0] = '\0';
    return ESP_OK;
}

esp_err_t background_recording_client_start(
    background_recording_client_t *client,
    const char *server_url,
    const neoagent_session_state_t *session,
    const char *device_label
) {
    if (client == NULL || server_url == NULL || session == NULL || !session->authenticated || session->session_cookie[0] == '\0') {
        return ESP_ERR_INVALID_ARG;
    }
    if (!board_support_audio_is_ready(client->board)) {
        client_set_state(client, "error", "Microphone unavailable", "Audio hardware is not ready.");
        return ESP_ERR_INVALID_STATE;
    }

    SemaphoreHandle_t lock = client_lock(client);
    if (lock == NULL || xSemaphoreTake(lock, pdMS_TO_TICKS(1000)) != pdTRUE) {
        return ESP_ERR_TIMEOUT;
    }
    if (client->active || client->starting || client->stopping) {
        xSemaphoreGive(lock);
        return ESP_ERR_INVALID_STATE;
    }
    snprintf(client->server_url, sizeof(client->server_url), "%s", server_url);
    snprintf(client->session_cookie, sizeof(client->session_cookie), "%s", session->session_cookie);
    snprintf(client->device_label, sizeof(client->device_label), "%s", device_label != NULL ? device_label : "");
    client->starting = true;
    client->active = false;
    client->stopping = false;
    client->session_ready = false;
    client->upload_pending = false;
    client->uploaded_chunks = 0;
    client->failed_uploads = 0;
    client->next_sequence = 0;
    client->stop_reason[0] = '\0';
    client_set_state_locked(client, "starting", "Starting recording", "Creating a background recording session.");
    xSemaphoreGive(lock);

    esp_err_t create_err = create_recording_session(client);
    if (create_err != ESP_OK) {
        lock = client_lock(client);
        if (lock != NULL && xSemaphoreTake(lock, pdMS_TO_TICKS(1000)) == pdTRUE) {
            client->starting = false;
            client->session_ready = false;
            client->failed_uploads += 1;
            client_set_state_locked(client, "error", "Recording start failed", "Could not create a recording session.");
            xSemaphoreGive(lock);
        }
        return create_err;
    }

    lock = client_lock(client);
    if (lock == NULL || xSemaphoreTake(lock, pdMS_TO_TICKS(1000)) != pdTRUE) {
        return ESP_ERR_TIMEOUT;
    }
    client->starting = false;
    client->active = true;
    client->stopping = false;
    client->session_ready = true;
    client->started_at_ms = esp_timer_get_time() / 1000LL;
    client_set_state_locked(client, "recording", "Recording active", "Background capture is running.");
    xSemaphoreGive(lock);

    if (xTaskCreate(recording_capture_task, "rec_capture", 8192, client, 4, (TaskHandle_t *)&client->capture_task) != pdPASS) {
        lock = client_lock(client);
        if (lock != NULL && xSemaphoreTake(lock, pdMS_TO_TICKS(1000)) == pdTRUE) {
            client->active = false;
            client->session_ready = false;
            client_set_state_locked(client, "error", "Recording unavailable", "Could not start microphone capture.");
            xSemaphoreGive(lock);
        }
        return ESP_ERR_NO_MEM;
    }
    if (xTaskCreate(recording_upload_task, "rec_upload", 8192, client, 4, (TaskHandle_t *)&client->upload_task) != pdPASS) {
        if (client->capture_task != NULL) {
            vTaskDelete((TaskHandle_t)client->capture_task);
            client->capture_task = NULL;
        }
        lock = client_lock(client);
        if (lock != NULL && xSemaphoreTake(lock, pdMS_TO_TICKS(1000)) == pdTRUE) {
            client->upload_task = NULL;
            client->active = false;
            client->session_ready = false;
            client_set_state_locked(client, "error", "Recording unavailable", "Could not start upload processing.");
            xSemaphoreGive(lock);
        }
        return ESP_ERR_NO_MEM;
    }
    return ESP_OK;
}

esp_err_t background_recording_client_stop(background_recording_client_t *client, const char *stop_reason) {
    if (client == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    SemaphoreHandle_t lock = client_lock(client);
    if (lock == NULL || xSemaphoreTake(lock, pdMS_TO_TICKS(1000)) != pdTRUE) {
        return ESP_ERR_TIMEOUT;
    }
    if (!client->active && !client->starting) {
        xSemaphoreGive(lock);
        return ESP_ERR_INVALID_STATE;
    }
    client->starting = false;
    client->stopping = true;
    snprintf(client->stop_reason, sizeof(client->stop_reason), "%s", stop_reason != NULL && stop_reason[0] != '\0' ? stop_reason : "ended");
    client_set_state_locked(client, "stopping", "Finishing recording", "Wrapping up the final chunk.");
    xSemaphoreGive(lock);
    return ESP_OK;
}

esp_err_t background_recording_client_snapshot(background_recording_client_t *client, background_recording_snapshot_t *snapshot) {
    if (client == NULL || snapshot == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    SemaphoreHandle_t lock = client_lock(client);
    if (lock == NULL || xSemaphoreTake(lock, pdMS_TO_TICKS(1000)) != pdTRUE) {
        return ESP_ERR_TIMEOUT;
    }
    memset(snapshot, 0, sizeof(*snapshot));
    snapshot->active = client->active;
    snapshot->starting = client->starting;
    snapshot->stopping = client->stopping;
    snapshot->upload_pending = client->upload_pending;
    snapshot->session_ready = client->session_ready;
    snapshot->uploaded_chunks = client->uploaded_chunks;
    snapshot->failed_uploads = client->failed_uploads;
    snapshot->started_at_ms = client->started_at_ms;
    snprintf(snapshot->session_id, sizeof(snapshot->session_id), "%s", client->session_id);
    snprintf(snapshot->state, sizeof(snapshot->state), "%s", client->state);
    snprintf(snapshot->status, sizeof(snapshot->status), "%s", client->status);
    snprintf(snapshot->detail, sizeof(snapshot->detail), "%s", client->detail);
    xSemaphoreGive(lock);
    return ESP_OK;
}

bool background_recording_client_is_active(background_recording_client_t *client) {
    if (client == NULL) {
        return false;
    }
    SemaphoreHandle_t lock = client_lock(client);
    if (lock == NULL || xSemaphoreTake(lock, pdMS_TO_TICKS(250)) != pdTRUE) {
        return false;
    }
    bool active = client->active || client->starting || client->stopping;
    xSemaphoreGive(lock);
    return active;
}

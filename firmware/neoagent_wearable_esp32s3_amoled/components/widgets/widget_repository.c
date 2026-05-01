#include "widget_repository.h"

#include <string.h>

#include "cJSON.h"
#include "esp_crt_bundle.h"
#include "esp_http_client.h"

typedef struct {
    char body[8192];
    size_t body_length;
} widget_http_capture_t;

static bool url_is_https(const char *url) {
    return url != NULL && strncmp(url, "https://", 8) == 0;
}

static void build_snapshots_url(const char *server_url, char *output, size_t output_size) {
    if (output == NULL || output_size == 0) {
        return;
    }
    output[0] = '\0';
    if (server_url == NULL || server_url[0] == '\0') {
        return;
    }
    size_t base_length = strlen(server_url);
    while (base_length > 0 && server_url[base_length - 1] == '/') {
        base_length--;
    }
    const char *path = "/api/widgets/snapshots?all=true";
    if (base_length + strlen(path) + 1 > output_size) {
        return;
    }
    memcpy(output, server_url, base_length);
    output[base_length] = '\0';
    strncat(output, path, output_size - strlen(output) - 1);
}

static esp_err_t widget_http_event_handler(esp_http_client_event_t *event) {
    widget_http_capture_t *capture = (widget_http_capture_t *)event->user_data;
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

static void copy_text(char *destination, size_t destination_size, const cJSON *item) {
    if (destination == NULL || destination_size == 0) {
        return;
    }
    destination[0] = '\0';
    if (!cJSON_IsString(item) || item->valuestring == NULL) {
        return;
    }
    strncpy(destination, item->valuestring, destination_size - 1);
    destination[destination_size - 1] = '\0';
}

static esp_err_t decode_snapshot(const cJSON *entry, neoagent_widget_snapshot_t *snapshot) {
    if (entry == NULL || snapshot == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    const cJSON *widget_id = cJSON_GetObjectItemCaseSensitive(entry, "widgetId");
    const cJSON *payload = cJSON_GetObjectItemCaseSensitive(entry, "payload");
    if (!cJSON_IsString(widget_id) || !cJSON_IsObject(payload)) {
        return ESP_ERR_INVALID_RESPONSE;
    }

    memset(snapshot, 0, sizeof(*snapshot));
    copy_text(snapshot->id, sizeof(snapshot->id), widget_id);
    copy_text(snapshot->title, sizeof(snapshot->title), cJSON_GetObjectItemCaseSensitive(payload, "title"));
    copy_text(snapshot->subtitle, sizeof(snapshot->subtitle), cJSON_GetObjectItemCaseSensitive(payload, "subtitle"));
    copy_text(snapshot->body, sizeof(snapshot->body), cJSON_GetObjectItemCaseSensitive(payload, "body"));
    copy_text(snapshot->metric, sizeof(snapshot->metric), cJSON_GetObjectItemCaseSensitive(payload, "metric"));
    copy_text(snapshot->metric_label, sizeof(snapshot->metric_label), cJSON_GetObjectItemCaseSensitive(payload, "metricLabel"));

    const cJSON *rows = cJSON_GetObjectItemCaseSensitive(payload, "rows");
    if (cJSON_IsArray(rows)) {
        size_t row_count = cJSON_GetArraySize(rows);
        if (row_count > NEOAGENT_WIDGET_ROWS_MAX) {
            row_count = NEOAGENT_WIDGET_ROWS_MAX;
        }
        for (size_t index = 0; index < row_count; ++index) {
            const cJSON *row = cJSON_GetArrayItem(rows, (int)index);
            if (!cJSON_IsObject(row)) {
                continue;
            }
            copy_text(snapshot->rows[index].label, sizeof(snapshot->rows[index].label), cJSON_GetObjectItemCaseSensitive(row, "label"));
            copy_text(snapshot->rows[index].value, sizeof(snapshot->rows[index].value), cJSON_GetObjectItemCaseSensitive(row, "value"));
            snapshot->row_count += 1;
        }
    }
    return snapshot->title[0] != '\0' ? ESP_OK : ESP_ERR_INVALID_RESPONSE;
}

esp_err_t widget_repository_init(widget_repository_t *repository) {
    if (repository == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    memset(repository, 0, sizeof(*repository));
    repository->stale = true;
    return ESP_OK;
}

esp_err_t widget_repository_upsert(widget_repository_t *repository, const neoagent_widget_snapshot_t *snapshot) {
    if (repository == NULL || snapshot == NULL || snapshot->id[0] == '\0') {
        return ESP_ERR_INVALID_ARG;
    }
    for (size_t index = 0; index < repository->count; ++index) {
        if (strncmp(repository->items[index].id, snapshot->id, sizeof(repository->items[index].id)) == 0) {
            repository->items[index] = *snapshot;
            repository->stale = false;
            return ESP_OK;
        }
    }
    if (repository->count >= NEOAGENT_WIDGET_CACHE_MAX) {
        return ESP_ERR_NO_MEM;
    }
    repository->items[repository->count++] = *snapshot;
    repository->stale = false;
    return ESP_OK;
}

const neoagent_widget_snapshot_t *widget_repository_get(const widget_repository_t *repository, size_t index) {
    if (repository == NULL || index >= repository->count) {
        return NULL;
    }
    return &repository->items[index];
}

esp_err_t widget_repository_refresh(widget_repository_t *repository, const char *server_url, const neoagent_session_state_t *session) {
    if (repository == NULL || server_url == NULL || session == NULL || !session->authenticated || session->session_cookie[0] == '\0') {
        return ESP_ERR_INVALID_ARG;
    }

    char url[NEOAGENT_SERVER_URL_MAX + 64];
    build_snapshots_url(server_url, url, sizeof(url));
    if (url[0] == '\0') {
        return ESP_ERR_INVALID_ARG;
    }

    widget_http_capture_t *capture = calloc(1, sizeof(*capture));
    if (capture == NULL) {
        return ESP_ERR_NO_MEM;
    }
    esp_http_client_config_t config = {
        .url = url,
        .method = HTTP_METHOD_GET,
        .event_handler = widget_http_event_handler,
        .user_data = capture,
        .timeout_ms = 12000,
        .buffer_size = 1024,
    };
    if (url_is_https(url)) {
        config.crt_bundle_attach = esp_crt_bundle_attach;
    }

    esp_http_client_handle_t client = esp_http_client_init(&config);
    if (client == NULL) {
        free(capture);
        return ESP_ERR_NO_MEM;
    }
    esp_http_client_set_header(client, "Cookie", session->session_cookie);
    esp_err_t err = esp_http_client_perform(client);
    int status_code = esp_http_client_get_status_code(client);
    esp_http_client_cleanup(client);
    if (err != ESP_OK) {
        free(capture);
        return err;
    }
    if (status_code < 200 || status_code >= 300) {
        free(capture);
        return ESP_FAIL;
    }

    cJSON *root = cJSON_Parse(capture->body);
    free(capture);
    if (!cJSON_IsArray(root)) {
        cJSON_Delete(root);
        return ESP_ERR_INVALID_RESPONSE;
    }

    widget_repository_t staged = {0};
    staged.stale = true;
    const size_t total = cJSON_GetArraySize(root);
    for (size_t index = 0; index < total && staged.count < NEOAGENT_WIDGET_CACHE_MAX; ++index) {
        neoagent_widget_snapshot_t snapshot = {0};
        if (decode_snapshot(cJSON_GetArrayItem(root, (int)index), &snapshot) == ESP_OK) {
            widget_repository_upsert(&staged, &snapshot);
        }
    }
    cJSON_Delete(root);
    if (staged.count == 0) {
        return ESP_ERR_NOT_FOUND;
    }
    repository->count = staged.count;
    repository->stale = staged.stale;
    memcpy(repository->items, staged.items, sizeof(staged.items));
    return ESP_OK;
}

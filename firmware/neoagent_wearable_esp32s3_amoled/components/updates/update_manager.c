#include "update_manager.h"

#include <string.h>

#include "cJSON.h"
#include "esp_app_desc.h"
#include "esp_crt_bundle.h"
#include "esp_http_client.h"
#include "esp_https_ota.h"
#include "esp_log.h"

static const char *TAG = "UpdateManager";

typedef struct {
    char body[8192];
    size_t body_length;
} update_http_capture_t;

static bool url_is_https(const char *url) {
    return url != NULL && strncmp(url, "https://", 8) == 0;
}

static void build_endpoint_url(const char *base_url, const char *path, char *output, size_t output_size) {
    if (output == NULL || output_size == 0) {
        return;
    }
    output[0] = '\0';
    if (base_url == NULL || base_url[0] == '\0' || path == NULL) {
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

static esp_err_t update_http_event_handler(esp_http_client_event_t *event) {
    update_http_capture_t *capture = (update_http_capture_t *)event->user_data;
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

static const char *trim_version_prefix(const char *version) {
    if (version == NULL) {
        return "";
    }
    if (version[0] == 'v' || version[0] == 'V') {
        return version + 1;
    }
    return version;
}

static bool version_equals(const char *left, const char *right) {
    return strcmp(trim_version_prefix(left), trim_version_prefix(right)) == 0;
}

static void copy_channel(char *destination, size_t destination_size, const char *value) {
    if (destination == NULL || destination_size == 0) {
        return;
    }
    destination[0] = '\0';
    if (value == NULL || value[0] == '\0') {
        strncpy(destination, "stable", destination_size - 1);
        destination[destination_size - 1] = '\0';
        return;
    }
    const char *normalized = value;
    if (strncmp(value, "beta", 4) == 0) {
        normalized = "beta";
    } else {
        normalized = "stable";
    }
    strncpy(destination, normalized, destination_size - 1);
    destination[destination_size - 1] = '\0';
}

static const char *normalized_channel(const char *value) {
    return value != NULL && strncmp(value, "beta", 4) == 0 ? "beta" : "stable";
}

static esp_err_t fetch_json(const char *url, const char *cookie, update_http_capture_t *capture, int *status_code) {
    if (url == NULL || capture == NULL) {
        return ESP_ERR_INVALID_ARG;
    }

    memset(capture, 0, sizeof(*capture));
    esp_http_client_config_t config = {
        .url = url,
        .method = HTTP_METHOD_GET,
        .event_handler = update_http_event_handler,
        .user_data = capture,
        .timeout_ms = 12000,
        .buffer_size = 1024,
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
    esp_err_t err = esp_http_client_perform(client);
    if (status_code != NULL) {
        *status_code = esp_http_client_get_status_code(client);
    }
    esp_http_client_cleanup(client);
    return err;
}

static esp_err_t parse_manifest(const char *json_body, update_manager_t *manager) {
    cJSON *root = cJSON_Parse(json_body);
    if (root == NULL) {
        return ESP_ERR_INVALID_RESPONSE;
    }

    const cJSON *configured = cJSON_GetObjectItemCaseSensitive(root, "configured");
    const cJSON *current_version = cJSON_GetObjectItemCaseSensitive(root, "currentVersion");
    const cJSON *download_url = cJSON_GetObjectItemCaseSensitive(root, "downloadUrl");
    const cJSON *release_notes_url = cJSON_GetObjectItemCaseSensitive(root, "releaseNotesUrl");
    const cJSON *mandatory = cJSON_GetObjectItemCaseSensitive(root, "mandatory");

    memset(manager->download_url, 0, sizeof(manager->download_url));
    memset(manager->latest_version, 0, sizeof(manager->latest_version));
    memset(manager->release_notes_url, 0, sizeof(manager->release_notes_url));

    copy_text(manager->latest_version, sizeof(manager->latest_version), current_version);
    copy_text(manager->download_url, sizeof(manager->download_url), download_url);
    copy_text(manager->release_notes_url, sizeof(manager->release_notes_url), release_notes_url);
    manager->mandatory = cJSON_IsTrue(mandatory);
    manager->configured = cJSON_IsTrue(configured);

    cJSON_Delete(root);
    if (manager->latest_version[0] == '\0' || manager->download_url[0] == '\0') {
        return ESP_ERR_NOT_FOUND;
    }
    return ESP_OK;
}

static const char *current_channel(const update_manager_t *manager) {
    if (manager == NULL || manager->channel[0] == '\0') {
        return "stable";
    }
    return manager->channel;
}

esp_err_t update_manager_init(update_manager_t *manager, const char *current_version) {
    if (manager == NULL || current_version == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    memset(manager, 0, sizeof(*manager));
    strncpy(manager->current_version, current_version, sizeof(manager->current_version) - 1);
    copy_channel(manager->channel, sizeof(manager->channel), "stable");
    return ESP_OK;
}

const char *update_manager_current_version(const update_manager_t *manager) {
    if (manager == NULL || manager->current_version[0] == '\0') {
        return "unknown";
    }
    return manager->current_version;
}

const char *update_manager_channel(const update_manager_t *manager) {
    return current_channel(manager);
}

esp_err_t update_manager_set_channel(update_manager_t *manager, const char *channel) {
    if (manager == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    copy_channel(manager->channel, sizeof(manager->channel), channel);
    return ESP_OK;
}

esp_err_t update_manager_auto_update(update_manager_t *manager, const char *server_url, const neoagent_session_state_t *session) {
    if (manager == NULL || server_url == NULL || server_url[0] == '\0' || session == NULL ||
        !session->authenticated || session->session_cookie[0] == '\0') {
        return ESP_ERR_INVALID_ARG;
    }

    char manifest_url[NEOAGENT_SERVER_URL_MAX + 64];
    char path[64];
    snprintf(path, sizeof(path), "/api/wearable/firmware/manifest?channel=%s", normalized_channel(current_channel(manager)));
    build_endpoint_url(server_url, path, manifest_url, sizeof(manifest_url));
    if (manifest_url[0] == '\0') {
        return ESP_ERR_INVALID_ARG;
    }

    update_http_capture_t *capture = calloc(1, sizeof(*capture));
    if (capture == NULL) {
        return ESP_ERR_NO_MEM;
    }
    int status_code = 0;
    esp_err_t err = fetch_json(manifest_url, session->session_cookie, capture, &status_code);
    if (err != ESP_OK) {
        ESP_LOGW(TAG, "manifest fetch failed: %s", esp_err_to_name(err));
        free(capture);
        return err;
    }
    if (status_code < 200 || status_code >= 300) {
        ESP_LOGW(TAG, "manifest fetch returned http=%d body=%s", status_code, capture->body);
        free(capture);
        return ESP_FAIL;
    }

    err = parse_manifest(capture->body, manager);
    free(capture);
    if (err != ESP_OK) {
        ESP_LOGW(TAG, "manifest parse failed: %s", esp_err_to_name(err));
        return err;
    }

    if (version_equals(manager->current_version, manager->latest_version)) {
        ESP_LOGI(TAG, "firmware already current version=%s", manager->current_version);
        return ESP_ERR_INVALID_STATE;
    }

    esp_http_client_config_t http_config = {
        .url = manager->download_url,
        .method = HTTP_METHOD_GET,
        .timeout_ms = 60000,
        .user_agent = "NeoAgentWearable/ota",
        .keep_alive_enable = true,
    };
    if (url_is_https(manager->download_url)) {
        http_config.crt_bundle_attach = esp_crt_bundle_attach;
    }

    esp_https_ota_config_t ota_config = {
        .http_config = &http_config,
    };

    ESP_LOGI(
        TAG,
        "starting ota current=%s latest=%s mandatory=%d download=%s",
        manager->current_version,
        manager->latest_version,
        manager->mandatory,
        manager->download_url
    );
    err = esp_https_ota(&ota_config);
    if (err != ESP_OK) {
        ESP_LOGW(TAG, "ota failed: %s", esp_err_to_name(err));
    }
    return err;
}

#include "pairing_manager.h"

#include <stdio.h>
#include <string.h>

#include "cJSON.h"
#include "esp_crt_bundle.h"
#include "esp_http_client.h"
#include "esp_log.h"

static const char *TAG = "Pairing";

typedef struct {
    char body[2048];
    size_t body_length;
    char set_cookie[NEOAGENT_SESSION_COOKIE_MAX];
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
    } else if (event->event_id == HTTP_EVENT_ON_HEADER && event->header_key != NULL && event->header_value != NULL &&
               strcasecmp(event->header_key, "Set-Cookie") == 0) {
        const char *separator = strchr(event->header_value, ';');
        size_t cookie_length = separator != NULL ? (size_t)(separator - event->header_value) : strlen(event->header_value);
        if (cookie_length >= sizeof(capture->set_cookie)) {
            cookie_length = sizeof(capture->set_cookie) - 1;
        }
        memcpy(capture->set_cookie, event->header_value, cookie_length);
        capture->set_cookie[cookie_length] = '\0';
    }
    return ESP_OK;
}

static esp_err_t perform_json_post(const char *url, const char *body, http_capture_t *capture, int *status_code) {
    if (url == NULL || body == NULL || capture == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    memset(capture, 0, sizeof(*capture));

    esp_http_client_config_t config = {
        .url = url,
        .method = HTTP_METHOD_POST,
        .event_handler = http_event_handler,
        .user_data = capture,
        .timeout_ms = 12000,
        .buffer_size = 2048,
    };
    if (url_is_https(url)) {
        config.crt_bundle_attach = esp_crt_bundle_attach;
    }

    esp_http_client_handle_t client = esp_http_client_init(&config);
    if (client == NULL) {
        return ESP_ERR_NO_MEM;
    }
    esp_http_client_set_header(client, "Content-Type", "application/json");
    esp_http_client_set_post_field(client, body, (int)strlen(body));
    esp_err_t err = esp_http_client_perform(client);
    if (status_code != NULL) {
        *status_code = esp_http_client_get_status_code(client);
    }
    esp_http_client_cleanup(client);
    return err;
}

static esp_err_t parse_challenge_response(const char *json_body, neoagent_pairing_state_t *state) {
    cJSON *root = cJSON_Parse(json_body);
    if (root == NULL) {
        return ESP_ERR_INVALID_RESPONSE;
    }
    cJSON *challenge_id = cJSON_GetObjectItemCaseSensitive(root, "challengeId");
    cJSON *poll_token = cJSON_GetObjectItemCaseSensitive(root, "pollToken");
    cJSON *qr_payload = cJSON_GetObjectItemCaseSensitive(root, "qrPayload");
    cJSON *expires_at = cJSON_GetObjectItemCaseSensitive(root, "expiresAt");
    if (!cJSON_IsString(challenge_id) || !cJSON_IsString(poll_token) || !cJSON_IsString(qr_payload)) {
        cJSON_Delete(root);
        return ESP_ERR_INVALID_RESPONSE;
    }

    memset(state, 0, sizeof(*state));
    strlcpy(state->challenge_id, challenge_id->valuestring, sizeof(state->challenge_id));
    strlcpy(state->poll_token, poll_token->valuestring, sizeof(state->poll_token));
    strlcpy(state->qr_payload, qr_payload->valuestring, sizeof(state->qr_payload));
    if (cJSON_IsString(expires_at)) {
        strlcpy(state->expires_at, expires_at->valuestring, sizeof(state->expires_at));
    }
    state->pending = true;
    cJSON_Delete(root);
    return ESP_OK;
}

static esp_err_t parse_status_response(const char *json_body, pairing_flow_state_t *state_out) {
    cJSON *root = cJSON_Parse(json_body);
    if (root == NULL) {
        return ESP_ERR_INVALID_RESPONSE;
    }
    cJSON *status = cJSON_GetObjectItemCaseSensitive(root, "status");
    if (!cJSON_IsString(status)) {
        cJSON_Delete(root);
        return ESP_ERR_INVALID_RESPONSE;
    }

    if (strcmp(status->valuestring, "approved") == 0) {
        *state_out = PAIRING_STATE_APPROVED;
    } else if (strcmp(status->valuestring, "claimed") == 0) {
        *state_out = PAIRING_STATE_CLAIMED;
    } else if (strcmp(status->valuestring, "expired") == 0) {
        *state_out = PAIRING_STATE_EXPIRED;
    } else {
        *state_out = PAIRING_STATE_QR_READY;
    }
    cJSON_Delete(root);
    return ESP_OK;
}

static esp_err_t parse_claim_response(const char *json_body, const char *session_cookie, neoagent_session_state_t *session) {
    if (session == NULL || session_cookie == NULL || session_cookie[0] == '\0') {
        return ESP_ERR_INVALID_RESPONSE;
    }
    cJSON *root = cJSON_Parse(json_body);
    if (root == NULL) {
        return ESP_ERR_INVALID_RESPONSE;
    }
    cJSON *user = cJSON_GetObjectItemCaseSensitive(root, "user");
    cJSON *user_id = user != NULL ? cJSON_GetObjectItemCaseSensitive(user, "id") : NULL;
    cJSON *username = user != NULL ? cJSON_GetObjectItemCaseSensitive(user, "username") : NULL;
    if (!cJSON_IsNumber(user_id) || !cJSON_IsString(username)) {
        cJSON_Delete(root);
        return ESP_ERR_INVALID_RESPONSE;
    }

    memset(session, 0, sizeof(*session));
    session->authenticated = true;
    strlcpy(session->session_cookie, session_cookie, sizeof(session->session_cookie));
    strlcpy(session->username, username->valuestring, sizeof(session->username));
    snprintf(session->user_id, sizeof(session->user_id), "%.0f", user_id->valuedouble);
    cJSON_Delete(root);
    return ESP_OK;
}

esp_err_t pairing_manager_init(pairing_manager_t *manager) {
    if (manager == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    memset(manager, 0, sizeof(*manager));
    manager->state = PAIRING_STATE_IDLE;
    return ESP_OK;
}

esp_err_t pairing_manager_set_challenge(pairing_manager_t *manager, const neoagent_pairing_state_t *challenge) {
    if (manager == NULL || challenge == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    manager->qr_state = *challenge;
    manager->state = PAIRING_STATE_QR_READY;
    return ESP_OK;
}

esp_err_t pairing_manager_create_challenge(pairing_manager_t *manager, const char *server_url, const char *device_label) {
    if (manager == NULL || server_url == NULL || server_url[0] == '\0') {
        return ESP_ERR_INVALID_ARG;
    }
    char url[NEOAGENT_SERVER_URL_MAX + 64];
    char body[256];
    http_capture_t capture;
    int status_code = 0;
    build_endpoint_url(server_url, "/api/auth/qr-login/challenge", url, sizeof(url));
    snprintf(body, sizeof(body), "{\"requestMetadata\":{\"deviceType\":\"wearable\",\"platform\":\"esp32-s3-amoled\",\"deviceLabel\":\"%s\"}}",
             device_label != NULL ? device_label : "NeoAgent wearable");
    esp_err_t err = perform_json_post(url, body, &capture, &status_code);
    if (err != ESP_OK || status_code < 200 || status_code >= 300) {
        ESP_LOGE(TAG, "challenge request failed err=%s status=%d body=%s", esp_err_to_name(err), status_code, capture.body);
        return err != ESP_OK ? err : ESP_FAIL;
    }
    err = parse_challenge_response(capture.body, &manager->qr_state);
    if (err == ESP_OK) {
        manager->state = PAIRING_STATE_QR_READY;
        ESP_LOGI(TAG, "pairing challenge created id=%s", manager->qr_state.challenge_id);
    }
    return err;
}

esp_err_t pairing_manager_poll_status(pairing_manager_t *manager, const char *server_url) {
    if (manager == NULL || server_url == NULL || manager->qr_state.challenge_id[0] == '\0' || manager->qr_state.poll_token[0] == '\0') {
        return ESP_ERR_INVALID_ARG;
    }
    char path[160];
    char url[NEOAGENT_SERVER_URL_MAX + 160];
    char body[256];
    http_capture_t capture;
    int status_code = 0;

    snprintf(path, sizeof(path), "/api/auth/qr-login/challenge/%s/status", manager->qr_state.challenge_id);
    build_endpoint_url(server_url, path, url, sizeof(url));
    snprintf(body, sizeof(body), "{\"token\":\"%s\"}", manager->qr_state.poll_token);
    esp_err_t err = perform_json_post(url, body, &capture, &status_code);
    if (err != ESP_OK || status_code < 200 || status_code >= 300) {
        return err != ESP_OK ? err : ESP_FAIL;
    }

    pairing_flow_state_t next_state = manager->state;
    err = parse_status_response(capture.body, &next_state);
    if (err != ESP_OK) {
        return err;
    }
    manager->state = next_state;
    if (next_state == PAIRING_STATE_EXPIRED) {
        manager->qr_state.pending = false;
    }
    return ESP_OK;
}

esp_err_t pairing_manager_claim_session(pairing_manager_t *manager, const char *server_url, neoagent_session_state_t *session, session_store_t *store) {
    if (manager == NULL || server_url == NULL || session == NULL || store == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    char path[160];
    char url[NEOAGENT_SERVER_URL_MAX + 160];
    char body[256];
    http_capture_t capture;
    int status_code = 0;

    snprintf(path, sizeof(path), "/api/auth/qr-login/challenge/%s/claim", manager->qr_state.challenge_id);
    build_endpoint_url(server_url, path, url, sizeof(url));
    snprintf(body, sizeof(body), "{\"token\":\"%s\"}", manager->qr_state.poll_token);
    esp_err_t err = perform_json_post(url, body, &capture, &status_code);
    if (err != ESP_OK || status_code < 200 || status_code >= 300) {
        ESP_LOGE(TAG, "claim request failed err=%s status=%d body=%s", esp_err_to_name(err), status_code, capture.body);
        return err != ESP_OK ? err : ESP_FAIL;
    }
    err = parse_claim_response(capture.body, capture.set_cookie, session);
    if (err != ESP_OK) {
        return err;
    }
    ESP_ERROR_CHECK(session_store_save_session(store, session));
    manager->state = PAIRING_STATE_CLAIMED;
    manager->qr_state.pending = false;
    return ESP_OK;
}

void pairing_manager_mark_approved(pairing_manager_t *manager) {
    if (manager != NULL) {
        manager->state = PAIRING_STATE_APPROVED;
    }
}

void pairing_manager_mark_claimed(pairing_manager_t *manager) {
    if (manager != NULL) {
        manager->state = PAIRING_STATE_CLAIMED;
        manager->qr_state.pending = false;
    }
}

void pairing_manager_mark_expired(pairing_manager_t *manager) {
    if (manager != NULL) {
        manager->state = PAIRING_STATE_EXPIRED;
        manager->qr_state.pending = false;
    }
}

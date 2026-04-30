#include "session_store.h"

#include <string.h>

#include "esp_log.h"
#include "nvs.h"
#include "nvs_flash.h"

static const char *TAG = "SessionStore";
static const char *KEY_DEVICE_CONFIG = "device_cfg";
static const char *KEY_SESSION = "session";
static const char *DEFAULT_NAMESPACE = "neoagent";

static esp_err_t write_blob(const char *namespace_name, const char *key, const void *value, size_t value_size) {
    nvs_handle_t handle;
    esp_err_t err = nvs_open(namespace_name, NVS_READWRITE, &handle);
    if (err != ESP_OK) {
        return err;
    }
    err = nvs_set_blob(handle, key, value, value_size);
    if (err == ESP_OK) {
        err = nvs_commit(handle);
    }
    nvs_close(handle);
    return err;
}

static esp_err_t read_blob(const char *namespace_name, const char *key, void *value, size_t value_size) {
    nvs_handle_t handle;
    esp_err_t err = nvs_open(namespace_name, NVS_READONLY, &handle);
    if (err != ESP_OK) {
        return err;
    }
    size_t required_size = value_size;
    err = nvs_get_blob(handle, key, value, &required_size);
    nvs_close(handle);
    if (err == ESP_OK && required_size != value_size) {
        return ESP_ERR_NVS_INVALID_LENGTH;
    }
    return err;
}

static const char *namespace_for(const session_store_t *store) {
    if (store == NULL || store->config.namespace_name[0] == '\0') {
        return DEFAULT_NAMESPACE;
    }
    return store->config.namespace_name;
}

esp_err_t session_store_init(session_store_t *store, const session_store_config_t *config) {
    if (store == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    memset(store, 0, sizeof(*store));
    if (config != NULL) {
        store->config = *config;
    }
    if (store->config.namespace_name[0] == '\0') {
        strncpy(store->config.namespace_name, DEFAULT_NAMESPACE, sizeof(store->config.namespace_name) - 1);
    }

    esp_err_t err = nvs_flash_init();
    if (err == ESP_ERR_NVS_NO_FREE_PAGES || err == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        err = nvs_flash_init();
    }
    if (err == ESP_OK) {
        store->initialized = true;
        ESP_LOGI(TAG, "NVS store ready");
    }
    return err;
}

esp_err_t session_store_save_device_config(session_store_t *store, const neoagent_device_config_t *config) {
    if (store == NULL || config == NULL || !store->initialized) {
        return ESP_ERR_INVALID_STATE;
    }
    return write_blob(namespace_for(store), KEY_DEVICE_CONFIG, config, sizeof(*config));
}

esp_err_t session_store_load_device_config(session_store_t *store, neoagent_device_config_t *config) {
    if (store == NULL || config == NULL || !store->initialized) {
        return ESP_ERR_INVALID_STATE;
    }
    memset(config, 0, sizeof(*config));
    esp_err_t err = read_blob(namespace_for(store), KEY_DEVICE_CONFIG, config, sizeof(*config));
    if (err == ESP_ERR_NVS_NOT_FOUND) {
        return ESP_ERR_NOT_FOUND;
    }
    return err;
}

esp_err_t session_store_save_session(session_store_t *store, const neoagent_session_state_t *session) {
    if (store == NULL || session == NULL || !store->initialized) {
        return ESP_ERR_INVALID_STATE;
    }
    return write_blob(namespace_for(store), KEY_SESSION, session, sizeof(*session));
}

esp_err_t session_store_load_session(session_store_t *store, neoagent_session_state_t *session) {
    if (store == NULL || session == NULL || !store->initialized) {
        return ESP_ERR_INVALID_STATE;
    }
    memset(session, 0, sizeof(*session));
    esp_err_t err = read_blob(namespace_for(store), KEY_SESSION, session, sizeof(*session));
    if (err == ESP_ERR_NVS_NOT_FOUND) {
        return ESP_ERR_NOT_FOUND;
    }
    return err;
}

esp_err_t session_store_clear_session(session_store_t *store) {
    if (store == NULL || !store->initialized) {
        return ESP_ERR_INVALID_STATE;
    }
    nvs_handle_t handle;
    esp_err_t err = nvs_open(namespace_for(store), NVS_READWRITE, &handle);
    if (err != ESP_OK) {
        return err;
    }
    err = nvs_erase_key(handle, KEY_SESSION);
    if (err == ESP_OK || err == ESP_ERR_NVS_NOT_FOUND) {
        err = nvs_commit(handle);
    }
    nvs_close(handle);
    return err;
}

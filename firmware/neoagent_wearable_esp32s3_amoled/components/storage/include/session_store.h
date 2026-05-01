#pragma once

#include <stdbool.h>

#include "esp_err.h"
#include "neoagent_wearable_types.h"

#define NEOAGENT_NAMESPACE_MAX 16

typedef struct {
    char namespace_name[NEOAGENT_NAMESPACE_MAX];
} session_store_config_t;

typedef struct {
    session_store_config_t config;
    bool initialized;
} session_store_t;

esp_err_t session_store_init(session_store_t *store, const session_store_config_t *config);
esp_err_t session_store_save_device_config(session_store_t *store, const neoagent_device_config_t *config);
esp_err_t session_store_load_device_config(session_store_t *store, neoagent_device_config_t *config);
esp_err_t session_store_save_firmware_update_settings(session_store_t *store, const neoagent_firmware_update_settings_t *settings);
esp_err_t session_store_load_firmware_update_settings(session_store_t *store, neoagent_firmware_update_settings_t *settings);
esp_err_t session_store_save_session(session_store_t *store, const neoagent_session_state_t *session);
esp_err_t session_store_load_session(session_store_t *store, neoagent_session_state_t *session);
esp_err_t session_store_clear_device_config(session_store_t *store);
esp_err_t session_store_clear_firmware_update_settings(session_store_t *store);
esp_err_t session_store_clear_session(session_store_t *store);

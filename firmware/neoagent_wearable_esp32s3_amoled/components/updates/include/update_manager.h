#pragma once

#include <stdbool.h>
#include <stddef.h>

#include "esp_err.h"
#include "neoagent_wearable_types.h"

typedef struct {
    char current_version[64];
    char channel[NEOAGENT_FIRMWARE_CHANNEL_MAX];
    char download_url[256];
    char latest_version[64];
    char release_notes_url[256];
    bool mandatory;
    bool configured;
} update_manager_t;

esp_err_t update_manager_init(update_manager_t *manager, const char *current_version);
const char *update_manager_current_version(const update_manager_t *manager);
const char *update_manager_channel(const update_manager_t *manager);
esp_err_t update_manager_set_channel(update_manager_t *manager, const char *channel);
esp_err_t update_manager_auto_update(update_manager_t *manager, const char *server_url, const neoagent_session_state_t *session);

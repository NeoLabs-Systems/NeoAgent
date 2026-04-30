#pragma once

#include <stdbool.h>

#include "esp_err.h"

typedef struct {
    char current_version[64];
    char download_url[256];
    bool mandatory;
} update_manager_t;

esp_err_t update_manager_init(update_manager_t *manager, const char *current_version);

#pragma once

#include "esp_err.h"
#include "neoagent_wearable_types.h"

typedef struct {
    neoagent_screen_id_t current_screen;
    bool ready;
} app_shell_t;

esp_err_t app_shell_init(app_shell_t *shell, neoagent_screen_id_t initial_screen);

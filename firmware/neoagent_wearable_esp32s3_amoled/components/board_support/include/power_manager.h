#pragma once

#include "esp_err.h"
#include "neoagent_wearable_types.h"

typedef struct {
    neoagent_status_chrome_t status;
} power_manager_t;

esp_err_t power_manager_init(power_manager_t *manager);
esp_err_t power_manager_update_battery(power_manager_t *manager, int battery_percent, bool charging);
const neoagent_status_chrome_t *power_manager_get_status(const power_manager_t *manager);

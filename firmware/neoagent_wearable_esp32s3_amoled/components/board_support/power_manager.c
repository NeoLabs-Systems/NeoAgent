#include "power_manager.h"

#include <string.h>

esp_err_t power_manager_init(power_manager_t *manager) {
    if (manager == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    memset(manager, 0, sizeof(*manager));
    return ESP_OK;
}

esp_err_t power_manager_update_battery(power_manager_t *manager, int battery_percent, bool charging) {
    if (manager == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    manager->status.battery_percent = battery_percent;
    manager->status.charging = charging;
    return ESP_OK;
}

const neoagent_status_chrome_t *power_manager_get_status(const power_manager_t *manager) {
    return manager == NULL ? NULL : &manager->status;
}

#include "update_manager.h"

#include <string.h>

esp_err_t update_manager_init(update_manager_t *manager, const char *current_version) {
    if (manager == NULL || current_version == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    memset(manager, 0, sizeof(*manager));
    strncpy(manager->current_version, current_version, sizeof(manager->current_version) - 1);
    return ESP_OK;
}

#include "widget_repository.h"

#include <string.h>

esp_err_t widget_repository_init(widget_repository_t *repository) {
    if (repository == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    memset(repository, 0, sizeof(*repository));
    repository->stale = true;
    return ESP_OK;
}

esp_err_t widget_repository_upsert(widget_repository_t *repository, const neoagent_widget_snapshot_t *snapshot) {
    if (repository == NULL || snapshot == NULL || snapshot->id[0] == '\0') {
        return ESP_ERR_INVALID_ARG;
    }
    for (size_t index = 0; index < repository->count; ++index) {
        if (strncmp(repository->items[index].id, snapshot->id, sizeof(repository->items[index].id)) == 0) {
            repository->items[index] = *snapshot;
            repository->stale = false;
            return ESP_OK;
        }
    }
    if (repository->count >= NEOAGENT_WIDGET_CACHE_MAX) {
        return ESP_ERR_NO_MEM;
    }
    repository->items[repository->count++] = *snapshot;
    repository->stale = false;
    return ESP_OK;
}

const neoagent_widget_snapshot_t *widget_repository_get(const widget_repository_t *repository, size_t index) {
    if (repository == NULL || index >= repository->count) {
        return NULL;
    }
    return &repository->items[index];
}

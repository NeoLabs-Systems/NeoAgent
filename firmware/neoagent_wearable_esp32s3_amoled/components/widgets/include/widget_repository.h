#pragma once

#include <stdbool.h>
#include <stddef.h>

#include "esp_err.h"
#include "neoagent_wearable_types.h"

#define NEOAGENT_WIDGET_CACHE_MAX 8

typedef struct {
    neoagent_widget_snapshot_t items[NEOAGENT_WIDGET_CACHE_MAX];
    size_t count;
    bool stale;
} widget_repository_t;

esp_err_t widget_repository_init(widget_repository_t *repository);
esp_err_t widget_repository_upsert(widget_repository_t *repository, const neoagent_widget_snapshot_t *snapshot);
const neoagent_widget_snapshot_t *widget_repository_get(const widget_repository_t *repository, size_t index);
esp_err_t widget_repository_refresh(widget_repository_t *repository, const char *server_url, const neoagent_session_state_t *session);

#pragma once

#include "esp_err.h"
#include "neoagent_wearable_types.h"

typedef struct {
    neoagent_screen_id_t current_screen;
} screen_router_t;

esp_err_t screen_router_init(screen_router_t *router, neoagent_screen_id_t initial_screen);
esp_err_t screen_router_navigate(screen_router_t *router, neoagent_screen_id_t next_screen);
neoagent_screen_id_t screen_router_current(const screen_router_t *router);

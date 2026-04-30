#include "screen_router.h"

esp_err_t screen_router_init(screen_router_t *router, neoagent_screen_id_t initial_screen) {
    if (router == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    router->current_screen = initial_screen;
    return ESP_OK;
}

esp_err_t screen_router_navigate(screen_router_t *router, neoagent_screen_id_t next_screen) {
    if (router == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    router->current_screen = next_screen;
    return ESP_OK;
}

neoagent_screen_id_t screen_router_current(const screen_router_t *router) {
    return router == NULL ? NEOAGENT_SCREEN_ASSISTANT : router->current_screen;
}

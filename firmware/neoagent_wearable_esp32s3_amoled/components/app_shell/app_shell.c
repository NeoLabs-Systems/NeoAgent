#include "app_shell.h"

esp_err_t app_shell_init(app_shell_t *shell, neoagent_screen_id_t initial_screen) {
    if (shell == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    shell->current_screen = initial_screen;
    shell->ready = true;
    return ESP_OK;
}

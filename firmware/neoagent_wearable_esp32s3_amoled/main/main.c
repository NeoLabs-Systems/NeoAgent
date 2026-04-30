#include <stdio.h>
#include <string.h>

#include "app_shell.h"
#include "board_support.h"
#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "pairing_manager.h"
#include "power_manager.h"
#include "provisioning_manager.h"
#include "screen_router.h"
#include "session_store.h"
#include "telemetry.h"
#include "ui_renderer.h"
#include "update_manager.h"
#include "wearable_voice_client.h"
#include "widget_repository.h"

static const char *TAG = "NeoAgentWearable";

#define NEOAGENT_RUNTIME_TASK_STACK_SIZE 24576

static session_store_t s_session_store;
static provisioning_manager_t s_provisioning;
static pairing_manager_t s_pairing;
static widget_repository_t s_widgets;
static wearable_voice_client_t s_voice_client;
static power_manager_t s_power_manager;
static screen_router_t s_router;
static app_shell_t s_shell;
static board_support_t s_board;
static ui_renderer_t s_ui;
static update_manager_t s_updates;

static esp_err_t run_pairing_flow(const neoagent_device_config_t *device_config) {
    if (device_config == NULL) {
        return ESP_ERR_INVALID_ARG;
    }

    ESP_ERROR_CHECK(screen_router_navigate(&s_router, NEOAGENT_SCREEN_PAIRING));
    ESP_ERROR_CHECK(ui_renderer_set_screen(&s_ui, screen_router_current(&s_router)));

    if (pairing_manager_create_challenge(&s_pairing, device_config->server_url, device_config->device_label) != ESP_OK) {
        ESP_LOGE(TAG, "failed to create pairing challenge");
        return ESP_FAIL;
    }
    ESP_ERROR_CHECK(ui_renderer_show_pairing_qr(&s_ui, s_pairing.qr_state.qr_payload));

    while (true) {
        vTaskDelay(pdMS_TO_TICKS(3000));
        esp_err_t poll_err = pairing_manager_poll_status(&s_pairing, device_config->server_url);
        if (poll_err != ESP_OK) {
            ESP_LOGW(TAG, "pairing poll failed: %s", esp_err_to_name(poll_err));
            continue;
        }
        if (s_pairing.state == PAIRING_STATE_APPROVED) {
            neoagent_session_state_t claimed_session = {0};
            if (pairing_manager_claim_session(&s_pairing, device_config->server_url, &claimed_session, &s_session_store) == ESP_OK) {
                ESP_LOGI(TAG, "pairing claimed for user=%s", claimed_session.username);
                ESP_ERROR_CHECK(screen_router_navigate(&s_router, NEOAGENT_SCREEN_ASSISTANT));
                ESP_ERROR_CHECK(ui_renderer_set_screen(&s_ui, screen_router_current(&s_router)));
                return ESP_OK;
            }
        } else if (s_pairing.state == PAIRING_STATE_EXPIRED) {
            ESP_LOGI(TAG, "pairing challenge expired; creating a new one");
            if (pairing_manager_create_challenge(&s_pairing, device_config->server_url, device_config->device_label) == ESP_OK) {
                ESP_ERROR_CHECK(ui_renderer_show_pairing_qr(&s_ui, s_pairing.qr_state.qr_payload));
            }
        }
    }
}

static void build_wearable_ws_url(const char *server_url, char *output, size_t output_size) {
    if (output == NULL || output_size == 0) {
        return;
    }
    output[0] = '\0';
    if (server_url == NULL || server_url[0] == '\0') {
        return;
    }
    const char *prefix = NULL;
    const char *host = NULL;
    if (strncmp(server_url, "https://", 8) == 0) {
        prefix = "wss://";
        host = server_url + 8;
    } else if (strncmp(server_url, "http://", 7) == 0) {
        prefix = "ws://";
        host = server_url + 7;
    } else {
        return;
    }
    const char *path = "/api/wearable/ws";
    const size_t prefix_len = strlen(prefix);
    const size_t host_len = strlen(host);
    const size_t path_len = strlen(path);
    if (prefix_len + host_len + path_len + 1 > output_size) {
        return;
    }
    memcpy(output, prefix, prefix_len);
    memcpy(output + prefix_len, host, host_len);
    memcpy(output + prefix_len + host_len, path, path_len);
    output[prefix_len + host_len + path_len] = '\0';
}

static void wearable_runtime_task(void *arg) {
    (void)arg;
    telemetry_log_boot("runtime_start");
    char wearable_ws_url[NEOAGENT_WS_URL_MAX] = {0};

    ESP_ERROR_CHECK(session_store_init(&s_session_store, NULL));
    ESP_ERROR_CHECK(provisioning_manager_init(&s_provisioning));
    ESP_ERROR_CHECK(pairing_manager_init(&s_pairing));
    ESP_ERROR_CHECK(widget_repository_init(&s_widgets));
    ESP_ERROR_CHECK(power_manager_init(&s_power_manager));
    ESP_ERROR_CHECK(screen_router_init(&s_router, NEOAGENT_SCREEN_PROVISIONING));
    ESP_ERROR_CHECK(app_shell_init(&s_shell, NEOAGENT_SCREEN_PROVISIONING));
    ESP_ERROR_CHECK(board_support_init(&s_board));
    ESP_ERROR_CHECK(ui_renderer_init(&s_ui, &s_board));
    ESP_ERROR_CHECK(update_manager_init(&s_updates, "0.1.0"));

    neoagent_device_config_t device_config = {0};
    neoagent_session_state_t session_state = {0};
    const esp_err_t config_err = session_store_load_device_config(&s_session_store, &device_config);
    const esp_err_t session_err = session_store_load_session(&s_session_store, &session_state);

    if (config_err == ESP_OK) {
        provisioning_manager_set_pending_config(&s_provisioning, &device_config);
        ESP_ERROR_CHECK(screen_router_navigate(&s_router, NEOAGENT_SCREEN_PAIRING));
        ESP_ERROR_CHECK(ui_renderer_set_screen(&s_ui, screen_router_current(&s_router)));
        ESP_ERROR_CHECK(board_support_show_message(&s_board, "Connecting Wi-Fi", device_config.wifi_ssid, "Waiting for network before QR pairing."));
        if (provisioning_manager_connect_station(&s_provisioning, &device_config, 20000) == ESP_OK) {
            build_wearable_ws_url(device_config.server_url, wearable_ws_url, sizeof(wearable_ws_url));
            if (wearable_ws_url[0] != '\0') {
                ESP_ERROR_CHECK(wearable_voice_client_init(&s_voice_client, wearable_ws_url));
            }
        } else {
            ESP_LOGW(TAG, "wifi connection failed; returning to setup portal");
            s_provisioning.has_pending_config = false;
            memset(&device_config, 0, sizeof(device_config));
        }
    }

    if (provisioning_manager_has_complete_config(&s_provisioning)) {
        if (session_err == ESP_OK) {
            ESP_ERROR_CHECK(screen_router_navigate(&s_router, NEOAGENT_SCREEN_ASSISTANT));
            ESP_ERROR_CHECK(ui_renderer_set_screen(&s_ui, screen_router_current(&s_router)));
        } else {
            ESP_ERROR_CHECK(run_pairing_flow(&device_config));
        }
    } else {
        ESP_ERROR_CHECK(screen_router_navigate(&s_router, NEOAGENT_SCREEN_PROVISIONING));
        ESP_ERROR_CHECK(ui_renderer_set_screen(&s_ui, screen_router_current(&s_router)));
        ESP_ERROR_CHECK(provisioning_manager_start_portal(&s_provisioning, &s_session_store));
        ESP_ERROR_CHECK(ui_renderer_show_provisioning(
            &s_ui,
            provisioning_manager_ap_ssid(&s_provisioning),
            provisioning_manager_ap_password(&s_provisioning)
        ));
    }

    ESP_LOGI(TAG, "board display=%d touch=%d audio=%d", s_board.display_ready, s_board.touch_ready, s_board.audio_ready);
    ESP_LOGI(TAG, "server_url=%s paired=%d screen=%d", device_config.server_url, session_state.authenticated, (int)screen_router_current(&s_router));
    telemetry_log_boot("main_ready");

    while (true) {
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}

void app_main(void) {
    telemetry_log_boot("main_start");
    BaseType_t created = xTaskCreate(
        wearable_runtime_task,
        "neo_runtime",
        NEOAGENT_RUNTIME_TASK_STACK_SIZE,
        NULL,
        5,
        NULL
    );
    if (created != pdPASS) {
        ESP_LOGE(TAG, "failed to start runtime task");
        telemetry_log_boot("runtime_task_failed");
        return;
    }
}

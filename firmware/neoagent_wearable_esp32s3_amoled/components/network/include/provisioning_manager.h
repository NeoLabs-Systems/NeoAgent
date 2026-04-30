#pragma once

#include <stdbool.h>

#include "esp_err.h"
#include "freertos/FreeRTOS.h"
#include "freertos/event_groups.h"
#include "esp_http_server.h"
#include "esp_netif.h"
#include "neoagent_wearable_types.h"
#include "session_store.h"

#define NEOAGENT_PROVISIONING_SSID_MAX 32
#define NEOAGENT_PROVISIONING_PASSWORD_MAX 32

typedef struct {
    neoagent_device_config_t pending_config;
    bool has_pending_config;
    bool portal_running;
    bool portal_saved_config;
    bool wifi_connected;
    char ap_ssid[NEOAGENT_PROVISIONING_SSID_MAX];
    char ap_password[NEOAGENT_PROVISIONING_PASSWORD_MAX];
    httpd_handle_t http_server;
    esp_netif_t *ap_netif;
    esp_netif_t *sta_netif;
    EventGroupHandle_t wifi_events;
} provisioning_manager_t;

esp_err_t provisioning_manager_init(provisioning_manager_t *manager);
esp_err_t provisioning_manager_set_pending_config(provisioning_manager_t *manager, const neoagent_device_config_t *config);
bool provisioning_manager_has_complete_config(const provisioning_manager_t *manager);
esp_err_t provisioning_manager_validate_server_url(const char *server_url);
esp_err_t provisioning_manager_start_portal(provisioning_manager_t *manager, session_store_t *store);
esp_err_t provisioning_manager_connect_station(provisioning_manager_t *manager, const neoagent_device_config_t *config, int timeout_ms);
const char *provisioning_manager_ap_ssid(const provisioning_manager_t *manager);
const char *provisioning_manager_ap_password(const provisioning_manager_t *manager);
bool provisioning_manager_portal_saved_config(const provisioning_manager_t *manager);

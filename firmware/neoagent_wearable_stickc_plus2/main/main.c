#include <stdbool.h>
#include <stdio.h>
#include <string.h>

#include "board_support.h"
#include "esp_log.h"
#include "esp_pm.h"
#include "esp_sleep.h"
#include "esp_system.h"
#include "esp_timer.h"
#include "esp_wifi.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "pairing_manager.h"
#include "provisioning_manager.h"
#include "session_store.h"
#include "wearable_voice_client.h"

static const char *TAG = "StickC";
static const char *PLATFORM = "m5stickc-plus2";
static session_store_t store;
static provisioning_manager_t network;
static pairing_manager_t pairing;
static board_support_t board;

static void enter_deep_sleep(void) {
    if (board_button_a()) return;
    ESP_ERROR_CHECK(board_prepare_deep_sleep());
    ESP_ERROR_CHECK(esp_wifi_stop());
    ESP_LOGI(TAG, "Entering deep sleep; press A to wake");
    vTaskDelay(pdMS_TO_TICKS(100));
    ESP_ERROR_CHECK(esp_sleep_disable_wakeup_source(ESP_SLEEP_WAKEUP_ALL));
    ESP_ERROR_CHECK(esp_sleep_enable_ext0_wakeup(GPIO_NUM_37, 0));
    esp_deep_sleep_start();
}

static void show(const char *title, const char *body) {
    board_display_awake(true);
    board_display_message(title, body);
    board_display_tick();
}

static void portal(void) {
    ESP_ERROR_CHECK(provisioning_manager_start_portal(&network, &store));
    char instructions[180];
    const char *password = provisioning_manager_ap_password(&network);
    snprintf(instructions, sizeof(instructions), "Connect your phone to Wi-Fi:\n%s\n\n%s%s\n\nOpen 192.168.4.1",
             provisioning_manager_ap_ssid(&network), password[0] ? "Password: " : "Open network", password);
    show("Set up Wi-Fi", instructions);
    while (true) {
        board_display_tick();
        vTaskDelay(pdMS_TO_TICKS(30));
    }
}

static void reset_setup(void) {
    session_store_clear_session(&store);
    session_store_clear_device_config(&store);
    show("Setup reset", "Restarting...");
    vTaskDelay(pdMS_TO_TICKS(500));
    esp_restart();
}

static void pair(const neoagent_device_config_t *config, neoagent_session_state_t *session) {
    while (true) {
        show("Pairing", "Getting a code...");
        if (pairing_manager_create_challenge(&pairing, config->server_url, config->device_label, PLATFORM) != ESP_OK) {
            show("Pairing failed", "Check your server. Retrying...");
            vTaskDelay(pdMS_TO_TICKS(5000));
            continue;
        }
        if (board_display_qr("Pair NeoAgent", pairing.qr_state.qr_payload) != ESP_OK) {
            show("Pairing failed", "Code too large for screen. Check server URL.");
            vTaskDelay(pdMS_TO_TICKS(5000));
            continue;
        }
        int64_t next_poll = 0;
        int64_t held_b = 0;
        while (true) {
            board_display_tick();
            const int64_t now = esp_timer_get_time();
            if (board_button_b()) {
                if (!held_b) held_b = now;
                if (now - held_b > 3000000) reset_setup();
            } else held_b = 0;
            if (now >= next_poll) {
                next_poll = now + 3000000;
                if (pairing_manager_poll_status(&pairing, config->server_url) == ESP_OK) {
                    if (pairing.state == PAIRING_STATE_APPROVED && pairing_manager_claim_session(&pairing, config->server_url, session, &store) == ESP_OK) return;
                    if (pairing.state == PAIRING_STATE_EXPIRED || pairing.state == PAIRING_STATE_CLAIMED) break;
                }
            }
            vTaskDelay(pdMS_TO_TICKS(30));
        }
    }
}

static bool websocket_url(const char *server, char *url, size_t size) {
    const char *host;
    const char *scheme;
    if (strncmp(server, "https://", 8) == 0) { scheme = "wss://"; host = server + 8; }
    else if (strncmp(server, "http://", 7) == 0) { scheme = "ws://"; host = server + 7; }
    else return false;
    size_t length = strlen(host);
    while (length && host[length - 1] == '/') length--;
    int written = snprintf(url, size, "%s%.*s/api/wearable/ws", scheme, (int)length, host);
    return written > 0 && (size_t)written < size;
}

static void assistant(const neoagent_device_config_t *config, const neoagent_session_state_t *session) {
    char url[NEOAGENT_WS_URL_MAX];
    if (!websocket_url(config->server_url, url, sizeof(url))) {
        show("Invalid server", "Hold B to reset setup.");
        while (!board_button_b()) { board_display_tick(); vTaskDelay(pdMS_TO_TICKS(50)); }
        reset_setup();
    }
    wearable_voice_client_t *voice = NULL;
    ESP_ERROR_CHECK(wearable_voice_client_init(&voice, &board, url, session->session_cookie, config->device_label, PLATFORM));
    provisioning_manager_set_station_power_save(true);
    bool a_was_down = false, b_was_down = false, display_on = true, pending_reply = false;
    int64_t last_activity = esp_timer_get_time(), b_held_at = 0, reply_finished_at = 0;
    uint32_t final_seq = 0;
    char previous[NEOAGENT_VOICE_TEXT_MAX + 80] = "";
    wearable_voice_snapshot_t snapshot = {0};
    while (true) {
        const int64_t now = esp_timer_get_time();
        const bool a = board_button_a(), b = board_button_b();
        wearable_voice_client_poll(voice);
        wearable_voice_client_snapshot(voice, &snapshot);
        if (snapshot.capturing || snapshot.task_running || snapshot.speaking) last_activity = now;
        if (snapshot.authentication_rejected) {
            session_store_clear_session(&store);
            show("Session expired", "Pair again.");
            vTaskDelay(pdMS_TO_TICKS(1200));
            esp_restart();
        }
        if (a && !a_was_down) {
            display_on = true; board_display_awake(true); last_activity = now;
            provisioning_manager_set_station_power_save(false);
            ESP_ERROR_CHECK(board_microphone_active(true));
            wearable_voice_client_talk_start(voice);
        } else if (!a && a_was_down) {
            wearable_voice_client_talk_stop(voice);
            last_activity = now;
        }
        if (b && !b_was_down) { b_held_at = now; display_on = true; board_display_awake(true); last_activity = now; }
        if (b && b_held_at && now - b_held_at > 3000000) reset_setup();
        if (!b && b_was_down && b_held_at) { board_display_scroll(); b_held_at = 0; }
        a_was_down = a; b_was_down = b;
        if (!a && !snapshot.capturing && now - last_activity > 300000) {
            ESP_ERROR_CHECK(board_microphone_active(false));
            if (snapshot.call == WEARABLE_CALL_IDLE) provisioning_manager_set_station_power_save(true);
        }
        if (snapshot.assistant_final_seq != final_seq) {
            final_seq = snapshot.assistant_final_seq;
            pending_reply = !snapshot.task_running;
            reply_finished_at = now;
        }
        if (snapshot.task_running) pending_reply = false;
        if (pending_reply && !snapshot.task_running && !snapshot.capturing && !snapshot.speaking && now - reply_finished_at >= 800000) {
            pending_reply = false; display_on = true; board_display_awake(true); last_activity = now;
            board_beep();
        }
        if (snapshot.call != WEARABLE_CALL_IDLE && !a && !snapshot.capturing && !snapshot.task_running && !snapshot.speaking && now - last_activity > 60000000) {
            wearable_voice_client_call_end(voice);
            provisioning_manager_set_station_power_save(true);
        }
        if (display_on && !a && !snapshot.capturing && !snapshot.task_running && now - last_activity > 30000000) {
            board_display_awake(false); display_on = false;
        }
        if (!a && !b && !snapshot.capturing && !snapshot.task_running && !snapshot.speaking &&
            !pending_reply && snapshot.call == WEARABLE_CALL_IDLE && now - last_activity > 120000000) {
            enter_deep_sleep();
        }
        char content[sizeof(previous)];
        const char *title = !snapshot.server_connected ? "Connecting" : a ? "Listening" : snapshot.reconnecting ? "Connecting" : snapshot.task_running ? "Working" : "NeoAgent";
        const char *body = snapshot.last_error[0] ? snapshot.last_error : snapshot.caption[0] ? snapshot.caption : "Hold A to talk.\n\nB scrolls. Hold B to reset setup.";
        snprintf(content, sizeof(content), "%s\n%s", title, body);
        if (strcmp(content, previous) != 0) {
            if (!a && !snapshot.task_running && !snapshot.reconnecting &&
                !snapshot.last_error[0] && !snapshot.caption[0]) {
                board_display_idle(snapshot.server_connected);
            } else {
                board_display_message(title, body);
            }
            strlcpy(previous, content, sizeof(previous));
        }
        board_display_tick();
        vTaskDelay(pdMS_TO_TICKS(display_on ? 40 : 200));
    }
}

static void wearable_task(void *arg) {
    (void)arg;
    ESP_LOGI(TAG, "Wake cause: %d", (int)esp_sleep_get_wakeup_cause());
    ESP_ERROR_CHECK(board_support_init(&board));
    esp_pm_config_t pm = { .max_freq_mhz = 160, .min_freq_mhz = 40, .light_sleep_enable = true };
    ESP_ERROR_CHECK(esp_pm_configure(&pm));
    ESP_ERROR_CHECK(session_store_init(&store, NULL));
    ESP_ERROR_CHECK(provisioning_manager_init(&network));
    ESP_ERROR_CHECK(pairing_manager_init(&pairing));
    neoagent_device_config_t config = {0};
    neoagent_session_state_t session = {0};
    if (session_store_load_device_config(&store, &config) != ESP_OK) portal();
    show("Connecting", "Joining Wi-Fi...");
    if (provisioning_manager_connect_station(&network, &config, 20000) != ESP_OK) portal();
    esp_err_t sync = provisioning_manager_sync_time(&network, config.server_url, 10000);
    if (sync != ESP_OK) ESP_LOGW(TAG, "Time sync failed: %s", esp_err_to_name(sync));
    if (session_store_load_session(&store, &session) != ESP_OK || !session.authenticated) pair(&config, &session);
    assistant(&config, &session);
}

void app_main(void) {
    BaseType_t created = xTaskCreate(wearable_task, "neo_runtime", 24576, NULL, 5, NULL);
    if (created != pdPASS) {
        ESP_LOGE(TAG, "Could not start wearable task");
        esp_restart();
    }
}

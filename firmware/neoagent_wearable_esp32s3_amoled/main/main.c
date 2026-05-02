#include <stdio.h>
#include <string.h>
#include <time.h>

#include "app_shell.h"
#include "background_recording_client.h"
#include "board_support.h"
#include "driver/gpio.h"
#include "esp_app_desc.h"
#include "esp_sleep.h"
#include "esp_system.h"
#include "esp_log.h"
#include "esp_heap_caps.h"
#include "esp_timer.h"
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
#define NEOAGENT_TOUCH_SCREEN_WIDTH 448
#define NEOAGENT_TOUCH_SCREEN_HEIGHT 368
#define NEOAGENT_WIDGET_REFRESH_INTERVAL_MS 60000
#define NEOAGENT_CHROME_REFRESH_INTERVAL_MS 5000
#define NEOAGENT_IDLE_TIMEOUT_MS 180000
#define NEOAGENT_SLEEP_BOOT_GPIO GPIO_NUM_0
#define NEOAGENT_SLEEP_POWER_GPIO GPIO_NUM_17
#define NEOAGENT_SLEEP_WAKE_GPIO_MASK ((1ULL << NEOAGENT_SLEEP_BOOT_GPIO) | (1ULL << NEOAGENT_SLEEP_POWER_GPIO))
#define NEOAGENT_SLEEP_WAKE_RELEASE_TIMEOUT_MS 3000
#define NEOAGENT_SLEEP_WAKE_RELEASE_STABLE_MS 180
#define NEOAGENT_NAV_WIDTH 64
#define NEOAGENT_NAV_ASSISTANT_MAX_Y 92
#define NEOAGENT_NAV_WIDGETS_MAX_Y 184
#define NEOAGENT_NAV_RECORDING_MAX_Y 276
#define NEOAGENT_ASSISTANT_ORB_CENTER_X 256
#define NEOAGENT_ASSISTANT_ORB_CENTER_Y 164
#define NEOAGENT_ASSISTANT_ORB_RADIUS 78
#define NEOAGENT_RECORDING_ORB_CENTER_X 189
#define NEOAGENT_RECORDING_ORB_CENTER_Y 201
#define NEOAGENT_RECORDING_ORB_RADIUS 76
#define NEOAGENT_WIDGET_PREV_MAX_X 128
#define NEOAGENT_WIDGET_NEXT_MIN_X 384
#define NEOAGENT_WIDGET_BODY_TOP_Y 58
#define NEOAGENT_WIDGET_BODY_BOTTOM_Y 308
#define NEOAGENT_SETTINGS_NETWORK_TOP_Y 96
#define NEOAGENT_SETTINGS_NETWORK_BOTTOM_Y 158
#define NEOAGENT_SETTINGS_UPDATE_TOP_Y 170
#define NEOAGENT_SETTINGS_UPDATE_BOTTOM_Y 232
#define NEOAGENT_SETTINGS_UPDATE_STABLE_TOP_Y 70
#define NEOAGENT_SETTINGS_UPDATE_STABLE_BOTTOM_Y 126
#define NEOAGENT_SETTINGS_UPDATE_BETA_TOP_Y 124
#define NEOAGENT_SETTINGS_UPDATE_BETA_BOTTOM_Y 180
#define NEOAGENT_SETTINGS_UPDATE_ACTION_TOP_Y 188
#define NEOAGENT_SETTINGS_UPDATE_ACTION_BOTTOM_Y 236
#define NEOAGENT_SETTINGS_SETUP_ACTION_TOP_Y 236
#define NEOAGENT_SETTINGS_SETUP_ACTION_BOTTOM_Y 286
#define NEOAGENT_SETTINGS_BACK_TOP_Y 314
#define NEOAGENT_SETTINGS_BACK_BOTTOM_Y 360
#define NEOAGENT_SETTINGS_RESET_TOP_Y 220
#define NEOAGENT_SETTINGS_RESET_BOTTOM_Y 292

typedef enum {
    SHELL_TAB_ASSISTANT = 0,
    SHELL_TAB_WIDGETS = 1,
    SHELL_TAB_RECORDING = 2,
    SHELL_TAB_SETTINGS = 3,
} shell_tab_t;

typedef enum {
    SETTINGS_VIEW_ROOT = 0,
    SETTINGS_VIEW_NETWORK = 1,
    SETTINGS_VIEW_UPDATE = 2,
} settings_view_t;

static session_store_t s_session_store;
static provisioning_manager_t s_provisioning;
static pairing_manager_t s_pairing;
static widget_repository_t s_widgets;
static wearable_voice_client_t s_voice_client;
static background_recording_client_t s_recording_client;
static power_manager_t s_power_manager;
static screen_router_t s_router;
static app_shell_t s_shell;
static board_support_t s_board;
static ui_renderer_t s_ui;
static update_manager_t s_updates;

static bool is_voice_available(void);
static esp_err_t persist_firmware_update_channel(const char *channel);
static size_t configured_wifi_network_count(const neoagent_device_config_t *device_config);

static void format_elapsed_timer(int64_t started_at_ms, char *buffer, size_t buffer_size) {
    if (buffer == NULL || buffer_size == 0) {
        return;
    }
    if (started_at_ms <= 0) {
        snprintf(buffer, buffer_size, "00:00");
        return;
    }
    int64_t elapsed_ms = (esp_timer_get_time() / 1000LL) - started_at_ms;
    if (elapsed_ms < 0) {
        elapsed_ms = 0;
    }
    uint32_t total_seconds = (uint32_t)(elapsed_ms / 1000LL);
    snprintf(buffer, buffer_size, "%02u:%02u", (unsigned)(total_seconds / 60U), (unsigned)(total_seconds % 60U));
}
static void start_firmware_update(const neoagent_device_config_t *device_config, const neoagent_session_state_t *session_state);

static size_t configured_wifi_network_count(const neoagent_device_config_t *device_config) {
    if (device_config == NULL) {
        return 0;
    }
    if (device_config->wifi_network_count > 0) {
        return device_config->wifi_network_count;
    }
    return device_config->wifi_ssid[0] != '\0' ? 1 : 0;
}

static void append_utf8_text(char *destination, size_t destination_size, const char *text) {
    if (destination == NULL || destination_size == 0 || text == NULL) {
        return;
    }
    size_t used = strlen(destination);
    const unsigned char *cursor = (const unsigned char *)text;
    while (*cursor != '\0' && used + 1 < destination_size) {
        if (*cursor < 0x80) {
            destination[used++] = (char)*cursor++;
            continue;
        }
        if (cursor[0] == 0xC3 && cursor[1] != 0) {
            const char *replacement = NULL;
            switch (cursor[1]) {
                case 0x84:
                case 0xA4:
                    replacement = "ae";
                    break;
                case 0x96:
                case 0xB6:
                    replacement = "oe";
                    break;
                case 0x9C:
                case 0xBC:
                    replacement = "ue";
                    break;
                case 0x9F:
                    replacement = "ss";
                    break;
                default:
                    replacement = "?";
                    break;
            }
            size_t len = strlen(replacement);
            if (used + len >= destination_size) {
                break;
            }
            memcpy(destination + used, replacement, len);
            used += len;
            cursor += 2;
            continue;
        }
        if (cursor[0] == 0xE2 && cursor[1] != 0 && cursor[2] != 0) {
            const char *replacement = "?";
            if (cursor[1] == 0x80 && (cursor[2] == 0x98 || cursor[2] == 0x99)) {
                replacement = "'";
            } else if (cursor[1] == 0x80 && (cursor[2] == 0x9C || cursor[2] == 0x9D)) {
                replacement = "\"";
            } else if (cursor[1] == 0x80 && (cursor[2] == 0x93 || cursor[2] == 0x94)) {
                replacement = "-";
            }
            size_t len = strlen(replacement);
            if (used + len >= destination_size) {
                break;
            }
            memcpy(destination + used, replacement, len);
            used += len;
            cursor += 3;
            continue;
        }
        destination[used++] = '?';
        cursor += (*cursor & 0xF8) == 0xF0 ? 4 : ((*cursor & 0xF0) == 0xE0 ? 3 : ((*cursor & 0xE0) == 0xC0 ? 2 : 1));
    }
    destination[used] = '\0';
}

static void sanitize_display_text(char *destination, size_t destination_size, const char *source) {
    if (destination == NULL || destination_size == 0) {
        return;
    }
    destination[0] = '\0';
    if (source == NULL) {
        return;
    }
    append_utf8_text(destination, destination_size, source);
}

static const char *reset_reason_name(esp_reset_reason_t reason) {
    switch (reason) {
        case ESP_RST_POWERON:
            return "poweron";
        case ESP_RST_SW:
            return "software";
        case ESP_RST_PANIC:
            return "panic";
        case ESP_RST_INT_WDT:
            return "int_wdt";
        case ESP_RST_TASK_WDT:
            return "task_wdt";
        case ESP_RST_WDT:
            return "wdt";
        case ESP_RST_BROWNOUT:
            return "brownout";
        case ESP_RST_USB:
            return "usb";
        default:
            return "other";
    }
}

static void log_internal_heap(const char *stage) {
    ESP_LOGI(
        TAG,
        "heap stage=%s free_internal=%u largest_internal=%u free_8bit=%u",
        stage != NULL ? stage : "unknown",
        (unsigned)heap_caps_get_free_size(MALLOC_CAP_INTERNAL),
        (unsigned)heap_caps_get_largest_free_block(MALLOC_CAP_INTERNAL),
        (unsigned)heap_caps_get_free_size(MALLOC_CAP_8BIT)
    );
}

static void format_time_label(char *buffer, size_t buffer_size) {
    time_t now = time(NULL);
    if (buffer == NULL || buffer_size == 0) {
        return;
    }
    if (now < 100000) {
        snprintf(buffer, buffer_size, "--:--");
        return;
    }
    struct tm local_time = {0};
    int offset_seconds = provisioning_manager_time_offset_seconds();
    if (offset_seconds != 0) {
        time_t adjusted = now + offset_seconds;
        gmtime_r(&adjusted, &local_time);
    } else {
        localtime_r(&now, &local_time);
    }
    strftime(buffer, buffer_size, "%H:%M", &local_time);
}

static bool update_power_chrome(void) {
    int battery_percent = -1;
    bool charging = false;
    if (board_support_read_battery_status(&s_board, &battery_percent, &charging) != ESP_OK) {
        return false;
    }
    const neoagent_status_chrome_t *current = power_manager_get_status(&s_power_manager);
    const bool changed =
        current == NULL
        || current->battery_percent != battery_percent
        || current->charging != charging;
    ESP_ERROR_CHECK(power_manager_update_battery(&s_power_manager, battery_percent, charging));
    return changed;
}

static void append_bounded(char *destination, size_t destination_size, const char *suffix) {
    if (destination == NULL || destination_size == 0 || suffix == NULL) {
        return;
    }
    size_t used = strlen(destination);
    if (used >= destination_size - 1) {
        return;
    }
    size_t available = destination_size - used - 1;
    size_t suffix_length = strlen(suffix);
    size_t to_copy = suffix_length < available ? suffix_length : available;
    if (to_copy == 0) {
        return;
    }
    memcpy(destination + used, suffix, to_copy);
    destination[used + to_copy] = '\0';
}

static board_assistant_state_t assistant_visual_state_from_snapshot(const wearable_voice_snapshot_t *voice_snapshot) {
    if (voice_snapshot == NULL) {
        return BOARD_ASSISTANT_STATE_IDLE;
    }
    if (voice_snapshot->last_error[0] != '\0') {
        return BOARD_ASSISTANT_STATE_ERROR;
    }
    if (voice_snapshot->recording) {
        return BOARD_ASSISTANT_STATE_LISTENING;
    }
    if (strcmp(voice_snapshot->state, "speaking") == 0 || voice_snapshot->assistant_speaking) {
        return BOARD_ASSISTANT_STATE_SPEAKING;
    }
    if (strcmp(voice_snapshot->state, "thinking") == 0) {
        return BOARD_ASSISTANT_STATE_THINKING;
    }
    if (strcmp(voice_snapshot->state, "transcribing") == 0) {
        return BOARD_ASSISTANT_STATE_TRANSCRIBING;
    }
    if (strcmp(voice_snapshot->state, "listening") == 0) {
        return BOARD_ASSISTANT_STATE_LISTENING;
    }
    return BOARD_ASSISTANT_STATE_IDLE;
}

static void render_assistant_tab(
    const neoagent_device_config_t *device_config,
    const wearable_voice_snapshot_t *voice_snapshot,
    const background_recording_snapshot_t *recording_snapshot
) {
    char status[96];
    char hint[180];
    char display_hint[180];
    const bool recording_active = recording_snapshot != NULL && (recording_snapshot->active || recording_snapshot->starting || recording_snapshot->stopping);
    const bool voice_available = !recording_active && voice_snapshot != NULL && voice_snapshot->transport_available;
    const bool mic_active = voice_snapshot != NULL && voice_snapshot->recording;
    const board_assistant_state_t visual_state = assistant_visual_state_from_snapshot(voice_snapshot);

    snprintf(
        status,
        sizeof(status),
        recording_active ? "Recorder active" :
        voice_snapshot != NULL && voice_snapshot->last_error[0] != '\0'
            ? "Voice issue"
            : (visual_state == BOARD_ASSISTANT_STATE_LISTENING ? "Listening"
                : (visual_state == BOARD_ASSISTANT_STATE_TRANSCRIBING ? "Transcribing"
                    : (visual_state == BOARD_ASSISTANT_STATE_THINKING ? "Thinking"
                        : (visual_state == BOARD_ASSISTANT_STATE_SPEAKING ? "Speaking"
                            : (voice_available ? "Ready" : "Voice unavailable")))))
    );
    if (recording_active) {
        snprintf(hint, sizeof(hint), "Background recording is using the microphone. Stop recording to talk.");
    } else if (voice_snapshot != NULL && voice_snapshot->last_error[0] != '\0') {
        snprintf(hint, sizeof(hint), "%s", voice_snapshot->last_error);
    } else if (voice_snapshot != NULL && voice_snapshot->assistant_text[0] != '\0') {
        sanitize_display_text(hint, sizeof(hint), voice_snapshot->assistant_text);
    } else if (voice_snapshot != NULL && voice_snapshot->transcript[0] != '\0') {
        sanitize_display_text(hint, sizeof(hint), voice_snapshot->transcript);
    } else {
        hint[0] = '\0';
    }
    sanitize_display_text(display_hint, sizeof(display_hint), hint);
    (void)device_config;
    ESP_ERROR_CHECK(ui_renderer_show_assistant_home(&s_ui, status, display_hint, mic_active, visual_state));
}

static bool is_voice_available(void) {
    return s_voice_client.transport_available;
}

static void render_widget_tab(const widget_repository_t *widgets, size_t widget_index, esp_err_t last_widget_status) {
    if (widgets != NULL && widgets->count > 0) {
        ESP_ERROR_CHECK(ui_renderer_show_widget(&s_ui, &widgets->items[widget_index], widget_index, widgets->count));
        return;
    }

    neoagent_widget_snapshot_t empty_widget = {0};
    if (last_widget_status == ESP_ERR_NOT_FOUND) {
        snprintf(empty_widget.title, sizeof(empty_widget.title), "No widgets");
        empty_widget.metric[0] = '\0';
        empty_widget.body[0] = '\0';
    } else {
        snprintf(empty_widget.title, sizeof(empty_widget.title), "Widget error");
        snprintf(empty_widget.metric, sizeof(empty_widget.metric), "%s", esp_err_to_name(last_widget_status));
        empty_widget.body[0] = '\0';
    }
    ESP_ERROR_CHECK(ui_renderer_show_widget(&s_ui, &empty_widget, 0, 1));
}

static void render_recording_tab(const background_recording_snapshot_t *snapshot) {
    char timer_text[12];
    char headline[132];
    bool active = false;
    bool busy = false;

    format_elapsed_timer(snapshot != NULL ? snapshot->started_at_ms : 0, timer_text, sizeof(timer_text));
    if (snapshot != NULL) {
        active = snapshot->active;
        busy = snapshot->starting || snapshot->stopping || snapshot->upload_pending;
    }

    snprintf(
        headline,
        sizeof(headline),
        "%s",
        snapshot != NULL && snapshot->starting ? "Starting recording" :
        snapshot != NULL && snapshot->stopping ? "Finishing recording" :
        snapshot != NULL && snapshot->upload_pending ? "Uploading recording" :
        active ? "Recording in progress" : "Ready to record"
    );

    ESP_ERROR_CHECK(ui_renderer_show_recording(
        &s_ui,
        snapshot != NULL && snapshot->starting ? "Starting" :
        snapshot != NULL && snapshot->stopping ? "Stopping" :
        snapshot != NULL && snapshot->upload_pending ? "Uploading" :
        snapshot != NULL && snapshot->status[0] != '\0' ? snapshot->status : "Recording ready",
        headline,
        "",
        active,
        busy,
        timer_text
    ));
}

static void render_settings_tab(
    const neoagent_device_config_t *device_config,
    const neoagent_session_state_t *session_state,
    settings_view_t settings_view,
    bool show_reset
) {
    (void)session_state;
    char headline[140];
    char body[220];

    if (show_reset) {
        ESP_ERROR_CHECK(ui_renderer_show_settings(&s_ui, "Reset", "Forget this device", "Clear pairing and Wi-Fi setup, then return to provisioning.", NULL, true));
        return;
    }

    if (settings_view == SETTINGS_VIEW_ROOT) {
        snprintf(headline, sizeof(headline), "Device settings");
        body[0] = '\0';
        ESP_ERROR_CHECK(ui_renderer_show_settings(&s_ui, "Settings", headline, body, NULL, false));
        return;
    }

    if (settings_view == SETTINGS_VIEW_UPDATE) {
        headline[0] = '\0';
        body[0] = '\0';
        ESP_ERROR_CHECK(ui_renderer_show_settings(&s_ui, "Update", headline, body, update_manager_channel(&s_updates), false));
        return;
    }

    snprintf(
        headline,
        sizeof(headline),
        "Wi-Fi %s",
        device_config != NULL && device_config->wifi_ssid[0] != '\0' ? device_config->wifi_ssid : "not configured"
    );
    snprintf(body, sizeof(body), "Saved networks: %u\nServer\n", (unsigned)configured_wifi_network_count(device_config));
    append_bounded(
        body,
        sizeof(body),
        device_config != NULL && device_config->server_url[0] != '\0' ? device_config->server_url : "No backend configured"
    );
    ESP_ERROR_CHECK(ui_renderer_show_settings(&s_ui, "Network", headline, body, NULL, false));
}

static esp_err_t persist_firmware_update_channel(const char *channel) {
    neoagent_firmware_update_settings_t update_settings = {0};
    const char *normalized = channel != NULL && strcmp(channel, "beta") == 0 ? "beta" : "stable";
    snprintf(update_settings.channel, sizeof(update_settings.channel), "%s", normalized);
    esp_err_t err = update_manager_set_channel(&s_updates, update_settings.channel);
    if (err != ESP_OK) {
        return err;
    }
    return session_store_save_firmware_update_settings(&s_session_store, &update_settings);
}

static void start_firmware_update(const neoagent_device_config_t *device_config, const neoagent_session_state_t *session_state) {
    if (device_config == NULL || session_state == NULL) {
        ESP_ERROR_CHECK(board_support_show_message(&s_board, "Update Failed", "Missing device state", "Cannot start OTA without a saved server and session."));
        return;
    }

    ESP_ERROR_CHECK(board_support_show_message(&s_board, "Updating Firmware", "Checking the manifest...", "Do not power off the device."));
    vTaskDelay(pdMS_TO_TICKS(250));

    esp_err_t update_err = update_manager_auto_update(&s_updates, device_config->server_url, session_state);
    if (update_err == ESP_OK) {
        ESP_ERROR_CHECK(board_support_show_message(&s_board, "Update Complete", "Rebooting into new firmware", "The device will restart now."));
        vTaskDelay(pdMS_TO_TICKS(1500));
        esp_restart();
        return;
    }

    if (update_err == ESP_ERR_INVALID_STATE) {
        ESP_ERROR_CHECK(board_support_show_message(&s_board, "Already Up To Date", "No firmware update was installed", "The current version matches the configured release."));
        return;
    }

    if (update_err == ESP_ERR_NOT_FOUND) {
        ESP_ERROR_CHECK(board_support_show_message(&s_board, "Update Unavailable", "No firmware download is configured", "The manifest did not publish an OTA image."));
        return;
    }

    if (update_err == ESP_ERR_INVALID_ARG) {
        ESP_ERROR_CHECK(board_support_show_message(&s_board, "Update Failed", "Missing server or session", "Connect the device and sign in before trying again."));
        return;
    }

    char error_line[160];
    snprintf(error_line, sizeof(error_line), "%s", esp_err_to_name(update_err));
    ESP_ERROR_CHECK(board_support_show_message(&s_board, "Update Failed", error_line, "Check the manifest and try again."));
}

static void render_current_tab(
    shell_tab_t current_tab,
    const neoagent_device_config_t *device_config,
    const neoagent_session_state_t *session_state,
    const widget_repository_t *widgets,
    size_t widget_index,
    settings_view_t settings_view,
    esp_err_t last_widget_status,
    const wearable_voice_snapshot_t *voice_snapshot,
    const background_recording_snapshot_t *recording_snapshot,
    bool wifi_connected,
    bool settings_show_reset
) {
    neoagent_status_chrome_t chrome = {0};
    char time_label[8];

    const neoagent_status_chrome_t *power_status = power_manager_get_status(&s_power_manager);
    if (power_status != NULL) {
        chrome = *power_status;
    }
    chrome.wifi_connected = wifi_connected;
    chrome.paired = session_state != NULL && session_state->authenticated;
    format_time_label(time_label, sizeof(time_label));
    ESP_ERROR_CHECK(board_support_set_chrome(&s_board, &chrome, time_label));

    switch (current_tab) {
        case SHELL_TAB_ASSISTANT:
            render_assistant_tab(device_config, voice_snapshot, recording_snapshot);
            break;
        case SHELL_TAB_WIDGETS:
            render_widget_tab(widgets, widget_index, last_widget_status);
            break;
        case SHELL_TAB_RECORDING:
            render_recording_tab(recording_snapshot);
            break;
        case SHELL_TAB_SETTINGS:
            render_settings_tab(device_config, session_state, settings_view, settings_show_reset);
            break;
    }
}

static void stop_recording_if_needed(const char *stop_reason) {
    if (!background_recording_client_is_active(&s_recording_client)) {
        return;
    }
    if (background_recording_client_stop(&s_recording_client, stop_reason) != ESP_OK) {
        return;
    }
    for (size_t attempt = 0; attempt < 75; ++attempt) {
        if (!background_recording_client_is_active(&s_recording_client)) {
            return;
        }
        vTaskDelay(pdMS_TO_TICKS(80));
    }
}

static bool recording_activity_in_progress(
    const wearable_voice_snapshot_t *voice_snapshot,
    const background_recording_snapshot_t *recording_snapshot
) {
    return (voice_snapshot != NULL && voice_snapshot->recording)
        || (recording_snapshot != NULL && (
            recording_snapshot->active
            || recording_snapshot->starting
            || recording_snapshot->stopping
            || recording_snapshot->upload_pending
        ));
}

static bool voice_snapshot_changed(const wearable_voice_snapshot_t *previous, const wearable_voice_snapshot_t *current) {
    if (previous == NULL || current == NULL) {
        return previous != current;
    }
    return previous->transport_available != current->transport_available
        || previous->websocket_connected != current->websocket_connected
        || previous->session_ready != current->session_ready
        || previous->recording != current->recording
        || previous->assistant_speaking != current->assistant_speaking
        || strcmp(previous->state, current->state) != 0
        || strcmp(previous->transcript, current->transcript) != 0
        || strcmp(previous->assistant_text, current->assistant_text) != 0
        || strcmp(previous->last_error, current->last_error) != 0;
}

static bool sleep_wake_buttons_released(void) {
    return gpio_get_level(NEOAGENT_SLEEP_BOOT_GPIO) != 0 && gpio_get_level(NEOAGENT_SLEEP_POWER_GPIO) != 0;
}

static bool wait_for_sleep_wake_buttons_released(void) {
    TickType_t stable_since = 0;
    const TickType_t deadline = xTaskGetTickCount() + pdMS_TO_TICKS(NEOAGENT_SLEEP_WAKE_RELEASE_TIMEOUT_MS);

    while (xTaskGetTickCount() < deadline) {
        const TickType_t now = xTaskGetTickCount();
        if (sleep_wake_buttons_released()) {
            if (stable_since == 0) {
                stable_since = now;
            } else if (now - stable_since >= pdMS_TO_TICKS(NEOAGENT_SLEEP_WAKE_RELEASE_STABLE_MS)) {
                return true;
            }
        } else {
            stable_since = 0;
        }
        vTaskDelay(pdMS_TO_TICKS(20));
    }
    return false;
}

static void enter_sleep_due_to_idle(const wearable_voice_snapshot_t *voice_snapshot) {
    if (voice_snapshot != NULL && voice_snapshot->recording) {
        wearable_voice_client_stop_ptt(&s_voice_client);
    }
    stop_recording_if_needed("sleep");
    if (!wait_for_sleep_wake_buttons_released()) {
        ESP_LOGW(TAG, "deep sleep skipped because a wake button is still held");
        return;
    }
    esp_err_t display_err = board_support_set_display_awake(&s_board, false);
    if (display_err != ESP_OK) {
        ESP_LOGW(TAG, "display off before sleep failed: %s", esp_err_to_name(display_err));
    } else {
        ESP_LOGI(TAG, "deep sleep -> display off");
    }
    esp_err_t wake_err = esp_sleep_enable_ext1_wakeup_io(NEOAGENT_SLEEP_WAKE_GPIO_MASK, ESP_EXT1_WAKEUP_ANY_LOW);
    if (wake_err != ESP_OK) {
        ESP_LOGW(TAG, "sleep wake source setup failed: %s", esp_err_to_name(wake_err));
    }
    vTaskDelay(pdMS_TO_TICKS(80));
    esp_deep_sleep_start();
}

static void enter_charging_display_standby(bool *display_sleeping) {
    esp_err_t display_err = board_support_set_display_awake(&s_board, true);
    if (display_err != ESP_OK) {
        ESP_LOGW(TAG, "display standby wake failed: %s", esp_err_to_name(display_err));
        return;
    }
    esp_err_t boot_err = board_support_show_boot_screen(&s_board);
    if (boot_err != ESP_OK) {
        ESP_LOGW(TAG, "charging standby boot screen failed: %s", esp_err_to_name(boot_err));
        return;
    }
    if (display_sleeping != NULL) {
        *display_sleeping = true;
    }
    ESP_LOGI(TAG, "charging standby -> boot screen");
}

static bool wake_display_from_standby(bool *display_sleeping) {
    esp_err_t display_err = board_support_set_display_awake(&s_board, true);
    if (display_err != ESP_OK) {
        ESP_LOGW(TAG, "display wake failed: %s", esp_err_to_name(display_err));
        return false;
    }
    if (display_sleeping != NULL) {
        *display_sleeping = false;
    }
    ESP_LOGI(TAG, "display standby -> awake");
    return true;
}

static void run_assistant_shell(const neoagent_device_config_t *device_config, neoagent_session_state_t *session_state, const char *wearable_ws_url) {
    TickType_t last_widget_refresh = 0;
    TickType_t last_chrome_refresh = 0;
    TickType_t last_interaction = xTaskGetTickCount();
    size_t widget_index = 0;
    esp_err_t last_widget_status = ESP_ERR_NOT_FOUND;
    board_touch_event_t touch_event = {0};
    board_button_event_t button_event = {0};
    wearable_voice_snapshot_t voice_snapshot = {0};
    background_recording_snapshot_t recording_snapshot = {0};
    shell_tab_t current_tab = SHELL_TAB_ASSISTANT;
    settings_view_t settings_view = SETTINGS_VIEW_ROOT;
    bool settings_show_reset = false;
    bool boot_voice_hold_active = false;
    bool charging = false;
    bool display_sleeping = false;
    bool suppress_power_until_release = false;
    bool suppress_boot_until_release = false;

    if (wearable_ws_url != NULL && wearable_ws_url[0] != '\0') {
        esp_err_t voice_err = wearable_voice_client_init(
            &s_voice_client,
            &s_board,
            wearable_ws_url,
            session_state->session_cookie,
            device_config->device_label
        );
        if (voice_err != ESP_OK) {
            ESP_LOGW(TAG, "voice client init failed: %s", esp_err_to_name(voice_err));
        }
    }
    ESP_ERROR_CHECK(screen_router_navigate(&s_router, NEOAGENT_SCREEN_ASSISTANT));
    update_power_chrome();
    const neoagent_status_chrome_t *initial_power_status = power_manager_get_status(&s_power_manager);
    charging = initial_power_status != NULL && initial_power_status->charging;
    last_interaction = xTaskGetTickCount();
    vTaskDelay(pdMS_TO_TICKS(1500));
    wearable_voice_client_snapshot(&s_voice_client, &voice_snapshot);
    background_recording_client_snapshot(&s_recording_client, &recording_snapshot);
    render_current_tab(current_tab, device_config, session_state, &s_widgets, widget_index, settings_view, last_widget_status, &voice_snapshot, &recording_snapshot, true, settings_show_reset);

    while (true) {
        TickType_t now = xTaskGetTickCount();
        if (display_sleeping) {
            if (board_support_poll_buttons(&s_board, &button_event) == ESP_OK &&
                (button_event.power_pressed || button_event.power_released || button_event.power_short_press || button_event.power_long_press || button_event.boot_pressed || button_event.boot_released || button_event.boot_short_press || button_event.boot_long_press)) {
                last_interaction = now;
                if (button_event.power_pressed || button_event.power_long_press || button_event.power_short_press) {
                    suppress_power_until_release = true;
                }
                if (button_event.boot_pressed || button_event.boot_long_press || button_event.boot_short_press) {
                    suppress_boot_until_release = true;
                }
                if (wake_display_from_standby(&display_sleeping)) {
                    update_power_chrome();
                    render_current_tab(current_tab, device_config, session_state, &s_widgets, widget_index, settings_view, last_widget_status, &voice_snapshot, &recording_snapshot, true, settings_show_reset);
                    last_chrome_refresh = 0;
                    last_widget_refresh = 0;
                }
                vTaskDelay(pdMS_TO_TICKS(20));
                continue;
            }
            if (board_support_poll_touch(&s_board, &touch_event) == ESP_OK &&
                (touch_event.pressed || touch_event.released || touch_event.tapped || touch_event.swipe_up || touch_event.swipe_down)) {
                last_interaction = now;
                if (wake_display_from_standby(&display_sleeping)) {
                    update_power_chrome();
                    render_current_tab(current_tab, device_config, session_state, &s_widgets, widget_index, settings_view, last_widget_status, &voice_snapshot, &recording_snapshot, true, settings_show_reset);
                    last_chrome_refresh = 0;
                    last_widget_refresh = 0;
                }
                vTaskDelay(pdMS_TO_TICKS(20));
                continue;
            }
        }
        if (is_voice_available()) {
            esp_err_t voice_poll_err = wearable_voice_client_poll(&s_voice_client);
            if (voice_poll_err != ESP_OK && voice_poll_err != ESP_ERR_TIMEOUT) {
                ESP_LOGW(TAG, "voice poll failed: %s", esp_err_to_name(voice_poll_err));
            }
        }
        background_recording_client_snapshot(&s_recording_client, &recording_snapshot);
        
        // Keep network/voice alive while charging standby has only turned the AMOLED off.
        if (!display_sleeping) {
            if (last_chrome_refresh == 0 || now - last_chrome_refresh >= pdMS_TO_TICKS(NEOAGENT_CHROME_REFRESH_INTERVAL_MS)) {
                bool chrome_changed = update_power_chrome();
                const neoagent_status_chrome_t *power_status = power_manager_get_status(&s_power_manager);
                charging = power_status != NULL && power_status->charging;
                static char last_time_label[8] = "--:--";
                char next_time_label[8] = {0};
                format_time_label(next_time_label, sizeof(next_time_label));
                if (strcmp(last_time_label, next_time_label) != 0) {
                    snprintf(last_time_label, sizeof(last_time_label), "%s", next_time_label);
                    chrome_changed = true;
                }
                if (chrome_changed || current_tab == SHELL_TAB_RECORDING || (current_tab == SHELL_TAB_ASSISTANT && background_recording_client_is_active(&s_recording_client))) {
                    render_current_tab(current_tab, device_config, session_state, &s_widgets, widget_index, settings_view, last_widget_status, &voice_snapshot, &recording_snapshot, true, settings_show_reset);
                }
                last_chrome_refresh = now;
            }
            wearable_voice_snapshot_t previous_voice_snapshot = voice_snapshot;
            wearable_voice_client_snapshot(&s_voice_client, &voice_snapshot);
            if (current_tab == SHELL_TAB_ASSISTANT && voice_snapshot_changed(&previous_voice_snapshot, &voice_snapshot)) {
                render_current_tab(current_tab, device_config, session_state, &s_widgets, widget_index, settings_view, last_widget_status, &voice_snapshot, &recording_snapshot, true, settings_show_reset);
            }

            if (last_widget_refresh == 0 || now - last_widget_refresh >= pdMS_TO_TICKS(NEOAGENT_WIDGET_REFRESH_INTERVAL_MS)) {
                ESP_LOGI(TAG, "refreshing widgets");
                esp_err_t refresh_err = widget_repository_refresh(&s_widgets, device_config->server_url, session_state);
                last_widget_status = refresh_err;
                if (refresh_err == ESP_OK && s_widgets.count > 0) {
                    ESP_LOGI(TAG, "loaded %u widgets", (unsigned)s_widgets.count);
                    widget_index = 0;
                } else if (refresh_err == ESP_ERR_NOT_FOUND) {
                    ESP_LOGI(TAG, "no widgets available for paired user");
                } else {
                    ESP_LOGW(TAG, "widget refresh failed: %s", esp_err_to_name(refresh_err));
                }
                if (refresh_err == ESP_OK) {
                    render_current_tab(current_tab, device_config, session_state, &s_widgets, widget_index, settings_view, last_widget_status, &voice_snapshot, &recording_snapshot, true, settings_show_reset);
                }
                last_widget_refresh = now;
            }
        } else {
            // Still update voice snapshot while the display is sleeping.
            wearable_voice_client_snapshot(&s_voice_client, &voice_snapshot);
            if (last_chrome_refresh == 0 || now - last_chrome_refresh >= pdMS_TO_TICKS(NEOAGENT_CHROME_REFRESH_INTERVAL_MS)) {
                update_power_chrome();
                const neoagent_status_chrome_t *power_status = power_manager_get_status(&s_power_manager);
                charging = power_status != NULL && power_status->charging;
                last_chrome_refresh = now;
                if (!charging) {
                    enter_sleep_due_to_idle(&voice_snapshot);
                }
            }
        }

        if (board_support_poll_touch(&s_board, &touch_event) == ESP_OK &&
            (touch_event.pressed || touch_event.released || touch_event.tapped || touch_event.swipe_up || touch_event.swipe_down)) {
            last_interaction = now;
            ESP_LOGI(
                TAG,
                "touch event x=%u y=%u pressed=%d released=%d tapped=%d swipe_up=%d swipe_down=%d",
                touch_event.x,
                touch_event.y,
                touch_event.pressed,
                touch_event.released,
                touch_event.tapped,
                touch_event.swipe_up,
                touch_event.swipe_down
            );
            if (display_sleeping) {
                if (!wake_display_from_standby(&display_sleeping)) {
                    continue;
                }
                update_power_chrome();
                render_current_tab(current_tab, device_config, session_state, &s_widgets, widget_index, settings_view, last_widget_status, &voice_snapshot, &recording_snapshot, true, settings_show_reset);
                last_chrome_refresh = 0;
                last_widget_refresh = 0;
                continue;
            }
            if (touch_event.pressed && current_tab == SHELL_TAB_SETTINGS && settings_view != SETTINGS_VIEW_ROOT && !settings_show_reset &&
                touch_event.x >= NEOAGENT_NAV_WIDTH &&
                touch_event.y >= NEOAGENT_SETTINGS_BACK_TOP_Y && touch_event.y <= NEOAGENT_SETTINGS_BACK_BOTTOM_Y) {
                settings_view = SETTINGS_VIEW_ROOT;
                render_current_tab(current_tab, device_config, session_state, &s_widgets, widget_index, settings_view, last_widget_status, &voice_snapshot, &recording_snapshot, true, settings_show_reset);
                continue;
            }

            if (touch_event.pressed && touch_event.x < NEOAGENT_NAV_WIDTH) {
                if (touch_event.y < NEOAGENT_NAV_ASSISTANT_MAX_Y) {
                    current_tab = SHELL_TAB_ASSISTANT;
                } else if (touch_event.y < NEOAGENT_NAV_WIDGETS_MAX_Y) {
                    current_tab = SHELL_TAB_WIDGETS;
                } else if (touch_event.y < NEOAGENT_NAV_RECORDING_MAX_Y) {
                    current_tab = SHELL_TAB_RECORDING;
                } else {
                    settings_view = SETTINGS_VIEW_ROOT;
                    settings_show_reset = false;
                    current_tab = SHELL_TAB_SETTINGS;
                }
                ESP_LOGI(TAG, "nav -> tab=%d", (int)current_tab);
                render_current_tab(current_tab, device_config, session_state, &s_widgets, widget_index, settings_view, last_widget_status, &voice_snapshot, &recording_snapshot, true, settings_show_reset);
                vTaskDelay(pdMS_TO_TICKS(20));
                continue;
            }

            if (current_tab == SHELL_TAB_ASSISTANT) {
                const int32_t dx = (int32_t)touch_event.x - NEOAGENT_ASSISTANT_ORB_CENTER_X;
                const int32_t dy = (int32_t)touch_event.y - NEOAGENT_ASSISTANT_ORB_CENTER_Y;
                const bool in_orb = ((dx * dx) + (dy * dy)) <= (NEOAGENT_ASSISTANT_ORB_RADIUS * NEOAGENT_ASSISTANT_ORB_RADIUS);
                if (touch_event.pressed && in_orb && !voice_snapshot.recording && is_voice_available() && !background_recording_client_is_active(&s_recording_client)) {
                    if (wearable_voice_client_start_ptt(&s_voice_client) != ESP_OK) {
                        ESP_LOGW(TAG, "voice start failed");
                    }
                    wearable_voice_client_snapshot(&s_voice_client, &voice_snapshot);
                    render_current_tab(current_tab, device_config, session_state, &s_widgets, widget_index, settings_view, last_widget_status, &voice_snapshot, &recording_snapshot, true, settings_show_reset);
                } else if (touch_event.pressed && in_orb && !is_voice_available()) {
                    ESP_LOGW(TAG, "voice transport unavailable on firmware");
                } else if (touch_event.pressed && in_orb && background_recording_client_is_active(&s_recording_client)) {
                    render_current_tab(current_tab, device_config, session_state, &s_widgets, widget_index, settings_view, last_widget_status, &voice_snapshot, &recording_snapshot, true, settings_show_reset);
                } else if (touch_event.released && voice_snapshot.recording) {
                    wearable_voice_client_stop_ptt(&s_voice_client);
                    wearable_voice_client_snapshot(&s_voice_client, &voice_snapshot);
                    render_current_tab(current_tab, device_config, session_state, &s_widgets, widget_index, settings_view, last_widget_status, &voice_snapshot, &recording_snapshot, true, settings_show_reset);
                }
            } else if (current_tab == SHELL_TAB_WIDGETS) {
                if (touch_event.tapped && touch_event.y >= NEOAGENT_WIDGET_BODY_TOP_Y && touch_event.y <= NEOAGENT_WIDGET_BODY_BOTTOM_Y && touch_event.x <= NEOAGENT_WIDGET_PREV_MAX_X && s_widgets.count > 0) {
                    widget_index = widget_index == 0 ? s_widgets.count - 1 : widget_index - 1;
                } else if (touch_event.tapped && touch_event.y >= NEOAGENT_WIDGET_BODY_TOP_Y && touch_event.y <= NEOAGENT_WIDGET_BODY_BOTTOM_Y && touch_event.x >= NEOAGENT_WIDGET_NEXT_MIN_X && s_widgets.count > 0) {
                    widget_index = (widget_index + 1) % s_widgets.count;
                } else if (touch_event.tapped) {
                    last_widget_refresh = 0;
                }
                render_current_tab(current_tab, device_config, session_state, &s_widgets, widget_index, settings_view, last_widget_status, &voice_snapshot, &recording_snapshot, true, settings_show_reset);
            } else if (current_tab == SHELL_TAB_RECORDING) {
                const int32_t dx = (int32_t)touch_event.x - NEOAGENT_RECORDING_ORB_CENTER_X;
                const int32_t dy = (int32_t)touch_event.y - NEOAGENT_RECORDING_ORB_CENTER_Y;
                const bool in_orb = ((dx * dx) + (dy * dy)) <= (NEOAGENT_RECORDING_ORB_RADIUS * NEOAGENT_RECORDING_ORB_RADIUS);
                if (touch_event.tapped && in_orb) {
                    if (background_recording_client_is_active(&s_recording_client)) {
                        background_recording_client_stop(&s_recording_client, "ended");
                    } else if (voice_snapshot.recording) {
                        wearable_voice_client_stop_ptt(&s_voice_client);
                    } else {
                        esp_err_t recording_err = background_recording_client_start(
                            &s_recording_client,
                            device_config->server_url,
                            session_state,
                            device_config->device_label
                        );
                        if (recording_err != ESP_OK) {
                            ESP_LOGW(TAG, "recording start failed: %s", esp_err_to_name(recording_err));
                        }
                    }
                    background_recording_client_snapshot(&s_recording_client, &recording_snapshot);
                }
                render_current_tab(current_tab, device_config, session_state, &s_widgets, widget_index, settings_view, last_widget_status, &voice_snapshot, &recording_snapshot, true, settings_show_reset);
            } else if (current_tab == SHELL_TAB_SETTINGS) {
                if (touch_event.swipe_up) {
                    settings_show_reset = true;
                } else if (touch_event.swipe_down) {
                    settings_show_reset = false;
                } else if (!settings_show_reset && settings_view == SETTINGS_VIEW_ROOT && touch_event.tapped &&
                           touch_event.y >= NEOAGENT_SETTINGS_NETWORK_TOP_Y && touch_event.y <= NEOAGENT_SETTINGS_NETWORK_BOTTOM_Y) {
                    settings_view = SETTINGS_VIEW_NETWORK;
                } else if (!settings_show_reset && settings_view == SETTINGS_VIEW_ROOT && touch_event.tapped &&
                           touch_event.y >= NEOAGENT_SETTINGS_UPDATE_TOP_Y && touch_event.y <= NEOAGENT_SETTINGS_UPDATE_BOTTOM_Y) {
                    settings_view = SETTINGS_VIEW_UPDATE;
                } else if (!settings_show_reset && settings_view == SETTINGS_VIEW_UPDATE && touch_event.tapped &&
                           touch_event.y >= NEOAGENT_SETTINGS_UPDATE_STABLE_TOP_Y && touch_event.y <= NEOAGENT_SETTINGS_UPDATE_STABLE_BOTTOM_Y) {
                    if (persist_firmware_update_channel("stable") == ESP_OK) {
                        ESP_LOGI(TAG, "firmware channel set to stable");
                    } else {
                        ESP_LOGW(TAG, "failed to persist stable firmware channel");
                    }
                } else if (!settings_show_reset && settings_view == SETTINGS_VIEW_UPDATE && touch_event.tapped &&
                           touch_event.y >= NEOAGENT_SETTINGS_UPDATE_BETA_TOP_Y && touch_event.y <= NEOAGENT_SETTINGS_UPDATE_BETA_BOTTOM_Y) {
                    if (persist_firmware_update_channel("beta") == ESP_OK) {
                        ESP_LOGI(TAG, "firmware channel set to beta");
                    } else {
                        ESP_LOGW(TAG, "failed to persist beta firmware channel");
                    }
                } else if (!settings_show_reset && settings_view == SETTINGS_VIEW_UPDATE && touch_event.tapped &&
                           touch_event.y >= NEOAGENT_SETTINGS_UPDATE_ACTION_TOP_Y && touch_event.y <= NEOAGENT_SETTINGS_UPDATE_ACTION_BOTTOM_Y) {
                    render_current_tab(current_tab, device_config, session_state, &s_widgets, widget_index, settings_view, last_widget_status, &voice_snapshot, &recording_snapshot, true, settings_show_reset);
                    start_firmware_update(device_config, session_state);
                    continue;
                } else if (!settings_show_reset && settings_view == SETTINGS_VIEW_UPDATE && touch_event.tapped &&
                           touch_event.y >= NEOAGENT_SETTINGS_SETUP_ACTION_TOP_Y && touch_event.y <= NEOAGENT_SETTINGS_SETUP_ACTION_BOTTOM_Y) {
                    ESP_LOGI(TAG, "setup mode requested from settings");
                    stop_recording_if_needed("setup_mode");
                    ESP_ERROR_CHECK(session_store_clear_device_config(&s_session_store));
                    esp_restart();
                } else if (settings_show_reset && touch_event.tapped && touch_event.y >= NEOAGENT_SETTINGS_RESET_TOP_Y && touch_event.y <= NEOAGENT_SETTINGS_RESET_BOTTOM_Y) {
                    ESP_LOGI(TAG, "reset device requested from settings");
                    stop_recording_if_needed("reset");
                    ESP_ERROR_CHECK(session_store_clear_session(&s_session_store));
                    ESP_ERROR_CHECK(session_store_clear_device_config(&s_session_store));
                    ESP_ERROR_CHECK(session_store_clear_firmware_update_settings(&s_session_store));
                    esp_restart();
                }
                render_current_tab(current_tab, device_config, session_state, &s_widgets, widget_index, settings_view, last_widget_status, &voice_snapshot, &recording_snapshot, true, settings_show_reset);
            }
        }

        if (board_support_poll_buttons(&s_board, &button_event) == ESP_OK) {
            if (button_event.power_pressed || button_event.power_released || button_event.power_short_press || button_event.power_long_press || button_event.boot_pressed || button_event.boot_released || button_event.boot_short_press || button_event.boot_long_press) {
                last_interaction = now;
            }
            if (display_sleeping) {
                if (button_event.power_pressed || button_event.power_long_press || button_event.power_short_press) {
                    suppress_power_until_release = true;
                }
                if (button_event.boot_pressed || button_event.boot_long_press || button_event.boot_short_press) {
                    suppress_boot_until_release = true;
                }
                if (!wake_display_from_standby(&display_sleeping)) {
                    continue;
                }
                update_power_chrome();
                render_current_tab(current_tab, device_config, session_state, &s_widgets, widget_index, settings_view, last_widget_status, &voice_snapshot, &recording_snapshot, true, settings_show_reset);
                last_chrome_refresh = 0;
                last_widget_refresh = 0;
                continue;
            }
            if (suppress_power_until_release) {
                if (button_event.power_released) {
                    suppress_power_until_release = false;
                }
                button_event.power_pressed = false;
                button_event.power_released = false;
                button_event.power_short_press = false;
                button_event.power_long_press = false;
            }
            if (suppress_boot_until_release) {
                if (button_event.boot_released) {
                    suppress_boot_until_release = false;
                }
                button_event.boot_pressed = false;
                button_event.boot_released = false;
                button_event.boot_short_press = false;
                button_event.boot_long_press = false;
            }
            if (button_event.power_long_press) {
                if (recording_activity_in_progress(&voice_snapshot, &recording_snapshot)) {
                    ESP_LOGI(TAG, "power long press ignored while recording is active");
                    continue;
                }
                ESP_LOGI(TAG, "power long press -> %s", charging ? "charging standby" : "deep sleep");
                if (charging) {
                    if (!display_sleeping) {
                        enter_charging_display_standby(&display_sleeping);
                        continue;
                    }
                } else {
                    enter_sleep_due_to_idle(&voice_snapshot);
                }
            } else if (button_event.power_short_press) {
                current_tab = (shell_tab_t)((current_tab + 1) % 4);
                ESP_LOGI(TAG, "power short press -> tab=%d", (int)current_tab);
                render_current_tab(current_tab, device_config, session_state, &s_widgets, widget_index, settings_view, last_widget_status, &voice_snapshot, &recording_snapshot, true, settings_show_reset);
            }

            if (button_event.boot_pressed) {
                if (is_voice_available() && !voice_snapshot.recording && !background_recording_client_is_active(&s_recording_client)) {
                    current_tab = SHELL_TAB_ASSISTANT;
                    wearable_voice_client_start_ptt(&s_voice_client);
                    boot_voice_hold_active = true;
                    wearable_voice_client_snapshot(&s_voice_client, &voice_snapshot);
                    render_current_tab(current_tab, device_config, session_state, &s_widgets, widget_index, settings_view, last_widget_status, &voice_snapshot, &recording_snapshot, true, settings_show_reset);
                }
            } else if (button_event.boot_released && boot_voice_hold_active) {
                boot_voice_hold_active = false;
                if (voice_snapshot.recording) {
                    wearable_voice_client_stop_ptt(&s_voice_client);
                }
                ESP_LOGI(TAG, "boot release handled tab=%d", (int)current_tab);
                wearable_voice_client_snapshot(&s_voice_client, &voice_snapshot);
                render_current_tab(current_tab, device_config, session_state, &s_widgets, widget_index, settings_view, last_widget_status, &voice_snapshot, &recording_snapshot, true, settings_show_reset);
            } else if (button_event.boot_short_press) {
                if (current_tab == SHELL_TAB_WIDGETS && s_widgets.count > 0) {
                    widget_index = (widget_index + 1) % s_widgets.count;
                } else if (current_tab == SHELL_TAB_RECORDING) {
                    if (background_recording_client_is_active(&s_recording_client)) {
                        background_recording_client_stop(&s_recording_client, "ended");
                    } else {
                        background_recording_client_start(&s_recording_client, device_config->server_url, session_state, device_config->device_label);
                    }
                    background_recording_client_snapshot(&s_recording_client, &recording_snapshot);
                } else {
                    last_widget_refresh = 0;
                }
                ESP_LOGI(TAG, "boot short press handled tab=%d", (int)current_tab);
                wearable_voice_client_snapshot(&s_voice_client, &voice_snapshot);
                render_current_tab(current_tab, device_config, session_state, &s_widgets, widget_index, settings_view, last_widget_status, &voice_snapshot, &recording_snapshot, true, settings_show_reset);
            } else if (button_event.boot_long_press) {
                ESP_LOGI(TAG, "boot long press tab=%d", (int)current_tab);
            }
        }

        const bool touch_activity = touch_event.pressed || touch_event.released || touch_event.tapped || touch_event.swipe_up || touch_event.swipe_down;
        const bool button_activity = button_event.power_pressed || button_event.power_released || button_event.power_short_press || button_event.power_long_press || button_event.boot_pressed || button_event.boot_released || button_event.boot_short_press || button_event.boot_long_press;

        if (touch_activity || button_activity) {
            last_interaction = now;
            if (display_sleeping) {
                if (!wake_display_from_standby(&display_sleeping)) {
                    vTaskDelay(pdMS_TO_TICKS(80));
                    continue;
                }
                update_power_chrome();
                render_current_tab(current_tab, device_config, session_state, &s_widgets, widget_index, settings_view, last_widget_status, &voice_snapshot, &recording_snapshot, true, settings_show_reset);
                last_chrome_refresh = 0;
                last_widget_refresh = 0;
            }
        } else if (now - last_interaction >= pdMS_TO_TICKS(NEOAGENT_IDLE_TIMEOUT_MS)) {
            if (recording_activity_in_progress(&voice_snapshot, &recording_snapshot)) {
                last_interaction = now;
                continue;
            }
            if (charging) {
                if (!display_sleeping) {
                    enter_charging_display_standby(&display_sleeping);
                }
            } else {
                enter_sleep_due_to_idle(&voice_snapshot);
            }
        }
        vTaskDelay(pdMS_TO_TICKS(display_sleeping ? 20 : 80));
    }
}

static esp_err_t run_pairing_flow(const neoagent_device_config_t *device_config, neoagent_session_state_t *session_state) {
    if (device_config == NULL || session_state == NULL) {
        return ESP_ERR_INVALID_ARG;
    }

    ESP_ERROR_CHECK(screen_router_navigate(&s_router, NEOAGENT_SCREEN_PAIRING));
    ESP_ERROR_CHECK(ui_renderer_set_screen(&s_ui, screen_router_current(&s_router)));

    log_internal_heap("before_pairing_create");
    if (pairing_manager_create_challenge(&s_pairing, device_config->server_url, device_config->device_label) != ESP_OK) {
        ESP_LOGE(TAG, "failed to create pairing challenge");
        return ESP_FAIL;
    }
    ESP_ERROR_CHECK(ui_renderer_show_pairing_qr(&s_ui, s_pairing.qr_state.qr_payload));
    log_internal_heap("after_pairing_qr");

    while (true) {
        vTaskDelay(pdMS_TO_TICKS(3000));
        log_internal_heap("before_pairing_poll");
        esp_err_t poll_err = pairing_manager_poll_status(&s_pairing, device_config->server_url);
        if (poll_err != ESP_OK) {
            ESP_LOGW(TAG, "pairing poll failed: %s", esp_err_to_name(poll_err));
            continue;
        }
        ESP_LOGI(TAG, "pairing state=%d challenge=%s", (int)s_pairing.state, s_pairing.qr_state.challenge_id);
        if (s_pairing.state == PAIRING_STATE_APPROVED) {
            neoagent_session_state_t claimed_session = {0};
            if (pairing_manager_claim_session(&s_pairing, device_config->server_url, &claimed_session, &s_session_store) == ESP_OK) {
                ESP_LOGI(TAG, "pairing claimed for user=%s", claimed_session.username);
                *session_state = claimed_session;
                return ESP_OK;
            }
            ESP_LOGW(TAG, "pairing approved but claim failed; refreshing challenge");
            pairing_manager_mark_expired(&s_pairing);
        } else if (s_pairing.state == PAIRING_STATE_CLAIMED) {
            neoagent_session_state_t persisted_session = {0};
            if (session_store_load_session(&s_session_store, &persisted_session) == ESP_OK && persisted_session.authenticated) {
                *session_state = persisted_session;
                return ESP_OK;
            }
            ESP_LOGW(TAG, "pairing reported claimed without a persisted session; refreshing challenge");
            pairing_manager_mark_expired(&s_pairing);
        } else if (s_pairing.state == PAIRING_STATE_EXPIRED) {
            ESP_LOGI(TAG, "pairing challenge expired; creating a new one");
            if (pairing_manager_create_challenge(&s_pairing, device_config->server_url, device_config->device_label) == ESP_OK) {
                ESP_ERROR_CHECK(ui_renderer_show_pairing_qr(&s_ui, s_pairing.qr_state.qr_payload));
                log_internal_heap("after_pairing_refresh");
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
    esp_reset_reason_t reason = esp_reset_reason();
    ESP_LOGI(TAG, "reset_reason=%d (%s)", (int)reason, reset_reason_name(reason));
    char wearable_ws_url[NEOAGENT_WS_URL_MAX] = {0};

    ESP_ERROR_CHECK(session_store_init(&s_session_store, NULL));
    ESP_ERROR_CHECK(provisioning_manager_init(&s_provisioning));
    ESP_ERROR_CHECK(pairing_manager_init(&s_pairing));
    ESP_ERROR_CHECK(widget_repository_init(&s_widgets));
    ESP_ERROR_CHECK(power_manager_init(&s_power_manager));
    ESP_ERROR_CHECK(screen_router_init(&s_router, NEOAGENT_SCREEN_PROVISIONING));
    ESP_ERROR_CHECK(app_shell_init(&s_shell, NEOAGENT_SCREEN_PROVISIONING));
    ESP_ERROR_CHECK(board_support_init(&s_board));
    ESP_ERROR_CHECK(background_recording_client_init(&s_recording_client, &s_board));
    ESP_ERROR_CHECK(ui_renderer_init(&s_ui, &s_board));
    const esp_app_desc_t *app_desc = esp_app_get_description();
    ESP_ERROR_CHECK(update_manager_init(&s_updates, app_desc != NULL ? app_desc->version : "unknown"));

    neoagent_device_config_t device_config = {0};
    neoagent_session_state_t session_state = {0};
    neoagent_firmware_update_settings_t firmware_update_settings = {0};
    const esp_err_t config_err = session_store_load_device_config(&s_session_store, &device_config);
    const esp_err_t session_err = session_store_load_session(&s_session_store, &session_state);
    const esp_err_t firmware_update_err = session_store_load_firmware_update_settings(&s_session_store, &firmware_update_settings);

    if (firmware_update_err == ESP_OK && firmware_update_settings.channel[0] != '\0') {
        ESP_ERROR_CHECK(update_manager_set_channel(&s_updates, firmware_update_settings.channel));
    } else {
        ESP_ERROR_CHECK(update_manager_set_channel(&s_updates, "stable"));
    }

    if (config_err == ESP_OK) {
        provisioning_manager_set_pending_config(&s_provisioning, &device_config);
        ESP_ERROR_CHECK(screen_router_navigate(&s_router, NEOAGENT_SCREEN_PAIRING));
        ESP_ERROR_CHECK(ui_renderer_set_screen(&s_ui, screen_router_current(&s_router)));
        ESP_ERROR_CHECK(board_support_show_message(&s_board, "Connecting Wi-Fi", device_config.wifi_ssid, "Waiting for network before QR pairing."));
        if (provisioning_manager_connect_station(&s_provisioning, &device_config, 20000) == ESP_OK) {
            esp_err_t time_sync_err = provisioning_manager_sync_time(&s_provisioning, device_config.server_url, 10000);
            if (time_sync_err != ESP_OK) {
                ESP_LOGW(TAG, "time sync failed: %s", esp_err_to_name(time_sync_err));
            }
            build_wearable_ws_url(device_config.server_url, wearable_ws_url, sizeof(wearable_ws_url));
        } else {
            ESP_LOGW(TAG, "wifi connection failed; returning to setup portal");
            s_provisioning.has_pending_config = false;
            memset(&device_config, 0, sizeof(device_config));
        }
    }

    if (provisioning_manager_has_complete_config(&s_provisioning)) {
        if (session_err == ESP_OK) {
            run_assistant_shell(&device_config, &session_state, wearable_ws_url);
        } else {
            ESP_ERROR_CHECK(run_pairing_flow(&device_config, &session_state));
            run_assistant_shell(&device_config, &session_state, wearable_ws_url);
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

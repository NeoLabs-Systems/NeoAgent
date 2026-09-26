#include <stdio.h>
#include <string.h>
#include <time.h>

#include "app_shell.h"
#include "board_support.h"
#include "driver/gpio.h"
#include "driver/rtc_io.h"
#include "esp_app_desc.h"
#include "esp_ota_ops.h"
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

static const char *TAG = "NeoAgentWearable";

#define NEOAGENT_RUNTIME_TASK_STACK_SIZE 24576
#define NEOAGENT_CHROME_REFRESH_INTERVAL_MS 5000
#define NEOAGENT_TOUCH_ACTION_COOLDOWN_MS 300
#define NEOAGENT_SLEEP_BOOT_GPIO GPIO_NUM_0
#define NEOAGENT_SLEEP_POWER_GPIO GPIO_NUM_17
#define NEOAGENT_SLEEP_WAKE_GPIO_MASK ((1ULL << NEOAGENT_SLEEP_BOOT_GPIO) | (1ULL << NEOAGENT_SLEEP_POWER_GPIO))
#define NEOAGENT_SLEEP_WAKE_RELEASE_TIMEOUT_MS 3000
#define NEOAGENT_SLEEP_WAKE_RELEASE_STABLE_MS 180
typedef enum {
    SHELL_TAB_CALL = 0,
    SHELL_TAB_SETTINGS = 1,
} shell_tab_t;

// The last hand-off result or failed call, for the mascot's done/blocked face.
typedef struct {
    uint32_t id;
    bool ok;
    uint32_t task_outcome_seq;
    uint32_t error_seq;
} call_moment_t;

// Everything the shell shows, redrawn only when something in it changed.
typedef struct {
    shell_tab_t tab;
    board_settings_page_t page;
    board_call_view_t call;
    char status[48];
    char caption[NEOAGENT_VOICE_TEXT_MAX];
    char task[NEOAGENT_VOICE_TEXT_MAX];
} shell_view_t;

static session_store_t s_session_store;
static provisioning_manager_t s_provisioning;
static pairing_manager_t s_pairing;
static wearable_voice_client_t *s_voice;
static power_manager_t s_power_manager;
static screen_router_t s_router;
static app_shell_t s_shell;
static board_support_t s_board;
static ui_renderer_t s_ui;
static update_manager_t s_updates;

static esp_err_t persist_firmware_update_channel(const char *channel);
static size_t configured_wifi_network_count(const neoagent_device_config_t *device_config);

static bool start_firmware_update(
    const neoagent_device_config_t *device_config,
    const neoagent_session_state_t *session_state,
    bool interactive,
    bool *display_sleeping
);
static bool wake_display_from_standby(bool *display_sleeping);

typedef struct {
    bool *display_sleeping;
    bool install_started;
} firmware_install_context_t;

static void log_ui_result(esp_err_t err, const char *operation) {
    if (err != ESP_OK) {
        ESP_LOGW(TAG, "ui operation=%s failed: %s", operation, esp_err_to_name(err));
    }
}

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

static void confirm_healthy_ota_boot(void) {
    const esp_partition_t *running = esp_ota_get_running_partition();
    esp_ota_img_states_t state = ESP_OTA_IMG_UNDEFINED;
    if (running == NULL || esp_ota_get_state_partition(running, &state) != ESP_OK || state != ESP_OTA_IMG_PENDING_VERIFY) {
        return;
    }
    esp_err_t err = esp_ota_mark_app_valid_cancel_rollback();
    if (err == ESP_OK) {
        ESP_LOGI(TAG, "confirmed healthy OTA image");
    } else {
        ESP_LOGE(TAG, "failed to confirm OTA image: %s", esp_err_to_name(err));
    }
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

static void read_voice(wearable_voice_snapshot_t *snapshot) {
    if (s_voice != NULL) {
        wearable_voice_client_snapshot(s_voice, snapshot);
    } else {
        memset(snapshot, 0, sizeof(*snapshot));
    }
}

static void track_moment(call_moment_t *moment, const wearable_voice_snapshot_t *voice) {
    if (voice->task_outcome_seq != moment->task_outcome_seq) {
        moment->task_outcome_seq = voice->task_outcome_seq;
        moment->id += 1;
        moment->ok = voice->task_outcome_ok;
    }
    if (voice->error_seq != moment->error_seq) {
        moment->error_seq = voice->error_seq;
        // A hiccup the server recovers from mid-call is not a failure.
        if (voice->call == WEARABLE_CALL_IDLE) {
            moment->id += 1;
            moment->ok = false;
        }
    }
}

// The mascot's mood read straight off the call; the stabilizer decides what shows.
static mascot_mood_t call_mood(const wearable_voice_snapshot_t *voice, const call_moment_t *moment) {
    if (!voice->server_connected) {
        return MASCOT_MOOD_ASLEEP;
    }
    if (voice->capturing || voice->speaking) {
        return MASCOT_MOOD_LISTENING;
    }
    if (voice->task_running) {
        return MASCOT_MOOD_WORKING;
    }
    if (voice->call == WEARABLE_CALL_CONNECTING || voice->reconnecting) {
        return MASCOT_MOOD_THINKING;
    }
    if (moment->id != 0) {
        return moment->ok ? MASCOT_MOOD_DONE : MASCOT_MOOD_BLOCKED;
    }
    return MASCOT_MOOD_IDLE;
}

static void format_call_status(char *status, size_t size, const wearable_voice_snapshot_t *voice) {
    if (voice->call == WEARABLE_CALL_CONNECTING) {
        snprintf(status, size, "Calling...");
        return;
    }
    if (voice->call == WEARABLE_CALL_IDLE) {
        snprintf(status, size, voice->server_connected ? "Tap to call" : "Connecting...");
        return;
    }
    const char *state = "Ready";
    if (voice->reconnecting) {
        state = "Reconnecting";
    } else if (voice->speaking) {
        state = "Speaking";
    } else if (voice->capturing) {
        state = "Listening";
    } else if (voice->hands_free) {
        state = "Muted";
    }
    const int64_t elapsed_us = voice->call_started_at_us > 0 ? esp_timer_get_time() - voice->call_started_at_us : 0;
    const unsigned seconds = (unsigned)(elapsed_us / 1000000);
    if (seconds >= 3600) {
        snprintf(status, size, "%02u:%02u:%02u - %s", seconds / 3600, (seconds / 60) % 60, seconds % 60, state);
    } else {
        snprintf(status, size, "%02u:%02u - %s", seconds / 60, seconds % 60, state);
    }
}

static void build_call_view(shell_view_t *view, const wearable_voice_snapshot_t *voice, mascot_mood_t mood) {
    board_call_view_t *call = &view->call;
    call->mood = mood;
    call->phase = voice->call == WEARABLE_CALL_ACTIVE
        ? BOARD_CALL_ACTIVE
        : (voice->call == WEARABLE_CALL_CONNECTING ? BOARD_CALL_DIALING : BOARD_CALL_IDLE);
    call->hands_free = voice->hands_free;
    call->capturing = voice->capturing;
    call->speaking = voice->speaking;
    call->name = "NeoAgent";
    format_call_status(view->status, sizeof(view->status), voice);
    call->status = view->status;
    // A call that failed or dropped says why until the next one starts.
    const bool show_error = voice->call == WEARABLE_CALL_IDLE && voice->last_error[0] != '\0';
    sanitize_display_text(view->caption, sizeof(view->caption), show_error ? voice->last_error : voice->caption);
    call->caption = view->caption;
    call->caption_from_assistant = !show_error && voice->caption_from_assistant;
    if (voice->task_running) {
        sanitize_display_text(view->task, sizeof(view->task), voice->task_request);
        call->task = view->task;
    } else {
        call->task = NULL;
    }
}

static bool call_view_changed(const shell_view_t *previous, const shell_view_t *current) {
    const board_call_view_t *a = &previous->call;
    const board_call_view_t *b = &current->call;
    return a->mood != b->mood
        || a->phase != b->phase
        || a->hands_free != b->hands_free
        || a->capturing != b->capturing
        || a->speaking != b->speaking
        || (a->task == NULL) != (b->task == NULL)
        || a->caption_from_assistant != b->caption_from_assistant
        || strcmp(previous->status, current->status) != 0
        || strcmp(previous->caption, current->caption) != 0
        || strcmp(previous->task, current->task) != 0;
}

static void render_settings(const neoagent_device_config_t *device_config, board_settings_page_t page) {
    char headline[140] = {0};
    char body[220] = {0};
    board_settings_view_t view = {.page = page};

    if (page == BOARD_SETTINGS_UPDATE) {
        view.channel = update_manager_channel(&s_updates);
    } else if (page == BOARD_SETTINGS_DEVICE) {
        const esp_app_desc_t *app_desc = esp_app_get_description();
        const uint32_t uptime_seconds = (uint32_t)(esp_timer_get_time() / 1000000);
        snprintf(headline, sizeof(headline), "%s", device_config != NULL && device_config->device_label[0] != '\0' ? device_config->device_label : "NeoAgent wearable");
        snprintf(
            body,
            sizeof(body),
            "Firmware %s\nUptime %uh %um\nFree memory %u KB\nWi-Fi %s",
            app_desc != NULL ? app_desc->version : "unknown",
            (unsigned)(uptime_seconds / 3600),
            (unsigned)((uptime_seconds / 60) % 60),
            (unsigned)(esp_get_free_heap_size() / 1024),
            provisioning_manager_is_connected(&s_provisioning) ? "connected" : "reconnecting"
        );
    } else if (page == BOARD_SETTINGS_NETWORK) {
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
    }
    view.headline = headline;
    view.body = body;
    log_ui_result(ui_renderer_show_settings(&s_ui, &view), "settings");
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

static void show_firmware_install_started(void *context) {
    firmware_install_context_t *install_context = (firmware_install_context_t *)context;
    bool *display_sleeping = install_context != NULL ? install_context->display_sleeping : NULL;
    if (install_context != NULL) {
        install_context->install_started = true;
    }
    if (display_sleeping != NULL && *display_sleeping && !wake_display_from_standby(display_sleeping)) {
        ESP_LOGW(TAG, "firmware install started while the display remained asleep");
    }
    log_ui_result(
        board_support_show_message(
            &s_board,
            MASCOT_MOOD_WORKING,
            "Installing Firmware",
            "Downloading the latest GitHub release...",
            "Keep the device powered on."
        ),
        "update_install"
    );
}

static bool start_firmware_update(
    const neoagent_device_config_t *device_config,
    const neoagent_session_state_t *session_state,
    bool interactive,
    bool *display_sleeping
) {
    if (device_config == NULL || session_state == NULL) {
        if (interactive) {
            log_ui_result(board_support_show_message(&s_board, MASCOT_MOOD_BLOCKED, "Update Failed", "Missing device state", "Cannot start OTA without a saved server and session."), "update_missing_state");
        }
        return false;
    }

    if (interactive) {
        log_ui_result(board_support_show_message(&s_board, MASCOT_MOOD_THINKING, "Checking For Updates", "Looking for the latest GitHub release...", "This can take a moment."), "update_start");
        vTaskDelay(pdMS_TO_TICKS(250));
    }

    firmware_install_context_t install_context = {
        .display_sleeping = display_sleeping,
        .install_started = false,
    };
    esp_err_t update_err = update_manager_auto_update(
        &s_updates,
        device_config->server_url,
        session_state,
        interactive,
        interactive ? show_firmware_install_started : NULL,
        &install_context
    );
    if (update_err == ESP_OK) {
        if (interactive) {
            log_ui_result(board_support_show_message(&s_board, MASCOT_MOOD_DONE, "Update Complete", "Rebooting into new firmware", "The device will restart now."), "update_complete");
            vTaskDelay(pdMS_TO_TICKS(1500));
        }
        esp_restart();
        return true;
    }

    if (update_err == ESP_ERR_INVALID_STATE) {
        ESP_LOGI(TAG, "firmware is already current");
        if (interactive) {
            log_ui_result(board_support_show_message(&s_board, MASCOT_MOOD_DONE, "Already Up To Date", "No firmware update was installed", "The current version matches the configured release."), "update_current");
        }
        return false;
    }

    if (update_err == ESP_ERR_NOT_FOUND) {
        ESP_LOGW(TAG, "firmware release asset is unavailable");
        if (interactive) {
            log_ui_result(board_support_show_message(&s_board, MASCOT_MOOD_IDLE, "Update Unavailable", "No firmware download is configured", "The manifest did not publish an OTA image."), "update_unavailable");
        }
        return false;
    }

    if (update_err == ESP_ERR_INVALID_ARG) {
        ESP_LOGW(TAG, "firmware update is missing server or session state");
        if (interactive) {
            log_ui_result(board_support_show_message(&s_board, MASCOT_MOOD_BLOCKED, "Update Failed", "Missing server or session", "Connect the device and sign in before trying again."), "update_invalid_state");
        }
        return false;
    }

    ESP_LOGW(TAG, "firmware update failed: %s (0x%x)", esp_err_to_name(update_err), (unsigned int)update_err);
    if (interactive || install_context.install_started) {
        const char *detail = update_err == ESP_ERR_INVALID_RESPONSE
            ? "The release server returned an invalid response"
            : update_err == ESP_ERR_TIMEOUT
                ? "The firmware download timed out"
                : "The firmware could not be downloaded or verified";
        log_ui_result(board_support_show_message(&s_board, MASCOT_MOOD_BLOCKED, "Update Failed", detail, "Check the connection and try again."), "update_failed");
    }
    return false;
}

static void refresh_chrome(const neoagent_session_state_t *session_state) {
    neoagent_status_chrome_t chrome = {0};
    char time_label[8];
    const neoagent_status_chrome_t *power_status = power_manager_get_status(&s_power_manager);
    if (power_status != NULL) {
        chrome = *power_status;
    }
    chrome.wifi_connected = provisioning_manager_is_connected(&s_provisioning);
    chrome.paired = session_state != NULL && session_state->authenticated;
    format_time_label(time_label, sizeof(time_label));
    log_ui_result(board_support_set_chrome(&s_board, &chrome, time_label), "chrome");
}

static void render_shell(const shell_view_t *view, const neoagent_device_config_t *device_config, const neoagent_session_state_t *session_state) {
    if (view->tab == SHELL_TAB_CALL) {
        log_ui_result(ui_renderer_show_call(&s_ui, &view->call), "call");
    } else {
        render_settings(device_config, view->page);
    }
    refresh_chrome(session_state);
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

static esp_err_t configure_deep_sleep_wake_pin(gpio_num_t gpio_num) {
    if (!esp_sleep_is_valid_wakeup_gpio(gpio_num)) {
        return ESP_ERR_INVALID_ARG;
    }

    esp_err_t err = rtc_gpio_init(gpio_num);
    if (err != ESP_OK) {
        return err;
    }
    err = rtc_gpio_set_direction(gpio_num, RTC_GPIO_MODE_INPUT_ONLY);
    if (err != ESP_OK) {
        return err;
    }
    err = rtc_gpio_pulldown_dis(gpio_num);
    if (err != ESP_OK) {
        return err;
    }
    return rtc_gpio_pullup_en(gpio_num);
}

static esp_err_t configure_deep_sleep_wake_sources(void) {
    esp_err_t err = configure_deep_sleep_wake_pin(NEOAGENT_SLEEP_BOOT_GPIO);
    if (err != ESP_OK) {
        return err;
    }
    err = configure_deep_sleep_wake_pin(NEOAGENT_SLEEP_POWER_GPIO);
    if (err != ESP_OK) {
        return err;
    }

    err = esp_sleep_enable_ext1_wakeup_io(NEOAGENT_SLEEP_WAKE_GPIO_MASK, ESP_EXT1_WAKEUP_ANY_LOW);
    if (err != ESP_OK) {
        return err;
    }
    return esp_sleep_pd_config(ESP_PD_DOMAIN_RTC_PERIPH, ESP_PD_OPTION_ON);
}

static void enter_deep_sleep(void) {
    if (s_voice != NULL) {
        wearable_voice_client_call_end(s_voice);
    }
    if (!wait_for_sleep_wake_buttons_released()) {
        ESP_LOGW(TAG, "deep sleep skipped because a wake button is still held");
        return;
    }
    esp_err_t wake_err = configure_deep_sleep_wake_sources();
    if (wake_err != ESP_OK) {
        ESP_LOGW(TAG, "deep sleep skipped because wake source setup failed: %s", esp_err_to_name(wake_err));
        return;
    }
    esp_err_t display_err = board_support_set_display_awake(&s_board, false);
    if (display_err != ESP_OK) {
        ESP_LOGW(TAG, "display off before sleep failed: %s", esp_err_to_name(display_err));
    } else {
        ESP_LOGI(TAG, "deep sleep -> display off");
    }
    vTaskDelay(pdMS_TO_TICKS(80));
    esp_deep_sleep_start();
}

static bool enter_display_standby(bool *display_sleeping) {
    esp_err_t display_err = board_support_set_display_awake(&s_board, false);
    if (display_err != ESP_OK) {
        ESP_LOGW(TAG, "display standby failed: %s", esp_err_to_name(display_err));
        return false;
    }
    if (display_sleeping != NULL) {
        *display_sleeping = true;
    }
    ESP_LOGI(TAG, "display -> standby");
    return true;
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

static void forget_session_and_restart(void) {
    ESP_LOGW(TAG, "saved wearable session was rejected; returning to pairing");
    ESP_ERROR_CHECK(session_store_clear_session(&s_session_store));
    vTaskDelay(pdMS_TO_TICKS(250));
    esp_restart();
}

// A tap on a settings control; returns true when the page must be redrawn.
static bool handle_settings_target(
    board_target_t target,
    shell_view_t *view,
    const neoagent_device_config_t *device_config,
    const neoagent_session_state_t *session_state,
    bool *display_sleeping
) {
    switch (target) {
        case BOARD_TARGET_BACK:
            if (view->page == BOARD_SETTINGS_ROOT) {
                view->tab = SHELL_TAB_CALL;
            } else {
                view->page = BOARD_SETTINGS_ROOT;
            }
            return true;
        case BOARD_TARGET_SETTINGS_NETWORK:
            view->page = BOARD_SETTINGS_NETWORK;
            return true;
        case BOARD_TARGET_SETTINGS_UPDATE:
            view->page = BOARD_SETTINGS_UPDATE;
            return true;
        case BOARD_TARGET_SETTINGS_DEVICE:
            view->page = BOARD_SETTINGS_DEVICE;
            return true;
        case BOARD_TARGET_SETTINGS_FORGET:
            view->page = BOARD_SETTINGS_FORGET;
            return true;
        case BOARD_TARGET_CHANNEL_STABLE:
        case BOARD_TARGET_CHANNEL_BETA: {
            const char *channel = target == BOARD_TARGET_CHANNEL_BETA ? "beta" : "stable";
            if (persist_firmware_update_channel(channel) != ESP_OK) {
                ESP_LOGW(TAG, "failed to persist %s firmware channel", channel);
                return false;
            }
            ESP_LOGI(TAG, "firmware channel set to %s", channel);
            return true;
        }
        case BOARD_TARGET_UPDATE_NOW:
            start_firmware_update(device_config, session_state, true, display_sleeping);
            return true;
        case BOARD_TARGET_SETUP_MODE:
            ESP_LOGI(TAG, "setup mode requested from settings");
            ESP_ERROR_CHECK(session_store_clear_device_config(&s_session_store));
            esp_restart();
            return false;
        case BOARD_TARGET_FORGET_CONFIRM:
            ESP_LOGI(TAG, "reset device requested from settings");
            ESP_ERROR_CHECK(session_store_clear_session(&s_session_store));
            ESP_ERROR_CHECK(session_store_clear_device_config(&s_session_store));
            ESP_ERROR_CHECK(session_store_clear_firmware_update_settings(&s_session_store));
            esp_restart();
            return false;
        default:
            return false;
    }
}

// A tap on a call control. Holding the push-to-talk button is handled on press and release.
static void handle_call_tap(board_target_t target, const wearable_voice_snapshot_t *voice, shell_view_t *view) {
    if (target == BOARD_TARGET_OPEN_SETTINGS) {
        view->tab = SHELL_TAB_SETTINGS;
        view->page = BOARD_SETTINGS_ROOT;
        return;
    }
    if (s_voice == NULL) {
        return;
    }
    switch (target) {
        case BOARD_TARGET_CALL:
            wearable_voice_client_call_start(s_voice);
            break;
        case BOARD_TARGET_END_CALL:
            wearable_voice_client_call_end(s_voice);
            break;
        case BOARD_TARGET_TALK:
            if (voice->hands_free) {
                if (voice->capturing) {
                    wearable_voice_client_talk_stop(s_voice);
                } else {
                    wearable_voice_client_talk_start(s_voice);
                }
            }
            break;
        case BOARD_TARGET_MASCOT:
            // The face is the big button: it stops a reply mid-sentence, or places a call.
            if (voice->speaking) {
                wearable_voice_client_stop_speaking(s_voice);
            } else if (voice->call == WEARABLE_CALL_IDLE) {
                wearable_voice_client_call_start(s_voice);
            }
            break;
        default:
            break;
    }
}

static bool push_to_talk_ready(const wearable_voice_snapshot_t *voice) {
    return s_voice != NULL && voice->call == WEARABLE_CALL_ACTIVE && !voice->hands_free;
}

static void run_assistant_shell(const neoagent_device_config_t *device_config, neoagent_session_state_t *session_state, const char *wearable_ws_url) {
    TickType_t last_chrome_refresh = 0;
    board_touch_event_t touch_event = {0};
    board_button_event_t button_event = {0};
    wearable_voice_snapshot_t voice = {0};
    shell_view_t view = {.tab = SHELL_TAB_CALL, .page = BOARD_SETTINGS_ROOT};
    shell_view_t shown = {0};
    bool shown_valid = false;
    call_moment_t moment = {0};
    mascot_stabilizer_t stabilizer;
    board_target_t pressed_target = BOARD_TARGET_NONE;
    bool touch_talking = false;
    bool boot_talking = false;
    bool charging = false;
    bool display_sleeping = false;
    bool standby_wake_armed = false;
    bool suppress_power_until_release = false;
    bool suppress_boot_until_release = false;
    TickType_t last_touch_action = 0;
    TickType_t last_activity = xTaskGetTickCount();
#if CONFIG_NEOAGENT_AUTO_OTA
    const TickType_t shell_started_at = last_activity;
    TickType_t last_auto_update_check = 0;
    bool completed_initial_auto_update_check = false;
#endif

    mascot_stabilizer_init(&stabilizer);
    if (wearable_ws_url != NULL && wearable_ws_url[0] != '\0') {
        esp_err_t voice_err = wearable_voice_client_init(
            &s_voice,
            &s_board,
            wearable_ws_url,
            session_state->session_cookie,
            device_config->device_label
        );
        if (voice_err != ESP_OK) {
            ESP_LOGW(TAG, "voice client init failed: %s", esp_err_to_name(voice_err));
            s_voice = NULL;
        }
    }
    ESP_ERROR_CHECK(screen_router_navigate(&s_router, NEOAGENT_SCREEN_ASSISTANT));
    update_power_chrome();
    const neoagent_status_chrome_t *initial_power_status = power_manager_get_status(&s_power_manager);
    charging = initial_power_status != NULL && initial_power_status->charging;

    while (true) {
        TickType_t now = xTaskGetTickCount();
        if (display_sleeping) {
            board_support_poll_buttons(&s_board, &button_event);
            board_support_poll_touch(&s_board, &touch_event);
            const bool any_input_down = !sleep_wake_buttons_released() || board_support_touch_is_active(&s_board);
            if (!standby_wake_armed) {
                standby_wake_armed = !any_input_down && !touch_event.released;
            } else if (button_event.power_pressed || button_event.boot_pressed || touch_event.pressed) {
                suppress_power_until_release = button_event.power_pressed;
                suppress_boot_until_release = button_event.boot_pressed;
                if (wake_display_from_standby(&display_sleeping)) {
                    update_power_chrome();
                    shown_valid = false;
                    last_chrome_refresh = 0;
                    last_activity = now;
                }
            }
            if (s_voice != NULL) {
                wearable_voice_client_poll(s_voice);
            }
            vTaskDelay(pdMS_TO_TICKS(30));
            continue;
        }

        if (s_voice != NULL) {
            wearable_voice_client_poll(s_voice);
        }
        read_voice(&voice);
        if (voice.authentication_rejected) {
            forget_session_and_restart();
        }
        track_moment(&moment, &voice);
        mascot_stabilizer_update(&stabilizer, call_mood(&voice, &moment), moment.id, esp_timer_get_time() / 1000);

        // A reply playing, a push-to-talk hold or a call being placed keeps the
        // display on; an open hands-free call may go dark like a phone at the ear.
        const bool voice_active = voice.speaking || voice.call == WEARABLE_CALL_CONNECTING || (voice.capturing && !voice.hands_free);
        if (voice_active) {
            last_activity = now;
        }
        if (now - last_activity >= pdMS_TO_TICKS(CONFIG_NEOAGENT_DISPLAY_TIMEOUT_SECONDS * 1000)) {
            if (enter_display_standby(&display_sleeping)) {
                standby_wake_armed = false;
                continue;
            }
            last_activity = now;
        }

        if (last_chrome_refresh == 0 || now - last_chrome_refresh >= pdMS_TO_TICKS(NEOAGENT_CHROME_REFRESH_INTERVAL_MS)) {
            update_power_chrome();
            const neoagent_status_chrome_t *power_status = power_manager_get_status(&s_power_manager);
            charging = power_status != NULL && power_status->charging;
            refresh_chrome(session_state);
            last_chrome_refresh = now;
        }

#if CONFIG_NEOAGENT_AUTO_OTA
        const TickType_t auto_update_delay = completed_initial_auto_update_check
            ? pdMS_TO_TICKS(CONFIG_NEOAGENT_AUTO_OTA_CHECK_INTERVAL_MINUTES * 60 * 1000)
            : pdMS_TO_TICKS(CONFIG_NEOAGENT_AUTO_OTA_INITIAL_DELAY_SECONDS * 1000);
        const TickType_t auto_update_elapsed = completed_initial_auto_update_check
            ? now - last_auto_update_check
            : now - shell_started_at;
        const neoagent_status_chrome_t *auto_update_power = power_manager_get_status(&s_power_manager);
        const bool auto_update_power_ready = auto_update_power == NULL
            || auto_update_power->charging
            || auto_update_power->battery_percent < 0
            || auto_update_power->battery_percent >= CONFIG_NEOAGENT_AUTO_OTA_MIN_BATTERY_PERCENT;
        if (auto_update_elapsed >= auto_update_delay
            && provisioning_manager_is_connected(&s_provisioning)
            && auto_update_power_ready
            && voice.call == WEARABLE_CALL_IDLE) {
            completed_initial_auto_update_check = true;
            last_auto_update_check = now;
            ESP_LOGI(TAG, "checking GitHub release channel=%s", update_manager_channel(&s_updates));
            start_firmware_update(device_config, session_state, false, &display_sleeping);
            shown_valid = false;
        }
#endif

        if (board_support_poll_touch(&s_board, &touch_event) == ESP_OK &&
            (touch_event.pressed || touch_event.released)) {
            last_activity = now;
            if (touch_event.pressed) {
                pressed_target = board_support_hit_test(&s_board, touch_event.x, touch_event.y);
                if (view.tab == SHELL_TAB_CALL && pressed_target == BOARD_TARGET_TALK && push_to_talk_ready(&voice)) {
                    wearable_voice_client_talk_start(s_voice);
                    touch_talking = true;
                }
            }
            if (touch_event.released) {
                const bool tap_allowed = touch_event.tapped && (last_touch_action == 0 ||
                    now - last_touch_action >= pdMS_TO_TICKS(NEOAGENT_TOUCH_ACTION_COOLDOWN_MS));
                if (touch_talking) {
                    // A hold ends however the finger leaves the glass.
                    touch_talking = false;
                    wearable_voice_client_talk_stop(s_voice);
                } else if (touch_event.swipe_left && view.tab == SHELL_TAB_CALL) {
                    view.tab = SHELL_TAB_SETTINGS;
                    view.page = BOARD_SETTINGS_ROOT;
                    shown_valid = false;
                } else if (touch_event.swipe_right && view.tab == SHELL_TAB_SETTINGS) {
                    handle_settings_target(BOARD_TARGET_BACK, &view, device_config, session_state, &display_sleeping);
                    shown_valid = false;
                } else if (tap_allowed && pressed_target != BOARD_TARGET_NONE) {
                    ESP_LOGI(TAG, "tap target=%d tab=%d", (int)pressed_target, (int)view.tab);
                    last_touch_action = now;
                    if (view.tab == SHELL_TAB_CALL) {
                        handle_call_tap(pressed_target, &voice, &view);
                    } else if (handle_settings_target(pressed_target, &view, device_config, session_state, &display_sleeping)) {
                        shown_valid = false;
                    }
                }
                pressed_target = BOARD_TARGET_NONE;
            }
        }

        if (board_support_poll_buttons(&s_board, &button_event) == ESP_OK) {
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
            if (button_event.power_long_press && !boot_talking) {
                ESP_LOGI(TAG, "power long press -> %s", charging ? "charging standby" : "deep sleep");
                if (charging) {
                    enter_display_standby(&display_sleeping);
                    standby_wake_armed = false;
                    continue;
                }
                enter_deep_sleep();
            } else if (button_event.power_short_press) {
                view.tab = view.tab == SHELL_TAB_CALL ? SHELL_TAB_SETTINGS : SHELL_TAB_CALL;
                view.page = BOARD_SETTINGS_ROOT;
                shown_valid = false;
            }

            // BOOT is the call button: press to call, hold to talk on a
            // push-to-talk call, press to mute a hands-free one, hold to hang up.
            if (s_voice != NULL) {
                if (button_event.boot_pressed && push_to_talk_ready(&voice)) {
                    wearable_voice_client_talk_start(s_voice);
                    boot_talking = true;
                } else if (button_event.boot_released && boot_talking) {
                    boot_talking = false;
                    wearable_voice_client_talk_stop(s_voice);
                } else if (button_event.boot_short_press && !boot_talking) {
                    view.tab = SHELL_TAB_CALL;
                    if (voice.call == WEARABLE_CALL_IDLE) {
                        wearable_voice_client_call_start(s_voice);
                    } else if (voice.speaking) {
                        wearable_voice_client_stop_speaking(s_voice);
                    } else if (voice.hands_free && voice.capturing) {
                        wearable_voice_client_talk_stop(s_voice);
                    } else if (voice.hands_free) {
                        wearable_voice_client_talk_start(s_voice);
                    }
                } else if (button_event.boot_long_press && !boot_talking && voice.call != WEARABLE_CALL_IDLE) {
                    wearable_voice_client_call_end(s_voice);
                }
            }
            const bool button_activity = button_event.power_pressed || button_event.power_released || button_event.boot_pressed || button_event.boot_released;
            if (button_activity) {
                last_activity = now;
            }
        }

        read_voice(&voice);
        if (view.tab == SHELL_TAB_CALL) {
            build_call_view(&view, &voice, stabilizer.shown);
        }
        const bool changed = !shown_valid
            || view.tab != shown.tab
            || view.page != shown.page
            || (view.tab == SHELL_TAB_CALL && call_view_changed(&shown, &view));
        if (changed) {
            render_shell(&view, device_config, session_state);
            shown = view;
            shown.call.status = shown.status;
            shown.call.caption = shown.caption;
            shown.call.task = view.call.task != NULL ? shown.task : NULL;
            shown_valid = true;
        }
        vTaskDelay(pdMS_TO_TICKS(40));
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
    ESP_ERROR_CHECK(power_manager_init(&s_power_manager));
    ESP_ERROR_CHECK(screen_router_init(&s_router, NEOAGENT_SCREEN_PROVISIONING));
    ESP_ERROR_CHECK(app_shell_init(&s_shell, NEOAGENT_SCREEN_PROVISIONING));
    ESP_ERROR_CHECK(board_support_init(&s_board));
    ESP_ERROR_CHECK(ui_renderer_init(&s_ui, &s_board));
    confirm_healthy_ota_boot();
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
        ESP_ERROR_CHECK(board_support_show_message(&s_board, MASCOT_MOOD_THINKING, "Connecting Wi-Fi", device_config.wifi_ssid, "Waiting for network before QR pairing."));
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

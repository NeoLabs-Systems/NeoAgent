#include "telemetry.h"

#include "esp_log.h"

static const char *TAG = "WearableTelemetry";

void telemetry_log_boot(const char *stage) {
    ESP_LOGI(TAG, "boot_stage=%s", stage ? stage : "unknown");
}

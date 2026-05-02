#include "board_support.h"

#include <assert.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "driver/gpio.h"
#include "driver/i2c_master.h"
#include "driver/i2s_std.h"
#include "driver/spi_master.h"
#include "esp_check.h"
#include "esp_codec_dev.h"
#include "esp_codec_dev_defaults.h"
#include "esp_err.h"
#include "esp_io_expander_tca9554.h"
#include "esp_lcd_io_i2c.h"
#include "esp_lcd_panel_io.h"
#include "esp_lcd_panel_ops.h"
#include "esp_lcd_panel_vendor.h"
#include "esp_lcd_touch.h"
#include "esp_lcd_touch_ft5x06.h"
#include "esp_lcd_sh8601.h"
#include "esp_log.h"
#include "esp_timer.h"
#include "freertos/FreeRTOS.h"
#include "freertos/semphr.h"
#include "freertos/task.h"
#include "lvgl.h"
#include "extra/libs/qrcode/lv_qrcode.h"
#include "extra/widgets/spinner/lv_spinner.h"

static const char *TAG = "BoardSupport";

#define BOARD_LCD_HOST SPI2_HOST
#define BOARD_TOUCH_HOST I2C_NUM_0

#define BOARD_LCD_CS GPIO_NUM_12
#define BOARD_LCD_PCLK GPIO_NUM_11
#define BOARD_LCD_DATA0 GPIO_NUM_4
#define BOARD_LCD_DATA1 GPIO_NUM_5
#define BOARD_LCD_DATA2 GPIO_NUM_6
#define BOARD_LCD_DATA3 GPIO_NUM_7

#define BOARD_TOUCH_SCL GPIO_NUM_14
#define BOARD_TOUCH_SDA GPIO_NUM_15
#define BOARD_TOUCH_INT GPIO_NUM_21
#define BOARD_BOOT_BUTTON GPIO_NUM_0
#define BOARD_POWER_BUTTON GPIO_NUM_17
#define BOARD_I2S_BCLK GPIO_NUM_9
#define BOARD_I2S_MCLK GPIO_NUM_16
#define BOARD_I2S_WS GPIO_NUM_45
#define BOARD_I2S_DOUT GPIO_NUM_8
#define BOARD_I2S_DIN GPIO_NUM_10
#define BOARD_AUDIO_POWER_AMP GPIO_NUM_46

#define BOARD_LCD_H_RES 368
#define BOARD_LCD_V_RES 448
#define BOARD_LCD_BIT_PER_PIXEL 16
#define BOARD_LVGL_BUF_HEIGHT (BOARD_LCD_V_RES / 10)
#define BOARD_LVGL_TICK_PERIOD_MS 2
#define BOARD_LVGL_TASK_STACK_SIZE (4 * 1024)
#define BOARD_BUTTON_LONG_PRESS_US 700000
#define BOARD_AUDIO_SAMPLE_RATE 24000
#define BOARD_AUDIO_BITS_PER_SAMPLE I2S_DATA_BIT_WIDTH_16BIT
#define BOARD_AUDIO_CHANNELS 1
#define BOARD_AUDIO_VOLUME_PERCENT 68
#define BOARD_AUDIO_INPUT_GAIN_DB 30.0f
#define BOARD_AXP2101_ADDRESS 0x34
#define BOARD_AXP2101_STATUS1 0x00
#define BOARD_AXP2101_STATUS2 0x01
#define BOARD_AXP2101_ADC_CHANNEL_CTRL 0x30
#define BOARD_AXP2101_BAT_DET_CTRL 0x68
#define BOARD_AXP2101_BAT_PERCENT_DATA 0xA4

typedef struct {
    char chunk_id[96];
    uint32_t sample_rate;
    uint16_t bits_per_sample;
    uint16_t channels;
    const uint8_t *payload;
    size_t payload_length;
} board_wav_view_t;

typedef struct {
    bool initialized;
    bool qr_screen_active;
    SemaphoreHandle_t lvgl_mutex;
    lv_obj_t *screen;
    lv_obj_t *title_label;
    lv_obj_t *line1_label;
    lv_obj_t *line2_label;
    lv_obj_t *qr_code;
    esp_lcd_panel_handle_t panel_handle;
    lv_disp_drv_t disp_drv;
    lv_disp_draw_buf_t disp_buf;
    lv_color_t *buf1;
    lv_color_t *buf2;
    i2c_master_bus_handle_t i2c_bus;
    esp_lcd_panel_io_handle_t touch_io;
    esp_lcd_touch_handle_t touch_handle;
    i2s_chan_handle_t i2s_tx_chan;
    i2s_chan_handle_t i2s_rx_chan;
    esp_codec_dev_handle_t codec_handle;
    board_audio_format_t audio_format;
    bool touch_down;
    uint16_t touch_start_x;
    uint16_t touch_start_y;
    uint16_t last_touch_x;
    uint16_t last_touch_y;
    neoagent_status_chrome_t chrome;
    char chrome_time[8];
    bool boot_button_down;
    bool power_button_down;
    bool boot_button_long_fired;
    bool power_button_long_fired;
    int64_t boot_button_press_started_us;
    int64_t power_button_press_started_us;
    i2c_master_dev_handle_t pmu_device_handle;  // Cached PMU device handle to reduce I2C bus contention
    uint8_t pmu_read_error_count;  // Error counter for diagnostic purposes
} board_runtime_t;

static board_runtime_t s_runtime = {0};

static const sh8601_lcd_init_cmd_t s_lcd_init_cmds[] = {
    {0x11, (uint8_t[]){0x00}, 0, 120},
    {0x44, (uint8_t[]){0x01, 0xD1}, 2, 0},
    {0x35, (uint8_t[]){0x00}, 1, 0},
    {0x53, (uint8_t[]){0x20}, 1, 10},
    {0x2A, (uint8_t[]){0x00, 0x00, 0x01, 0x6F}, 4, 0},
    {0x2B, (uint8_t[]){0x00, 0x00, 0x01, 0xBF}, 4, 0},
    {0x51, (uint8_t[]){0x00}, 1, 10},
    {0x29, (uint8_t[]){0x00}, 0, 10},
    {0x51, (uint8_t[]){0xFF}, 1, 0},
};

static bool board_lock(int timeout_ms) {
    if (s_runtime.lvgl_mutex == NULL) {
        return false;
    }
    const TickType_t timeout_ticks = timeout_ms < 0 ? portMAX_DELAY : pdMS_TO_TICKS(timeout_ms);
    return xSemaphoreTake(s_runtime.lvgl_mutex, timeout_ticks) == pdTRUE;
}

static void board_unlock(void) {
    if (s_runtime.lvgl_mutex != NULL) {
        xSemaphoreGive(s_runtime.lvgl_mutex);
    }
}

static bool board_notify_flush_ready(esp_lcd_panel_io_handle_t panel_io, esp_lcd_panel_io_event_data_t *edata, void *user_ctx) {
    lv_disp_drv_t *disp_driver = (lv_disp_drv_t *)user_ctx;
    lv_disp_flush_ready(disp_driver);
    return false;
}

static void board_lvgl_flush_cb(lv_disp_drv_t *drv, const lv_area_t *area, lv_color_t *color_map) {
    esp_lcd_panel_handle_t panel_handle = (esp_lcd_panel_handle_t)drv->user_data;
    esp_lcd_panel_draw_bitmap(panel_handle, area->x1, area->y1, area->x2 + 1, area->y2 + 1, color_map);
}

static void board_lvgl_rounder_cb(lv_disp_drv_t *disp_drv, lv_area_t *area) {
    (void)disp_drv;
    area->x1 = (area->x1 >> 1) << 1;
    area->y1 = (area->y1 >> 1) << 1;
    area->x2 = ((area->x2 >> 1) << 1) + 1;
    area->y2 = ((area->y2 >> 1) << 1) + 1;
}

static void board_lvgl_update_cb(lv_disp_drv_t *drv) {
    esp_lcd_panel_handle_t panel_handle = (esp_lcd_panel_handle_t)drv->user_data;
    switch (drv->rotated) {
        case LV_DISP_ROT_NONE:
            esp_lcd_panel_swap_xy(panel_handle, false);
            esp_lcd_panel_mirror(panel_handle, true, false);
            break;
        case LV_DISP_ROT_90:
            esp_lcd_panel_swap_xy(panel_handle, true);
            esp_lcd_panel_mirror(panel_handle, true, true);
            break;
        case LV_DISP_ROT_180:
            esp_lcd_panel_swap_xy(panel_handle, false);
            esp_lcd_panel_mirror(panel_handle, false, true);
            break;
        case LV_DISP_ROT_270:
            esp_lcd_panel_swap_xy(panel_handle, true);
            esp_lcd_panel_mirror(panel_handle, false, false);
            break;
    }
}

static void board_increase_lvgl_tick(void *arg) {
    (void)arg;
    lv_tick_inc(BOARD_LVGL_TICK_PERIOD_MS);
}

static void board_lvgl_task(void *arg) {
    (void)arg;
    while (true) {
        if (board_lock(-1)) {
            uint32_t delay_ms = lv_timer_handler();
            board_unlock();
            if (delay_ms < 1) {
                delay_ms = 1;
            } else if (delay_ms > 500) {
                delay_ms = 500;
            }
            vTaskDelay(pdMS_TO_TICKS(delay_ms));
        } else {
            vTaskDelay(pdMS_TO_TICKS(10));
        }
    }
}

static void board_load_screen(lv_obj_t *screen, lv_scr_load_anim_t animation) {
    (void)animation;
    lv_obj_t *previous_screen = s_runtime.screen;
    s_runtime.screen = screen;
    lv_scr_load(screen);
    if (previous_screen != NULL && previous_screen != screen) {
        lv_obj_del(previous_screen);
    }
}

static void board_set_translate_y(void *object, int32_t value) {
    lv_obj_set_style_translate_y((lv_obj_t *)object, (lv_coord_t)value, 0);
}

static void board_format_battery_text(char *text, size_t text_size) {
    if (text == NULL || text_size == 0) {
        return;
    }
    if (s_runtime.chrome.battery_percent < 0) {
        snprintf(text, text_size, "--%%");
        return;
    }
    snprintf(text, text_size, "%d%%", s_runtime.chrome.battery_percent);
}

static lv_obj_t *board_create_header(lv_obj_t *screen, const char *title) {
    char battery_text[12];

    lv_obj_t *header = lv_obj_create(screen);
    lv_obj_set_size(header, 368, 54);
    lv_obj_align(header, LV_ALIGN_TOP_MID, 0, 0);
    lv_obj_set_style_radius(header, 0, 0);
    lv_obj_set_style_bg_color(header, lv_color_hex(0x0b1219), 0);
    lv_obj_set_style_border_width(header, 0, 0);
    lv_obj_set_style_pad_all(header, 0, 0);
    lv_obj_clear_flag(header, LV_OBJ_FLAG_SCROLLABLE);

    lv_obj_t *divider = lv_obj_create(header);
    lv_obj_set_size(divider, 336, 1);
    lv_obj_align(divider, LV_ALIGN_BOTTOM_MID, 0, 0);
    lv_obj_set_style_radius(divider, 0, 0);
    lv_obj_set_style_bg_color(divider, lv_color_hex(0x1e2b38), 0);
    lv_obj_set_style_border_width(divider, 0, 0);
    lv_obj_clear_flag(divider, LV_OBJ_FLAG_SCROLLABLE);

    lv_obj_t *time_label = lv_label_create(header);
    lv_obj_set_style_text_font(time_label, &lv_font_montserrat_14, 0);
    lv_obj_set_style_text_color(time_label, lv_color_hex(0x9fb3c8), 0);
    lv_label_set_text(time_label, s_runtime.chrome_time[0] != '\0' ? s_runtime.chrome_time : "--:--");
    lv_obj_align(time_label, LV_ALIGN_LEFT_MID, 18, -1);

    lv_obj_t *title_label = lv_label_create(header);
    lv_obj_set_style_text_font(title_label, &lv_font_montserrat_14, 0);
    lv_obj_set_style_text_color(title_label, lv_color_hex(0xe6b667), 0);
    lv_label_set_text(title_label, title != NULL ? title : "NeoAgent");
    lv_obj_center(title_label);

    lv_obj_t *battery_pill = lv_obj_create(header);
    lv_obj_set_size(battery_pill, 66, 28);
    lv_obj_align(battery_pill, LV_ALIGN_RIGHT_MID, -16, -1);
    lv_obj_set_style_radius(battery_pill, 14, 0);
    lv_obj_set_style_bg_color(battery_pill, lv_color_hex(0x131d27), 0);
    lv_obj_set_style_border_width(battery_pill, 1, 0);
    lv_obj_set_style_border_color(
        battery_pill,
        s_runtime.chrome.charging ? lv_color_hex(0x77cfb8) : lv_color_hex(0x314355),
        0
    );
    lv_obj_set_style_pad_all(battery_pill, 0, 0);
    lv_obj_clear_flag(battery_pill, LV_OBJ_FLAG_SCROLLABLE);

    lv_obj_t *battery_symbol = lv_label_create(battery_pill);
    lv_obj_set_style_text_font(battery_symbol, &lv_font_montserrat_12, 0);
    lv_obj_set_style_text_color(
        battery_symbol,
        s_runtime.chrome.charging ? lv_color_hex(0x77cfb8) : lv_color_hex(0xe6edf5),
        0
    );
    lv_label_set_text(battery_symbol, s_runtime.chrome.charging ? LV_SYMBOL_CHARGE : LV_SYMBOL_BATTERY_FULL);
    lv_obj_align(battery_symbol, LV_ALIGN_LEFT_MID, 8, 0);

    board_format_battery_text(battery_text, sizeof(battery_text));
    lv_obj_t *battery_label = lv_label_create(battery_pill);
    lv_obj_set_style_text_font(battery_label, &lv_font_montserrat_12, 0);
    lv_obj_set_style_text_color(battery_label, lv_color_hex(0xe6edf5), 0);
    lv_label_set_text(battery_label, battery_text);
    lv_obj_align(battery_label, LV_ALIGN_RIGHT_MID, -8, 0);

    return header;
}

static void board_style_base_screen(lv_obj_t *screen) {
    lv_obj_set_style_bg_color(screen, lv_color_hex(0x081018), 0);
    lv_obj_set_style_bg_grad_color(screen, lv_color_hex(0x081018), 0);
    lv_obj_set_style_bg_grad_dir(screen, LV_GRAD_DIR_NONE, 0);
    lv_obj_set_style_border_width(screen, 0, 0);
    lv_obj_set_style_pad_all(screen, 0, 0);
}

static lv_obj_t *board_create_surface(lv_obj_t *screen) {
    lv_obj_t *surface = lv_obj_create(screen);
    lv_obj_set_size(surface, 332, 330);
    lv_obj_align(surface, LV_ALIGN_TOP_MID, 0, 62);
    lv_obj_set_style_radius(surface, 28, 0);
    lv_obj_set_style_bg_color(surface, lv_color_hex(0x171919), 0);
    lv_obj_set_style_bg_grad_color(surface, lv_color_hex(0x171919), 0);
    lv_obj_set_style_bg_grad_dir(surface, LV_GRAD_DIR_NONE, 0);
    lv_obj_set_style_border_width(surface, 1, 0);
    lv_obj_set_style_border_color(surface, lv_color_hex(0x2a2b28), 0);
    lv_obj_set_style_shadow_width(surface, 30, 0);
    lv_obj_set_style_shadow_opa(surface, LV_OPA_20, 0);
    lv_obj_set_style_shadow_color(surface, lv_color_hex(0x000000), 0);
    lv_obj_set_style_pad_all(surface, 18, 0);
    lv_obj_clear_flag(surface, LV_OBJ_FLAG_SCROLLABLE);
    return surface;
}

static lv_obj_t *board_create_nav_bar(lv_obj_t *screen, size_t active_index) {
    static const char *icons[] = {LV_SYMBOL_AUDIO, LV_SYMBOL_IMAGE, LV_SYMBOL_PLAY, LV_SYMBOL_SETTINGS};
    static const char *labels[] = {"Talk", "Widgets", "Record", "Settings"};
    lv_obj_t *nav = lv_obj_create(screen);
    lv_obj_set_size(nav, 368, 68);
    lv_obj_align(nav, LV_ALIGN_BOTTOM_MID, 0, 0);
    lv_obj_set_style_radius(nav, 0, 0);
    lv_obj_set_style_bg_color(nav, lv_color_hex(0x0a121a), 0);
    lv_obj_set_style_border_width(nav, 0, 0);
    lv_obj_set_style_pad_all(nav, 0, 0);
    lv_obj_clear_flag(nav, LV_OBJ_FLAG_SCROLLABLE);

    for (size_t i = 0; i < 4; ++i) {
        lv_obj_t *segment = lv_obj_create(nav);
        lv_obj_set_size(segment, 92, 68);
        lv_obj_align(segment, LV_ALIGN_LEFT_MID, (int32_t)(i * 92), 0);
        lv_obj_set_style_radius(segment, 0, 0);
        lv_obj_set_style_bg_opa(segment, LV_OPA_TRANSP, 0);
        lv_obj_set_style_border_width(segment, 0, 0);
        lv_obj_set_style_pad_all(segment, 0, 0);
        lv_obj_clear_flag(segment, LV_OBJ_FLAG_SCROLLABLE);

        if (i == active_index) {
            lv_obj_t *indicator = lv_obj_create(segment);
            lv_obj_set_size(indicator, 74, 3);
            lv_obj_align(indicator, LV_ALIGN_TOP_MID, 0, 0);
            lv_obj_set_style_radius(indicator, 3, 0);
            lv_obj_set_style_bg_color(indicator, lv_color_hex(0xe2b76d), 0);
            lv_obj_set_style_border_width(indicator, 0, 0);
            lv_obj_clear_flag(indicator, LV_OBJ_FLAG_SCROLLABLE);
        }

        lv_obj_t *icon = lv_label_create(segment);
        lv_obj_set_style_text_font(icon, &lv_font_montserrat_16, 0);
        lv_obj_set_style_text_color(icon, i == active_index ? lv_color_hex(0xe6edf5) : lv_color_hex(0x6f879f), 0);
        lv_label_set_text(icon, icons[i]);
        lv_obj_align(icon, LV_ALIGN_TOP_MID, 0, 13);

        lv_obj_t *label = lv_label_create(segment);
        lv_obj_set_style_text_font(label, &lv_font_montserrat_12, 0);
        lv_obj_set_style_text_color(label, i == active_index ? lv_color_hex(0xe2b76d) : lv_color_hex(0x73879a), 0);
        lv_label_set_text(label, labels[i]);
        lv_obj_align(label, LV_ALIGN_BOTTOM_MID, 0, -11);
    }
    return nav;
}

static lv_obj_t *board_create_stat_tile(
    lv_obj_t *parent,
    lv_coord_t width,
    lv_coord_t height,
    lv_align_t align,
    lv_coord_t x_ofs,
    lv_coord_t y_ofs,
    const char *label,
    const char *value,
    bool highlighted
) {
    lv_obj_t *tile = lv_obj_create(parent);
    lv_obj_set_size(tile, width, height);
    lv_obj_align(tile, align, x_ofs, y_ofs);
    lv_obj_set_style_radius(tile, 16, 0);
    lv_obj_set_style_bg_color(tile, lv_color_hex(0x1e1f1d), 0);
    lv_obj_set_style_border_width(tile, highlighted ? 1 : 0, 0);
    lv_obj_set_style_border_color(tile, lv_color_hex(0x9d6b08), 0);
    lv_obj_set_style_pad_all(tile, 10, 0);
    lv_obj_clear_flag(tile, LV_OBJ_FLAG_SCROLLABLE);

    lv_obj_t *label_obj = lv_label_create(tile);
    lv_obj_set_style_text_font(label_obj, &lv_font_montserrat_12, 0);
    lv_obj_set_style_text_color(label_obj, lv_color_hex(0xb6aa92), 0);
    lv_label_set_text(label_obj, label != NULL ? label : "");
    lv_obj_align(label_obj, LV_ALIGN_TOP_LEFT, 0, 0);

    lv_obj_t *value_obj = lv_label_create(tile);
    lv_obj_set_width(value_obj, width - 20);
    lv_label_set_long_mode(value_obj, LV_LABEL_LONG_WRAP);
    lv_obj_set_style_text_font(value_obj, highlighted ? &lv_font_montserrat_16 : &lv_font_montserrat_14, 0);
    lv_obj_set_style_text_color(value_obj, highlighted ? lv_color_hex(0xf4b517) : lv_color_hex(0xe8e1d2), 0);
    lv_label_set_text(value_obj, value != NULL ? value : "");
    lv_obj_align(value_obj, LV_ALIGN_BOTTOM_LEFT, 0, 0);

    return tile;
}

static lv_obj_t *board_create_list_row(lv_obj_t *parent, lv_coord_t y_ofs, const char *icon, const char *label, bool active) {
    lv_obj_t *row = lv_obj_create(parent);
    lv_obj_set_size(row, 296, 52);
    lv_obj_align(row, LV_ALIGN_TOP_MID, 0, y_ofs);
    lv_obj_set_style_radius(row, 12, 0);
    lv_obj_set_style_bg_color(row, lv_color_hex(0x141615), 0);
    lv_obj_set_style_border_width(row, active ? 1 : 0, 0);
    lv_obj_set_style_border_color(row, lv_color_hex(0x8f6209), 0);
    lv_obj_set_style_pad_all(row, 0, 0);
    lv_obj_clear_flag(row, LV_OBJ_FLAG_SCROLLABLE);

    lv_obj_t *icon_label = lv_label_create(row);
    lv_obj_set_style_text_font(icon_label, &lv_font_montserrat_16, 0);
    lv_obj_set_style_text_color(icon_label, lv_color_hex(0xf1a60c), 0);
    lv_label_set_text(icon_label, icon != NULL ? icon : "");
    lv_obj_align(icon_label, LV_ALIGN_LEFT_MID, 14, 0);

    lv_obj_t *text_label = lv_label_create(row);
    lv_obj_set_style_text_font(text_label, &lv_font_montserrat_16, 0);
    lv_obj_set_style_text_color(text_label, lv_color_hex(0xe4ddd0), 0);
    lv_label_set_text(text_label, label != NULL ? label : "");
    lv_obj_align(text_label, LV_ALIGN_LEFT_MID, 40, 0);

    return row;
}

static void board_animate_entry(lv_obj_t *object) {
    lv_anim_t animation;
    lv_anim_init(&animation);
    lv_anim_set_var(&animation, object);
    lv_anim_set_values(&animation, 10, 0);
    lv_anim_set_time(&animation, 90);
    lv_anim_set_exec_cb(&animation, board_set_translate_y);
    lv_anim_start(&animation);
}

static esp_err_t board_audio_open_codec(uint32_t sample_rate_hz, uint8_t channels, uint8_t bits_per_sample) {
    if (s_runtime.codec_handle == NULL) {
        return ESP_ERR_INVALID_STATE;
    }
    if (s_runtime.audio_format.sample_rate_hz == sample_rate_hz &&
        s_runtime.audio_format.channels == channels &&
        s_runtime.audio_format.bits_per_sample == bits_per_sample) {
        return ESP_OK;
    }

    esp_codec_dev_close(s_runtime.codec_handle);
    esp_codec_dev_sample_info_t sample_cfg = {
        .sample_rate = sample_rate_hz,
        .channel = channels,
        .channel_mask = channels >= 2 ? 0x03 : 0x01,
        .bits_per_sample = (i2s_data_bit_width_t)bits_per_sample,
    };
    if (esp_codec_dev_open(s_runtime.codec_handle, &sample_cfg) != ESP_CODEC_DEV_OK) {
        return ESP_FAIL;
    }
    s_runtime.audio_format.sample_rate_hz = sample_rate_hz;
    s_runtime.audio_format.channels = channels;
    s_runtime.audio_format.bits_per_sample = bits_per_sample;
    return ESP_OK;
}

// Initialize cached PMU device handle on I2C bus
static esp_err_t board_pmu_device_init(void) {
    if (s_runtime.i2c_bus == NULL) {
        return ESP_ERR_INVALID_STATE;
    }
    
    if (s_runtime.pmu_device_handle != NULL) {
        return ESP_OK;  // Already initialized
    }
    
    i2c_device_config_t device_config = {
        .dev_addr_length = I2C_ADDR_BIT_LEN_7,
        .device_address = BOARD_AXP2101_ADDRESS,
        .scl_speed_hz = 400000,
    };
    
    esp_err_t err = i2c_master_bus_add_device(s_runtime.i2c_bus, &device_config, &s_runtime.pmu_device_handle);
    if (err != ESP_OK) {
        ESP_LOGW(TAG, "pmu device init failed: %s", esp_err_to_name(err));
        s_runtime.pmu_device_handle = NULL;
    }
    return err;
}

// Read PMU register with I2C error recovery for noise tolerance during charging
static esp_err_t board_pmu_read_register(uint8_t reg, uint8_t *buffer, size_t length) {
    if (buffer == NULL || length == 0 || s_runtime.i2c_bus == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    
    // Ensure PMU device is initialized
    if (s_runtime.pmu_device_handle == NULL) {
        ESP_RETURN_ON_ERROR(board_pmu_device_init(), TAG, "pmu device init failed");
    }
    
    // Retry with exponential backoff for I2C errors during charging
    const int max_retries = 3;
    const int base_delay_ms = 2;
    
    for (int attempt = 0; attempt < max_retries; attempt++) {
        esp_err_t read_err = i2c_master_transmit_receive(
            s_runtime.pmu_device_handle, 
            &reg, 
            1, 
            buffer, 
            length, 
            1000  // 1 second timeout per attempt
        );
        
        if (read_err == ESP_OK) {
            // Clear error counter on success
            s_runtime.pmu_read_error_count = 0;
            return ESP_OK;
        }
        
        if (attempt < max_retries - 1) {
            // Exponential backoff: 2ms, 4ms, 8ms...
            int delay_ms = base_delay_ms << attempt;
            vTaskDelay(pdMS_TO_TICKS(delay_ms));
        } else {
            // Final attempt failed
            s_runtime.pmu_read_error_count++;
            if (s_runtime.pmu_read_error_count % 10 == 0) {
                ESP_LOGW(TAG, "pmu read failed after %d retries (error count: %u): %s", 
                    max_retries, s_runtime.pmu_read_error_count, esp_err_to_name(read_err));
            }
            return read_err;
        }
    }
    
    return ESP_FAIL;
}

// Write PMU register with I2C error recovery
static esp_err_t board_pmu_write_register(uint8_t reg, uint8_t value) {
    if (s_runtime.i2c_bus == NULL) {
        return ESP_ERR_INVALID_STATE;
    }
    
    // Ensure PMU device is initialized
    if (s_runtime.pmu_device_handle == NULL) {
        ESP_RETURN_ON_ERROR(board_pmu_device_init(), TAG, "pmu device init failed");
    }
    
    // Retry with exponential backoff
    const int max_retries = 3;
    const int base_delay_ms = 2;
    
    for (int attempt = 0; attempt < max_retries; attempt++) {
        uint8_t payload[2] = {reg, value};
        esp_err_t write_err = i2c_master_transmit(
            s_runtime.pmu_device_handle, 
            payload, 
            sizeof(payload), 
            1000  // 1 second timeout per attempt
        );
        
        if (write_err == ESP_OK) {
            return ESP_OK;
        }
        
        if (attempt < max_retries - 1) {
            // Exponential backoff
            int delay_ms = base_delay_ms << attempt;
            vTaskDelay(pdMS_TO_TICKS(delay_ms));
        } else {
            ESP_LOGW(TAG, "pmu write 0x%02x=0x%02x failed after %d retries: %s", 
                reg, value, max_retries, esp_err_to_name(write_err));
            return write_err;
        }
    }
    
    return ESP_FAIL;
}

static esp_err_t board_pmu_enable_battery_measurements(void) {
    uint8_t adc_ctrl = 0;
    uint8_t det_ctrl = 0;
    ESP_RETURN_ON_ERROR(board_pmu_read_register(BOARD_AXP2101_ADC_CHANNEL_CTRL, &adc_ctrl, 1), TAG, "pmu adc ctrl read failed");
    ESP_RETURN_ON_ERROR(board_pmu_read_register(BOARD_AXP2101_BAT_DET_CTRL, &det_ctrl, 1), TAG, "pmu battery det read failed");
    adc_ctrl |= 0x01;
    det_ctrl |= 0x01;
    ESP_RETURN_ON_ERROR(board_pmu_write_register(BOARD_AXP2101_ADC_CHANNEL_CTRL, adc_ctrl), TAG, "pmu adc ctrl write failed");
    ESP_RETURN_ON_ERROR(board_pmu_write_register(BOARD_AXP2101_BAT_DET_CTRL, det_ctrl), TAG, "pmu battery det write failed");
    return ESP_OK;
}

static esp_err_t board_audio_init_codec(void) {
    if (s_runtime.codec_handle != NULL) {
        return ESP_OK;
    }

    esp_err_t err = ESP_OK;
    bool tx_enabled = false;
    bool rx_enabled = false;
    i2s_chan_handle_t tx_chan = NULL;
    i2s_chan_handle_t rx_chan = NULL;
    const audio_codec_data_if_t *data_if = NULL;
    const audio_codec_gpio_if_t *gpio_if = NULL;
    const audio_codec_ctrl_if_t *ctrl_if = NULL;
    const audio_codec_if_t *codec_if = NULL;
    esp_codec_dev_handle_t codec_handle = NULL;

    i2s_chan_config_t chan_cfg = I2S_CHANNEL_DEFAULT_CONFIG(0, I2S_ROLE_MASTER);
    chan_cfg.auto_clear = true;
    err = i2s_new_channel(&chan_cfg, &tx_chan, &rx_chan);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "i2s_new_channel failed: %s", esp_err_to_name(err));
        return err;
    }

    const i2s_std_config_t std_cfg = {
        .clk_cfg = I2S_STD_CLK_DEFAULT_CONFIG(BOARD_AUDIO_SAMPLE_RATE),
        .slot_cfg = I2S_STD_PHILIPS_SLOT_DEFAULT_CONFIG(BOARD_AUDIO_BITS_PER_SAMPLE, I2S_SLOT_MODE_MONO),
        .gpio_cfg = {
            .mclk = BOARD_I2S_MCLK,
            .bclk = BOARD_I2S_BCLK,
            .ws = BOARD_I2S_WS,
            .dout = BOARD_I2S_DOUT,
            .din = BOARD_I2S_DIN,
            .invert_flags = {
                .mclk_inv = false,
                .bclk_inv = false,
                .ws_inv = false,
            },
        },
    };

    err = i2s_channel_init_std_mode(tx_chan, &std_cfg);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "i2s tx init failed: %s", esp_err_to_name(err));
        goto cleanup;
    }
    err = i2s_channel_init_std_mode(rx_chan, &std_cfg);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "i2s rx init failed: %s", esp_err_to_name(err));
        goto cleanup;
    }
    err = i2s_channel_enable(tx_chan);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "i2s tx enable failed: %s", esp_err_to_name(err));
        goto cleanup;
    }
    tx_enabled = true;
    err = i2s_channel_enable(rx_chan);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "i2s rx enable failed: %s", esp_err_to_name(err));
        goto cleanup;
    }
    rx_enabled = true;

    audio_codec_i2s_cfg_t i2s_cfg = {
        .port = 0,
        .tx_handle = tx_chan,
        .rx_handle = rx_chan,
    };
    data_if = audio_codec_new_i2s_data(&i2s_cfg);
    if (data_if == NULL) {
        err = ESP_FAIL;
        ESP_LOGE(TAG, "audio i2s data interface failed");
        goto cleanup;
    }

    gpio_if = audio_codec_new_gpio();
    if (gpio_if == NULL) {
        err = ESP_FAIL;
        ESP_LOGE(TAG, "audio gpio interface failed");
        goto cleanup;
    }

    audio_codec_i2c_cfg_t i2c_cfg = {
        .port = BOARD_TOUCH_HOST,
        .addr = ES8311_CODEC_DEFAULT_ADDR,
        .bus_handle = s_runtime.i2c_bus,
    };
    ctrl_if = audio_codec_new_i2c_ctrl(&i2c_cfg);
    if (ctrl_if == NULL) {
        err = ESP_FAIL;
        ESP_LOGE(TAG, "audio i2c ctrl interface failed");
        goto cleanup;
    }

    const esp_codec_dev_hw_gain_t gain = {
        .pa_voltage = 5.0f,
        .codec_dac_voltage = 3.3f,
    };
    es8311_codec_cfg_t es8311_cfg = {
        .ctrl_if = ctrl_if,
        .gpio_if = gpio_if,
        .codec_mode = ESP_CODEC_DEV_WORK_MODE_BOTH,
        .master_mode = false,
        .use_mclk = true,
        .digital_mic = false,
        .pa_pin = BOARD_AUDIO_POWER_AMP,
        .pa_reverted = false,
        .invert_mclk = false,
        .invert_sclk = false,
        .hw_gain = gain,
    };
    codec_if = es8311_codec_new(&es8311_cfg);
    if (codec_if == NULL) {
        err = ESP_FAIL;
        ESP_LOGE(TAG, "es8311 init failed");
        goto cleanup;
    }

    esp_codec_dev_cfg_t dev_cfg = {
        .dev_type = ESP_CODEC_DEV_TYPE_IN_OUT,
        .codec_if = codec_if,
        .data_if = data_if,
    };
    codec_handle = esp_codec_dev_new(&dev_cfg);
    if (codec_handle == NULL) {
        err = ESP_FAIL;
        ESP_LOGE(TAG, "codec handle init failed");
        goto cleanup;
    }

    s_runtime.i2s_tx_chan = tx_chan;
    s_runtime.i2s_rx_chan = rx_chan;
    s_runtime.codec_handle = codec_handle;
    err = board_audio_open_codec(BOARD_AUDIO_SAMPLE_RATE, BOARD_AUDIO_CHANNELS, 16);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "codec open failed: %s", esp_err_to_name(err));
        goto cleanup;
    }
    if (esp_codec_dev_set_out_vol(s_runtime.codec_handle, BOARD_AUDIO_VOLUME_PERCENT) != ESP_CODEC_DEV_OK) {
        err = ESP_FAIL;
        goto cleanup;
    }
    if (esp_codec_dev_set_in_gain(s_runtime.codec_handle, BOARD_AUDIO_INPUT_GAIN_DB) != ESP_CODEC_DEV_OK) {
        err = ESP_FAIL;
        goto cleanup;
    }
    return ESP_OK;

cleanup:
    if (codec_handle != NULL) {
        esp_codec_dev_delete(codec_handle);
    }
    s_runtime.codec_handle = NULL;
    s_runtime.audio_format.sample_rate_hz = 0;
    s_runtime.audio_format.channels = 0;
    s_runtime.audio_format.bits_per_sample = 0;
    if (codec_if != NULL) {
        audio_codec_delete_codec_if(codec_if);
    }
    if (ctrl_if != NULL) {
        audio_codec_delete_ctrl_if(ctrl_if);
    }
    if (gpio_if != NULL) {
        audio_codec_delete_gpio_if(gpio_if);
    }
    if (data_if != NULL) {
        audio_codec_delete_data_if(data_if);
    }
    if (rx_enabled && rx_chan != NULL) {
        i2s_channel_disable(rx_chan);
    }
    if (tx_enabled && tx_chan != NULL) {
        i2s_channel_disable(tx_chan);
    }
    if (rx_chan != NULL) {
        i2s_del_channel(rx_chan);
    }
    if (tx_chan != NULL) {
        i2s_del_channel(tx_chan);
    }
    s_runtime.i2s_tx_chan = NULL;
    s_runtime.i2s_rx_chan = NULL;
    return ESP_OK;
}

static esp_err_t board_parse_wav(const uint8_t *wav_bytes, size_t wav_length, board_wav_view_t *view) {
    if (wav_bytes == NULL || wav_length < 44 || view == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    if (memcmp(wav_bytes, "RIFF", 4) != 0 || memcmp(wav_bytes + 8, "WAVE", 4) != 0) {
        return ESP_ERR_INVALID_RESPONSE;
    }

    uint16_t audio_format = 0;
    uint16_t channels = 0;
    uint32_t sample_rate = 0;
    uint16_t bits_per_sample = 0;
    const uint8_t *payload = NULL;
    size_t payload_length = 0;
    size_t offset = 12;

    while (offset + 8 <= wav_length) {
        const uint8_t *chunk = wav_bytes + offset;
        uint32_t chunk_size = (uint32_t)chunk[4] | ((uint32_t)chunk[5] << 8) | ((uint32_t)chunk[6] << 16) | ((uint32_t)chunk[7] << 24);
        offset += 8;
        if (offset + chunk_size > wav_length) {
            return ESP_ERR_INVALID_SIZE;
        }
        if (memcmp(chunk, "fmt ", 4) == 0 && chunk_size >= 16) {
            audio_format = (uint16_t)wav_bytes[offset] | ((uint16_t)wav_bytes[offset + 1] << 8);
            channels = (uint16_t)wav_bytes[offset + 2] | ((uint16_t)wav_bytes[offset + 3] << 8);
            sample_rate = (uint32_t)wav_bytes[offset + 4] | ((uint32_t)wav_bytes[offset + 5] << 8) | ((uint32_t)wav_bytes[offset + 6] << 16) | ((uint32_t)wav_bytes[offset + 7] << 24);
            bits_per_sample = (uint16_t)wav_bytes[offset + 14] | ((uint16_t)wav_bytes[offset + 15] << 8);
        } else if (memcmp(chunk, "data", 4) == 0) {
            payload = wav_bytes + offset;
            payload_length = chunk_size;
        }
        offset += chunk_size + (chunk_size & 1U);
    }

    if (audio_format != 1 || payload == NULL || payload_length == 0 || sample_rate == 0 || channels == 0 || bits_per_sample == 0) {
        return ESP_ERR_INVALID_RESPONSE;
    }
    view->sample_rate = sample_rate;
    view->channels = channels;
    view->bits_per_sample = bits_per_sample;
    view->payload = payload;
    view->payload_length = payload_length;
    view->chunk_id[0] = '\0';
    return ESP_OK;
}

static void board_create_status_screen(void) {
    lv_obj_t *screen = lv_obj_create(NULL);
    board_style_base_screen(screen);
    board_create_header(screen, "SETUP");

    s_runtime.title_label = lv_label_create(screen);
    lv_obj_set_width(s_runtime.title_label, 296);
    lv_label_set_long_mode(s_runtime.title_label, LV_LABEL_LONG_WRAP);
    lv_obj_set_style_text_align(s_runtime.title_label, LV_TEXT_ALIGN_CENTER, 0);
    lv_obj_set_style_text_color(s_runtime.title_label, lv_color_hex(0xf0ede4), 0);
    lv_obj_set_style_text_font(s_runtime.title_label, &lv_font_montserrat_16, 0);
    lv_obj_align(s_runtime.title_label, LV_ALIGN_TOP_MID, 0, 136);

    s_runtime.line1_label = lv_label_create(screen);
    lv_obj_set_width(s_runtime.line1_label, 300);
    lv_label_set_long_mode(s_runtime.line1_label, LV_LABEL_LONG_WRAP);
    lv_obj_set_style_text_align(s_runtime.line1_label, LV_TEXT_ALIGN_CENTER, 0);
    lv_obj_set_style_text_color(s_runtime.line1_label, lv_color_hex(0xc5b9a6), 0);
    lv_obj_set_style_text_font(s_runtime.line1_label, &lv_font_montserrat_16, 0);
    lv_obj_align(s_runtime.line1_label, LV_ALIGN_TOP_MID, 0, 186);

    s_runtime.line2_label = lv_label_create(screen);
    lv_obj_set_width(s_runtime.line2_label, 300);
    lv_label_set_long_mode(s_runtime.line2_label, LV_LABEL_LONG_WRAP);
    lv_obj_set_style_text_align(s_runtime.line2_label, LV_TEXT_ALIGN_CENTER, 0);
    lv_obj_set_style_text_color(s_runtime.line2_label, lv_color_hex(0x817968), 0);
    lv_obj_set_style_text_font(s_runtime.line2_label, &lv_font_montserrat_12, 0);
    lv_obj_align(s_runtime.line2_label, LV_ALIGN_TOP_MID, 0, 278);

    s_runtime.screen = screen;
    s_runtime.qr_code = NULL;
    s_runtime.qr_screen_active = false;
    board_load_screen(screen, LV_SCR_LOAD_ANIM_FADE_ON);
}

static void board_create_boot_screen(void) {
    lv_obj_t *screen = lv_obj_create(NULL);
    board_style_base_screen(screen);

    lv_obj_t *ambient_glow = lv_obj_create(screen);
    lv_obj_set_size(ambient_glow, 340, 340);
    lv_obj_align(ambient_glow, LV_ALIGN_TOP_LEFT, -92, -78);
    lv_obj_set_style_radius(ambient_glow, LV_RADIUS_CIRCLE, 0);
    lv_obj_set_style_bg_color(ambient_glow, lv_color_hex(0xd2ab62), 0);
    lv_obj_set_style_bg_opa(ambient_glow, (lv_opa_t)22, 0);
    lv_obj_set_style_border_width(ambient_glow, 0, 0);
    lv_obj_set_style_shadow_width(ambient_glow, 88, 0);
    lv_obj_set_style_shadow_opa(ambient_glow, (lv_opa_t)22, 0);
    lv_obj_set_style_shadow_color(ambient_glow, lv_color_hex(0xd2ab62), 0);
    lv_obj_clear_flag(ambient_glow, LV_OBJ_FLAG_SCROLLABLE);

    lv_obj_t *secondary_glow = lv_obj_create(screen);
    lv_obj_set_size(secondary_glow, 220, 220);
    lv_obj_align(secondary_glow, LV_ALIGN_CENTER, 0, -14);
    lv_obj_set_style_radius(secondary_glow, LV_RADIUS_CIRCLE, 0);
    lv_obj_set_style_bg_color(secondary_glow, lv_color_hex(0x78b6a9), 0);
    lv_obj_set_style_bg_opa(secondary_glow, LV_OPA_10, 0);
    lv_obj_set_style_border_width(secondary_glow, 0, 0);
    lv_obj_set_style_shadow_width(secondary_glow, 42, 0);
    lv_obj_set_style_shadow_opa(secondary_glow, (lv_opa_t)18, 0);
    lv_obj_set_style_shadow_color(secondary_glow, lv_color_hex(0x78b6a9), 0);
    lv_obj_clear_flag(secondary_glow, LV_OBJ_FLAG_SCROLLABLE);

    lv_obj_t *badge = lv_obj_create(screen);
    lv_obj_set_size(badge, 46, 46);
    lv_obj_align(badge, LV_ALIGN_CENTER, 0, -46);
    lv_obj_set_style_radius(badge, 14, 0);
    lv_obj_set_style_bg_color(badge, lv_color_hex(0xd29e47), 0);
    lv_obj_set_style_border_width(badge, 1, 0);
    lv_obj_set_style_border_color(badge, lv_color_hex(0xb68f4f), 0);
    lv_obj_set_style_shadow_width(badge, 18, 0);
    lv_obj_set_style_shadow_opa(badge, (lv_opa_t)25, 0);
    lv_obj_set_style_shadow_color(badge, lv_color_hex(0x000000), 0);
    lv_obj_clear_flag(badge, LV_OBJ_FLAG_SCROLLABLE);

    lv_obj_t *title_label = lv_label_create(screen);
    lv_obj_set_style_text_font(title_label, &lv_font_montserrat_16, 0);
    lv_obj_set_style_text_color(title_label, lv_color_hex(0xf0e7db), 0);
    lv_label_set_text(title_label, "NeoOS");
    lv_obj_align(title_label, LV_ALIGN_CENTER, 0, 8);

    lv_obj_t *spinner = lv_spinner_create(screen, 1200, 70);
    lv_obj_set_size(spinner, 30, 30);
    lv_obj_align(spinner, LV_ALIGN_CENTER, 0, 56);
    lv_obj_set_style_arc_width(spinner, 4, LV_PART_MAIN);
    lv_obj_set_style_arc_color(spinner, lv_color_hex(0xd2ab62), LV_PART_MAIN);
    lv_obj_set_style_arc_width(spinner, 4, LV_PART_INDICATOR);
    lv_obj_set_style_arc_color(spinner, lv_color_hex(0xf1d39d), LV_PART_INDICATOR);
    lv_obj_set_style_arc_opa(spinner, LV_OPA_COVER, LV_PART_MAIN);
    lv_obj_set_style_arc_opa(spinner, LV_OPA_COVER, LV_PART_INDICATOR);

    lv_obj_t *subtitle_label = lv_label_create(screen);
    lv_obj_set_style_text_font(subtitle_label, &lv_font_montserrat_12, 0);
    lv_obj_set_style_text_color(subtitle_label, lv_color_hex(0xbfc6c0), 0);
    lv_label_set_text(subtitle_label, "Loading NeoOS");
    lv_obj_align(subtitle_label, LV_ALIGN_CENTER, 0, 92);

    s_runtime.screen = screen;
    s_runtime.title_label = NULL;
    s_runtime.line1_label = NULL;
    s_runtime.line2_label = NULL;
    s_runtime.qr_code = NULL;
    s_runtime.qr_screen_active = false;
    board_load_screen(screen, LV_SCR_LOAD_ANIM_FADE_ON);
}

static void board_create_qr_screen(const char *title, const char *subtitle, const char *qr_payload) {
    lv_obj_t *screen = lv_obj_create(NULL);
    board_style_base_screen(screen);
    board_create_header(screen, "PAIR");

    lv_obj_t *title_label = lv_label_create(screen);
    lv_obj_set_style_text_font(title_label, &lv_font_montserrat_12, 0);
    lv_obj_set_style_text_color(title_label, lv_color_hex(0xb89b5c), 0);
    lv_label_set_text(title_label, title != NULL ? title : "Scan To Pair");
    lv_obj_align(title_label, LV_ALIGN_TOP_MID, 0, 164);

    lv_obj_t *qr_frame = lv_obj_create(screen);
    lv_obj_set_size(qr_frame, 160, 160);
    lv_obj_set_style_radius(qr_frame, 16, 0);
    lv_obj_set_style_bg_color(qr_frame, lv_color_hex(0xffffff), 0);
    lv_obj_set_style_border_width(qr_frame, 2, 0);
    lv_obj_set_style_border_color(qr_frame, lv_color_hex(0xd59a12), 0);
    lv_obj_set_style_pad_all(qr_frame, 10, 0);
    lv_obj_align(qr_frame, LV_ALIGN_CENTER, 0, 8);

    lv_obj_t *qr_code = lv_qrcode_create(qr_frame, 136, lv_color_hex(0x111111), lv_color_hex(0xffffff));
    lv_obj_center(qr_code);
    if (qr_payload != NULL && qr_payload[0] != '\0') {
        lv_qrcode_update(qr_code, qr_payload, strlen(qr_payload));
    }

    lv_obj_t *subtitle_label = lv_label_create(screen);
    lv_obj_set_width(subtitle_label, 280);
    lv_label_set_long_mode(subtitle_label, LV_LABEL_LONG_WRAP);
    lv_obj_set_style_text_align(subtitle_label, LV_TEXT_ALIGN_CENTER, 0);
    lv_obj_set_style_text_color(subtitle_label, lv_color_hex(0xe5ddd0), 0);
    lv_obj_set_style_text_font(subtitle_label, &lv_font_montserrat_16, 0);
    lv_obj_align(subtitle_label, LV_ALIGN_CENTER, 0, 126);
    lv_label_set_text(subtitle_label, subtitle != NULL ? subtitle : "");

    lv_obj_t *footer_label = lv_label_create(screen);
    lv_obj_set_width(footer_label, 300);
    lv_label_set_long_mode(footer_label, LV_LABEL_LONG_WRAP);
    lv_obj_set_style_text_align(footer_label, LV_TEXT_ALIGN_CENTER, 0);
    lv_obj_set_style_text_color(footer_label, lv_color_hex(0x918878), 0);
    lv_obj_set_style_text_font(footer_label, &lv_font_montserrat_12, 0);
    lv_obj_align(footer_label, LV_ALIGN_CENTER, 0, 170);
    lv_label_set_text(footer_label, "Open NeoAgent on another device and scan this code.");

    s_runtime.screen = screen;
    s_runtime.title_label = title_label;
    s_runtime.line1_label = subtitle_label;
    s_runtime.line2_label = footer_label;
    s_runtime.qr_code = qr_code;
    s_runtime.qr_screen_active = true;
    board_load_screen(screen, LV_SCR_LOAD_ANIM_MOVE_LEFT);
}

static void board_create_assistant_screen(const char *status, const char *hint, bool mic_active, board_assistant_state_t state) {
    lv_obj_t *screen = lv_obj_create(NULL);
    board_style_base_screen(screen);
    board_create_header(screen, "ASSISTANT");

    lv_color_t orb_start = lv_color_hex(0xe0a908);
    lv_color_t shadow_color = lv_color_hex(0xf0b310);
    const char *caption = "";
    const bool show_output_card = hint != NULL && hint[0] != '\0';

    switch (state) {
        case BOARD_ASSISTANT_STATE_LISTENING:
            orb_start = lv_color_hex(0xf4a300);
            shadow_color = lv_color_hex(0xf2b22e);
            caption = "Release to send";
            break;
        case BOARD_ASSISTANT_STATE_TRANSCRIBING:
            orb_start = lv_color_hex(0xf0b34c);
            shadow_color = lv_color_hex(0xf0b34c);
            caption = "Transcribing";
            break;
        case BOARD_ASSISTANT_STATE_THINKING:
            orb_start = lv_color_hex(0x9c8c4e);
            shadow_color = lv_color_hex(0xc3a45c);
            caption = "Thinking";
            break;
        case BOARD_ASSISTANT_STATE_SPEAKING:
            orb_start = lv_color_hex(0xf0bc4d);
            shadow_color = lv_color_hex(0xf2c86f);
            caption = "Speaking";
            break;
        case BOARD_ASSISTANT_STATE_ERROR:
            orb_start = lv_color_hex(0xb86f58);
            shadow_color = lv_color_hex(0xcf8a72);
            caption = "Tap and hold to retry";
            break;
        case BOARD_ASSISTANT_STATE_IDLE:
        default:
            break;
    }

    lv_obj_t *status_pill = lv_obj_create(screen);
    lv_obj_set_size(status_pill, 132, 30);
    lv_obj_align(status_pill, LV_ALIGN_TOP_MID, 0, 54);
    lv_obj_set_style_radius(status_pill, 15, 0);
    lv_obj_set_style_bg_color(status_pill, lv_color_hex(0x111a23), 0);
    lv_obj_set_style_border_width(status_pill, 1, 0);
    lv_obj_set_style_border_color(status_pill, lv_color_hex(0x273746), 0);
    lv_obj_clear_flag(status_pill, LV_OBJ_FLAG_SCROLLABLE);

    lv_obj_t *status_label = lv_label_create(status_pill);
    lv_obj_set_style_text_font(status_label, &lv_font_montserrat_12, 0);
    lv_obj_set_style_text_color(status_label, lv_color_hex(0xe8bf6e), 0);
    lv_label_set_text(status_label, status != NULL ? status : "Ready");
    lv_obj_center(status_label);

    lv_obj_t *orb_glow = lv_obj_create(screen);
    lv_obj_set_size(orb_glow, 148, 148);
    lv_obj_align(orb_glow, LV_ALIGN_CENTER, 0, -12);
    lv_obj_set_style_radius(orb_glow, LV_RADIUS_CIRCLE, 0);
    lv_obj_set_style_bg_color(orb_glow, orb_start, 0);
    lv_obj_set_style_bg_grad_color(orb_glow, orb_start, 0);
    lv_obj_set_style_bg_grad_dir(orb_glow, LV_GRAD_DIR_NONE, 0);
    lv_obj_set_style_border_width(orb_glow, 0, 0);
    lv_obj_set_style_shadow_width(orb_glow, mic_active ? 44 : 34, 0);
    lv_obj_set_style_shadow_color(orb_glow, shadow_color, 0);
    lv_obj_set_style_shadow_opa(orb_glow, mic_active ? LV_OPA_50 : LV_OPA_40, 0);
    lv_obj_clear_flag(orb_glow, LV_OBJ_FLAG_SCROLLABLE);

    if (caption[0] != '\0') {
        lv_obj_t *caption_label = lv_label_create(screen);
        lv_obj_set_width(caption_label, 220);
        lv_label_set_long_mode(caption_label, LV_LABEL_LONG_WRAP);
        lv_obj_set_style_text_align(caption_label, LV_TEXT_ALIGN_CENTER, 0);
        lv_obj_set_style_text_font(caption_label, &lv_font_montserrat_12, 0);
        lv_obj_set_style_text_color(caption_label, lv_color_hex(0x9baabd), 0);
        lv_label_set_text(caption_label, caption);
        lv_obj_align(caption_label, LV_ALIGN_CENTER, 0, 102);
    }

    if (show_output_card) {
        lv_obj_t *output_card = lv_obj_create(screen);
        lv_obj_set_size(output_card, 316, 108);
        lv_obj_align(output_card, LV_ALIGN_BOTTOM_MID, 0, -72);
        lv_obj_set_style_radius(output_card, 24, 0);
        lv_obj_set_style_bg_color(output_card, lv_color_hex(0x111a23), 0);
        lv_obj_set_style_border_width(output_card, 1, 0);
        lv_obj_set_style_border_color(output_card, lv_color_hex(0x223343), 0);
        lv_obj_set_style_pad_all(output_card, 14, 0);
        lv_obj_clear_flag(output_card, LV_OBJ_FLAG_SCROLLABLE);

        lv_obj_t *output_label = lv_label_create(output_card);
        lv_obj_set_width(output_label, 284);
        lv_label_set_long_mode(output_label, LV_LABEL_LONG_WRAP);
        lv_obj_set_style_text_align(output_label, LV_TEXT_ALIGN_CENTER, 0);
        lv_obj_set_style_text_font(output_label, &lv_font_montserrat_14, 0);
        lv_obj_set_style_text_color(output_label, lv_color_hex(0xe8eef5), 0);
        lv_label_set_text(output_label, hint);
        lv_obj_center(output_label);
    }

    board_create_nav_bar(screen, 0);
    board_animate_entry(orb_glow);

    s_runtime.qr_screen_active = false;
    board_load_screen(screen, LV_SCR_LOAD_ANIM_MOVE_RIGHT);
}

static void board_create_widget_screen(const char *title, const char *metric, const char *detail, const char *footer, size_t index, size_t total) {
    char position[32];
    lv_obj_t *screen = lv_obj_create(NULL);
    board_style_base_screen(screen);
    board_create_header(screen, "WIDGETS");
    lv_obj_t *surface = board_create_surface(screen);

    lv_obj_t *eyebrow = lv_label_create(surface);
    lv_obj_set_style_text_font(eyebrow, &lv_font_montserrat_12, 0);
    lv_obj_set_style_text_color(eyebrow, lv_color_hex(0x8fa7bf), 0);
    lv_label_set_text(eyebrow, "LIVE CARD");
    lv_obj_align(eyebrow, LV_ALIGN_TOP_LEFT, 0, 2);

    lv_obj_t *title_label = lv_label_create(surface);
    lv_obj_set_width(title_label, 250);
    lv_label_set_long_mode(title_label, LV_LABEL_LONG_WRAP);
    lv_obj_set_style_text_font(title_label, &lv_font_montserrat_16, 0);
    lv_obj_set_style_text_color(title_label, lv_color_hex(0xf1f4f8), 0);
    lv_label_set_text(title_label, title != NULL ? title : "Widget");
    lv_obj_align(title_label, LV_ALIGN_TOP_LEFT, 0, 20);

    const bool has_metric = metric != NULL && metric[0] != '\0';
    const bool has_detail = detail != NULL && detail[0] != '\0';
    snprintf(position, sizeof(position), "%u / %u", (unsigned)(index + 1), (unsigned)total);
    if (!has_metric && !has_detail) {
        lv_obj_t *empty_label = lv_label_create(surface);
        lv_obj_set_width(empty_label, 240);
        lv_label_set_long_mode(empty_label, LV_LABEL_LONG_WRAP);
        lv_obj_set_style_text_align(empty_label, LV_TEXT_ALIGN_CENTER, 0);
        lv_obj_set_style_text_font(empty_label, &lv_font_montserrat_16, 0);
        lv_obj_set_style_text_color(empty_label, lv_color_hex(0x95aabf), 0);
        lv_label_set_text(empty_label, "No widgets available");
        lv_obj_align(empty_label, LV_ALIGN_CENTER, 0, -8);
    } else {
        if (has_metric) {
            lv_obj_t *metric_label = lv_label_create(surface);
            lv_obj_set_width(metric_label, 250);
            lv_label_set_long_mode(metric_label, LV_LABEL_LONG_WRAP);
            lv_obj_set_style_text_font(metric_label, &lv_font_montserrat_16, 0);
            lv_obj_set_style_text_color(metric_label, lv_color_hex(0xe6b667), 0);
            lv_label_set_text(metric_label, metric);
            lv_obj_align(metric_label, LV_ALIGN_TOP_LEFT, 0, 78);
        }

        if (has_detail) {
            lv_obj_t *detail_label = lv_label_create(surface);
            lv_obj_set_width(detail_label, 286);
            lv_label_set_long_mode(detail_label, LV_LABEL_LONG_WRAP);
            lv_obj_set_style_text_font(detail_label, &lv_font_montserrat_12, 0);
            lv_obj_set_style_text_color(detail_label, lv_color_hex(0xb7c7d6), 0);
            lv_label_set_text(detail_label, detail);
            lv_obj_align(detail_label, LV_ALIGN_TOP_LEFT, 0, has_metric ? 146 : 96);
        }
    }

    if (total > 1) {
        lv_obj_t *position_pill = lv_obj_create(surface);
        lv_obj_set_size(position_pill, 74, 34);
        lv_obj_align(position_pill, LV_ALIGN_TOP_RIGHT, 0, 74);
        lv_obj_set_style_radius(position_pill, 17, 0);
        lv_obj_set_style_bg_color(position_pill, lv_color_hex(0x14202c), 0);
        lv_obj_set_style_border_width(position_pill, 1, 0);
        lv_obj_set_style_border_color(position_pill, lv_color_hex(0x294155), 0);
        lv_obj_clear_flag(position_pill, LV_OBJ_FLAG_SCROLLABLE);
        lv_obj_t *position_label = lv_label_create(position_pill);
        lv_obj_set_style_text_font(position_label, &lv_font_montserrat_12, 0);
        lv_obj_set_style_text_color(position_label, lv_color_hex(0xd3deea), 0);
        lv_label_set_text(position_label, position);
        lv_obj_center(position_label);

        lv_obj_t *dot_row = lv_obj_create(surface);
        lv_obj_set_size(dot_row, 94, 18);
        lv_obj_align(dot_row, LV_ALIGN_BOTTOM_MID, 0, -8);
        lv_obj_set_style_bg_opa(dot_row, LV_OPA_TRANSP, 0);
        lv_obj_set_style_border_width(dot_row, 0, 0);
        lv_obj_set_style_pad_all(dot_row, 0, 0);
        lv_obj_clear_flag(dot_row, LV_OBJ_FLAG_SCROLLABLE);
        for (size_t dot = 0; dot < total && dot < 5; ++dot) {
            lv_obj_t *dot_obj = lv_obj_create(dot_row);
            lv_obj_set_size(dot_obj, dot == index ? 16 : 8, 8);
            lv_obj_align(dot_obj, LV_ALIGN_LEFT_MID, (lv_coord_t)(dot * 18), 0);
            lv_obj_set_style_radius(dot_obj, LV_RADIUS_CIRCLE, 0);
            lv_obj_set_style_bg_color(dot_obj, dot == index ? lv_color_hex(0xe6b667) : lv_color_hex(0x32485d), 0);
            lv_obj_set_style_border_width(dot_obj, 0, 0);
            lv_obj_clear_flag(dot_obj, LV_OBJ_FLAG_SCROLLABLE);
        }

        lv_obj_t *prev_pill = lv_obj_create(screen);
        lv_obj_set_size(prev_pill, 44, 44);
        lv_obj_align(prev_pill, LV_ALIGN_BOTTOM_LEFT, 18, -74);
        lv_obj_set_style_radius(prev_pill, 22, 0);
        lv_obj_set_style_bg_color(prev_pill, lv_color_hex(0x12202b), 0);
        lv_obj_set_style_border_width(prev_pill, 1, 0);
        lv_obj_set_style_border_color(prev_pill, lv_color_hex(0x2e4458), 0);
        lv_obj_t *prev_label = lv_label_create(prev_pill);
        lv_obj_set_style_text_font(prev_label, &lv_font_montserrat_16, 0);
        lv_obj_set_style_text_color(prev_label, lv_color_hex(0xe4ecf5), 0);
        lv_label_set_text(prev_label, LV_SYMBOL_LEFT);
        lv_obj_center(prev_label);

        lv_obj_t *next_pill = lv_obj_create(screen);
        lv_obj_set_size(next_pill, 44, 44);
        lv_obj_align(next_pill, LV_ALIGN_BOTTOM_RIGHT, -18, -74);
        lv_obj_set_style_radius(next_pill, 22, 0);
        lv_obj_set_style_bg_color(next_pill, lv_color_hex(0x12202b), 0);
        lv_obj_set_style_border_width(next_pill, 1, 0);
        lv_obj_set_style_border_color(next_pill, lv_color_hex(0x2e4458), 0);
        lv_obj_t *next_label = lv_label_create(next_pill);
        lv_obj_set_style_text_font(next_label, &lv_font_montserrat_16, 0);
        lv_obj_set_style_text_color(next_label, lv_color_hex(0xe4ecf5), 0);
        lv_label_set_text(next_label, LV_SYMBOL_RIGHT);
        lv_obj_center(next_label);
    }

    board_create_nav_bar(screen, 1);
    board_animate_entry(surface);

    s_runtime.qr_screen_active = false;
    board_load_screen(screen, LV_SCR_LOAD_ANIM_MOVE_LEFT);
}

static void board_create_recording_screen(
    const char *status,
    const char *headline,
    const char *detail,
    bool active,
    bool busy,
    const char *timer_text
) {
    lv_obj_t *screen = lv_obj_create(NULL);
    board_style_base_screen(screen);
    board_create_header(screen, "RECORD");

    lv_obj_t *status_pill = lv_obj_create(screen);
    lv_obj_set_size(status_pill, 148, 30);
    lv_obj_align(status_pill, LV_ALIGN_TOP_MID, 0, 58);
    lv_obj_set_style_radius(status_pill, 15, 0);
    lv_obj_set_style_bg_color(status_pill, lv_color_hex(0x111a23), 0);
    lv_obj_set_style_border_width(status_pill, 1, 0);
    lv_obj_set_style_border_color(status_pill, active ? lv_color_hex(0x6f2c33) : lv_color_hex(0x273746), 0);
    lv_obj_clear_flag(status_pill, LV_OBJ_FLAG_SCROLLABLE);

    lv_obj_t *status_label = lv_label_create(status_pill);
    lv_obj_set_style_text_font(status_label, &lv_font_montserrat_12, 0);
    lv_obj_set_style_text_color(status_label, active ? lv_color_hex(0xffd8da) : lv_color_hex(0xe8bf6e), 0);
    lv_label_set_text(status_label, status != NULL ? status : "Recording ready");
    lv_obj_center(status_label);

    lv_obj_t *timer_label = lv_label_create(screen);
    lv_obj_set_style_text_font(timer_label, &lv_font_montserrat_16, 0);
    lv_obj_set_style_text_color(timer_label, lv_color_hex(0xf2f4f8), 0);
    lv_label_set_text(timer_label, timer_text != NULL ? timer_text : "00:00");
    lv_obj_align(timer_label, LV_ALIGN_TOP_MID, 0, 106);

    lv_obj_t *cta_orb = lv_obj_create(screen);
    lv_obj_set_size(cta_orb, 150, 150);
    lv_obj_align(cta_orb, LV_ALIGN_CENTER, 0, 4);
    lv_obj_set_style_radius(cta_orb, LV_RADIUS_CIRCLE, 0);
    lv_obj_set_style_bg_color(cta_orb, active ? lv_color_hex(0xa63e48) : lv_color_hex(0xe0a908), 0);
    lv_obj_set_style_bg_grad_color(cta_orb, active ? lv_color_hex(0xa63e48) : lv_color_hex(0xe0a908), 0);
    lv_obj_set_style_bg_grad_dir(cta_orb, LV_GRAD_DIR_NONE, 0);
    lv_obj_set_style_border_width(cta_orb, 0, 0);
    lv_obj_set_style_shadow_width(cta_orb, busy ? 44 : 34, 0);
    lv_obj_set_style_shadow_opa(cta_orb, LV_OPA_40, 0);
    lv_obj_set_style_shadow_color(cta_orb, active ? lv_color_hex(0xbb505c) : lv_color_hex(0xf0b310), 0);
    lv_obj_clear_flag(cta_orb, LV_OBJ_FLAG_SCROLLABLE);

    lv_obj_t *cta_label = lv_label_create(cta_orb);
    lv_obj_set_width(cta_label, 120);
    lv_label_set_long_mode(cta_label, LV_LABEL_LONG_WRAP);
    lv_obj_set_style_text_align(cta_label, LV_TEXT_ALIGN_CENTER, 0);
    lv_obj_set_style_text_font(cta_label, &lv_font_montserrat_16, 0);
    lv_obj_set_style_text_color(cta_label, lv_color_hex(0x101010), 0);
    lv_label_set_text(cta_label, busy ? "Working..." : (active ? "Stop" : "Start"));
    lv_obj_center(cta_label);

    lv_obj_t *headline_label = lv_label_create(screen);
    lv_obj_set_width(headline_label, 260);
    lv_label_set_long_mode(headline_label, LV_LABEL_LONG_WRAP);
    lv_obj_set_style_text_align(headline_label, LV_TEXT_ALIGN_CENTER, 0);
    lv_obj_set_style_text_font(headline_label, &lv_font_montserrat_16, 0);
    lv_obj_set_style_text_color(headline_label, lv_color_hex(0xe8eef5), 0);
    lv_label_set_text(headline_label, headline != NULL ? headline : "Background capture");
    lv_obj_align(headline_label, LV_ALIGN_CENTER, 0, 112);

    if (detail != NULL && detail[0] != '\0') {
        lv_obj_t *detail_label = lv_label_create(screen);
        lv_obj_set_width(detail_label, 278);
        lv_label_set_long_mode(detail_label, LV_LABEL_LONG_WRAP);
        lv_obj_set_style_text_align(detail_label, LV_TEXT_ALIGN_CENTER, 0);
        lv_obj_set_style_text_font(detail_label, &lv_font_montserrat_12, 0);
        lv_obj_set_style_text_color(detail_label, lv_color_hex(0x9fb1c4), 0);
        lv_label_set_text(detail_label, detail);
        lv_obj_align(detail_label, LV_ALIGN_CENTER, 0, 152);
    }

    board_create_nav_bar(screen, 2);
    board_animate_entry(cta_orb);

    s_runtime.qr_screen_active = false;
    board_load_screen(screen, LV_SCR_LOAD_ANIM_MOVE_LEFT);
}

static void board_create_settings_screen(const char *section_title, const char *headline, const char *body, const char *selected_value, bool show_reset) {
    lv_obj_t *screen = lv_obj_create(NULL);
    board_style_base_screen(screen);
    board_create_header(screen, "SETTINGS");

    lv_obj_t *frame = lv_obj_create(screen);
    lv_obj_set_size(frame, 314, 304);
    lv_obj_align(frame, LV_ALIGN_CENTER, 0, -16);
    lv_obj_set_style_radius(frame, 24, 0);
    lv_obj_set_style_bg_color(frame, lv_color_hex(0x111a23), 0);
    lv_obj_set_style_border_width(frame, 1, 0);
    lv_obj_set_style_border_color(frame, lv_color_hex(0x223343), 0);
    lv_obj_set_style_pad_all(frame, 14, 0);
    lv_obj_clear_flag(frame, LV_OBJ_FLAG_SCROLLABLE);

    if (!show_reset) {
        if (section_title != NULL && strcmp(section_title, "Update") == 0) {
            board_create_list_row(frame, 0, "S", "Stable", selected_value == NULL || strcmp(selected_value, "beta") != 0);
            board_create_list_row(frame, 58, "B", "Beta", selected_value != NULL && strcmp(selected_value, "beta") == 0);

            lv_obj_t *update = lv_obj_create(frame);
            lv_obj_set_size(update, 268, 46);
            lv_obj_align(update, LV_ALIGN_BOTTOM_MID, 0, -66);
            lv_obj_set_style_radius(update, 18, 0);
            lv_obj_set_style_bg_color(update, lv_color_hex(0x143025), 0);
            lv_obj_set_style_border_width(update, 1, 0);
            lv_obj_set_style_border_color(update, lv_color_hex(0x29513d), 0);
            lv_obj_clear_flag(update, LV_OBJ_FLAG_SCROLLABLE);

            lv_obj_t *update_label = lv_label_create(update);
            lv_obj_set_style_text_font(update_label, &lv_font_montserrat_14, 0);
            lv_obj_set_style_text_color(update_label, lv_color_hex(0xe1f2ea), 0);
            lv_label_set_text(update_label, "Update now");
            lv_obj_center(update_label);

            lv_obj_t *setup = lv_obj_create(frame);
            lv_obj_set_size(setup, 268, 46);
            lv_obj_align(setup, LV_ALIGN_BOTTOM_MID, 0, -14);
            lv_obj_set_style_radius(setup, 18, 0);
            lv_obj_set_style_bg_color(setup, lv_color_hex(0x2c220f), 0);
            lv_obj_set_style_border_width(setup, 1, 0);
            lv_obj_set_style_border_color(setup, lv_color_hex(0x8a6b35), 0);
            lv_obj_clear_flag(setup, LV_OBJ_FLAG_SCROLLABLE);

            lv_obj_t *setup_label = lv_label_create(setup);
            lv_obj_set_style_text_font(setup_label, &lv_font_montserrat_14, 0);
            lv_obj_set_style_text_color(setup_label, lv_color_hex(0xf2dfb8), 0);
            lv_label_set_text(setup_label, "Re-enter setup mode");
            lv_obj_center(setup_label);
        } else if (section_title != NULL && strcmp(section_title, "Settings") == 0) {
            board_create_list_row(frame, 32, LV_SYMBOL_WIFI, "Network", false);
            board_create_list_row(frame, 110, LV_SYMBOL_REFRESH, "Update", false);
        } else {
            lv_obj_t *headline_label = lv_label_create(frame);
            lv_obj_set_width(headline_label, 268);
            lv_label_set_long_mode(headline_label, LV_LABEL_LONG_WRAP);
            lv_obj_set_style_text_font(headline_label, &lv_font_montserrat_16, 0);
            lv_obj_set_style_text_color(headline_label, lv_color_hex(0xe7eef7), 0);
            lv_label_set_text(headline_label, headline != NULL ? headline : "Settings");
            lv_obj_align(headline_label, LV_ALIGN_TOP_LEFT, 0, 24);

            if (body != NULL && body[0] != '\0') {
                lv_obj_t *body_label = lv_label_create(frame);
                lv_obj_set_width(body_label, 268);
                lv_label_set_long_mode(body_label, LV_LABEL_LONG_WRAP);
                lv_obj_set_style_text_font(body_label, &lv_font_montserrat_12, 0);
                lv_obj_set_style_text_color(body_label, lv_color_hex(0xa4b6c9), 0);
                lv_label_set_text(body_label, body);
                lv_obj_align(body_label, LV_ALIGN_TOP_LEFT, 0, 66);
            }
        }
    } else {
        lv_obj_t *eyebrow = lv_label_create(frame);
        lv_obj_set_style_text_font(eyebrow, &lv_font_montserrat_12, 0);
        lv_obj_set_style_text_color(eyebrow, lv_color_hex(0xd8b06b), 0);
        lv_label_set_text(eyebrow, "RESET");
        lv_obj_align(eyebrow, LV_ALIGN_TOP_LEFT, 0, 4);

        lv_obj_t *headline_label = lv_label_create(frame);
        lv_obj_set_width(headline_label, 268);
        lv_label_set_long_mode(headline_label, LV_LABEL_LONG_WRAP);
        lv_obj_set_style_text_font(headline_label, &lv_font_montserrat_16, 0);
        lv_obj_set_style_text_color(headline_label, lv_color_hex(0xe7eef7), 0);
        lv_label_set_text(headline_label, "Forget this device");
        lv_obj_align(headline_label, LV_ALIGN_TOP_LEFT, 0, 34);

        lv_obj_t *body_label = lv_label_create(frame);
        lv_obj_set_width(body_label, 268);
        lv_label_set_long_mode(body_label, LV_LABEL_LONG_WRAP);
        lv_obj_set_style_text_font(body_label, &lv_font_montserrat_12, 0);
        lv_obj_set_style_text_color(body_label, lv_color_hex(0xa4b6c9), 0);
        lv_label_set_text(body_label, "Clear pairing and Wi-Fi setup, then return to provisioning.");
        lv_obj_align(body_label, LV_ALIGN_TOP_LEFT, 0, 76);

        lv_obj_t *reset = lv_obj_create(frame);
        lv_obj_set_size(reset, 268, 54);
        lv_obj_align(reset, LV_ALIGN_BOTTOM_MID, 0, -22);
        lv_obj_set_style_radius(reset, 18, 0);
        lv_obj_set_style_bg_color(reset, lv_color_hex(0x38171d), 0);
        lv_obj_set_style_border_width(reset, 1, 0);
        lv_obj_set_style_border_color(reset, lv_color_hex(0x6d3a42), 0);
        lv_obj_clear_flag(reset, LV_OBJ_FLAG_SCROLLABLE);

        lv_obj_t *reset_label = lv_label_create(reset);
        lv_obj_set_style_text_font(reset_label, &lv_font_montserrat_14, 0);
        lv_obj_set_style_text_color(reset_label, lv_color_hex(0xf3d4d7), 0);
        lv_label_set_text(reset_label, "Reset Device");
        lv_obj_center(reset_label);
    }

    if (show_reset || (section_title != NULL && strcmp(section_title, "Settings") == 0)) {
        board_create_nav_bar(screen, 3);
    } else {
        lv_obj_t *back = lv_obj_create(screen);
        lv_obj_set_size(back, 312, 54);
        lv_obj_align(back, LV_ALIGN_BOTTOM_MID, 0, -12);
        lv_obj_set_style_radius(back, 18, 0);
        lv_obj_set_style_bg_color(back, lv_color_hex(0x101820), 0);
        lv_obj_set_style_border_width(back, 1, 0);
        lv_obj_set_style_border_color(back, lv_color_hex(0x2a3947), 0);
        lv_obj_clear_flag(back, LV_OBJ_FLAG_SCROLLABLE);

        lv_obj_t *back_label = lv_label_create(back);
        lv_obj_set_style_text_font(back_label, &lv_font_montserrat_14, 0);
        lv_obj_set_style_text_color(back_label, lv_color_hex(0xe7eef7), 0);
        lv_label_set_text(back_label, LV_SYMBOL_LEFT " Back");
        lv_obj_center(back_label);
    }
    board_animate_entry(frame);

    s_runtime.qr_screen_active = false;
    board_load_screen(screen, LV_SCR_LOAD_ANIM_MOVE_LEFT);
}

esp_err_t board_support_init(board_support_t *board) {
    if (board == NULL) {
        return ESP_ERR_INVALID_ARG;
    }

    memset(board, 0, sizeof(*board));
    if (s_runtime.initialized) {
        board->display_ready = true;
        board->touch_ready = true;
        board->audio_ready = s_runtime.codec_handle != NULL;
        return ESP_OK;
    }

    const i2c_master_bus_config_t i2c_config = {
        .clk_source = I2C_CLK_SRC_DEFAULT,
        .i2c_port = BOARD_TOUCH_HOST,
        .sda_io_num = BOARD_TOUCH_SDA,
        .scl_io_num = BOARD_TOUCH_SCL,
        .glitch_ignore_cnt = 15,  // Maximum glitch filtering to suppress charger noise during I2C transactions
        .flags.enable_internal_pullup = true,
    };
    ESP_ERROR_CHECK(i2c_new_master_bus(&i2c_config, &s_runtime.i2c_bus));

    const gpio_config_t button_config = {
        .pin_bit_mask = (1ULL << BOARD_BOOT_BUTTON) | (1ULL << BOARD_POWER_BUTTON),
        .mode = GPIO_MODE_INPUT,
        .pull_up_en = GPIO_PULLUP_ENABLE,
        .pull_down_en = GPIO_PULLDOWN_DISABLE,
        .intr_type = GPIO_INTR_DISABLE,
    };
    ESP_ERROR_CHECK(gpio_config(&button_config));

    esp_io_expander_handle_t io_expander = NULL;
    ESP_ERROR_CHECK(esp_io_expander_new_i2c_tca9554(s_runtime.i2c_bus, ESP_IO_EXPANDER_I2C_TCA9554_ADDRESS_000, &io_expander));
    ESP_ERROR_CHECK(esp_io_expander_set_dir(io_expander, IO_EXPANDER_PIN_NUM_0 | IO_EXPANDER_PIN_NUM_1 | IO_EXPANDER_PIN_NUM_2, IO_EXPANDER_OUTPUT));
    ESP_ERROR_CHECK(esp_io_expander_set_level(io_expander, IO_EXPANDER_PIN_NUM_0, 0));
    ESP_ERROR_CHECK(esp_io_expander_set_level(io_expander, IO_EXPANDER_PIN_NUM_1, 0));
    ESP_ERROR_CHECK(esp_io_expander_set_level(io_expander, IO_EXPANDER_PIN_NUM_2, 0));
    vTaskDelay(pdMS_TO_TICKS(200));
    ESP_ERROR_CHECK(esp_io_expander_set_level(io_expander, IO_EXPANDER_PIN_NUM_0, 1));
    ESP_ERROR_CHECK(esp_io_expander_set_level(io_expander, IO_EXPANDER_PIN_NUM_1, 1));
    ESP_ERROR_CHECK(esp_io_expander_set_level(io_expander, IO_EXPANDER_PIN_NUM_2, 1));

    const spi_bus_config_t bus_config = SH8601_PANEL_BUS_QSPI_CONFIG(
        BOARD_LCD_PCLK,
        BOARD_LCD_DATA0,
        BOARD_LCD_DATA1,
        BOARD_LCD_DATA2,
        BOARD_LCD_DATA3,
        BOARD_LCD_H_RES * BOARD_LCD_V_RES * BOARD_LCD_BIT_PER_PIXEL / 8
    );
    ESP_ERROR_CHECK(spi_bus_initialize(BOARD_LCD_HOST, &bus_config, SPI_DMA_CH_AUTO));

    esp_lcd_panel_io_handle_t io_handle = NULL;
    const esp_lcd_panel_io_spi_config_t io_config = SH8601_PANEL_IO_QSPI_CONFIG(
        BOARD_LCD_CS,
        board_notify_flush_ready,
        &s_runtime.disp_drv
    );
    ESP_ERROR_CHECK(esp_lcd_new_panel_io_spi((esp_lcd_spi_bus_handle_t)BOARD_LCD_HOST, &io_config, &io_handle));

    const sh8601_vendor_config_t vendor_config = {
        .init_cmds = s_lcd_init_cmds,
        .init_cmds_size = sizeof(s_lcd_init_cmds) / sizeof(s_lcd_init_cmds[0]),
        .flags = {
            .use_qspi_interface = 1,
        },
    };
    const esp_lcd_panel_dev_config_t panel_config = {
        .reset_gpio_num = -1,
        .rgb_ele_order = LCD_RGB_ELEMENT_ORDER_RGB,
        .bits_per_pixel = BOARD_LCD_BIT_PER_PIXEL,
        .vendor_config = (void *)&vendor_config,
    };
    ESP_ERROR_CHECK(esp_lcd_new_panel_sh8601(io_handle, &panel_config, &s_runtime.panel_handle));
    ESP_ERROR_CHECK(esp_lcd_panel_reset(s_runtime.panel_handle));
    ESP_ERROR_CHECK(esp_lcd_panel_init(s_runtime.panel_handle));
    ESP_ERROR_CHECK(esp_lcd_panel_disp_on_off(s_runtime.panel_handle, true));

    esp_lcd_panel_io_i2c_config_t touch_io_config = ESP_LCD_TOUCH_IO_I2C_FT5x06_CONFIG();
    ESP_ERROR_CHECK(esp_lcd_new_panel_io_i2c(s_runtime.i2c_bus, &touch_io_config, &s_runtime.touch_io));

    esp_lcd_touch_config_t touch_config = {
        .x_max = BOARD_LCD_H_RES,
        .y_max = BOARD_LCD_V_RES,
        .rst_gpio_num = GPIO_NUM_NC,
        .int_gpio_num = BOARD_TOUCH_INT,
        .levels = {
            .reset = 0,
            .interrupt = 0,
        },
        .flags = {
            .swap_xy = 0,
            .mirror_x = 0,
            .mirror_y = 0,
        },
    };
    esp_err_t touch_err = esp_lcd_touch_new_i2c_ft5x06(s_runtime.touch_io, &touch_config, &s_runtime.touch_handle);
    if (touch_err != ESP_OK) {
        ESP_LOGW(TAG, "touch init failed: %s", esp_err_to_name(touch_err));
        s_runtime.touch_handle = NULL;
    }

    lv_init();
    s_runtime.buf1 = heap_caps_malloc(BOARD_LCD_H_RES * BOARD_LVGL_BUF_HEIGHT * sizeof(lv_color_t), MALLOC_CAP_DMA);
    s_runtime.buf2 = NULL;
    assert(s_runtime.buf1 != NULL);
    lv_disp_draw_buf_init(&s_runtime.disp_buf, s_runtime.buf1, s_runtime.buf2, BOARD_LCD_H_RES * BOARD_LVGL_BUF_HEIGHT);

    lv_disp_drv_init(&s_runtime.disp_drv);
    s_runtime.disp_drv.hor_res = BOARD_LCD_H_RES;
    s_runtime.disp_drv.ver_res = BOARD_LCD_V_RES;
    s_runtime.disp_drv.flush_cb = board_lvgl_flush_cb;
    s_runtime.disp_drv.rounder_cb = board_lvgl_rounder_cb;
    s_runtime.disp_drv.drv_update_cb = board_lvgl_update_cb;
    s_runtime.disp_drv.draw_buf = &s_runtime.disp_buf;
    s_runtime.disp_drv.user_data = s_runtime.panel_handle;
    lv_disp_t *display = lv_disp_drv_register(&s_runtime.disp_drv);

    (void)display;

    const esp_timer_create_args_t timer_args = {
        .callback = board_increase_lvgl_tick,
        .name = "neo_lvgl_tick",
    };
    esp_timer_handle_t tick_timer = NULL;
    ESP_ERROR_CHECK(esp_timer_create(&timer_args, &tick_timer));
    ESP_ERROR_CHECK(esp_timer_start_periodic(tick_timer, BOARD_LVGL_TICK_PERIOD_MS * 1000));

    s_runtime.lvgl_mutex = xSemaphoreCreateMutex();
    assert(s_runtime.lvgl_mutex != NULL);
    xTaskCreate(board_lvgl_task, "neo_lvgl", BOARD_LVGL_TASK_STACK_SIZE, NULL, 2, NULL);

    if (board_lock(-1)) {
        board_create_boot_screen();
        board_unlock();
    }

    s_runtime.initialized = true;
    s_runtime.chrome.battery_percent = -1;
    snprintf(s_runtime.chrome_time, sizeof(s_runtime.chrome_time), "--:--");
    esp_err_t audio_err = board_audio_init_codec();
    if (audio_err != ESP_OK) {
        ESP_LOGW(TAG, "audio init failed: %s", esp_err_to_name(audio_err));
    }
    esp_err_t pmu_err = board_pmu_enable_battery_measurements();
    if (pmu_err != ESP_OK) {
        ESP_LOGW(TAG, "pmu battery setup failed: %s", esp_err_to_name(pmu_err));
    }

    board->display_ready = true;
    board->touch_ready = s_runtime.touch_handle != NULL;
    board->audio_ready = audio_err == ESP_OK;
    ESP_LOGI(TAG, "display initialized; touch_ready=%d audio_ready=%d", board->touch_ready, board->audio_ready);
    return ESP_OK;
}

esp_err_t board_support_set_chrome(board_support_t *board, const neoagent_status_chrome_t *status, const char *time_text) {
    if (board == NULL || !s_runtime.initialized) {
        return ESP_ERR_INVALID_STATE;
    }
    if (!board_lock(1000)) {
        return ESP_ERR_TIMEOUT;
    }
    if (status != NULL) {
        s_runtime.chrome = *status;
    }
    if (time_text != NULL && time_text[0] != '\0') {
        snprintf(s_runtime.chrome_time, sizeof(s_runtime.chrome_time), "%s", time_text);
    } else {
        snprintf(s_runtime.chrome_time, sizeof(s_runtime.chrome_time), "--:--");
    }
    board_unlock();
    return ESP_OK;
}

esp_err_t board_support_show_message(board_support_t *board, const char *title, const char *line1, const char *line2) {
    if (board == NULL || !s_runtime.initialized) {
        return ESP_ERR_INVALID_STATE;
    }
    if (!board_lock(1000)) {
        return ESP_ERR_TIMEOUT;
    }
    board_create_status_screen();
    lv_label_set_text(s_runtime.title_label, title != NULL ? title : "");
    lv_label_set_text(s_runtime.line1_label, line1 != NULL ? line1 : "");
    lv_label_set_text(s_runtime.line2_label, line2 != NULL ? line2 : "");
    board_unlock();
    return ESP_OK;
}

esp_err_t board_support_show_boot_screen(board_support_t *board) {
    if (board == NULL || !s_runtime.initialized) {
        return ESP_ERR_INVALID_STATE;
    }
    if (!board_lock(1000)) {
        return ESP_ERR_TIMEOUT;
    }
    board_create_boot_screen();
    board_unlock();
    return ESP_OK;
}

esp_err_t board_support_show_qr(board_support_t *board, const char *title, const char *subtitle, const char *qr_payload) {
    if (board == NULL || !s_runtime.initialized) {
        return ESP_ERR_INVALID_STATE;
    }
    if (!board_lock(1000)) {
        return ESP_ERR_TIMEOUT;
    }
    board_create_qr_screen(title, subtitle, qr_payload);
    board_unlock();
    return ESP_OK;
}

esp_err_t board_support_show_assistant(board_support_t *board, const char *status, const char *hint, bool mic_active, board_assistant_state_t state) {
    if (board == NULL || !s_runtime.initialized) {
        return ESP_ERR_INVALID_STATE;
    }
    if (!board_lock(1000)) {
        return ESP_ERR_TIMEOUT;
    }
    board_create_assistant_screen(status, hint, mic_active, state);
    board_unlock();
    return ESP_OK;
}

esp_err_t board_support_show_widget_card(board_support_t *board, const char *title, const char *metric, const char *detail, const char *footer, size_t index, size_t total) {
    if (board == NULL || !s_runtime.initialized) {
        return ESP_ERR_INVALID_STATE;
    }
    if (!board_lock(1000)) {
        return ESP_ERR_TIMEOUT;
    }
    board_create_widget_screen(title, metric, detail, footer, index, total);
    board_unlock();
    return ESP_OK;
}

esp_err_t board_support_show_recording(board_support_t *board, const char *status, const char *headline, const char *detail, bool active, bool busy, const char *timer_text) {
    if (board == NULL || !s_runtime.initialized) {
        return ESP_ERR_INVALID_STATE;
    }
    if (!board_lock(1000)) {
        return ESP_ERR_TIMEOUT;
    }
    board_create_recording_screen(status, headline, detail, active, busy, timer_text);
    board_unlock();
    return ESP_OK;
}

esp_err_t board_support_show_settings(board_support_t *board, const char *section_title, const char *headline, const char *body, const char *selected_value, bool show_reset) {
    if (board == NULL || !s_runtime.initialized) {
        return ESP_ERR_INVALID_STATE;
    }
    if (!board_lock(1000)) {
        return ESP_ERR_TIMEOUT;
    }
    board_create_settings_screen(section_title, headline, body, selected_value, show_reset);
    board_unlock();
    return ESP_OK;
}

esp_err_t board_support_poll_touch(board_support_t *board, board_touch_event_t *event) {
    if (board == NULL || event == NULL || !s_runtime.initialized) {
        return ESP_ERR_INVALID_ARG;
    }
    memset(event, 0, sizeof(*event));
    if (s_runtime.touch_handle == NULL) {
        return ESP_ERR_NOT_SUPPORTED;
    }

    const int interrupt_level = gpio_get_level(BOARD_TOUCH_INT);
    if (!s_runtime.touch_down && interrupt_level != 0) {
        return ESP_OK;
    }

    uint16_t x[1] = {0};
    uint16_t y[1] = {0};
    uint8_t points = 0;
    esp_err_t touch_read_err = esp_lcd_touch_read_data(s_runtime.touch_handle);
    if (touch_read_err != ESP_OK) {
        ESP_LOGW(TAG, "touch read failed: %s", esp_err_to_name(touch_read_err));
        return touch_read_err;
    }
    bool pressed = esp_lcd_touch_get_coordinates(s_runtime.touch_handle, x, y, NULL, &points, 1);

    if (pressed && points > 0) {
        event->pressed = !s_runtime.touch_down;
        event->x = x[0];
        event->y = y[0];
        if (!s_runtime.touch_down) {
            s_runtime.touch_start_x = x[0];
            s_runtime.touch_start_y = y[0];
        }
        s_runtime.touch_down = true;
        s_runtime.last_touch_x = x[0];
        s_runtime.last_touch_y = y[0];
        return ESP_OK;
    }

    if (s_runtime.touch_down) {
        s_runtime.touch_down = false;
        event->released = true;
        event->tapped = true;
        event->x = s_runtime.last_touch_x;
        event->y = s_runtime.last_touch_y;
        int32_t delta_y = (int32_t)s_runtime.last_touch_y - (int32_t)s_runtime.touch_start_y;
        int32_t delta_x = (int32_t)s_runtime.last_touch_x - (int32_t)s_runtime.touch_start_x;
        if (delta_y <= -60 && abs(delta_y) > abs(delta_x)) {
            event->swipe_up = true;
            event->tapped = false;
        } else if (delta_y >= 60 && abs(delta_y) > abs(delta_x)) {
            event->swipe_down = true;
            event->tapped = false;
        }
        return ESP_OK;
    }

    return ESP_OK;
}

static void board_update_button_state(
    bool pressed,
    bool *down,
    bool *long_fired,
    int64_t *started_us,
    bool *press_event,
    bool *release_event,
    bool *short_press,
    bool *long_press
) {
    const int64_t now_us = esp_timer_get_time();
    if (pressed) {
        if (!*down) {
            *down = true;
            *long_fired = false;
            *started_us = now_us;
            *press_event = true;
            return;
        }
        if (!*long_fired && (now_us - *started_us) >= BOARD_BUTTON_LONG_PRESS_US) {
            *long_fired = true;
            *long_press = true;
        }
        return;
    }

    if (!*down) {
        return;
    }

    if (!*long_fired) {
        *short_press = true;
    }
    *release_event = true;
    *down = false;
    *long_fired = false;
    *started_us = 0;
}

esp_err_t board_support_poll_buttons(board_support_t *board, board_button_event_t *event) {
    if (board == NULL || event == NULL || !s_runtime.initialized) {
        return ESP_ERR_INVALID_ARG;
    }
    memset(event, 0, sizeof(*event));
    board_update_button_state(
        gpio_get_level(BOARD_POWER_BUTTON) == 0,
        &s_runtime.power_button_down,
        &s_runtime.power_button_long_fired,
        &s_runtime.power_button_press_started_us,
        &event->power_pressed,
        &event->power_released,
        &event->power_short_press,
        &event->power_long_press
    );
    board_update_button_state(
        gpio_get_level(BOARD_BOOT_BUTTON) == 0,
        &s_runtime.boot_button_down,
        &s_runtime.boot_button_long_fired,
        &s_runtime.boot_button_press_started_us,
        &event->boot_pressed,
        &event->boot_released,
        &event->boot_short_press,
        &event->boot_long_press
    );
    return ESP_OK;
}

bool board_support_audio_is_ready(const board_support_t *board) {
    return board != NULL && s_runtime.initialized && s_runtime.codec_handle != NULL;
}

const board_audio_format_t *board_support_audio_format(const board_support_t *board) {
    if (!board_support_audio_is_ready(board)) {
        return NULL;
    }
    return &s_runtime.audio_format;
}

esp_err_t board_support_audio_read(board_support_t *board, void *buffer, size_t buffer_size, size_t *bytes_read, int timeout_ms) {
    if (!board_support_audio_is_ready(board) || buffer == NULL || bytes_read == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    *bytes_read = 0;
    if (s_runtime.i2s_rx_chan == NULL) {
        return ESP_ERR_INVALID_STATE;
    }
    return i2s_channel_read(
        s_runtime.i2s_rx_chan,
        buffer,
        buffer_size,
        bytes_read,
        timeout_ms < 0 ? portMAX_DELAY : pdMS_TO_TICKS(timeout_ms)
    );
}

esp_err_t board_support_audio_play_wav(board_support_t *board, const uint8_t *wav_bytes, size_t wav_length, int timeout_ms) {
    if (!board_support_audio_is_ready(board) || wav_bytes == NULL || wav_length == 0) {
        return ESP_ERR_INVALID_ARG;
    }
    if (s_runtime.i2s_tx_chan == NULL) {
        return ESP_ERR_INVALID_STATE;
    }

    board_wav_view_t view = {0};
    ESP_RETURN_ON_ERROR(board_parse_wav(wav_bytes, wav_length, &view), TAG, "invalid wav payload");
    ESP_RETURN_ON_ERROR(
        board_audio_open_codec(view.sample_rate, (uint8_t)view.channels, (uint8_t)view.bits_per_sample),
        TAG,
        "codec reopen failed"
    );

    size_t offset = 0;
    while (offset < view.payload_length) {
        size_t written = 0;
        esp_err_t err = i2s_channel_write(
            s_runtime.i2s_tx_chan,
            view.payload + offset,
            view.payload_length - offset,
            &written,
            timeout_ms < 0 ? portMAX_DELAY : pdMS_TO_TICKS(timeout_ms)
        );
        if (err != ESP_OK) {
            return err;
        }
        if (written == 0) {
            return ESP_ERR_TIMEOUT;
        }
        offset += written;
    }
    return ESP_OK;
}

esp_err_t board_support_read_battery_status(board_support_t *board, int *battery_percent, bool *charging) {
    if (board == NULL || !s_runtime.initialized || battery_percent == NULL || charging == NULL) {
        return ESP_ERR_INVALID_ARG;
    }

    uint8_t status1 = 0;
    uint8_t status2 = 0;
    uint8_t percent = 0;
    ESP_RETURN_ON_ERROR(board_pmu_read_register(BOARD_AXP2101_STATUS1, &status1, 1), TAG, "pmu status1 read failed");
    ESP_RETURN_ON_ERROR(board_pmu_read_register(BOARD_AXP2101_STATUS2, &status2, 1), TAG, "pmu status2 read failed");

    const bool battery_connected = (status1 & 0x08U) != 0;
    *charging = ((status2 >> 5) & 0x03U) == 0x01U;
    if (!battery_connected) {
        *battery_percent = -1;
        return ESP_OK;
    }

    ESP_RETURN_ON_ERROR(board_pmu_read_register(BOARD_AXP2101_BAT_PERCENT_DATA, &percent, 1), TAG, "pmu percent read failed");
    if (percent > 100) {
        percent = 100;
    }
    *battery_percent = (int)percent;
    return ESP_OK;
}

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
#include "board_ui.h"
#include "lvgl.h"

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

#define BOARD_LCD_NATIVE_H_RES 368
#define BOARD_LCD_NATIVE_V_RES 448
#define BOARD_LCD_H_RES BOARD_UI_WIDTH
#define BOARD_LCD_V_RES BOARD_UI_HEIGHT
#define BOARD_LCD_BIT_PER_PIXEL 16
#define BOARD_LVGL_BUF_HEIGHT 24
#define BOARD_LVGL_BUF_PIXELS (BOARD_LCD_H_RES * BOARD_LVGL_BUF_HEIGHT)
#define BOARD_UI_ROTATION LV_DISP_ROT_270
#define BOARD_LVGL_TICK_PERIOD_MS 2
#define BOARD_LVGL_TASK_STACK_SIZE (4 * 1024)
#define BOARD_BUTTON_LONG_PRESS_US 700000
#define BOARD_TOUCH_SWIPE_DISTANCE 60
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
    bool initialized;
    SemaphoreHandle_t lvgl_mutex;
    esp_lcd_panel_handle_t panel_handle;
    lv_disp_drv_t disp_drv;
    lv_disp_draw_buf_t disp_buf;
    lv_color_t *buf1;
    lv_color_t *buf2;
    lv_color_t *rotate_buf;
    bool display_awake;
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
    const int32_t logical_w = area->x2 - area->x1 + 1;
    const int32_t logical_h = area->y2 - area->y1 + 1;
    const size_t pixel_count = (size_t)logical_w * (size_t)logical_h;

    if (s_runtime.rotate_buf == NULL || pixel_count > BOARD_LVGL_BUF_PIXELS) {
        ESP_LOGE(TAG, "invalid flush buffer pixels=%u", (unsigned)pixel_count);
        lv_disp_flush_ready(drv);
        return;
    }

    int32_t draw_x1 = 0;
    int32_t draw_y1 = 0;
    int32_t draw_x2 = 0;
    int32_t draw_y2 = 0;

    switch (BOARD_UI_ROTATION) {
        case LV_DISP_ROT_90:
            draw_x1 = BOARD_LCD_NATIVE_H_RES - 1 - area->y2;
            draw_y1 = area->x1;
            draw_x2 = BOARD_LCD_NATIVE_H_RES - area->y1;
            draw_y2 = area->x2 + 1;
            for (int32_t y = 0; y < logical_h; ++y) {
                for (int32_t x = 0; x < logical_w; ++x) {
                    s_runtime.rotate_buf[x * logical_h + (logical_h - 1 - y)] = color_map[y * logical_w + x];
                }
            }
            break;
        case LV_DISP_ROT_270:
            draw_x1 = area->y1;
            draw_y1 = BOARD_LCD_NATIVE_V_RES - 1 - area->x2;
            draw_x2 = area->y2 + 1;
            draw_y2 = BOARD_LCD_NATIVE_V_RES - area->x1;
            for (int32_t y = 0; y < logical_h; ++y) {
                for (int32_t x = 0; x < logical_w; ++x) {
                    s_runtime.rotate_buf[(logical_w - 1 - x) * logical_h + y] = color_map[y * logical_w + x];
                }
            }
            break;
        default:
            ESP_LOGE(TAG, "unsupported software rotation=%d", (int)BOARD_UI_ROTATION);
            lv_disp_flush_ready(drv);
            return;
    }

    esp_err_t err = esp_lcd_panel_draw_bitmap(panel_handle, draw_x1, draw_y1, draw_x2, draw_y2, s_runtime.rotate_buf);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "flush failed: %s", esp_err_to_name(err));
        lv_disp_flush_ready(drv);
    }
}

static void board_lvgl_rounder_cb(lv_disp_drv_t *disp_drv, lv_area_t *area) {
    (void)disp_drv;
    area->x1 = (area->x1 >> 1) << 1;
    area->y1 = (area->y1 >> 1) << 1;
    area->x2 = ((area->x2 >> 1) << 1) + 1;
    area->y2 = ((area->y2 >> 1) << 1) + 1;
}

static void board_transform_touch_point(uint16_t raw_x, uint16_t raw_y, uint16_t *logical_x, uint16_t *logical_y) {
    uint16_t x = raw_x;
    uint16_t y = raw_y;

    switch (BOARD_UI_ROTATION) {
        case LV_DISP_ROT_90:
            x = raw_y;
            y = (BOARD_LCD_NATIVE_H_RES - 1U) - raw_x;
            break;
        case LV_DISP_ROT_180:
            x = (BOARD_LCD_NATIVE_H_RES - 1U) - raw_x;
            y = (BOARD_LCD_NATIVE_V_RES - 1U) - raw_y;
            break;
        case LV_DISP_ROT_270:
            x = (BOARD_LCD_NATIVE_V_RES - 1U) - raw_y;
            y = raw_x;
            break;
        case LV_DISP_ROT_NONE:
        default:
            break;
    }

    if (x >= BOARD_LCD_H_RES) {
        x = BOARD_LCD_H_RES - 1U;
    }
    if (y >= BOARD_LCD_V_RES) {
        y = BOARD_LCD_V_RES - 1U;
    }
    *logical_x = x;
    *logical_y = y;
}

static void board_increase_lvgl_tick(void *arg) {
    (void)arg;
    lv_tick_inc(BOARD_LVGL_TICK_PERIOD_MS);
}

static void board_lvgl_task(void *arg) {
    (void)arg;
    while (true) {
        if (board_lock(-1)) {
            // A dark panel needs no frames; animation picks up on wake.
            uint32_t delay_ms = s_runtime.display_awake ? lv_timer_handler() : 100;
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

static void board_pmu_device_reset(void) {
    if (s_runtime.i2c_bus != NULL && s_runtime.pmu_device_handle != NULL) {
        esp_err_t err = i2c_master_bus_rm_device(s_runtime.pmu_device_handle);
        if (err != ESP_OK) {
            ESP_LOGW(TAG, "pmu device reset failed: %s", esp_err_to_name(err));
        }
    }
    s_runtime.pmu_device_handle = NULL;
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
            board_pmu_device_reset();
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
            board_pmu_device_reset();
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
        BOARD_LCD_NATIVE_H_RES * BOARD_LCD_NATIVE_V_RES * BOARD_LCD_BIT_PER_PIXEL / 8
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
    s_runtime.display_awake = true;

    esp_lcd_panel_io_i2c_config_t touch_io_config = ESP_LCD_TOUCH_IO_I2C_FT5x06_CONFIG();
    ESP_ERROR_CHECK(esp_lcd_new_panel_io_i2c(s_runtime.i2c_bus, &touch_io_config, &s_runtime.touch_io));

    esp_lcd_touch_config_t touch_config = {
        .x_max = BOARD_LCD_NATIVE_H_RES,
        .y_max = BOARD_LCD_NATIVE_V_RES,
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
    s_runtime.buf1 = heap_caps_malloc(BOARD_LVGL_BUF_PIXELS * sizeof(lv_color_t), MALLOC_CAP_DMA);
    s_runtime.buf2 = NULL;
    s_runtime.rotate_buf = heap_caps_malloc(BOARD_LVGL_BUF_PIXELS * sizeof(lv_color_t), MALLOC_CAP_DMA);
    assert(s_runtime.buf1 != NULL);
    assert(s_runtime.rotate_buf != NULL);
    lv_disp_draw_buf_init(&s_runtime.disp_buf, s_runtime.buf1, s_runtime.buf2, BOARD_LVGL_BUF_PIXELS);

    lv_disp_drv_init(&s_runtime.disp_drv);
    s_runtime.disp_drv.hor_res = BOARD_LCD_H_RES;
    s_runtime.disp_drv.ver_res = BOARD_LCD_V_RES;
    s_runtime.disp_drv.flush_cb = board_lvgl_flush_cb;
    s_runtime.disp_drv.rounder_cb = board_lvgl_rounder_cb;
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
        board_ui_show_boot();
        board_unlock();
    }

    s_runtime.initialized = true;
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
    board_ui_set_chrome(status, time_text);
    board_unlock();
    return ESP_OK;
}

esp_err_t board_support_set_display_awake(board_support_t *board, bool awake) {
    if (board == NULL || !s_runtime.initialized || s_runtime.panel_handle == NULL) {
        return ESP_ERR_INVALID_STATE;
    }
    if (!board_lock(1000)) {
        return ESP_ERR_TIMEOUT;
    }
    if (s_runtime.display_awake == awake) {
        board_unlock();
        return ESP_OK;
    }
    esp_err_t err = esp_lcd_panel_disp_on_off(s_runtime.panel_handle, awake);
    if (err == ESP_OK) {
        s_runtime.display_awake = awake;
        if (awake) {
            // Rendering paused while dark; redraw what changed meanwhile.
            lv_obj_invalidate(lv_scr_act());
        }
    }
    board_unlock();
    return err;
}

esp_err_t board_support_show_message(board_support_t *board, mascot_mood_t mood, const char *title, const char *line1, const char *line2) {
    if (board == NULL || !s_runtime.initialized) {
        return ESP_ERR_INVALID_STATE;
    }
    if (!board_lock(1000)) {
        return ESP_ERR_TIMEOUT;
    }
    board_ui_show_message(mood, title, line1, line2);
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
    board_ui_show_qr(title, subtitle, qr_payload);
    board_unlock();
    return ESP_OK;
}

esp_err_t board_support_show_call(board_support_t *board, const board_call_view_t *view) {
    if (board == NULL || view == NULL || !s_runtime.initialized) {
        return ESP_ERR_INVALID_STATE;
    }
    if (!board_lock(1000)) {
        return ESP_ERR_TIMEOUT;
    }
    board_ui_show_call(view);
    board_unlock();
    return ESP_OK;
}

esp_err_t board_support_show_settings(board_support_t *board, const board_settings_view_t *view) {
    if (board == NULL || view == NULL || !s_runtime.initialized) {
        return ESP_ERR_INVALID_STATE;
    }
    if (!board_lock(1000)) {
        return ESP_ERR_TIMEOUT;
    }
    board_ui_show_settings(view);
    board_unlock();
    return ESP_OK;
}

board_target_t board_support_hit_test(board_support_t *board, uint16_t x, uint16_t y) {
    if (board == NULL || !s_runtime.initialized || !board_lock(1000)) {
        return BOARD_TARGET_NONE;
    }
    const board_target_t target = board_ui_hit_test(x, y);
    board_unlock();
    return target;
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
        uint16_t logical_x = 0;
        uint16_t logical_y = 0;
        board_transform_touch_point(x[0], y[0], &logical_x, &logical_y);
        event->pressed = !s_runtime.touch_down;
        event->x = logical_x;
        event->y = logical_y;
        if (!s_runtime.touch_down) {
            s_runtime.touch_start_x = logical_x;
            s_runtime.touch_start_y = logical_y;
        }
        s_runtime.touch_down = true;
        s_runtime.last_touch_x = logical_x;
        s_runtime.last_touch_y = logical_y;
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
        if (delta_y <= -BOARD_TOUCH_SWIPE_DISTANCE && abs(delta_y) > abs(delta_x)) {
            event->swipe_up = true;
            event->tapped = false;
        } else if (delta_y >= BOARD_TOUCH_SWIPE_DISTANCE && abs(delta_y) > abs(delta_x)) {
            event->swipe_down = true;
            event->tapped = false;
        } else if (delta_x <= -BOARD_TOUCH_SWIPE_DISTANCE && abs(delta_x) > abs(delta_y)) {
            event->swipe_left = true;
            event->tapped = false;
        } else if (delta_x >= BOARD_TOUCH_SWIPE_DISTANCE && abs(delta_x) > abs(delta_y)) {
            event->swipe_right = true;
            event->tapped = false;
        }
        return ESP_OK;
    }

    return ESP_OK;
}

bool board_support_touch_is_active(const board_support_t *board) {
    if (board == NULL || !s_runtime.initialized || s_runtime.touch_handle == NULL) {
        return false;
    }
    return s_runtime.touch_down || gpio_get_level(BOARD_TOUCH_INT) == 0;
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

static bool board_audio_ready(const board_support_t *board) {
    return board != NULL && s_runtime.initialized && s_runtime.codec_handle != NULL;
}

const board_audio_format_t *board_support_audio_format(const board_support_t *board) {
    if (!board_audio_ready(board)) {
        return NULL;
    }
    return &s_runtime.audio_format;
}

esp_err_t board_support_audio_read(board_support_t *board, void *buffer, size_t buffer_size, size_t *bytes_read, int timeout_ms) {
    if (!board_audio_ready(board) || buffer == NULL || bytes_read == NULL) {
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

esp_err_t board_support_audio_write(board_support_t *board, const void *pcm, size_t length, int timeout_ms) {
    if (!board_audio_ready(board) || pcm == NULL) {
        return ESP_ERR_INVALID_ARG;
    }
    if (s_runtime.i2s_tx_chan == NULL) {
        return ESP_ERR_INVALID_STATE;
    }
    const uint8_t *bytes = (const uint8_t *)pcm;
    size_t offset = 0;
    while (offset < length) {
        size_t written = 0;
        const esp_err_t err = i2s_channel_write(
            s_runtime.i2s_tx_chan,
            bytes + offset,
            length - offset,
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

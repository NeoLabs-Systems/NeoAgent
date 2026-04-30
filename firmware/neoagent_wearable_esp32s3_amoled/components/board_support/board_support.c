#include "board_support.h"

#include <assert.h>
#include <string.h>

#include "driver/i2c_master.h"
#include "driver/spi_master.h"
#include "esp_err.h"
#include "esp_io_expander_tca9554.h"
#include "esp_lcd_panel_io.h"
#include "esp_lcd_panel_ops.h"
#include "esp_lcd_panel_vendor.h"
#include "esp_lcd_sh8601.h"
#include "esp_log.h"
#include "esp_timer.h"
#include "freertos/FreeRTOS.h"
#include "freertos/semphr.h"
#include "freertos/task.h"
#include "lvgl.h"
#include "extra/libs/qrcode/lv_qrcode.h"

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

#define BOARD_LCD_H_RES 368
#define BOARD_LCD_V_RES 448
#define BOARD_LCD_BIT_PER_PIXEL 16
#define BOARD_LVGL_BUF_HEIGHT (BOARD_LCD_V_RES / 4)
#define BOARD_LVGL_TICK_PERIOD_MS 2
#define BOARD_LVGL_TASK_STACK_SIZE (4 * 1024)

typedef struct {
    bool initialized;
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

static void board_create_default_screen(void) {
    s_runtime.screen = lv_obj_create(NULL);
    lv_obj_set_style_bg_color(s_runtime.screen, lv_color_hex(0x050816), 0);
    lv_obj_set_style_bg_grad_color(s_runtime.screen, lv_color_hex(0x11335b), 0);
    lv_obj_set_style_bg_grad_dir(s_runtime.screen, LV_GRAD_DIR_VER, 0);
    lv_obj_set_style_border_width(s_runtime.screen, 0, 0);
    lv_obj_set_style_pad_all(s_runtime.screen, 24, 0);

    s_runtime.title_label = lv_label_create(s_runtime.screen);
    lv_obj_set_width(s_runtime.title_label, 320);
    lv_label_set_long_mode(s_runtime.title_label, LV_LABEL_LONG_WRAP);
    lv_obj_set_style_text_color(s_runtime.title_label, lv_color_hex(0xffffff), 0);
    lv_obj_set_style_text_font(s_runtime.title_label, &lv_font_montserrat_16, 0);
    lv_obj_align(s_runtime.title_label, LV_ALIGN_TOP_LEFT, 0, 20);

    s_runtime.line1_label = lv_label_create(s_runtime.screen);
    lv_obj_set_width(s_runtime.line1_label, 320);
    lv_label_set_long_mode(s_runtime.line1_label, LV_LABEL_LONG_WRAP);
    lv_obj_set_style_text_color(s_runtime.line1_label, lv_color_hex(0xd6e5ff), 0);
    lv_obj_set_style_text_font(s_runtime.line1_label, &lv_font_montserrat_16, 0);
    lv_obj_align(s_runtime.line1_label, LV_ALIGN_TOP_LEFT, 0, 110);

    s_runtime.line2_label = lv_label_create(s_runtime.screen);
    lv_obj_set_width(s_runtime.line2_label, 320);
    lv_label_set_long_mode(s_runtime.line2_label, LV_LABEL_LONG_WRAP);
    lv_obj_set_style_text_color(s_runtime.line2_label, lv_color_hex(0x9fb8d8), 0);
    lv_obj_set_style_text_font(s_runtime.line2_label, &lv_font_montserrat_12, 0);
    lv_obj_align(s_runtime.line2_label, LV_ALIGN_TOP_LEFT, 0, 220);

    lv_scr_load(s_runtime.screen);
}

static void board_create_qr_screen(const char *title, const char *subtitle, const char *qr_payload) {
    if (s_runtime.screen != NULL) {
        lv_obj_del(s_runtime.screen);
        s_runtime.screen = NULL;
    }
    lv_obj_t *screen = lv_obj_create(NULL);
    lv_obj_set_style_bg_color(screen, lv_color_hex(0x04101b), 0);
    lv_obj_set_style_bg_grad_color(screen, lv_color_hex(0x12385e), 0);
    lv_obj_set_style_bg_grad_dir(screen, LV_GRAD_DIR_VER, 0);
    lv_obj_set_style_border_width(screen, 0, 0);
    lv_obj_set_style_pad_all(screen, 18, 0);

    lv_obj_t *title_label = lv_label_create(screen);
    lv_obj_set_width(title_label, 332);
    lv_label_set_long_mode(title_label, LV_LABEL_LONG_WRAP);
    lv_obj_set_style_text_color(title_label, lv_color_hex(0xffffff), 0);
    lv_obj_set_style_text_font(title_label, &lv_font_montserrat_16, 0);
    lv_obj_align(title_label, LV_ALIGN_TOP_MID, 0, 10);
    lv_label_set_text(title_label, title != NULL ? title : "Pair Device");

    lv_obj_t *subtitle_label = lv_label_create(screen);
    lv_obj_set_width(subtitle_label, 332);
    lv_label_set_long_mode(subtitle_label, LV_LABEL_LONG_WRAP);
    lv_obj_set_style_text_align(subtitle_label, LV_TEXT_ALIGN_CENTER, 0);
    lv_obj_set_style_text_color(subtitle_label, lv_color_hex(0xcce1ff), 0);
    lv_obj_set_style_text_font(subtitle_label, &lv_font_montserrat_12, 0);
    lv_obj_align(subtitle_label, LV_ALIGN_TOP_MID, 0, 46);
    lv_label_set_text(subtitle_label, subtitle != NULL ? subtitle : "");

    lv_obj_t *qr_frame = lv_obj_create(screen);
    lv_obj_set_size(qr_frame, 192, 192);
    lv_obj_set_style_radius(qr_frame, 26, 0);
    lv_obj_set_style_bg_color(qr_frame, lv_color_hex(0xf6fbff), 0);
    lv_obj_set_style_border_width(qr_frame, 0, 0);
    lv_obj_set_style_pad_all(qr_frame, 12, 0);
    lv_obj_align(qr_frame, LV_ALIGN_CENTER, 0, 24);

    lv_obj_t *qr_code = lv_qrcode_create(qr_frame, 168, lv_color_hex(0x08111c), lv_color_hex(0xf6fbff));
    lv_obj_center(qr_code);
    if (qr_payload != NULL && qr_payload[0] != '\0') {
        lv_qrcode_update(qr_code, qr_payload, strlen(qr_payload));
    }

    lv_obj_t *footer_label = lv_label_create(screen);
    lv_obj_set_width(footer_label, 320);
    lv_label_set_long_mode(footer_label, LV_LABEL_LONG_WRAP);
    lv_obj_set_style_text_align(footer_label, LV_TEXT_ALIGN_CENTER, 0);
    lv_obj_set_style_text_color(footer_label, lv_color_hex(0x9cb8da), 0);
    lv_obj_set_style_text_font(footer_label, &lv_font_montserrat_12, 0);
    lv_obj_align(footer_label, LV_ALIGN_BOTTOM_MID, 0, -16);
    lv_label_set_text(footer_label, "Open NeoAgent on another device and scan this code.");

    s_runtime.screen = screen;
    s_runtime.title_label = title_label;
    s_runtime.line1_label = subtitle_label;
    s_runtime.line2_label = footer_label;
    s_runtime.qr_code = qr_code;
    lv_scr_load(screen);
}

esp_err_t board_support_init(board_support_t *board) {
    if (board == NULL) {
        return ESP_ERR_INVALID_ARG;
    }

    memset(board, 0, sizeof(*board));
    if (s_runtime.initialized) {
        board->display_ready = true;
        board->touch_ready = true;
        board->audio_ready = true;
        return ESP_OK;
    }

    const i2c_master_bus_config_t i2c_config = {
        .clk_source = I2C_CLK_SRC_DEFAULT,
        .i2c_port = BOARD_TOUCH_HOST,
        .sda_io_num = BOARD_TOUCH_SDA,
        .scl_io_num = BOARD_TOUCH_SCL,
        .glitch_ignore_cnt = 7,
        .flags.enable_internal_pullup = true,
    };
    ESP_ERROR_CHECK(i2c_new_master_bus(&i2c_config, &s_runtime.i2c_bus));

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

    lv_init();
    s_runtime.buf1 = heap_caps_malloc(BOARD_LCD_H_RES * BOARD_LVGL_BUF_HEIGHT * sizeof(lv_color_t), MALLOC_CAP_DMA);
    s_runtime.buf2 = heap_caps_malloc(BOARD_LCD_H_RES * BOARD_LVGL_BUF_HEIGHT * sizeof(lv_color_t), MALLOC_CAP_DMA);
    assert(s_runtime.buf1 != NULL && s_runtime.buf2 != NULL);
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
        board_create_default_screen();
        board_unlock();
    }

    s_runtime.initialized = true;
    board->display_ready = true;
    board->touch_ready = false;
    board->audio_ready = true;
    ESP_LOGI(TAG, "display initialized; touch driver pending board-specific FT3168 support");
    return ESP_OK;
}

esp_err_t board_support_show_message(board_support_t *board, const char *title, const char *line1, const char *line2) {
    if (board == NULL || !s_runtime.initialized) {
        return ESP_ERR_INVALID_STATE;
    }
    if (!board_lock(1000)) {
        return ESP_ERR_TIMEOUT;
    }
    lv_label_set_text(s_runtime.title_label, title != NULL ? title : "");
    lv_label_set_text(s_runtime.line1_label, line1 != NULL ? line1 : "");
    lv_label_set_text(s_runtime.line2_label, line2 != NULL ? line2 : "");
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

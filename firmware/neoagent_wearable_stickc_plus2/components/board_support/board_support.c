#include "board_support.h"

#include <stdlib.h>
#include <string.h>
#include "driver/gpio.h"
#include "driver/i2s_pdm.h"
#include "driver/rtc_io.h"
#include "driver/ledc.h"
#include "driver/spi_master.h"
#include "esp_heap_caps.h"
#include "esp_lcd_panel_io.h"
#include "esp_lcd_panel_ops.h"
#include "esp_lcd_panel_vendor.h"
#include "esp_timer.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "lvgl.h"

#define WIDTH 240
#define HEIGHT 135
#define PIN_HOLD 4
#define PIN_BACKLIGHT 27
#define PIN_BUTTON_A 37
#define PIN_BUTTON_B 39
#define PIN_BUTTON_C 35
#define PIN_BUZZER 2
#define PIN_MIC_CLOCK 0
#define PIN_MIC_DATA 34

static esp_lcd_panel_handle_t panel;
static i2s_chan_handle_t mic;
static bool mic_active;
static lv_disp_draw_buf_t draw_buffer;
static lv_disp_drv_t display_driver;
static lv_obj_t *body_viewport;
static esp_timer_handle_t display_timer;
static bool display_awake = true;
static const board_audio_format_t audio_format = {16000, 1, 16};
LV_FONT_DECLARE(neoagent_latin_16);

static bool flush_done(esp_lcd_panel_io_handle_t io, esp_lcd_panel_io_event_data_t *event, void *ctx) {
    (void)io; (void)event;
    lv_disp_flush_ready(ctx);
    return false;
}

static void flush(lv_disp_drv_t *driver, const lv_area_t *area, lv_color_t *pixels) {
    if (esp_lcd_panel_draw_bitmap(panel, area->x1, area->y1, area->x2 + 1, area->y2 + 1, pixels) != ESP_OK) {
        lv_disp_flush_ready(driver);
    }
}

static void lv_tick(void *arg) { (void)arg; lv_tick_inc(5); }

esp_err_t board_support_init(board_support_t *board) {
    gpio_config_t output = { .pin_bit_mask = (1ULL << PIN_HOLD) | (1ULL << PIN_BACKLIGHT), .mode = GPIO_MODE_OUTPUT };
    ESP_ERROR_CHECK(gpio_config(&output));
    gpio_set_level(PIN_HOLD, 1);
    gpio_hold_dis(PIN_HOLD);
    gpio_deep_sleep_hold_dis();
    gpio_set_level(PIN_BACKLIGHT, 0);
    rtc_gpio_deinit(PIN_BUTTON_A);
    gpio_config_t buttons = { .pin_bit_mask = (1ULL << PIN_BUTTON_A) | (1ULL << PIN_BUTTON_B) | (1ULL << PIN_BUTTON_C), .mode = GPIO_MODE_INPUT };
    ESP_ERROR_CHECK(gpio_config(&buttons));
    spi_bus_config_t bus = { .mosi_io_num = 15, .miso_io_num = -1, .sclk_io_num = 13, .quadwp_io_num = -1, .quadhd_io_num = -1, .max_transfer_sz = WIDTH * 20 * 2 };
    ESP_ERROR_CHECK(spi_bus_initialize(SPI2_HOST, &bus, SPI_DMA_CH_AUTO));
    esp_lcd_panel_io_handle_t io;
    esp_lcd_panel_io_spi_config_t io_config = {
        .cs_gpio_num = 5, .dc_gpio_num = 14, .spi_mode = 0, .pclk_hz = 20 * 1000 * 1000,
        .trans_queue_depth = 8, .lcd_cmd_bits = 8, .lcd_param_bits = 8,
        .on_color_trans_done = flush_done, .user_ctx = &display_driver,
    };
    ESP_ERROR_CHECK(esp_lcd_new_panel_io_spi((esp_lcd_spi_bus_handle_t)SPI2_HOST, &io_config, &io));
    esp_lcd_panel_dev_config_t config = { .reset_gpio_num = 12, .rgb_ele_order = LCD_RGB_ELEMENT_ORDER_BGR, .bits_per_pixel = 16 };
    ESP_ERROR_CHECK(esp_lcd_new_panel_st7789(io, &config, &panel));
    ESP_ERROR_CHECK(esp_lcd_panel_reset(panel));
    ESP_ERROR_CHECK(esp_lcd_panel_init(panel));
    ESP_ERROR_CHECK(esp_lcd_panel_swap_xy(panel, true));
    ESP_ERROR_CHECK(esp_lcd_panel_mirror(panel, true, false));
    ESP_ERROR_CHECK(esp_lcd_panel_set_gap(panel, 40, 52));
    ESP_ERROR_CHECK(esp_lcd_panel_invert_color(panel, true));
    ESP_ERROR_CHECK(esp_lcd_panel_disp_on_off(panel, true));
    lv_init();
    lv_color_t *pixels = heap_caps_malloc(WIDTH * 20 * sizeof(*pixels), MALLOC_CAP_DMA);
    if (!pixels) return ESP_ERR_NO_MEM;
    lv_disp_draw_buf_init(&draw_buffer, pixels, NULL, WIDTH * 20);
    lv_disp_drv_init(&display_driver);
    display_driver.hor_res = WIDTH; display_driver.ver_res = HEIGHT;
    display_driver.flush_cb = flush; display_driver.draw_buf = &draw_buffer;
    lv_disp_drv_register(&display_driver);
    esp_timer_create_args_t timer_args = { .callback = lv_tick, .name = "lv_tick" };
    ESP_ERROR_CHECK(esp_timer_create(&timer_args, &display_timer));
    ESP_ERROR_CHECK(esp_timer_start_periodic(display_timer, 5000));
    gpio_set_level(PIN_BACKLIGHT, 1);

    i2s_chan_config_t channel = I2S_CHANNEL_DEFAULT_CONFIG(I2S_NUM_0, I2S_ROLE_MASTER);
    ESP_ERROR_CHECK(i2s_new_channel(&channel, NULL, &mic));
    i2s_pdm_rx_config_t pdm = {
        .clk_cfg = I2S_PDM_RX_CLK_DEFAULT_CONFIG(16000),
        .slot_cfg = I2S_PDM_RX_SLOT_DEFAULT_CONFIG(I2S_DATA_BIT_WIDTH_16BIT, I2S_SLOT_MODE_MONO),
        .gpio_cfg = { .clk = PIN_MIC_CLOCK, .din = PIN_MIC_DATA },
    };
    ESP_ERROR_CHECK(i2s_channel_init_pdm_rx_mode(mic, &pdm));
    ledc_timer_config_t buzzer_timer = { .speed_mode = LEDC_LOW_SPEED_MODE, .timer_num = LEDC_TIMER_1, .duty_resolution = LEDC_TIMER_10_BIT, .freq_hz = 2400, .clk_cfg = LEDC_AUTO_CLK };
    ESP_ERROR_CHECK(ledc_timer_config(&buzzer_timer));
    ledc_channel_config_t buzzer = { .gpio_num = PIN_BUZZER, .speed_mode = LEDC_LOW_SPEED_MODE, .channel = LEDC_CHANNEL_1, .timer_sel = LEDC_TIMER_1, .duty = 0 };
    ESP_ERROR_CHECK(ledc_channel_config(&buzzer));
    board->audio_ready = true;
    return ESP_OK;
}

const board_audio_format_t *board_support_audio_format(const board_support_t *board) { return board->audio_ready ? &audio_format : NULL; }
esp_err_t board_microphone_active(bool active) {
    if (active == mic_active) return ESP_OK;
    esp_err_t result = active ? i2s_channel_enable(mic) : i2s_channel_disable(mic);
    if (result == ESP_OK) mic_active = active;
    return result;
}
esp_err_t board_support_audio_read(board_support_t *board, void *buffer, size_t size, size_t *read, int timeout_ms) {
    (void)board;
    return i2s_channel_read(mic, buffer, size, read, timeout_ms);
}
esp_err_t board_support_audio_write(board_support_t *board, const void *buffer, size_t size, int timeout_ms) {
    (void)board; (void)buffer; (void)size; (void)timeout_ms;
    return ESP_OK;
}

static lv_obj_t *new_screen(void) {
    lv_obj_t *screen = lv_scr_act();
    lv_obj_clean(screen);
    lv_obj_scroll_to(screen, 0, 0, LV_ANIM_OFF);
    lv_obj_clear_flag(screen, LV_OBJ_FLAG_SCROLLABLE);
    lv_obj_set_style_bg_color(screen, lv_color_hex(0x0d151c), 0);
    lv_obj_set_style_text_color(screen, lv_color_hex(0xf2f4ed), 0);
    lv_obj_set_style_text_font(screen, &neoagent_latin_16, 0);
    body_viewport = NULL;
    return screen;
}

void board_display_message(const char *title, const char *body) {
    lv_obj_t *screen = new_screen();
    lv_obj_t *heading = lv_label_create(screen);
    lv_obj_set_width(heading, WIDTH - 12);
    lv_obj_set_style_text_color(heading, lv_color_hex(0xd8b06b), 0);
    lv_label_set_long_mode(heading, LV_LABEL_LONG_WRAP);
    lv_label_set_text(heading, title);
    lv_obj_align(heading, LV_ALIGN_TOP_LEFT, 6, 8);
    body_viewport = lv_obj_create(screen);
    lv_obj_remove_style_all(body_viewport);
    lv_obj_set_size(body_viewport, WIDTH - 12, HEIGHT - 34);
    lv_obj_align(body_viewport, LV_ALIGN_TOP_LEFT, 6, 30);
    lv_obj_set_scroll_dir(body_viewport, LV_DIR_VER);
    lv_obj_set_scrollbar_mode(body_viewport, LV_SCROLLBAR_MODE_AUTO);
    lv_obj_t *body_label = lv_label_create(body_viewport);
    lv_obj_set_width(body_label, WIDTH - 12);
    lv_label_set_long_mode(body_label, LV_LABEL_LONG_WRAP);
    lv_label_set_text(body_label, body);
    lv_obj_update_layout(body_viewport);
}

void board_display_idle(bool connected) {
    lv_obj_t *screen = new_screen();
    lv_obj_t *circle = lv_obj_create(screen);
    lv_obj_set_size(circle, 66, 66);
    lv_obj_align(circle, LV_ALIGN_LEFT_MID, 13, -2);
    lv_obj_set_style_radius(circle, LV_RADIUS_CIRCLE, 0);
    lv_obj_set_style_bg_color(circle, lv_color_hex(0x1d3030), 0);
    lv_obj_set_style_border_color(circle, lv_color_hex(0xd8b06b), 0);
    lv_obj_set_style_border_width(circle, 2, 0);
    lv_obj_clear_flag(circle, LV_OBJ_FLAG_SCROLLABLE);
    lv_obj_t *button = lv_label_create(circle);
    lv_label_set_text(button, "A");
    lv_obj_set_style_text_color(button, lv_color_hex(0xd8b06b), 0);
    lv_obj_center(button);
    lv_obj_t *brand = lv_label_create(screen);
    lv_label_set_text(brand, "NeoAgent");
    lv_obj_set_style_text_color(brand, lv_color_hex(0xd8b06b), 0);
    lv_obj_align(brand, LV_ALIGN_TOP_LEFT, 94, 13);
    lv_obj_t *action = lv_label_create(screen);
    lv_obj_set_width(action, 140);
    lv_label_set_long_mode(action, LV_LABEL_LONG_WRAP);
    lv_label_set_text(action, connected ? "Hold A to talk" : "Connecting...");
    lv_obj_align(action, LV_ALIGN_TOP_LEFT, 94, 43);
    lv_obj_t *hint = lv_label_create(screen);
    lv_obj_set_width(hint, WIDTH - 16);
    lv_obj_set_style_text_color(hint, lv_color_hex(0x9aaea9), 0);
    lv_label_set_text(hint, "B/C scroll  |  Hold B: setup");
    lv_obj_align(hint, LV_ALIGN_BOTTOM_LEFT, 8, -5);
}

esp_err_t board_display_qr(const char *title, const char *payload) {
    lv_obj_t *screen = new_screen();
    lv_obj_t *label = lv_label_create(screen);
    lv_label_set_text(label, title);
    lv_obj_set_width(label, WIDTH - HEIGHT - 10);
    lv_label_set_long_mode(label, LV_LABEL_LONG_WRAP);
    lv_obj_align(label, LV_ALIGN_TOP_LEFT, HEIGHT + 5, 12);
    lv_obj_t *frame = lv_obj_create(screen);
    lv_obj_set_size(frame, 135, 135);
    lv_obj_set_style_bg_color(frame, lv_color_white(), 0);
    lv_obj_set_style_border_width(frame, 0, 0);
    lv_obj_set_style_radius(frame, 0, 0);
    lv_obj_set_style_pad_all(frame, 0, 0);
    lv_obj_clear_flag(frame, LV_OBJ_FLAG_SCROLLABLE);
    lv_obj_align(frame, LV_ALIGN_LEFT_MID, 0, 0);
    lv_obj_t *qr = lv_qrcode_create(frame, 120, lv_color_black(), lv_color_white());
    if (!qr || lv_qrcode_update(qr, payload, strlen(payload)) != LV_RES_OK) return ESP_FAIL;
    lv_obj_align(qr, LV_ALIGN_CENTER, 0, 0);
    label = lv_label_create(screen);
    lv_obj_set_width(label, WIDTH - HEIGHT - 10);
    lv_label_set_long_mode(label, LV_LABEL_LONG_WRAP);
    lv_label_set_text(label, "Scan with NeoAgent");
    lv_obj_align(label, LV_ALIGN_LEFT_MID, HEIGHT + 5, 13);
    return ESP_OK;
}

void board_display_scroll(int direction) {
    if (!body_viewport) return;
    lv_obj_update_layout(body_viewport);
    lv_obj_scroll_by_bounded(body_viewport, 0, direction > 0 ? -80 : 80, LV_ANIM_OFF);
}
void board_display_awake(bool awake) {
    if (awake == display_awake) return;
    display_awake = awake;
    gpio_set_level(PIN_BACKLIGHT, awake ? 1 : 0);
    if (awake) ESP_ERROR_CHECK(esp_timer_start_periodic(display_timer, 5000));
    else ESP_ERROR_CHECK(esp_timer_stop(display_timer));
}
void board_display_tick(void) { if (display_awake) lv_timer_handler(); }
void board_beep(void) {
    ledc_set_duty(LEDC_LOW_SPEED_MODE, LEDC_CHANNEL_1, 512);
    ledc_update_duty(LEDC_LOW_SPEED_MODE, LEDC_CHANNEL_1);
    vTaskDelay(pdMS_TO_TICKS(120));
    ledc_set_duty(LEDC_LOW_SPEED_MODE, LEDC_CHANNEL_1, 0);
    ledc_update_duty(LEDC_LOW_SPEED_MODE, LEDC_CHANNEL_1);
}
bool board_button_a(void) { return gpio_get_level(PIN_BUTTON_A) == 0; }
bool board_button_b(void) { return gpio_get_level(PIN_BUTTON_B) == 0; }
bool board_button_c(void) { return gpio_get_level(PIN_BUTTON_C) == 0; }

esp_err_t board_prepare_deep_sleep(void) {
    board_display_awake(false);
    esp_err_t result = esp_lcd_panel_disp_on_off(panel, false);
    if (result != ESP_OK) return result;
    result = esp_lcd_panel_disp_sleep(panel, true);
    if (result != ESP_OK) return result;
    result = gpio_hold_en(PIN_HOLD);
    if (result == ESP_OK) gpio_deep_sleep_hold_en();
    return result;
}

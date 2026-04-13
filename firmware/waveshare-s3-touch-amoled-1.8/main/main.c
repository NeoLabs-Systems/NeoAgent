#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "esp_event.h"
#include "esp_check.h"
#include "esp_http_client.h"
#include "esp_http_server.h"
#include "esp_lcd_panel_io.h"
#include "esp_lcd_panel_ops.h"
#include "esp_log.h"
#include "esp_mac.h"
#include "esp_netif.h"
#include "esp_system.h"
#include "esp_wifi.h"
#include "driver/gpio.h"
#include "driver/i2c.h"
#include "driver/i2s_std.h"
#include "driver/spi_master.h"
#include "freertos/FreeRTOS.h"
#include "freertos/event_groups.h"
#include "freertos/task.h"
#include "nvs.h"
#include "nvs_flash.h"
#include "cJSON.h"

#define MAX_WIFI_PROFILES 5
#define MAX_STR_64 64
#define MAX_STR_128 128
#define MAX_STR_256 256
#define MAX_POST_BODY 3072

#define WIFI_CONNECTED_BIT BIT0
#define WIFI_FAIL_BIT BIT1

#define BOOT_BUTTON_GPIO GPIO_NUM_0
#define BOOT_LONG_PRESS_MS 4500
#define RECORD_HOLD_MS 600
#define BUTTON_POLL_MS 50

#define LCD_HOST SPI2_HOST
#define LCD_WIDTH 368
#define LCD_HEIGHT 448
#define LCD_PIN_CS GPIO_NUM_12
#define LCD_PIN_PCLK GPIO_NUM_11
#define LCD_PIN_D0 GPIO_NUM_4
#define LCD_PIN_D1 GPIO_NUM_5
#define LCD_PIN_D2 GPIO_NUM_6
#define LCD_PIN_D3 GPIO_NUM_7

#define I2C_PORT I2C_NUM_0
#define I2C_SDA GPIO_NUM_15
#define I2C_SCL GPIO_NUM_14
#define ES8311_ADDR 0x18
#define AUDIO_PA_PIN ((gpio_num_t)46)

#define I2S_SAMPLE_RATE 16000
#define I2S_BCLK ((gpio_num_t)9)
#define I2S_WS ((gpio_num_t)45)
#define I2S_DOUT ((gpio_num_t)8)
#define I2S_DIN ((gpio_num_t)10)
#define I2S_MCLK ((gpio_num_t)16)

#define RESPONSE_CARD_COUNT 5
#define RESPONSE_CARD_CHARS 200

#define LCD_OPCODE_WRITE_CMD (0x02ULL)
#define LCD_OPCODE_WRITE_COLOR (0x32ULL)

static const char *TAG = "waveshare_amoled";

static EventGroupHandle_t s_wifi_event_group;
static int s_retry_num = 0;
static esp_netif_t *s_sta_netif = NULL;
static esp_netif_t *s_ap_netif = NULL;
static httpd_handle_t s_httpd = NULL;
static bool s_recording = false;
static int s_recording_chunks_sent = 0;
static esp_lcd_panel_io_handle_t s_lcd_io = NULL;
static bool s_display_ready = false;
static i2s_chan_handle_t s_i2s_rx_chan = NULL;
static bool s_audio_ready = false;

typedef struct {
  char text[RESPONSE_CARD_CHARS + 1];
} response_card_t;

static response_card_t s_response_cards[RESPONSE_CARD_COUNT];
static int s_response_count = 0;

typedef struct {
  char ssid[MAX_STR_64 + 1];
  char password[MAX_STR_64 + 1];
} wifi_profile_t;

typedef struct {
  char backend_url[MAX_STR_256 + 1];
  char pairing_code[MAX_STR_64 + 1];
  char device_token[MAX_STR_256 + 1];
  char device_id[MAX_STR_128 + 1];
  char device_name[MAX_STR_128 + 1];
  char mac_address[MAX_STR_64 + 1];
  int wifi_count;
  wifi_profile_t wifi[MAX_WIFI_PROFILES];
} device_config_t;

static device_config_t s_cfg;

static const char *HTML_FORM =
    "<!doctype html><html><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'>"
  "<title>NeoOS Wearable Setup</title><style>"
    "body{font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif;background:#f5f7fb;margin:0;padding:20px;color:#10243b}"
    "main{max-width:760px;margin:auto;background:#fff;border-radius:16px;padding:20px;box-shadow:0 8px 24px rgba(0,0,0,.08)}"
    "h1{margin:0 0 8px}p{color:#3f5572}label{display:block;margin-top:12px;font-weight:600}"
    "input{width:100%;padding:10px;border:1px solid #cfd7e3;border-radius:10px;margin-top:6px}"
    "button{margin-top:18px;padding:12px 18px;border:none;border-radius:10px;background:#0b65d7;color:#fff;font-weight:700;cursor:pointer}"
    "small{display:block;color:#637b99;margin-top:6px}"
    "</style></head><body><main>"
    "<h1>NeoOS Wearable Setup</h1>"
    "<p>Configure backend URL, pairing code, and up to five Wi-Fi profiles.</p>"
    "<form method='post' action='/save'>"
    "<label>Backend URL<input name='backend_url' placeholder='https://your-neoagent.example.com' required /></label>"
    "<label>Device Name<input name='device_name' placeholder='NeoOS Wearable' /></label>"
    "<label>Pairing Code<input name='pairing_code' placeholder='Code from NeoAgent app' required /></label>"
    "<label>Wi-Fi 1 SSID<input name='ssid1' required /></label>"
    "<label>Wi-Fi 1 Password<input name='pass1' type='password' /></label>"
    "<label>Wi-Fi 2 SSID (optional)<input name='ssid2' /></label>"
    "<label>Wi-Fi 2 Password<input name='pass2' type='password' /></label>"
    "<label>Wi-Fi 3 SSID (optional)<input name='ssid3' /></label>"
    "<label>Wi-Fi 3 Password<input name='pass3' type='password' /></label>"
    "<label>Wi-Fi 4 SSID (optional)<input name='ssid4' /></label>"
    "<label>Wi-Fi 4 Password<input name='pass4' type='password' /></label>"
    "<label>Wi-Fi 5 SSID (optional)<input name='ssid5' /></label>"
    "<label>Wi-Fi 5 Password<input name='pass5' type='password' /></label>"
    "<button type='submit'>Save and Reboot</button>"
    "</form><small>Hold BOOT for 4.5s while running to reset setup mode.</small>"
    "</main></body></html>";

static void trim_in_place(char *s) {
  char *start = s;
  while (*start && isspace((unsigned char)*start)) start++;
  if (start != s) memmove(s, start, strlen(start) + 1);
  size_t n = strlen(s);
  while (n > 0 && isspace((unsigned char)s[n - 1])) {
    s[n - 1] = '\0';
    n--;
  }
}

static void url_decode(char *dst, size_t dst_len, const char *src) {
  size_t di = 0;
  for (size_t i = 0; src[i] != '\0' && di + 1 < dst_len; i++) {
    if (src[i] == '+') {
      dst[di++] = ' ';
      continue;
    }
    if (src[i] == '%' && isxdigit((unsigned char)src[i + 1]) && isxdigit((unsigned char)src[i + 2])) {
      char hex[3] = {src[i + 1], src[i + 2], '\0'};
      dst[di++] = (char)strtol(hex, NULL, 16);
      i += 2;
      continue;
    }
    dst[di++] = src[i];
  }
  dst[di] = '\0';
}

static bool parse_form_value(const char *body, const char *key, char *out, size_t out_len) {
  if (!body || !key || !out || out_len == 0) return false;
  char needle[64];
  snprintf(needle, sizeof(needle), "%s=", key);
  const char *start = strstr(body, needle);
  if (!start) {
    out[0] = '\0';
    return false;
  }
  start += strlen(needle);
  const char *end = strchr(start, '&');
  size_t raw_len = end ? (size_t)(end - start) : strlen(start);
  char raw[512];
  if (raw_len >= sizeof(raw)) raw_len = sizeof(raw) - 1;
  memcpy(raw, start, raw_len);
  raw[raw_len] = '\0';
  url_decode(out, out_len, raw);
  trim_in_place(out);
  return out[0] != '\0';
}

static esp_err_t lcd_tx_param(uint8_t cmd, const void *param, size_t param_size) {
  if (!s_lcd_io) return ESP_FAIL;
  uint32_t qspi_cmd = ((uint32_t)LCD_OPCODE_WRITE_CMD << 24) | ((uint32_t)cmd << 8);
  return esp_lcd_panel_io_tx_param(s_lcd_io, qspi_cmd, param, param_size);
}

static esp_err_t lcd_tx_color(uint8_t cmd, const void *data, size_t len) {
  if (!s_lcd_io) return ESP_FAIL;
  uint32_t qspi_cmd = ((uint32_t)LCD_OPCODE_WRITE_COLOR << 24) | ((uint32_t)cmd << 8);
  return esp_lcd_panel_io_tx_color(s_lcd_io, qspi_cmd, data, len);
}

static esp_err_t lcd_draw_bitmap(int x_start, int y_start, int x_end, int y_end, const uint16_t *pixels) {
  uint8_t xs[4] = {(uint8_t)((x_start >> 8) & 0xFF), (uint8_t)(x_start & 0xFF), (uint8_t)(((x_end - 1) >> 8) & 0xFF), (uint8_t)((x_end - 1) & 0xFF)};
  uint8_t ys[4] = {(uint8_t)((y_start >> 8) & 0xFF), (uint8_t)(y_start & 0xFF), (uint8_t)(((y_end - 1) >> 8) & 0xFF), (uint8_t)((y_end - 1) & 0xFF)};
  ESP_RETURN_ON_ERROR(lcd_tx_param(0x2A, xs, sizeof(xs)), TAG, "lcd CASET failed");
  ESP_RETURN_ON_ERROR(lcd_tx_param(0x2B, ys, sizeof(ys)), TAG, "lcd RASET failed");
  return lcd_tx_color(0x2C, pixels, (size_t)(x_end - x_start) * (size_t)(y_end - y_start) * sizeof(uint16_t));
}

static inline uint16_t rgb565(uint8_t r, uint8_t g, uint8_t b) {
  return (uint16_t)(((r & 0xF8) << 8) | ((g & 0xFC) << 3) | (b >> 3));
}

static void lcd_fill_rect(int x, int y, int w, int h, uint16_t color) {
  if (!s_display_ready || w <= 0 || h <= 0) return;
  if (x < 0) {
    w += x;
    x = 0;
  }
  if (y < 0) {
    h += y;
    y = 0;
  }
  if (x + w > LCD_WIDTH) w = LCD_WIDTH - x;
  if (y + h > LCD_HEIGHT) h = LCD_HEIGHT - y;
  if (w <= 0 || h <= 0) return;

  uint16_t row[LCD_WIDTH];
  for (int i = 0; i < w; i++) row[i] = color;
  for (int yy = y; yy < y + h; yy++) {
    lcd_draw_bitmap(x, yy, x + w, yy + 1, row);
  }
}

static void glyph_3x5(char in, uint8_t out[5]) {
  char c = (char)toupper((unsigned char)in);
  memset(out, 0, 5);
  switch (c) {
    case 'A': out[0]=2; out[1]=5; out[2]=7; out[3]=5; out[4]=5; break;
    case 'B': out[0]=6; out[1]=5; out[2]=6; out[3]=5; out[4]=6; break;
    case 'C': out[0]=3; out[1]=4; out[2]=4; out[3]=4; out[4]=3; break;
    case 'D': out[0]=6; out[1]=5; out[2]=5; out[3]=5; out[4]=6; break;
    case 'E': out[0]=7; out[1]=4; out[2]=6; out[3]=4; out[4]=7; break;
    case 'F': out[0]=7; out[1]=4; out[2]=6; out[3]=4; out[4]=4; break;
    case 'G': out[0]=3; out[1]=4; out[2]=5; out[3]=5; out[4]=3; break;
    case 'H': out[0]=5; out[1]=5; out[2]=7; out[3]=5; out[4]=5; break;
    case 'I': out[0]=7; out[1]=2; out[2]=2; out[3]=2; out[4]=7; break;
    case 'J': out[0]=1; out[1]=1; out[2]=1; out[3]=5; out[4]=2; break;
    case 'K': out[0]=5; out[1]=5; out[2]=6; out[3]=5; out[4]=5; break;
    case 'L': out[0]=4; out[1]=4; out[2]=4; out[3]=4; out[4]=7; break;
    case 'M': out[0]=5; out[1]=7; out[2]=7; out[3]=5; out[4]=5; break;
    case 'N': out[0]=5; out[1]=7; out[2]=7; out[3]=7; out[4]=5; break;
    case 'O': out[0]=2; out[1]=5; out[2]=5; out[3]=5; out[4]=2; break;
    case 'P': out[0]=6; out[1]=5; out[2]=6; out[3]=4; out[4]=4; break;
    case 'Q': out[0]=2; out[1]=5; out[2]=5; out[3]=2; out[4]=1; break;
    case 'R': out[0]=6; out[1]=5; out[2]=6; out[3]=5; out[4]=5; break;
    case 'S': out[0]=3; out[1]=4; out[2]=2; out[3]=1; out[4]=6; break;
    case 'T': out[0]=7; out[1]=2; out[2]=2; out[3]=2; out[4]=2; break;
    case 'U': out[0]=5; out[1]=5; out[2]=5; out[3]=5; out[4]=7; break;
    case 'V': out[0]=5; out[1]=5; out[2]=5; out[3]=5; out[4]=2; break;
    case 'W': out[0]=5; out[1]=5; out[2]=7; out[3]=7; out[4]=5; break;
    case 'X': out[0]=5; out[1]=5; out[2]=2; out[3]=5; out[4]=5; break;
    case 'Y': out[0]=5; out[1]=5; out[2]=2; out[3]=2; out[4]=2; break;
    case 'Z': out[0]=7; out[1]=1; out[2]=2; out[3]=4; out[4]=7; break;
    case '0': out[0]=7; out[1]=5; out[2]=5; out[3]=5; out[4]=7; break;
    case '1': out[0]=2; out[1]=6; out[2]=2; out[3]=2; out[4]=7; break;
    case '2': out[0]=7; out[1]=1; out[2]=7; out[3]=4; out[4]=7; break;
    case '3': out[0]=7; out[1]=1; out[2]=7; out[3]=1; out[4]=7; break;
    case '4': out[0]=5; out[1]=5; out[2]=7; out[3]=1; out[4]=1; break;
    case '5': out[0]=7; out[1]=4; out[2]=7; out[3]=1; out[4]=7; break;
    case '6': out[0]=7; out[1]=4; out[2]=7; out[3]=5; out[4]=7; break;
    case '7': out[0]=7; out[1]=1; out[2]=1; out[3]=1; out[4]=1; break;
    case '8': out[0]=7; out[1]=5; out[2]=7; out[3]=5; out[4]=7; break;
    case '9': out[0]=7; out[1]=5; out[2]=7; out[3]=1; out[4]=7; break;
    case '.': out[4]=2; break;
    case ',': out[3]=2; out[4]=4; break;
    case ':': out[1]=2; out[3]=2; break;
    case '-': out[2]=7; break;
    case '/': out[0]=1; out[1]=1; out[2]=2; out[3]=4; out[4]=4; break;
    case ' ': break;
    default: out[0]=7; out[1]=1; out[2]=2; out[3]=0; out[4]=2; break;
  }
}

static void lcd_draw_char3x5(int x, int y, char c, uint16_t fg, uint16_t bg, int scale) {
  uint8_t rows[5];
  glyph_3x5(c, rows);
  for (int ry = 0; ry < 5; ry++) {
    for (int rx = 0; rx < 3; rx++) {
      const bool on = (rows[ry] >> (2 - rx)) & 0x01;
      lcd_fill_rect(x + rx * scale, y + ry * scale, scale, scale, on ? fg : bg);
    }
  }
}

static void lcd_draw_text_block(int x, int y, int w, const char *text, uint16_t fg, uint16_t bg, int scale, int max_lines) {
  const int char_w = 4 * scale;
  const int char_h = 6 * scale;
  const int max_cols = w / char_w;
  if (max_cols <= 0) return;

  int col = 0;
  int line = 0;
  for (size_t i = 0; text && text[i] != '\0'; i++) {
    char c = text[i];
    if (c == '\n' || col >= max_cols) {
      line++;
      col = 0;
      if (line >= max_lines) break;
      if (c == '\n') continue;
    }
    lcd_draw_char3x5(x + col * char_w, y + line * char_h, c, fg, bg, scale);
    col++;
  }
}

static void lcd_draw_text_centered(int y, const char *text, uint16_t fg, uint16_t bg, int scale) {
  if (!text) return;
  const int char_w = 4 * scale;
  int text_w = (int)strlen(text) * char_w;
  if (text_w <= 0) return;
  int x = (LCD_WIDTH - text_w) / 2;
  if (x < 4) x = 4;
  lcd_draw_text_block(x, y, LCD_WIDTH - (x * 2), text, fg, bg, scale, 1);
}

static void run_neoos_boot_animation(void) {
  if (!s_display_ready) return;

  const uint16_t base_bg = rgb565(7, 11, 20);
  const uint16_t stripe_a = rgb565(18, 38, 72);
  const uint16_t stripe_b = rgb565(22, 88, 176);
  const uint16_t text_primary = rgb565(233, 245, 255);
  const uint16_t text_muted = rgb565(145, 190, 235);
  const uint16_t bar_bg = rgb565(16, 28, 44);

  for (int frame = 0; frame < 26; frame++) {
    const int progress_w = ((LCD_WIDTH - 80) * (frame + 1)) / 26;
    const uint8_t pulse = (uint8_t)(160 + ((frame % 6) * 12));
    const uint16_t pulse_color = rgb565(40, 120, pulse);

    lcd_fill_rect(0, 0, LCD_WIDTH, LCD_HEIGHT, base_bg);

    for (int i = 0; i < 8; i++) {
      int x = (frame * 17 + i * 53) % LCD_WIDTH;
      lcd_fill_rect(x, 0, 28, 4, stripe_a);
      lcd_fill_rect((x + 19) % LCD_WIDTH, LCD_HEIGHT - 4, 24, 4, stripe_b);
    }

    lcd_fill_rect(24, 102, LCD_WIDTH - 48, 112, rgb565(10, 20, 33));
    lcd_fill_rect(24, 102, LCD_WIDTH - 48, 3, stripe_b);
    lcd_fill_rect(24, 211, LCD_WIDTH - 48, 3, stripe_a);

    lcd_draw_text_centered(126, "NEOOS", text_primary, rgb565(10, 20, 33), 5);
    lcd_draw_text_centered(170, "WEARABLE RUNTIME", text_muted, rgb565(10, 20, 33), 2);

    lcd_fill_rect(40, 252, LCD_WIDTH - 80, 18, bar_bg);
    lcd_fill_rect(40, 252, progress_w, 18, pulse_color);

    char stage[32];
    snprintf(stage, sizeof(stage), "BOOT %d%%", (frame + 1) * 100 / 26);
    lcd_draw_text_centered(278, stage, text_muted, base_bg, 2);
    vTaskDelay(pdMS_TO_TICKS(38));
  }

  lcd_draw_text_centered(306, "SYSTEM READY", rgb565(173, 229, 255), base_bg, 2);
  vTaskDelay(pdMS_TO_TICKS(260));
}

static void render_response_cards(void) {
  if (!s_display_ready) return;

  const uint16_t bg = rgb565(8, 14, 26);
  const uint16_t bar = rgb565(26, 94, 180);
  const uint16_t card = rgb565(22, 34, 54);
  const uint16_t border = rgb565(60, 94, 130);
  const uint16_t text = rgb565(236, 244, 255);

  lcd_fill_rect(0, 0, LCD_WIDTH, LCD_HEIGHT, bg);
  lcd_fill_rect(0, 0, LCD_WIDTH, 34, bar);
  lcd_draw_text_block(8, 8, LCD_WIDTH - 16, "NEOOS RESPONSES", text, bar, 2, 1);

  const int card_h = 76;
  const int top = 42;
  for (int i = 0; i < s_response_count && i < 5; i++) {
    int y = top + i * (card_h + 6);
    lcd_fill_rect(8, y, LCD_WIDTH - 16, card_h, card);
    lcd_fill_rect(8, y, LCD_WIDTH - 16, 2, border);
    char label[24];
    snprintf(label, sizeof(label), "CARD %d", i + 1);
    lcd_draw_text_block(14, y + 8, 92, label, rgb565(153, 208, 255), card, 2, 1);
    lcd_draw_text_block(14, y + 26, LCD_WIDTH - 28, s_response_cards[i].text, text, card, 2, 3);
  }

  if (s_response_count == 0) {
    lcd_draw_text_block(12, 64, LCD_WIDTH - 24, "WAITING FOR RESPONSES...", text, bg, 2, 2);
  }
}

static void push_response_card(const char *text) {
  if (!text || text[0] == '\0') return;
  for (int i = RESPONSE_CARD_COUNT - 1; i > 0; i--) {
    memcpy(&s_response_cards[i], &s_response_cards[i - 1], sizeof(response_card_t));
  }
  strncpy(s_response_cards[0].text, text, RESPONSE_CARD_CHARS);
  s_response_cards[0].text[RESPONSE_CARD_CHARS] = '\0';
  if (s_response_count < RESPONSE_CARD_COUNT) s_response_count++;
  render_response_cards();
}

static bool init_display(void) {
  const spi_bus_config_t buscfg = {
      .sclk_io_num = LCD_PIN_PCLK,
      .data0_io_num = LCD_PIN_D0,
      .data1_io_num = LCD_PIN_D1,
      .data2_io_num = LCD_PIN_D2,
      .data3_io_num = LCD_PIN_D3,
      .max_transfer_sz = LCD_WIDTH * 80 * sizeof(uint16_t),
  };

  if (spi_bus_initialize(LCD_HOST, &buscfg, SPI_DMA_CH_AUTO) != ESP_OK) {
    ESP_LOGW(TAG, "Display bus init failed");
    return false;
  }

  esp_lcd_panel_io_spi_config_t io_cfg = {
      .cs_gpio_num = LCD_PIN_CS,
      .dc_gpio_num = -1,
      .spi_mode = 0,
      .pclk_hz = 40 * 1000 * 1000,
      .trans_queue_depth = 10,
      .on_color_trans_done = NULL,
      .user_ctx = NULL,
      .lcd_cmd_bits = 32,
      .lcd_param_bits = 8,
      .flags = {
          .quad_mode = 1,
      },
  };

  if (esp_lcd_new_panel_io_spi((esp_lcd_spi_bus_handle_t)LCD_HOST, &io_cfg, &s_lcd_io) != ESP_OK || !s_lcd_io) {
    ESP_LOGW(TAG, "Display panel IO init failed");
    return false;
  }

  lcd_tx_param(0x11, NULL, 0);
  vTaskDelay(pdMS_TO_TICKS(120));
  uint8_t cmd44[2] = {0x01, 0xD1};
  uint8_t cmd35[1] = {0x00};
  uint8_t cmd53[1] = {0x20};
  uint8_t cmd36[1] = {0x00};
  uint8_t cmd3a[1] = {0x55};
  uint8_t cmd51[1] = {0xCF};
  lcd_tx_param(0x44, cmd44, sizeof(cmd44));
  lcd_tx_param(0x35, cmd35, sizeof(cmd35));
  lcd_tx_param(0x53, cmd53, sizeof(cmd53));
  lcd_tx_param(0x36, cmd36, sizeof(cmd36));
  lcd_tx_param(0x3A, cmd3a, sizeof(cmd3a));
  lcd_tx_param(0x51, cmd51, sizeof(cmd51));
  lcd_tx_param(0x29, NULL, 0);

  s_display_ready = true;
  render_response_cards();
  ESP_LOGI(TAG, "Display initialized (%dx%d)", LCD_WIDTH, LCD_HEIGHT);
  return true;
}

static esp_err_t es8311_write_reg(uint8_t reg, uint8_t value) {
  uint8_t data[2] = {reg, value};
  return i2c_master_write_to_device(I2C_PORT, ES8311_ADDR, data, sizeof(data), pdMS_TO_TICKS(80));
}

static bool init_audio_capture(void) {
  i2c_config_t i2c_cfg = {
      .mode = I2C_MODE_MASTER,
      .sda_io_num = I2C_SDA,
      .scl_io_num = I2C_SCL,
      .sda_pullup_en = GPIO_PULLUP_ENABLE,
      .scl_pullup_en = GPIO_PULLUP_ENABLE,
      .master.clk_speed = 100000,
  };
  if (i2c_param_config(I2C_PORT, &i2c_cfg) == ESP_OK) {
    i2c_driver_install(I2C_PORT, I2C_MODE_MASTER, 0, 0, 0);
  }

  gpio_set_direction(AUDIO_PA_PIN, GPIO_MODE_OUTPUT);
  gpio_set_level(AUDIO_PA_PIN, 1);

  // Minimal codec wake + ADC path enable sequence used by ES8311-based wearable demos.
  es8311_write_reg(0x00, 0x1F);
  es8311_write_reg(0x00, 0x80);
  es8311_write_reg(0x00, 0x00);
  es8311_write_reg(0x01, 0x30);
  es8311_write_reg(0x02, 0x00);
  es8311_write_reg(0x03, 0x10);
  es8311_write_reg(0x16, 0x24);
  es8311_write_reg(0x17, 0x18);
  es8311_write_reg(0x18, 0x02);

  i2s_chan_config_t chan_cfg = I2S_CHANNEL_DEFAULT_CONFIG(I2S_NUM_0, I2S_ROLE_MASTER);
  if (i2s_new_channel(&chan_cfg, NULL, &s_i2s_rx_chan) != ESP_OK || !s_i2s_rx_chan) {
    ESP_LOGW(TAG, "I2S channel alloc failed");
    return false;
  }

  i2s_std_config_t std_cfg = {
      .clk_cfg = I2S_STD_CLK_DEFAULT_CONFIG(I2S_SAMPLE_RATE),
      .slot_cfg = I2S_STD_MSB_SLOT_DEFAULT_CONFIG(I2S_DATA_BIT_WIDTH_16BIT, I2S_SLOT_MODE_MONO),
      .gpio_cfg = {
          .mclk = I2S_MCLK,
          .bclk = I2S_BCLK,
          .ws = I2S_WS,
          .dout = I2S_DOUT,
          .din = I2S_DIN,
          .invert_flags = {
              .mclk_inv = false,
              .bclk_inv = false,
              .ws_inv = false,
          },
      },
  };

  if (i2s_channel_init_std_mode(s_i2s_rx_chan, &std_cfg) != ESP_OK) {
    ESP_LOGW(TAG, "I2S std init failed");
    return false;
  }
  if (i2s_channel_enable(s_i2s_rx_chan) != ESP_OK) {
    ESP_LOGW(TAG, "I2S enable failed");
    return false;
  }
  s_audio_ready = true;
  ESP_LOGI(TAG, "Audio capture initialized at %d Hz", I2S_SAMPLE_RATE);
  return true;
}

static size_t capture_pcm_chunk(uint8_t *out, size_t out_len) {
  if (!out || out_len == 0) return 0;
  if (!s_audio_ready || !s_i2s_rx_chan) {
    memset(out, 0, out_len);
    return out_len;
  }

  size_t bytes_read = 0;
  esp_err_t err = i2s_channel_read(s_i2s_rx_chan, out, out_len, &bytes_read, pdMS_TO_TICKS(80));
  if (err != ESP_OK || bytes_read == 0) {
    memset(out, 0, out_len);
    return out_len;
  }
  if (bytes_read < out_len) {
    memset(out + bytes_read, 0, out_len - bytes_read);
    bytes_read = out_len;
  }
  return bytes_read;
}

static esp_err_t save_config_to_nvs(const device_config_t *cfg) {
  nvs_handle_t nvs;
  esp_err_t err = nvs_open("neo_cfg", NVS_READWRITE, &nvs);
  if (err != ESP_OK) return err;

  err = nvs_set_str(nvs, "backend_url", cfg->backend_url);
  if (err == ESP_OK) err = nvs_set_str(nvs, "pairing_code", cfg->pairing_code);
  if (err == ESP_OK) err = nvs_set_str(nvs, "device_token", cfg->device_token);
  if (err == ESP_OK) err = nvs_set_str(nvs, "device_id", cfg->device_id);
  if (err == ESP_OK) err = nvs_set_str(nvs, "device_name", cfg->device_name);
  if (err == ESP_OK) err = nvs_set_str(nvs, "mac_address", cfg->mac_address);
  if (err == ESP_OK) err = nvs_set_i32(nvs, "wifi_count", cfg->wifi_count);

  for (int i = 0; err == ESP_OK && i < cfg->wifi_count; i++) {
    char key_ssid[16];
    char key_pass[16];
    snprintf(key_ssid, sizeof(key_ssid), "ssid_%d", i);
    snprintf(key_pass, sizeof(key_pass), "pass_%d", i);
    err = nvs_set_str(nvs, key_ssid, cfg->wifi[i].ssid);
    if (err == ESP_OK) err = nvs_set_str(nvs, key_pass, cfg->wifi[i].password);
  }

  if (err == ESP_OK) err = nvs_commit(nvs);
  nvs_close(nvs);
  return err;
}

static bool load_config_from_nvs(device_config_t *cfg) {
  memset(cfg, 0, sizeof(*cfg));
  nvs_handle_t nvs;
  if (nvs_open("neo_cfg", NVS_READONLY, &nvs) != ESP_OK) return false;

  size_t len = sizeof(cfg->backend_url);
  if (nvs_get_str(nvs, "backend_url", cfg->backend_url, &len) != ESP_OK) {
    nvs_close(nvs);
    return false;
  }

  len = sizeof(cfg->pairing_code);
  if (nvs_get_str(nvs, "pairing_code", cfg->pairing_code, &len) != ESP_OK) {
    nvs_close(nvs);
    return false;
  }

  len = sizeof(cfg->device_token);
  if (nvs_get_str(nvs, "device_token", cfg->device_token, &len) != ESP_OK) {
    cfg->device_token[0] = '\0';
  }

  len = sizeof(cfg->device_id);
  if (nvs_get_str(nvs, "device_id", cfg->device_id, &len) != ESP_OK) {
    cfg->device_id[0] = '\0';
  }

  len = sizeof(cfg->device_name);
  if (nvs_get_str(nvs, "device_name", cfg->device_name, &len) != ESP_OK) {
    strncpy(cfg->device_name, "NeoOS Wearable", sizeof(cfg->device_name) - 1);
  }

  len = sizeof(cfg->mac_address);
  if (nvs_get_str(nvs, "mac_address", cfg->mac_address, &len) != ESP_OK) {
    cfg->mac_address[0] = '\0';
  }

  int32_t wifi_count = 0;
  if (nvs_get_i32(nvs, "wifi_count", &wifi_count) != ESP_OK || wifi_count <= 0) {
    nvs_close(nvs);
    return false;
  }
  if (wifi_count > MAX_WIFI_PROFILES) wifi_count = MAX_WIFI_PROFILES;

  cfg->wifi_count = (int)wifi_count;
  for (int i = 0; i < cfg->wifi_count; i++) {
    char key_ssid[16];
    char key_pass[16];
    size_t ssid_len = sizeof(cfg->wifi[i].ssid);
    size_t pass_len = sizeof(cfg->wifi[i].password);
    snprintf(key_ssid, sizeof(key_ssid), "ssid_%d", i);
    snprintf(key_pass, sizeof(key_pass), "pass_%d", i);
    if (nvs_get_str(nvs, key_ssid, cfg->wifi[i].ssid, &ssid_len) != ESP_OK) {
      nvs_close(nvs);
      return false;
    }
    if (nvs_get_str(nvs, key_pass, cfg->wifi[i].password, &pass_len) != ESP_OK) {
      cfg->wifi[i].password[0] = '\0';
    }
  }

  nvs_close(nvs);
  return true;
}

static void clear_config_nvs(void) {
  nvs_handle_t nvs;
  if (nvs_open("neo_cfg", NVS_READWRITE, &nvs) != ESP_OK) return;
  nvs_erase_all(nvs);
  nvs_commit(nvs);
  nvs_close(nvs);
}

static void wifi_event_handler(void *arg, esp_event_base_t event_base, int32_t event_id, void *event_data) {
  (void)arg;
  if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_START) {
    esp_wifi_connect();
    return;
  }
  if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_DISCONNECTED) {
    if (s_retry_num < 5) {
      esp_wifi_connect();
      s_retry_num++;
      ESP_LOGW(TAG, "Wi-Fi retry %d", s_retry_num);
    } else {
      xEventGroupSetBits(s_wifi_event_group, WIFI_FAIL_BIT);
    }
    return;
  }
  if (event_base == IP_EVENT && event_id == IP_EVENT_STA_GOT_IP) {
    ip_event_got_ip_t *event = (ip_event_got_ip_t *)event_data;
    ESP_LOGI(TAG, "Got IP: " IPSTR, IP2STR(&event->ip_info.ip));
    s_retry_num = 0;
    xEventGroupSetBits(s_wifi_event_group, WIFI_CONNECTED_BIT);
  }
}

static void start_wifi_common(void) {
  ESP_ERROR_CHECK(esp_netif_init());
  ESP_ERROR_CHECK(esp_event_loop_create_default());
  s_sta_netif = esp_netif_create_default_wifi_sta();
  s_ap_netif = esp_netif_create_default_wifi_ap();

  wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
  ESP_ERROR_CHECK(esp_wifi_init(&cfg));

  ESP_ERROR_CHECK(esp_event_handler_register(WIFI_EVENT, ESP_EVENT_ANY_ID, &wifi_event_handler, NULL));
  ESP_ERROR_CHECK(esp_event_handler_register(IP_EVENT, IP_EVENT_STA_GOT_IP, &wifi_event_handler, NULL));
}

static void stop_softap(void) {
  if (s_httpd) {
    httpd_stop(s_httpd);
    s_httpd = NULL;
  }
  esp_wifi_set_mode(WIFI_MODE_STA);
}

static esp_err_t root_get_handler(httpd_req_t *req) {
  httpd_resp_set_type(req, "text/html");
  httpd_resp_send(req, HTML_FORM, HTTPD_RESP_USE_STRLEN);
  return ESP_OK;
}

static esp_err_t save_post_handler(httpd_req_t *req) {
  char body[MAX_POST_BODY + 1];
  int remaining = req->content_len;
  if (remaining <= 0 || remaining > MAX_POST_BODY) {
    httpd_resp_send_err(req, HTTPD_400_BAD_REQUEST, "Invalid request size");
    return ESP_FAIL;
  }

  int offset = 0;
  while (remaining > 0) {
    int ret = httpd_req_recv(req, body + offset, remaining);
    if (ret <= 0) {
      httpd_resp_send_err(req, HTTPD_400_BAD_REQUEST, "Failed to read body");
      return ESP_FAIL;
    }
    remaining -= ret;
    offset += ret;
  }
  body[offset] = '\0';

  device_config_t new_cfg = {0};
  parse_form_value(body, "backend_url", new_cfg.backend_url, sizeof(new_cfg.backend_url));
  parse_form_value(body, "device_name", new_cfg.device_name, sizeof(new_cfg.device_name));
  parse_form_value(body, "pairing_code", new_cfg.pairing_code, sizeof(new_cfg.pairing_code));
  if (new_cfg.device_name[0] == '\0') {
    strncpy(new_cfg.device_name, "NeoOS Wearable", sizeof(new_cfg.device_name) - 1);
  }

  for (int i = 0; i < MAX_WIFI_PROFILES; i++) {
    char key_ssid[12];
    char key_pass[12];
    snprintf(key_ssid, sizeof(key_ssid), "ssid%d", i + 1);
    snprintf(key_pass, sizeof(key_pass), "pass%d", i + 1);

    char ssid[MAX_STR_64 + 1] = {0};
    char pass[MAX_STR_64 + 1] = {0};
    bool has_ssid = parse_form_value(body, key_ssid, ssid, sizeof(ssid));
    parse_form_value(body, key_pass, pass, sizeof(pass));
    if (!has_ssid) continue;

    strncpy(new_cfg.wifi[new_cfg.wifi_count].ssid, ssid, MAX_STR_64);
    strncpy(new_cfg.wifi[new_cfg.wifi_count].password, pass, MAX_STR_64);
    new_cfg.wifi_count++;
  }

  if (new_cfg.backend_url[0] == '\0' || new_cfg.pairing_code[0] == '\0' || new_cfg.wifi_count == 0) {
    httpd_resp_send_err(req, HTTPD_400_BAD_REQUEST, "backend_url, pairing_code, and at least one Wi-Fi are required");
    return ESP_FAIL;
  }

  if (save_config_to_nvs(&new_cfg) != ESP_OK) {
    httpd_resp_send_err(req, HTTPD_500_INTERNAL_SERVER_ERROR, "Failed to save config");
    return ESP_FAIL;
  }

  httpd_resp_set_type(req, "text/html");
  httpd_resp_sendstr(req, "<html><body><h3>Saved. Rebooting...</h3></body></html>");
  vTaskDelay(pdMS_TO_TICKS(600));
  esp_restart();
  return ESP_OK;
}

static void start_captive_ap_portal(void) {
  uint8_t mac[6] = {0};
  esp_read_mac(mac, ESP_MAC_WIFI_SOFTAP);

  char ssid[33];
  snprintf(ssid, sizeof(ssid), "NeoOS-%02X%02X", mac[4], mac[5]);

  wifi_config_t ap_cfg = {0};
  strncpy((char *)ap_cfg.ap.ssid, ssid, sizeof(ap_cfg.ap.ssid));
  strncpy((char *)ap_cfg.ap.password, "neoagent-setup", sizeof(ap_cfg.ap.password));
  ap_cfg.ap.ssid_len = strlen(ssid);
  ap_cfg.ap.channel = 6;
  ap_cfg.ap.max_connection = 4;
  ap_cfg.ap.authmode = WIFI_AUTH_WPA2_PSK;
  ap_cfg.ap.pmf_cfg.required = false;

  ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_APSTA));
  ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_AP, &ap_cfg));
  ESP_ERROR_CHECK(esp_wifi_start());

  httpd_config_t http_cfg = HTTPD_DEFAULT_CONFIG();
  http_cfg.max_open_sockets = 6;
  if (httpd_start(&s_httpd, &http_cfg) == ESP_OK) {
    httpd_uri_t root = {
      .uri = "/",
      .method = HTTP_GET,
      .handler = root_get_handler,
      .user_ctx = NULL,
    };
    httpd_uri_t save = {
      .uri = "/save",
      .method = HTTP_POST,
      .handler = save_post_handler,
      .user_ctx = NULL,
    };
    httpd_register_uri_handler(s_httpd, &root);
    httpd_register_uri_handler(s_httpd, &save);
  }

  ESP_LOGI(TAG, "Setup AP started: SSID=%s password=neoagent-setup", ssid);
}

static bool connect_wifi_profile(const wifi_profile_t *profile) {
  wifi_config_t sta_cfg = {0};
  strncpy((char *)sta_cfg.sta.ssid, profile->ssid, sizeof(sta_cfg.sta.ssid));
  strncpy((char *)sta_cfg.sta.password, profile->password, sizeof(sta_cfg.sta.password));
  sta_cfg.sta.threshold.authmode = WIFI_AUTH_WPA2_PSK;
  sta_cfg.sta.pmf_cfg.capable = true;
  sta_cfg.sta.pmf_cfg.required = false;

  ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
  ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_STA, &sta_cfg));
  ESP_ERROR_CHECK(esp_wifi_start());

  EventBits_t bits = xEventGroupWaitBits(
      s_wifi_event_group,
      WIFI_CONNECTED_BIT | WIFI_FAIL_BIT,
      pdTRUE,
      pdFALSE,
      pdMS_TO_TICKS(20000));

  if (bits & WIFI_CONNECTED_BIT) {
    ESP_LOGI(TAG, "Connected to Wi-Fi SSID=%s", profile->ssid);
    esp_wifi_set_ps(WIFI_PS_MIN_MODEM);
    return true;
  }
  ESP_LOGW(TAG, "Failed to connect Wi-Fi SSID=%s", profile->ssid);
  esp_wifi_stop();
  vTaskDelay(pdMS_TO_TICKS(400));
  return false;
}

static void build_device_mac_string(char *out, size_t out_len) {
  uint8_t mac[6] = {0};
  esp_read_mac(mac, ESP_MAC_WIFI_STA);
  snprintf(out, out_len, "%02X:%02X:%02X:%02X:%02X:%02X", mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
}

static bool http_post_json(const char *url, const char *json, const char *bearer_token, char *response_buf, size_t response_len, int *status_out) {
  if (response_buf && response_len > 0) response_buf[0] = '\0';

  esp_http_client_config_t cfg = {
      .url = url,
      .method = HTTP_METHOD_POST,
      .timeout_ms = 12000,
  };
  esp_http_client_handle_t client = esp_http_client_init(&cfg);
  if (!client) return false;

  esp_http_client_set_header(client, "Content-Type", "application/json");
  if (bearer_token && bearer_token[0] != '\0') {
    char auth[320];
    snprintf(auth, sizeof(auth), "Bearer %s", bearer_token);
    esp_http_client_set_header(client, "Authorization", auth);
  }
  esp_http_client_set_post_field(client, json, strlen(json));

  esp_err_t err = esp_http_client_perform(client);
  if (err != ESP_OK) {
    esp_http_client_cleanup(client);
    return false;
  }

  int status = esp_http_client_get_status_code(client);
  if (status_out) *status_out = status;

  int read = 0;
  if (response_buf && response_len > 1) {
    read = esp_http_client_read_response(client, response_buf, response_len - 1);
    if (read < 0) read = 0;
    response_buf[read] = '\0';
  }

  esp_http_client_cleanup(client);
  return status >= 200 && status < 300;
}

static bool http_get_with_bearer(const char *url, const char *bearer_token, char *response_buf, size_t response_len, int *status_out) {
  if (response_buf && response_len > 0) response_buf[0] = '\0';

  esp_http_client_config_t cfg = {
      .url = url,
      .method = HTTP_METHOD_GET,
      .timeout_ms = 12000,
  };
  esp_http_client_handle_t client = esp_http_client_init(&cfg);
  if (!client) return false;

  if (bearer_token && bearer_token[0] != '\0') {
    char auth[320];
    snprintf(auth, sizeof(auth), "Bearer %s", bearer_token);
    esp_http_client_set_header(client, "Authorization", auth);
  }

  esp_err_t err = esp_http_client_perform(client);
  if (err != ESP_OK) {
    esp_http_client_cleanup(client);
    return false;
  }

  int status = esp_http_client_get_status_code(client);
  if (status_out) *status_out = status;

  if (response_buf && response_len > 1) {
    int read = esp_http_client_read_response(client, response_buf, response_len - 1);
    if (read < 0) read = 0;
    response_buf[read] = '\0';
  }

  esp_http_client_cleanup(client);
  return status >= 200 && status < 300;
}

static bool http_post_binary(const char *url, const uint8_t *data, size_t len, const char *bearer_token, const char *characteristic_uuid, int *status_out) {
  esp_http_client_config_t cfg = {
      .url = url,
      .method = HTTP_METHOD_POST,
      .timeout_ms = 12000,
  };
  esp_http_client_handle_t client = esp_http_client_init(&cfg);
  if (!client) return false;

  if (bearer_token && bearer_token[0] != '\0') {
    char auth[320];
    snprintf(auth, sizeof(auth), "Bearer %s", bearer_token);
    esp_http_client_set_header(client, "Authorization", auth);
  }
  esp_http_client_set_header(client, "Content-Type", "application/octet-stream");
  if (characteristic_uuid && characteristic_uuid[0] != '\0') {
    esp_http_client_set_header(client, "x-characteristic-uuid", characteristic_uuid);
  }
  esp_http_client_set_post_field(client, (const char *)data, len);

  esp_err_t err = esp_http_client_perform(client);
  if (err != ESP_OK) {
    esp_http_client_cleanup(client);
    return false;
  }

  int status = esp_http_client_get_status_code(client);
  if (status_out) *status_out = status;
  esp_http_client_cleanup(client);
  return status >= 200 && status < 300;
}

static void send_device_status(const char *status, int battery_level) {
  if (s_cfg.device_token[0] == '\0' || s_cfg.backend_url[0] == '\0') return;

  char url[512];
  snprintf(url, sizeof(url), "%s/api/wearable-device/status", s_cfg.backend_url);

  cJSON *root = cJSON_CreateObject();
  cJSON_AddStringToObject(root, "status", status);
  if (s_cfg.mac_address[0] != '\0') {
    cJSON_AddStringToObject(root, "macAddress", s_cfg.mac_address);
  }
  cJSON_AddNumberToObject(root, "batteryLevel", battery_level);
  char *payload = cJSON_PrintUnformatted(root);
  cJSON_Delete(root);
  if (!payload) return;

  char response[256];
  int http_status = 0;
  if (!http_post_json(url, payload, s_cfg.device_token, response, sizeof(response), &http_status)) {
    ESP_LOGW(TAG, "status push failed status=%d", http_status);
  }
  free(payload);
}

static void poll_and_ack_responses(void) {
  if (s_cfg.device_token[0] == '\0' || s_cfg.backend_url[0] == '\0') return;

  char url[512];
  snprintf(url, sizeof(url), "%s/api/wearable-device/responses/next?limit=5", s_cfg.backend_url);

  char response[4096];
  int http_status = 0;
  if (!http_get_with_bearer(url, s_cfg.device_token, response, sizeof(response), &http_status)) {
    return;
  }

  cJSON *json = cJSON_Parse(response);
  if (!json) return;

  cJSON *responses = cJSON_GetObjectItemCaseSensitive(json, "responses");
  if (!cJSON_IsArray(responses) || cJSON_GetArraySize(responses) == 0) {
    cJSON_Delete(json);
    return;
  }

  int last_id = 0;
  const int count = cJSON_GetArraySize(responses);
  for (int i = 0; i < count; i++) {
    cJSON *item = cJSON_GetArrayItem(responses, i);
    cJSON *id = cJSON_GetObjectItemCaseSensitive(item, "id");
    cJSON *content = cJSON_GetObjectItemCaseSensitive(item, "content");
    if (cJSON_IsNumber(id) && id->valueint > last_id) {
      last_id = id->valueint;
    }
    if (cJSON_IsString(content) && content->valuestring) {
      ESP_LOGI(TAG, "RESPONSE: %.140s", content->valuestring);
      push_response_card(content->valuestring);
    }
  }
  cJSON_Delete(json);

  if (last_id <= 0) return;

  char ack_url[512];
  snprintf(ack_url, sizeof(ack_url), "%s/api/wearable-device/responses/ack", s_cfg.backend_url);
  cJSON *ack = cJSON_CreateObject();
  cJSON_AddNumberToObject(ack, "lastMessageId", last_id);
  char *ack_payload = cJSON_PrintUnformatted(ack);
  cJSON_Delete(ack);
  if (!ack_payload) return;

  char ack_resp[256];
  int ack_status = 0;
  http_post_json(ack_url, ack_payload, s_cfg.device_token, ack_resp, sizeof(ack_resp), &ack_status);
  free(ack_payload);
}

static void upload_recording_chunk(void) {
  if (!s_recording || s_cfg.device_token[0] == '\0' || s_cfg.backend_url[0] == '\0') return;

  char url[512];
  snprintf(url, sizeof(url), "%s/api/wearable-device/stream", s_cfg.backend_url);

  uint8_t pcm_chunk[3200];
  size_t pcm_len = capture_pcm_chunk(pcm_chunk, sizeof(pcm_chunk));
  if (pcm_len == 0) return;

  int status = 0;
  const char *characteristicUuid = "001120a3-2233-4455-6677-889912345678";
  if (http_post_binary(url, pcm_chunk, pcm_len, s_cfg.device_token, characteristicUuid, &status)) {
    s_recording_chunks_sent++;
  } else {
    ESP_LOGW(TAG, "chunk upload failed status=%d", status);
  }
}

static void send_recording_utterance_summary(void) {
  if (s_cfg.device_token[0] == '\0' || s_cfg.backend_url[0] == '\0') return;

  char url[512];
  snprintf(url, sizeof(url), "%s/api/wearable-device/utterance", s_cfg.backend_url);

  char text[160];
  snprintf(
      text,
      sizeof(text),
      "Recorded %d realtime audio chunks from ES8311 input. Summarize and respond in concise cards.",
      s_recording_chunks_sent);

  cJSON *root = cJSON_CreateObject();
  cJSON_AddStringToObject(root, "text", text);
  char *payload = cJSON_PrintUnformatted(root);
  cJSON_Delete(root);
  if (!payload) return;

  char response[256];
  int status = 0;
  if (!http_post_json(url, payload, s_cfg.device_token, response, sizeof(response), &status)) {
    ESP_LOGW(TAG, "utterance post failed status=%d", status);
  }
  free(payload);
}

static bool ensure_paired_token(void) {
  if (s_cfg.device_token[0] != '\0') return true;

  if (s_cfg.pairing_code[0] == '\0') {
    ESP_LOGE(TAG, "No pairing code configured");
    return false;
  }

  if (s_cfg.mac_address[0] == '\0') {
    build_device_mac_string(s_cfg.mac_address, sizeof(s_cfg.mac_address));
  }

  char url[512];
  snprintf(url, sizeof(url), "%s/api/wearable-device/pair/claim", s_cfg.backend_url);

  cJSON *root = cJSON_CreateObject();
  cJSON_AddStringToObject(root, "code", s_cfg.pairing_code);
  cJSON_AddStringToObject(root, "deviceId", s_cfg.device_id[0] ? s_cfg.device_id : s_cfg.mac_address);
  cJSON_AddStringToObject(root, "deviceName", s_cfg.device_name[0] ? s_cfg.device_name : "NeoOS Wearable");
  cJSON_AddStringToObject(root, "macAddress", s_cfg.mac_address);
  cJSON_AddStringToObject(root, "protocol", "waveshare_amoled_1_8");
  cJSON_AddStringToObject(root, "firmwareVersion", "0.1.0");

  char *payload = cJSON_PrintUnformatted(root);
  cJSON_Delete(root);
  if (!payload) return false;

  char response[1024];
  int status = 0;
  bool ok = http_post_json(url, payload, NULL, response, sizeof(response), &status);
  free(payload);

  if (!ok) {
    ESP_LOGE(TAG, "Pair claim failed status=%d", status);
    return false;
  }

  cJSON *json = cJSON_Parse(response);
  if (!json) return false;
  cJSON *token = cJSON_GetObjectItemCaseSensitive(json, "token");
  cJSON *deviceId = cJSON_GetObjectItemCaseSensitive(json, "deviceId");
  if (!cJSON_IsString(token) || token->valuestring[0] == '\0') {
    cJSON_Delete(json);
    return false;
  }

  strncpy(s_cfg.device_token, token->valuestring, sizeof(s_cfg.device_token) - 1);
  if (cJSON_IsString(deviceId) && deviceId->valuestring) {
    strncpy(s_cfg.device_id, deviceId->valuestring, sizeof(s_cfg.device_id) - 1);
  }
  cJSON_Delete(json);

  if (save_config_to_nvs(&s_cfg) != ESP_OK) {
    ESP_LOGW(TAG, "Paired token acquired but saving NVS failed");
  }
  ESP_LOGI(TAG, "Pairing claim successful");
  return true;
}

static void heartbeat_task(void *arg) {
  (void)arg;
  while (true) {
    if (s_cfg.device_token[0] != '\0' && s_cfg.backend_url[0] != '\0') {
      send_device_status(s_recording ? "recording" : "connected", 100);
      if (s_recording) {
        upload_recording_chunk();
      }
      poll_and_ack_responses();
    }
    const int sleepMs = s_recording ? 5000 : 30000;
    vTaskDelay(pdMS_TO_TICKS(sleepMs));
  }
}

static void button_actions_task(void *arg) {
  (void)arg;
  int held_ms = 0;
  bool recording_started_for_hold = false;

  while (true) {
    const int level = gpio_get_level(BOOT_BUTTON_GPIO);
    if (level == 0) {
      held_ms += BUTTON_POLL_MS;
      if (!recording_started_for_hold && held_ms >= RECORD_HOLD_MS && held_ms < BOOT_LONG_PRESS_MS) {
        recording_started_for_hold = true;
        if (!s_recording) {
          s_recording = true;
          s_recording_chunks_sent = 0;
          ESP_LOGI(TAG, "Button hold -> recording started");
          push_response_card("Recording started...");
          send_device_status("recording", 100);
        }
      }
    } else {
      if (s_recording && recording_started_for_hold) {
        s_recording = false;
        ESP_LOGI(TAG, "Button release -> recording stopped");
        push_response_card("Recording stopped. Sending utterance...");
        send_device_status("connected", 100);
        send_recording_utterance_summary();
      }
      held_ms = 0;
      recording_started_for_hold = false;
    }

    vTaskDelay(pdMS_TO_TICKS(BUTTON_POLL_MS));
  }
}

static void connect_using_saved_profiles_or_fallback(void) {
  bool connected = false;
  for (int i = 0; i < s_cfg.wifi_count; i++) {
    if (connect_wifi_profile(&s_cfg.wifi[i])) {
      connected = true;
      break;
    }
  }

  if (connected) {
    stop_softap();
    push_response_card("Wi-Fi connected. Pairing with backend...");
    if (s_cfg.mac_address[0] == '\0') {
      build_device_mac_string(s_cfg.mac_address, sizeof(s_cfg.mac_address));
    }

    if (!ensure_paired_token()) {
      ESP_LOGW(TAG, "Pairing claim failed, falling back to setup AP mode");
      push_response_card("Pairing failed. Returning to setup AP mode.");
      memset(s_cfg.device_token, 0, sizeof(s_cfg.device_token));
      save_config_to_nvs(&s_cfg);
      start_captive_ap_portal();
      return;
    }

    ESP_LOGI(TAG, "Device ready and paired: backend=%s device=%s", s_cfg.backend_url, s_cfg.device_id);
    push_response_card("Device paired and connected. Hold BOOT to record.");
    xTaskCreate(heartbeat_task, "heartbeat_task", 6144, NULL, 4, NULL);
    xTaskCreate(button_actions_task, "button_actions_task", 4096, NULL, 4, NULL);
    return;
  }

  ESP_LOGW(TAG, "No Wi-Fi profile connected, returning to setup AP mode");
  push_response_card("Wi-Fi failed. Setup AP started.");
  start_captive_ap_portal();
}

static void button_reset_task(void *arg) {
  (void)arg;
  int held_ms = 0;
  while (true) {
    int level = gpio_get_level(BOOT_BUTTON_GPIO);
    if (level == 0) {
      held_ms += BUTTON_POLL_MS;
      if (held_ms >= BOOT_LONG_PRESS_MS) {
        ESP_LOGW(TAG, "BOOT long-press detected, clearing setup config and rebooting");
        clear_config_nvs();
        vTaskDelay(pdMS_TO_TICKS(300));
        esp_restart();
      }
    } else {
      held_ms = 0;
    }
    vTaskDelay(pdMS_TO_TICKS(BUTTON_POLL_MS));
  }
}

void app_main(void) {
  esp_err_t err = nvs_flash_init();
  if (err == ESP_ERR_NVS_NO_FREE_PAGES || err == ESP_ERR_NVS_NEW_VERSION_FOUND) {
    ESP_ERROR_CHECK(nvs_flash_erase());
    err = nvs_flash_init();
  }
  ESP_ERROR_CHECK(err);

  gpio_config_t io_cfg = {
      .pin_bit_mask = (1ULL << BOOT_BUTTON_GPIO),
      .mode = GPIO_MODE_INPUT,
      .pull_up_en = GPIO_PULLUP_ENABLE,
      .pull_down_en = GPIO_PULLDOWN_DISABLE,
      .intr_type = GPIO_INTR_DISABLE,
  };
  ESP_ERROR_CHECK(gpio_config(&io_cfg));

  s_wifi_event_group = xEventGroupCreate();
  init_display();
  run_neoos_boot_animation();
  init_audio_capture();
  start_wifi_common();
  xTaskCreate(button_reset_task, "button_reset_task", 4096, NULL, 3, NULL);

  if (!load_config_from_nvs(&s_cfg)) {
    ESP_LOGI(TAG, "No valid configuration found, starting setup AP portal");
    push_response_card("Setup mode. Join AP and configure backend/Wi-Fi.");
    start_captive_ap_portal();
    return;
  }

  ESP_LOGI(TAG, "Configuration loaded, attempting Wi-Fi profiles");
  push_response_card("Booting with saved configuration...");
  connect_using_saved_profiles_or_fallback();
}
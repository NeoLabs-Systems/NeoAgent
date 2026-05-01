#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#define NEOAGENT_SERVER_URL_MAX 256
#define NEOAGENT_DEVICE_LABEL_MAX 64
#define NEOAGENT_WIFI_SSID_MAX 64
#define NEOAGENT_WIFI_PASSWORD_MAX 64
#define NEOAGENT_WIFI_NETWORK_MAX 4
#define NEOAGENT_SESSION_COOKIE_MAX 512
#define NEOAGENT_QR_CHALLENGE_ID_MAX 96
#define NEOAGENT_QR_TOKEN_MAX 160
#define NEOAGENT_QR_PAYLOAD_MAX 384
#define NEOAGENT_WIDGET_ID_MAX 80
#define NEOAGENT_WIDGET_TITLE_MAX 128
#define NEOAGENT_WIDGET_TEXT_MAX 256
#define NEOAGENT_WIDGET_ROWS_MAX 3
#define NEOAGENT_WIDGET_CHIPS_MAX 3
#define NEOAGENT_VOICE_SESSION_ID_MAX 96
#define NEOAGENT_VOICE_TURN_ID_MAX 96
#define NEOAGENT_WS_URL_MAX 256
#define NEOAGENT_FIRMWARE_CHANNEL_MAX 16

typedef enum {
    NEOAGENT_SCREEN_ASSISTANT = 0,
    NEOAGENT_SCREEN_WIDGETS = 1,
    NEOAGENT_SCREEN_RECORDER = 2,
    NEOAGENT_SCREEN_SETTINGS = 3,
    NEOAGENT_SCREEN_PROVISIONING = 4,
    NEOAGENT_SCREEN_PAIRING = 5,
} neoagent_screen_id_t;

typedef struct {
    char ssid[NEOAGENT_WIFI_SSID_MAX];
    char password[NEOAGENT_WIFI_PASSWORD_MAX];
    uint8_t channel;
    uint8_t bssid[6];
} neoagent_wifi_network_t;

typedef struct {
    char wifi_ssid[NEOAGENT_WIFI_SSID_MAX];
    char wifi_password[NEOAGENT_WIFI_PASSWORD_MAX];
    char server_url[NEOAGENT_SERVER_URL_MAX];
    char device_label[NEOAGENT_DEVICE_LABEL_MAX];
    uint8_t wifi_channel;
    uint8_t wifi_bssid[6];
    neoagent_wifi_network_t wifi_networks[NEOAGENT_WIFI_NETWORK_MAX];
    uint8_t wifi_network_count;
} neoagent_device_config_t;

typedef struct {
    bool authenticated;
    char session_cookie[NEOAGENT_SESSION_COOKIE_MAX];
    char username[NEOAGENT_DEVICE_LABEL_MAX];
    char user_id[24];
} neoagent_session_state_t;

typedef struct {
    char challenge_id[NEOAGENT_QR_CHALLENGE_ID_MAX];
    char poll_token[NEOAGENT_QR_TOKEN_MAX];
    char approve_secret[NEOAGENT_QR_TOKEN_MAX];
    char qr_payload[NEOAGENT_QR_PAYLOAD_MAX];
    char expires_at[48];
    bool pending;
} neoagent_pairing_state_t;

typedef struct {
    char label[72];
    char value[120];
} neoagent_widget_row_t;

typedef struct {
    char id[NEOAGENT_WIDGET_ID_MAX];
    char title[NEOAGENT_WIDGET_TITLE_MAX];
    char subtitle[NEOAGENT_WIDGET_TEXT_MAX];
    char body[NEOAGENT_WIDGET_TEXT_MAX];
    char metric[48];
    char metric_label[64];
    neoagent_widget_row_t rows[NEOAGENT_WIDGET_ROWS_MAX];
    size_t row_count;
} neoagent_widget_snapshot_t;

typedef struct {
    bool charging;
    int battery_percent;
    bool wifi_connected;
    bool paired;
} neoagent_status_chrome_t;

typedef struct {
    char channel[NEOAGENT_FIRMWARE_CHANNEL_MAX];
} neoagent_firmware_update_settings_t;

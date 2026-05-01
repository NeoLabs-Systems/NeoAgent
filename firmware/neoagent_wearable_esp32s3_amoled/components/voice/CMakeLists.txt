idf_component_register(
    SRCS "wearable_voice_client.c"
    INCLUDE_DIRS "include"
    REQUIRES common board_support esp_websocket_client cjson mbedtls app_update esp_timer
)

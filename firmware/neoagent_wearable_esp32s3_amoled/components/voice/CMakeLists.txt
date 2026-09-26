idf_component_register(
    SRCS "wearable_voice_client.c" "pcm_resampler.c"
    INCLUDE_DIRS "include"
    REQUIRES common board_support esp_websocket_client esp_ringbuf cjson mbedtls app_update esp_timer
)

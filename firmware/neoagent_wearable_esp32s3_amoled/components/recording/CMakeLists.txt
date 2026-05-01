idf_component_register(
    SRCS "background_recording_client.c"
    INCLUDE_DIRS "include"
    REQUIRES common board_support esp_http_client esp-tls mbedtls cjson esp_timer
)

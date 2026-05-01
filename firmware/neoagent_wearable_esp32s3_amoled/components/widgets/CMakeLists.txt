idf_component_register(
    SRCS "widget_repository.c"
    INCLUDE_DIRS "include"
    REQUIRES common json esp_http_client esp-tls mbedtls
)

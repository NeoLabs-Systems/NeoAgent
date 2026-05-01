idf_component_register(SRCS "update_manager.c" INCLUDE_DIRS "include" REQUIRES common json esp_http_client esp_https_ota app_update esp-tls mbedtls)

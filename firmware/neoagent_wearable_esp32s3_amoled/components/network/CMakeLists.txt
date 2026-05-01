idf_component_register(
    SRCS "provisioning_manager.c"
    INCLUDE_DIRS "include"
    REQUIRES common cjson esp_http_client esp_netif esp_event esp_wifi esp_http_server esp-tls mbedtls nvs_flash storage
)

idf_component_register(
    SRCS "provisioning_manager.c"
    INCLUDE_DIRS "include"
    REQUIRES common esp_netif esp_event esp_wifi esp_http_server nvs_flash storage
)

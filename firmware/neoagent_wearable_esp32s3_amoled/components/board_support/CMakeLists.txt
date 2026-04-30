idf_component_register(
    SRCS "power_manager.c" "board_support.c"
    INCLUDE_DIRS "include"
    REQUIRES common driver esp_timer esp_lcd lvgl esp_lcd_touch_ft5x06 esp_lcd_sh8601 esp_io_expander_tca9554
)

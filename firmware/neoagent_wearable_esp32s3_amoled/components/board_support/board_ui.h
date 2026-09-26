#pragma once

#include <stdbool.h>

#include "board_support.h"
#include "lvgl.h"

// The wearable's screens, drawn with LVGL in the app's design language.
// Every function here runs with the LVGL lock held.

#define BOARD_UI_WIDTH 448
#define BOARD_UI_HEIGHT 368

void board_ui_show_boot(void);
void board_ui_show_message(mascot_mood_t mood, const char *title, const char *line1, const char *line2);
void board_ui_show_qr(const char *title, const char *subtitle, const char *qr_payload);
void board_ui_show_call(const board_call_view_t *view);
void board_ui_show_settings(const board_settings_view_t *view);
void board_ui_set_chrome(const neoagent_status_chrome_t *chrome, const char *time_text);
board_target_t board_ui_hit_test(uint16_t x, uint16_t y);

// The mascot as an LVGL object: `tile_side` is the tile's size at rest; the
// object is larger so the tile can bounce, shake and glow inside it.
lv_obj_t *mascot_view_create(lv_obj_t *parent, lv_coord_t tile_side, mascot_mood_t mood);
void mascot_view_set_mood(lv_obj_t *view, mascot_mood_t mood);

#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "board_ui.h"
#include "extra/libs/qrcode/lv_qrcode.h"

// Dark palette of the app (flutter_app/lib/src/theme/palette.dart).
#define UI_BG 0x0E1511
#define UI_BG_SECONDARY 0x171F1A
#define UI_BG_TERTIARY 0x1C261F
#define UI_TEXT 0xECEFE5
#define UI_TEXT_SECONDARY 0xAEB7A6
#define UI_TEXT_MUTED 0x7E8877
#define UI_ACCENT 0xE1B052
#define UI_SUCCESS 0x74C07C
#define UI_DANGER 0xDE8A78
#define UI_HAIRLINE 0xE0F0E0
#define UI_OPA_BORDER 0x14
#define UI_OPA_BORDER_LIGHT 0x24

#define UI_GUTTER 24
// Longest caption the call screen is handed (NEOAGENT_VOICE_TEXT_MAX).
#define NEOAGENT_VOICE_CAPTION_MAX 240
#define UI_HEADER_HEIGHT 48
#define UI_ICON_BUTTON 36
#define UI_ROW_HEIGHT 56
#define UI_ROW_GAP 8
#define UI_CAPTION_LINES 5

// The call screen: the mascot inside its halo on the left, the call on the right.
#define CALL_HALO_CX 140
#define CALL_HALO_CY 206
#define CALL_HALO_EXTENT 204
#define CALL_HALO_RING 162
#define CALL_MASCOT_TILE 112
#define CALL_COLUMN_X 268
#define CALL_COLUMN_W 160
#define CALL_BUTTON 58
#define CALL_PULSE_MS 1800

static struct {
    lv_obj_t *time;
    lv_obj_t *battery_icon;
    lv_obj_t *battery;
} s_header;

static struct {
    lv_obj_t *screen;
    lv_obj_t *halo;
    lv_obj_t *ripples[2];
    lv_obj_t *ring;
    lv_obj_t *mascot;
    lv_obj_t *name;
    lv_obj_t *status;
    lv_obj_t *caption;
    lv_obj_t *task;
    lv_obj_t *task_label;
    lv_obj_t *controls;
    board_call_phase_t phase;
    bool hands_free;
    bool capturing;
    uint32_t pulse_color;  // 0 while nobody talks.
} s_call;

static neoagent_status_chrome_t s_chrome = {.battery_percent = -1};
static char s_time[8] = "--:--";

static lv_obj_t *plain(lv_obj_t *parent, lv_coord_t width, lv_coord_t height) {
    lv_obj_t *obj = lv_obj_create(parent);
    lv_obj_remove_style_all(obj);
    lv_obj_set_size(obj, width, height);
    lv_obj_clear_flag(obj, LV_OBJ_FLAG_SCROLLABLE | LV_OBJ_FLAG_CLICKABLE);
    return obj;
}

static lv_obj_t *surface(lv_obj_t *parent, lv_coord_t width, lv_coord_t height, uint32_t color, lv_coord_t radius) {
    lv_obj_t *obj = plain(parent, width, height);
    lv_obj_set_style_bg_color(obj, lv_color_hex(color), 0);
    lv_obj_set_style_bg_opa(obj, LV_OPA_COVER, 0);
    lv_obj_set_style_radius(obj, radius, 0);
    return obj;
}

static void hairline(lv_obj_t *obj, uint32_t color, lv_opa_t opa, lv_coord_t width) {
    lv_obj_set_style_border_color(obj, lv_color_hex(color), 0);
    lv_obj_set_style_border_opa(obj, opa, 0);
    lv_obj_set_style_border_width(obj, width, 0);
}

static lv_obj_t *text(lv_obj_t *parent, const lv_font_t *font, uint32_t color, const char *value) {
    lv_obj_t *label = lv_label_create(parent);
    lv_obj_set_style_text_font(label, font, 0);
    lv_obj_set_style_text_color(label, lv_color_hex(color), 0);
    lv_label_set_text(label, value != NULL ? value : "");
    return label;
}

static lv_obj_t *wrapped_text(lv_obj_t *parent, const lv_font_t *font, uint32_t color, lv_coord_t width, const char *value) {
    lv_obj_t *label = text(parent, font, color, value);
    lv_obj_set_width(label, width);
    lv_label_set_long_mode(label, LV_LABEL_LONG_WRAP);
    return label;
}

// Marks `obj` as the control for `target`; hit testing reads it back.
static void tag(lv_obj_t *obj, board_target_t target) {
    lv_obj_set_user_data(obj, (void *)(uintptr_t)target);
    lv_obj_add_flag(obj, LV_OBJ_FLAG_USER_1);
}

static lv_obj_t *new_screen(void) {
    lv_obj_t *screen = lv_obj_create(NULL);
    lv_obj_remove_style_all(screen);
    lv_obj_set_style_bg_color(screen, lv_color_hex(UI_BG), 0);
    lv_obj_set_style_bg_opa(screen, LV_OPA_COVER, 0);
    lv_obj_clear_flag(screen, LV_OBJ_FLAG_SCROLLABLE);
    return screen;
}

static void load_screen(lv_obj_t *screen) {
    lv_obj_t *previous = lv_scr_act();
    if (s_call.screen != screen) {
        memset(&s_call, 0, sizeof(s_call));
    }
    lv_scr_load(screen);
    if (previous != NULL && previous != screen) {
        lv_obj_del(previous);
    }
}

static const char *battery_symbol(void) {
    if (s_chrome.charging) {
        return LV_SYMBOL_CHARGE;
    }
    const int percent = s_chrome.battery_percent;
    if (percent < 0 || percent >= 80) {
        return LV_SYMBOL_BATTERY_FULL;
    }
    if (percent >= 55) {
        return LV_SYMBOL_BATTERY_3;
    }
    if (percent >= 30) {
        return LV_SYMBOL_BATTERY_2;
    }
    return percent >= 10 ? LV_SYMBOL_BATTERY_1 : LV_SYMBOL_BATTERY_EMPTY;
}

static void refresh_header(void) {
    if (s_header.time != NULL) {
        lv_label_set_text(s_header.time, s_time);
    }
    if (s_header.battery != NULL) {
        char percent[12];
        if (s_chrome.battery_percent < 0) {
            snprintf(percent, sizeof(percent), "--%%");
        } else {
            snprintf(percent, sizeof(percent), "%d%%", s_chrome.battery_percent);
        }
        lv_label_set_text(s_header.battery, percent);
        lv_label_set_text(s_header.battery_icon, battery_symbol());
        lv_obj_set_style_text_color(s_header.battery_icon, lv_color_hex(s_chrome.charging ? UI_SUCCESS : UI_TEXT_SECONDARY), 0);
    }
}

static lv_obj_t *icon_button(lv_obj_t *parent, const char *symbol, board_target_t target) {
    lv_obj_t *button = surface(parent, UI_ICON_BUTTON, UI_ICON_BUTTON, UI_BG_TERTIARY, LV_RADIUS_CIRCLE);
    hairline(button, UI_HAIRLINE, UI_OPA_BORDER_LIGHT, 1);
    lv_obj_center(text(button, &lv_font_montserrat_16, UI_TEXT, symbol));
    tag(button, target);
    return button;
}

// Time or a back button on the left, an optional title, the battery on the right.
static void build_header(lv_obj_t *screen, const char *title, bool back, bool settings) {
    memset(&s_header, 0, sizeof(s_header));
    lv_obj_t *bar = plain(screen, BOARD_UI_WIDTH, UI_HEADER_HEIGHT);

    if (back) {
        lv_obj_align(icon_button(bar, LV_SYMBOL_LEFT, BOARD_TARGET_BACK), LV_ALIGN_LEFT_MID, UI_GUTTER - 8, 2);
    } else {
        s_header.time = text(bar, &lv_font_montserrat_16, UI_TEXT_SECONDARY, s_time);
        lv_obj_align(s_header.time, LV_ALIGN_LEFT_MID, UI_GUTTER, 2);
    }
    if (title != NULL) {
        lv_obj_align(text(bar, &lv_font_montserrat_16, UI_TEXT, title), LV_ALIGN_CENTER, 0, 2);
    }

    lv_obj_t *cluster = plain(bar, LV_SIZE_CONTENT, LV_SIZE_CONTENT);
    lv_obj_set_flex_flow(cluster, LV_FLEX_FLOW_ROW);
    lv_obj_set_flex_align(cluster, LV_FLEX_ALIGN_START, LV_FLEX_ALIGN_CENTER, LV_FLEX_ALIGN_CENTER);
    lv_obj_set_style_pad_column(cluster, 6, 0);
    s_header.battery_icon = text(cluster, &lv_font_montserrat_16, UI_TEXT_SECONDARY, "");
    s_header.battery = text(cluster, &lv_font_montserrat_14, UI_TEXT_SECONDARY, "");
    if (settings) {
        plain(cluster, 8, 1);
        icon_button(cluster, LV_SYMBOL_SETTINGS, BOARD_TARGET_OPEN_SETTINGS);
    }
    lv_obj_align(cluster, LV_ALIGN_RIGHT_MID, settings ? -(UI_GUTTER - 8) : -UI_GUTTER, 2);
    refresh_header();
}

// A centred column: the mascot, then the texts under it.
static lv_obj_t *centred_column(lv_obj_t *screen, lv_coord_t width) {
    lv_obj_t *column = plain(screen, width, LV_SIZE_CONTENT);
    lv_obj_set_flex_flow(column, LV_FLEX_FLOW_COLUMN);
    lv_obj_set_flex_align(column, LV_FLEX_ALIGN_CENTER, LV_FLEX_ALIGN_CENTER, LV_FLEX_ALIGN_CENTER);
    lv_obj_set_style_pad_row(column, 8, 0);
    return column;
}

static lv_obj_t *centred_text(lv_obj_t *parent, const lv_font_t *font, uint32_t color, lv_coord_t width, const char *value) {
    lv_obj_t *label = wrapped_text(parent, font, color, width, value);
    lv_obj_set_style_text_align(label, LV_TEXT_ALIGN_CENTER, 0);
    if (value == NULL || value[0] == '\0') {
        lv_obj_add_flag(label, LV_OBJ_FLAG_HIDDEN);
    }
    return label;
}

void board_ui_show_boot(void) {
    lv_obj_t *screen = new_screen();
    lv_obj_t *column = centred_column(screen, BOARD_UI_WIDTH);
    mascot_view_create(column, 120, MASCOT_MOOD_THINKING);
    centred_text(column, &lv_font_montserrat_24, UI_TEXT, BOARD_UI_WIDTH, "NeoAgent");
    lv_obj_center(column);
    load_screen(screen);
}

void board_ui_show_message(mascot_mood_t mood, const char *title, const char *line1, const char *line2) {
    lv_obj_t *screen = new_screen();
    const lv_coord_t width = BOARD_UI_WIDTH - (2 * UI_GUTTER) - 32;
    lv_obj_t *column = centred_column(screen, width);
    mascot_view_create(column, 88, mood);
    centred_text(column, &lv_font_montserrat_24, UI_TEXT, width, title);
    centred_text(column, &lv_font_montserrat_16, UI_TEXT_SECONDARY, width, line1);
    centred_text(column, &lv_font_montserrat_14, UI_TEXT_MUTED, width, line2);
    lv_obj_center(column);
    load_screen(screen);
}

void board_ui_show_qr(const char *title, const char *subtitle, const char *qr_payload) {
    lv_obj_t *screen = new_screen();
    build_header(screen, "Pair", false, false);

    lv_obj_t *frame = surface(screen, 176, 176, 0xFFFFFF, 20);
    lv_obj_set_pos(frame, UI_GUTTER + 8, 76);
    lv_obj_t *code = lv_qrcode_create(frame, 152, lv_color_hex(0x111111), lv_color_hex(0xFFFFFF));
    lv_obj_center(code);
    if (qr_payload != NULL && qr_payload[0] != '\0') {
        lv_qrcode_update(code, qr_payload, strlen(qr_payload));
    }

    const lv_coord_t column_x = UI_GUTTER + 8 + 176 + 24;
    const lv_coord_t column_w = BOARD_UI_WIDTH - column_x - UI_GUTTER;
    lv_obj_t *column = plain(screen, column_w, LV_SIZE_CONTENT);
    lv_obj_set_flex_flow(column, LV_FLEX_FLOW_COLUMN);
    lv_obj_set_style_pad_row(column, 10, 0);
    lv_obj_set_pos(column, column_x, 72);
    mascot_view_create(column, 52, MASCOT_MOOD_WAITING);
    wrapped_text(column, &lv_font_montserrat_16, UI_TEXT, column_w, title);
    wrapped_text(column, &lv_font_montserrat_14, UI_TEXT_SECONDARY, column_w, subtitle);
    wrapped_text(column, &lv_font_montserrat_12, UI_TEXT_MUTED, column_w, "Open NeoAgent on another device and scan this code.");
    load_screen(screen);
}

static lv_point_t measure(lv_obj_t *label, const char *value, lv_coord_t width) {
    lv_point_t size;
    lv_txt_get_size(
        &size,
        value,
        lv_obj_get_style_text_font(label, 0),
        lv_obj_get_style_text_letter_space(label, 0),
        lv_obj_get_style_text_line_space(label, 0),
        width,
        LV_TEXT_FLAG_NONE
    );
    return size;
}

// A live transcript grows at its end, so when it outgrows its lines the
// oldest words give way.
static void set_caption(lv_obj_t *label, const char *value, lv_coord_t width) {
    const lv_font_t *font = lv_obj_get_style_text_font(label, 0);
    const lv_coord_t max_height = UI_CAPTION_LINES * lv_font_get_line_height(font);
    char fitted[NEOAGENT_VOICE_CAPTION_MAX + 4];
    const char *start = value;
    while (true) {
        snprintf(fitted, sizeof(fitted), "%s%s", start == value ? "" : "...", start);
        const char *space = strchr(start, ' ');
        if (measure(label, fitted, width).y <= max_height || space == NULL) {
            break;
        }
        start = space + 1;
    }
    lv_label_set_text(label, fitted);
}

// One line, cut short with an ellipsis when it does not fit.
static void set_single_line(lv_obj_t *label, const char *value, lv_coord_t width) {
    char fitted[NEOAGENT_VOICE_CAPTION_MAX + 4];
    strlcpy(fitted, value, sizeof(fitted));
    size_t length = strlen(fitted);
    if (measure(label, fitted, LV_COORD_MAX).x > width) {
        while (length > 0) {
            do {
                length -= 1;
            } while (length > 0 && ((unsigned char)fitted[length] & 0xC0) == 0x80);
            while (length > 0 && fitted[length - 1] == ' ') {
                length -= 1;
            }
            memcpy(fitted + length, "...", 4);
            if (measure(label, fitted, LV_COORD_MAX).x <= width) {
                break;
            }
        }
    }
    lv_label_set_text(label, fitted);
}

static void ripple_exec(void *var, int32_t value) {
    (void)var;
    for (int i = 0; i < 2; ++i) {
        lv_obj_t *ripple = s_call.ripples[i];
        if (ripple == NULL) {
            continue;
        }
        const int32_t phase = (value + (i * 500)) % 1000;
        const lv_coord_t side = (lv_coord_t)(CALL_HALO_RING + ((CALL_HALO_EXTENT - CALL_HALO_RING) * phase / 1000));
        lv_obj_set_size(ripple, side, side);
        lv_obj_set_pos(ripple, (CALL_HALO_EXTENT - side) / 2, (CALL_HALO_EXTENT - side) / 2);
        lv_obj_set_style_bg_opa(ripple, (lv_opa_t)(41 * (1000 - phase) / 1000), 0);
    }
}

// Ripples out from the mascot in `color` while someone talks; a hairline otherwise.
static void set_halo(uint32_t color) {
    if (color == s_call.pulse_color) {
        return;
    }
    s_call.pulse_color = color;
    lv_anim_del(s_call.halo, ripple_exec);
    if (color == 0) {
        for (int i = 0; i < 2; ++i) {
            lv_obj_add_flag(s_call.ripples[i], LV_OBJ_FLAG_HIDDEN);
        }
        hairline(s_call.ring, UI_HAIRLINE, UI_OPA_BORDER_LIGHT, 2);
        return;
    }
    for (int i = 0; i < 2; ++i) {
        lv_obj_set_style_bg_color(s_call.ripples[i], lv_color_hex(color), 0);
        lv_obj_clear_flag(s_call.ripples[i], LV_OBJ_FLAG_HIDDEN);
    }
    hairline(s_call.ring, color, LV_OPA_60, 2);
    lv_anim_t pulse;
    lv_anim_init(&pulse);
    lv_anim_set_var(&pulse, s_call.halo);
    lv_anim_set_exec_cb(&pulse, ripple_exec);
    lv_anim_set_values(&pulse, 0, 1000);
    lv_anim_set_time(&pulse, CALL_PULSE_MS);
    lv_anim_set_repeat_count(&pulse, LV_ANIM_REPEAT_INFINITE);
    lv_anim_start(&pulse);
}

// A microphone drawn from shapes; the built-in symbol font has none.
static void mic_icon(lv_obj_t *parent, uint32_t color, bool muted) {
    lv_obj_t *icon = plain(parent, 24, 30);
    lv_obj_center(icon);
    lv_obj_t *capsule = surface(icon, 10, 17, color, 5);
    lv_obj_align(capsule, LV_ALIGN_TOP_MID, 0, 0);
    lv_obj_t *cradle = lv_arc_create(icon);
    lv_obj_remove_style_all(cradle);
    lv_obj_set_size(cradle, 20, 20);
    lv_obj_align(cradle, LV_ALIGN_TOP_MID, 0, 3);
    lv_arc_set_bg_angles(cradle, 0, 180);
    lv_obj_set_style_arc_width(cradle, 2, LV_PART_MAIN);
    lv_obj_set_style_arc_color(cradle, lv_color_hex(color), LV_PART_MAIN);
    lv_obj_set_style_arc_opa(cradle, LV_OPA_COVER, LV_PART_MAIN);
    lv_obj_set_style_arc_rounded(cradle, true, LV_PART_MAIN);
    lv_obj_clear_flag(cradle, LV_OBJ_FLAG_CLICKABLE);
    lv_obj_t *stem = surface(icon, 2, 6, color, 1);
    lv_obj_align(stem, LV_ALIGN_BOTTOM_MID, 0, 0);
    if (muted) {
        static const lv_point_t slash[] = {{2, 2}, {22, 28}};
        lv_obj_t *line = lv_line_create(icon);
        lv_line_set_points(line, slash, 2);
        lv_obj_set_style_line_width(line, 2, 0);
        lv_obj_set_style_line_color(line, lv_color_hex(color), 0);
        lv_obj_set_style_line_rounded(line, true, 0);
    }
}

// A round call control with its label underneath, like the app's.
static lv_obj_t *call_button(lv_obj_t *parent, uint32_t fill_color, bool outlined, const char *label, board_target_t target) {
    lv_obj_t *item = plain(parent, CALL_COLUMN_W / 2, LV_SIZE_CONTENT);
    lv_obj_add_flag(item, LV_OBJ_FLAG_OVERFLOW_VISIBLE);
    lv_obj_set_flex_flow(item, LV_FLEX_FLOW_COLUMN);
    lv_obj_set_flex_align(item, LV_FLEX_ALIGN_START, LV_FLEX_ALIGN_CENTER, LV_FLEX_ALIGN_CENTER);
    lv_obj_set_style_pad_row(item, 6, 0);
    lv_obj_t *circle = surface(item, CALL_BUTTON, CALL_BUTTON, fill_color, LV_RADIUS_CIRCLE);
    if (outlined) {
        hairline(circle, UI_HAIRLINE, UI_OPA_BORDER_LIGHT, 1);
    }
    text(item, &lv_font_montserrat_12, UI_TEXT_SECONDARY, label);
    tag(item, target);
    return circle;
}

static void build_controls(const board_call_view_t *view) {
    lv_obj_clean(s_call.controls);
    if (view->phase == BOARD_CALL_IDLE) {
        lv_obj_t *call = call_button(s_call.controls, UI_SUCCESS, false, "Call", BOARD_TARGET_CALL);
        lv_obj_center(text(call, &lv_font_montserrat_24, 0xFFFFFF, LV_SYMBOL_CALL));
        return;
    }
    if (view->phase == BOARD_CALL_ACTIVE) {
        const char *label = NULL;
        uint32_t fill_color = UI_BG_TERTIARY;
        uint32_t icon_color = UI_TEXT;
        bool muted = false;
        if (view->hands_free) {
            muted = !view->capturing;
            label = muted ? "Unmute" : "Mute";
            if (muted) {
                fill_color = UI_TEXT;
                icon_color = UI_BG;
            }
        } else {
            label = view->capturing ? "Release to send" : "Hold to talk";
            fill_color = view->capturing ? UI_SUCCESS : UI_ACCENT;
            icon_color = UI_BG;
        }
        lv_obj_t *talk = call_button(s_call.controls, fill_color, fill_color == UI_BG_TERTIARY, label, BOARD_TARGET_TALK);
        mic_icon(talk, icon_color, muted);
    }
    lv_obj_t *end = call_button(s_call.controls, UI_DANGER, false, "End", BOARD_TARGET_END_CALL);
    lv_obj_center(text(end, &lv_font_montserrat_24, 0xFFFFFF, LV_SYMBOL_CLOSE));
}

static void build_call_screen(void) {
    memset(&s_call, 0, sizeof(s_call));
    lv_obj_t *screen = new_screen();
    build_header(screen, NULL, false, true);
    s_call.screen = screen;

    s_call.halo = plain(screen, CALL_HALO_EXTENT, CALL_HALO_EXTENT);
    lv_obj_set_pos(s_call.halo, CALL_HALO_CX - (CALL_HALO_EXTENT / 2), CALL_HALO_CY - (CALL_HALO_EXTENT / 2));
    tag(s_call.halo, BOARD_TARGET_MASCOT);
    for (int i = 0; i < 2; ++i) {
        s_call.ripples[i] = surface(s_call.halo, CALL_HALO_RING, CALL_HALO_RING, UI_ACCENT, LV_RADIUS_CIRCLE);
        lv_obj_add_flag(s_call.ripples[i], LV_OBJ_FLAG_HIDDEN);
    }
    s_call.ring = plain(s_call.halo, CALL_HALO_RING, CALL_HALO_RING);
    lv_obj_set_style_radius(s_call.ring, LV_RADIUS_CIRCLE, 0);
    hairline(s_call.ring, UI_HAIRLINE, UI_OPA_BORDER_LIGHT, 2);
    lv_obj_center(s_call.ring);
    s_call.mascot = mascot_view_create(s_call.halo, CALL_MASCOT_TILE, MASCOT_MOOD_IDLE);
    lv_obj_center(s_call.mascot);

    s_call.name = text(screen, &lv_font_montserrat_24, UI_TEXT, "");
    lv_obj_set_pos(s_call.name, CALL_COLUMN_X, 84);

    s_call.status = text(screen, &lv_font_montserrat_16, UI_TEXT_SECONDARY, "");
    lv_obj_set_pos(s_call.status, CALL_COLUMN_X, 118);

    s_call.caption = wrapped_text(screen, &lv_font_montserrat_14, UI_TEXT, CALL_COLUMN_W, "");
    lv_obj_set_pos(s_call.caption, CALL_COLUMN_X, 150);

    s_call.task = surface(screen, CALL_COLUMN_W, 26, UI_ACCENT, 13);
    lv_obj_set_style_bg_opa(s_call.task, 0x14, 0);
    hairline(s_call.task, UI_ACCENT, 0x24, 1);
    lv_obj_set_pos(s_call.task, CALL_COLUMN_X, 240);
    s_call.task_label = text(s_call.task, &lv_font_montserrat_12, UI_TEXT, "");
    lv_obj_align(s_call.task_label, LV_ALIGN_LEFT_MID, 12, 0);

    s_call.controls = plain(screen, CALL_COLUMN_W, 88);
    lv_obj_add_flag(s_call.controls, LV_OBJ_FLAG_OVERFLOW_VISIBLE);
    lv_obj_set_pos(s_call.controls, CALL_COLUMN_X, 276);
    lv_obj_set_flex_flow(s_call.controls, LV_FLEX_FLOW_ROW);
    lv_obj_set_flex_align(s_call.controls, LV_FLEX_ALIGN_SPACE_EVENLY, LV_FLEX_ALIGN_START, LV_FLEX_ALIGN_START);

    load_screen(screen);
}

void board_ui_show_call(const board_call_view_t *view) {
    const bool fresh = s_call.screen == NULL || s_call.screen != lv_scr_act();
    if (fresh) {
        build_call_screen();
    }
    mascot_view_set_mood(s_call.mascot, view->mood);
    set_single_line(s_call.name, view->name != NULL ? view->name : "NeoAgent", CALL_COLUMN_W);
    set_single_line(s_call.status, view->status != NULL ? view->status : "", CALL_COLUMN_W);
    set_caption(s_call.caption, view->caption != NULL ? view->caption : "", CALL_COLUMN_W);
    lv_obj_set_style_text_color(s_call.caption, lv_color_hex(view->caption_from_assistant ? UI_TEXT : UI_TEXT_SECONDARY), 0);

    if (view->task != NULL) {
        char task[NEOAGENT_VOICE_CAPTION_MAX];
        snprintf(task, sizeof(task), "Working: %s", view->task[0] != '\0' ? view->task : "in the background");
        set_single_line(s_call.task_label, task, CALL_COLUMN_W - 24);
        lv_obj_clear_flag(s_call.task, LV_OBJ_FLAG_HIDDEN);
    } else {
        lv_obj_add_flag(s_call.task, LV_OBJ_FLAG_HIDDEN);
    }

    if (fresh || view->phase != s_call.phase || view->hands_free != s_call.hands_free || view->capturing != s_call.capturing) {
        s_call.phase = view->phase;
        s_call.hands_free = view->hands_free;
        s_call.capturing = view->capturing;
        build_controls(view);
    }

    uint32_t pulse = 0;
    if (view->phase == BOARD_CALL_ACTIVE && view->speaking) {
        pulse = UI_ACCENT;
    } else if (view->phase == BOARD_CALL_ACTIVE && view->capturing) {
        pulse = UI_SUCCESS;
    }
    set_halo(pulse);
}

static lv_obj_t *list_row(lv_obj_t *parent, lv_coord_t y, const char *icon, const char *label, uint32_t label_color, board_target_t target) {
    lv_obj_t *row = surface(parent, BOARD_UI_WIDTH - (2 * UI_GUTTER), UI_ROW_HEIGHT, UI_BG_SECONDARY, 16);
    hairline(row, UI_HAIRLINE, UI_OPA_BORDER, 1);
    lv_obj_set_pos(row, UI_GUTTER, y);
    if (icon != NULL) {
        lv_obj_align(text(row, &lv_font_montserrat_16, UI_ACCENT, icon), LV_ALIGN_LEFT_MID, 18, 0);
    }
    lv_obj_align(text(row, &lv_font_montserrat_16, label_color, label), LV_ALIGN_LEFT_MID, icon != NULL ? 52 : 18, 0);
    tag(row, target);
    return row;
}

static lv_coord_t row_y(int index) {
    return UI_HEADER_HEIGHT + 8 + (index * (UI_ROW_HEIGHT + UI_ROW_GAP));
}

static void choice_row(lv_obj_t *screen, int index, const char *label, bool selected, board_target_t target) {
    lv_obj_t *row = list_row(screen, row_y(index), NULL, label, UI_TEXT, target);
    if (selected) {
        hairline(row, UI_ACCENT, LV_OPA_COVER, 1);
        lv_obj_set_style_bg_color(row, lv_color_mix(lv_color_hex(UI_ACCENT), lv_color_hex(UI_BG_SECONDARY), 0x24), 0);
    }
    lv_obj_t *radio = plain(row, 20, 20);
    lv_obj_set_style_radius(radio, LV_RADIUS_CIRCLE, 0);
    hairline(radio, selected ? UI_ACCENT : UI_TEXT_MUTED, LV_OPA_COVER, 2);
    lv_obj_align(radio, LV_ALIGN_RIGHT_MID, -18, 0);
    if (selected) {
        lv_obj_center(surface(radio, 8, 8, UI_ACCENT, LV_RADIUS_CIRCLE));
    }
}

static void action_button(lv_obj_t *screen, lv_coord_t y, const char *label, uint32_t fill_color, uint32_t label_color, board_target_t target) {
    lv_obj_t *button = surface(screen, BOARD_UI_WIDTH - (2 * UI_GUTTER), 48, fill_color, 24);
    lv_obj_set_pos(button, UI_GUTTER, y);
    if (fill_color == UI_BG_TERTIARY) {
        hairline(button, UI_HAIRLINE, UI_OPA_BORDER_LIGHT, 1);
    }
    lv_obj_center(text(button, &lv_font_montserrat_16, label_color, label));
    tag(button, target);
}

static void text_card(lv_obj_t *screen, const char *headline, const char *body) {
    const lv_coord_t width = BOARD_UI_WIDTH - (2 * UI_GUTTER);
    lv_obj_t *card = surface(screen, width, BOARD_UI_HEIGHT - UI_HEADER_HEIGHT - 24, UI_BG_SECONDARY, 20);
    hairline(card, UI_HAIRLINE, UI_OPA_BORDER, 1);
    lv_obj_set_pos(card, UI_GUTTER, UI_HEADER_HEIGHT + 8);
    lv_obj_set_flex_flow(card, LV_FLEX_FLOW_COLUMN);
    lv_obj_set_style_pad_all(card, 20, 0);
    lv_obj_set_style_pad_row(card, 12, 0);
    wrapped_text(card, &lv_font_montserrat_16, UI_TEXT, width - 40, headline);
    wrapped_text(card, &lv_font_montserrat_14, UI_TEXT_SECONDARY, width - 40, body);
}

void board_ui_show_settings(const board_settings_view_t *view) {
    lv_obj_t *screen = new_screen();
    switch (view->page) {
        case BOARD_SETTINGS_NETWORK:
            build_header(screen, "Network", true, false);
            text_card(screen, view->headline, view->body);
            break;
        case BOARD_SETTINGS_DEVICE:
            build_header(screen, "Device", true, false);
            text_card(screen, view->headline, view->body);
            break;
        case BOARD_SETTINGS_UPDATE: {
            const bool beta = view->channel != NULL && strcmp(view->channel, "beta") == 0;
            build_header(screen, "Updates", true, false);
            choice_row(screen, 0, "Stable", !beta, BOARD_TARGET_CHANNEL_STABLE);
            choice_row(screen, 1, "Beta", beta, BOARD_TARGET_CHANNEL_BETA);
            action_button(screen, row_y(2) + 12, "Check for updates", UI_ACCENT, UI_BG, BOARD_TARGET_UPDATE_NOW);
            action_button(screen, row_y(2) + 72, "Re-enter setup mode", UI_BG_TERTIARY, UI_TEXT, BOARD_TARGET_SETUP_MODE);
            break;
        }
        case BOARD_SETTINGS_FORGET: {
            build_header(screen, "Forget device", true, false);
            const lv_coord_t width = BOARD_UI_WIDTH - (2 * UI_GUTTER);
            lv_obj_t *column = plain(screen, width, LV_SIZE_CONTENT);
            lv_obj_set_flex_flow(column, LV_FLEX_FLOW_COLUMN);
            lv_obj_set_style_pad_row(column, 12, 0);
            lv_obj_set_pos(column, UI_GUTTER, UI_HEADER_HEIGHT + 20);
            mascot_view_create(column, 64, MASCOT_MOOD_WAITING);
            wrapped_text(column, &lv_font_montserrat_16, UI_TEXT, width, "Clear pairing and Wi-Fi, then return to setup.");
            action_button(screen, BOARD_UI_HEIGHT - 48 - 24, "Forget this device", UI_DANGER, UI_BG, BOARD_TARGET_FORGET_CONFIRM);
            break;
        }
        case BOARD_SETTINGS_ROOT:
        default:
            build_header(screen, "Settings", true, false);
            list_row(screen, row_y(0), LV_SYMBOL_WIFI, "Network", UI_TEXT, BOARD_TARGET_SETTINGS_NETWORK);
            list_row(screen, row_y(1), LV_SYMBOL_REFRESH, "Updates", UI_TEXT, BOARD_TARGET_SETTINGS_UPDATE);
            list_row(screen, row_y(2), LV_SYMBOL_SETTINGS, "Device", UI_TEXT, BOARD_TARGET_SETTINGS_DEVICE);
            list_row(screen, row_y(3), LV_SYMBOL_TRASH, "Forget device", UI_DANGER, BOARD_TARGET_SETTINGS_FORGET);
            break;
    }
    load_screen(screen);
}

void board_ui_set_chrome(const neoagent_status_chrome_t *chrome, const char *time_text) {
    if (chrome != NULL) {
        s_chrome = *chrome;
    }
    strlcpy(s_time, time_text != NULL && time_text[0] != '\0' ? time_text : "--:--", sizeof(s_time));
    refresh_header();
}

// The topmost tagged control under the point. Controls take touches a few
// pixels outside their edge, which small targets on a wrist need.
#define UI_TOUCH_SLOP 4
static board_target_t find_target(lv_obj_t *obj, const lv_point_t *point) {
    if (lv_obj_has_flag(obj, LV_OBJ_FLAG_HIDDEN)) {
        return BOARD_TARGET_NONE;
    }
    for (int32_t i = (int32_t)lv_obj_get_child_cnt(obj) - 1; i >= 0; --i) {
        const board_target_t found = find_target(lv_obj_get_child(obj, i), point);
        if (found != BOARD_TARGET_NONE) {
            return found;
        }
    }
    if (!lv_obj_has_flag(obj, LV_OBJ_FLAG_USER_1)) {
        return BOARD_TARGET_NONE;
    }
    lv_area_t area;
    lv_obj_get_coords(obj, &area);
    lv_area_increase(&area, UI_TOUCH_SLOP, UI_TOUCH_SLOP);
    return _lv_area_is_point_on(&area, point, 0) ? (board_target_t)(uintptr_t)lv_obj_get_user_data(obj) : BOARD_TARGET_NONE;
}

board_target_t board_ui_hit_test(uint16_t x, uint16_t y) {
    const lv_point_t point = {.x = (lv_coord_t)x, .y = (lv_coord_t)y};
    lv_obj_t *screen = lv_scr_act();
    return screen != NULL ? find_target(screen, &point) : BOARD_TARGET_NONE;
}

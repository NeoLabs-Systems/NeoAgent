#include <math.h>
#include <stdlib.h>

#include "board_ui.h"
#include "esp_timer.h"

// Paints the mascot the way flutter_app/lib/src/mascot/neo_mascot.dart does:
// a dark tile with a lip, an edge highlight and an optional rim glow, and a
// screen of 9×9 dots. LVGL has no blur, so a lit dot's glow is two faint
// rings around its core.

#define FRAME_PERIOD_MS 33
// Room around the tile for the done bounce, the blocked shake and the rim glow.
#define VIEW_MARGIN 0.15f

#define COLOR_GOLD 0xE1B052
#define COLOR_ALERT 0xDE8A78
#define COLOR_LIP 0x070B09
#define COLOR_SCREEN 0x030504
#define COLOR_UNLIT 0x17201A
#define COLOR_EDGE 0xECEFE5
#define OPA_EDGE 0x24
#define COLOR_TILE_TOP 0x243029
#define COLOR_TILE_BOTTOM 0x0C120E

typedef struct {
    mascot_player_t player;
    lv_coord_t tile_side;
    lv_timer_t *timer;
} mascot_view_state_t;

static int64_t now_ms(void) {
    return esp_timer_get_time() / 1000;
}

static lv_opa_t opa_of(float fraction) {
    if (fraction <= 0.0f) {
        return LV_OPA_TRANSP;
    }
    return fraction >= 1.0f ? LV_OPA_COVER : (lv_opa_t)lroundf(fraction * 255.0f);
}

static lv_area_t area_of(float x, float y, float w, float h) {
    const lv_area_t area = {
        .x1 = (lv_coord_t)lroundf(x),
        .y1 = (lv_coord_t)lroundf(y),
        .x2 = (lv_coord_t)(lroundf(x + w) - 1),
        .y2 = (lv_coord_t)(lroundf(y + h) - 1),
    };
    return area;
}

static void fill(lv_draw_ctx_t *ctx, float x, float y, float w, float h, float radius, lv_color_t color, lv_opa_t opa) {
    lv_draw_rect_dsc_t dsc;
    lv_draw_rect_dsc_init(&dsc);
    dsc.radius = (lv_coord_t)lroundf(radius);
    dsc.bg_color = color;
    dsc.bg_opa = opa;
    const lv_area_t area = area_of(x, y, w, h);
    lv_draw_rect(ctx, &dsc, &area);
}

static void dot(lv_draw_ctx_t *ctx, float cx, float cy, float radius, lv_color_t color, lv_opa_t opa) {
    fill(ctx, cx - radius, cy - radius, radius * 2.0f, radius * 2.0f, LV_RADIUS_CIRCLE, color, opa);
}

static void on_draw(lv_event_t *event) {
    lv_obj_t *view = lv_event_get_target(event);
    mascot_view_state_t *state = lv_obj_get_user_data(view);
    if (state == NULL) {
        return;
    }
    lv_draw_ctx_t *ctx = lv_event_get_draw_ctx(event);
    mascot_picture_t picture;
    mascot_player_sample(&state->player, now_ms(), &picture);

    lv_area_t coords;
    lv_obj_get_coords(view, &coords);
    const float side = (float)state->tile_side;
    const float lip = side * 0.025f;
    const float tile_side = side - lip;
    // The tile sits at the top of a `side` square centred in the view, with
    // the lip showing below it; the tile moves and scales around its centre.
    const float centre_x = (float)(coords.x1 + coords.x2 + 1) / 2.0f;
    const float centre_y = (float)(coords.y1 + coords.y2 + 1) / 2.0f - (lip / 2.0f);
    const float rest_pitch = tile_side * 0.88f * 10.0f / 102.0f;
    const float scale = picture.scale;
    const float ts = tile_side * scale;
    const float left = centre_x + (picture.shift * rest_pitch) - (ts / 2.0f);
    const float top = centre_y - (ts / 2.0f);
    const float radius = ts * 0.33f;
    const lv_color_t lit = lv_color_mix(lv_color_hex(COLOR_ALERT), lv_color_hex(COLOR_GOLD), opa_of(picture.alert));

    if (picture.rim > 0.01f) {
        lv_draw_rect_dsc_t glow;
        lv_draw_rect_dsc_init(&glow);
        glow.radius = (lv_coord_t)lroundf(radius);
        glow.bg_opa = LV_OPA_TRANSP;
        glow.shadow_color = lit;
        glow.shadow_width = (lv_coord_t)lroundf(ts * 0.08f);
        glow.shadow_opa = opa_of(0.35f * picture.rim);
        const lv_area_t area = area_of(left, top, ts, ts);
        lv_draw_rect(ctx, &glow, &area);
    }

    fill(ctx, left, top + (lip * scale), ts, ts, radius, lv_color_hex(COLOR_LIP), LV_OPA_COVER);

    lv_draw_rect_dsc_t tile;
    lv_draw_rect_dsc_init(&tile);
    tile.radius = (lv_coord_t)lroundf(radius);
    tile.bg_opa = LV_OPA_COVER;
    tile.bg_grad.dir = LV_GRAD_DIR_VER;
    tile.bg_grad.stops_count = 2;
    tile.bg_grad.stops[0].color = lv_color_hex(COLOR_TILE_TOP);
    tile.bg_grad.stops[0].frac = 0;
    tile.bg_grad.stops[1].color = lv_color_hex(COLOR_TILE_BOTTOM);
    tile.bg_grad.stops[1].frac = 255;
    tile.border_side = LV_BORDER_SIDE_FULL;
    if (picture.rim > 0.01f) {
        tile.border_color = lit;
        tile.border_width = (lv_coord_t)fmaxf(1.0f, lroundf(ts * 0.022f));
        tile.border_opa = opa_of(0.75f * picture.rim);
    } else {
        tile.border_color = lv_color_hex(COLOR_EDGE);
        tile.border_width = (lv_coord_t)fmaxf(1.0f, lroundf(ts * 0.012f));
        tile.border_opa = OPA_EDGE;
    }
    const lv_area_t tile_area = area_of(left, top, ts, ts);
    lv_draw_rect(ctx, &tile, &tile_area);

    const float inset = ts * 0.06f;
    const float screen_side = ts - (2.0f * inset);
    fill(ctx, left + inset, top + inset, screen_side, screen_side, ts * 0.267f, lv_color_hex(COLOR_SCREEN), LV_OPA_COVER);

    const float pitch = screen_side * 10.0f / 102.0f;
    const float first = screen_side * 11.0f / 102.0f;
    const lv_color_t unlit = lv_color_hex(COLOR_UNLIT);
    for (int y = 0; y < MASCOT_GRID; ++y) {
        for (int x = 0; x < MASCOT_GRID; ++x) {
            const float cx = left + inset + first + ((float)x * pitch);
            const float cy = top + inset + first + ((float)y * pitch);
            float level = picture.dots[(y * MASCOT_GRID) + x];
            level = level < 0.0f ? 0.0f : (level > 1.0f ? 1.0f : level);
            dot(ctx, cx, cy, pitch * 0.21f, unlit, LV_OPA_COVER);
            if (level > 0.02f) {
                dot(ctx, cx, cy, pitch * 0.56f, lit, opa_of(0.10f * level));
                dot(ctx, cx, cy, pitch * 0.46f, lit, opa_of(0.22f * level));
                dot(ctx, cx, cy, pitch * 0.36f, lit, opa_of(level));
            }
        }
    }
}

static void on_frame(lv_timer_t *timer) {
    lv_obj_t *view = timer->user_data;
    mascot_view_state_t *state = lv_obj_get_user_data(view);
    if (mascot_player_tick(&state->player, now_ms())) {
        lv_obj_invalidate(view);
    }
}

static void on_delete(lv_event_t *event) {
    mascot_view_state_t *state = lv_obj_get_user_data(lv_event_get_target(event));
    if (state != NULL) {
        lv_timer_del(state->timer);
        free(state);
    }
}

lv_obj_t *mascot_view_create(lv_obj_t *parent, lv_coord_t tile_side, mascot_mood_t mood) {
    lv_obj_t *view = lv_obj_create(parent);
    lv_obj_remove_style_all(view);
    const lv_coord_t extent = tile_side + (2 * (lv_coord_t)lroundf((float)tile_side * VIEW_MARGIN));
    lv_obj_set_size(view, extent, extent);
    lv_obj_clear_flag(view, LV_OBJ_FLAG_SCROLLABLE | LV_OBJ_FLAG_CLICKABLE);

    mascot_view_state_t *state = calloc(1, sizeof(*state));
    if (state == NULL) {
        return view;
    }
    state->tile_side = tile_side;
    mascot_player_init(&state->player, mood, now_ms());
    lv_obj_set_user_data(view, state);
    state->timer = lv_timer_create(on_frame, FRAME_PERIOD_MS, view);
    lv_obj_add_event_cb(view, on_draw, LV_EVENT_DRAW_MAIN, NULL);
    lv_obj_add_event_cb(view, on_delete, LV_EVENT_DELETE, NULL);
    return view;
}

void mascot_view_set_mood(lv_obj_t *view, mascot_mood_t mood) {
    mascot_view_state_t *state = lv_obj_get_user_data(view);
    if (state != NULL) {
        mascot_player_set_mood(&state->player, mood, now_ms());
        lv_obj_invalidate(view);
    }
}

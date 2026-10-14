#include <stddef.h>
#include <string.h>

#include "mascot_private.h"

// Frame tables from flutter_app/lib/src/mascot/mascot_frames.dart. Rows use
// `#` for a lit dot, `-` for half, `+` for a quarter and `.` off.

#define DEFAULT_HOLD_MS 400
#define DEFAULT_FADE_MS 120
#define COMET_RING_LENGTH (4 * (MASCOT_GRID - 1))

typedef struct {
    const char *rows[MASCOT_GRID];
    uint16_t hold_ms;
    bool alert;
    float shift;
    float scale;
    float rim;
} frame_spec_t;

static const frame_spec_t IDLE_SPEC[] = {
    {.rows = {".........", ".........", "..##.##..", "..##.##..", "..##.##..", ".........", ".........", ".........", "........."}},
};

static const frame_spec_t BLINK_SPEC[] = {
    {.rows = {".........", ".........", ".........", "..##.##..", "..##.##..", ".........", ".........", ".........", "........."}, .hold_ms = 50},
    {.rows = {".........", ".........", ".........", ".........", "..##.##..", ".........", ".........", ".........", "........."}, .hold_ms = 80},
    {.rows = {".........", ".........", ".........", "..##.##..", "..##.##..", ".........", ".........", ".........", "........."}, .hold_ms = 50},
};

static const frame_spec_t GLANCE_LEFT_SPEC[] = {
    {.rows = {".........", ".........", ".##.##...", ".##.##...", ".##.##...", ".........", ".........", ".........", "........."}, .hold_ms = 900},
};

static const frame_spec_t GLANCE_RIGHT_SPEC[] = {
    {.rows = {".........", ".........", "...##.##.", "...##.##.", "...##.##.", ".........", ".........", ".........", "........."}, .hold_ms = 900},
};

static const frame_spec_t LISTENING_SPEC[] = {
    {.rows = {".........", ".........", "..##.##..", "..##.##..", "..##.##..", ".........", "...#.#...", "..#####..", "........."}, .hold_ms = 120},
    {.rows = {".........", ".........", "..##.##..", "..##.##..", "..##.##..", ".........", "..#.#.#..", "..#####..", "........."}, .hold_ms = 120},
    {.rows = {".........", ".........", "..##.##..", "..##.##..", "..##.##..", ".........", "...###...", "..#####..", "........."}, .hold_ms = 120},
    {.rows = {".........", ".........", "..##.##..", "..##.##..", "..##.##..", ".........", "....#....", "..#####..", "........."}, .hold_ms = 120},
    {.rows = {".........", ".........", "..##.##..", "..##.##..", "..##.##..", ".........", "..##.##..", "..#####..", "........."}, .hold_ms = 120},
    {.rows = {".........", ".........", "..##.##..", "..##.##..", "..##.##..", ".........", "....#....", "...###...", "........."}, .hold_ms = 120},
};

static const frame_spec_t THINKING_SPEC[] = {
    {.rows = {".........", "...##.##.", "...##.##.", "...##.##.", ".........", ".........", "...#++...", ".........", "........."}, .hold_ms = 280},
    {.rows = {".........", "...##.##.", "...##.##.", "...##.##.", ".........", ".........", "...+#+...", ".........", "........."}, .hold_ms = 280},
    {.rows = {".........", "...##.##.", "...##.##.", "...##.##.", ".........", ".........", "...++#...", ".........", "........."}, .hold_ms = 280},
    {.rows = {".........", "...##.##.", "...##.##.", "...##.##.", ".........", ".........", "...+++...", ".........", "........."}, .hold_ms = 280},
};

static const frame_spec_t WAITING_SPEC[] = {
    {.rows = {".........", "..##.##..", "..##.##..", "..##.##..", "..##.##..", ".........", ".........", "...###...", "........."}, .hold_ms = 530, .rim = 1},
    {.rows = {".........", "..##.##..", "..##.##..", "..##.##..", "..##.##..", ".........", ".........", ".........", "........."}, .hold_ms = 530, .rim = 0.35f},
};

#define BLOCKED_ROWS {".........", ".........", ".#.#.#.#.", "..#...#..", ".#.#.#.#.", ".........", "....#....", "...#.#...", "........."}
static const frame_spec_t BLOCKED_SPEC[] = {
    {.rows = BLOCKED_ROWS, .hold_ms = 60, .alert = true, .shift = -0.6f, .rim = 0.6f},
    {.rows = BLOCKED_ROWS, .hold_ms = 60, .alert = true, .shift = 0.6f, .rim = 0.6f},
    {.rows = BLOCKED_ROWS, .hold_ms = 60, .alert = true, .shift = -0.4f, .rim = 0.6f},
    {.rows = BLOCKED_ROWS, .hold_ms = 2200, .alert = true, .rim = 0.6f},
};

#define DONE_ROWS {".........", ".........", "..#...#..", ".#.#.#.#.", ".........", ".........", "..#...#..", "...###...", "........."}
static const frame_spec_t DONE_SPEC[] = {
    {.rows = DONE_ROWS, .hold_ms = 110, .scale = 1.12f},
    {.rows = DONE_ROWS, .hold_ms = 110, .scale = 0.96f},
    {.rows = DONE_ROWS},
};

static const frame_spec_t ASLEEP_SPEC[] = {
    {.rows = {"......---", ".......-.", "......---", ".........", "..--.--..", ".........", ".........", ".........", "........."}, .hold_ms = 1600},
    {.rows = {".........", ".........", ".........", ".........", "..--.--..", ".........", ".........", ".........", "........."}, .hold_ms = 1600},
};

static const char *const COMET_EYES[MASCOT_GRID] = {
    ".........", ".........", ".........", ".........", ".###.###.", ".........", ".........", ".........", ".........",
};

static mascot_frame_t s_idle[1];
static mascot_frame_t s_blink[3];
static mascot_frame_t s_glance_left[1];
static mascot_frame_t s_glance_right[1];
static mascot_frame_t s_listening[6];
static mascot_frame_t s_thinking[4];
static mascot_frame_t s_working[COMET_RING_LENGTH];
static mascot_frame_t s_waiting[2];
static mascot_frame_t s_blocked[4];
static mascot_frame_t s_done[3];
static mascot_frame_t s_asleep[2];

static mascot_clip_t s_clips[MASCOT_MOOD_ASLEEP + 1];
static mascot_clip_t s_blink_clip;
static mascot_clip_t s_glance_left_clip;
static mascot_clip_t s_glance_right_clip;
static bool s_built;

static void parse_rows(const char *const rows[MASCOT_GRID], uint8_t dots[MASCOT_DOTS]) {
    for (int y = 0; y < MASCOT_GRID; ++y) {
        for (int x = 0; x < MASCOT_GRID; ++x) {
            uint8_t level = 0;
            switch (rows[y][x]) {
                case '#':
                    level = 255;
                    break;
                case '-':
                    level = 128;
                    break;
                case '+':
                    level = 64;
                    break;
                default:
                    break;
            }
            dots[y * MASCOT_GRID + x] = level;
        }
    }
}

static void build_frames(const frame_spec_t *specs, size_t count, mascot_frame_t *frames) {
    for (size_t i = 0; i < count; ++i) {
        parse_rows(specs[i].rows, frames[i].dots);
        frames[i].hold_ms = specs[i].hold_ms != 0 ? specs[i].hold_ms : DEFAULT_HOLD_MS;
        frames[i].alert = specs[i].alert;
        frames[i].shift = specs[i].shift;
        frames[i].scale = specs[i].scale != 0 ? specs[i].scale : 1;
        frames[i].rim = specs[i].rim;
    }
}

// Underscore eyes with a comet running round the edge of the screen.
static void build_comet(void) {
    int ring[COMET_RING_LENGTH];
    int n = 0;
    for (int x = 0; x < MASCOT_GRID; ++x) {
        ring[n++] = x;
    }
    for (int y = 1; y < MASCOT_GRID; ++y) {
        ring[n++] = y * MASCOT_GRID + MASCOT_GRID - 1;
    }
    for (int x = MASCOT_GRID - 2; x >= 0; --x) {
        ring[n++] = (MASCOT_GRID - 1) * MASCOT_GRID + x;
    }
    for (int y = MASCOT_GRID - 2; y >= 1; --y) {
        ring[n++] = y * MASCOT_GRID;
    }

    uint8_t eyes[MASCOT_DOTS];
    parse_rows(COMET_EYES, eyes);
    for (int head = 0; head < COMET_RING_LENGTH; ++head) {
        mascot_frame_t *frame = &s_working[head];
        memcpy(frame->dots, eyes, sizeof(eyes));
        frame->dots[ring[head]] = 255;
        frame->dots[ring[(head + COMET_RING_LENGTH - 1) % COMET_RING_LENGTH]] = 128;
        frame->dots[ring[(head + COMET_RING_LENGTH - 2) % COMET_RING_LENGTH]] = 51;
        frame->hold_ms = 45;
        frame->alert = false;
        frame->shift = 0;
        frame->scale = 1;
        frame->rim = 0;
    }
}

#define SET_CLIP(clip, table, loop_, fade)                        \
    (clip) = (mascot_clip_t){                                      \
        .frames = (table),                                         \
        .count = (uint8_t)(sizeof(table) / sizeof((table)[0])),    \
        .loop = (loop_),                                           \
        .fade_ms = (fade),                                         \
    }

static void build_clips(void) {
    if (s_built) {
        return;
    }
    build_frames(IDLE_SPEC, 1, s_idle);
    build_frames(BLINK_SPEC, 3, s_blink);
    build_frames(GLANCE_LEFT_SPEC, 1, s_glance_left);
    build_frames(GLANCE_RIGHT_SPEC, 1, s_glance_right);
    build_frames(LISTENING_SPEC, 6, s_listening);
    build_frames(THINKING_SPEC, 4, s_thinking);
    build_comet();
    build_frames(WAITING_SPEC, 2, s_waiting);
    build_frames(BLOCKED_SPEC, 4, s_blocked);
    build_frames(DONE_SPEC, 3, s_done);
    build_frames(ASLEEP_SPEC, 2, s_asleep);

    SET_CLIP(s_clips[MASCOT_MOOD_IDLE], s_idle, true, DEFAULT_FADE_MS);
    SET_CLIP(s_clips[MASCOT_MOOD_LISTENING], s_listening, true, 90);
    SET_CLIP(s_clips[MASCOT_MOOD_THINKING], s_thinking, true, DEFAULT_FADE_MS);
    SET_CLIP(s_clips[MASCOT_MOOD_WORKING], s_working, true, 60);
    SET_CLIP(s_clips[MASCOT_MOOD_WAITING], s_waiting, true, 160);
    SET_CLIP(s_clips[MASCOT_MOOD_BLOCKED], s_blocked, true, 60);
    SET_CLIP(s_clips[MASCOT_MOOD_DONE], s_done, false, 110);
    SET_CLIP(s_clips[MASCOT_MOOD_ASLEEP], s_asleep, true, 600);
    SET_CLIP(s_blink_clip, s_blink, false, 50);
    SET_CLIP(s_glance_left_clip, s_glance_left, false, DEFAULT_FADE_MS);
    SET_CLIP(s_glance_right_clip, s_glance_right, false, DEFAULT_FADE_MS);
    s_built = true;
}

const mascot_clip_t *mascot_clip_for_mood(mascot_mood_t mood) {
    build_clips();
    if ((int)mood < 0 || mood > MASCOT_MOOD_ASLEEP) {
        mood = MASCOT_MOOD_IDLE;
    }
    return &s_clips[mood];
}

const mascot_clip_t *mascot_idle_move_clip(uint32_t roll_percent) {
    build_clips();
    if (roll_percent >= 85) {
        return &s_glance_right_clip;
    }
    if (roll_percent >= 70) {
        return &s_glance_left_clip;
    }
    return &s_blink_clip;
}

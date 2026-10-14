#pragma once

#include <stdbool.h>
#include <stdint.h>

// The NeoAgent mascot: a dark tile whose screen is a 9×9 dot-matrix face.
// This is the firmware port of flutter_app/lib/src/mascot/ — the frame tables,
// the clip player and the mood stabilizer. Change both when a face changes.
//
// Nothing here draws; the display layer samples the player and paints it.

#define MASCOT_GRID 9
#define MASCOT_DOTS (MASCOT_GRID * MASCOT_GRID)

typedef enum {
    MASCOT_MOOD_IDLE = 0,
    MASCOT_MOOD_LISTENING,
    MASCOT_MOOD_THINKING,
    MASCOT_MOOD_WORKING,
    MASCOT_MOOD_WAITING,
    MASCOT_MOOD_BLOCKED,
    MASCOT_MOOD_DONE,
    MASCOT_MOOD_ASLEEP,
} mascot_mood_t;

// One picture on the matrix, plus how the tile around it moves while it is up.
typedef struct {
    uint8_t dots[MASCOT_DOTS];  // Brightness per dot, row-major, 0–255.
    uint16_t hold_ms;           // How long the frame stays up.
    bool alert;                 // Dots and rim use the alert color, not gold.
    float shift;                // Horizontal nudge of the tile, in dot pitches.
    float scale;                // Tile scale around its centre.
    float rim;                  // Glow on the tile's edge, 0–1.
} mascot_frame_t;

typedef struct {
    const mascot_frame_t *frames;
    uint8_t count;
    bool loop;         // Otherwise the last frame stays up.
    uint16_t fade_ms;  // Cross-fade between consecutive frames.
} mascot_clip_t;

// What is on screen at one instant.
typedef struct {
    float dots[MASCOT_DOTS];  // 0–1.
    float alert;              // 0 gold … 1 alert color.
    float shift;
    float scale;
    float rim;
} mascot_picture_t;

// Steps through the current mood's clip on a clock the caller supplies, and
// cross-fades from whatever is on screen, even mid-fade, so the face never
// jumps. At rest it plays a blink or a glance every few seconds.
typedef struct {
    mascot_picture_t from;
    mascot_picture_t to;
    int64_t fade_started_ms;
    uint16_t fade_ms;
    bool settled;             // The finished frame has been reported as a change.
    const mascot_clip_t *clip;
    uint8_t index;
    int64_t step_at_ms;       // 0 when the clip has nothing more to show.
    bool back_to_idle;        // The clip is a blink or glance.
    int64_t idle_move_at_ms;  // 0 when no idle move is scheduled.
    mascot_mood_t mood;
    uint32_t rng;
} mascot_player_t;

// Turns the mood read straight off live state into the mood on screen:
// thinking/working hold briefly before giving way, and done/blocked play once
// per moment (the run or error they belong to) and then settle to idle.
typedef struct {
    mascot_mood_t shown;
    int64_t shown_since_ms;
    bool has_shown_since;
    bool seen;
    uint32_t played_moment;
    int64_t one_shot_until_ms;  // 0 when no done/blocked is playing.
} mascot_stabilizer_t;

const mascot_clip_t *mascot_clip_for_mood(mascot_mood_t mood);

void mascot_player_init(mascot_player_t *player, mascot_mood_t mood, int64_t now_ms);
void mascot_player_set_mood(mascot_player_t *player, mascot_mood_t mood, int64_t now_ms);
// Advances the clip. Returns true while the picture is changing.
bool mascot_player_tick(mascot_player_t *player, int64_t now_ms);
void mascot_player_sample(const mascot_player_t *player, int64_t now_ms, mascot_picture_t *out);

void mascot_stabilizer_init(mascot_stabilizer_t *stabilizer);
// Feeds the latest raw mood; `moment` identifies the occurrence for done and
// blocked (0 for none). Returns how many ms until it should be called again to
// settle a pending change, or -1 when nothing is pending.
int32_t mascot_stabilizer_update(mascot_stabilizer_t *stabilizer, mascot_mood_t raw, uint32_t moment, int64_t now_ms);

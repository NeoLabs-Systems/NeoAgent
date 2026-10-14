#include <string.h>

#include "mascot_private.h"

// Timing from flutter_app/lib/src/mascot/neo_mascot.dart and mascot_mood.dart.
#define MOOD_FADE_MS 180
#define IDLE_RETURN_FADE_MS 90
#define IDLE_MOVE_MIN_WAIT_MS 2600
#define IDLE_MOVE_WAIT_SPREAD_MS 3800
#define ACTIVITY_DWELL_MS 450
#define DONE_HOLD_MS 2400
#define BLOCKED_HOLD_MS 6000

static float ease_out_cubic(float t) {
    const float u = 1.0f - t;
    return 1.0f - (u * u * u);
}

static float mix_at(const mascot_player_t *player, int64_t now_ms) {
    if (player->fade_ms == 0) {
        return 1.0f;
    }
    float t = (float)(now_ms - player->fade_started_ms) / (float)player->fade_ms;
    if (t <= 0.0f) {
        return 0.0f;
    }
    if (t >= 1.0f) {
        return 1.0f;
    }
    return ease_out_cubic(t);
}

static float lerp(float a, float b, float t) {
    return a + ((b - a) * t);
}

static void blend(const mascot_picture_t *from, const mascot_picture_t *to, float t, mascot_picture_t *out) {
    for (int i = 0; i < MASCOT_DOTS; ++i) {
        out->dots[i] = lerp(from->dots[i], to->dots[i], t);
    }
    out->alert = lerp(from->alert, to->alert, t);
    out->shift = lerp(from->shift, to->shift, t);
    out->scale = lerp(from->scale, to->scale, t);
    out->rim = lerp(from->rim, to->rim, t);
}

// Freezes what is on screen as the new start and fades towards `frame`.
static void show(mascot_player_t *player, const mascot_frame_t *frame, uint16_t fade_ms, int64_t now_ms) {
    mascot_picture_t current;
    blend(&player->from, &player->to, mix_at(player, now_ms), &current);
    player->from = current;
    for (int i = 0; i < MASCOT_DOTS; ++i) {
        player->to.dots[i] = frame->dots[i] / 255.0f;
    }
    player->to.alert = frame->alert ? 1.0f : 0.0f;
    player->to.shift = frame->shift;
    player->to.scale = frame->scale;
    player->to.rim = frame->rim;
    player->fade_ms = fade_ms;
    player->fade_started_ms = now_ms;
    player->settled = false;
}

static void schedule_step(mascot_player_t *player, int64_t now_ms) {
    const mascot_clip_t *clip = player->clip;
    const uint16_t hold_ms = clip->frames[player->index].hold_ms;
    const bool last = player->index == clip->count - 1;
    if (last && !clip->loop) {
        player->step_at_ms = player->back_to_idle ? now_ms + hold_ms : 0;
        return;
    }
    player->step_at_ms = clip->count > 1 ? now_ms + hold_ms : 0;
}

static void play(mascot_player_t *player, const mascot_clip_t *clip, uint16_t fade_ms, bool back_to_idle, int64_t now_ms) {
    player->clip = clip;
    player->index = 0;
    player->back_to_idle = back_to_idle;
    show(player, &clip->frames[0], fade_ms, now_ms);
    schedule_step(player, now_ms);
}

static uint32_t next_random(mascot_player_t *player) {
    uint32_t x = player->rng;
    x ^= x << 13;
    x ^= x >> 17;
    x ^= x << 5;
    player->rng = x;
    return x;
}

static void schedule_idle_move(mascot_player_t *player, int64_t now_ms) {
    player->idle_move_at_ms = now_ms + IDLE_MOVE_MIN_WAIT_MS + (next_random(player) % IDLE_MOVE_WAIT_SPREAD_MS);
}

static void enter(mascot_player_t *player, mascot_mood_t mood, uint16_t fade_ms, int64_t now_ms) {
    player->mood = mood;
    player->step_at_ms = 0;
    player->idle_move_at_ms = 0;
    play(player, mascot_clip_for_mood(mood), fade_ms, false, now_ms);
    if (mood == MASCOT_MOOD_IDLE) {
        schedule_idle_move(player, now_ms);
    }
}

void mascot_player_init(mascot_player_t *player, mascot_mood_t mood, int64_t now_ms) {
    memset(player, 0, sizeof(*player));
    player->from.scale = 1.0f;
    player->to.scale = 1.0f;
    player->rng = ((uint32_t)now_ms * 2654435761u) | 1u;
    enter(player, mood, 0, now_ms);
}

void mascot_player_set_mood(mascot_player_t *player, mascot_mood_t mood, int64_t now_ms) {
    if (mood != player->mood) {
        enter(player, mood, MOOD_FADE_MS, now_ms);
    }
}

bool mascot_player_tick(mascot_player_t *player, int64_t now_ms) {
    bool changed = false;
    if (player->step_at_ms != 0 && now_ms >= player->step_at_ms) {
        const mascot_clip_t *clip = player->clip;
        if (player->index == clip->count - 1 && !clip->loop) {
            // A blink or glance has finished; look ahead again.
            player->step_at_ms = 0;
            play(player, mascot_clip_for_mood(MASCOT_MOOD_IDLE), IDLE_RETURN_FADE_MS, false, now_ms);
            schedule_idle_move(player, now_ms);
        } else {
            player->index = (uint8_t)((player->index + 1) % clip->count);
            show(player, &clip->frames[player->index], clip->fade_ms, now_ms);
            schedule_step(player, now_ms);
        }
        changed = true;
    }
    if (player->idle_move_at_ms != 0 && now_ms >= player->idle_move_at_ms) {
        player->idle_move_at_ms = 0;
        const mascot_clip_t *move = mascot_idle_move_clip(next_random(player) % 100);
        play(player, move, move->fade_ms, true, now_ms);
        changed = true;
    }
    if (!player->settled) {
        // One more change after the fade ends, so the finished frame is drawn.
        player->settled = player->fade_ms == 0 || now_ms - player->fade_started_ms >= player->fade_ms;
        changed = true;
    }
    return changed;
}

void mascot_player_sample(const mascot_player_t *player, int64_t now_ms, mascot_picture_t *out) {
    blend(&player->from, &player->to, mix_at(player, now_ms), out);
}

void mascot_stabilizer_init(mascot_stabilizer_t *stabilizer) {
    memset(stabilizer, 0, sizeof(*stabilizer));
    stabilizer->shown = MASCOT_MOOD_IDLE;
}

static void stabilizer_show(mascot_stabilizer_t *stabilizer, mascot_mood_t mood, int64_t now_ms) {
    if (mood == stabilizer->shown && stabilizer->has_shown_since) {
        return;
    }
    stabilizer->shown = mood;
    stabilizer->shown_since_ms = now_ms;
    stabilizer->has_shown_since = true;
}

static bool is_activity(mascot_mood_t mood) {
    return mood == MASCOT_MOOD_THINKING || mood == MASCOT_MOOD_WORKING;
}

int32_t mascot_stabilizer_update(mascot_stabilizer_t *stabilizer, mascot_mood_t raw, uint32_t moment, int64_t now_ms) {
    const bool first = !stabilizer->seen;
    stabilizer->seen = true;

    if (raw == MASCOT_MOOD_DONE || raw == MASCOT_MOOD_BLOCKED) {
        // A moment already there on the first update happened before the
        // mascot existed and does not play.
        if (first) {
            stabilizer->played_moment = moment;
        } else if (moment != stabilizer->played_moment) {
            stabilizer->played_moment = moment;
            stabilizer->one_shot_until_ms = now_ms + (raw == MASCOT_MOOD_DONE ? DONE_HOLD_MS : BLOCKED_HOLD_MS);
            stabilizer_show(stabilizer, raw, now_ms);
        }
        const int64_t until = stabilizer->one_shot_until_ms;
        if (stabilizer->shown == raw && until != 0 && now_ms < until) {
            return (int32_t)(until - now_ms);
        }
        stabilizer->one_shot_until_ms = 0;
        stabilizer_show(stabilizer, MASCOT_MOOD_IDLE, now_ms);
        return -1;
    }

    stabilizer->one_shot_until_ms = 0;
    // A run flips between reasoning and short tool calls several times a
    // second; hold thinking/working briefly so the face does not strobe.
    if (raw != stabilizer->shown &&
        stabilizer->has_shown_since &&
        is_activity(stabilizer->shown) &&
        (is_activity(raw) || raw == MASCOT_MOOD_IDLE)) {
        const int64_t remaining = ACTIVITY_DWELL_MS - (now_ms - stabilizer->shown_since_ms);
        if (remaining > 0) {
            return (int32_t)remaining;
        }
    }
    stabilizer_show(stabilizer, raw, now_ms);
    return -1;
}

#pragma once

#include "mascot.h"

// A blink (most rolls) or a look aside, for a mascot at rest; roll is 0–99.
const mascot_clip_t *mascot_idle_move_clip(uint32_t roll_percent);

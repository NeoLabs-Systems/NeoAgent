#include "pcm_resampler.h"

#include <string.h>

#define Q16_ONE (1u << 16)

void pcm_resampler_init(pcm_resampler_t *resampler, uint32_t in_rate, uint32_t out_rate) {
    memset(resampler, 0, sizeof(*resampler));
    resampler->passthrough = in_rate == out_rate;
    resampler->lowpass = in_rate > out_rate;
    resampler->step_q16 = (uint32_t)(((uint64_t)in_rate << 16) / out_rate);
}

size_t pcm_resampler_max_output(uint32_t in_rate, uint32_t out_rate, size_t in_samples) {
    return (size_t)(((uint64_t)in_samples * out_rate + in_rate - 1) / in_rate) + 2;
}

size_t pcm_resampler_process(pcm_resampler_t *resampler, const int16_t *in, size_t in_samples, int16_t *out) {
    if (resampler->passthrough) {
        memcpy(out, in, in_samples * sizeof(int16_t));
        return in_samples;
    }
    size_t written = 0;
    for (size_t i = 0; i < in_samples; ++i) {
        int32_t current = in[i];
        if (resampler->lowpass) {
            // [1 2 1] / 4: about -12 dB at a third of the input rate.
            const int32_t filtered = (resampler->history[0] + (2 * resampler->history[1]) + current) / 4;
            resampler->history[0] = resampler->history[1];
            resampler->history[1] = current;
            current = filtered;
        }
        while (resampler->pos_q16 < Q16_ONE) {
            const int32_t delta = current - resampler->prev;
            out[written++] = (int16_t)(resampler->prev + ((delta * (int32_t)resampler->pos_q16) >> 16));
            resampler->pos_q16 += resampler->step_q16;
        }
        resampler->pos_q16 -= Q16_ONE;
        resampler->prev = current;
    }
    return written;
}

#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

// Streams 16-bit mono PCM from one sample rate to another by linear
// interpolation, carrying state across chunks. Downsampling runs a short
// low-pass first so the dropped band does not fold back into speech.
typedef struct {
    bool passthrough;
    bool lowpass;
    uint32_t step_q16;  // Input samples per output sample, Q16.
    uint32_t pos_q16;   // Where the next output falls between `prev` and the next input.
    int32_t prev;
    int32_t history[2];
} pcm_resampler_t;

void pcm_resampler_init(pcm_resampler_t *resampler, uint32_t in_rate, uint32_t out_rate);
size_t pcm_resampler_max_output(uint32_t in_rate, uint32_t out_rate, size_t in_samples);
// `out` needs room for pcm_resampler_max_output() samples. Returns how many were written.
size_t pcm_resampler_process(pcm_resampler_t *resampler, const int16_t *in, size_t in_samples, int16_t *out);

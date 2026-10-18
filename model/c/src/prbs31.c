#include "prbs31.h"

#include <stddef.h>

static const uint8_t taps[Q_TAPS] = {PRBS_ORDER - 1, 27};

static uint32_t state;

void prbs31_reset(uint32_t seed)
{
    state = seed & PRBS_STATE_MASK;
}

void prbs31_gen(uint32_t output[PRBS_WORDS])
{
    for (uint8_t word = 0; word < PRBS_WORDS; word++)
    {
        output[word] = 0;
    }

    for (size_t bit_index = 0; bit_index < PRBS_PARALLELISM; bit_index++)
    {
        uint32_t output_bit = (state >> PRBS_OUTPUT_BIT) & UINT32_C(1);
        uint32_t feedback = 0;

        for (uint8_t tap_index = 0; tap_index < Q_TAPS; tap_index++)
        {
            feedback ^= (state >> taps[tap_index]) & UINT32_C(1);
        }

        output[bit_index / 32] |= output_bit << (bit_index % 32);
        state = ((state << 1) & PRBS_STATE_MASK) | feedback;
    }
}

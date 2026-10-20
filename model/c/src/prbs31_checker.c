#include "prbs31_checker.h"

#include <stddef.h>

static const uint8_t taps[Q_TAPS] = {PRBS_ORDER - 1, 27};

static uint32_t state;
static uint8_t locked;

void prbs31_checker_reset(void)
{
    state = 0;
    locked = 0;
}

void prbs31_checker(const uint32_t i_data[PRBS_WORDS], uint8_t *o_locked, uint32_t *o_error_count)
{
    uint32_t expected[PRBS_WORDS] = {0};
    uint32_t error_count = 0;
    uint32_t seed_candidate = 0;

    //! Seeder
    if (!locked)
    {
        for (uint8_t bit_index = 0; bit_index < PRBS_ORDER; bit_index++)
        {
            uint32_t received_bit = (i_data[0] >> (bit_index)) & UINT32_C(1);

            seed_candidate |= received_bit << (PRBS_ORDER - 1 - bit_index);
        }

        state = seed_candidate & PRBS_STATE_MASK;
    }

    //! PRBS
    for (size_t bit_index = 0; bit_index < PRBS_PARALLELISM; bit_index++)
    {
        uint32_t output_bit = (state >> PRBS_OUTPUT_BIT) & UINT32_C(1);
        uint32_t feedback = 0;

        for (uint8_t tap_index = 0; tap_index < Q_TAPS; tap_index++)
        {
            feedback ^= (state >> taps[tap_index]) & UINT32_C(1);
        }

        expected[bit_index / 32] |= output_bit << (bit_index % 32);
        state = ((state << 1) & PRBS_STATE_MASK) | feedback;
    }

    //! Error Count
    for (size_t bit_index = 0; bit_index < PRBS_PARALLELISM; bit_index++)
    {
        uint32_t error_word = i_data[bit_index / 32] ^ expected[bit_index / 32];

        error_count += (error_word >> (bit_index % 32)) & UINT32_C(1);
    }

    //! Lock condition
    if (!locked)
    {
        if ((seed_candidate != 0) && (error_count == 0))
        {
            locked = 1;
        }

        //! The acquistion payload is excluded from BER measurement.
        *o_error_count = 0;
    }
    else
    {
        *o_error_count = error_count;
    }

    *o_locked = locked;
}

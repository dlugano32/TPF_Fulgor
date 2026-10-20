#include "svdpi.h"

#include <stdint.h>

#include "prbs31_checker.h"

void prbs31_checker_reset_dpi(void)
{
    prbs31_checker_reset();
}

void prbs31_checker_dpi(const svBitVecVal *data, svBit *locked, unsigned int *error_count)
{
    uint32_t input_words[PRBS_WORDS];
    uint32_t model_error_count;
    uint8_t model_locked;

    for (uint8_t word = 0; word < PRBS_WORDS; word++)
    {
        input_words[word] = (uint32_t)data[word];
    }

    prbs31_checker(input_words, &model_locked, &model_error_count);

    *locked = (svBit)model_locked;
    *error_count = (unsigned int)model_error_count;
}

#include "svdpi.h"

#include <stdint.h>

#include "prbs31.h"

void prbs31_reset_dpi(const svBitVecVal *seed)
{
    prbs31_reset((uint32_t) seed[0]);
}

void prbs31_gen_dpi(svBitVecVal *output)
{
    uint32_t output_words[PRBS_WORDS];

    prbs31_gen(output_words);

    for (uint8_t word = 0; word < PRBS_WORDS; word++)
    {
        output[word] = (svBitVecVal) output_words[word];
    }
}

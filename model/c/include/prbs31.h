#ifndef PRBS31_H
#define PRBS31_H

#include <stdint.h>

#define Q_TAPS 2
#define PRBS_OUTPUT_BIT (PRBS_ORDER - 1)
#define PRBS_ORDER       31
#define PRBS_PARALLELISM 791
#define PRBS_WORDS       25
#define PRBS_STATE_MASK  0x7FFFFFFF

void prbs31_reset(uint32_t seed);
void prbs31_gen(uint32_t output[PRBS_WORDS]);

#endif

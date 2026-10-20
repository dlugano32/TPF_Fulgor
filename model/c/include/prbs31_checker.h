#ifndef PRBS31_CHECKER_H
#define PRBS31_CHECKER_H

#include <stdint.h>

#define Q_TAPS 2
#define PRBS_OUTPUT_BIT (PRBS_ORDER - 1)
#define PRBS_ORDER       31
#define PRBS_PARALLELISM 791
#define PRBS_WORDS       25
#define PRBS_STATE_MASK  0x7FFFFFFF

void prbs31_checker_reset(void);

void prbs31_checker(const uint32_t i_data[PRBS_WORDS], uint8_t *o_locked, uint32_t *o_error_count);

#endif

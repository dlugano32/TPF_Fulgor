#ifndef GF127_H
#define GF127_H

#include <stdint.h>

#define GF127_M               7
#define GF127_ORDER           127
#define GF127_ELEMENT_MASK    0x7F
#define GF127_REDUCTION_POLY  0x09   // x^7 = x^3 + 1

uint8_t gf127_multiply(uint8_t a, uint8_t b);
uint8_t gf127_square(uint8_t value);
uint8_t gf127_cube(uint8_t value);
uint8_t gf127_power(uint8_t base, uint8_t exponent);
uint8_t gf127_divide(uint8_t numerator, uint8_t denominator);
uint8_t gf127_log(uint8_t value);
uint8_t gf127_trace(uint8_t value);
uint8_t gf127_half_trace(uint8_t value);

#endif

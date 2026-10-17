#ifndef BCH_DECODER_H
#define BCH_DECODER_H

#include <stdint.h>

#define BCH_N                127
#define BCH_PARITY_BITS      14
#define GF_M                 7
#define GF_ORDER             127
#define GF_ELEMENT_MASK      0x7F
#define GF_REDUCTION_POLY    0x09   // x^7 = x^3 + 1
#define BCH_MESSAGE_WORDS    4
#define BCH_CODEWORD_WORDS   4
#define BCH_MAX_ERRORS       2
#define BCH_DECODER_FAILURE  UINT8_MAX

uint8_t bch_decoder(const uint32_t received[BCH_CODEWORD_WORDS], uint32_t error[BCH_CODEWORD_WORDS], uint32_t codeword[BCH_CODEWORD_WORDS], uint32_t message[BCH_MESSAGE_WORDS]);

#endif

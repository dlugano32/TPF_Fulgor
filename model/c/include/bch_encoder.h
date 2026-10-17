#ifndef BCH_ENCODER_H
#define BCH_ENCODER_H

#include <stdint.h>

#define BCH_MESSAGE_WORDS   4
#define BCH_CODEWORD_WORDS  4
#define BCH_PARITY_BITS     14
#define BCH_MESSAGE_BITS    113
#define BCH_GENERATOR_POLY  0x4377 // g(x) = x^14 + x^9 + x^8 + x^6 + x^5 + x^4 + x^2 + x + 1
#define BCH_PARITY_MASK     0x3FFF
#define BCH_GENERATOR_LOW   (BCH_GENERATOR_POLY & BCH_PARITY_MASK)


void bch_encoder(const uint32_t message[BCH_MESSAGE_WORDS], uint32_t codeword[BCH_CODEWORD_WORDS]);

#endif

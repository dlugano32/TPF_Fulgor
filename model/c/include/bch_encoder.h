#ifndef BCH_ENCODER_H
#define BCH_ENCODER_H

#include <stdint.h>

#define BCH_MESSAGE_WORDS  4
#define BCH_CODEWORD_WORDS 4
#define BCH_PARITY_BITS 14

void bch_encoder(const uint32_t message[BCH_MESSAGE_WORDS], uint32_t codeword[BCH_CODEWORD_WORDS]);

#endif

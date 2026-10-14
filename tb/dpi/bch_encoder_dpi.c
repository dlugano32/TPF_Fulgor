#include "svdpi.h"

#include <stdint.h>

#include "bch_encoder.h"

void bch_encode_dpi(const svBitVecVal *message, svBitVecVal *codeword)
{
    uint32_t message_words[BCH_MESSAGE_WORDS];
    uint32_t codeword_words[BCH_CODEWORD_WORDS];

    for (uint8_t i = 0; i < BCH_MESSAGE_WORDS; i++) {
        message_words[i] = (uint32_t) message[i];
    }

    bch_encoder(message_words, codeword_words);

    for (uint8_t i = 0; i < BCH_CODEWORD_WORDS; i++) {
        codeword[i] = (svBitVecVal) codeword_words[i];
    }
}

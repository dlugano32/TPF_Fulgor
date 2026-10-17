#include "svdpi.h"

#include <stdint.h>

#include "bch_decoder.h"

void bch_decode_dpi(
    const svBitVecVal *received,
    svBitVecVal *error,
    svBitVecVal *codeword,
    svBitVecVal *message,
    svBit *corrected,
    svBit *uncorrectable
)
{
    uint32_t received_words[BCH_CODEWORD_WORDS];
    uint32_t error_words[BCH_CODEWORD_WORDS];
    uint32_t codeword_words[BCH_CODEWORD_WORDS];
    uint32_t message_words[BCH_MESSAGE_WORDS];

    for (uint8_t i = 0; i < BCH_CODEWORD_WORDS; i++)
    {
        received_words[i] = (uint32_t) received[i];
    }

    uint8_t error_count = bch_decoder(
        received_words,
        error_words,
        codeword_words,
        message_words
    );

    for (uint8_t i = 0; i < BCH_CODEWORD_WORDS; i++)
    {
        error[i] = (svBitVecVal) error_words[i];
        codeword[i] = (svBitVecVal) codeword_words[i];
    }

    for (uint8_t i = 0; i < BCH_MESSAGE_WORDS; i++)
    {
        message[i] = (svBitVecVal) message_words[i];
    }

    *corrected = (error_count == 1 || error_count == 2);
    *uncorrectable = (error_count == BCH_DECODER_FAILURE);
}

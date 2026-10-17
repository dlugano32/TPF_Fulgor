#include "bch_encoder.h"

#include <stddef.h>

static uint8_t get_bit(const uint32_t value[BCH_MESSAGE_WORDS], uint8_t position)
{
    return (value[position / 32] >> (position % 32)) & 1;
}

static uint16_t calculate_parity(const uint32_t message[BCH_MESSAGE_WORDS])
{
    uint16_t remainder = 0;

    for (int16_t position = BCH_MESSAGE_BITS - 1; position >= 0; position--)
    {
        uint8_t feedback = ((remainder >> (BCH_PARITY_BITS - 1)) & 1) ^ get_bit(message, position);

        remainder = (remainder << 1) & BCH_PARITY_MASK;

        if (feedback != 0)
        {
            remainder ^= BCH_GENERATOR_LOW;
        }
    }

    return remainder;
}

void bch_encoder(const uint32_t message[BCH_MESSAGE_WORDS], uint32_t codeword[BCH_CODEWORD_WORDS])
{
    uint16_t parity = calculate_parity(message);

    codeword[0] = (message[0] << BCH_PARITY_BITS) | parity;
    codeword[1] = (message[1] << BCH_PARITY_BITS) | (message[0] >> 18);
    codeword[2] = (message[2] << BCH_PARITY_BITS) | (message[1] >> 18);
    codeword[3] = (message[3] << BCH_PARITY_BITS) | (message[2] >> 18);
}

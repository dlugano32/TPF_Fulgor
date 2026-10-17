#include "bch_decoder.h"
#include "gf127.h"

#include <stddef.h>

static uint8_t get_bit(const uint32_t value[BCH_CODEWORD_WORDS], uint8_t position)
{
    return (value[position / 32] >> (position % 32)) & 1;
}

static void set_bit(uint32_t value[BCH_CODEWORD_WORDS], uint8_t position)
{
    value[position / 32] |= UINT32_C(1) << (position % 32);
}

static void calculate_syn(const uint32_t received[BCH_CODEWORD_WORDS], uint8_t *syn1, uint8_t *syn3)
{
    uint8_t alpha1 = 1;
    uint8_t alpha3 = 1;

    *syn1 = 0;
    *syn3 = 0;

    for (uint8_t position = 0; position < BCH_N; position++)
    {
        if (get_bit(received, position) != 0)
        {
            *syn1 ^= alpha1;
            *syn3 ^= alpha3;
        }

        alpha1 = gf127_multiply(alpha1, 0x2);  // multiply by alpha
        alpha3 = gf127_multiply(alpha3, 0x8);  // multiply by alpha^3
    }
}

static void copy_codeword(
    const uint32_t source[BCH_CODEWORD_WORDS],
    uint32_t destination[BCH_CODEWORD_WORDS]
)
{
    for (uint8_t i = 0; i < BCH_CODEWORD_WORDS; i++)
    {
        destination[i] = source[i];
    }
}

static void extract_message(
    const uint32_t codeword[BCH_CODEWORD_WORDS],
    uint32_t message[BCH_MESSAGE_WORDS]
)
{
    message[0] = (codeword[0] >> BCH_PARITY_BITS) | (codeword[1] << 18);
    message[1] = (codeword[1] >> BCH_PARITY_BITS) | (codeword[2] << 18);
    message[2] = (codeword[2] >> BCH_PARITY_BITS) | (codeword[3] << 18);
    message[3] =  codeword[3] >> BCH_PARITY_BITS;
}

static uint8_t root_to_position(uint8_t root)
{
    uint8_t logarithm = gf127_log(root);

    return (logarithm == 0) ? 0 : GF127_ORDER - logarithm;
}

static uint8_t decoder_failure(
    const uint32_t received[BCH_CODEWORD_WORDS],
    uint32_t err[BCH_CODEWORD_WORDS],
    uint32_t codeword[BCH_CODEWORD_WORDS],
    uint32_t message[BCH_MESSAGE_WORDS]
)
{
    for (uint8_t i = 0; i < BCH_CODEWORD_WORDS; i++)
    {
        err[i] = 0;
    }

    copy_codeword(received, codeword);
    extract_message(codeword, message);

    return BCH_DECODER_FAILURE;
}

uint8_t bch_decoder(const uint32_t received[BCH_CODEWORD_WORDS], uint32_t err[BCH_CODEWORD_WORDS], uint32_t codeword[BCH_CODEWORD_WORDS], uint32_t message[BCH_MESSAGE_WORDS])
{
    uint8_t syn1;
    uint8_t syn3;
    uint8_t err_count = 0;
    uint8_t err_positions[BCH_MAX_ERRORS] = {0};

    calculate_syn(received, &syn1, &syn3);

    if (syn1 == 0)
    {
        if (syn3 != 0)
        {
            return decoder_failure(received, err, codeword, message);
        }
    }
    else if (gf127_cube(syn1) == syn3)
    {
        err_count = 1;
        err_positions[0] = gf127_log(syn1);
    }
    else
    {
        uint8_t syn1_cubed = gf127_cube(syn1);
        uint8_t mu = gf127_divide(syn1_cubed ^ syn3, syn1_cubed);

        if (gf127_trace(mu) != 0)
        {
            return decoder_failure(received, err, codeword, message);
        }

        uint8_t omega1 = gf127_half_trace(mu);
        uint8_t omega2 = omega1 ^ 1;
        uint8_t denominator = gf127_multiply(mu, syn1);
        uint8_t root1 = gf127_divide(omega1, denominator);
        uint8_t root2 = gf127_divide(omega2, denominator);

        err_count = 2;
        err_positions[0] = root_to_position(root1);
        err_positions[1] = root_to_position(root2);
    }

    for (uint8_t i = 0; i < BCH_CODEWORD_WORDS; i++)
    {
        err[i] = 0;
    }

    for (uint8_t i = 0; i < err_count; i++)
    {
        set_bit(err, err_positions[i]);
    }

    for (uint8_t i = 0; i < BCH_CODEWORD_WORDS; i++)
    {
        codeword[i] = received[i] ^ err[i];
    }

    calculate_syn(codeword, &syn1, &syn3);

    if (syn1 != 0 || syn3 != 0)
    {
        return decoder_failure(received, err, codeword, message);
    }

    extract_message(codeword, message);

    return err_count;
}

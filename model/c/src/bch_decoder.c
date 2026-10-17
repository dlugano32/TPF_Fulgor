#include "bch_decoder.h"

#include <stddef.h>

static uint8_t gf_multiply(uint8_t a, uint8_t b)
{
    uint8_t product = 0;

    for (uint8_t i = 0; i < GF_M; i++)
    {
        if ((b & 1) != 0)
        {
            product ^= a;
        }

        uint8_t carry = a & 0x40;

        a = (a << 1) & GF_ELEMENT_MASK;

        if (carry != 0)
        {
            a ^= GF_REDUCTION_POLY;
        }

        b >>= 1;
    }

    return product;
}

static uint8_t gf_square(uint8_t value)
{
    return gf_multiply(value, value);
}

static uint8_t gf_cube(uint8_t value)
{
    return gf_multiply(gf_square(value), value);
}

static uint8_t gf_power(uint8_t base, uint8_t exponent)
{
    uint8_t result = 1;

    while (exponent != 0)
    {
        if ((exponent & 1) != 0)
        {
            result = gf_multiply(result, base);
        }

        base = gf_square(base);
        exponent >>= 1;
    }

    return result;
}

static uint8_t gf_divide(uint8_t numerator, uint8_t denominator)
{
    return gf_multiply(numerator, gf_power(denominator, GF_ORDER - 1)); // alpha^(-1) = alpha^(2m-2)
}

static uint8_t gf_log(uint8_t value)
{
    uint8_t power = 1;

    for (uint8_t exponent = 0; exponent < GF_ORDER; exponent++)
    {
        if (power == value)
        {
            return exponent;
        }

        power = gf_multiply(power, 0x02);   // multiply by alpha
    }

    return GF_ORDER;
}

static uint8_t gf_trace(uint8_t value)
{
    // Tr(alpha) = alpha + alpha^2 + alpha^4 + ... + alpha2^(m-1)

    uint8_t trace = value;
    uint8_t power = value;

    for (uint8_t i = 1; i < GF_M; i++)
    {
        power = gf_square(power);
        trace ^= power;
    }

    return trace;
}

static uint8_t gf_half_trace(uint8_t value)
{
    // HTr(alpha) = alpha + alpha^4 + alpha^16 + ... + alpha2^(m-1)
    uint8_t half_trace = value;
    uint8_t power = value;

    for (uint8_t i = 0; i < (GF_M - 1) / 2; i++)
    {
        power = gf_square(gf_square(power));
        half_trace ^= power;
    }

    return half_trace;
}

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

        alpha1 = gf_multiply(alpha1, 0x2);  // multiply by alpha
        alpha3 = gf_multiply(alpha3, 0x8);  // multiply by alpha^3
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
    uint8_t logarithm = gf_log(root);

    return (logarithm == 0) ? 0 : GF_ORDER - logarithm;
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
        if(syn3 != 0) 
        {
            return decoder_failure(received, err, codeword, message);
        }
    }
    else if (gf_cube(syn1) == syn3)
    {
        err_count = 1;
        err_positions[0] = gf_log(syn1);
    }
    else
    {
        uint8_t syn1_cubed = gf_cube(syn1);
        uint8_t mu = gf_divide(syn1_cubed ^ syn3, syn1_cubed);

        if (gf_trace(mu) != 0)
        {
            return decoder_failure(received, err, codeword, message);
        }

        uint8_t omega1 = gf_half_trace(mu);
        uint8_t omega2 = omega1 ^ 1;
        uint8_t denominator = gf_multiply(mu, syn1);
        uint8_t root1 = gf_divide(omega1, denominator);
        uint8_t root2 = gf_divide(omega2, denominator);

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

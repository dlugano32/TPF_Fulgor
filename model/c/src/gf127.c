#include "gf127.h"

uint8_t gf127_multiply(uint8_t a, uint8_t b)
{
    uint8_t product = 0;

    for (uint8_t i = 0; i < GF127_M; i++)
    {
        if ((b & 1) != 0)
        {
            product ^= a;
        }

        uint8_t carry = a & 0x40;

        a = (a << 1) & GF127_ELEMENT_MASK;

        if (carry != 0)
        {
            a ^= GF127_REDUCTION_POLY;
        }

        b >>= 1;
    }

    return product;
}

uint8_t gf127_square(uint8_t value)
{
    return gf127_multiply(value, value);
}

uint8_t gf127_cube(uint8_t value)
{
    return gf127_multiply(gf127_square(value), value);
}

uint8_t gf127_power(uint8_t base, uint8_t exponent)
{
    uint8_t result = 1;

    while (exponent != 0)
    {
        if ((exponent & 1) != 0)
        {
            result = gf127_multiply(result, base);
        }

        base = gf127_square(base);
        exponent >>= 1;
    }

    return result;
}

uint8_t gf127_divide(uint8_t numerator, uint8_t denominator)
{
    // alpha^(-1) = alpha^(2^m - 2)
    return gf127_multiply(numerator, gf127_power(denominator, GF127_ORDER - 1));
}

uint8_t gf127_log(uint8_t value)
{
    uint8_t power = 1;

    for (uint8_t exponent = 0; exponent < GF127_ORDER; exponent++)
    {
        if (power == value)
        {
            return exponent;
        }

        power = gf127_multiply(power, 0x02);   // multiply by alpha
    }

    return GF127_ORDER;
}

uint8_t gf127_trace(uint8_t value)
{
    // Tr(alpha) = alpha + alpha^2 + alpha^4 + ... + alpha^(2^(m-1))
    uint8_t trace = value;
    uint8_t power = value;

    for (uint8_t i = 1; i < GF127_M; i++)
    {
        power = gf127_square(power);
        trace ^= power;
    }

    return trace;
}

uint8_t gf127_half_trace(uint8_t value)
{
    // HTr(alpha) = alpha + alpha^4 + alpha^16 + ... + alpha^(2^(m-1))
    uint8_t half_trace = value;
    uint8_t power = value;

    for (uint8_t i = 0; i < (GF127_M - 1) / 2; i++)
    {
        power = gf127_square(gf127_square(power));
        half_trace ^= power;
    }

    return half_trace;
}

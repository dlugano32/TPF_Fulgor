#include "bch_encoder.h"

#include <stddef.h>

/* Cada fila se almacena como LSW first (Least significant word first). */
static const uint32_t parity_masks[BCH_PARITY_BITS][BCH_MESSAGE_WORDS] = {
    {UINT32_C(0x784EE361), UINT32_C(0x2A2D78A6), UINT32_C(0x31436955), UINT32_C(0x00015BF0)},
    {UINT32_C(0x88D325A3), UINT32_C(0x7E7789EA), UINT32_C(0x53C5BBFF), UINT32_C(0x0001EC10)},
    {UINT32_C(0x69E8A827), UINT32_C(0xD6C26B73), UINT32_C(0x96C81EAB), UINT32_C(0x000083D0)},
    {UINT32_C(0xD3D1504E), UINT32_C(0xAD84D6E6), UINT32_C(0x2D903D57), UINT32_C(0x000107A1)},
    {UINT32_C(0xDFEC43FD), UINT32_C(0x7124D56B), UINT32_C(0x6A6313FA), UINT32_C(0x000154B2)},
    {UINT32_C(0xC796649B), UINT32_C(0xC864D271), UINT32_C(0xE5854EA1), UINT32_C(0x0001F294)},
    {UINT32_C(0xF7622A57), UINT32_C(0xBAE4DC45), UINT32_C(0xFA49F416), UINT32_C(0x0000BED9)},
    {UINT32_C(0xEEC454AE), UINT32_C(0x75C9B88B), UINT32_C(0xF493E82D), UINT32_C(0x00017DB3)},
    {UINT32_C(0xA5C64A3D), UINT32_C(0xC1BE09B1), UINT32_C(0xD864B90F), UINT32_C(0x0001A097)},
    {UINT32_C(0x33C2771B), UINT32_C(0xA9516BC5), UINT32_C(0x818A1B4A), UINT32_C(0x00001ADF)},
    {UINT32_C(0x6784EE36), UINT32_C(0x52A2D78A), UINT32_C(0x03143695), UINT32_C(0x000035BF)},
    {UINT32_C(0xCF09DC6C), UINT32_C(0xA545AF14), UINT32_C(0x06286D2A), UINT32_C(0x00006B7E)},
    {UINT32_C(0x9E13B8D8), UINT32_C(0x4A8B5E29), UINT32_C(0x0C50DA55), UINT32_C(0x0000D6FC)},
    {UINT32_C(0x3C2771B0), UINT32_C(0x9516BC53), UINT32_C(0x18A1B4AA), UINT32_C(0x0001ADF8)}
};

// Fila P_T[0]
// parity_masks[0][0] ->  31:0  -> 0x784EE361
// parity_masks[0][1] ->  63:32 -> 0x2A2D78A6
// parity_masks[0][2] ->  95:64 -> 0x31436955
// parity_masks[0][3] -> 127:96 -> 0x00015BF0

// Reduccion XOR de 32 bits
static uint32_t parity32(uint32_t value)
{
    value ^= value >> 16;
    value ^= value >> 8;
    value ^= value >> 4;
    value ^= value >> 2;
    value ^= value >> 1;

    return value & 1;
}

void bch_encoder(const uint32_t message[BCH_MESSAGE_WORDS], uint32_t codeword[BCH_CODEWORD_WORDS]) 
{
    uint32_t parity = 0;
    uint32_t parity_bit = 0;


    for (uint8_t i = 0; i < BCH_PARITY_BITS; i++) 
    {
        parity_bit = 0;

        for (uint8_t j = 0; j < BCH_MESSAGE_WORDS; j++) 
        {
            parity_bit ^= parity32(message[j] & parity_masks[i][j]);
        }

        parity |= parity_bit << i;
    }

    codeword[0] = (message[0] << BCH_PARITY_BITS) | parity;
    codeword[1] = (message[1] << BCH_PARITY_BITS) | (message[0] >> 18);
    codeword[2] = (message[2] << BCH_PARITY_BITS) | (message[1] >> 18);
    codeword[3] = (message[3] << BCH_PARITY_BITS) | (message[2] >> 18);
}

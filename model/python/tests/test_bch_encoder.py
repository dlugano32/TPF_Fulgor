"""Pruebas del encoder sistematico BCH(127,113)."""

import random
import sys
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPOSITORY_ROOT))

from model.python.src.bch_design import cosets_for_t, generator_polynomial
from model.python.src.bch_encoder import (
    K,
    PARITY_BITS,
    build_parity_matrix,
    encode,
    encode_with_matrix,
)
from model.python.tools.GF2m import GF2m
from model.python.tools.GF2m_matrix import transpose_matrix
from model.python.tools.GFPoly import GFPoly


RANDOM_MESSAGES = 1000
RANDOM_SEED = 127113


def check_message(
    message,
    generator,
    parity_matrix,
    transposed_masks,
    zero_polynomial,
) -> None:
    """Compara la división, P y las máscaras transpuestas para RTL."""

    codeword_polynomial = encode(message, generator)
    codeword_matrix = encode_with_matrix(message, generator, parity_matrix)
    _, remainder = codeword_matrix.divide(generator)

    assert codeword_matrix == codeword_polynomial
    assert remainder == zero_polynomial

    rtl_parity = 0

    for parity_bit, mask in enumerate(transposed_masks):
        bit = (message & mask).bit_count() & 1
        rtl_parity |= bit << parity_bit

    assert rtl_parity == codeword_matrix.to_int() & ((1 << PARITY_BITS) - 1)


def test_matrix_dimensions(parity_matrix) -> None:
    """Verifica las dimensiones de P y de su transpuesta para RTL."""

    assert len(parity_matrix) == K
    assert all(len(row) == PARITY_BITS for row in parity_matrix)

    transposed_matrix = transpose_matrix(parity_matrix)

    assert len(transposed_matrix) == PARITY_BITS
    assert all(len(row) == K for row in transposed_matrix)


def test_zero_and_ones(
    generator,
    parity_matrix,
    transposed_masks,
    zero_polynomial,
) -> None:
    """Verifica los mensajes nulo y todo unos."""

    check_message(0, generator, parity_matrix, transposed_masks, zero_polynomial)
    check_message(
        (1 << K) - 1,
        generator,
        parity_matrix,
        transposed_masks,
        zero_polynomial,
    )


def test_basis_vectors(
    generator,
    parity_matrix,
    transposed_masks,
    zero_polynomial,
) -> None:
    """Verifica los 113 mensajes de la base canonica."""

    for bit_index in range(K):
        check_message(
            1 << bit_index,
            generator,
            parity_matrix,
            transposed_masks,
            zero_polynomial,
        )


def test_random_messages(
    generator,
    parity_matrix,
    transposed_masks,
    zero_polynomial,
) -> None:
    """Verifica 1000 mensajes pseudoaleatorios con semilla fija."""

    random_generator = random.Random(RANDOM_SEED)

    for _ in range(RANDOM_MESSAGES):
        message = random_generator.getrandbits(K)
        check_message(
            message,
            generator,
            parity_matrix,
            transposed_masks,
            zero_polynomial,
        )


def main() -> None:
    field = GF2m(m=7, primitive_poly=0b0001001)
    cosets = cosets_for_t(t=2, m=field.m)
    generator = generator_polynomial(field, cosets)

    gf2 = GF2m(m=1, primitive_poly=0b1)
    parity_matrix = build_parity_matrix(generator, gf2)
    transposed_matrix = transpose_matrix(parity_matrix)
    transposed_masks = []

    for row in transposed_matrix:
        mask = 0

        for message_bit, coefficient in enumerate(row):
            mask |= int(coefficient) << message_bit

        transposed_masks.append(mask)

    zero_polynomial = GFPoly(field, [field.element(0)])

    test_matrix_dimensions(parity_matrix)
    print("[PASS] dimensiones de P")

    test_zero_and_ones(
        generator,
        parity_matrix,
        transposed_masks,
        zero_polynomial,
    )
    print("[PASS] mensajes nulo y todo unos")

    test_basis_vectors(
        generator,
        parity_matrix,
        transposed_masks,
        zero_polynomial,
    )
    print("[PASS] 113 vectores de la base canonica")

    test_random_messages(
        generator,
        parity_matrix,
        transposed_masks,
        zero_polynomial,
    )
    print(f"[PASS] {RANDOM_MESSAGES} mensajes aleatorios")

    print("\nTodas las pruebas del encoder BCH finalizaron correctamente.")


if __name__ == "__main__":
    main()

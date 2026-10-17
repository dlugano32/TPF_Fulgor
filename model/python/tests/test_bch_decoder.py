"""Pruebas del decoder search-less BCH(127,113)."""

import random
import sys
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPOSITORY_ROOT))

from model.python.src.bch_decoder import N, build_syndrome_matrix, calculate_syndromes, decode, syndrome_matrix_to_systemverilog, syndrome_masks_from_matrix
from model.python.src.bch_design import cosets_for_t, generator_polynomial
from model.python.src.bch_encoder import K, encode
from model.python.tools.GF2m import GF2m


RANDOM_MESSAGES = 1000
RANDOM_SEED = 2026


def test_syndrome_matrix(field, matrix, masks) -> None:
    """Verifica dimensiones, orden de bits y errores base de la matriz M."""

    syndrome_bits = 2 * field.m

    assert len(matrix) == N
    assert all(len(row) == syndrome_bits for row in matrix)
    assert len(masks) == syndrome_bits

    for position in range(N):
        syndrome_1, syndrome_3 = calculate_syndromes(
            1 << position,
            field,
            masks,
        )

        assert int(syndrome_1) == field.exp(position)
        assert int(syndrome_3) == field.exp(3 * position)

        expected_row = [
            (int(syndrome_1) >> bit_index) & 1
            for bit_index in range(field.m)
        ]
        expected_row.extend(
            (int(syndrome_3) >> bit_index) & 1
            for bit_index in range(field.m)
        )
        assert matrix[position] == expected_row

    systemverilog = syndrome_matrix_to_systemverilog(matrix)
    mask_literals = [
        f"127'h{mask:032X}"
        for mask in reversed(masks)
    ]

    assert "localparam logic [126:0] M_T [13:0]" in systemverilog
    assert all(mask_literal in systemverilog for mask_literal in mask_literals)


def test_random_messages(generator, field, syndrome_masks) -> None:
    """Verifica 1000 palabras validas generadas con mensajes aleatorios."""

    random_generator = random.Random(RANDOM_SEED)
    zero = field.element(0)

    for _ in range(RANDOM_MESSAGES):
        message = random_generator.getrandbits(K)
        codeword = encode(message, generator).to_int()

        syndrome_1, syndrome_3 = calculate_syndromes(
            codeword,
            field,
            syndrome_masks,
        )
        corrected, error_positions = decode(codeword, field, syndrome_masks)

        assert syndrome_1 == zero
        assert syndrome_3 == zero
        assert corrected == codeword
        assert error_positions == []


def test_single_errors(codeword, field, syndrome_masks) -> None:
    """Verifica exhaustivamente las 127 posiciones de error simple."""

    for position in range(N):
        received = codeword ^ (1 << position)
        corrected, error_positions = decode(received, field, syndrome_masks)

        assert corrected == codeword
        assert error_positions == [position]


def test_double_errors(codeword, field, syndrome_masks) -> None:
    """Verifica exhaustivamente las 8001 parejas de errores."""

    for first_position in range(N):
        for second_position in range(first_position + 1, N):
            received = codeword ^ (1 << first_position) ^ (1 << second_position)
            corrected, error_positions = decode(received, field, syndrome_masks)

            assert corrected == codeword
            assert error_positions == [first_position, second_position]


def main() -> None:
    field = GF2m(m=7, primitive_poly=0b0001001)
    cosets = cosets_for_t(t=2, m=field.m)
    generator = generator_polynomial(field, cosets)

    syndrome_matrix = build_syndrome_matrix(field)
    syndrome_masks = syndrome_masks_from_matrix(syndrome_matrix)

    test_syndrome_matrix(field, syndrome_matrix, syndrome_masks)
    print("[PASS] matriz de sindromes 127x14")

    test_random_messages(generator, field, syndrome_masks)
    print(f"[PASS] {RANDOM_MESSAGES} mensajes aleatorios validos")

    random_generator = random.Random(RANDOM_SEED)
    message = random_generator.getrandbits(K)
    codeword = encode(message, generator).to_int()

    test_single_errors(codeword, field, syndrome_masks)
    print("[PASS] 127 errores simples")

    test_double_errors(codeword, field, syndrome_masks)
    print("[PASS] 8001 parejas de errores")

    print("\nTodas las pruebas del decoder BCH finalizaron correctamente.")


if __name__ == "__main__":
    main()

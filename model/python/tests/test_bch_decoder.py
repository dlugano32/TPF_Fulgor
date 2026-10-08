"""Pruebas del decoder search-less BCH(127,113)."""

import random
import sys
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPOSITORY_ROOT))

from model.python.src.bch_decoder import N, calculate_syndromes, decode
from model.python.src.bch_design import cosets_for_t, generator_polynomial
from model.python.src.bch_encoder import K, encode_systematic
from model.python.tools.GF2m import GF2m


RANDOM_MESSAGES = 1000
RANDOM_SEED = 2026


def test_random_messages(generator, field) -> None:
    """Verifica 1000 palabras validas generadas con mensajes aleatorios."""

    random_generator = random.Random(RANDOM_SEED)
    zero = field.element(0)

    for _ in range(RANDOM_MESSAGES):
        message = random_generator.getrandbits(K)
        codeword = encode_systematic(message, generator).to_int()

        syndrome_1, syndrome_3 = calculate_syndromes(codeword, field)
        corrected, error_positions = decode(codeword, field)

        assert syndrome_1 == zero
        assert syndrome_3 == zero
        assert corrected == codeword
        assert error_positions == []


def test_single_errors(codeword, field) -> None:
    """Verifica exhaustivamente las 127 posiciones de error simple."""

    for position in range(N):
        received = codeword ^ (1 << position)
        corrected, error_positions = decode(received, field)

        assert corrected == codeword
        assert error_positions == [position]


def test_double_errors(codeword, field) -> None:
    """Verifica exhaustivamente las 8001 parejas de errores."""

    for first_position in range(N):
        for second_position in range(first_position + 1, N):
            received = codeword ^ (1 << first_position) ^ (1 << second_position)
            corrected, error_positions = decode(received, field)

            assert corrected == codeword
            assert error_positions == [first_position, second_position]


def main() -> None:
    field = GF2m(m=7, primitive_poly=0b0001001)
    cosets = cosets_for_t(t=2, m=field.m)
    generator = generator_polynomial(field, cosets)

    test_random_messages(generator, field)
    print(f"[PASS] {RANDOM_MESSAGES} mensajes aleatorios validos")

    random_generator = random.Random(RANDOM_SEED)
    message = random_generator.getrandbits(K)
    codeword = encode_systematic(message, generator).to_int()

    test_single_errors(codeword, field)
    print("[PASS] 127 errores simples")

    test_double_errors(codeword, field)
    print("[PASS] 8001 parejas de errores")

    print("\nTodas las pruebas del decoder BCH finalizaron correctamente.")


if __name__ == "__main__":
    main()

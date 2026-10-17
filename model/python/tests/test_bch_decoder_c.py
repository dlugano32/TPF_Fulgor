"""Compara el modelo C del decoder BCH(127,113) contra Python."""

import ctypes
import os
import random
import subprocess
import sys
import tempfile
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPOSITORY_ROOT))

from model.python.src.bch_decoder import build_syndrome_matrix, decode, syndrome_masks_from_matrix
from model.python.src.bch_design import cosets_for_t, generator_polynomial
from model.python.src.bch_encoder import K, N, encode
from model.python.tools.GF2m import GF2m


WORD_BITS = 32
MESSAGE_WORDS = 4
CODEWORD_WORDS = 4
RANDOM_MESSAGES = 1000
RANDOM_SEED = 2026

WordArray = ctypes.c_uint32 * CODEWORD_WORDS


def build_c_model(output_directory: Path) -> ctypes.CDLL:
    """Compila los modelos C del encoder y decoder como biblioteca temporal."""

    include_directory = REPOSITORY_ROOT / "model/c/include"
    source_directory = REPOSITORY_ROOT / "model/c/src"
    library_path = output_directory / "libbch_decoder.so"
    compiler = os.environ.get("CC", "gcc")

    subprocess.run(
        [
            compiler,
            "-std=c11",
            "-O2",
            "-Wall",
            "-Wextra",
            "-Werror",
            "-fPIC",
            "-shared",
            f"-I{include_directory}",
            str(source_directory / "bch_encoder.c"),
            str(source_directory / "bch_decoder.c"),
            "-o",
            str(library_path),
        ],
        check=True,
    )

    library = ctypes.CDLL(str(library_path))
    library.bch_encoder.argtypes = [
        ctypes.POINTER(ctypes.c_uint32),
        ctypes.POINTER(ctypes.c_uint32),
    ]
    library.bch_encoder.restype = None
    library.bch_decoder.argtypes = [
        ctypes.POINTER(ctypes.c_uint32),
        ctypes.POINTER(ctypes.c_uint32),
        ctypes.POINTER(ctypes.c_uint32),
        ctypes.POINTER(ctypes.c_uint32),
    ]
    library.bch_decoder.restype = ctypes.c_uint8

    return library


def integer_to_words(value: int, word_count: int = CODEWORD_WORDS) -> ctypes.Array:
    """Separa un entero en palabras uint32, LSW first como espera el C."""

    word_mask = (1 << WORD_BITS) - 1
    array_type = ctypes.c_uint32 * word_count

    return array_type(
        *((value >> (WORD_BITS * index)) & word_mask for index in range(word_count))
    )


def words_to_integer(words: ctypes.Array) -> int:
    """Reconstruye un entero a partir de palabras uint32 LSW first."""

    return sum(int(word) << (WORD_BITS * index) for index, word in enumerate(words))


def encode_with_c(library: ctypes.CDLL, message: int) -> int:
    """Codifica un mensaje con el modelo C."""

    message_words = integer_to_words(message, MESSAGE_WORDS)
    codeword_words = WordArray()
    library.bch_encoder(message_words, codeword_words)

    return words_to_integer(codeword_words) & ((1 << N) - 1)


def decode_with_c(library: ctypes.CDLL, received: int) -> tuple[int, int, int, int]:
    """Decodifica y devuelve cantidad de errores, mascara, codeword y mensaje."""

    received_words = integer_to_words(received)
    error_words = WordArray()
    codeword_words = WordArray()
    message_words = WordArray()
    error_count = library.bch_decoder(
        received_words,
        error_words,
        codeword_words,
        message_words,
    )

    return (
        error_count,
        words_to_integer(error_words) & ((1 << N) - 1),
        words_to_integer(codeword_words) & ((1 << N) - 1),
        words_to_integer(message_words) & ((1 << K) - 1),
    )


def check_case(
    library: ctypes.CDLL,
    received: int,
    field: GF2m,
    syndrome_masks: tuple[int, ...],
) -> None:
    """Compara una decodificacion C con el oraculo algebraico en Python."""

    python_codeword, python_positions = decode(received, field, syndrome_masks)
    error_count, error_mask, c_codeword, c_message = decode_with_c(library, received)
    expected_error_mask = received ^ python_codeword

    assert error_count == len(python_positions)
    assert error_mask == expected_error_mask
    assert c_codeword == python_codeword
    assert c_message == python_codeword >> 14


def test_c_model_matches_python() -> None:
    """Comprueba palabras validas y todos los errores simples y dobles."""

    field = GF2m(m=7, primitive_poly=0b0001001)
    cosets = cosets_for_t(t=2, m=field.m)
    generator = generator_polynomial(field, cosets)
    syndrome_matrix = build_syndrome_matrix(field)
    syndrome_masks = syndrome_masks_from_matrix(syndrome_matrix)
    random_generator = random.Random(RANDOM_SEED)

    with tempfile.TemporaryDirectory(prefix="bch_decoder_test_") as temporary:
        library = build_c_model(Path(temporary))

        for _ in range(RANDOM_MESSAGES):
            message = random_generator.getrandbits(K)
            codeword = encode_with_c(library, message)
            expected_codeword = encode(message, generator).to_int()

            assert codeword == expected_codeword
            check_case(library, codeword, field, syndrome_masks)

        message = random_generator.getrandbits(K)
        codeword = encode_with_c(library, message)

        for position in range(N):
            check_case(
                library,
                codeword ^ (1 << position),
                field,
                syndrome_masks,
            )

        for first_position in range(N):
            for second_position in range(first_position + 1, N):
                check_case(
                    library,
                    codeword ^ (1 << first_position) ^ (1 << second_position),
                    field,
                    syndrome_masks,
                )

    print(f"[PASS] {RANDOM_MESSAGES} palabras validas")
    print("[PASS] 127 errores simples")
    print("[PASS] 8001 parejas de errores")
    print("[PASS] El modelo C coincide con el decoder algebraico en Python")


if __name__ == "__main__":
    test_c_model_matches_python()

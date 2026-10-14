"""Compara el modelo C del encoder BCH(127,113) contra Python."""

import ctypes
import os
import random
import subprocess
import sys
import tempfile
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPOSITORY_ROOT))

from model.python.src.bch_design import cosets_for_t, generator_polynomial
from model.python.src.bch_encoder import K, N, encode
from model.python.tools.GF2m import GF2m


WORD_BITS = 32
MESSAGE_WORDS = 4
CODEWORD_WORDS = 4
RANDOM_MESSAGES = 1000
RANDOM_SEED = 2026

WordArray = ctypes.c_uint32 * MESSAGE_WORDS


def find_c_model() -> tuple[Path, Path]:
    """Encuentra el fuente y los headers en los layouts usados por el proyecto."""

    candidates = (
        (
            REPOSITORY_ROOT / "model/c/src/bch_encoder.c",
            REPOSITORY_ROOT / "model/c/include",
        ),
        (
            REPOSITORY_ROOT / "c_model/bch_encoder.c",
            REPOSITORY_ROOT / "c_model",
        ),
    )

    for source, include_directory in candidates:
        if source.is_file() and (include_directory / "bch_encoder.h").is_file():
            return source, include_directory

    searched = "\n".join(f"  - {source}" for source, _ in candidates)
    raise FileNotFoundError(
        "No se encontró bch_encoder.c. Rutas examinadas:\n" + searched
    )


def build_c_model(output_directory: Path) -> ctypes.CDLL:
    """Compila el modelo C puro como una biblioteca compartida temporal."""

    source, include_directory = find_c_model()
    library_path = output_directory / "libbch_encoder.so"
    compiler = os.environ.get("CC", "gcc")

    subprocess.run(
        [
            compiler,
            "-std=c11",
            "-O2",
            "-fPIC",
            "-shared",
            f"-I{include_directory}",
            str(source),
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
    return library


def integer_to_words(value: int, word_count: int) -> ctypes.Array:
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
    """Invoca bch_encoder() y devuelve su codeword como entero de 127 bits."""

    message_words = integer_to_words(message, MESSAGE_WORDS)
    codeword_words = WordArray()
    library.bch_encoder(message_words, codeword_words)
    return words_to_integer(codeword_words) & ((1 << N) - 1)


def message_vectors():
    """Genera casos extremos, una base completa y casos pseudoaleatorios."""

    yield 0
    yield (1 << K) - 1

    for bit_index in range(K):
        yield 1 << bit_index

    random_generator = random.Random(RANDOM_SEED)
    for _ in range(RANDOM_MESSAGES):
        yield random_generator.getrandbits(K)


def test_c_model_matches_python() -> None:
    """Comprueba que C y Python producen la misma cw para cada mensaje."""

    field = GF2m(m=7, primitive_poly=0b0001001)
    cosets = cosets_for_t(t=2, m=field.m)
    generator = generator_polynomial(field, cosets)
    checked = 0

    with tempfile.TemporaryDirectory(prefix="bch_encoder_test_") as temporary:
        library = build_c_model(Path(temporary))

        for message in message_vectors():
            python_codeword = encode(message, generator).to_int()
            c_codeword = encode_with_c(library, message)

            assert c_codeword == python_codeword, (
                "El modelo C no coincide con Python:\n"
                f"  msg       = 0x{message:029x}\n"
                f"  cw_python = 0x{python_codeword:032x}\n"
                f"  cw_c      = 0x{c_codeword:032x}"
            )

            print(f"[PY/C] msg=0x{message:029x} cw=0x{c_codeword:032x}")
            checked += 1

    print(f"[PASS] C y Python coinciden para {checked} mensajes")


if __name__ == "__main__":
    test_c_model_matches_python()

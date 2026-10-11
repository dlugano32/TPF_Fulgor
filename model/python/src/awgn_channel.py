import math
import random

FRAME_BITS = 889

def noise_sigma(ebn0_db: float, code_rate: float) -> float:
    """Calcula el desvío estándar del ruido para símbolos de energía uno."""

    if code_rate <= 0.0 or code_rate > 1.0:
        raise ValueError("La tasa de código debe pertenecer al intervalo (0, 1]")

    ebn0 = 10.0 ** (ebn0_db / 10.0)
    esn0 = code_rate * ebn0

    return math.sqrt(1.0 / (2.0 * esn0))


def theoretical_ber(ebn0_db: float, code_rate: float) -> float:
    """BER teórica de PAM2 con AWGN y decisión dura."""

    sigma = noise_sigma(ebn0_db, code_rate)

    return 0.5 * math.erfc(1.0 / (math.sqrt(2.0) * sigma))


def pam2_awgn_frame(frame: int, sigma: float, random_generator: random.Random) -> int:
    """Transmite un frame PAM2 por AWGN y devuelve las decisiones duras."""

    if frame < 0 or frame >= 1 << FRAME_BITS:
        raise ValueError(f"El frame debe tener hasta {FRAME_BITS} bits")

    received_frame = 0

    for bit_index in range(FRAME_BITS):
        bit = (frame >> bit_index) & 1
        symbol = 1.0 if bit == 0 else -1.0
        sample = symbol + random_generator.gauss(0.0, sigma)

        if sample < 0.0:
            received_frame |= 1 << bit_index

    return received_frame

import math
import random


FRAME_BITS = 889
SEED = 2026


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


def pam2_modulate(frames: list[int]) -> list[float]:
    """Mapea los bits a PAM2: 0 -> +1 y 1 -> -1."""

    symbols = []

    for frame in frames:
        if frame < 0 or frame >= 1 << FRAME_BITS:
            raise ValueError(f"Cada frame debe tener hasta {FRAME_BITS} bits")

        for bit_index in range(FRAME_BITS):
            bit = (frame >> bit_index) & 1
            symbols.append(1.0 if bit == 0 else -1.0)

    return symbols


def add_awgn(symbols: list[float], ebn0_db: float, code_rate: float, seed: int) -> list[float]:
    """Agrega ruido AWGN para el Eb/N0 y la tasa de código indicados."""

    sigma = noise_sigma(ebn0_db, code_rate)
    random_generator = random.Random(seed)

    return [
        symbol + random_generator.gauss(0.0, sigma)
        for symbol in symbols
    ]


def hard_decision(samples: list[float]) -> list[int]:
    """Decide 0 para muestras positivas y 1 para muestras negativas."""

    if len(samples) % FRAME_BITS != 0:
        raise ValueError(f"La cantidad de muestras debe ser múltiplo de {FRAME_BITS}")

    received_frames = []

    for frame_start in range(0, len(samples), FRAME_BITS):
        frame = 0

        for bit_index in range(FRAME_BITS):
            if samples[frame_start + bit_index] < 0.0:
                frame |= 1 << bit_index

        received_frames.append(frame)

    return received_frames


def pam2_awgn_channel(frames: list[int], ebn0_db: float, code_rate: float, seed: int) -> tuple[list[int], list[float]]:
    """Aplica modulación PAM2, canal AWGN y decisión dura."""

    transmitted_symbols = pam2_modulate(frames)
    received_samples = add_awgn(transmitted_symbols, ebn0_db, code_rate, seed)
    received_frames = hard_decision(received_samples)

    return received_frames, received_samples


def main() -> None:
    random_generator = random.Random(SEED)
    frames = [random_generator.getrandbits(FRAME_BITS) for _ in range(100)]
    code_rate = 113 / 127

    # Con una misma semilla, las muestras y decisiones deben repetirse.
    received_frames, samples = pam2_awgn_channel(frames, 3.0, code_rate, SEED)

    errors = sum(
        (transmitted ^ received).bit_count()
        for transmitted, received in zip(frames, received_frames)
    )
    ber = errors / (len(frames) * FRAME_BITS)

    print("Canal PAM2-AWGN")
    print("Modulación            : 0 -> +1, 1 -> -1")
    print("Decisión dura         : umbral en cero")
    print(f"BER para Eb/N0 = 3 dB: {ber:.6f}")


if __name__ == "__main__":
    main()

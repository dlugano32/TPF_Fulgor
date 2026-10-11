import random

from model.python.src.awgn_channel import noise_sigma, pam2_awgn_frame
from model.python.src.bch_decoder import decode
from model.python.src.bch_design import cosets_for_t, generator_polynomial
from model.python.src.bch_encoder import K, N, encode
from model.python.src.interleaver import BRANCHES, DELAY, TOTAL_DELAY, deinterleave, interleave
from model.python.src.lane_permutation import LANES, inverse_permute_lanes, permute_lanes
from model.python.src.prbs31 import PRBS31Generator
from model.python.src.prbs_checker import PRBS31Checker
from model.python.tools.GF2m import GF2m


PRBS_TAPS = [30, 27]
PRBS_SEED = 0x5A17C3D2
LOCK_MATCHES = 31
FRAME_COUNT = 100
CHANNEL_SEED = 2026
CODE_RATE = K / N
PAYLOAD_BITS = LANES * K
PARITY_BITS = N - K
MESSAGE_MASK = (1 << K) - 1
CODEWORD_MASK = (1 << N) - 1
_BCH_CONTEXT = None


def bits_to_int(bits: list[int]) -> int:
    """
        Convierte bits en orden temporal a un entero con el primer bit en bit 0.
            [bit0, bit1, bit2, ..., bit n] -> int value
    """

    value = 0

    for bit_index, bit in enumerate(bits):
        value |= bit << bit_index

    return value


def int_to_bits(value: int, width: int) -> list[int]:
    """Convierte un entero a bits en orden temporal."""

    return [(value >> bit_index) & 1 for bit_index in range(width)]


def get_bch_context():
    """Construye una sola vez el campo y el polinomio generador g(x)."""

    global _BCH_CONTEXT

    if _BCH_CONTEXT is None:
        field = GF2m(m=7, primitive_poly=0b0001001)
        cosets = cosets_for_t(t=2, m=field.m)
        generator = generator_polynomial(field, cosets)
        _BCH_CONTEXT = field, generator

    return _BCH_CONTEXT


def encode_frame(payload: int, generator) -> int:
    """Codifica los siete mensajes BCH de un frame."""

    encoded_frame = 0

    for lane in range(LANES):
        message = (payload >> (lane * K)) & MESSAGE_MASK

        codeword = encode(message, generator).to_int()
        encoded_frame |= codeword << (lane * N)

    return encoded_frame


def decode_frame(encoded_frame: int, field: GF2m) -> int:
    """Decodifica las siete codewords y devuelve el payload recuperado."""

    payload = 0

    for lane in range(LANES):
        received = (encoded_frame >> (lane * N)) & CODEWORD_MASK

        try:
            corrected, _ = decode(received, field)
        except (ValueError, ZeroDivisionError):
            corrected = received

        message = (corrected >> PARITY_BITS) & MESSAGE_MASK
        payload |= message << (lane * K)

    return payload


def run(
    frame_count: int = FRAME_COUNT,
    use_channel: bool = False,
    ebn0_db: float = 0.0,
    channel_seed: int = CHANNEL_SEED,
    verbose: bool = True,
) -> dict:

    if frame_count <= 0:
        raise ValueError("La cantidad de frames debe ser mayor que cero")

    field, generator_polynomial_bch = get_bch_context()

    prbs_generator = PRBS31Generator(PRBS_SEED, PRBS_TAPS)
    post_fec_checker = PRBS31Checker(PRBS_TAPS, LOCK_MATCHES)
    random_generator = random.Random(channel_seed)
    sigma = noise_sigma(ebn0_db, CODE_RATE) if use_channel else 0.0

    interleaver_fifos = [
        [0 for _ in range(branch * DELAY)]
        for branch in range(BRANCHES)
    ]

    deinterleaver_fifos = [
        [0 for _ in range((BRANCHES - 1 - branch) * DELAY)]
        for branch in range(BRANCHES)
    ]

    transmitted_frames = []
    decoded_frames = 0
    pre_fec_errors = 0

    # Se agregan TOTAL_DELAY ciclos para vaciar los interleavers.
    for cycle in range(frame_count + TOTAL_DELAY):
        if cycle < frame_count:
            payload_bits = prbs_generator.generate(PAYLOAD_BITS)
            payload = bits_to_int(payload_bits)

            encoded_frame = encode_frame(payload, generator_polynomial_bch)
            transmitted_frames.append(encoded_frame)
            channel_input = permute_lanes(encoded_frame)
        else:
            channel_input = 0

        interleaved_frame = interleave(channel_input, interleaver_fifos)

        if use_channel:
            received_frame = pam2_awgn_frame(interleaved_frame, sigma, random_generator)
        else:
            received_frame = interleaved_frame

        deinterleaved_frame = deinterleave(received_frame, deinterleaver_fifos)

        # Equivale a esperar el valid luego de la latencia del interleaver.
        if cycle < TOTAL_DELAY:
            continue

        encoded_frame = inverse_permute_lanes(deinterleaved_frame)
        frame_index = cycle - TOTAL_DELAY
        transmitted_frame = transmitted_frames[frame_index]
        decoded_payload = decode_frame(encoded_frame, field)

        pre_fec_errors += (encoded_frame ^ transmitted_frame).bit_count()
        post_fec_checker.check(int_to_bits(decoded_payload, PAYLOAD_BITS))

        decoded_frames += 1

    expected_bits = frame_count * PAYLOAD_BITS

    if not post_fec_checker.locked:
        raise RuntimeError("El checker PRBS debe adquirir lock para medir BER")

    pre_fec_bits = frame_count * LANES * N
    results = {
        "frames": frame_count,
        "pre_fec_bits": pre_fec_bits,
        "pre_fec_errors": pre_fec_errors,
        "pre_fec_ber": pre_fec_errors / pre_fec_bits,
        "post_fec_bits": post_fec_checker.checked_bits,
        "post_fec_errors": post_fec_checker.error_bits,
        "post_fec_ber": post_fec_checker.ber(),
    }

    assert decoded_frames == frame_count

    if not use_channel:
        assert pre_fec_errors == 0
        assert post_fec_checker.received_bits == expected_bits
        assert post_fec_checker.discarded_bits == 31 + LOCK_MATCHES
        assert (post_fec_checker.checked_bits == expected_bits - post_fec_checker.discarded_bits)
        assert post_fec_checker.error_bits == 0
        assert post_fec_checker.ber() == 0.0

    if verbose:
        mode = f"AWGN, Eb/N0 = {ebn0_db:.1f} dB" if use_channel else "sin ruido"
        print(f"Cadena FEC completa: {mode}")
        print(f"Frames transmitidos : {frame_count}")
        print(f"Frames decodificados: {decoded_frames}")
        print(f"Bits pre-FEC        : {results['pre_fec_bits']}")
        print(f"Errores pre-FEC     : {results['pre_fec_errors']}")
        print(f"BER pre-FEC         : {results['pre_fec_ber']:.3e}")
        print(f"Bits post-FEC       : {results['post_fec_bits']}")
        print(f"Errores post-FEC    : {results['post_fec_errors']}")
        print(f"BER post-FEC        : {results['post_fec_ber']:.3e}")

    return results


if __name__ == "__main__":
    run(frame_count=FRAME_COUNT, use_channel=False)
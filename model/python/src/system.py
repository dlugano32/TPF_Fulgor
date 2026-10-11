import random

from model.python.src.awgn_channel import noise_sigma, pam2_awgn_frame
from model.python.src.bch_decoder import decode
from model.python.src.bch_design import cosets_for_t, generator_polynomial
from model.python.src.bch_encoder import K, N, build_parity_matrix, encode
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


def parity_masks_from_matrix(matrix: list[list]) -> list[int]:
    """Convierte las columnas de P en máscaras para XOR y popcount."""

    parity_masks = []

    for parity_bit in range(PARITY_BITS):
        mask = 0

        for message_bit in range(K):
            mask |= int(matrix[message_bit][parity_bit]) << message_bit

        parity_masks.append(mask)

    return parity_masks


def get_bch_context():
    """Construye una sola vez el campo, g(x) y las máscaras de paridad."""

    global _BCH_CONTEXT

    if _BCH_CONTEXT is None:
        field = GF2m(m=7, primitive_poly=0b0001001)
        cosets = cosets_for_t(t=2, m=field.m)
        generator = generator_polynomial(field, cosets)
        gf2 = GF2m(m=1, primitive_poly=0b1)
        parity_matrix = build_parity_matrix(generator, gf2)
        parity_masks = parity_masks_from_matrix(parity_matrix)
        _BCH_CONTEXT = field, generator, parity_masks

    return _BCH_CONTEXT


def encode_frame(payload: int, generator, parity_masks=None) -> int:
    """Codifica los siete mensajes BCH de un frame."""

    encoded_frame = 0

    for lane in range(LANES):
        message = (payload >> (lane * K)) & MESSAGE_MASK

        if parity_masks is None:
            codeword = encode(message, generator).to_int()
        else:
            parity = 0

            for parity_bit, mask in enumerate(parity_masks):
                parity |= ((message & mask).bit_count() & 1) << parity_bit

            codeword = (message << PARITY_BITS) | parity

        encoded_frame |= codeword << (lane * N)

    return encoded_frame


def decode_frame(
    encoded_frame: int,
    field: GF2m,
    expected_frame: int | None = None,
) -> tuple[int, int, int]:
    """Decodifica los codewords y devuelve payload, correcciones y fallas."""

    payload = 0
    corrections = 0
    decoder_failures = 0

    for lane in range(LANES):
        received = (encoded_frame >> (lane * N)) & CODEWORD_MASK
        expected = None

        if expected_frame is not None:
            expected = (expected_frame >> (lane * N)) & CODEWORD_MASK

        # En Monte Carlo, evitar el decoder cuando el canal no modificó la
        # codeword acelera los puntos de BER baja sin cambiar el resultado.
        if expected is not None and received == expected:
            corrected = received
            error_positions = []
        else:
            try:
                corrected, error_positions = decode(received, field)
            except (ValueError, ZeroDivisionError):
                corrected = received
                error_positions = []
                decoder_failures += 1

        message = (corrected >> PARITY_BITS) & MESSAGE_MASK

        payload |= message << (lane * K)
        corrections += len(error_positions)

    return payload, corrections, decoder_failures


def run(
    frame_count: int = FRAME_COUNT,
    use_channel: bool = False,
    ebn0_db: float = 0.0,
    channel_seed: int = CHANNEL_SEED,
    verbose: bool = True,
) -> dict:

    if frame_count <= 0:
        raise ValueError("La cantidad de frames debe ser mayor que cero")

    field, generator_polynomial_bch, parity_masks = get_bch_context()

    prbs_generator = PRBS31Generator(PRBS_SEED, PRBS_TAPS)
    prbs_checker = PRBS31Checker(PRBS_TAPS, LOCK_MATCHES)
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
    transmitted_payloads = []
    decoded_frames = 0
    total_corrections = 0
    decoder_failures = 0
    pre_fec_errors = 0
    post_fec_errors = 0
    post_fec_frame_errors = 0

    # TOTAL_DELAY es el delay total del interleaver. Son unos ciclos adicionales para recuperar todos los frames ingresados al mismo.
    for cycle in range(frame_count + TOTAL_DELAY):
        if cycle < frame_count:
            payload_bits = prbs_generator.generate(PAYLOAD_BITS)
            payload = bits_to_int(payload_bits)
            encoder_masks = parity_masks if use_channel else None
            encoded_frame = encode_frame(
                payload,
                generator_polynomial_bch,
                encoder_masks,
            )
            transmitted_frames.append(encoded_frame)
            transmitted_payloads.append(payload)
            channel_input = permute_lanes(encoded_frame)
        else:
            channel_input = 0

        interleaved_frame = interleave(channel_input, interleaver_fifos)

        if use_channel:
            received_frame = pam2_awgn_frame(
                interleaved_frame,
                sigma,
                random_generator,
            )
        else:
            received_frame = interleaved_frame

        deinterleaved_frame = deinterleave(received_frame, deinterleaver_fifos)

        # Equivalente a esperar una señal de valid de datos. Los primeros 7 ciclos tienen mensajes nulos por la purga de las fifos de los interleavers
        if cycle < TOTAL_DELAY:
            continue

        encoded_frame = inverse_permute_lanes(deinterleaved_frame)
        frame_index = cycle - TOTAL_DELAY
        expected_frame = transmitted_frames[frame_index]
        expected_payload = transmitted_payloads[frame_index]

        pre_fec_errors += (encoded_frame ^ expected_frame).bit_count()

        decoder_reference = expected_frame if use_channel else None
        payload, corrections, failures = decode_frame(
            encoded_frame,
            field,
            decoder_reference,
        )
        payload_errors = (payload ^ expected_payload).bit_count()

        prbs_checker.check(int_to_bits(payload, PAYLOAD_BITS))

        decoded_frames += 1
        total_corrections += corrections
        decoder_failures += failures
        post_fec_errors += payload_errors
        post_fec_frame_errors += payload_errors != 0

    expected_bits = frame_count * PAYLOAD_BITS
    pre_fec_bits = frame_count * LANES * N
    post_fec_bits = frame_count * PAYLOAD_BITS
    results = {
        "frames": frame_count,
        "pre_fec_bits": pre_fec_bits,
        "pre_fec_errors": pre_fec_errors,
        "pre_fec_ber": pre_fec_errors / pre_fec_bits,
        "post_fec_bits": post_fec_bits,
        "post_fec_errors": post_fec_errors,
        "post_fec_ber": post_fec_errors / post_fec_bits,
        "post_fec_frame_errors": post_fec_frame_errors,
        "post_fec_fer": post_fec_frame_errors / frame_count,
        "corrections": total_corrections,
        "decoder_failures": decoder_failures,
        "checker": prbs_checker,
    }

    assert decoded_frames == frame_count

    if not use_channel:
        assert total_corrections == 0
        assert decoder_failures == 0
        assert pre_fec_errors == 0
        assert post_fec_errors == 0
        assert prbs_checker.locked
        assert prbs_checker.received_bits == expected_bits
        assert prbs_checker.discarded_bits == 31 + LOCK_MATCHES
        assert prbs_checker.checked_bits == expected_bits - prbs_checker.discarded_bits
        assert prbs_checker.error_bits == 0
        assert prbs_checker.ber() == 0.0

    if verbose:
        mode = f"AWGN, Eb/N0 = {ebn0_db:.1f} dB" if use_channel else "sin ruido"
        print(f"Cadena FEC completa: {mode}")
        print(f"Frames transmitidos : {frame_count}")
        print(f"Frames decodificados: {decoded_frames}")
        print(f"Errores pre-FEC     : {pre_fec_errors}")
        print(f"BER pre-FEC         : {results['pre_fec_ber']:.3e}")
        print(f"Correcciones BCH    : {total_corrections}")
        print(f"Fallas del decoder  : {decoder_failures}")
        print(f"Errores post-FEC    : {post_fec_errors}")
        print(f"BER post-FEC        : {results['post_fec_ber']:.3e}")
        print(f"FER post-FEC        : {results['post_fec_fer']:.3e}")

    return results


if __name__ == "__main__":
    run()

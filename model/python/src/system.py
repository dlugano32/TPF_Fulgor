import random

from model.python.src.awgn_channel import noise_sigma, pam2_awgn_frame
from model.python.src.bch_decoder import decode
from model.python.src.bch_design import cosets_for_t, generator_polynomial
from model.python.src.bch_encoder import K, N, build_parity_matrix, encode_with_matrix, parity_masks_from_matrix
from model.python.src.interleaver import BRANCHES, DELAY, FRAME_BITS, TOTAL_DELAY, deinterleave, interleave
from model.python.src.lane_permutation import LANES, inverse_permute_lanes, permute_lanes
from model.python.src.prbs31 import PRBS31Generator
from model.python.src.prbs_checker import PRBS31Checker
from model.python.tools.GF2m import GF2m


PRBS_TAPS = [30, 27]
PRBS_SEED = 0x5A17C3D2
LOCK_MATCHES = 31
FRAME_COUNT = 100
CHANNEL_SEED = 2026
CHANNEL_MODES = ("none", "awgn", "burst")
CODE_RATE = K / N
PAYLOAD_BITS = LANES * K
PARITY_BITS = N - K
MESSAGE_MASK = (1 << K) - 1
CODEWORD_MASK = (1 << N) - 1
BURST_REFERENCE_CYCLE = TOTAL_DELAY + 1     # Delay del interleaver + delay del lock de PRBS checker


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


class FECSystem:
    """Modelo reutilizable de la cadena FEC completa."""

    def __init__(self, mode: str):
        if mode not in CHANNEL_MODES:
            raise ValueError(
                f"El modo debe ser uno de: {', '.join(CHANNEL_MODES)}"
            )

        self.mode = mode
        self.field = GF2m(m=7, primitive_poly=0b0001001)
        cosets = cosets_for_t(t=2, m=self.field.m)
        self.generator = generator_polynomial(self.field, cosets)

        gf2 = GF2m(m=1, primitive_poly=0b1)
        parity_matrix = build_parity_matrix(self.generator, gf2)
        self.parity_masks = parity_masks_from_matrix(parity_matrix)

        self.prbs_generator = PRBS31Generator(PRBS_SEED, PRBS_TAPS)
        self.post_fec_checker = PRBS31Checker(PRBS_TAPS, LOCK_MATCHES)
        self.random_generator = random.Random(CHANNEL_SEED)

        self.interleaver_fifos = [
            [0 for _ in range(branch * DELAY)]
            for branch in range(BRANCHES)
        ]
        self.deinterleaver_fifos = [
            [0 for _ in range((BRANCHES - 1 - branch) * DELAY)]
            for branch in range(BRANCHES)
        ]

    def _reset(self, channel_seed: int) -> None:
        """Reinicia el estado mutable sin reinstanciar los componentes."""

        self.prbs_generator.reset()
        self.post_fec_checker.reset()
        self.random_generator.seed(channel_seed)

        for fifo in self.interleaver_fifos:
            fifo[:] = [0 for _ in fifo]

        for fifo in self.deinterleaver_fifos:
            fifo[:] = [0 for _ in fifo]

    def encode_frame(self, payload: int) -> int:
        """Codifica los siete mensajes BCH mediante la matriz de paridad."""

        encoded_frame = 0

        for lane in range(LANES):
            message = (payload >> (lane * K)) & MESSAGE_MASK
            codeword = encode_with_matrix(message, self.parity_masks)
            encoded_frame |= codeword << (lane * N)

        return encoded_frame

    def decode_frame(self, encoded_frame: int) -> int:
        """Decodifica las siete codewords y devuelve el payload recuperado."""

        payload = 0

        for lane in range(LANES):
            received = (encoded_frame >> (lane * N)) & CODEWORD_MASK

            try:
                corrected, _ = decode(received, self.field)
            except (ValueError, ZeroDivisionError):
                corrected = received

            message = (corrected >> PARITY_BITS) & MESSAGE_MASK
            payload |= message << (lane * K)

        return payload

    @staticmethod
    def burst_mask_for_cycle(cycle: int, burst_offset: int, burst_length: int) -> int:
        """Devuelve la parte de la ráfaga que cae en el ciclo indicado."""

        burst_start = BURST_REFERENCE_CYCLE * FRAME_BITS + burst_offset
        burst_end = burst_start + burst_length
        frame_start = cycle * FRAME_BITS
        frame_end = frame_start + FRAME_BITS
        overlap_start = max(burst_start, frame_start)
        overlap_end = min(burst_end, frame_end)

        if overlap_start >= overlap_end:
            return 0

        local_start = overlap_start - frame_start
        overlap_length = overlap_end - overlap_start
        return ((1 << overlap_length) - 1) << local_start

    def _validate_run(self, frame_count: int, burst_length: int | None, burst_offset: int) -> None:
        if frame_count <= 0:
            raise ValueError("La cantidad de frames debe ser mayor que cero")

        if self.mode == "burst" and burst_length is None:
            raise ValueError("El modo burst requiere indicar burst_length")

        if self.mode != "burst" and burst_length is not None:
            raise ValueError("burst_length sólo puede usarse en modo burst")

        if self.mode == "burst":
            if burst_length <= 0 or burst_length > FRAME_BITS:
                raise ValueError(
                    f"La longitud del burst debe estar entre 1 y {FRAME_BITS}"
                )

            if burst_offset < 0 or burst_offset >= FRAME_BITS:
                raise ValueError(
                    f"El offset del burst debe estar entre 0 y {FRAME_BITS - 1}"
                )

            minimum_frames = BURST_REFERENCE_CYCLE + 2

            if frame_count < minimum_frames:
                raise ValueError(
                    f"El modo burst requiere al menos {minimum_frames} frames"
                )

    def run(
        self,
        frame_count: int = FRAME_COUNT,
        ebn0_db: float = 0.0,
        channel_seed: int = CHANNEL_SEED,
        burst_length: int | None = None,
        burst_offset: int = 0,
        verbose: bool = True,
    ) -> dict:
        self._validate_run(frame_count, burst_length, burst_offset)
        self._reset(channel_seed)

        sigma = noise_sigma(ebn0_db, CODE_RATE) if self.mode == "awgn" else 0.0
        transmitted_frames = []
        decoded_frames = 0
        pre_fec_errors = 0

        # Se agregan TOTAL_DELAY ciclos para vaciar los interleavers.
        for cycle in range(frame_count + TOTAL_DELAY):
            if cycle < frame_count:
                payload_bits = self.prbs_generator.generate(PAYLOAD_BITS)
                payload = bits_to_int(payload_bits)

                encoded_frame = self.encode_frame(payload)
                transmitted_frames.append(encoded_frame)
                channel_input = permute_lanes(encoded_frame)
            else:
                channel_input = 0

            interleaved_frame = interleave(channel_input, self.interleaver_fifos)

            if self.mode == "awgn":
                received_frame = pam2_awgn_frame(interleaved_frame, sigma, self.random_generator)
            elif self.mode == "burst":
                error_mask = self.burst_mask_for_cycle(cycle, burst_offset, burst_length)
                received_frame = interleaved_frame ^ error_mask
            else:
                received_frame = interleaved_frame

            deinterleaved_frame = deinterleave(received_frame, self.deinterleaver_fifos)

            # Equivale a esperar el valid luego de la latencia del interleaver.
            if cycle < TOTAL_DELAY:
                continue

            encoded_frame = inverse_permute_lanes(deinterleaved_frame)
            frame_index = cycle - TOTAL_DELAY
            transmitted_frame = transmitted_frames[frame_index]
            decoded_payload = self.decode_frame(encoded_frame)

            pre_fec_errors += (encoded_frame ^ transmitted_frame).bit_count()
            self.post_fec_checker.check(int_to_bits(decoded_payload, PAYLOAD_BITS))
            decoded_frames += 1

        expected_bits = frame_count * PAYLOAD_BITS

        if not self.post_fec_checker.locked:
            raise RuntimeError("El checker PRBS debe adquirir lock para medir BER")

        pre_fec_bits = frame_count * LANES * N
        results = {
            "frames": frame_count,
            "pre_fec_bits": pre_fec_bits,
            "pre_fec_errors": pre_fec_errors,
            "pre_fec_ber": pre_fec_errors / pre_fec_bits,
            "post_fec_bits": self.post_fec_checker.checked_bits,
            "post_fec_errors": self.post_fec_checker.error_bits,
            "post_fec_ber": self.post_fec_checker.ber(),
        }

        assert decoded_frames == frame_count

        if self.mode == "none":
            assert pre_fec_errors == 0
            assert self.post_fec_checker.received_bits == expected_bits
            assert self.post_fec_checker.discarded_bits == 31 + LOCK_MATCHES
            assert (self.post_fec_checker.checked_bits == expected_bits - self.post_fec_checker.discarded_bits)
            assert self.post_fec_checker.error_bits == 0
            assert self.post_fec_checker.ber() == 0.0

        if verbose:
            self._print_results(results, decoded_frames, ebn0_db, burst_length, burst_offset)

        return results

    def _print_results(self, results: dict, decoded_frames: int, ebn0_db: float, burst_length: int | None, burst_offset: int) -> None:
        if self.mode == "awgn":
            mode_description = f"AWGN, Eb/N0 = {ebn0_db:.1f} dB"
        elif self.mode == "burst":
            mode_description = (f"burst de {burst_length} bits, offset {burst_offset}")
        else:
            mode_description = "sin ruido"

        print(f"Cadena FEC completa: {mode_description}")
        print(f"Frames transmitidos : {results['frames']}")
        print(f"Frames decodificados: {decoded_frames}")
        print(f"Bits pre-FEC        : {results['pre_fec_bits']}")
        print(f"Errores pre-FEC     : {results['pre_fec_errors']}")
        print(f"BER pre-FEC         : {results['pre_fec_ber']:.3e}")
        print(f"Bits post-FEC       : {results['post_fec_bits']}")
        print(f"Errores post-FEC    : {results['post_fec_errors']}")
        print(f"BER post-FEC        : {results['post_fec_ber']:.3e}")


if __name__ == "__main__":
    system = FECSystem(mode="none")
    system.run(frame_count=FRAME_COUNT)

"""Pruebas de integración de la cadena completa y del barrido de ráfagas."""

import random
import unittest
from unittest.mock import patch

from model.python.src.bch_decoder import decode
from model.python.src.bch_encoder import K, N, encode
from model.python.src.burst_sweep import FIRST_START, post_fec_errors_for_burst, sweep_bursts
from model.python.src.interleaver import FRAME_BITS, TOTAL_DELAY
from model.python.src.system import FECSystem, LANES, encode_frame, run


class TestFECSystem(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.system = FECSystem()

    def test_mask_encoder_matches_polynomial_encoder(self) -> None:
        random_generator = random.Random(127113)

        for _ in range(10):
            payload = random_generator.getrandbits(LANES * K)
            expected = 0

            for lane in range(LANES):
                message = (payload >> (lane * K)) & ((1 << K) - 1)
                expected |= encode(message, self.system.generator).to_int() << (lane * N)

            self.assertEqual(
                encode_frame(payload, self.system.parity_masks),
                expected,
            )

    def test_no_channel_has_zero_ber(self) -> None:
        results = self.system.run(
            frame_count=2,
            channel_mode="none",
            verbose=False,
        )

        self.assertEqual(results["pre_fec_errors"], 0)
        self.assertEqual(results["post_fec_errors"], 0)
        self.assertEqual(results["decoder_failures"], 0)

    def test_no_channel_uses_the_real_decoder(self) -> None:
        system = FECSystem()

        with patch("model.python.src.system.decode", wraps=decode) as decoder:
            system.run(frame_count=1, channel_mode="none", verbose=False)

        self.assertEqual(decoder.call_count, LANES)

    def test_compatible_run_function(self) -> None:
        results = run(frame_count=1, channel_mode="none", verbose=False)

        self.assertEqual(results["frames"], 1)
        self.assertEqual(results["post_fec_ber"], 0.0)

    def test_fast_burst_model_matches_complete_system(self) -> None:
        cases = [
            (848, 98),
            (848, 99),
            (777, 113),
            (777, 114),
        ]

        for offset, burst_length in cases:
            expected_errors = post_fec_errors_for_burst(
                self.system,
                FIRST_START + offset,
                burst_length,
            )
            results = self.system.run(
                frame_count=TOTAL_DELAY + 2,
                channel_mode="burst",
                burst_start=FIRST_START + offset,
                burst_length=burst_length,
                verbose=False,
            )

            self.assertEqual(results["post_fec_errors"], expected_errors)

    def test_complete_offset_sweep(self) -> None:
        results = sweep_bursts(verbose=False)
        table = {
            row["burst_length"]: row["failing_offset_count"]
            for row in results["table"]
        }

        self.assertEqual(results["maximum_guaranteed_correctable"], 98)
        self.assertEqual(results["first_potential_failure"], 99)
        self.assertEqual(results["last_not_universal_failure"], 113)
        self.assertEqual(results["first_universal_failure"], 114)
        self.assertEqual(table, {98: 0, 99: 72, 113: 887, 114: FRAME_BITS})


if __name__ == "__main__":
    unittest.main()

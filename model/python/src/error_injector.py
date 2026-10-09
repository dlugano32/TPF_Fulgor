import random


FRAME_BITS = 889
SEED = 2026


def inject_random_errors(
    frames: list[int], probability: float, seed: int
) -> tuple[list[int], list[int]]:
    """Invierte cada bit independientemente con probabilidad p."""

    if probability < 0.0 or probability > 1.0:
        raise ValueError("La probabilidad debe pertenecer al intervalo [0, 1]")

    random_generator = random.Random(seed)
    corrupted_frames = []
    error_masks = []

    for frame in frames:
        if frame < 0 or frame >= 1 << FRAME_BITS:
            raise ValueError(f"Cada frame debe tener hasta {FRAME_BITS} bits")

        error_mask = 0

        for bit_index in range(FRAME_BITS):
            if random_generator.random() < probability:
                error_mask |= 1 << bit_index

        corrupted_frames.append(frame ^ error_mask)
        error_masks.append(error_mask)

    return corrupted_frames, error_masks


def inject_burst(
    frames: list[int], start_position: int, burst_length: int
) -> tuple[list[int], list[int]]:
    """Invierte una ráfaga de bits consecutivos sobre el flujo de frames."""

    stream_bits = len(frames) * FRAME_BITS

    if start_position < 0:
        raise ValueError("La posición inicial no puede ser negativa")

    if burst_length < 0:
        raise ValueError("La longitud de la ráfaga no puede ser negativa")

    if start_position + burst_length > stream_bits:
        raise ValueError("La ráfaga excede la longitud del flujo")

    corrupted_frames = frames.copy()
    error_masks = [0 for _ in frames]

    for stream_position in range(start_position, start_position + burst_length):
        frame_index = stream_position // FRAME_BITS
        bit_index = stream_position % FRAME_BITS
        error_masks[frame_index] |= 1 << bit_index

    for frame_index, error_mask in enumerate(error_masks):
        corrupted_frames[frame_index] ^= error_mask

    return corrupted_frames, error_masks


def main() -> None:
    random_generator = random.Random(SEED)
    frames = [random_generator.getrandbits(FRAME_BITS) for _ in range(4)]

    # Los extremos p=0 y p=1 no alteran ningún bit o los invierten todos.
    output_zero, masks_zero = inject_random_errors(frames, 0.0, SEED)
    output_one, masks_one = inject_random_errors(frames, 1.0, SEED)
    frame_mask = (1 << FRAME_BITS) - 1

    assert output_zero == frames
    assert masks_zero == [0 for _ in frames]
    assert output_one == [frame ^ frame_mask for frame in frames]
    assert masks_one == [frame_mask for _ in frames]

    # Una misma semilla debe producir exactamente el mismo patrón de errores.
    output, masks = inject_random_errors(frames, 0.01, SEED)
    repeated_output, repeated_masks = inject_random_errors(frames, 0.01, SEED)

    assert output == repeated_output
    assert masks == repeated_masks

    # La ráfaga atraviesa el límite entre el primer y el segundo frame.
    burst_output, burst_masks = inject_burst(frames, FRAME_BITS - 5, 12)

    assert burst_masks[0].bit_count() == 5
    assert burst_masks[1].bit_count() == 7
    assert sum(mask.bit_count() for mask in burst_masks) == 12

    for original, corrupted, error_mask in zip(frames, burst_output, burst_masks):
        assert corrupted == original ^ error_mask

    print("Inyector de errores")
    print("Errores independientes p=0 : OK")
    print("Errores independientes p=1 : OK")
    print("Repetibilidad               : OK")
    print("Ráfaga entre frames         : 12 errores, OK")


if __name__ == "__main__":
    main()

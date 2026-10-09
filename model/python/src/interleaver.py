import random


FRAME_BITS = 889
BRANCHES = 8
DELAY = 1
TOTAL_DELAY = (BRANCHES - 1) * DELAY


BRANCH_MASKS = [
    sum(
        1 << position
        for position in range(FRAME_BITS)
        if position % BRANCHES == branch
    )
    for branch in range(BRANCHES)
]


def interleave(frame: int, fifos: list[list[int]]) -> int:
    """Aplica los retardos 0, 1, ..., 7 a las ramas del frame."""

    if frame < 0 or frame >= 1 << FRAME_BITS:
        raise ValueError(f"El frame debe tener hasta {FRAME_BITS} bits")

    output = 0

    for branch in range(BRANCHES):
        branch_data = frame & BRANCH_MASKS[branch]
        branch_delay = branch * DELAY

        if branch_delay == 0:
            delayed_data = branch_data
        else:
            delayed_data = fifos[branch].pop(0)
            fifos[branch].append(branch_data)

        output |= delayed_data

    return output


def deinterleave(frame: int, fifos: list[list[int]]) -> int:
    """Aplica los retardos complementarios 7, 6, ..., 0."""

    if frame < 0 or frame >= 1 << FRAME_BITS:
        raise ValueError(f"El frame debe tener hasta {FRAME_BITS} bits")

    output = 0

    for branch in range(BRANCHES):
        branch_data = frame & BRANCH_MASKS[branch]
        branch_delay = (BRANCHES - 1 - branch) * DELAY

        if branch_delay == 0:
            delayed_data = branch_data
        else:
            delayed_data = fifos[branch].pop(0)
            fifos[branch].append(branch_data)

        output |= delayed_data

    return output


def main() -> None:
    interleaver_fifos = [
        [0 for _ in range(branch * DELAY)]
        for branch in range(BRANCHES)
    ]
    deinterleaver_fifos = [
        [0 for _ in range((BRANCHES - 1 - branch) * DELAY)]
        for branch in range(BRANCHES)
    ]

    random_generator = random.Random(2026)
    input_frames = [(1 << FRAME_BITS) - 1]

    # Armamos 14 frames
    for _ in range(15):
        input_frames.append(random_generator.getrandbits(FRAME_BITS))

    output_frames = []

    # Los frames nulos finales vacían la fifo del interleaver
    for frame in input_frames + [0 for _ in range(TOTAL_DELAY)]:
        interleaved = interleave(frame, interleaver_fifos)
        recovered = deinterleave(interleaved, deinterleaver_fifos)
        output_frames.append(recovered)

    # expected_frames = latencia de 7 frames + input frames
    expected_frames = [0 for _ in range(TOTAL_DELAY)] +  input_frames

    assert output_frames == expected_frames

    print("Interleaver convolucional")
    print(f"Bits por frame       : {FRAME_BITS}")
    print(f"Ramas                : {BRANCHES}")
    print(f"Retardo elemental    : {DELAY} frame")
    print(f"Latencia total       : {TOTAL_DELAY} frames")
    print("Interleaver + inversa: OK")


if __name__ == "__main__":
    main()

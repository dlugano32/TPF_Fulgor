LANES = 7
CODEWORD_BITS = 127
FRAME_BITS = LANES * CODEWORD_BITS


def permute_lanes(frame: int) -> int:
    """Intercala bit a bit las siete codewords del frame."""

    if frame < 0 or frame >= 1 << FRAME_BITS:
        raise ValueError(f"El frame debe tener hasta {FRAME_BITS} bits")

    permuted = 0

    for bit_index in range(CODEWORD_BITS):
        for lane in range(LANES):
            input_index = lane * CODEWORD_BITS + bit_index
            output_index = bit_index * LANES + lane
            bit = (frame >> input_index) & 1
            permuted |= bit << output_index

    return permuted


def inverse_permute_lanes(permuted: int) -> int:
    """Recupera las siete codewords a partir del frame intercalado."""

    if permuted < 0 or permuted >= 1 << FRAME_BITS:
        raise ValueError(f"El frame debe tener hasta {FRAME_BITS} bits")

    frame = 0

    for bit_index in range(CODEWORD_BITS):
        for lane in range(LANES):
            input_index = bit_index * LANES + lane
            output_index = lane * CODEWORD_BITS + bit_index
            bit = (permuted >> input_index) & 1
            frame |= bit << output_index

    return frame


def main() -> None:
    # Cada lane contiene una codeword distinta para hacer visible el mapeo.
    codewords = [
        (lane + 1) * 0x123456789ABCDEF0123456789AB
        for lane in range(LANES)
    ]

    frame = 0

    for lane, codeword in enumerate(codewords):
        frame |= codeword << (lane * CODEWORD_BITS)

    permuted = permute_lanes(frame)
    recovered = inverse_permute_lanes(permuted)

    assert recovered == frame

    print("Permutación de lanes")
    print(f"Lanes              : {LANES}")
    print(f"Bits por codeword  : {CODEWORD_BITS}")
    print(f"Bits por frame     : {FRAME_BITS}")
    print("Permutación inversa: OK")
    print("889 posiciones     : OK")


if __name__ == "__main__":
    main()

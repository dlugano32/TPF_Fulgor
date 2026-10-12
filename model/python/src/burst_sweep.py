from model.python.src.interleaver import FRAME_BITS
from model.python.src.system import BURST_REFERENCE_CYCLE, FECSystem


MIN_BURST_LENGTH = 3
MAX_BURST_LENGTH = 127
FRAME_COUNT = BURST_REFERENCE_CYCLE + 2


def count_failing_offsets(system: FECSystem, burst_length: int) -> int:
    """Cuenta las fases que dejan al menos un error post-FEC."""

    failing_offsets = 0

    for burst_offset in range(FRAME_BITS):
        result = system.run(
            frame_count=FRAME_COUNT,
            burst_length=burst_length,
            burst_offset=burst_offset,
            verbose=False,
        )

        if result["post_fec_errors"] > 0:
            failing_offsets += 1

    return failing_offsets


def sweep() -> list[dict]:
    """Barre longitudes y las 889 fases posibles del inicio del burst."""

    system = FECSystem(mode="burst")
    results = []
    print("Longitud | Offsets con error post-FEC | Offsets evaluados")
    print("---------+----------------------------+------------------")

    for burst_length in range(MIN_BURST_LENGTH, MAX_BURST_LENGTH + 1):
        failing_offsets = count_failing_offsets(system, burst_length)
        result = {
            "burst_length": burst_length,
            "failing_offsets": failing_offsets,
            "total_offsets": FRAME_BITS,
        }
        results.append(result)

        print(
            f"{burst_length:8d} | {failing_offsets:26d} | "
            f"{FRAME_BITS:17d}"
        )

    return results


def summarize(results: list[dict]) -> None:
    """Resume los límites que surgen del barrido exhaustivo."""

    always_correctable = [
        result["burst_length"]
        for result in results
        if result["failing_offsets"] == 0
    ]
    sometimes_failing = [
        result["burst_length"]
        for result in results
        if result["failing_offsets"] > 0
    ]
    sometimes_correctable = [
        result["burst_length"]
        for result in results
        if result["failing_offsets"] < result["total_offsets"]
    ]
    always_failing = [
        result["burst_length"]
        for result in results
        if result["failing_offsets"] == result["total_offsets"]
    ]

    print("\nResumen")
    print(f"Máxima longitud siempre corregible : {max(always_correctable)}")
    print(f"Primera longitud con algún error   : {min(sometimes_failing)}")
    print(f"Máxima longitud aún corregible     : {max(sometimes_correctable)}")
    print(f"Primera longitud siempre con error : {min(always_failing)}")


def main() -> None:
    results = sweep()
    summarize(results)


if __name__ == "__main__":
    main()

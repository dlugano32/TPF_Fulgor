"""Simulacion simple del gearbox 889->1024 y la FIFO CDC."""


INPUT_WIDTH = 889
OUTPUT_WIDTH = 1024

# Unidad de tiempo normalizada.
FEC_PERIOD = 889
DSP_PERIOD = 1024
SUPERPERIOD = FEC_PERIOD * DSP_PERIOD

# Configuración
SYNC_STAGES = 2
FIFO_DEPTH = 8
ALMOST_FULL = 7
BACKPRESSURE_CYCLES = 1
START_LEVELS = range(1, 5)


def shift_pipeline(pipeline: list[int], value: int) -> int:
    """
        Desplaza un sincronizador y devuelve su salida.
        Nos ayuda a simular el sincronizador de FFs.
    """

    pipeline.insert(0, value)
    pipeline.pop()

    return pipeline[-1]


def simulate_phase(phase: int, start_level: int) -> dict:
    """Simula una fase relativa durante un superperiodo completo."""

    gearbox_bits = 0
    write_ptr = 0
    read_ptr = 0

    write_sync = [0] * SYNC_STAGES
    read_sync = [0] * SYNC_STAGES
    sync_write_ptr = 0
    sync_read_ptr = 0

    stop_pipeline = [False] * BACKPRESSURE_CYCLES
    read_started = False

    gaps = 0
    overflows = 0
    backpressure_cycles = 0
    maximum_occupancy = 0

    next_fec_edge = FEC_PERIOD
    next_dsp_edge = phase if phase > 0 else DSP_PERIOD
    final_time = next_dsp_edge + SUPERPERIOD

    while next_fec_edge <= final_time or next_dsp_edge <= final_time:

        # Ante un empate de clocks, se analiza primero el read, ya que sería el peor caso

        # Si el proximo evento es un flanco DSP -> Read
        if next_dsp_edge <= next_fec_edge and next_dsp_edge <= final_time:
            sync_write_ptr = shift_pipeline(write_sync, write_ptr)

            # Cuantas palabras disponibles se ven desde DSP
            visible_occupancy = sync_write_ptr - read_ptr

            # Umbral de arranque
            if not read_started and visible_occupancy >= start_level:
                read_started = True

            if read_started:
                if visible_occupancy <= 0:
                    gaps += 1   # underflow
                else:
                    read_ptr += 1

            next_dsp_edge += DSP_PERIOD

        # Proximo evento es un flanco de FEC -> Write
        elif next_fec_edge <= final_time:
            sync_read_ptr = shift_pipeline(read_sync, read_ptr)

            # Cuantas palabras escritas se ven desde FEC.
            visible_occupancy = write_ptr - sync_read_ptr
            stop_request = visible_occupancy >= ALMOST_FULL

            if BACKPRESSURE_CYCLES == 0:
                stop_active = stop_request
            else:
                stop_active = stop_pipeline.pop(0)
                stop_pipeline.append(stop_request)

            # Si hay backpressure cycles se dejan de generar bits hasta que se consuman los datos de la FIFO
            if stop_active:
                backpressure_cycles += 1
            else:
                gearbox_bits += INPUT_WIDTH

                if gearbox_bits >= OUTPUT_WIDTH:
                    physical_occupancy = write_ptr - read_ptr

                    if physical_occupancy >= FIFO_DEPTH:
                        overflows += 1  # Overflow
                    else:
                        gearbox_bits -= OUTPUT_WIDTH
                        write_ptr += 1

            next_fec_edge += FEC_PERIOD

        physical_occupancy = write_ptr - read_ptr
        maximum_occupancy = max(maximum_occupancy, physical_occupancy)

    return {
        "gaps": gaps,
        "overflows": overflows,
        "backpressure_cycles": backpressure_cycles,
        "maximum_occupancy": maximum_occupancy,
    }


def simulate_start_level(start_level: int) -> dict:
    """Barre todas las fases para un unico START_LEVEL."""

    failed_phases = 0
    total_gaps = 0
    total_overflows = 0
    phases_with_backpressure = 0
    maximum_occupancy = 0

    # Lo simulo para 1024 fases relativas al periodo de FEC
    for phase in range(DSP_PERIOD):
        result = simulate_phase(phase, start_level)

        if result["gaps"] > 0 or result["overflows"] > 0:
            failed_phases += 1

        if result["backpressure_cycles"] > 0:
            phases_with_backpressure += 1

        total_gaps += result["gaps"]
        total_overflows += result["overflows"]
        maximum_occupancy = max(maximum_occupancy, result["maximum_occupancy"])

    return {
        "failed_phases": failed_phases,
        "gaps": total_gaps,
        "overflows": total_overflows,
        "phases_with_backpressure": phases_with_backpressure,
        "maximum_occupancy": maximum_occupancy,
    }


def main() -> None:
    print("CONFIGURACION")
    print(f"SYNC_STAGES         = {SYNC_STAGES}")
    print(f"FIFO_DEPTH          = {FIFO_DEPTH}")
    print(f"ALMOST_FULL         = {ALMOST_FULL}")
    print(f"BACKPRESSURE_CYCLES = {BACKPRESSURE_CYCLES}")

    print("\nUmbral | Failed Cycles | Gaps | Overflow | BP Cycles | Max ocup.")
    print("-------+---------------+------+----------+-----------+-----------")

    for start_level in START_LEVELS:
        result = simulate_start_level(start_level)
        print(
            f"{start_level:6d} | "
            f"{result['failed_phases']:13d} | "
            f"{result['gaps']:4d} | "
            f"{result['overflows']:8d} | "
            f"{result['phases_with_backpressure']:9d} | "
            f"{result['maximum_occupancy']:8d}"
        )


if __name__ == "__main__":
    main()

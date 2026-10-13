from pathlib import Path

from model.python.tools.GF2m import GF2m
from model.python.tools.GF2m_matrix import (
    matrix_matrix_product,
    matrix_vector_product,
    vector_matrix_product,
)


ORDER = 31
TAPS = [30, 27]
STATE_MASK = (1 << ORDER) - 1
PARALLELISM = 791


class PRBS31Generator:
    """Generador PRBS31 serie"""

    def __init__(self, seed: int, taps: list[int]):
        if seed <= 0 or seed > STATE_MASK:
            raise ValueError("La seed debe ser un valor no nulo de 31 bits")

        if not taps or any(tap < 0 or tap >= ORDER for tap in taps):
            raise ValueError("Cada tap debe ser un índice válido del estado")

        if len(set(taps)) != len(taps):
            raise ValueError("Los taps no pueden estar repetidos")

        self.seed = seed
        self.taps = taps.copy()
        self.reset()

    def reset(self) -> None:
        """Reinicia el generador en la seed configurada."""

        self.state = self.seed

    def generate(self, bit_count: int) -> list[int]:
        """Genera bits en orden temporal y conserva el estado alcanzado."""

        if bit_count < 0:
            raise ValueError("La cantidad de bits no puede ser negativa")

        output_bits = []

        for _ in range(bit_count):
            output = (self.state >> 30) & 1
            feedback = 0

            for tap in self.taps:
                feedback ^= (self.state >> tap) & 1

            self.state = ((self.state << 1) & STATE_MASK) | feedback
            output_bits.append(output)

        return output_bits


def transition_matrix(field: GF2m, order: int, taps: list) -> list[list]:
    zero = field.element(0)
    one = field.element(1)

    A = [[zero for _ in range(order)] for _ in range(order)]

    for tap in taps:
        A[0][tap] = one

    for bit_index in range(1, order):
        A[bit_index][bit_index - 1] = one

    return A


def parallel_matrices(A: list[list], parallelism: int) -> tuple[list[list], list[list]]:
    """Construye la matriz de salida B y la transición paralela A^P."""

    order = len(A)
    field = A[0][0].field
    zero = field.element(0)
    one = field.element(1)

    # B[i] permite obtener el bit de salida luego de i avances:
    #     output[i] = B[i] * state
    output_row = [zero for _ in range(order)]
    output_row[order - 1] = one
    B = []

    for _ in range(parallelism):
        B.append(output_row)
        output_row = vector_matrix_product(output_row, A)

    # Calcula A^P mediante exponenciación binaria.
    A_parallel = [
        [one if row == column else zero for column in range(order)]
        for row in range(order)
    ]
    matrix_power = A
    exponent = parallelism

    while exponent != 0:
        if exponent & 1:
            A_parallel = matrix_matrix_product(A_parallel, matrix_power)

        matrix_power = matrix_matrix_product(matrix_power, matrix_power)
        exponent >>= 1

    return B, A_parallel


def binary_matrix_to_systemverilog(matrix: list[list], name: str) -> str:
    """Genera un localparam SystemVerilog para una matriz binaria."""

    if not matrix or not matrix[0]:
        raise ValueError("La matriz no puede estar vacía")

    rows = len(matrix)
    columns = len(matrix[0])

    if any(len(row) != columns for row in matrix):
        raise ValueError("Todas las filas deben tener la misma longitud")

    hex_digits = (columns + 3) // 4
    lines = [
        f"    localparam logic [{columns - 1}:0] {name} "
        f"[{rows - 1}:0] = '{{"
    ]

    # En un arreglo declarado [N-1:0], el primer elemento corresponde a [N-1].
    for row_index in range(rows - 1, -1, -1):
        packed_row = 0

        for column_index, coefficient in enumerate(matrix[row_index]):
            packed_row |= int(coefficient) << column_index

        comma = "," if row_index != 0 else ""
        lines.append(
            f"        {columns}'h{packed_row:0{hex_digits}X}{comma}"
        )

    lines.append("    };")

    return "\n".join(lines) + "\n"


def write_parallel_matrices_systemverilog(
    A_parallel: list[list], B: list[list], filename: Path
) -> None:
    """Guarda las matrices paralelas A y B como localparams de SystemVerilog."""

    filename.parent.mkdir(parents=True, exist_ok=True)
    contents = binary_matrix_to_systemverilog(A_parallel, "A")
    contents += "\n"
    contents += binary_matrix_to_systemverilog(B, "B")
    filename.write_text(contents, encoding="utf-8")


def main() -> None:

    # PRBS31: p(x) = x^31 + x^28 + 1
    order = ORDER
    taps = TAPS
    parallelism = PARALLELISM
    sequence_length = 2**12

    gf2 = GF2m(m=1, primitive_poly=0b1)
    zero = gf2.element(0)
    one = gf2.element(1)
    A = transition_matrix(gf2, order, taps)
    B, A_parallel = parallel_matrices(A, parallelism)

    # Semilla no nula: los 31 registros inicializados en uno.
    seed = [one for _ in range(order)]

    # Modelo serie de referencia.
    serial_state = seed.copy()
    serial_sequence = []

    for _ in range(sequence_length):
        serial_sequence.append(int(serial_state[order - 1]))
        serial_state = matrix_vector_product(A, serial_state)

    # Se generan bloques de 791 bits hasta superar la longitud a comparar.
    parallel_state = seed.copy()
    parallel_sequence = []

    while len(parallel_sequence) < sequence_length:
        output_block = matrix_vector_product(B, parallel_state)
        parallel_sequence.extend(int(bit) for bit in output_block)
        parallel_state = matrix_vector_product(A_parallel, parallel_state)

    parallel_sequence = parallel_sequence[:sequence_length]

    assert parallel_sequence == serial_sequence

    # El generador reutilizable debe respetar la misma convención de estado.
    integer_generator = PRBS31Generator(seed=STATE_MASK, taps=taps)
    integer_sequence = integer_generator.generate(sequence_length)
    assert integer_sequence == serial_sequence

    output_file = (
        Path(__file__).resolve().parents[3]
        / "rtl/tx/prbs31_matrices.txt"
    )
    write_parallel_matrices_systemverilog(A_parallel, B, output_file)

    print("PRBS31")
    print(f"Matriz de transición serial   : {len(A)}x{len(A[0])}")
    print(f"Matriz de salida paralela     : {len(B)}x{len(B[0])}")
    print(f"Matriz de transición paralela: "f"{len(A_parallel)}x{len(A_parallel[0])}")
    print("Archivo                       :", output_file)
    print(f"Bits comparados               : {sequence_length}")
    print("Serie y paralelo reducido     : OK")
    print("Serie y matriz extendida      : OK")
    print("Generador serie: OK")

if __name__ == "__main__":
    main()

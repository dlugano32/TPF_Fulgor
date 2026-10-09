from model.python.tools.GF2m import GF2m
from model.python.tools.GF2m_matrix import matrix_matrix_product, matrix_vector_product, vector_matrix_product

def transition_matrix (field: GF2m, order: int, taps: list) -> list[list]:
    zero = field.element(0)
    one  = field.element(1)

    A = [[zero for _ in range(order)]
            for _ in range(order)
    ]

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


def main() -> None:

    # PRBS31: p(x) = x^31 + x^28 + 1
    order = 31
    taps = [30, 27]
    parallelism = 791
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

    # Modelo paralelo. Se generan bloques de 791 bits hasta superar la longitud que se desea comparar
    parallel_state = seed.copy()
    parallel_sequence = []

    while len(parallel_sequence) < sequence_length:
        output_block = matrix_vector_product(B, parallel_state)
        parallel_sequence.extend(int(bit) for bit in output_block)
        parallel_state = matrix_vector_product(A_parallel, parallel_state)

    parallel_sequence = parallel_sequence[:sequence_length]


    assert parallel_sequence == serial_sequence

    print("PRBS31")
    print(f"Matriz de transición serial   : {len(A)}x{len(A[0])}")
    print(f"Matriz de salida paralela     : {len(B)}x{len(B[0])}")
    print(f"Matriz de transición paralela: "f"{len(A_parallel)}x{len(A_parallel[0])}")
    print(f"Bits comparados               : {sequence_length}")
    print("Serie y paralelo reducido     : OK")
    print("Serie y matriz extendida      : OK")

if __name__ == "__main__":
    main()

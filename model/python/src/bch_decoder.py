from pathlib import Path

from model.python.tools.GF2m import GF2m
from model.python.tools.GF2m_matrix import transpose_matrix


N = 127


def build_syndrome_matrix(field: GF2m) -> list[list[int]]:
    matrix = []

    alpha = field.element(2)

    for j in range(N):
        s1 = alpha ** j
        s3 = alpha ** (3 * j)
        row = [(int(s1) >> bit_index) & 1 for bit_index in range(field.m)]
        row.extend((int(s3) >> bit_index) & 1 for bit_index in range(field.m))
        matrix.append(row)

    return matrix


def syndrome_masks_from_matrix(matrix: list[list[int]]) -> tuple[int, ...]:
    """Convierte las columnas de M en 14 mascaras enteras de 127 bits."""

    transposed_matrix = transpose_matrix(matrix)
    masks = []

    for row in transposed_matrix:
        mask = 0

        for received_bit, coefficient in enumerate(row):
            mask |= int(coefficient) << received_bit

        masks.append(mask)

    return tuple(masks)


def syndrome_matrix_to_systemverilog(
    matrix: list[list[int]],
    name: str = "M_T",
) -> str:
    """Genera la declaracion SystemVerilog de la matriz M transpuesta."""

    received_bits = len(matrix)
    syndrome_bits = len(matrix[0])
    syndrome_masks = syndrome_masks_from_matrix(matrix)
    hex_digits = (received_bits + 3) // 4
    lines = [
        f"    localparam logic [{received_bits - 1}:0] {name} "
        f"[{syndrome_bits - 1}:0] = '{{"
    ]

    # En un arreglo declarado [13:0], el primer elemento corresponde a M_T[13].
    for syndrome_bit in range(syndrome_bits - 1, -1, -1):
        comma = "," if syndrome_bit != 0 else ""
        lines.append(
            f"        {received_bits}'h"
            f"{syndrome_masks[syndrome_bit]:0{hex_digits}X}{comma}"
        )

    lines.append("    };")

    return "\n".join(lines) + "\n"


def write_syndrome_matrix_systemverilog(
    matrix: list[list[int]],
    filename: Path,
) -> None:
    """Guarda M transpuesta como un localparam de SystemVerilog."""

    filename.parent.mkdir(parents=True, exist_ok=True)
    filename.write_text(
        syndrome_matrix_to_systemverilog(matrix),
        encoding="utf-8",
    )


def calculate_syndromes(received: int, field: GF2m, syndrome_masks: tuple[int, ...]) -> tuple:
    """Calcula S1 y S3 mediante el producto binario r M."""

    if received < 0 or received >= 1 << N:
        raise ValueError(f"La palabra recibida debe tener hasta {N} bits")

    syndrome_vector = 0

    for syndrome_bit, mask in enumerate(syndrome_masks):
        syndrome_vector |= ((received & mask).bit_count() & 1) << syndrome_bit

    syndrome_1 = field.element(syndrome_vector & ((1 << field.m) - 1))
    syndrome_3 = field.element(syndrome_vector >> field.m)

    return syndrome_1, syndrome_3


def decode(received: int, field: GF2m, syndrome_masks: tuple[int, ...]) -> tuple[int, list[int]]:
    """
    Corrige hasta dos errores mediante el algoritmo search-less.

    Devuelve la palabra corregida y las posiciones de los errores. Si los
    sindromes no corresponden a un patron corregible, genera ValueError.
    """

    zero = field.element(0)
    one = field.element(1)
    syndrome_1, syndrome_3 = calculate_syndromes(received, field, syndrome_masks)

    # Sin errores.
    if syndrome_1 == zero:
        if syndrome_3 != zero:
            raise ValueError("Los sindromes no corresponden a cero, uno o dos errores")

        return received, []

    # Un error: sigma(X) = 1 + S1 X.
    if syndrome_1 ** 3 == syndrome_3:
        root = one / syndrome_1
        error_positions = [(-field.log(int(root))) % N]

    # Dos errores: solucion cerrada de sigma(X) mediante las ecuaciones
    # (9)-(12) del algoritmo search-less.
    else:
        numerator = syndrome_1 ** 3 + syndrome_3
        mu = numerator / (syndrome_1 ** 3)

        # Para m impar puede elegirse theta = 1, ya que Tr(1) = 1.
        theta = one

        if theta.trace() != 1:
            raise ValueError("El algoritmo requiere un elemento theta de traza uno")

        # Ecuacion (11): obtiene una solucion de omega^2 + omega = mu.
        omega_1 = zero
        partial_sum = zero
        mu_power = mu
        theta_power = theta.square()

        for _ in range(1, field.m):
            partial_sum = partial_sum + mu_power    # mu + mu^2 + ... + mu^(2^(m-1))
            omega_1 = omega_1 + partial_sum * theta_power   # w1 = mu th^2 + (mu + mu ^2) th^2^2 ....
            mu_power = mu_power.square()
            theta_power = theta_power.square()

        if omega_1.square() + omega_1 != mu:
            raise ValueError("La ecuacion cuadratica no tiene solucion en el campo")

        omega_2 = omega_1 + one
        root_1 = omega_1 / (mu * syndrome_1)
        root_2 = omega_2 / (mu * syndrome_1)

        error_positions = sorted(
            [
                (-field.log(int(root_1))) % N,
                (-field.log(int(root_2))) % N,
            ]
        )

    corrected = received

    for position in error_positions:
        corrected ^= 1 << position

    corrected_syndrome_1, corrected_syndrome_3 = calculate_syndromes(
        corrected,
        field,
        syndrome_masks,
    )

    if corrected_syndrome_1 != zero or corrected_syndrome_3 != zero:
        raise ValueError("No fue posible corregir la palabra recibida")

    return corrected, error_positions


def main() -> None:
    # GF(2^7), con p(x) = x^7 + x^3 + 1.
    field = GF2m(m=7, primitive_poly=0b0001001)
    syndrome_matrix = build_syndrome_matrix(field)
    syndrome_masks = syndrome_masks_from_matrix(syndrome_matrix)

    # Ejemplo: una palabra valida con errores en las posiciones 6 y 91.
    codeword = 0x048D159E26AF37BC048D159E26AF1CD6
    received = codeword ^ (1 << 6) ^ (1 << 91)
    corrected, error_positions = decode(received, field, syndrome_masks)

    output_file = (
        Path(__file__).resolve().parents[3]
        / "rtl/rx/bch_syndrome_matrix.txt"
    )
    write_syndrome_matrix_systemverilog(syndrome_matrix, output_file)

    print("BCH(127,113)")
    print(f"Matriz M  : {len(syndrome_matrix)}x{len(syndrome_matrix[0])}")
    print(f"Matriz RTL: {len(syndrome_matrix[0])}x{len(syndrome_matrix)}")
    print("Archivo   :", output_file)
    print(f"Recibida  : 0x{received:032X}")
    print(f"Corregida : 0x{corrected:032X}")
    print("Errores   :", error_positions)


if __name__ == "__main__":
    main()

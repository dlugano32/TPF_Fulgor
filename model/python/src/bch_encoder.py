from pathlib import Path

from model.python.tools.GF2m import GF2m
from model.python.tools.GF2m_matrix import transpose_matrix, vector_matrix_product
from model.python.tools.GFPoly import GFPoly
from model.python.src.bch_design import cosets_for_t, generator_polynomial


N = 127
K = 113
PARITY_BITS = N - K


def int_to_vector(value: int, width: int, field: GF2m) -> list:
    """Convierte un entero al vector [bit_0, bit_1, ..., bit_n]."""

    if value < 0 or value >= 1 << width:
        raise ValueError(f"El valor debe tener hasta {width} bits")

    return [field.element((value >> bit_index) & 1) for bit_index in range(width)]


def encode_systematic(message: int, generator: GFPoly, message_bits: int = K) -> GFPoly:
    """Calcula c(x) = x^r m(x) + r(x) mediante division polinomica."""

    if message < 0 or message >= 1 << message_bits:
        raise ValueError(f"El mensaje debe tener hasta {message_bits} bits")

    field = generator.field
    zero = field.element(0)
    parity_bits = len(generator.coefficients) - 1
    message_coefficients = int_to_vector(message, message_bits, field)

    shifted_message = GFPoly(field, [zero] * parity_bits + message_coefficients)

    _, parity = shifted_message.divide(generator)
    codeword = shifted_message + parity

    return codeword


def build_parity_matrix(generator: GFPoly, field: GF2m, message_bits: int = K) -> list[list]:
    """
        Construye la matriz de paridad P de 113 filas por 14 columnas, para r = m P.

        La fila j contiene la paridad generada por el mensaje base m(x) = x^j.
    """

    parity_bits = len(generator.coefficients) - 1
    matrix = []

    # La fila j se obtiene codificando el mensaje base m(x) = x^j.
    for message_bit in range(message_bits):
        codeword = encode_systematic(1 << message_bit, generator, message_bits)
        row = []

        for parity_bit in range(parity_bits):
            coefficient = codeword.coefficients[parity_bit]
            row.append(field.element(int(coefficient)))

        matrix.append(row)

    return matrix


def encode_with_matrix(message: int, generator: GFPoly, matrix: list[list]) -> GFPoly:
    """Codifica sistematicamente mediante la matriz de Paridad."""

    message_bits = len(matrix)
    parity_bits = len(matrix[0])

    if message < 0 or message >= 1 << message_bits:
        raise ValueError(f"El mensaje debe tener hasta {message_bits} bits")

    if parity_bits != len(generator.coefficients) - 1:
        raise ValueError("La cantidad de columnas no coincide con el grado de g(x)")

    matrix_field = matrix[0][0].field
    message_vector = int_to_vector(message, message_bits, matrix_field)
    parity_vector = vector_matrix_product(message_vector, matrix)

    polynomial_field = generator.field
    parity_coefficients = [
        polynomial_field.element(int(element))
        for element in parity_vector
    ]
    message_coefficients = int_to_vector(message, message_bits, polynomial_field)

    return GFPoly(polynomial_field, parity_coefficients + message_coefficients)


def parity_matrix_to_systemverilog(matrix: list[list], name: str = "P_T") -> str:
    """Genera la declaracion SystemVerilog de la matriz transpuesta."""

    message_bits = len(matrix)
    parity_bits = len(matrix[0])
    transposed_matrix = transpose_matrix(matrix)
    hex_digits = (message_bits + 3) // 4
    lines = [
        f"    localparam logic [{message_bits - 1}:0] {name} "
        f"[{parity_bits - 1}:0] = '{{"
    ]

    # En un arreglo declarado [13:0], el primer elemento es P_T[13].
    for parity_bit in range(parity_bits - 1, -1, -1):
        transposed_row = 0

        for message_bit in range(message_bits):
            coefficient = transposed_matrix[parity_bit][message_bit]
            transposed_row |= int(coefficient) << message_bit

        comma = "," if parity_bit != 0 else ""
        lines.append(
            f"        {message_bits}'h{transposed_row:0{hex_digits}X}{comma}"
        )

    lines.append("    };")

    return "\n".join(lines) + "\n"


def write_parity_matrix_systemverilog(matrix: list[list], filename: Path) -> None:
    """Guarda P transpuesta como un localparam de SystemVerilog."""

    filename.parent.mkdir(parents=True, exist_ok=True)
    filename.write_text(
        parity_matrix_to_systemverilog(matrix),
        encoding="utf-8",
    )


def main() -> None:
    # GF(2^7), con p(x) = x^7 + x^3 + 1.
    field = GF2m(m=7, primitive_poly=0b0001001)
    cosets = cosets_for_t(t=2, m=field.m)
    generator = generator_polynomial(field, cosets)

    # La matriz de paridad es binaria, por lo que se construye sobre GF(2).
    gf2 = GF2m(m=1, primitive_poly=0b1)
    parity_matrix = build_parity_matrix(generator, gf2)

    # Mensaje de ejemplo de 113 bits.
    message = 0x123456789ABCDEF0123456789ABC

    codeword_polynomial = encode_systematic(message, generator)
    codeword_matrix = encode_with_matrix(message, generator, parity_matrix)
    _, remainder = codeword_matrix.divide(generator)

    assert codeword_matrix == codeword_polynomial
    assert remainder == GFPoly(field, [field.element(0)])

    codeword_value = codeword_matrix.to_int()
    parity_mask = (1 << PARITY_BITS) - 1

    output_file = ( Path(__file__).resolve().parents[3]/ "rtl/tx/bch_parity_matrix.txt")
    write_parity_matrix_systemverilog(parity_matrix, output_file)

    print("BCH(127,113)")
    print("g(x) =", generator.to_string())
    print(f"Mensaje : 0x{message:029X}")
    print(f"Paridad : 0x{codeword_value & parity_mask:04X}")
    print(f"Codigo  : 0x{codeword_value:032X}")
    print(f"Matriz P     : {len(parity_matrix)}x{len(parity_matrix[0])}")
    print(f"Matriz RTL PT: {len(parity_matrix[0])}x{len(parity_matrix)}")
    print("Archivo :", output_file)
    print("Division polinomica y matriz combinacional: OK")


if __name__ == "__main__":
    main()

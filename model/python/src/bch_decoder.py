from model.python.tools.GF2m import GF2m
from model.python.tools.GFPoly import GFPoly


N = 127


def calculate_syndromes(received: int, field: GF2m) -> tuple:
    """Calcula S1 = r(alpha) y S3 = r(alpha^3)."""

    if received < 0 or received >= 1 << N:
        raise ValueError(f"La palabra recibida debe tener hasta {N} bits")

    coefficients = [
        field.element((received >> bit_index) & 1)
        for bit_index in range(N)
    ]
    received_polynomial = GFPoly(field, coefficients)
    alpha = field.element(field.exp(1))

    syndrome_1 = received_polynomial.evaluate(alpha)
    syndrome_3 = received_polynomial.evaluate(alpha ** 3)

    return syndrome_1, syndrome_3


def decode(received: int, field: GF2m) -> tuple[int, list[int]]:
    """
    Corrige hasta dos errores mediante el algoritmo search-less.

    Devuelve la palabra corregida y las posiciones de los errores. Si los
    sindromes no corresponden a un patron corregible, genera ValueError.
    """

    zero = field.element(0)
    one = field.element(1)
    syndrome_1, syndrome_3 = calculate_syndromes(received, field)

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

    corrected_syndrome_1, corrected_syndrome_3 = calculate_syndromes(corrected, field)

    if corrected_syndrome_1 != zero or corrected_syndrome_3 != zero:
        raise ValueError("No fue posible corregir la palabra recibida")

    return corrected, error_positions


def main() -> None:
    # GF(2^7), con p(x) = x^7 + x^3 + 1.
    field = GF2m(m=7, primitive_poly=0b0001001)

    # Ejemplo: una palabra valida con errores en las posiciones 6 y 91.
    codeword = 0x048D159E26AF37BC048D159E26AF1CD6
    received = codeword ^ (1 << 6) ^ (1 << 91)
    corrected, error_positions = decode(received, field)

    print("BCH(127,113)")
    print(f"Recibida  : 0x{received:032X}")
    print(f"Corregida : 0x{corrected:032X}")
    print("Errores   :", error_positions)


if __name__ == "__main__":
    main()

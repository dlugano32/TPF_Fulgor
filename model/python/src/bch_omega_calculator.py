from model.python.tools.GF2m import GF2m


def calculate_omega(field: GF2m, mu: int) -> int:
    """Calcula omega = mu^2 + mu^8 + mu^32 en GF(2^7)."""

    return field.power(mu, 2) ^ field.power(mu, 8) ^ field.power(mu, 32)


def main() -> None:
    # GF(2^7), p(x) = x^7 + x^3 + 1.
    field = GF2m(m=7, primitive_poly=0b0001001)

    # Cada columna es la respuesta de omega para un vector base de mu (alpha, alpha^2, ..., alpha^6)
    columns = [calculate_omega(field, 1 << bit) for bit in range(field.m)]

    for output_bit in range(field.m):
        terms = [
            f"mu[{input_bit}]"
            for input_bit, column in enumerate(columns)
            if (column >> output_bit) & 1
        ]
        print(f"assign omega[{output_bit}] = {' ^ '.join(terms)};")


if __name__ == "__main__":
    main()

from model.python.tools.GF2m import GF2m
from model.python.tools.GFPoly import GFPoly


def cyclotomic_coset(i: int, m: int) -> list[int]:
    """
    Construye el coset ciclotomico binario:

        C_i = {i, 2*i, 4*i, ...} mod 2^m-1
    """

    n = 2**m - 1
    coset = []
    current = i % n

    while current not in coset:
        coset.append(current)
        current = (2 * current) % n

    return coset


def all_cyclotomic_cosets(m: int) -> list[list[int]]:
    """Devuelve todos los cosets ciclotomicos distintos modulo 2^m-1."""

    n = 2**m - 1
    cosets = []
    used_exponents = set()

    for exponent in range(n):
        if exponent not in used_exponents:
            coset = cyclotomic_coset(exponent, m)
            cosets.append(coset)
            used_exponents.update(coset)

    return cosets


def minimal_polynomial(field: GF2m, coset: list[int]) -> GFPoly:
    """Calcula el polinomio minimo asociado con un coset ciclotomico."""

    alpha = field.element(2)
    roots = [alpha**exponent for exponent in coset]

    return GFPoly.from_roots(field, roots)


def cosets_for_t(t: int, m: int) -> list[list[int]]:
    """Selecciona los cosets del BCH narrow-sense con raices 1 a 2*t."""

    if t <= 0:
        raise ValueError("t debe ser mayor que cero")

    selected_cosets = []
    selected_leaders = set()

    for exponent in range(1, 2 * t + 1):
        coset = cyclotomic_coset(exponent, m)
        leader = min(coset)

        if leader not in selected_leaders:
            selected_cosets.append(cyclotomic_coset(leader, m))
            selected_leaders.add(leader)

    return selected_cosets


def generator_polynomial(field: GF2m, cosets: list[list[int]]) -> GFPoly:
    """Multiplica los polinomios minimos de los cosets seleccionados."""

    generator = GFPoly(field, [field.element(1)])

    for coset in cosets:
        generator = generator * minimal_polynomial(field, coset)

    return generator


def bch_codes(field: GF2m, maximum_t: int) -> list[tuple[int, int, int, list[int]]]:
    """Construye la tabla de codigos BCH narrow-sense desde t=1."""

    n = field.order - 1
    rows = []

    for t in range(1, maximum_t + 1):
        cosets = cosets_for_t(t, field.m)
        generator = generator_polynomial(field, cosets)
        generator_degree = len(generator.coefficients) - 1
        leaders = [min(coset) for coset in cosets]

        rows.append((n, n - generator_degree, t, leaders))

    return rows


def print_table(headers: tuple[str, ...], rows: list[tuple]) -> None:
    """Imprime una tabla de texto sin dependencias externas."""

    text_rows = []

    for row in rows:
        text_rows.append(tuple(str(value) for value in row))

    widths = []

    for column in range(len(headers)):
        width = len(headers[column])

        for row in text_rows:
            width = max(width, len(row[column]))

        widths.append(width)

    print(" | ".join(headers[i].ljust(widths[i]) for i in range(len(headers))))
    print("-+-".join("-" * width for width in widths))

    for row in text_rows:
        print(" | ".join(row[i].ljust(widths[i]) for i in range(len(headers))))


def print_cosets_table(field: GF2m) -> None:
    """Imprime todos los cosets y sus polinomios minimos."""

    rows = []

    for coset in all_cyclotomic_cosets(field.m):
        polynomial = minimal_polynomial(field, coset)
        coset_name = f"C{min(coset)} = {coset}"
        rows.append((coset_name, polynomial.to_string()))

    print_table(("Clase ciclotomica", "Polinomio minimo"), rows)


def print_bch_codes_table(field: GF2m, maximum_t: int) -> None:
    """Imprime los parametros BCH y los cosets usados para cada t."""

    rows = []

    for n, k, t, leaders in bch_codes(field, maximum_t):
        cosets = ", ".join(f"C{leader}" for leader in leaders)
        rows.append((n, k, t, cosets))

    print_table(("n", "k", "t", "Cosets utilizados"), rows)


def main() -> None:
    # GF(2^7) -> Primitive Poly = X^7 + X^3 + 1
    # El termino x^7 queda implicito. 0b0001001 representa x^3 + 1.
    gf127 = GF2m(m=7, primitive_poly=0b0001001)

    print("ELEMENTOS DE GF(2^7)")
    gf127.print_elements_table()

    print("\nCOSETS CICLOTOMICOS Y POLINOMIOS MINIMOS")
    print_cosets_table(gf127)

    print("\nCODIGOS BCH PRIMITIVOS NARROW-SENSE")
    print_bch_codes_table(gf127, maximum_t=10)

    ############################################################
    # Para el caso que nos interesa BCH(127,113) para t=2
    ############################################################

    c1 = cyclotomic_coset(i=1, m=7)
    c3 = cyclotomic_coset(i=3, m=7)

    m1 = minimal_polynomial(gf127, c1)
    m3 = minimal_polynomial(gf127, c3)

    g = m1 * m3

    print("")
    print("BCH(127,113) CONSTRUCTION")
    print("C1 =", c1)
    print("C3 =", c3)

    print("m1(x) =", m1.to_string())
    print("m3(x) =", m3.to_string())
    print("g(x)  =", g.to_string())

if __name__ == "__main__":
    main()

"""Pruebas exhaustivas de la aritmética de GF(2^7)."""

import sys
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPOSITORY_ROOT))

from model.python.tools.GF2m import GF2m


M = 7
ORDER = 1 << M
MULTIPLICATIVE_ORDER = ORDER - 1
PRIMITIVE_POLY_LOW = 0b0001001
PRIMITIVE_POLY_FULL = (1 << M) | PRIMITIVE_POLY_LOW


def reference_multiply(a: int, b: int) -> int:
    """Multiplicación polinómica independiente con reducción módulo p(x)."""

    product = 0

    for bit in range(M):
        if b & (1 << bit):
            product ^= a << bit

    while product.bit_length() > M:
        shift = product.bit_length() - 1 - M
        product ^= PRIMITIVE_POLY_FULL << shift

    return product


def reference_power(a: int, exponent: int) -> int:
    """Potencia calculada con la multiplicación de referencia."""

    result = 1

    for _ in range(exponent):
        result = reference_multiply(result, a)

    return result


def reference_trace(a: int) -> int:
    """Traza calculada mediante cuadrados de la implementación de referencia."""

    result = 0
    term = a

    for _ in range(M):
        result ^= term
        term = reference_multiply(term, term)

    return result


def expect_exception(exception_type, function, *args) -> None:
    """Verifica que una llamada produzca la excepción esperada."""

    try:
        function(*args)
    except exception_type:
        return

    raise AssertionError(f"Se esperaba la excepción {exception_type.__name__}")


def test_tables(field: GF2m) -> None:
    """Verifica las tablas exponencial y logarítmica."""

    # Las tablas deben contener una única vez cada elemento no nulo del campo.
    assert len(field.exp_table) == MULTIPLICATIVE_ORDER
    assert len(field.log_table) == ORDER
    assert field.log_table[0] == -1
    assert set(field.exp_table) == set(range(1, ORDER))

    # exp y log deben ser operaciones inversas para los elementos no nulos.
    for exponent in range(MULTIPLICATIVE_ORDER):
        value = field.exp(exponent)

        assert field.log(value) == exponent
        assert field.exp(field.log(value)) == value

    assert field.exp(MULTIPLICATIVE_ORDER) == 1
    assert field.exp(-1) == field.exp(MULTIPLICATIVE_ORDER - 1)


def test_addition(field: GF2m) -> None:
    """Verifica exhaustivamente la suma del campo."""

    # En característica dos, sumar es hacer XOR y cada elemento es su opuesto.
    for a in range(ORDER):
        assert field.add(a, 0) == a
        assert field.add(a, a) == 0

        for b in range(ORDER):
            assert field.add(a, b) == (a ^ b)
            assert field.add(a, b) == field.add(b, a)


def test_multiplication(field: GF2m) -> None:
    """Compara exhaustivamente la multiplicación con una referencia independiente."""

    # Se prueban todos los pares contra un producto polinómico de referencia.
    for a in range(ORDER):
        assert field.multiply(a, 0) == 0
        assert field.multiply(a, 1) == a

        for b in range(ORDER):
            expected = reference_multiply(a, b)

            assert field.multiply(a, b) == expected
            assert field.multiply(a, b) == field.multiply(b, a)


def test_power_square_inverse_and_division(field: GF2m) -> None:
    """Verifica potencia, cuadrado, inverso y división."""

    # Las potencias y los cuadrados se comparan con la referencia polinómica.
    for a in range(ORDER):
        assert field.square(a) == reference_multiply(a, a)

        for exponent in range(MULTIPLICATIVE_ORDER + 1):
            assert field.power(a, exponent) == reference_power(a, exponent)

    # Todo elemento no nulo debe poseer un único inverso multiplicativo.
    for a in range(1, ORDER):
        inverse = field.inverse(a)

        assert field.multiply(a, inverse) == 1
        assert inverse == field.exp(-field.log(a))

    # Dividir y volver a multiplicar por el divisor debe recuperar el dividendo.
    for a in range(ORDER):
        for b in range(1, ORDER):
            quotient = field.divide(a, b)

            assert field.multiply(quotient, b) == a


def test_trace(field: GF2m) -> None:
    """Verifica exhaustivamente la definición y propiedades de la traza."""

    # La traza debe coincidir con su definición, ser binaria y lineal.
    for a in range(ORDER):
        trace_a = field.trace(a)

        assert trace_a in (0, 1)
        assert trace_a == reference_trace(a)
        assert field.trace(field.square(a)) == trace_a

        for b in range(ORDER):
            assert field.trace(field.add(a, b)) == (trace_a ^ field.trace(b))


def test_element_interface(field: GF2m) -> None:
    """Verifica que GFElement coincida con la interfaz entera de GF2m."""

    # Los operadores de GFElement deben delegar sin cambiar los resultados.
    for a in range(ORDER):
        element_a = field.element(a)

        assert int(element_a) == a
        assert int(element_a.square()) == field.square(a)
        assert element_a.trace() == field.trace(a)

        if a != 0:
            assert int(element_a.inverse()) == field.inverse(a)

        for b in range(ORDER):
            element_b = field.element(b)

            assert int(element_a + element_b) == field.add(a, b)
            assert int(element_a - element_b) == field.add(a, b)
            assert int(element_a * element_b) == field.multiply(a, b)

            if b != 0:
                assert int(element_a / element_b) == field.divide(a, b)

    # También se verifica el operador de potencia de GFElement.
    for a in range(ORDER):
        element_a = field.element(a)

        for exponent in range(MULTIPLICATIVE_ORDER + 1):
            assert int(element_a**exponent) == field.power(a, exponent)


def test_representations(field: GF2m) -> None:
    """Verifica las representaciones binaria y polinómica."""

    # Se comprueban casos conocidos de la convención bit i <-> coeficiente x^i.
    assert field.to_polynomial_string(0) == "0"
    assert field.to_polynomial_string(1) == "1"
    assert field.to_polynomial_string(0b0000010) == "x"
    assert field.to_polynomial_string(0b1001001) == "x^6 + x^3 + 1"

    # La tabla debe representar los 128 elementos de manera consistente.
    rows = field.elements_table()

    assert len(rows) == ORDER
    assert rows[0] == ("-", "0", "0000000")

    for exponent, value in enumerate(field.exp_table):
        power, polynomial, vector = rows[exponent + 1]

        assert power == f"alpha^{exponent}"
        assert polynomial == field.to_polynomial_string(value)
        assert vector == f"{value:07b}"


def test_invalid_operations(field: GF2m) -> None:
    """Verifica los casos inválidos definidos por la interfaz."""

    # Se validan divisiones por cero, argumentos fuera de rango y tipos inválidos.
    expect_exception(ZeroDivisionError, field.inverse, 0)
    expect_exception(ZeroDivisionError, field.divide, 1, 0)
    expect_exception(ValueError, field.log, 0)
    expect_exception(ValueError, field.power, 1, -1)
    expect_exception(ValueError, field.element, -1)
    expect_exception(ValueError, field.element, ORDER)
    expect_exception(TypeError, field.element, 1.0)


def run_test(name: str, test, field: GF2m) -> None:
    """Ejecuta una prueba y muestra su resultado."""

    test(field)
    print(f"[PASS] {name}")


def main() -> None:
    field = GF2m(m=M, primitive_poly=PRIMITIVE_POLY_LOW)

    tests = (
        ("tablas exp/log", test_tables),
        ("suma", test_addition),
        ("multiplicación", test_multiplication),
        ("potencia, cuadrado, inverso y división", test_power_square_inverse_and_division),
        ("traza", test_trace),
        ("interfaz GFElement", test_element_interface),
        ("representaciones", test_representations),
        ("operaciones inválidas", test_invalid_operations),
    )

    for name, test in tests:
        run_test(name, test, field)

    print("\nTodas las pruebas de GF(2^7) finalizaron correctamente.")


if __name__ == "__main__":
    main()

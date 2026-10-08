from model.python.tools.GF2m import GF2m, GFElement


class GFPoly:
    """
    Representa un polinomio con coeficientes en GF(2^m).

    Los coeficientes se almacenan en orden creciente de grado:

        [a_0, a_1, ..., a_n]

    representa:

        a_0 + a_1*x + ... + a_n*x^n

    Por lo tanto, coefficients[i] es el coeficiente de x^i.
    """

    def __init__(self, field: GF2m, coefficients: list[GFElement] | tuple[GFElement, ...]):
        if not isinstance(field, GF2m):
            raise TypeError("El campo debe ser una instancia de GF2m")

        if not isinstance(coefficients, (list, tuple)):
            raise TypeError("Los coeficientes deben estar en una lista o tupla")

        if len(coefficients) == 0:
            raise ValueError("La lista de coeficientes no puede estar vacía")

        self.field = field

        for coefficient in coefficients:
            if not isinstance(coefficient, GFElement):
                raise TypeError("Cada coeficiente debe ser un GFElement")

            if coefficient.field is not self.field:
                raise ValueError("Todos los coeficientes deben pertenecer al campo")

        self.coefficients = list(coefficients)

        # Elimina ceros en los términos de mayor grado.
        zero = self.field.element(0)

        while len(self.coefficients) > 1 and self.coefficients[-1] == zero:
            self.coefficients.pop()

    def __add__(self, other: "GFPoly") -> "GFPoly":
        """Suma dos polinomios pertenecientes al mismo campo."""

        if not isinstance(other, GFPoly):
            raise TypeError("Solo se pueden sumar polinomios GFPoly")

        if other.field is not self.field:
            raise ValueError("Los polinomios deben pertenecer al mismo campo")

        zero = self.field.element(0)

        # Longitud del polinomio de mayor grado.
        max_length = max( len(self.coefficients), len(other.coefficients) )

        # Agrega ceros en los términos de mayor grado para igualar longitudes.
        self_coefficients = self.coefficients + [zero] * (max_length - len(self.coefficients))

        other_coefficients = other.coefficients + [zero] * (max_length - len(other.coefficients))

        # Suma coeficiente a coeficiente dentro de GF(2^m).
        result_coefficients = []

        for coefficient_a, coefficient_b in zip( self_coefficients, other_coefficients):

            result_coefficients.append( coefficient_a + coefficient_b )

        return GFPoly( self.field, result_coefficients)

    def __sub__(self, other: "GFPoly") -> "GFPoly":
        """
        En GF(2^m), suma y resta son la misma operación.
        """
        return self.__add__(other)

    def __mul__(self, other: "GFPoly") -> "GFPoly":
        """Multiplica dos polinomios pertenecientes al mismo campo."""

        if not isinstance(other, GFPoly):
            raise TypeError("Solo se pueden multiplicar polinomios GFPoly")

        if other.field is not self.field:
            raise ValueError("Los polinomios deben pertenecer al mismo campo")

        zero = self.field.element(0)

        # El producto de polinomios de longitudes n y m
        # tiene n + m - 1 coeficientes.
        result_length = len(self.coefficients) + len(other.coefficients)- 1

        result_coefficients = [ zero for _ in range(result_length) ]

        # Cada coeficiente de un polinomio se multiplica
        # por todos los coeficientes del otro.
        for i, coefficient_a in enumerate(self.coefficients):

            for j, coefficient_b in enumerate(other.coefficients):

                product = coefficient_a * coefficient_b

                result_coefficients[i + j] = result_coefficients[i + j] + product

        return GFPoly(self.field, result_coefficients)

    def divide(self, divisor: "GFPoly") -> tuple["GFPoly", "GFPoly"]:
        """
        Divide dos polinomios pertenecientes al mismo campo.

        Implementa :
            dividendo = cociente * divisor + resto
            grado(resto) < grado(divisor)

        Devuelve:
            (cociente, resto)
        """

        if not isinstance(divisor, GFPoly):
            raise TypeError("El divisor debe ser un polinomio GFPoly")

        if divisor.field is not self.field:
            raise ValueError("Los polinomios deben pertenecer al mismo campo")

        zero = self.field.element(0)

        # El polinomio nulo se representa como [zero].
        if divisor.coefficients == [zero]:
            raise ZeroDivisionError("No se puede dividir por el polinomio nulo")

        dividend_degree = len(self.coefficients) - 1
        divisor_degree = len(divisor.coefficients) - 1

        # Si el dividendo tiene menor grado que el divisor:
        #   cociente = 0 y resto = dividendo.
        if dividend_degree < divisor_degree:
            quotient = GFPoly(self.field, [zero])
            remainder = GFPoly(self.field, self.coefficients.copy())

            return quotient, remainder

        quotient_degree = dividend_degree - divisor_degree

        quotient_coefficients = [
            zero for _ in range(quotient_degree + 1)
        ]

        # Inicialmente, el resto es igual al dividendo.
        remainder = GFPoly( self.field, self.coefficients.copy())

        # La división continúa mientras el resto no sea nulo y su grado sea mayor o igual al del divisor.
        while (
            remainder.coefficients != [zero]
            and len(remainder.coefficients)
            >= len(divisor.coefficients)
        ):
            remainder_degree = len(remainder.coefficients) - 1

            # Grado del próximo término del cociente.
            degree_difference = remainder_degree - divisor_degree

            # Coeficiente del próximo término del cociente.
            factor = remainder.coefficients[-1] / divisor.coefficients[-1]

            # Ubica el factor en la posición correspondiente dentro de la lista del cociente.
            quotient_coefficients[degree_difference] = factor

            # Multiplica el divisor por el factor.
            product = divisor.scale(factor)

            # Multiplica el producto por x^degree_difference.
            product = GFPoly(self.field, [zero] * degree_difference + product.coefficients)

            # Cancela el término principal del resto.
            remainder = remainder + product

        quotient = GFPoly(self.field, quotient_coefficients)

        return quotient, remainder

    def __eq__(self, other) -> bool:
        """Compara dos polinomios."""
        if not isinstance(other, GFPoly):
            return False

        return (
            self.field is other.field
            and self.coefficients == other.coefficients
        )

    def scale(self, scalar: GFElement) -> "GFPoly":
        """Multiplica todos los coeficientes por un escalar del campo."""

        if not isinstance(scalar, GFElement):
            raise TypeError("El escalar debe ser un elemento GFElement")

        if scalar.field is not self.field:
            raise ValueError("El escalar debe pertenecer al mismo campo")

        scaled_coefficients = [
            coefficient * scalar
            for coefficient in self.coefficients
        ]

        return GFPoly(self.field, scaled_coefficients)

    def evaluate(self, x: GFElement) -> GFElement:
        """Evalúa el polinomio en un elemento del campo."""

        if not isinstance(x, GFElement):
            raise TypeError("El punto de evaluación debe ser un GFElement")

        if x.field is not self.field:
            raise ValueError("El punto de evaluación debe pertenecer al mismo campo")

        # Algoritmo implementado
        # result = 0
        # Los coeficientes se recorren desde el término de mayor grado.
        # result = 0*x + a_n
        # result = a_n*x + a_(n-1)
        # ...

        result = self.field.element(0)

        for coefficient in reversed(self.coefficients):
            result = result * x + coefficient

        return result

    def to_int(self) -> int:
        """
            Devuelve la representación entera del polinomio binario.

            Convención:
                el bit i representa el coeficiente de x^i.

            Ejemplo:
                x^3 + x + 1
                coeficientes = [1, 1, 0, 1]
                máscara      = 0b1011

            Este método sólo es válido para polinomios GF(2)
        """

        value = 0

        for exponent, coefficient in enumerate(self.coefficients):
            coefficient_value = int(coefficient)

            value |= coefficient_value << exponent

        return value

    def to_string(self) -> str:
        """
        Devuelve la representación algebraica del polinomio binario.

        Ejemplos:
            [1, 1, 0, 1] -> X^3 + X + 1
            [0, 0, 1]    -> X^2
            [0]          -> 0

        Este método sólo es válido para polinomios GF(2)
        """

        terms = []
        degree = len(self.coefficients) - 1

        for exponent in range(degree, -1, -1):
            coefficient = self.coefficients[exponent]
            coefficient_value = int(coefficient)

            if coefficient_value not in (0, 1):
                raise ValueError(
                    "El polinomio no pertenece a GF(2): "
                    "todos sus coeficientes deben ser 0 o 1"
                )

            # Los términos con coeficiente cero no se imprimen.
            if coefficient_value == 0:
                continue

            if exponent == 0:
                terms.append("1")
            elif exponent == 1:
                terms.append("X")
            else:
                terms.append(f"X^{exponent}")

        # Si no se encontró ningún término no nulo,
        # se trata del polinomio cero.
        if not terms:
            return "0"

        return " + ".join(terms)
    
    @classmethod
    def from_roots(cls, field: GF2m, roots: list[GFElement] | tuple[GFElement, ...]) -> "GFPoly":
        """
            Construye el polinomio a partir de sus raices

                (x - r1)(x - r2)...(x - rk)
        """

        if not isinstance(field, GF2m):
            raise TypeError("El campo debe ser una instancia de GF2m")

        if not isinstance(roots, (list, tuple)):
            raise TypeError("Las raíces deben estar en una lista o tupla")

        for root in roots:
            if not isinstance(root, GFElement):
                raise TypeError("Cada raíz debe ser un GFElement")

            if root.field is not field:
                raise ValueError("Todas las raíces deben pertenecer al campo")

        # Algoritmo implementado:
        # poly = 1

        # factor = x + alpha
        # poly = 1 * (x + alpha)

        # factor = x + alpha^2
        # poly = (x + alpha) * (x + alpha^2)

        one = field.element(1)
        # Inicializamos el poly como 1 (neutro multiplicativo)
        poly = cls(field, [one])

        for root in roots:
            # Factor: x + root
            factor = cls(field, [root, one])

            poly = poly * factor

        return poly

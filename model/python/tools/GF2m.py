## GF2m.py

class GF2m:
    """
    Representa un campo de Galois GF(2^m).

    primitive_poly contiene únicamente los m bits inferiores
    del polinomio primitivo. El término x^m queda implícito.

    Ejemplo:
        P(x) = x^4 + x + 1
        primitive_poly = 0b0011
    """

    def __init__(self, m: int, primitive_poly: int):
        if m <= 0:
            raise ValueError("m debe ser un entero positivo")

        if not 0 <= primitive_poly < (1 << m):
            raise ValueError(f"El polinomio debe representarse con exactamente {m} bits")

        # Un polinomio primitivo debe tener término independiente 1.
        if primitive_poly & 1 == 0:
            raise ValueError("El polinomio primitivo debe tener término independiente igual a 1")

        self.m = m
        self.primitive_poly = primitive_poly

        # Cantidad de elementos del campo: 2^m.
        self.order = 1 << m

        # Máscara para conservar solamente los m bits inferiores.
        self.mask = self.order - 1

        # Tablas de exponenciación y logaritmo
        self.exp_table, self.log_table = self._build_tables()

    def element(self, value: int) -> "GFElement":
        """Crea un elemento perteneciente a este campo."""
        return GFElement(self, value)

    def add(self, a: int, b: int) -> int:
        """
        Suma modular en GF(2^m).
        """
        self._validate_value(a)
        self._validate_value(b)

        return a ^ b

    def multiply(self, a: int, b: int) -> int:
        """
        Producto polinómico con reducción módulo P(x):
            suma en GF(2)       → XOR
            multiplicar por x   → desplazamiento a la izquierda
            reducción módulo P  → XOR con primitive_poly
        """

        self._validate_value(a)
        self._validate_value(b)

        result = 0

        while b != 0:
            # Si el bit menos significativo de b es 1, se agrega el polinomio a al resultado.
            if b & 1:
                result ^= a

            # Detecta si a contiene el término x^(m-1).
            # Al desplazarlo aparecería un término x^m.
            carry = a & (1 << (self.m - 1))

            # Multiplicación por x.
            a <<= 1

            # Si apareció x^m, se reduce usando el polinomio primitivo.
            if carry:
                a ^= self.primitive_poly

            # Conserva solamente los m bits inferiores.
            a &= self.mask

            # Avanza al siguiente bit del multiplicador.
            b >>= 1

        return result

    def square(self, a: int) -> int:
        """Calcula el cuadrado de un elemento del campo."""

        self._validate_value(a)

        return self.multiply(a, a)

    def trace(self, a: int) -> int:
        """
        Calcula la traza absoluta de GF(2^m) sobre GF(2):

            Tr(a) = a + a^2 + a^(2^2) + ... + a^(2^(m-1))

        El resultado pertenece a GF(2), por lo que siempre es 0 o 1.
        """

        self._validate_value(a)

        result = 0
        term = a

        for _ in range(self.m):
            result = self.add(result, term)
            term = self.square(term)

        if result not in (0, 1):
            raise RuntimeError("La traza calculada no pertenece a GF(2)")

        return result

    def power(self, a: int, n: int) -> int:
        """
        Calcula a^n mediante exponenciación binaria.

        Se recorren los bits de n desde el menos significativo:
            bit de n igual a 1 → acumular la potencia actual
            siguiente potencia → elevar la base al cuadrado
            siguiente bit      → desplazar n a la derecha

        Solo se admiten exponentes n >= 0.
        """
        self._validate_value(a)

        if n < 0:
            raise ValueError("El exponente debe ser mayor o igual que cero")

        result = 1
        base = a
        exponent = n

        while exponent != 0:
            if exponent & 1:
                result = self.multiply(result, base)

            base = self.multiply(base, base)
            exponent >>= 1

        return result

    def inverse(self, a: int) -> int:
        """
        Calcula el inverso multiplicativo de a.

        Para a != 0:

            a^(-k) = a^(2^m - 2)
        """
        self._validate_value(a)

        if a == 0:
            raise ZeroDivisionError("El elemento 0 no tiene inverso multiplicativo")

        return self.power(a, self.order - 2)

    def divide(self, a: int, b: int) -> int:
        """
        División en GF(2^m):

            a / b = a * b^(-1)
        """
        self._validate_value(a)
        self._validate_value(b)

        if b == 0:
            raise ZeroDivisionError("No se puede dividir por cero")

        return self.multiply(a, self.inverse(b))

    def exp(self, exponent: int) -> int:
        """
        Devuelve el exponente de alpha
        """

        if not isinstance(exponent, int):
            raise TypeError("El exponente debe ser un entero")

        return self.exp_table[exponent % (self.order - 1)]

    def log(self, value: int) -> int:
        """
        Devuelve el logaritmo de alpha.
        """

        self._validate_value(value)

        if value == 0:
            raise ValueError("El elemento cero no tiene logaritmo")

        return self.log_table[value]

    def to_polynomial_string(self, value: int) -> str:
        """Devuelve la representacion polinomica de un elemento del campo."""

        self._validate_value(value)

        if value == 0:
            return "0"

        terms = []

        for exponent in range(self.m - 1, -1, -1):
            if value & (1 << exponent):
                if exponent == 0:
                    terms.append("1")
                elif exponent == 1:
                    terms.append("x")
                else:
                    terms.append(f"x^{exponent}")

        return " + ".join(terms)

    def elements_table(self) -> list[tuple[str, str, str]]:
        """
        Construye la tabla de elementos del campo.

        Cada fila contiene:
            potencia de alpha, representacion polinomica y vector binario.
        """

        rows = [("-", "0", "0" * self.m)]

        for exponent, value in enumerate(self.exp_table):
            rows.append(
                (
                    f"alpha^{exponent}",
                    self.to_polynomial_string(value),
                    f"{value:0{self.m}b}",
                )
            )

        return rows

    def print_elements_table(self) -> None:
        """Imprime potencia, forma polinomica y vector de cada elemento."""

        headers = ("Potencia", "Polinomica", "Vectorial")
        rows = self.elements_table()
        widths = []

        for column in range(len(headers)):
            width = len(headers[column])

            for row in rows:
                width = max(width, len(row[column]))

            widths.append(width)

        print(
            f"{headers[0]:<{widths[0]}} | "
            f"{headers[1]:<{widths[1]}} | "
            f"{headers[2]:<{widths[2]}}"
        )
        print("-+-".join("-" * width for width in widths))

        for row in rows:
            print(
                f"{row[0]:<{widths[0]}} | "
                f"{row[1]:<{widths[1]}} | "
                f"{row[2]:<{widths[2]}}"
            )


    def _build_tables(self) -> tuple[list[int], list[int]]:
        """
        Construye las tablas de exponenciación y logaritmo.

        exp_table[i] = representación polinómica de alpha^i
        
        log_table[a] = i tal que a = alpha^i

        La construcción también verifica que el polinomio sea primitivo:
        las potencias de alpha deben recorrer todos los elementos no nulos
        sin repetirse antes de volver a 1.
        """

        # El grupo multiplicativo tiene 2^m - 1 elementos.
        multiplicative_order = self.order - 1

        exp_table = [0]  * multiplicative_order     # Representa unicamente los elementos no nulos
        log_table = [-1] * self.order               # Para que log_table[0] = -1

        current = 1     # alpha^0 = 1

        # Para m >= 2, alpha = x se representa como 0b10. En GF(2), en
        # cambio, ese valor queda fuera del campo: al reducir x modulo
        # P(x) = x + 1 se obtiene alpha = 1.
        alpha = 1 if self.m == 1 else 0b10

        for exponent in range(multiplicative_order):
            # Si el valor del logaritmo es distinto a -1 significa que el elemento ya apareció como potencia de alfa
            # Por lo tanto se estaría repitiendo antes de 2^m-1 y el polinomio no es primitivo
            if log_table[current] != -1:
                raise ValueError(f"El polinomio proporcionado no es primitivo: alpha^{exponent}"
                                 f"repite el valor 0b{current:0{self.m}b}"
                )

            exp_table[exponent] = current
            log_table[current] = exponent

            # Multiplicar por alpha
            current = self.multiply(current, alpha)

        # Si el valor de current, que es una potencia de alpha, volvió a 1 antes de 2^m-1 significa que el polinomio no
        # es primitivo
        if current != 1:
            raise ValueError(f"El polinomio proporcionado no es primitivo: alpha^{multiplicative_order} != 1")

        return exp_table, log_table

    def _validate_value(self, value: int) -> None:
        """Verifica que el entero pertenezca al rango del campo."""
        if not isinstance(value, int):
            raise TypeError("Los elementos del campo deben ser enteros")

        if not 0 <= value < self.order:
            raise ValueError(f"El elemento debe estar en el rango [0, {self.order - 1}]")

    def __repr__(self) -> str:
        return (
            f"GF(2^{self.m}, "
            f"P=0b{self.primitive_poly:0{self.m}b})"
        )



class GFElement:
    """Representa un elemento perteneciente a un campo GF(2^m)."""

    def __init__(self, field: GF2m, value: int):
        field._validate_value(value)

        self.field = field
        self.value = value

    def inverse(self) -> "GFElement":
        """Devuelve el inverso multiplicativo del elemento."""

        return GFElement(self.field, self.field.inverse(self.value))

    def square(self) -> "GFElement":
        """Devuelve el cuadrado del elemento."""

        return GFElement(self.field, self.field.square(self.value))

    def trace(self) -> int:
        """Devuelve la traza absoluta del elemento sobre GF(2)."""

        return self.field.trace(self.value)

    def __add__(self, other: "GFElement") -> "GFElement":
        """Suma dos elementos pertenecientes al mismo campo."""
        self._validate_other(other)

        return GFElement(self.field, self.field.add(self.value, other.value))

    def __sub__(self, other: "GFElement") -> "GFElement":
        """
        Resta dos elementos del mismo campo.

        En GF(2^m), suma y resta son la misma operación.
        """
        return self.__add__(other)

    def __mul__(self, other: "GFElement") -> "GFElement":
        """Multiplica dos elementos pertenecientes al mismo campo."""
        self._validate_other(other)

        return GFElement(self.field, self.field.multiply(self.value, other.value))

    def __truediv__(self, other: "GFElement") -> "GFElement":
        """Divide dos elementos pertenecientes al mismo campo."""
        self._validate_other(other)

        return GFElement(self.field, self.field.divide(self.value, other.value))

    def __pow__(self, exponent: int) -> "GFElement":
        """Eleva el elemento a una potencia entera no negativa."""
        return GFElement(self.field, self.field.power(self.value, exponent))

    def __eq__(self, other) -> bool:
        """Compara dos elementos del mismo campo."""
        if not isinstance(other, GFElement):
            return False

        return (self.field is other.field and self.value == other.value)

    def __int__(self) -> int:
        """Devuelve la representación entera del elemento."""
        return self.value

    def __repr__(self) -> str:
        """Muestra el elemento en representación decimal y binaria."""
        binary = f"{self.value:0{self.field.m}b}"

        return f"GFElement({self.value}, 0b{binary})"

    def _validate_other(self, other: "GFElement") -> None:
        """
        Verifica que el otro operando sea un GFElement perteneciente al mismo campo.
        """
        if not isinstance(other, GFElement):
            raise TypeError("Las operaciones solo se permiten entre elementos GFElement")

        if self.field is not other.field:
            raise ValueError("Los elementos deben pertenecer al mismo campo")

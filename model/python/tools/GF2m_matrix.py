from model.python.tools.GF2m import GF2m
from model.python.tools.GFPoly import GFPoly


def transpose_matrix(matrix):
    """Transpone una matriz."""

    rows = len(matrix)
    columns = len(matrix[0])

    return [
        [matrix[i][j] for i in range(rows)]
        for j in range(columns)
    ]


def vector_matrix_product(vector, matrix):
    """Multiplica un vector fila por una matriz"""

    rows = len(matrix)
    columns = len(matrix[0])

    if len(vector) != rows:
        raise ValueError("Las dimensiones del vector y la matriz no coinciden")

    gf = vector[0].field
    result = []

    # result[j] = sum(vector[i] * matrix[i][j])
    for j in range(columns):
        value = gf.element(0)

        for i in range(rows):
            value = value + vector[i] * matrix[i][j]

        result.append(value)

    return result


def matrix_vector_product(matrix, vector):
    """Multiplica una matriz por un vector columna."""

    rows = len(matrix)
    columns = len(matrix[0])

    if len(vector) != columns:
        raise ValueError("Las dimensiones de la matriz y el vector no coinciden")

    gf = matrix[0][0].field
    result = []

    # result[i] = sum(matrix[i][j] * vector[j])
    for i in range(rows):
        value = gf.element(0)

        for j in range(columns):
            value = value + matrix[i][j] * vector[j]

        result.append(value)

    return result


def matrix_matrix_product(matrix_a, matrix_b):
    """Multiplica dos matrices."""

    rows_a = len(matrix_a)
    columns_a = len(matrix_a[0])
    rows_b = len(matrix_b)
    columns_b = len(matrix_b[0])

    if columns_a != rows_b:
        raise ValueError("Las dimensiones de las matrices no coinciden")

    gf = matrix_a[0][0].field
    result = []

    # result[i][j] = sum(matrix_a[i][k] * matrix_b[k][j])
    for i in range(rows_a):
        result_row = []

        for j in range(columns_b):
            value = gf.element(0)

            for k in range(columns_a):
                value = value + matrix_a[i][k] * matrix_b[k][j]

            result_row.append(value)

        result.append(result_row)

    return result


def hamming_weight(vector):
    """Cuenta la cantidad de elementos iguales a uno"""

    weight = 0

    for element in vector:
        if int(element) == 1:
            weight += 1

    return weight


def vector_to_int(vector):
    """Convierte un vector de GFElement a una lista de enteros"""

    result = []

    for element in vector:
        result.append(int(element))

    return result

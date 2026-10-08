# TPF FEC / VLSI / FPGA

Implementacion de una cadena de transmision y recepcion con siete codigos
BCH(127,113) en paralelo, tasa de linea de 800 Gb/s, interleaver
convolucional y cruces entre los dominios FEC y DSP.

El desarrollo sigue los gates definidos por el enunciado. No se comienza una
etapa de implementacion hasta cerrar los criterios de aceptacion de la etapa
anterior.

## Fuentes de verdad

1. `docs/DAMIAN_LUGANO_TP.pdf`: especificacion del trabajo.
2. `planning/acceptance_matrix.md`: trazabilidad y gates internos.
3. Modelo Python: referencia inicial, analisis y generacion de vectores.
4. Modelo C: referencia ejecutable para DPI-C y regresiones extensas.
5. RTL: implementacion sintetizable, validada contra ambos modelos.

Los modelos Python y C deben ser bit-exactos entre si. Los vectores producidos
por Python se conservan como regresiones estaticas; el modelo C permite generar
resultados esperados durante la simulacion sin limitarse a vectores previos.

## Directorios

La estructura y las reglas de cada area se documentan en
`docs/REPOSITORY_LAYOUT.md`.

## Estado inicial

- Enunciado disponible.
- Utilidades preliminares de campo y polinomios en `utils/`, pendientes de
  auditoria antes de integrarlas al modelo Python.
- Etapa activa: Etapa 0, analisis y dimensionamiento.

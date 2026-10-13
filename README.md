# TPF FEC / VLSI / FPGA

Este repositorio contiene el Trabajo Práctico Final de los cursos de DDA, FEC y VLSI. El objetivo es diseñar, modelar, verificar e implementar una cadena de transmisión y recepción FEC de 800 Gb/s basada en siete códigos BCH(127,113) en paralelo.

El trabajo abarca el modelo de referencia en Python y C, la implementación RTL, la verificación en SystemVerilog, la síntesis lógica y la validación sobre FPGA.

## Organización del repositorio

```text
docs/       Enunciado, bibliografía e informe en LaTeX
model/      Modelos de referencia en Python y C
rtl/        Implementación RTL del transmisor y del receptor
tb/         Testbenches unitarios y de integración
syn/        Scripts, restricciones y resultados de síntesis
fpga/       Integración y validación sobre FPGA
reports/    Figuras, resultados y evidencia de las distintas etapas
scripts/    Scripts generales de automatización
```

La especificación original se encuentra en [`docs/DAMIAN_LUGANO_TP.pdf`](docs/DAMIAN_LUGANO_TP.pdf). El desarrollo y las decisiones de diseño se documentan en [`docs/informe/main.tex`](docs/informe/main.tex).

## Estado actual

Las etapas de **Análisis y dimensionamiento del sistema** y de **Modelo de
referencia en Python** están cerradas.

El modelo Python incluye la aritmética de `GF(2^7)`, la construcción del
BCH(127,113), el codificador y el decodificador algebraico para `t = 2`, el
generador y el checker PRBS31, la permutación de lanes, el interleaver
convolucional y sus operaciones inversas, además de los modelos de canal y de
inyección de ráfagas. Los bloques fueron verificados individualmente y la
cadena completa fue integrada y simulada sin ruido, sobre canal aleatorio y
con ráfagas. Se obtuvieron los barridos de BER pre-FEC y post-FEC y se
evaluaron exhaustivamente los 889 offsets de inicio de las ráfagas.

La siguiente etapa comprende los modelos de referencia en C para su uso
directo desde los scoreboards y la implementación RTL del transmisor y del
receptor.
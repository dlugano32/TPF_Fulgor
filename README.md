# TPF FEC / VLSI / FPGA

Este repositorio contiene el Trabajo Práctico Final de los cursos de DDA, FEC y VLSI. El objetivo es diseñar, modelar, verificar e implementar una cadena de transmisión y recepción FEC de 800 Gb/s basada en siete códigos BCH(127,113) en paralelo.

El trabajo abarca el modelo de referencia en Python y C, la implementación RTL, la verificación en SystemVerilog, la síntesis lógica y la validación sobre FPGA.

## Organización del repositorio

```text
docs/       Enunciado, bibliografía e informe en LaTeX
model/      Modelos de referencia en Python y C
rtl/        Implementación RTL del transmisor y del receptor
tb/         Testbenches unitarios y de integración
vectors/    Vectores de prueba y regresión
syn/        Scripts, restricciones y resultados de síntesis
fpga/       Integración y validación sobre FPGA
reports/    Figuras, resultados y evidencia de las distintas etapas
scripts/    Scripts generales de automatización
```

La especificación original se encuentra en [`docs/DAMIAN_LUGANO_TP.pdf`](docs/DAMIAN_LUGANO_TP.pdf). El desarrollo y las decisiones de diseño se documentan en [`docs/informe/main.tex`](docs/informe/main.tex).

## Estado actual

La etapa de **Análisis y dimensionamiento del sistema** está cerrada.

Actualmente se encuentra en desarrollo la etapa de **Modelos de referencia**. Los modelos Python de los bloques principales ya están implementados y verificados individualmente. El próximo paso es integrarlos en una simulación completa sin ruido y, posteriormente, incorporar el canal para realizar los barridos Monte Carlo de BER y FER.

Luego se continuará con la implementación RTL del transmisor y del receptor.

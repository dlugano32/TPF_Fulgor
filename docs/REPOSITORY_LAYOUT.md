# Estructura del repositorio

```text
TPF_Fulgor/
|-- docs/
|   |-- DAMIAN_LUGANO_TP.pdf     Enunciado del trabajo
|   `-- informe/                 Informe en LaTeX (main.tex) y figuras (pics/)
|-- model/
|   |-- python/
|   |   |-- src/                 Oraculo: BCH, PRBS31, canal AWGN, interleaver,
|   |   |                        permutacion, Monte Carlo y dimensionamiento
|   |   |-- tests/               Tests de GF(2^7), encoder y decoder BCH
|   |   `-- tools/               Aritmetica GF(2^m), polinomios y matrices
|   `-- c/
|       |-- include/             Cabeceras de los modelos bit-exactos
|       `-- src/                 GF(2^7), BCH encoder/decoder, PRBS31 y checker
|-- rtl/
|   |-- common/                  gearbox_cdc y sincronizadores (nivel y reset)
|   |-- tx/
|   |   |-- tx_top.sv            Top del transmisor
|   |   |-- prbs31/              Generador PRBS31 paralelo
|   |   |-- encoder/             Codificador BCH(127,113)
|   |   |-- lane_permuter/       Permutacion de lanes
|   |   `-- conv_interleaver/    Interleaver convolucional (Forney)
|   |-- rx/
|   |   |-- rx_top.sv            Top del receptor
|   |   |-- conv_deinterleaver/  Deinterleaver convolucional
|   |   |-- lane_depermuter/     Permutacion inversa de lanes
|   |   |-- decoder/             Decodificador BCH (search-less)
|   |   |   `-- gf127_op/        Operadores y LUTs sobre GF(2^7)
|   |   `-- prbs31_checker/      Checker PRBS31 y contador de errores
|   `-- _deprecated/             Version anterior del CDC (FIFO asincronica + gearbox)
|-- tb/
|   |-- dpi/                     Adaptadores SystemVerilog/C (DPI-C)
|   |-- unit/                    Bancos por bloque: prbs31, bch_encoder, bch_decoder
|   `-- integration/             Bancos de integracion: bch_codec, prbs31_checker,
|                                tx_rx_top, tx_rx_cdc (+ _deprecated/)
|-- syn/                         Scripts de Fusion Compiler (TCL) y restricciones (SDC)
`-- reports/
    |-- figures/                 Figuras reproducibles del informe
    |-- results/                 Resumenes versionables de simulaciones
    `-- syn/                     Reportes de sintesis por bloque y por top
```

# Estructura del repositorio

```text
TPF_Fulgor/
|-- docs/                    Enunciado y documentacion de arquitectura
|-- planning/                Gates, trazabilidad, cronograma y decisiones
|-- model/
|   |-- python/              Oraculo inicial y herramientas de analisis
|   `-- c/                   Modelo bit-exacto para regresion y DPI-C
|-- vectors/
|   |-- smoke/               Casos pequenos versionados
|   `-- generated/           Vectores reproducibles generados localmente
|-- rtl/
|   |-- common/              Tipos y bloques compartidos
|   |-- tx/                  Camino transmisor
|   `-- rx/                  Camino receptor
|-- tb/
|   |-- common/              Transacciones, interfaces y utilidades
|   |-- unit/                Bancos por bloque
|   |-- integration/         Banco end-to-end
|   |-- dpi/                 Adaptadores SystemVerilog/C
|   `-- tests/               Tests dirigidos y aleatorios
|-- synth/
|   |-- dc/                  Scripts de Design Compiler
|   `-- constraints/         Relojes, I/O, CDC y excepciones
|-- fpga/
|   |-- rtl/                 Wrapper y logica exclusiva de FPGA
|   |-- constraints/         XDC de la FPGA
|   |-- scripts/             Creacion y ejecucion del proyecto
|   `-- software/            Control y captura de mediciones
|-- scripts/                 Automatizacion comun
`-- reports/
    |-- stages/              Evidencia de cierre por etapa
    |-- figures/             Figuras reproducibles del informe
    `-- results/             Resumenes versionables de mediciones
```
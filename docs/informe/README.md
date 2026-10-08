# Informe en LaTeX

El informe utiliza el formato del TP3 de VLSI y se compila con XeLaTeX mediante
`latexmk`.

Desde este directorio:

```bash
latexmk -xelatex -interaction=nonstopmode -halt-on-error -outdir=build main.tex
```

La fuente principal es `main.tex`. Las figuras propias del trabajo deben
guardarse en `pics/`. Durante la preparación inicial, el logo de Fundación
Fulgor se reutiliza desde el repositorio de VLSI mediante `graphicspath`.

from pathlib import Path

from model.python.tools.GF2m import GF2m


def log_table_to_systemverilog(field: GF2m, input_name: str = "i_element", output_name: str = "o_logarithm") -> str:
    """Genera un case que implementa log_alpha para los elementos no nulos."""

    lines = [f"    case ({input_name})"]
    lines.append(
        f"        7'h00: {output_name} = 7'd0; // log_alpha(0) no esta definido"
    )

    for element in range(1, field.order):
        logarithm = field.log(element)
        lines.append(
            f"        7'h{element:02X}: {output_name} = 7'd{logarithm};"
        )

    lines.append(f"        default: {output_name} = 7'd0;")
    lines.append("    endcase")

    return "\n".join(lines) + "\n"


def exp_table_to_systemverilog(field: GF2m, input_name: str = "i_exponent", output_name: str = "o_element") -> str:
    """Genera un case que implementa alpha elevado a exponent_i."""

    lines = [f"    case ({input_name})"]

    for exponent in range((1 << field.m) - 1):
        element = field.exp(exponent)
        lines.append(
            f"        7'd{exponent}: {output_name} = 7'h{element:02X};"
        )

    lines.append(f"        default: {output_name} = 7'h00;")
    lines.append("    endcase")

    return "\n".join(lines) + "\n"


def write_gf127_luts(output_directory: Path) -> tuple[Path, Path]:
    """Genera y guarda ambos bloques case en el directorio indicado."""

    # p(x) = x^7 + x^3 + 1
    field = GF2m(m=7, primitive_poly=0b0001001)
    output_directory.mkdir(parents=True, exist_ok=True)

    log_file = output_directory / "gf127_log_lut_case.txt"
    exp_file = output_directory / "gf127_exp_lut_case.txt"

    log_file.write_text(log_table_to_systemverilog(field), encoding="utf-8")
    exp_file.write_text(exp_table_to_systemverilog(field), encoding="utf-8")

    return log_file, exp_file


def main() -> None:
    output_directory = (
        Path(__file__).resolve().parents[3]
        / "rtl/rx/decoder"
    )
    log_file, exp_file = write_gf127_luts(output_directory)

    print("Tabla log :", log_file)
    print("Tabla exp :", exp_file)
    print("Entradas  : 128 para log, 127 para exp")


if __name__ == "__main__":
    main()

import math
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np

from awgn_channel import noise_sigma, theoretical_ber


N = 127
K = 113
CODE_RATE = K / N

EBN0_DB_LIST = np.arange(3.0, 9.01, 0.5)
VISUAL_EBN0_DB = 3.0
OUTPUT_DIRECTORY = Path(__file__).resolve().parents[1] / "results"


def calculate_ber() -> list[float]:
    """Calcula la BER teórica para cada valor de Eb/N0."""

    theoretical_values = []

    print("Eb/N0 [dB] | BER teórica")
    print("------------+------------")

    for ebn0_db in EBN0_DB_LIST:
        ber_theory = theoretical_ber(ebn0_db, CODE_RATE)
        theoretical_values.append(ber_theory)

        print(f"{ebn0_db:11.1f} | {ber_theory:10.4e}")

    return theoretical_values


def plot_ber(theoretical_values) -> None:
    """Grafica la BER teórica de PAM2 sobre AWGN."""

    plt.figure(figsize=(7, 5))
    plt.semilogy(EBN0_DB_LIST, theoretical_values, "o-", label="PAM2 teórica")
    plt.grid(True, which="both", alpha=0.4)
    plt.xlabel("$E_b/N_0$ [dB]")
    plt.ylabel("BER pre-FEC")
    plt.title("Canal PAM2-AWGN con decisión dura")
    plt.legend()
    plt.tight_layout()
    plt.savefig(OUTPUT_DIRECTORY / "ber_pre_fec.png", dpi=160)
    plt.close()


def plot_constellation(sigma: float) -> None:
    """Muestra los símbolos PAM2 y su dispersión teórica por el ruido."""

    figure, axes = plt.subplots(1, 2, figsize=(9, 3.5), sharey=True)
    ideal_symbols = np.array([-1.0, 1.0])

    axes[0].scatter(ideal_symbols, np.zeros(len(ideal_symbols)), s=55)
    axes[0].set_title("Sin ruido")

    axes[1].errorbar(
        ideal_symbols,
        np.zeros(len(ideal_symbols)),
        xerr=sigma,
        fmt="o",
        capsize=5,
        label=r"Símbolos y dispersión $\pm\sigma$",
    )
    axes[1].set_title(f"Con ruido, $E_b/N_0={VISUAL_EBN0_DB:.1f}$ dB")
    axes[1].legend()

    for axis in axes:
        axis.axvline(0.0, color="gray", linewidth=1, linestyle="--")
        axis.set_xlabel("Amplitud")
        axis.set_ylim(-0.25, 0.25)
        axis.grid(True, alpha=0.3)

    axes[0].set_ylabel("Componente ortogonal")
    figure.suptitle("Constelación PAM2")
    figure.tight_layout()
    figure.savefig(OUTPUT_DIRECTORY / "pam2_constellation.png", dpi=160)
    plt.close(figure)


def gaussian_pdf(values, mean: float, sigma: float):
    """Evalúa una densidad gaussiana."""

    scale = 1.0 / (sigma * math.sqrt(2.0 * math.pi))
    return scale * np.exp(-0.5 * ((values - mean) / sigma) ** 2)


def plot_noise_pdf(sigma: float) -> None:
    """Grafica la PDF teórica del ruido gaussiano."""

    horizontal_axis = np.linspace(-4.0 * sigma, 4.0 * sigma, 500)

    plt.figure(figsize=(7, 5))
    plt.plot(horizontal_axis, gaussian_pdf(horizontal_axis, 0.0, sigma), label="PDF teórica")
    plt.grid(True, alpha=0.3)
    plt.xlabel("Amplitud del ruido $n$")
    plt.ylabel("Densidad de probabilidad")
    plt.title(f"Ruido AWGN, $E_b/N_0={VISUAL_EBN0_DB:.1f}$ dB")
    plt.legend()
    plt.tight_layout()
    plt.savefig(OUTPUT_DIRECTORY / "noise_pdf.png", dpi=160)
    plt.close()


def plot_received_distribution(sigma: float) -> None:
    """Grafica la PDF teórica de las muestras y=x+n."""

    horizontal_axis = np.linspace(-3.5, 3.5, 700)
    theoretical_pdf = 0.5 * gaussian_pdf(horizontal_axis, -1.0, sigma)
    theoretical_pdf += 0.5 * gaussian_pdf(horizontal_axis, 1.0, sigma)

    plt.figure(figsize=(7, 5))
    plt.plot(horizontal_axis, theoretical_pdf, label="PDF teórica")
    plt.axvline(0.0, color="gray", linewidth=1, linestyle="--", label="Umbral")
    plt.grid(True, alpha=0.3)
    plt.xlabel("Muestra recibida $y=x+n$")
    plt.ylabel("Densidad de probabilidad")
    plt.title(f"Distribución de las muestras, $E_b/N_0={VISUAL_EBN0_DB:.1f}$ dB")
    plt.legend()
    plt.tight_layout()
    plt.savefig(OUTPUT_DIRECTORY / "received_samples_pdf.png", dpi=160)
    plt.close()


def main() -> None:
    OUTPUT_DIRECTORY.mkdir(parents=True, exist_ok=True)

    theoretical_values = calculate_ber()
    plot_ber(theoretical_values)

    sigma = noise_sigma(VISUAL_EBN0_DB, CODE_RATE)
    plot_constellation(sigma)
    plot_noise_pdf(sigma)
    plot_received_distribution(sigma)

    print(f"\nGráficos guardados en {OUTPUT_DIRECTORY}")


if __name__ == "__main__":
    main()

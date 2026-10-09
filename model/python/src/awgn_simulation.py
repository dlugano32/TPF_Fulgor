import math
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np

from model.python.src.awgn_channel import noise_sigma, theoretical_ber


N = 127
K = 113
CODE_RATE = K / N

EBN0_DB_LIST = np.arange(3.0, 9.01, 0.5)
FRAMES_PER_BATCH = 20_000
MAX_FRAMES = 2_000_000
MIN_ERRORS = 200
SEED = 2026

VISUAL_EBN0_DB = 6.0
VISUAL_SAMPLES = 200_000
OUTPUT_DIRECTORY = Path(__file__).resolve().parents[1] / "results"


def simulate_ber(random_generator) -> tuple[list[float], list[float]]:
    """Estima la BER pre-FEC para cada valor de Eb/N0."""

    simulated_ber = []
    theoretical_values = []

    print("Eb/N0 [dB] | Frames | Errores | BER simulada | BER teórica")
    print("------------+--------+---------+--------------+------------")

    for ebn0_db in EBN0_DB_LIST:
        sigma = noise_sigma(ebn0_db, CODE_RATE)
        frames = 0
        errors = 0

        while frames < MAX_FRAMES and errors < MIN_ERRORS:
            batch_frames = min(FRAMES_PER_BATCH, MAX_FRAMES - frames)
            bits = random_generator.integers(0, 2, size=(batch_frames, N), dtype=np.int8)
            transmitted = 1.0 - 2.0 * bits
            noise = random_generator.normal(0.0, sigma, transmitted.shape)
            received_bits = transmitted + noise < 0.0

            errors += int(np.count_nonzero(received_bits != bits))
            frames += batch_frames

        ber = errors / (frames * N)
        ber_theory = theoretical_ber(ebn0_db, CODE_RATE)
        simulated_ber.append(ber)
        theoretical_values.append(ber_theory)

        print(
            f"{ebn0_db:11.1f} | {frames:6d} | {errors:7d} | "
            f"{ber:12.4e} | {ber_theory:10.4e}"
        )

    return simulated_ber, theoretical_values


def plot_ber(simulated_ber, theoretical_values) -> None:
    """Grafica la BER simulada y la expresión teórica."""

    plt.figure(figsize=(7, 5))
    plt.semilogy(EBN0_DB_LIST, theoretical_values, "-", label="PAM2 teórica")
    plt.semilogy(EBN0_DB_LIST, simulated_ber, "o", label="PAM2 simulada")
    plt.grid(True, which="both", alpha=0.4)
    plt.xlabel("$E_b/N_0$ [dB]")
    plt.ylabel("BER pre-FEC")
    plt.title("Canal PAM2-AWGN con decisión dura")
    plt.legend()
    plt.tight_layout()
    plt.savefig(OUTPUT_DIRECTORY / "ber_pre_fec.png", dpi=160)
    plt.close()


def plot_constellation(transmitted, received) -> None:
    """Muestra la constelación PAM2 ideal y luego del canal."""

    figure, axes = plt.subplots(1, 2, figsize=(9, 3.5), sharey=True)
    ideal_symbols = np.unique(transmitted)

    axes[0].scatter(ideal_symbols, np.zeros(len(ideal_symbols)), s=55)
    axes[0].set_title("Sin ruido")

    axes[1].scatter(received[:1000], np.zeros(1000), s=8, alpha=0.15)
    axes[1].scatter(
        ideal_symbols,
        np.zeros(len(ideal_symbols)),
        s=40,
        marker="x",
        label="Símbolos ideales",
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


def plot_noise_pdf(noise, sigma: float) -> None:
    """Compara el histograma del ruido con su PDF teórica."""

    horizontal_axis = np.linspace(-4.0 * sigma, 4.0 * sigma, 500)

    plt.figure(figsize=(7, 5))
    plt.hist(noise, bins=100, density=True, alpha=0.55, label="Muestras")
    plt.plot(horizontal_axis, gaussian_pdf(horizontal_axis, 0.0, sigma), label="PDF teórica")
    plt.grid(True, alpha=0.3)
    plt.xlabel("Amplitud del ruido $n$")
    plt.ylabel("Densidad de probabilidad")
    plt.title(f"Ruido AWGN, $E_b/N_0={VISUAL_EBN0_DB:.1f}$ dB")
    plt.legend()
    plt.tight_layout()
    plt.savefig(OUTPUT_DIRECTORY / "noise_pdf.png", dpi=160)
    plt.close()


def plot_received_distribution(received, sigma: float) -> None:
    """Muestra la distribución bimodal de las muestras y=x+n."""

    horizontal_axis = np.linspace(-3.5, 3.5, 700)
    theoretical_pdf = 0.5 * gaussian_pdf(horizontal_axis, -1.0, sigma)
    theoretical_pdf += 0.5 * gaussian_pdf(horizontal_axis, 1.0, sigma)

    plt.figure(figsize=(7, 5))
    plt.hist(received, bins=120, density=True, alpha=0.55, label="Muestras recibidas")
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
    random_generator = np.random.default_rng(SEED)

    simulated_ber, theoretical_values = simulate_ber(random_generator)
    plot_ber(simulated_ber, theoretical_values)

    sigma = noise_sigma(VISUAL_EBN0_DB, CODE_RATE)
    bits = random_generator.integers(0, 2, VISUAL_SAMPLES, dtype=np.int8)
    transmitted = 1.0 - 2.0 * bits
    noise = random_generator.normal(0.0, sigma, VISUAL_SAMPLES)
    received = transmitted + noise

    plot_constellation(transmitted, received)
    plot_noise_pdf(noise, sigma)
    plot_received_distribution(received, sigma)

    print(f"\nGráficos guardados en {OUTPUT_DIRECTORY}")


if __name__ == "__main__":
    main()

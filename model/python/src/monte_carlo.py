import csv
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np

from model.python.src.system import FECSystem


EBN0_DB_LIST = np.arange(3.0, 8.01, 0.5)
FRAMES_PER_BATCH = 20_000
MAX_FRAMES = 2_000_000
MIN_POST_ERRORS = 200
SEED = 2026
OUTPUT_DIRECTORY = Path(__file__).resolve().parents[1] / "results"
PLOT_FILE = OUTPUT_DIRECTORY / "ber_system_new.png"
CSV_FILE = OUTPUT_DIRECTORY / "ber_system_new.csv"
CSV_FIELDS = (
    "ebn0_db",
    "frames",
    "pre_fec_bits",
    "pre_fec_errors",
    "pre_fec_ber",
    "post_fec_bits",
    "post_fec_errors",
    "post_fec_ber",
)


def save_csv(results: list[dict]) -> None:
    """Guarda los puntos completados de la simulación."""

    OUTPUT_DIRECTORY.mkdir(parents=True, exist_ok=True)
    with CSV_FILE.open("w", newline="", encoding="utf-8") as csv_file:
        writer = csv.DictWriter(csv_file, fieldnames=CSV_FIELDS)
        writer.writeheader()
        for result in results:
            writer.writerow({
                **result,
                "ebn0_db": f"{result['ebn0_db']:.1f}",
                "pre_fec_ber": f"{result['pre_fec_ber']:.12e}",
                "post_fec_ber": f"{result['post_fec_ber']:.12e}",
            })


def simulate() -> list[dict]:
    """Ejecuta Monte Carlo hasta alcanzar errores o el máximo de frames."""

    system = FECSystem(mode="awgn")
    results = []
    print("Eb/N0 | Frames | BER pre    | BER post   | Errores post")
    print("------+--------+------------+------------+-------------")

    for point_index, ebn0_db in enumerate(EBN0_DB_LIST):
        frames = 0
        pre_fec_bits = 0
        pre_fec_errors = 0
        post_fec_bits = 0
        post_fec_errors = 0

        while frames < MAX_FRAMES and post_fec_errors < MIN_POST_ERRORS:
            batch_frames = min(FRAMES_PER_BATCH, MAX_FRAMES - frames)
            channel_seed = SEED + point_index * MAX_FRAMES + frames
            batch = system.run(
                frame_count=batch_frames,
                ebn0_db=float(ebn0_db),
                channel_seed=channel_seed,
                verbose=False,
            )

            frames += batch["frames"]
            pre_fec_bits += batch["pre_fec_bits"]
            pre_fec_errors += batch["pre_fec_errors"]
            post_fec_bits += batch["post_fec_bits"]
            post_fec_errors += batch["post_fec_errors"]

        pre_fec_ber = pre_fec_errors / pre_fec_bits
        post_fec_ber = post_fec_errors / post_fec_bits

        result = {
            "ebn0_db": float(ebn0_db),
            "frames": frames,
            "pre_fec_bits": pre_fec_bits,
            "pre_fec_errors": pre_fec_errors,
            "pre_fec_ber": pre_fec_ber,
            "post_fec_bits": post_fec_bits,
            "post_fec_errors": post_fec_errors,
            "post_fec_ber": post_fec_ber,
        }
        results.append(result)
        save_csv(results)

        print(
            f"{ebn0_db:5.1f} | {frames:6d} | {pre_fec_ber:10.3e} | "
            f"{post_fec_ber:10.3e} | {post_fec_errors:12d}"
        )

    return results


def plot(results: list[dict]) -> None:
    """Grafica BER pre-FEC y post-FEC en función de Eb/N0."""

    ebn0_db = np.array([result["ebn0_db"] for result in results])
    pre_fec_ber = np.array([result["pre_fec_ber"] for result in results])
    post_fec_ber = np.array([result["post_fec_ber"] for result in results])

    measured_post = post_fec_ber > 0.0

    OUTPUT_DIRECTORY.mkdir(parents=True, exist_ok=True)
    plt.figure(figsize=(7, 5))
    plt.semilogy(
        ebn0_db,
        pre_fec_ber,
        "o-",
        label="Pre-FEC",
    )
    plt.semilogy(
        ebn0_db[measured_post],
        post_fec_ber[measured_post],
        "s-",
        label="Post-FEC",
    )

    plt.grid(True, which="both", alpha=0.4)
    plt.xlabel("$E_b/N_0$ [dB]")
    plt.ylabel("BER")
    plt.title("Cadena BCH(127,113) sobre canal AWGN")
    plt.legend()
    plt.tight_layout()
    plt.savefig(PLOT_FILE, dpi=160)
    plt.close()


def main() -> None:
    results = simulate()
    plot(results)
    print(f"\nTabla guardada en {CSV_FILE}")
    print(f"Gráfico guardado en {PLOT_FILE}")


if __name__ == "__main__":
    main()

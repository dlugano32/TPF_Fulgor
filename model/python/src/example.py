#!/usr/bin/env python3
"""
BCH(127,113) t=2  +  PAM2 (BPSK)  +  AWGN  +  hard decision decoding

Cuentito:
  1. Tomamos 113 bits de mensaje y les agregamos 14 bits de paridad
     (BCH sistematico sobre GF(2^7), g(x) = m1(x) * m3(x), corrige t=2).
  2. Cada bit va a un simbolo PAM2: 0 -> +1, 1 -> -1  (Es = 1).
  3. Sumamos ruido gaussiano con sigma^2 = N0/2. El N0 sale del Eb/N0
     pedido, teniendo en cuenta el rate R = 113/127 (el codigo "gasta"
     energia en la paridad).
  4. Slicer: signo de la muestra -> bit (hard decision).
  5. Decoder algebraico:
       S1 = r(a), S3 = r(a^3)
       S1=0, S3=0          -> sin errores
       S3 = S1^3           -> 1 error en la posicion log(S1)
       si no               -> sigma(x) = 1 + S1 x + ((S3 + S1^3)/S1) x^2
                              Chien: buscamos raices; si hay 2, corregimos;
                              si no, falla de decodificacion (se deja igual).
  6. Medimos BER pre FEC (salida del slicer) y post FEC (bits de mensaje),
     y la SNR medida en el canal para chequear que el ruido es el pedido.

Convencion: c[i] es el coeficiente de x^i.
  c(x) = p(x) + x^14 * m(x)  ->  c = [p0..p13 | m0..m112]
"""

import numpy as np
from math import erfc, sqrt

# ---------------------------------------------------------------------------
# Parametros
# ---------------------------------------------------------------------------
M = 7
N = 127
K = 113
NK = N - K           # 14
T = 2
PRIM_POLY = 0b10001001   # x^7 + x^3 + 1

EBN0_DB_LIST = np.arange(3.0, 9.01, 0.5)
FRAMES_PER_BATCH = 20000
MAX_FRAMES = 2_000_000
MIN_POST_ERRORS = 200
SEED = 1234

# ---------------------------------------------------------------------------
# GF(2^7): tablas exp / log
# ---------------------------------------------------------------------------
Q = 1 << M           # 128
ORDER = Q - 1        # 127

EXP = np.zeros(2 * ORDER, dtype=np.int64)
LOG = np.full(Q, -1, dtype=np.int64)
x = 1
for i in range(ORDER):
    EXP[i] = x
    LOG[x] = i
    x <<= 1
    if x & Q:
        x ^= PRIM_POLY
EXP[ORDER:] = EXP[:ORDER]


def gf_mul(a, b):
    """Producto en GF(2^7), vectorizado. a, b arrays de enteros 0..127."""
    a = np.asarray(a)
    b = np.asarray(b)
    out = np.zeros(np.broadcast(a, b).shape, dtype=np.int64)
    nz = (a != 0) & (b != 0)
    la = np.broadcast_to(LOG[a], out.shape)
    lb = np.broadcast_to(LOG[b], out.shape)
    out[nz] = EXP[(la[nz] + lb[nz]) % ORDER]
    return out


def gf_div(a, b):
    """a / b en GF(2^7), b != 0."""
    a = np.asarray(a)
    b = np.asarray(b)
    out = np.zeros(np.broadcast(a, b).shape, dtype=np.int64)
    nz = (a != 0)
    la = np.broadcast_to(LOG[a], out.shape)
    lb = np.broadcast_to(LOG[b], out.shape)
    out[nz] = EXP[(la[nz] - lb[nz]) % ORDER]
    return out


def gf_pow(a, e):
    a = np.asarray(a)
    out = np.zeros(a.shape, dtype=np.int64)
    nz = (a != 0)
    out[nz] = EXP[(LOG[a[nz]] * e) % ORDER]
    return out


# ---------------------------------------------------------------------------
# Polinomio generador g(x) = m1(x) * m3(x)
# Polinomios binarios como listas de coeficientes, indice = grado
# ---------------------------------------------------------------------------
def poly_mul_gf(p, q):
    """Producto de polinomios con coeficientes en GF(2^7)."""
    r = [0] * (len(p) + len(q) - 1)
    for i, pi in enumerate(p):
        for j, qj in enumerate(q):
            r[i + j] ^= int(gf_mul(pi, qj))
    return r


def minimal_poly(power):
    """Polinomio minimo de a^power: producto de (x + a^(power*2^k)) sobre la clase ciclotomica."""
    coset = []
    e = power % ORDER
    while e not in coset:
        coset.append(e)
        e = (e * 2) % ORDER
    p = [1]
    for e in coset:
        p = poly_mul_gf(p, [int(EXP[e]), 1])
    assert all(c in (0, 1) for c in p), "el minimo tiene que quedar binario"
    return p


def poly_mul_bin(p, q):
    r = [0] * (len(p) + len(q) - 1)
    for i, pi in enumerate(p):
        if pi:
            for j, qj in enumerate(q):
                r[i + j] ^= qj
    return r


M1 = minimal_poly(1)
M3 = minimal_poly(3)
G_POLY = poly_mul_bin(M1, M3)
assert len(G_POLY) - 1 == NK, f"grado de g(x) = {len(G_POLY) - 1}, esperaba {NK}"


def poly_str(p):
    terms = [("1" if i == 0 else ("x" if i == 1 else f"x^{i}"))
             for i in range(len(p) - 1, -1, -1) if p[i]]
    return " + ".join(terms)


# ---------------------------------------------------------------------------
# Encoder sistematico via matriz generadora
# Fila j: x^(14+j) mod g(x)  en las posiciones de paridad, 1 en la posicion 14+j
# ---------------------------------------------------------------------------
def poly_mod_bin(dividend, divisor):
    r = list(dividend)
    dg = len(divisor) - 1
    for i in range(len(r) - 1, dg - 1, -1):
        if r[i]:
            for j in range(dg + 1):
                r[i - dg + j] ^= divisor[j]
    return r[:dg]


G_MAT = np.zeros((K, N), dtype=np.int64)
for j in range(K):
    mono = [0] * (NK + j + 1)
    mono[NK + j] = 1
    G_MAT[j, :NK] = poly_mod_bin(mono, G_POLY)
    G_MAT[j, NK + j] = 1


def bch_encode(msg):
    """msg: (F, 113) bits -> (F, 127) bits."""
    return (msg.astype(np.int64) @ G_MAT) & 1


# ---------------------------------------------------------------------------
# Sindromes como producto matricial binario
# A1[i] = bits de a^i,  A3[i] = bits de a^(3i)
# ---------------------------------------------------------------------------
BITW = (1 << np.arange(M)).astype(np.int64)
A1 = np.array([[(int(EXP[i % ORDER]) >> b) & 1 for b in range(M)] for i in range(N)], dtype=np.int64)
A3 = np.array([[(int(EXP[(3 * i) % ORDER]) >> b) & 1 for b in range(M)] for i in range(N)], dtype=np.int64)


def syndromes(r):
    s1 = (((r @ A1) & 1) @ BITW)
    s3 = (((r @ A3) & 1) @ BITW)
    return s1, s3


# ---------------------------------------------------------------------------
# Decoder hard decision t=2 (Peterson + Chien), vectorizado sobre tramas
# ---------------------------------------------------------------------------
# Para la Chien: a^{-i} y a^{-2i} para i = 0..126
INV_I = EXP[(-np.arange(N)) % ORDER]
INV_2I = EXP[(-2 * np.arange(N)) % ORDER]


def bch_decode(r):
    """
    r: (F, 127) bits recibidos (hard).
    Devuelve (c_hat, status) con status:
      0 = sin errores, 1 = corrigio 1, 2 = corrigio 2, -1 = falla detectada
    """
    F = r.shape[0]
    c_hat = r.copy()
    status = np.zeros(F, dtype=np.int64)

    s1, s3 = syndromes(r)
    s1_cubed = gf_pow(s1, 3)

    # 1 error
    one = (s1 != 0) & (s3 == s1_cubed)
    idx1 = np.nonzero(one)[0]
    pos1 = LOG[s1[idx1]]
    c_hat[idx1, pos1] ^= 1
    status[idx1] = 1

    # S1 = 0 y S3 != 0: mas de 2 errores, falla
    fail_a = (s1 == 0) & (s3 != 0)
    status[fail_a] = -1

    # 2 errores: sigma(x) = 1 + S1 x + sigma2 x^2
    two = (s1 != 0) & (s3 != s1_cubed)
    idx2 = np.nonzero(two)[0]
    if idx2.size:
        sig1 = s1[idx2]
        sig2 = gf_div(s3[idx2] ^ s1_cubed[idx2], sig1)
        # Chien: evaluar sigma(a^{-i}) para todo i, shape (F2, 127)
        val = 1 ^ gf_mul(sig1[:, None], INV_I[None, :]) ^ gf_mul(sig2[:, None], INV_2I[None, :])
        roots = (val == 0)
        nroots = roots.sum(axis=1)
        ok = (nroots == 2)
        rows_ok = idx2[ok]
        c_hat[rows_ok] ^= roots[ok].astype(np.int64)
        status[rows_ok] = 2
        status[idx2[~ok]] = -1

    return c_hat, status


# ---------------------------------------------------------------------------
# Self checks antes de simular
# ---------------------------------------------------------------------------
def self_check(rng):
    msg = rng.integers(0, 2, size=(2000, K))
    cw = bch_encode(msg)
    s1, s3 = syndromes(cw)
    assert np.all(s1 == 0) and np.all(s3 == 0), "encoder: palabras con sindrome != 0"
    assert np.array_equal(cw[:, NK:], msg), "encoder no es sistematico"

    # Todos los errores simples
    cw0 = cw[0]
    r = np.tile(cw0, (N, 1))
    r[np.arange(N), np.arange(N)] ^= 1
    c_hat, st = bch_decode(r)
    assert np.all(c_hat == cw0) and np.all(st == 1), "falla con 1 error"

    # Todos los pares de errores (8001 patrones)
    ii, jj = np.triu_indices(N, k=1)
    r = np.tile(cw0, (ii.size, 1))
    r[np.arange(ii.size), ii] ^= 1
    r[np.arange(ii.size), jj] ^= 1
    c_hat, st = bch_decode(r)
    assert np.all(c_hat == cw0) and np.all(st == 2), "falla con 2 errores"

    # 3 errores: nunca deberia "corregir" a la palabra original (dmin = 5)
    F = 5000
    r = np.tile(cw0, (F, 1))
    for f in range(F):
        r[f, rng.choice(N, 3, replace=False)] ^= 1
    c_hat, st = bch_decode(r)
    assert not np.any(np.all(c_hat == cw0, axis=1)), "3 errores devolvieron la palabra original?"
    miscorr = np.mean(st >= 0)
    print(f"[check] encoder sistematico OK, sindromes cero OK")
    print(f"[check] 127 patrones de 1 error y 8001 de 2 errores corregidos OK")
    print(f"[check] 3 errores: falla detectada {np.mean(st == -1):.3f}, miscorreccion {miscorr:.3f}")


# ---------------------------------------------------------------------------
# Canal y simulacion
# ---------------------------------------------------------------------------
def qfunc(v):
    return 0.5 * erfc(v / sqrt(2.0))


def simulate(rng):
    R = K / N
    results = []
    print()
    print(f"{'Eb/N0':>6} {'Es/N0':>6} {'SNRmed':>7} {'frames':>9} "
          f"{'BER pre':>10} {'BER teo':>10} {'BER post':>10} {'FER post':>10} {'fallas':>8}")

    for ebn0_db in EBN0_DB_LIST:
        ebn0 = 10 ** (ebn0_db / 10)
        esn0 = R * ebn0                 # energia por simbolo codificado
        sigma = np.sqrt(1.0 / (2.0 * esn0))   # Es = 1, sigma^2 = N0/2

        frames = 0
        pre_err = 0
        post_err = 0
        frame_err = 0
        fails = 0
        sig_pow = 0.0
        noise_pow = 0.0

        while frames < MAX_FRAMES and post_err < MIN_POST_ERRORS:
            F = FRAMES_PER_BATCH
            msg = rng.integers(0, 2, size=(F, K))
            cw = bch_encode(msg)

            tx = 1.0 - 2.0 * cw                    # PAM2: 0 -> +1, 1 -> -1
            noise = sigma * rng.standard_normal(tx.shape)
            rx = tx + noise

            r_hard = (rx < 0).astype(np.int64)     # slicer
            c_hat, st = bch_decode(r_hard)
            m_hat = c_hat[:, NK:]

            pre_err += int(np.sum(r_hard != cw))
            be = np.sum(m_hat != msg, axis=1)
            post_err += int(be.sum())
            frame_err += int(np.sum(be > 0))
            fails += int(np.sum(st == -1))
            sig_pow += float(np.sum(tx ** 2))
            noise_pow += float(np.sum(noise ** 2))
            frames += F

        ber_pre = pre_err / (frames * N)
        ber_post = post_err / (frames * K)
        fer = frame_err / frames
        snr_meas_db = 10 * np.log10(sig_pow / noise_pow)   # Es / sigma^2 = 2 Es/N0
        ber_teo = qfunc(np.sqrt(2 * esn0))

        results.append(dict(ebn0_db=ebn0_db, esn0_db=10 * np.log10(esn0),
                            snr_meas_db=snr_meas_db, frames=frames,
                            ber_pre=ber_pre, ber_teo=ber_teo,
                            ber_post=ber_post, fer=fer,
                            ber_unc=qfunc(np.sqrt(2 * ebn0))))
        print(f"{ebn0_db:6.2f} {10*np.log10(esn0):6.2f} {snr_meas_db:7.2f} {frames:9d} "
              f"{ber_pre:10.3e} {ber_teo:10.3e} {ber_post:10.3e} {fer:10.3e} {fails:8d}")
    return results


def plot(results, fname="bch127_113_pam2_ber.png"):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    eb = np.array([r["ebn0_db"] for r in results])
    unc = np.array([r["ber_unc"] for r in results])
    pre = np.array([r["ber_pre"] for r in results])
    teo = np.array([r["ber_teo"] for r in results])
    post = np.array([r["ber_post"] for r in results])

    # Fino para la curva teorica sin codificar
    ebf = np.linspace(eb[0], eb[-1], 200)
    uncf = [qfunc(np.sqrt(2 * 10 ** (e / 10))) for e in ebf]

    plt.figure(figsize=(8, 6))
    plt.semilogy(ebf, uncf, "k-", label="PAM2 sin codificar (teorica)")
    plt.semilogy(eb, teo, "b--", label="Pre FEC teorica (Es/N0 = R Eb/N0)")
    plt.semilogy(eb, pre, "bo", label="Pre FEC simulada")
    mask = post > 0
    plt.semilogy(eb[mask], post[mask], "rs-", label="Post FEC BCH(127,113) hard")
    plt.grid(True, which="both", alpha=0.4)
    plt.xlabel("Eb/N0 [dB]")
    plt.ylabel("BER")
    plt.title("BCH(127,113) t=2, PAM2, AWGN, hard decision")
    plt.legend()
    plt.ylim(1e-8, 1)
    plt.tight_layout()
    plt.savefig(fname, dpi=130)
    print(f"\nGrafico guardado en {fname}")


def main():
    rng = np.random.default_rng(SEED)
    print(f"GF(2^7), p(x) = {poly_str([int(b) for b in format(PRIM_POLY, 'b')[::-1]])}")
    print(f"m1(x) = {poly_str(M1)}")
    print(f"m3(x) = {poly_str(M3)}")
    print(f"g(x)  = {poly_str(G_POLY)}   (grado {len(G_POLY)-1})")
    print(f"Rate R = {K}/{N} = {K/N:.4f}, perdida de rate = {10*np.log10(N/K):.3f} dB")
    print()
    self_check(rng)
    results = simulate(rng)
    plot(results)


if __name__ == "__main__":
    main()
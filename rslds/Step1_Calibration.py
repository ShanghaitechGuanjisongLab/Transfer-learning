"""Step1_Calibration.py —— 判据校准（对应 PreReg §11-T2 的前置）

目的：给每一档预处理 P0/P1/P2 量出「在**没有吸引子**的数据上，判据表现成什么样」，
      并测出对真吸引子的功效。据此再决定主分析用哪一档。

五类合成数据（只换生成器，流水线完全相同）：
  N-A1  纯共模漂移（无吸引子）
  N-A2  秩-3 慢成分 × 随机载荷（更严苛的漂移，无吸引子）
  N-C   极限环（有低维结构、有径向收缩，但**无不动点**）
  P-C   点吸引子（τ = 10 / 40 s）
  P-L   线吸引子（τ = 10 s / 中性）

所有信噪比按**真实数据**校准：前 2 个 PC 的解释方差 ≈ 25%。
输出每个条件的 **绝对统计量** 分布（中位数与 5–95%），不做事先阈值。
"""
from __future__ import annotations

import json
import os
import time

import numpy as np
from scipy.signal import butter, filtfilt

import attractor_core as AC
from rslds_data import load_block, scan_cohort

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "results", "_step1_calibration.json")

T_USE = 4000
N_SIM = 20
VARIANTS = ["P0", "P1", "P2"]
DIMS = [2]
ALPHA = 1.0 / 3.0          # 信号方差占比 ≈ 25%


def lowpass(x, fs, fc, order=2):
    b, a = butter(order, fc / (fs / 2.0), "low")
    return filtfilt(b, a, x, axis=0)


def load_real_sources(n_mouse=2):
    ms = scan_cohort("ALB")
    by = {}
    for m in ms:
        by.setdefault(m["mouse"], {}).setdefault(m["phase"], []).append(m)
    srcs = []
    for mouse in sorted(by):
        ph = by[mouse]
        if "Learned" not in ph or len(srcs) >= n_mouse:
            continue
        d = load_block(ph["Learned"][0]["path"])
        Y = AC.dff(d["X"][:T_USE], d["fs"])
        Y = np.nan_to_num(Y, nan=0.0, posinf=0.0, neginf=0.0)
        Y = Y[:, np.std(Y, 0) > 1e-9]
        srcs.append(dict(mouse=mouse, Y=Y, fs=d["fs"]))
        print(f"  源 {mouse}: T={Y.shape[0]} N={Y.shape[1]} fs={d['fs']:.3f}")
    return srcs


def split_drift(Y, fs, fc=0.01):
    g = lowpass(Y.mean(1), fs, fc)
    return g, Y - g[:, None]


def circ_shift(R, rng):
    T, N = R.shape
    out = np.empty_like(R)
    for j in range(N):
        out[:, j] = np.roll(R[:, j], int(rng.integers(1, T)))
    return out


# ----------------------------- 生成器 ----------------------------- #
def gen_null_common(src, rng):
    g, R = split_drift(src["Y"], src["fs"])
    return g[:, None] + circ_shift(R, rng)


def gen_null_rank3(src, rng):
    g, R = split_drift(src["Y"], src["fs"])
    T, N = R.shape
    S = lowpass(rng.standard_normal((T, 3)), src["fs"], 0.01)
    S /= np.maximum(S.std(0, keepdims=True), 1e-12)
    slow = S @ rng.standard_normal((N, 3)).T
    slow *= np.std(g) / max(np.std(slow), 1e-12)
    return slow + circ_shift(R, rng)


def _plant(z, rng, alpha=ALPHA, rho=(0.5, 0.95)):
    T = len(z)
    N = 400
    zc = (z - z.mean(0)) / np.maximum(z.std(0), 1e-12)
    Lk = rng.standard_normal((N, z.shape[1]))
    Lk /= np.maximum(np.linalg.norm(Lk, axis=0, keepdims=True), 1e-12)
    sig = zc @ Lk.T
    sig *= np.sqrt(alpha / max(sig.var(0).mean(), 1e-12))
    rr = rng.uniform(*rho, size=N)
    e = rng.standard_normal((T, N))
    x = np.empty((T, N))
    x[0] = e[0]
    for t in range(1, T):
        x[t] = rr * x[t - 1] + np.sqrt(1 - rr ** 2) * e[t]
    return sig + x


def gen_null_ring(src, rng):
    T, fs = src["Y"].shape[0], src["fs"]
    dt = 1.0 / fs
    r, th = 1.0, 0.0
    z = np.empty((T, 2))
    for t in range(T):
        r = r + dt * 0.5 * (1.0 - r) + 0.02 * np.sqrt(dt) * rng.standard_normal()
        th = th + dt * 2 * np.pi * 0.05
        z[t] = [r * np.cos(th), r * np.sin(th)]
    return _plant(z, rng)


def _lin_plant(src, rng, tau):
    T, fs = src["Y"].shape[0], src["fs"]
    dt = 1.0 / fs
    K = np.array([1.0 / tau[0], (0.0 if not np.isfinite(tau[1]) else 1.0 / tau[1])])
    z = np.zeros((T, 2))
    sq = np.sqrt(dt) * 0.5
    for t in range(1, T):
        z[t] = z[t - 1] - dt * K * z[t - 1] + sq * rng.standard_normal(2)
    return _plant(z, rng)


def gen_point(src, rng):
    return _lin_plant(src, rng, (10.0, 40.0))


def gen_line(src, rng):
    return _lin_plant(src, rng, (8.0, np.inf))


# ----------------------------- 运行 ----------------------------- #
def run_cond(name, gen, srcs, rng):
    rec = []
    for variant in VARIANTS:
        for d in DIMS:
            rows = []
            for i in range(N_SIM):
                src = srcs[i % len(srcs)]
                try:
                    st = AC.analyze_Y(gen(src, rng), src["fs"], variant=variant, d=d)
                except Exception as e:
                    print(f"    !! {name} {variant} d={d} 失败: {e}")
                    continue
                rows.append(st)
            if not rows:
                continue
            n = len(rows)
            bas = np.array([r["basin"] if np.isfinite(r["basin"]) else 0.0 for r in rows])
            dv = np.array([r["div"] / r["speed_median"] if np.isfinite(r["div"]) else 0.0
                           for r in rows])
            rad = np.array([r["radial_median"] / r["speed_median"]
                            if np.isfinite(r["radial_median"]) else 0.0 for r in rows])
            nst = np.array([r["n_stable"] for r in rows])
            evr = np.array([r["evr_sum"] for r in rows])
            rec.append(dict(cond=name, variant=variant, d=d, n=n,
                            stable_frac=float(np.mean(nst > 0)),
                            basin_med=float(np.median(bas)),
                            basin_lo=float(np.percentile(bas, 5)),
                            basin_hi=float(np.percentile(bas, 95)),
                            div_med=float(np.median(dv)),
                            rad_med=float(np.median(rad)),
                            evr_med=float(np.median(evr))))
            print(f"  {name:<7s} {variant} d={d}  n={n:2d}  "
                  f"稳定点{np.mean(nst>0)*100:5.1f}%  "
                  f"basin={np.median(bas):.2f} [{np.percentile(bas,5):.2f},{np.percentile(bas,95):.2f}]  "
                  f"div/v={np.median(dv):+.3f}  rad/v={np.median(rad):+.3f}  evr={np.median(evr):.2f}")
    return rec


def main():
    t0 = time.time()
    print("=== 载入真实会话（提供漂移与残差） ===")
    srcs = load_real_sources(2)
    rng = np.random.default_rng(11)

    rec = []
    for name, gen in [("N-A1", gen_null_common), ("N-A2", gen_null_rank3),
                      ("N-C", gen_null_ring), ("P-C", gen_point), ("P-L", gen_line)]:
        print(f"\n=== {name} ===")
        rec += run_cond(name, gen, srcs, rng)

    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(rec, indent=2, ensure_ascii=False))
    print(f"\n用时 {time.time()-t0:.0f}s\n写出 {OUT}")


if __name__ == "__main__":
    main()

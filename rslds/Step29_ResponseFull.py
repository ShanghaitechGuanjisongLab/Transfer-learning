"""Step29_ResponseFull.py —— 完整诱发响应时间进程（−0.5 → 20 s，全细胞空间）

动机
  Step28 发现群体平均诱发响应在 4.5 s 内**单调上升、不回落**，且已排除"下一个 cue 渗入"
  （trial 间隔中位 33.7 s，5% 分位 26.4 s）。
  这直接影响两件事：
    ① T3 的"峰值后 2.5 s 回落相"假设是否成立
    ② τ1 ≈ 9–20 s 的慢模态是否**就是** trial 诱发响应本身的衰减（而非独立慢流形）

方法
  全细胞空间（基无关）：d_c(τ)=Z_{c+τ} − Z_{c−0.5}，R(τ)=median_c d_c(τ)，A(τ)=‖R(τ)‖
  伪 cue 对照（随机时刻）给出"典型 20 s 漂移幅度"作参照
"""
from __future__ import annotations

import json
import os

import numpy as np

import attractor_core as AC
from rslds_data import load_block, scan_cohort

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "results", "_step29_response_full.json")
PHASES = ["Learned", "Transfer", "Final"]
MIN_CELL = 40
BASE_S = -0.5
STEP = 0.25
TAUS = np.arange(BASE_S, 20.0 + 1e-9, STEP)
N_PSEUDO = 40


def prof(Z, centers, fs):
    rows = []
    for c in centers:
        a = int(c) + int(round(BASE_S * fs))
        b = int(c) + int(round(TAUS[-1] * fs))
        if a < 0 or b > len(Z):
            continue
        base = Z[a]
        seg = np.empty((len(TAUS), Z.shape[1]))
        for k, tau in enumerate(TAUS):
            seg[k] = Z[int(c) + int(round(tau * fs))]
        rows.append(seg - base)
    if len(rows) < 10:
        return None
    return np.linalg.norm(np.median(np.stack(rows), axis=0), axis=1)


def main():
    ms = scan_cohort("ALB", phases=PHASES)
    A, P = [], []
    rng = np.random.default_rng(0)
    for b in ms:
        d = load_block(b["path"])
        fs = d["fs"]
        Y0 = np.nan_to_num(AC.dff(d["X"], fs), nan=0.0, posinf=0.0, neginf=0.0)
        ok = np.std(Y0, axis=0) > 1e-9
        if int(ok.sum()) < MIN_CELL:
            continue
        cue = np.sort(np.asarray(d.get("idx_cue", []), dtype=np.int64))
        if len(cue) < 10:
            continue
        Z = AC.zscore_robust(AC.VARIANTS["P1"](Y0[:, ok], fs))
        sc = max(np.median(np.linalg.norm(Z, axis=1)), 1e-12)
        a = prof(Z, cue, fs)
        if a is None:
            continue
        A.append(a / sc)
        lo, hi = int(round(1.0 * fs)), len(Z) - int(round(TAUS[-1] * fs)) - 1
        if hi > lo:
            pc = [int(rng.integers(lo, hi)) for _ in range(N_PSEUDO)]
            p = prof(Z, pc, fs)
            if p is not None:
                P.append(p / sc)
        print(f"  {b['mouse']:<9s}{b['phase']:<9s}")

    if not A:
        print("无数据")
        return
    Am = np.median(np.stack(A), axis=0)
    Pm = np.median(np.stack(P), axis=0) if P else np.full_like(Am, np.nan)
    ip = int(np.argmax(np.where(TAUS >= 0, Am, -np.inf)))
    peak = float(Am[ip])
    res = dict(t_peak=float(TAUS[ip]), peak=peak, n_session=len(A))

    print(f"\n=== 全细胞空间诱发响应（{len(A)} session 中位）===")
    print(f"峰值潜伏期 = {TAUS[ip]:.2f} s")
    print(f"\n{'τ(s)':>7s}{'A':>9s}{'/峰':>8s}{'伪A':>9s}")
    for tau in (0, 0.5, 1, 1.5, 2, 2.5, 3, 4, 5, 6, 7, 8, 10, 12, 15, 18):
        j = int(np.argmin(np.abs(TAUS - tau)))
        print(f"{TAUS[j]:7.2f}{Am[j]:9.4f}{Am[j]/max(peak,1e-12):8.3f}{Pm[j]:9.4f}")
        res[f"A_at_{TAUS[j]:.2f}"] = float(Am[j])

    print()
    for frac in (0.75, 0.50, 0.25, 0.10):
        below = np.where(Am[ip:] <= frac * peak)[0]
        tt = float(TAUS[ip + below[0]]) if len(below) else np.nan
        print(f"从峰值回落到 {int(frac*100):2d}%：τ = {tt:.2f} s")
        res[f"back_to_{int(frac*100)}_tau"] = tt
        res[f"back_to_{int(frac*100)}_frompeak"] = (tt - TAUS[ip]) if np.isfinite(tt) else np.nan

    # 半衰时间（从峰值起）
    half = res.get("back_to_50_frompeak", np.nan)
    print(f"\n峰值潜伏期 {TAUS[ip]:.2f} s + 半衰 {half} s = "
          f"{TAUS[ip] + (half if np.isfinite(half) else 0):.2f} s 回到半幅")
    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(res, indent=2, ensure_ascii=False, default=float))
    print(f"写出 {OUT}")


if __name__ == "__main__":
    main()

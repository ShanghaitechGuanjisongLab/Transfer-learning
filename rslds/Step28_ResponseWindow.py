"""Step28_ResponseWindow.py —— 用数据核定 T3 的"回落相"窗口长度（v2）

v1 的错误
  v1 用 r(t)=‖X_{c+t} − x0‖，x0 是全局 cue 前中位状态。结果峰值潜伏期 3.75 s、
  振幅/基线 只有 1.54 —— 说明这个量被**慢漂移**主导：x0 固定而 X 随录制缓慢漂移，
  范数单调增长，把真正的诱发放应淹没了。

v2 的做法（消除漂移）
  逐 trial 用局部基线：d_c(τ) = X_{c+τ} − X_{c−0.5}
  在 trial 间取中位：R(τ) = median_c d_c(τ)（诱发响应在 τ 上对齐 ⇒ 保留；
  噪声与逐 trial 抖动 ⇒ 抵消）
  A(τ) = ‖R(τ)‖
  残余漂移检验：用随机时刻当伪 cue 做同样平均 ⇒ A_pseudo(τ)。
  若 A(峰)/A_pseudo(峰) 接近 1，说明看到的不是诱发响应。

输出
  ① 峰值潜伏期（cue 后）
  ② 从峰值起衰减到 75/50/25/10% 所需时间
  ③ 各候选窗口的"有效帧比例"（A 超过 25%/50% 峰）
"""
from __future__ import annotations

import json
import os

import numpy as np

import attractor_core as AC
import Step10_TICA as T
from rslds_data import load_block, scan_cohort

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "results", "_step28_response_window.json")
PHASES = ["Learned", "Transfer", "Final"]
KPC = 10
MIN_CELL = 40
BASE_S = -0.5
STEP = 0.125
TAUS = np.arange(BASE_S, 4.5 + 1e-9, STEP)
N_PSEUDO = 40


def profile(X, cue, fs, rng=None, n_pseudo=0):
    rows = []
    centers = list(cue) if rng is None else [
        int(rng.integers(int(round(1.0 * fs)), len(X) - int(round(TAUS[-1] * fs)) - 1))
        for _ in range(n_pseudo)]
    for c in centers:
        a = int(c) + int(round(BASE_S * fs))
        b = int(c) + int(round(TAUS[-1] * fs))
        if a < 0 or b > len(X):
            continue
        base = X[a]
        seg = np.empty((len(TAUS), X.shape[1]))
        for k, tau in enumerate(TAUS):
            seg[k] = X[int(c) + int(round(tau * fs))]
        rows.append(seg - base)
    if len(rows) < 10:
        return None, 0
    return np.median(np.stack(rows), axis=0), len(rows)


def profile_cell(Z, cue, fs):
    """全细胞空间（基无关）的 cue 锁时平均响应范数。"""
    rows = []
    for c in cue:
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
    R = np.median(np.stack(rows), axis=0)          # (nTau, nCell)
    return np.linalg.norm(R, axis=1)


def main():
    ms = scan_cohort("ALB", phases=PHASES)
    A_all, Ap_all, C_all = [], [], []
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
        X, _, _, _ = T.pcs(Z, KPC)
        X = X / max(np.median(np.linalg.norm(X, axis=1)), 1e-12)

        R, n = profile(X, cue, fs)
        if R is None:
            continue
        Rp, _ = profile(X, None, fs, np.random.default_rng(0), N_PSEUDO)
        A_all.append(np.linalg.norm(R, axis=1))
        if Rp is not None:
            Ap_all.append(np.linalg.norm(Rp, axis=1))
        Ac = profile_cell(Z, cue, fs)
        if Ac is not None:
            C_all.append(Ac / max(np.median(np.linalg.norm(Z, axis=1)), 1e-12))
        print(f"  {b['mouse']:<9s}{b['phase']:<9s} nTrial={n} fs={fs:.3f}")

    if not A_all:
        print("无数据")
        return
    A = np.median(np.stack(A_all), axis=0)
    Ap = np.median(np.stack(Ap_all), axis=0) if Ap_all else np.full_like(A, np.nan)
    ip = int(np.argmax(np.where(TAUS >= 0, A, -np.inf)))
    t_peak = float(TAUS[ip])
    peak = float(A[ip])
    res = dict(t_peak=t_peak, peak=peak, n_session=len(A_all),
               pseudo_at_peak=float(Ap[ip]) if np.isfinite(Ap[ip]) else None)

    print(f"\n=== 群体平均诱发响应进程（{len(A_all)} session 中位）===")
    print(f"峰值潜伏期 = {t_peak:.2f} s（cue 后）；峰值 ‖R‖ = {peak:.4f}")
    if np.isfinite(Ap[ip]):
        print(f"伪 cue 在 τ=峰 处 ‖R_pseudo‖ = {Ap[ip]:.4f}  "
              f"（峰/伪 = {peak/max(Ap[ip],1e-12):.2f}×）")
    print(f"\n{'τ(s)':>7s}{'‖R‖_PC10':>10s}{'/峰':>8s}{'伪‖R‖':>9s}{'‖R‖_全细胞':>12s}{'/峰':>8s}")
    C = np.median(np.stack(C_all), axis=0) if C_all else np.full_like(A, np.nan)
    ipC = int(np.argmax(np.where(TAUS >= 0, C, -np.inf)))
    peakC = float(C[ipC])
    for tau in (-0.375, 0.0, 0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0):
        j = int(np.argmin(np.abs(TAUS - tau)))
        print(f"{TAUS[j]:7.3f}{A[j]:10.4f}{A[j]/max(peak,1e-12):8.3f}{Ap[j]:9.4f}"
              f"{C[j]:12.4f}{C[j]/max(peakC,1e-12):8.3f}")
        res[f"A_at_{TAUS[j]:.3f}"] = float(A[j])
        res[f"C_at_{TAUS[j]:.3f}"] = float(C[j])
    print(f"\n全细胞空间峰值潜伏期 = {TAUS[ipC]:.2f} s")
    res["t_peak_cell"] = float(TAUS[ipC])

    print()
    for frac in (0.75, 0.50, 0.25, 0.10):
        below = np.where(A[ip:] <= frac * peak)[0]
        dt = float(below[0]) * STEP if len(below) else np.nan
        print(f"从峰值衰减到 {int(frac*100):2d}%：{dt:.2f} s")
        res[f"decay_to_{int(frac*100)}"] = dt

    print(f"\n{'窗口(s)':>8s}{'帧数':>6s}{'>25%峰':>9s}{'>50%峰':>9s}")
    for L in (1.0, 1.5, 2.0, 2.5, 3.0, 4.0):
        j1 = int(np.argmin(np.abs(TAUS - (t_peak + L))))
        w = A[ip:j1 + 1]
        if len(w) == 0:
            continue
        f25 = float(np.mean(w > 0.25 * peak))
        f50 = float(np.mean(w > 0.50 * peak))
        print(f"{L:8.1f}{len(w):6d}{f25:9.2f}{f50:9.2f}")
        res[f"frac25_{L}s"] = f25
        res[f"frac50_{L}s"] = f50

    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(res, indent=2, ensure_ascii=False, default=float))
    print(f"\n写出 {OUT}")


if __name__ == "__main__":
    main()

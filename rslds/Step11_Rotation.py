"""Step11_Rotation.py —— 检验「环吸引子 / 极限环」：TICA 复特征值

为什么需要
  Step10 只用了 |λ|，丢掉了相位。旋转型动力学在 TICA 里表现为**一对复共轭特征值**
  （|λ|≈1，θ≠0）。只看 |λ| 会把旋转误读成"很长的 τ"，甚至当成数值病态——
  Step10 里那两个 τ~1e12 s 的 session 正是可疑对象。

判据
  λ = |λ| e^{iθ}
   · |Im λ| / |λ| ≈ 0  → 无旋转
   · |Im λ| / |λ| 显著 > 0，且 A/B 两半相位一致 → 存在旋转（环）
   · 周期 T = 2π·(lag/fs)/θ

必查混淆
  若 T 接近 trial 周期（~30 s）或舔水周期（~0.15 s），则可能是行为节律而非网络动力学。
"""
from __future__ import annotations

import json
import os
import time

import numpy as np
from scipy.linalg import eig as geig

import attractor_core as AC
import Step10_TICA as T
from rslds_data import load_block, scan_cohort

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "results", "_step11_rotation.json")

LAG = 16
N_PERM = 20
PHASES = ["Learned", "Transfer", "Final"]


def eig_complex(X, segs, lag, fs, ridge=1e-8):
    C0, Ct = T.covs(X, segs, lag)
    if C0 is None:
        return None
    C0 = 0.5 * (C0 + C0.T)
    Ct = 0.5 * (Ct + Ct.T)
    C0 = C0 + ridge * (np.trace(C0) / len(C0)) * np.eye(len(C0))
    w, v = geig(Ct, C0)
    o = np.argsort(-np.abs(w))
    return w[o], v[:, o]


def rot_stats(w, lag, fs):
    """返回最大 |λ| 特征值的模/相位/周期，以及「前 5 个中最强的旋转」。"""
    mag = np.abs(w)
    ang = np.angle(w)
    i1 = int(np.argmax(mag))
    theta1 = float(ang[i1])
    T1 = (2 * np.pi * lag / fs / abs(theta1)) if abs(theta1) > 1e-6 else np.inf
    # 前 5 个中，虚部最强的（排除 θ≈0 与 θ≈π）
    best = 0.0
    bT = np.inf
    for k in range(min(5, len(w))):
        if mag[k] < 0.3:
            continue
        a = abs(ang[k])
        if 0.1 < a < np.pi - 0.1:
            if abs(np.imag(w[k])) > best:
                best = float(abs(np.imag(w[k])))
                bT = float(2 * np.pi * lag / fs / a)
    return dict(mag1=float(mag[i1]), theta1=theta1, period1=float(T1),
                rot_str=best, rot_period=float(bT),
                rot_ratio=float(best / max(mag[i1], 1e-12)))


def main():
    t0 = time.time()
    ms = scan_cohort("ALB", phases=PHASES)
    ms.sort(key=lambda b: (b["mouse"], PHASES.index(b["phase"])))
    rows = []

    print(f"{'鼠':<9s}{'阶段':<8s}{'|λ1|':>7s}{'|Im/λ1|':>9s}{'θ1(rad)':>9s}"
          f"{'T1(s)':>8s}{'旋转周期':>9s}{'零模型|Im|中位':>13s}{'trial周期':>9s}")
    for b in ms:
        d = load_block(b["path"])
        fs = d["fs"]
        Y = np.nan_to_num(AC.dff(d["X"], fs), nan=0.0, posinf=0.0, neginf=0.0)
        Y = Y[:, np.std(Y, axis=0) > 1e-9]
        Z = AC.zscore_robust(AC.VARIANTS["P1"](Y, fs))

        cue = np.sort(d.get("idx_cue", []))
        if len(cue) < 10:
            continue
        trials = [(int(c), int(cue[i + 1]) if i + 1 < len(cue) else len(Z))
                  for i, c in enumerate(cue)]
        trials = [(s, e) for s, e in trials if e - s > int(2 * fs)]
        rng = np.random.default_rng(0)
        segA, segB = T.split_trials(Z, trials, rng)
        X, _, _, _ = T.pcs(Z)

        eA = eig_complex(X, segA, LAG, fs)
        eB = eig_complex(X, segB, LAG, fs)
        if eA is None or eB is None:
            continue
        wA, _ = eA
        sA = rot_stats(wA, LAG, fs)
        sB = rot_stats(eB[0], LAG, fs)

        # 相位一致性：两半最强旋转的周期是否接近
        if np.isfinite(sA["rot_period"]) and np.isfinite(sB["rot_period"]):
            phase_consist = float(min(sA["rot_period"], sB["rot_period"])
                                  / max(sA["rot_period"], sB["rot_period"]))
        else:
            phase_consist = np.nan

        null_rot = []
        for _ in range(N_PERM):
            Zn = T.phase_rand(Z, rng)
            Xn, _, _, _ = T.pcs(Zn)
            en = eig_complex(Xn, segA, LAG, fs)
            if en is not None:
                null_rot.append(rot_stats(en[0], LAG, fs)["rot_str"])
        null_med = float(np.median(null_rot)) if null_rot else np.nan

        trial_period = float(np.median(np.diff(cue)) / fs) if len(cue) > 2 else np.nan

        rows.append(dict(mouse=b["mouse"], phase=b["phase"], mag1=sA["mag1"],
                         theta1=sA["theta1"], period1=sA["period1"],
                         rot_str=sA["rot_str"], rot_period=sA["rot_period"],
                         rot_ratio=sA["rot_ratio"], phase_consist=phase_consist,
                         null_rot_med=null_med, trial_period=trial_period,
                         rot_str_B=sB["rot_str"]))
        print(f"{b['mouse']:<9s}{b['phase']:<8s}{sA['mag1']:7.3f}{sA['rot_ratio']:9.3f}"
              f"{sA['theta1']:9.3f}{min(sA['period1'],9999):8.1f}{sA['rot_period']:9.1f}"
              f"{null_med:13.3f}{trial_period:9.1f}")

    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(rows, indent=2, ensure_ascii=False))

    if rows:
        rr = np.array([x["rot_ratio"] for x in rows])
        nn = np.array([x["null_rot_med"] for x in rows])
        print(f"\n=== 汇总（{len(rows)} session）===")
        print(f"旋转强度 |Im λ1|/|λ1|：中位 {np.median(rr):.3f}（{rr.min():.3f}–{rr.max():.3f}）")
        print(f"超过自身零模型中位的：{int((rr > nn).sum())}/{len(rr)}")
        strong = [(x['mouse'], x['phase'], round(x['rot_period'], 1))
                  for x in rows if x['rot_ratio'] > 0.3]
        print(f"|Im λ1|/|λ1| > 0.3 的 session：{len(strong)} 个 {strong}")
    print(f"\n用时 {(time.time()-t0)/60:.1f} min；写出 {OUT}")


if __name__ == "__main__":
    main()

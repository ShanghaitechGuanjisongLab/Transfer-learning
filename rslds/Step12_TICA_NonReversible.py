"""Step12_TICA_NonReversible.py —— 修正版：**不对 C(τ) 对称化**

修正的 bug（2026-10-23）
  Step10/Step11 里写了 `Ct = 0.5*(Ct+Ct.T)`。$C(\tau)$ 对称 + $C(0)$ 对称正定
  ⇒ 广义特征值必为实数 ⇒ **旋转在数学上被消灭**，θ≡0 是构造出来的，不是测出来的。
  旋转信息恰好全在 $C(\tau)$ 的**反对称部分**。

本脚本同时给出两个侧面（同一份 $C(\tau)$）

  ① 非可逆性（不需要特征分解，最稳）
        ρ_rot = ‖C(τ) − C(τ)ᵀ‖_F / ‖C(τ) + C(τ)ᵀ‖_F
     细致平衡成立 ⇒ 0；存在环流 ⇒ > 0

  ② 谱（$C(\tau)$ 保持不对称）
        C(τ)v = λ C(0)v  →  复特征值 |λ|、θ、周期 T = 2π·(lag/fs)/θ
        τ_i = −(lag/fs)/ln|λ_i|

零模型：逐细胞相位随机化（破坏跨细胞相位关系 ⇒ ρ_rot 应接近 0）
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
OUT = os.path.join(HERE, "results", "_step12_nonrev.json")

LAG = 16
N_PERM = 20
PHASES = ["Learned", "Transfer", "Final"]


def cov_pair(X, segs, lag):
    C0, Ct = T.covs(X, segs, lag)      # 注意：covs 里不做对称化
    return C0, Ct


def rho_rot(Ct):
    S = 0.5 * (Ct + Ct.T)
    A = 0.5 * (Ct - Ct.T)
    return float(np.linalg.norm(A, "fro") / max(np.linalg.norm(S, "fro"), 1e-12))


def spec(C0, Ct, lag, fs, ridge=1e-8):
    C0 = 0.5 * (C0 + C0.T)             # C0 本就对称，这一步无害
    C0 = C0 + ridge * (np.trace(C0) / len(C0)) * np.eye(len(C0))
    w, _ = geig(Ct, C0)                # ← Ct **不对称**
    o = np.argsort(-np.abs(w))
    w = w[o]
    mag = np.clip(np.abs(w), 1e-12, 1 - 1e-12)
    tau = -(lag / fs) / np.log(mag)
    return w, mag, tau


def main():
    t0 = time.time()
    ms = scan_cohort("ALB", phases=PHASES)
    ms.sort(key=lambda b: (b["mouse"], PHASES.index(b["phase"])))
    rows = []

    print(f"{'鼠':<9s}{'阶段':<8s}{'τ1':>7s}{'τ2':>7s}{'τ1/τ2':>6s}"
          f"{'ρ_rot':>7s}{'零模型ρ':>8s}{'p':>6s}{'|Im/λ|':>8s}{'旋转T':>8s}{'A/B ρ':>7s}")
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

        C0a, Cta = cov_pair(X, segA, LAG)
        C0b, Ctb = cov_pair(X, segB, LAG)
        if C0a is None or C0b is None:
            continue
        w, mag, tau = spec(C0a, Cta, LAG, fs)
        _, _, tauB = spec(C0b, Ctb, LAG, fs)
        r_a, r_b = rho_rot(Cta), rho_rot(Ctb)

        # 旋转：前 5 个里 |Im|/|λ| 最大者
        best, bT = 0.0, np.inf
        for k in range(min(5, len(w))):
            ratio = abs(np.imag(w[k])) / max(abs(w[k]), 1e-12)
            if ratio > best:
                best = ratio
                th = abs(np.angle(w[k]))
                bT = 2 * np.pi * LAG / fs / th if th > 1e-6 else np.inf

        # 零模型
        null_r = []
        for _ in range(N_PERM):
            Zn = T.phase_rand(Z, rng)
            Xn, _, _, _ = T.pcs(Zn)
            c0, ct = cov_pair(Xn, segA, LAG)
            if c0 is not None:
                null_r.append(rho_rot(ct))
        null_med = float(np.median(null_r)) if null_r else np.nan
        p = ((1 + sum(v >= r_a for v in null_r)) / (len(null_r) + 1)) if null_r else np.nan

        ratio_tau = float(tau[0] / tau[1]) if len(tau) > 1 else np.nan
        rows.append(dict(mouse=b["mouse"], phase=b["phase"],
                         tau1=float(tau[0]), tau2=float(tau[1]), tau_ratio=ratio_tau,
                         rho_rot=r_a, rho_rot_B=r_b, null_rho_med=null_med, p=p,
                         im_ratio=float(best), rot_period=float(bT),
                         tau_ratio_B=float(tauB[0] / tauB[1]) if len(tauB) > 1 else np.nan))
        print(f"{b['mouse']:<9s}{b['phase']:<8s}{tau[0]:7.1f}{tau[1]:7.1f}{ratio_tau:6.2f}"
              f"{r_a:7.3f}{null_med:8.3f}{p:6.3f}{best:8.3f}{min(bT,9999):8.1f}{r_b:7.3f}")

    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(rows, indent=2, ensure_ascii=False))

    if rows:
        rr = np.array([x["rho_rot"] for x in rows])
        nn = np.array([x["null_rho_med"] for x in rows])
        pp = np.array([x["p"] for x in rows])
        tr = np.array([x["tau_ratio"] for x in rows])
        print(f"\n=== 汇总（{len(rows)} session）===")
        print(f"ρ_rot：中位 {np.median(rr):.3f}（{rr.min():.3f}–{rr.max():.3f}）；"
              f"零模型中位 {np.median(nn):.3f}")
        print(f"ρ_rot 超过自身零模型 95% 的：{int((pp < 0.05).sum())}/{len(pp)}")
        print(f"τ1/τ2（不对称）：中位 {np.median(tr):.2f}（{np.nanmin(tr):.2f}–{np.nanmax(tr):.2f}）；"
              f"≥5 的 {int((tr >= 5).sum())} 个")
        ir = np.array([x["im_ratio"] for x in rows])
        print(f"|Im λ|/|λ| 最大者：中位 {np.median(ir):.3f}（{ir.min():.3f}–{ir.max():.3f}）")
    print(f"\n用时 {(time.time()-t0)/60:.1f} min；写出 {OUT}")


if __name__ == "__main__":
    main()

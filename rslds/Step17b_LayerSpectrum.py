"""Step17b_LayerSpectrum.py —— 分层且**用可靠口径**重算 τ 谱与 Q

为什么需要
  Step16 里的 Q 来自 VAR(1) **lag=1** 的转移矩阵特征值。这个口径在本项目已被判定不可靠：
  |λ|≈0.99 时误差在变量（error-in-variables）衰减会把 Q 抬高，Step13 用 lag=16 得到
  Q 中位 0.27，而 lag=1 得到 ~1.0。**分层结论里的 Q（0.83 vs 0.35）必须用 lag=16 重算。**

口径（与 Step12/Step13 一致）
  · lag = 16（TICA 时间尺度）
  · 解广义特征问题 geig(Ct, C0)，**Ct 不对称**（不对称化会抹掉 |Im λ|）
  · Q = |Im w| / |ln|w||，取前 5 个特征值中该比值最大者
  · 奇偶分半用新鲜 seed 0

输出 results/_step17b_layer_spectrum.json
"""
from __future__ import annotations

import json
import os
import time

import numpy as np

import attractor_core as AC
import Step10_TICA as T
import Step12_TICA_NonReversible as S12
from rslds_data import load_block, scan_cohort

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "results", "_step17b_layer_spectrum.json")

PHASES = ["Learned", "Transfer", "Final"]
LAG = 16
KPC = 10
MIN_CELL = 40
GROUPS = [("pooled", None), ("MOp2/3", 1), ("MOp5", 2)]


def spectrum(Y, fs, cue, kpc):
    Z = AC.zscore_robust(AC.VARIANTS["P1"](Y, fs))
    X, _, _, _ = T.pcs(Z, kpc)

    trials = [(int(cue[i]), int(cue[i + 1]) if i + 1 < len(cue) else len(Z))
              for i in range(len(cue))]
    trials = [(s, e) for s, e in trials if e - s > int(2 * fs)]
    segA, segB = T.split_trials(Z, trials, np.random.default_rng(0))

    C0a, Cta = S12.cov_pair(X, segA, LAG)
    C0b, Ctb = S12.cov_pair(X, segB, LAG)
    if C0a is None:
        return None
    w, mag, tau = S12.spec(C0a, Cta, LAG, fs)
    tauB = S12.spec(C0b, Ctb, LAG, fs)[2] if C0b is not None else np.full(2, np.nan)

    # Q 与旋转周期：前 5 个特征值里 |Im|/|λ| 最大者
    best, period = 0.0, np.inf
    for k in range(min(5, len(w))):
        ratio = abs(np.imag(w[k])) / max(abs(w[k]), 1e-12)
        if ratio > best:
            best = ratio
            th = abs(np.angle(w[k]))
            period = 2 * np.pi * LAG / fs / th if th > 1e-6 else np.inf
    # 同一特征值的能量衰减率 ⇒ Q
    kbest = int(np.argmax([abs(np.imag(w[k])) / max(abs(w[k]), 1e-12)
                           for k in range(min(5, len(w)))]))
    Q = float(abs(np.imag(w[kbest])) / max(abs(np.log(abs(w[kbest]))), 1e-12))

    return dict(tau1=float(tau[0]), tau2=float(tau[1]),
                tau_ratio=float(tau[0] / tau[1]) if len(tau) > 1 else np.nan,
                tau_ratio_B=float(tauB[0] / tauB[1]) if len(tauB) > 1 else np.nan,
                im_ratio=float(best), Q_lag16=Q,
                rot_period=float(period) if np.isfinite(period) else np.nan,
                n_dim=int(X.shape[1]))


def main():
    t0 = time.time()
    ms = scan_cohort("ALB", phases=PHASES)
    ms.sort(key=lambda b: (b["mouse"], PHASES.index(b["phase"])))
    rows = []
    print(f"{'鼠':<9s}{'阶段':<9s}{'组':<8s}{'nCell':>6s}{'τ1':>8s}{'τ2':>8s}"
          f"{'τ1/τ2':>7s}{'|Im/λ|':>8s}{'Q(lag16)':>9s}")
    for b in ms:
        d = load_block(b["path"])
        fs = d["fs"]
        Y0 = np.nan_to_num(AC.dff(d["X"], fs), nan=0.0, posinf=0.0, neginf=0.0)
        ok = np.std(Y0, axis=0) > 1e-9
        zl = np.asarray(d.get("z_layer", np.zeros(Y0.shape[1], dtype=np.int64)))
        if zl.size != Y0.shape[1]:
            zl = np.zeros(Y0.shape[1], dtype=np.int64)
        cue = np.sort(np.asarray(d.get("idx_cue", []), dtype=np.int64))
        if len(cue) < 10:
            continue
        for name, code in GROUPS:
            sel = ok if code is None else (ok & (zl == code))
            n_cell = int(sel.sum())
            if n_cell < MIN_CELL:
                continue
            r = spectrum(Y0[:, sel], fs, cue, min(KPC, n_cell - 2))
            if r is None:
                continue
            rows.append(dict(mouse=b["mouse"], phase=b["phase"], group=name,
                             n_cell=n_cell, **r))
            print(f"{b['mouse']:<9s}{b['phase']:<9s}{name:<8s}{n_cell:6d}"
                  f"{r['tau1']:8.1f}{r['tau2']:8.1f}{r['tau_ratio']:7.2f}"
                  f"{r['im_ratio']:8.3f}{r['Q_lag16']:9.2f}")

    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(rows, indent=2, ensure_ascii=False))

    print(f"\n=== 分层 τ 谱 / Q（lag=16 可靠口径，{len(rows)} 行）===")
    print(f"{'组':<9s}{'n':>4s}{'τ1 中位':>9s}{'τ1/τ2':>8s}{'Q 中位':>8s}"
          f"{'Q>0.5':>8s}{'Q>1':>6s}")
    for name, _ in GROUPS:
        g = [x for x in rows if x["group"] == name]
        if not g:
            continue
        Q = np.array([x["Q_lag16"] for x in g])
        print(f"{name:<9s}{len(g):4d}{np.median([x['tau1'] for x in g]):9.1f}"
              f"{np.median([x['tau_ratio'] for x in g]):8.2f}{np.median(Q):8.2f}"
              f"{int((Q > 0.5).sum()):5d}/{len(g)}{int((Q > 1).sum()):4d}/{len(g)}")
    print(f"\n用时 {(time.time()-t0)/60:.1f} min；写出 {OUT}")


if __name__ == "__main__":
    main()

"""Step30_PerTrialKinetics.py —— 单 trial 动力学：是"持续响应"还是"抖动瞬变"？

为什么必须做
  Step29 发现群体平均响应在 τ=3.0 s 才到峰、半衰在峰后约 6 s。有两种可能：
    (a) 每个 trial 本身就是慢的持续响应（真持续）
    (b) 每个 trial 是短瞬变，但**峰潜伏期抖动**大 ⇒ 平均后被抹宽成慢上升
  区分方法：比较
    · ‖median_c d_c(τ)‖  （trial 间先平均再取范数 = Step29，抖动会抹宽）
    · median_c ‖d_c(τ)‖  （先取范数再平均 = 单 trial 幅度，抖动不影响）
  若两者峰值潜伏期相近 ⇒ (a)；若后者明显更早 ⇒ (b)。

顺带检验 Step14 的 M1 统计量是否在测"衰减"
  `trials_rho` 在 [0, 1.5] s 内找峰 ip，再取 ip+1 s 的**投影残留比例**
      R = (d[ip+1s] · u) / amp,   u = d[ip]/amp
  若全局峰实际在 3 s，则在 [0,1.5] 内找到的"峰"只是**上升沿上的一点**，
  ip+1 s 处响应更大 ⇒ R > 1 ⇒ 它测的是**上升**，不是残留/衰减。
  本脚本直接报告 R 的分布。
"""
from __future__ import annotations

import json
import os

import numpy as np

import attractor_core as AC
from rslds_data import load_block, scan_cohort

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "results", "_step30_pertrial.json")
PHASES = ["Learned", "Transfer", "Final"]
MIN_CELL = 40
BASE_S, STEP, T_MAX = -0.5, 0.25, 12.0
TAUS = np.arange(BASE_S, T_MAX + 1e-9, STEP)
PEAK_WIN = (0.0, 1.5)      # 与 Step14 一致
LAG1S = 1.0


def main():
    ms = scan_cohort("ALB", phases=PHASES)
    agg_norm_of_med, agg_med_of_norm, peak_lat, Rvals = [], [], [], []
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

        D = []
        for c in cue:
            a = int(c) + int(round(BASE_S * fs))
            bb = int(c) + int(round(T_MAX * fs))
            if a < 0 or bb > len(Z):
                continue
            base = Z[a]
            seg = np.empty((len(TAUS), Z.shape[1]))
            for k, tau in enumerate(TAUS):
                seg[k] = Z[int(c) + int(round(tau * fs))]
            D.append(seg - base)
        if len(D) < 10:
            continue
        D = np.stack(D)                                    # (nTrial, nTau, nCell)
        nrm = np.linalg.norm(D, axis=2) / sc               # (nTrial, nTau)
        agg_norm_of_med.append(np.linalg.norm(np.median(D, axis=0), axis=1) / sc)
        agg_med_of_norm.append(np.median(nrm, axis=0))

        i0, i1 = int(round(PEAK_WIN[0] / STEP)), int(round(PEAK_WIN[1] / STEP))
        lag = int(round(LAG1S / STEP))
        for k in range(len(D)):
            m = nrm[k]
            ip = int(np.argmax(m[i0:i1])) + i0
            amp = float(m[ip])
            if amp <= 0 or ip + lag >= len(m):
                continue
            u = D[k, ip] / max(np.linalg.norm(D[k, ip]), 1e-12)
            Rvals.append(float((D[k, ip + lag] @ u) / max(np.linalg.norm(D[k, ip]), 1e-12)))
            peak_lat.append(float(TAUS[int(np.argmax(m))]))
        print(f"  {b['mouse']:<9s}{b['phase']:<9s} nTrial={len(D)}")

    Nm = np.median(np.stack(agg_norm_of_med), axis=0)
    Mn = np.median(np.stack(agg_med_of_norm), axis=0)
    lat = np.array(peak_lat)
    R = np.array(Rvals)
    tA, tB = float(TAUS[int(np.argmax(Nm))]), float(TAUS[int(np.argmax(Mn))])

    print(f"\n=== 峰值潜伏期（{len(agg_norm_of_med)} session）===")
    print(f"‖median_c d‖ 峰（先平均再取范数，抖动会抹宽）: {tA:.2f} s")
    print(f"median_c ‖d‖ 峰（单 trial 幅度）          : {tB:.2f} s")
    print(f"单 trial 全程峰潜伏期中位 = {np.median(lat):.2f} s"
          f"（25–75%: {np.percentile(lat,25):.2f}–{np.percentile(lat,75):.2f} s）")

    print(f"\n{'τ(s)':>7s}{'‖med d‖':>10s}{'med‖d‖':>10s}")
    for tau in (0, 0.5, 1, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10, 12):
        j = int(np.argmin(np.abs(TAUS - tau)))
        print(f"{TAUS[j]:7.2f}{Nm[j]/Nm.max():10.3f}{Mn[j]/Mn.max():10.3f}")

    print(f"\n=== Step14 的 R =(ip+1s 投影)/amp（ip 在 [0,1.5] s 内）===")
    print(f"n={len(R)}  trial；中位 {np.median(R):.3f}；"
          f"R>1 占 {100*np.mean(R>1):.1f}%；"
          f"5–95% = {np.percentile(R,5):.3f}–{np.percentile(R,95):.3f}")
    print("判读：R 中位 ≈1 或 >1 ⇒ 该统计量测的是**上升**而非衰减/残留。")

    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(dict(
            t_peak_norm_of_med=tA, t_peak_med_of_norm=tB,
            peak_lat_median=float(np.median(lat)),
            peak_lat_iqr=[float(np.percentile(lat, 25)), float(np.percentile(lat, 75))],
            R_median=float(np.median(R)), R_frac_gt1=float(np.mean(R > 1)),
            R_p5=float(np.percentile(R, 5)), R_p95=float(np.percentile(R, 95)),
            n_trial=int(len(R))), indent=2, ensure_ascii=False))
    print(f"写出 {OUT}")


if __name__ == "__main__":
    main()

"""CheckExcursion.py —— 少数状态的偏移到底走了到「另一个定点」距离的几成？

C 格的诊断：分段线性的速度场按构造就是一个椭圆碗，画出来没有信息。
真正有信息的是**偏移的幅度相对于两定点间距**：

  · 少数状态的驻留中位 $n$ 帧、$\rho_{\rm mnr}$ ⇒ 一阶近似只走了
    $1-\rho_{\rm mnr}^{\,n}$ 的分数（线性动力把点拉向自己的定点）
  · 实测：把 $x$ 对齐到舔水起始，投影到 (e1, e2)，看均值轨迹的最大偏移 / 两定点间距

用法：  .venv\\Scripts\\python rslds\\CheckExcursion.py [--mice yqn1130 vtf0354]
"""

from __future__ import annotations

import argparse
import os
import sys

import numpy as np

import rslds_data as rd
from RunRSLDS2 import BOX_SEC
from CheckMinorityState import runs_of, lick_onsets, WIN

HERE = os.path.dirname(os.path.abspath(__file__))
FIGDIR = os.path.join(HERE, "results", "fig1")


def fixed_points(As, bs):
    D = As.shape[1]
    out = np.full((As.shape[0], D), np.nan)
    for k in range(As.shape[0]):
        M = np.eye(D) - As[k]
        if abs(np.linalg.det(M)) > 1e-10:
            out[k] = np.linalg.solve(M, bs[k])
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mice", nargs="+", default=None)
    ap.add_argument("--rho", type=float, default=0.99)
    a = ap.parse_args()

    blocks = [b for b in rd.scan_cohort("ALB", phases=["Transfer"])
              if b["design"] == "LightWater"]
    if a.mice:
        blocks = [b for b in blocks if b["mouse"] in a.mice]

    print("=== 偏移幅度 vs 两定点间距 ===", flush=True)
    print("%-9s %6s %6s %7s %7s %8s %9s %9s %9s"
          % ("鼠", "占率m", "ρ_m", "ρ_M", "驻留帧", "线性可及", "实测偏移σ",
             "间距σ", "实测/间距"), flush=True)
    for b in blocks:
        f = os.path.join(FIGDIR, "stable_%s_K2_rho%.3f.npz" % (b["mouse"], a.rho))
        if not os.path.exists(f):
            continue
        z = np.load(f)
        x, lab, As, bs, fs = z["x"], z["z"].astype(int), z["As"], z["bs"], z["fs"]
        occ = np.array([(lab == k).mean() for k in range(2)])
        maj = int(np.argmax(occ))
        mnr = 1 - maj
        fp = fixed_points(As, bs)
        rM = float(np.max(np.abs(np.linalg.eigvals(As[maj]))))
        rm = float(np.max(np.abs(np.linalg.eigvals(As[mnr]))))
        st, ln = runs_of(lab == mnr)
        dwell = float(np.median(ln)) if ln.size else np.nan

        if np.all(np.isfinite(fp)):
            gap = float(np.linalg.norm(fp[mnr] - fp[maj]))
            e1 = (fp[mnr] - fp[maj]) / gap
        else:
            gap = np.nan
            e1 = np.linalg.svd(x - x.mean(0), full_matrices=False)[2][0]
        reach = 1 - rm ** max(dwell, 0) if np.isfinite(dwell) else np.nan

        # 舔水起始对齐的均值轨迹
        d = rd.load_block(b["path"])
        ev = lick_onsets(d["cd2"], fs)
        offs = np.arange(int(round(WIN[0] * fs)), int(round(WIN[1] * fs)) + 1)
        good = ev[(ev + offs[0] >= 0) & (ev + offs[-1] < x.shape[0])]
        X = np.stack([x[e + offs] for e in good]) - fp[maj]          # n_ev×n_off×5
        m = X.mean(axis=0)
        dev = np.linalg.norm(m - m[0], axis=1)
        amp = float(dev.max())
        base_sd = float(np.linalg.norm(X.std(axis=0)[0]))
        print("%-9s %6.2f %6.3f %7.3f %7.1f %8.0f%% %9.2f %9.2f %9.0f%%   (基线抖动 %.2f)"
              % (b["mouse"], occ[mnr], rm, rM, dwell, 100 * reach, amp, gap,
                 100 * amp / gap if np.isfinite(gap) and gap > 0 else np.nan, base_sd),
              flush=True)
    print("\n线性可及 = 1-ρ_m^驻留帧（状态 m 的动力学在驻留期内把点拉向自己定点的比例）")
    print("DONE", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())

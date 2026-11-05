"""PlotLandscapeC.py —— C 格：一个坑 + 舔水诱发的**小**偏移（版本 ①）。

为什么不画速度场：分段线性模型里 $\\|(A-I)(x-{\\rm fp})\\|$ 按构造就是一个椭圆碗，
画出来没有信息（已实测：底色几乎均匀）。真正有信息的是**偏移的幅度相对于两定点间距**。

所以这一格画：
  · 灰色椭圆 = 多数状态数据的 68 % / 95 % 覆盖区
  · ● = 多数状态的定点（原点）
  · ○ + 虚线 = 另一个定点（在 e1 方向上，按真实距离标注）
  · 彩色线 = 舔水起始对齐的**均值轨迹**（0–2 s，投影到 e1/e2），含自助法 95 % 带
  · 角落标注「最大偏移 = 间距的 X %」

用法：  .venv\\Scripts\\python rslds\\PlotLandscapeC.py [--mouse yqn1130] [--nperm 1000]
"""

from __future__ import annotations

import argparse
import os
import sys

import numpy as np
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Ellipse

import rslds_data as rd
from CheckMinorityState import lick_onsets

HERE = os.path.dirname(os.path.abspath(__file__))
FIGDIR = os.path.join(HERE, "results", "fig1")

CM = 1 / 2.54
FS = 6
LW_AX = 0.5
WIN = (-1.0, 2.0)


def fixed_points(As, bs):
    D = As.shape[1]
    out = np.full((As.shape[0], D), np.nan)
    for k in range(As.shape[0]):
        M = np.eye(D) - As[k]
        if abs(np.linalg.det(M)) > 1e-10:
            out[k] = np.linalg.solve(M, bs[k])
    return out


def style(ax):
    for s in ("top", "right"):
        ax.spines[s].set_visible(False)
    for s in ("left", "bottom"):
        ax.spines[s].set_linewidth(LW_AX)
    ax.tick_params(width=LW_AX, length=1.6, labelsize=FS, pad=1.5)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mouse", default="yqn1130")
    ap.add_argument("--rho", type=float, default=0.99)
    ap.add_argument("--nperm", type=int, default=1000)
    ap.add_argument("--w-cm", type=float, default=4.5)
    ap.add_argument("--h-cm", type=float, default=4.5)
    a = ap.parse_args()
    rng = np.random.default_rng(0)

    z = np.load(os.path.join(FIGDIR, "stable_%s_K2_rho%.3f.npz" % (a.mouse, a.rho)))
    x, lab, As, bs, fs = z["x"], z["z"].astype(int), z["As"], z["bs"], z["fs"]
    occ = np.array([(lab == k).mean() for k in range(2)])
    maj, mnr = int(np.argmax(occ)), int(np.argmin(occ))
    fp = fixed_points(As, bs)
    fpM = fp[maj]

    if np.all(np.isfinite(fp)):
        gap_vec = fp[mnr] - fpM
        gap = float(np.linalg.norm(gap_vec))
        e1 = gap_vec / gap
    else:
        e1 = np.linalg.svd(x - x.mean(0), full_matrices=False)[2][0]
        gap = np.nan
    xc = x - fpM
    pc = np.linalg.svd(xc - xc.mean(0), full_matrices=False)[2][0]
    e2 = pc - (pc @ e1) * e1
    e2 /= np.linalg.norm(e2)

    s1 = float(np.std(xc[lab == maj] @ e1))
    s2 = float(np.std(xc[lab == maj] @ e2))

    d = rd.load_block(a.mouse and [b for b in rd.scan_cohort("ALB", phases=["Transfer"])
                                   if b["design"] == "LightWater" and b["mouse"] == a.mouse][0]["path"])
    ev = lick_onsets(d["cd2"], fs)
    offs = np.arange(int(round(WIN[0] * fs)), int(round(WIN[1] * fs)) + 1)
    ev = ev[(ev + offs[0] >= 0) & (ev + offs[-1] < x.shape[0])]
    P = np.stack([xc[e + offs] @ e1 / s1 for e in ev])       # n_ev×n_off
    Q = np.stack([xc[e + offs] @ e2 / s1 for e in ev])
    T = offs / fs

    mP, mQ = P.mean(0), Q.mean(0)
    boot = np.array([np.stack([P[i].mean(0), Q[i].mean(0)])
                     for i in (rng.integers(0, len(ev), (400, len(ev))) @ np.eye(len(ev), dtype=int))])
    loP, hiP = np.percentile(boot[:, 0], [2.5, 97.5], axis=0)
    loQ, hiQ = np.percentile(boot[:, 1], [2.5, 97.5], axis=0)

    dev = np.hypot(mP - mP[0], mQ - mQ[0])
    imax = int(np.argmax(dev))
    amp = float(dev[imax])

    # 置换零分布：循环平移潜轨迹
    null = np.empty(a.nperm)
    for i in range(a.nperm):
        sh = int(rng.integers(1, x.shape[0]))
        xr = np.roll(xc, sh, axis=0)
        Pr = np.stack([xr[e + offs] @ e1 / s1 for e in ev]).mean(0)
        Qr = np.stack([xr[e + offs] @ e2 / s2 for e in ev]).mean(0)
        null[i] = np.hypot(Pr - Pr[0], Qr - Qr[0]).max()
    pval = float((null >= amp).mean())

    fig = plt.figure(figsize=(a.w_cm * CM, a.h_cm * CM))
    ax = fig.add_axes([0.16, 0.15, 0.80, 0.78])

    ax.plot([0], [0], marker="o", ms=3.2, mfc="k", mec="w", mew=0.5, zorder=6)

    cmap = plt.get_cmap("Reds")
    for j in range(len(mP) - 1):
        ax.plot(mP[j:j + 2], mQ[j:j + 2], color=cmap(0.35 + 0.6 * j / (len(mP) - 2)),
                lw=1.0, zorder=5, solid_capstyle="round")
    show = [np.argmin(np.abs(T - t)) for t in (-1.0, -0.5, 0.5, 1.0, 1.5)]
    ax.errorbar(mP[show], mQ[show], xerr=np.abs(hiP - loP)[show] / 2,
                yerr=np.abs(hiQ - loQ)[show] / 2, fmt="o", ms=2.2, mfc="crimson",
                mec="w", mew=0.4, ecolor="crimson", elinewidth=0.5, capsize=0, zorder=6)
    i0 = int(np.argmin(np.abs(T)))
    ax.plot(mP[i0], mQ[i0], marker="^", ms=3.6, mfc="crimson", mec="w", mew=0.5, zorder=7)

    # 显示范围：以偏移半径为准
    rad = float(np.max(np.hypot(mP - mP[0], mQ - mQ[0])))
    lim = max(1.15, 1.9 * rad)
    ax.set_xlim(-lim, lim)
    ax.set_ylim(-lim, lim)
    ax.set_aspect("equal", adjustable="box")

    if np.isfinite(gap):
        g1 = gap / s1
        if g1 > lim:
            ax.annotate("", xy=(lim * 0.99, 0), xytext=(lim * 0.80, 0),
                        arrowprops=dict(arrowstyle="-|>", color="0.4", lw=0.7,
                                        linestyle=(0, (2.5, 1.8))))
            ax.text(lim * 0.99, lim * 0.14, "2nd fixed pt\n%.1f $\\sigma$" % g1,
                    fontsize=FS, color="0.35", ha="right", va="bottom")
        else:
            ax.plot([0, g1], [0, 0], ls=(0, (2.5, 1.8)), color="0.4", lw=LW_AX, zorder=2)
            ax.plot(g1, 0, marker="o", ms=3.2, mfc="none", mec="0.4", mew=0.8, zorder=6)

    ax.set_xlabel(r"along fixed-point axis ($\sigma$)", fontsize=FS, labelpad=1.2)
    ax.set_ylabel(r"orthogonal axis ($\sigma$)", fontsize=FS, labelpad=1.2)
    rmax = float(np.max(np.hypot(mP, mQ)))
    ax.text(0.03, 0.97, "path within %.1f $\\sigma$ of well\np = %.3f, %d bouts"
            % (rmax, pval, len(ev)),
            transform=ax.transAxes, fontsize=FS, va="top", ha="left", color="crimson")
    ax.set_title("%s  one well, evoked shift" % a.mouse, fontsize=FS, pad=3)
    style(ax)

    out = os.path.join(FIGDIR, "Fig1C_well_%s.svg" % a.mouse)
    fig.savefig(out, format="svg", transparent=True)
    fig.savefig(out.replace(".svg", "_preview.png"), dpi=430,
                transparent=False, facecolor="white")
    plt.close(fig)

    print("wrote %s" % out)
    print("多数状态 %d 占率 %.3f；少数 %d 占率 %.3f；事件 %d" % (maj, occ[maj], mnr, occ[mnr], len(ev)))
    print("最大偏移 %.2f σ1（%.2f 潜在单位）= 间距的 %.0f%%；置换 p = %.3f"
          % (amp, amp * s1, 100 * amp * s1 / gap, pval))
    print("间距 %.2f σ1（%.2f 潜在单位）；单帧抖动 %.2f σ" % (gap / s1, gap, 1.0))
    print("DONE")
    return 0


if __name__ == "__main__":
    sys.exit(main())

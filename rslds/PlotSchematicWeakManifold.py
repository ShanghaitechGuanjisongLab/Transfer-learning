"""PlotSchematicWeakManifold.py —— 「弱回复慢流形 + 舔水触发偏转」的三格汇总图。

**不手绘**：三格都由实测量构成，每格讲一句、且每个数可追溯到某个 json/npz。

  (a) 回复很慢，而且 τ 是被我们自己钉住的
      每根柱 = 一只鼠**多数状态**的 τ（取自 ρ≤0.99 的稳定拟合）。
      两条虚线：1 s（GCaMP 时间常数，说明确实很慢）、12.4 s（ρ_max=0.99 对应的上限，
      说明"τ 是设的，不是测的"）。
  (b) 偏移只走到另一定点的几成
      每根柱 = 舔水对齐的均值轨迹峰值 / 两定点间距。100 % 参照线 = "真的走过去"。
  (c) 「第二个体制」只是一条 0.5 s 的窄带
      少数状态占用率对齐舔水起始（11 只鼠均值 ± SEM，20 Hz 公共网格）。

用法：  .venv\\Scripts\\python rslds\\PlotSchematicWeakManifold.py
"""

from __future__ import annotations

import argparse
import os
import sys

import numpy as np
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from scipy.signal import resample

import rslds_data as rd
from CheckMinorityState import lick_onsets, runs_of

HERE = os.path.dirname(os.path.abspath(__file__))
FIGDIR = os.path.join(HERE, "results", "fig1")
CM = 1 / 2.54
FS = 6
LW_AX = 0.5
WIN = (-1.0, 2.0)
N_COMMON = 81
T_COMMON = np.linspace(WIN[0], WIN[1], N_COMMON)
RHO = 0.99
N_NULL = 200


def style(ax):
    for s in ("top", "right"):
        ax.spines[s].set_visible(False)
    for s in ("left", "bottom"):
        ax.spines[s].set_linewidth(LW_AX)
    ax.tick_params(width=LW_AX, length=1.6, labelsize=FS, pad=1.5)


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
    ap.add_argument("--w-cm", type=float, default=9.0)
    ap.add_argument("--h-cm", type=float, default=4.0)
    a = ap.parse_args()

    blocks = [b for b in rd.scan_cohort("ALB", phases=["Transfer"])
              if b["design"] == "LightWater"]

    taus, excs, psths = [], [], []
    caps = []
    rng = np.random.default_rng(0)
    for b in blocks:
        f = os.path.join(FIGDIR, "stable_%s_K2_rho%.3f.npz" % (b["mouse"], RHO))
        if not os.path.exists(f):
            continue
        z = np.load(f)
        x, As, bs, lab = z["x"], z["As"], z["bs"], z["z"].astype(int)
        fs = float(z["fs"])
        occ = np.array([(lab == k).mean() for k in range(2)])
        maj, mnr = int(np.argmax(occ)), int(np.argmin(occ))
        rho_maj = float(np.max(np.abs(np.linalg.eigvals(As[maj]))))
        if not (0 < rho_maj < 1):
            continue
        taus.append(-1.0 / (fs * np.log(rho_maj)))
        caps.append(-1.0 / (fs * np.log(RHO)))

        # (b) 偏移 / 状态云半径（**不涉及 (I-A)^-1**）
        fp = fixed_points(As, bs)
        d = rd.load_block(b["path"])
        ev = lick_onsets(d["cd2"], fs)
        offs = np.arange(int(round(WIN[0] * fs)), int(round(WIN[1] * fs)) + 1)
        ev = ev[(ev + offs[0] >= 0) & (ev + offs[-1] < x.shape[0])]
        if ev.size >= 20:
            Xm = x[lab == maj]
            cloud = float(np.sqrt(np.trace(np.cov(Xm.T))))
            step = float(np.median(np.linalg.norm(np.diff(Xm, axis=0), axis=1)))
            Xs = x[ev[:, None] + offs[None, :]]
            m = Xs.mean(axis=0)
            exc = float(np.linalg.norm(m - m[0], axis=1).max())
            # 零分布：循环平移舔水起始时刻（落在多数状态）
            T = x.shape[0]
            nullv = []
            for _ in range(N_NULL):
                sh = (ev + int(rng.integers(1, T))) % T
                sh = np.sort(sh[(sh + offs[0] >= 0) & (sh + offs[-1] < T)])
                if sh.size < 20:
                    continue
                mn = x[sh[:, None] + offs[None, :]].mean(axis=0)
                nullv.append(float(np.linalg.norm(mn - mn[0], axis=1).max()))
            nullv = np.asarray(nullv)
            excs.append((b["mouse"], 100 * exc / cloud, exc, cloud, step,
                         100 * float(np.median(nullv)) / cloud,
                         float((nullv >= exc).mean())))

        # (c) 占用率 PSTH
        if ev.size >= 20:
            mm = (lab == mnr).astype(float)
            psths.append(resample(mm[ev[:, None] + offs[None, :]].mean(axis=0), N_COMMON))

    taus = np.array(taus)
    caps = np.array(caps)
    mice = [e[0] for e in excs]
    excv = np.array([e[1] for e in excs])
    exca = np.array([e[2] for e in excs])
    cloud = np.array([e[3] for e in excs])
    step = np.array([e[4] for e in excs])
    nullv = np.array([e[5] for e in excs])
    pval = np.array([e[6] for e in excs])
    order = np.argsort(excv)
    PSTH = np.array(psths)

    fig = plt.figure(figsize=(a.w_cm * CM, a.h_cm * CM))

    # ---------- (a) τ ----------
    ax = fig.add_axes([0.075, 0.245, 0.225, 0.58])
    idx = np.arange(taus.size)
    ax.bar(idx, np.sort(taus), width=0.72, color="0.55", edgecolor="none")
    cap = float(np.median(caps))
    ax.axhline(1.0, color="0.4", lw=LW_AX, ls=(0, (2.5, 1.8)))
    ax.axhline(cap, color="crimson", lw=LW_AX, ls=(0, (2.5, 1.8)))
    ax.text(taus.size - 0.25, 1.0, "1 s", fontsize=FS, ha="left", va="center",
            color="0.4")
    ax.text(taus.size - 0.25, cap, r"$\rho$=%.2f" % RHO, fontsize=FS, ha="left",
            va="center", color="crimson")
    ax.set_xlim(-0.7, taus.size + 3.9)
    ax.set_ylim(0, 14)
    ax.set_xticks([])
    ax.set_xlabel("mouse (sorted)", fontsize=FS, labelpad=1.2)
    ax.set_ylabel(r"$\tau$ of majority state (s)", fontsize=FS, labelpad=1.2)
    ax.set_title("slow restoring,\nand $\\tau$ is capped", fontsize=FS, pad=2)
    style(ax)

    # ---------- (b) 偏移 / 间距 ----------
    ax = fig.add_axes([0.405, 0.245, 0.215, 0.58])
    xx = np.arange(excv.size)
    ax.bar(xx, excv[order], width=0.74, color="crimson", edgecolor="none", alpha=0.85,
           label="lick-aligned")
    ax.hlines(nullv[order], xx - 0.37, xx + 0.37, color="0.15", lw=1.0,
              label="time-shifted null")
    ax.axhline(100, color="0.35", lw=LW_AX, ls=(0, (2.5, 1.8)))
    ax.text(excv.size - 0.25, 100, "cloud\nradius", fontsize=FS,
            ha="left", va="center", color="0.35")
    ax.set_xlim(-0.7, excv.size + 3.9)
    ax.set_ylim(0, 112)
    ax.set_xticks([])
    ax.set_xlabel("mouse (sorted)", fontsize=FS, labelpad=1.2)
    ax.set_ylabel("evoked shift / cloud radius (\%)", fontsize=FS, labelpad=1.2)
    ax.text(0.03, 0.97, "%d/%d mice\np < 0.05" % (int((pval < 0.05).sum()), pval.size),
            transform=ax.transAxes, fontsize=FS, va="top", ha="left")
    ax.set_title("the evoked shift is small\nbut above chance", fontsize=FS, pad=2)
    style(ax)

    # ---------- (c) PSTH ----------
    ax = fig.add_axes([0.735, 0.245, 0.245, 0.58])
    mu = PSTH.mean(axis=0) * 100
    se = PSTH.std(axis=0, ddof=1) / np.sqrt(PSTH.shape[0]) * 100
    ax.fill_between(T_COMMON, mu - se, mu + se, color="crimson", alpha=0.22, lw=0)
    ax.plot(T_COMMON, mu, color="crimson", lw=1.0)
    ax.axvline(0, color="0.4", lw=LW_AX, ls=(0, (2.5, 1.8)))
    base = float(mu[T_COMMON < 0].mean())
    ax.axhline(base, color="0.4", lw=LW_AX, ls=(0, (2.5, 1.8)))
    ax.set_xlim(T_COMMON[0], T_COMMON[-1])
    ax.set_ylim(0, max(mu + se) * 1.30)
    ax.set_xlabel("time from lick onset (s)", fontsize=FS, labelpad=1.2)
    ax.set_ylabel("P(minority state) (\%)", fontsize=FS, labelpad=1.2)
    ax.text(0.04, 0.97, "n = %d mice\npeak at %.2f s" % (PSTH.shape[0],
                                                          T_COMMON[int(np.argmax(mu))]),
            transform=ax.transAxes, fontsize=FS, va="top", ha="left")
    ax.set_title("the 2nd regime is\na brief band", fontsize=FS, pad=2)
    style(ax)

    out = os.path.join(FIGDIR, "FigSchematic_weak_manifold.svg")
    fig.savefig(out, format="svg", transparent=True)
    fig.savefig(out.replace(".svg", "_preview.png"), dpi=430,
                transparent=False, facecolor="white")
    plt.close(fig)

    print("wrote %s" % out)
    print("(a) τ：中位 %.1f s（%.1f–%.1f），n=%d；上限 12.4 s"
          % (np.median(taus), taus.min(), taus.max(), taus.size))
    print("(b) 偏移/云半径：观测中位 %.0f%%；零分布中位 %.0f%%；p<0.05 的 %d/%d"
          % (np.median(excv), np.median(nullv), int((pval < 0.05).sum()), pval.size))
    print("    偏移绝对 %.2f–%.2f，云半径中位 %.2f，单帧步长中位 %.2f"
          % (exca.min(), exca.max(), np.median(cloud), np.median(step)))
    print("(c) PSTH 基线 %.1f%%，峰值 %.1f%%（%.2f s），n=%d 只鼠"
          % (base, mu.max(), T_COMMON[int(np.argmax(mu))], PSTH.shape[0]))
    print("DONE")
    return 0


if __name__ == "__main__":
    sys.exit(main())

"""RunFig1.py —— 档 2：11 只鼠的景观切片（小多图）+ 每鼠 ΔK

图 1 的定义（笔记 D.5）：Naive vs Transfer 的**状态空间景观切片**——坑数/深度 + 轨迹方向箭头。

⚠ 这一版**不是**图 1 的成品，只做到档 2：
  · 只取每只鼠的 **Transfer**（首次学光-水）一个 block，**没有 Naive vs Transfer 对比**
  · 每块独立拟合 ⇒ 潜空间尺度与坐标系**各自独立**，所以只能画**独立坐标轴的小多图**，
    **绝不能**把 11 只鼠叠进一张坐标里
  · 跨块可比的只有**尺度不变量**：τ（A_k 特征值）、占用率、驻留、切换率、ΔK

景观按文献的**正确**定义（笔记 D.15 已核实）：**速度曲面** ‖(A_k−I)x+b_k‖，**不是**势能。
坑 = 各状态的定点 x_k* = (I−A_k)^{-1} b_k。

只做**去趋势口径**（A/B 控制已证明原始口径的"状态"是漂移被切段的伪影）。

用法：
    .venv\\Scripts\\python rslds\\RunFig1.py --list        只列出选中的 block
    .venv\\Scripts\\python rslds\\RunFig1.py --only 1      只跑第 1 只鼠（做图验证）
    .venv\\Scripts\\python rslds\\RunFig1.py               全跑 11 只
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time

import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

import ssm  # noqa: E402
import rslds_data as rd  # noqa: E402
from RunRSLDS2 import (N_OBS, D_LATENT, BOX_SEC, build_inputs, eig_report,
                       state_metrics, tau_from_eig, finite)  # noqa: E402

plt.rcParams["font.sans-serif"] = ["Microsoft YaHei", "SimHei", "DejaVu Sans"]
plt.rcParams["axes.unicode_minus"] = False

HERE = os.path.dirname(os.path.abspath(__file__))
OUTDIR = os.path.join(HERE, "results", "fig1")
K_LIST = [1, 2]
DETREND = "漂白去趋势"


# --------------------------------------------------------------------------- #
# 拟合
# --------------------------------------------------------------------------- #
def fit_one(Y, u, K, iters, seed):
    np.random.seed(seed)
    m = ssm.SLDS(N_OBS, K, D_LATENT, M=u.shape[1], transitions="recurrent",
                 dynamics="diagonal_gaussian", emissions="gaussian_orthog",
                 single_subspace=True)
    m.initialize(Y, inputs=u)
    t0 = time.time()
    elbos, q = m.fit(Y, inputs=u, method="laplace_em",
                     variational_posterior="structured_meanfield",
                     initialize=False, num_iters=iters, alpha=0.0, verbose=0)
    t_fit = time.time() - t0
    elbos = np.asarray(elbos, dtype=np.float64)
    x = np.asarray(q.mean_continuous_states[0], dtype=np.float64)
    Ez = np.asarray(q.mean_discrete_states[0], dtype=np.float64)
    z = np.asarray(m.most_likely_states(x, Y, input=u))
    return dict(m=m, elbos=elbos, x=x, z=z, Ez=Ez, t_fit=t_fit)


# --------------------------------------------------------------------------- #
# 景观
# --------------------------------------------------------------------------- #
def fixed_points(As, bs):
    D = As.shape[1]
    out = np.full((As.shape[0], D), np.nan)
    for k in range(As.shape[0]):
        M = np.eye(D) - As[k]
        if abs(np.linalg.det(M)) > 1e-8:
            out[k] = np.linalg.solve(M, bs[k])
    return out


def projection(x, fp, K):
    """投影到 2 维：轴1 = 两个定点连线（把两个"坑"摆在横轴上）；轴2 = 与轴1 正交、方差最大的方向。"""
    D = x.shape[1]
    C = np.cov(x.T)
    w, V = np.linalg.eigh(C)
    order = np.argsort(w)[::-1]
    if K >= 2 and np.all(np.isfinite(fp[:2])) and np.linalg.norm(fp[1] - fp[0]) > 1e-9:
        e1 = fp[1] - fp[0]
    else:
        e1 = V[:, order[0]]
    e1 = e1 / np.linalg.norm(e1)
    e2 = None
    for i in order:
        c = V[:, i] - (V[:, i] @ e1) * e1
        if np.linalg.norm(c) > 1e-6:
            e2 = c / np.linalg.norm(c)
            break
    if e2 is None:
        e2 = np.zeros(D); e2[1 % D] = 1.0
    return np.column_stack([e1, e2])


def draw_landscape(ax, res, K, fs, d, title, pre_sec=1.5, post_sec=3.0):
    """速度曲面 + 定点 + **cue 对齐的逐试次轨迹**（带箭头）。

    为什么要 cue 对齐、并且以**全体 cue 时刻的均值位置**为原点：
    原示意图的读法是"同一组起始状态下，轨迹是扇形分叉还是并入同一通道"。
    数据里对应的做法就是：把每个试次的潜轨迹按 cue 对齐、再整体平移，
    使各试次的起始点散布在原点附近（= "共同起始线"），于是扇形/平行一眼可辨。
    定点仍保持在各自的**真实相对位置**上。
    方向一致性用 Rayleigh R = |mean(单位位移向量)|，0=均匀，1=完全平行。
    """
    As, bs, x = res["m"].dynamics.As, res["m"].dynamics.bs, res["x"]
    fp = fixed_points(As, bs)
    P = projection(x, fp, K)
    xy = x @ P
    fp2 = fp @ P

    ev = np.asarray(d["idx_TrialStart"], dtype=int)
    ev = ev[(ev >= 0) & (ev < len(xy))]
    origin = xy[ev].mean(0) if ev.size else np.zeros(2)
    xy = xy - origin
    fp2 = fp2 - origin

    lo = np.percentile(xy, 0.5, axis=0)
    hi = np.percentile(xy, 99.5, axis=0)
    for q in (fp2,):
        m = np.all(np.isfinite(q), axis=1)
        if m.any():
            lo = np.minimum(lo, q[m].min(0))
            hi = np.maximum(hi, q[m].max(0))
    pad = 0.10 * (hi - lo + 1e-9)
    lo, hi = lo - pad, hi + pad
    gx = np.linspace(lo[0], hi[0], 61)
    gy = np.linspace(lo[1], hi[1], 61)
    GX, GY = np.meshgrid(gx, gy)
    G2 = np.column_stack([GX.ravel(), GY.ravel()])
    Gfull = G2 @ P.T
    eye = np.eye(D_LATENT)
    speed = np.stack([np.linalg.norm(Gfull @ (As[k] - eye).T + bs[k], axis=1) for k in range(K)])
    V = np.min(speed, axis=0).reshape(GX.shape)
    ax.contourf(GX, GY, V, levels=16, cmap="Greys", alpha=0.75)

    # ---- cue 对齐的逐试次轨迹 ----
    n_pre, n_post = int(round(pre_sec * fs)), int(round(post_sec * fs))
    segs, dirs = [], []
    for c in ev:
        if c - n_pre < 0 or c + n_post >= len(xy):
            continue
        s = xy[c - n_pre:c + n_post + 1]
        segs.append(s)
        dirs.append(s[-1] - s[n_pre])
    for s in segs:
        ax.plot(s[:, 0], s[:, 1], color="tab:blue", lw=0.6, alpha=0.45)
        a, b = s[n_pre], s[-1]
        if np.linalg.norm(b - a) > 1e-9:
            ax.annotate("", xy=b, xytext=a,
                        arrowprops=dict(arrowstyle="-|>", color="tab:blue", lw=0.9, alpha=0.8))
    R = np.nan
    if len(dirs) >= 3:
        U = np.asarray(dirs)
        n = np.linalg.norm(U, axis=1, keepdims=True)
        keep = (n.ravel() > 1e-9)
        if keep.sum() >= 3:
            R = float(np.linalg.norm((U[keep] / n[keep]).mean(0)))

    for k in range(K):
        if np.all(np.isfinite(fp2[k])):
            ax.plot(fp2[k, 0], fp2[k, 1], "o", ms=7, mfc="none", mec="tab:red", mew=1.5)
            ax.text(fp2[k, 0], fp2[k, 1], " k=%d" % k, fontsize=6, color="tab:red")
    ax.plot(0, 0, "+", color="k", ms=6, mew=1.0)
    ax.set_xlim(lo[0], hi[0]); ax.set_ylim(lo[1], hi[1])
    ax.set_title(title + "\nRayleigh R = %s（%d 试次）"
                 % ("nan" if not np.isfinite(R) else "%.2f" % R, len(dirs)), fontsize=7)
    ax.set_xlabel("潜维 1（定点连线方向）", fontsize=7)
    ax.set_ylabel("潜维 2", fontsize=7)
    ax.tick_params(labelsize=6)
    return R


# --------------------------------------------------------------------------- #
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--iters", type=int, default=300)
    ap.add_argument("--seed", type=int, default=0)
    ap.add_argument("--only", type=int, default=None, help="只跑前 N 只鼠")
    ap.add_argument("--list", action="store_true")
    a = ap.parse_args()
    os.makedirs(OUTDIR, exist_ok=True)

    blocks = rd.scan_cohort("ALB", phases=["Transfer"])
    blocks = [b for b in blocks if b["design"] == "LightWater"]
    if a.list:
        for i, b in enumerate(blocks):
            print("%2d  %-9s %-11s %-19s nCell=%3d  %5.1f min  %s"
                  % (i + 1, b["mouse"], b["phase"], b["datetime"], b["n_cell"],
                     b["dur_sec"] / 60, os.path.basename(b["path"])), flush=True)
        print("共 %d 个 Transfer block" % len(blocks), flush=True)
        return 0
    if a.only:
        blocks = blocks[:a.only]

    print("=== 档 2：景观切片（%d 只鼠 × K=%s × %s × %d 轮）==="
          % (len(blocks), K_LIST, DETREND, a.iters), flush=True)
    rows, res_all = [], {}
    for i, b in enumerate(blocks):
        d = rd.load_block(b["path"])
        assert rd.check_orientation(d)
        fs = d["fs"]
        u = build_inputs(d, fs)
        X = d["X"][:, d["cell_ok"] >= 1.0]
        Z = rd.zscore_cols(rd.detrend_bleach(X, fs))
        Y, fa = rd.factor_analysis(Z, N_OBS, seed=a.seed)
        row = dict(mouse=b["mouse"], datetime=b["datetime"], n_cell=int(X.shape[1]),
                   dur_min=d["dur_sec"] / 60, communality=float(np.mean(1 - fa.noise_variance_)))
        for K in K_LIST:
            t0 = time.time()
            r = fit_one(Y, u, K, a.iters, a.seed)
            tau = tau_from_eig(eig_report(r["m"].dynamics.As), fs)
            occ, nsw, segs = state_metrics(r["z"], K, fs)
            tn = np.sort(tau[np.isfinite(tau)])
            row["K%d" % K] = dict(
                elbo_per_pt=float(r["elbos"][-1]) / len(r["z"]),
                t_fit_sec=r["t_fit"],
                occupancy=[float(v) for v in occ],
                n_switch=nsw, switch_per_min=nsw / (len(r["z"]) / fs / 60),
                dwell_median_s=[float(np.median(v)) if v else np.nan for v in segs],
                tau_finite_s=[float(v) for v in tn],
                n_eig_ge1=int((eig_report(r["m"].dynamics.As) >= 1).sum()),
            )
            res_all[(b["mouse"], K)] = r
            r["d"] = d
            np.savez_compressed(
                os.path.join(OUTDIR, "fig1_%s_K%d.npz" % (b["mouse"], K)),
                x=r["x"], z=r["z"], Ez=r["Ez"], As=r["m"].dynamics.As, bs=r["m"].dynamics.bs,
                Rs=r["m"].transitions.Rs, Ws=r["m"].transitions.Ws,
                log_Ps=r["m"].transitions.log_Ps, elbos=r["elbos"], fs=fs,
                idxTrialStart=d["idx_TrialStart"], idxGiveWater=d["idx_GiveWater"],
                cd2=d["cd2"])
            print("  [%2d/%d] %-9s K=%d  ELBO/点 %8.3f  %.0f s  切换 %.1f/min  驻留中位 %s  τ %s"
                  % (i + 1, len(blocks), b["mouse"], K, row["K%d" % K]["elbo_per_pt"],
                     r["t_fit"], row["K%d" % K]["switch_per_min"],
                     round(float(np.nanmedian(row["K%d" % K]["dwell_median_s"])), 2),
                     [round(v, 1) for v in tn[:3]]), flush=True)
        row["dK"] = row["K2"]["elbo_per_pt"] - row["K1"]["elbo_per_pt"]
        rows.append(row)
        print("         ΔK = %+.3f   nCell=%d  共性=%.3f" % (row["dK"], row["n_cell"], row["communality"]),
              flush=True)

    with open(os.path.join(OUTDIR, "fig1_summary.json"), "w", encoding="utf-8") as fh:
        json.dump(finite(rows), fh, ensure_ascii=False, indent=1)
    print("\n指标已存：%s" % os.path.join(OUTDIR, "fig1_summary.json"), flush=True)

    make_figure(rows, res_all, blocks)
    # 再存一次：Rayleigh R 是在做图时算的
    with open(os.path.join(OUTDIR, "fig1_summary.json"), "w", encoding="utf-8") as fh:
        json.dump(finite(rows), fh, ensure_ascii=False, indent=1)
    print("DONE", flush=True)
    return 0


def make_figure(rows, res_all, blocks):
    n = len(rows)
    ncol = 4
    nrow = int(np.ceil((n + 1) / ncol))
    fig, axes = plt.subplots(nrow, ncol, figsize=(3.6 * ncol, 3.1 * nrow), squeeze=False)
    for i, row in enumerate(rows):
        ax = axes.ravel()[i]
        r = res_all.get((row["mouse"], 2))
        if r is None:
            ax.axis("off"); continue
        R = draw_landscape(ax, r, 2, r["d"]["fs"], r["d"],
                           "%s (n=%d)  ΔK=%+.2f  驻留 %.1fs"
                           % (row["mouse"], row["n_cell"], row["dK"],
                              float(np.nanmedian(row["K2"]["dwell_median_s"]))))
        row["rayleigh_R"] = R
    ax = axes.ravel()[n]
    names = [r["mouse"] for r in rows]
    dks = [r["dK"] for r in rows]
    ax.bar(range(n), dks, color="tab:blue")
    ax.axhline(0, color="k", lw=0.8)
    ax.axhline(0.448, color="tab:red", lw=1.0, ls="--")
    ax.text(0.02, 0.96, "红虚线 = 替代数据的上界\n（A/B 控制里 yqn0133 的交互项 +0.448）",
            transform=ax.transAxes, fontsize=6, va="top")
    ax.set_xticks(range(n)); ax.set_xticklabels(names, rotation=90, fontsize=6)
    ax.set_ylabel("ΔK = ELBO/点(K2) − (K1)", fontsize=7)
    ax.set_title("每只鼠「加状态」到底带来多少增益", fontsize=8)
    for j in range(n, nrow * ncol):
        axes.ravel()[j].axis("off")
    fig.suptitle("档 2：Transfer（首次学光-水）—— 速度景观切片（**各图坐标轴独立、不可叠加**）\n"
                 "背景 = ‖(A_k−I)x+b_k‖（越亮越快）；红圈 = 定点 x_k*；黑 + = 全体 cue 时刻的均值位置\n"
                 "蓝线 = cue 对齐的逐试次潜轨迹（起点散布在原点附近 = “共同起始线”），箭头为 +3 s 内的净位移方向",
                 fontsize=10)
    fig.tight_layout(rect=[0, 0, 1, 0.95])
    p = os.path.join(OUTDIR, "fig1_landscape_ALB_Transfer.png")
    fig.savefig(p, dpi=140)
    plt.close(fig)
    print("图：%s" % p, flush=True)


if __name__ == "__main__":
    sys.exit(main())

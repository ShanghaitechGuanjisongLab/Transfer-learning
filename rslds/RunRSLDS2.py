"""RunRSLDS2.py —— Stage 1 pilot 第二轮：修判据 + 查 τ 全 ∞

修两个问题（见笔记 (s) 的三个红旗）：
  ① PSP 判据换成**置换 null**。原来用固定阈值 `ptp > 0.05` 是错的 —— 30 次事件的
     纯噪声 PSP 其 ptp 期望就有 0.24~0.44，实测 12 个 ptp 全部 ≤ 噪声期望。
     现在用两种零假设，取更保守者：
       · 循环平移（shift predictor）：整体平移事件时刻一个随机量，**保留事件间隔结构**
       · 均匀随机：在 [0,T) 上随机撒同样多的事件时刻
     统计量仍用 ptp，p = (1 + #{null >= obs}) / (n_perm + 1)。
  ② 查 τ 谱为什么几乎全是 ∞（|λ|≥1，即潜动力学不收缩）：
     打出**拟合前/后**每个状态的完整 |λ| 谱与噪声方差，并把轮数从 150 提到 300
     看是否是没收敛。

另外把拟合出的量（Ez / z / As / 超参）存成 .npz —— 以后复查不必重跑。

用法：  .venv\\Scripts\\python rslds\\RunRSLDS2.py [--iters 300] [--K 2 3]
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

plt.rcParams["font.sans-serif"] = ["Microsoft YaHei", "SimHei", "DejaVu Sans"]
plt.rcParams["axes.unicode_minus"] = False

HERE = os.path.dirname(os.path.abspath(__file__))
OUTDIR = os.path.join(HERE, "results")
BLOCK = "ALB_yqn0133_20240517-0835_AudioWater.mat"
DETRENDS = ["原始", "漂白去趋势"]
N_OBS, D_LATENT = 15, 5      # ssm 要求 N > D
PSP_SEC, N_PERM = 3.0, 500
BOX_SEC = 1.0


# --------------------------------------------------------------------------- #
# 读数
# --------------------------------------------------------------------------- #
def psp_curve(Q, events, fs, win_sec):
    """事件锁定的状态概率曲线。Q: (T,K)。返回 (时间轴秒, (K,n))。"""
    n = int(round(win_sec * fs))
    offs = np.arange(-n, n + 1)
    ev = np.asarray(events, dtype=np.int64)
    if ev.size == 0:
        return offs / fs, np.zeros((Q.shape[1], offs.size))
    idx = ev[:, None] + offs[None, :]                      # (nEv, nOff)
    ok = (idx >= 0) & (idx < Q.shape[0])
    w = ok[:, :, None].astype(float)
    P = (Q[np.clip(idx, 0, Q.shape[0] - 1)] * w).sum(0) / np.maximum(w.sum(0), 1)
    return offs / fs, P.T


def psp_test(Ez, events, fs, win_sec, n_perm, rng):
    """置换 null：返回 (t, P, obs_ptp, p_shift, p_rand)。取两者更保守的 p。"""
    T, K = Ez.shape
    ev = np.asarray(events, dtype=np.int64)
    t, P = psp_curve(Ez, ev, fs, win_sec)
    obs = np.ptp(P, axis=1)
    null_s = np.zeros((n_perm, K))
    null_r = np.zeros((n_perm, K))
    for i in range(n_perm):
        s = int(rng.integers(0, T))
        null_s[i] = np.ptp(psp_curve(Ez, (ev + s) % T, fs, win_sec)[1], axis=1)
        null_r[i] = np.ptp(psp_curve(Ez, rng.integers(0, T, ev.size), fs, win_sec)[1], axis=1)
    p_s = (1 + (null_s >= obs).sum(0)) / (n_perm + 1)
    p_r = (1 + (null_r >= obs).sum(0)) / (n_perm + 1)
    return t, P, obs, p_s, p_r, np.percentile(null_s, 95, axis=0)


def eig_report(As):
    """每个状态的 |λ| 谱（降序）。"""
    K = As.shape[0]
    return np.array([np.sort(np.abs(np.linalg.eigvals(As[k])))[::-1] for k in range(K)])


def tau_from_eig(mag, fs):
    with np.errstate(divide="ignore", invalid="ignore"):
        return np.where(mag < 1.0, (1.0 / fs) / -np.log(np.maximum(mag, 1e-12)), np.inf)


def state_metrics(z, K, fs):
    occ = np.array([(z == k).mean() for k in range(K)])
    edges = np.concatenate(([0], np.where(np.diff(z) != 0)[0] + 1, [len(z)]))
    segs = [[] for _ in range(K)]
    for a, b in zip(edges[:-1], edges[1:]):
        segs[int(z[a])].append((b - a) / fs)
    return occ, int(np.sum(np.diff(z) != 0)), segs


def finite(x):
    if isinstance(x, (list, tuple)):
        return [finite(v) for v in x]
    if isinstance(x, dict):
        return {k: finite(v) for k, v in x.items()}
    if isinstance(x, (float, np.floating)):
        return float(x) if np.isfinite(x) else None
    if isinstance(x, (int, np.integer)):
        return int(x)
    return x


# --------------------------------------------------------------------------- #
def build_inputs(d, fs):
    T = d["X"].shape[0]
    u = np.zeros((T, 3))
    n_box = max(1, int(round(BOX_SEC * fs)))
    for col, key in [(0, "idx_TrialStart"), (2, "idx_GiveWater")]:
        for e in d[key]:
            e = int(e)
            if 0 <= e < T:
                u[e:min(T, e + n_box), col] = 1.0
    u[:, 1] = rd.smooth(rd.lick_indicator(d["cd2"]), n_box)
    return u


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--iters", type=int, default=300)
    ap.add_argument("--K", type=int, nargs="+", default=[2, 3])
    ap.add_argument("--seed", type=int, default=0)
    a = ap.parse_args()
    rng = np.random.default_rng(a.seed)

    os.makedirs(OUTDIR, exist_ok=True)
    d = rd.load_block(os.path.join(rd.DATA_ROOT, "ALB", BLOCK))
    assert rd.check_orientation(d)
    fs = d["fs"]
    u = build_inputs(d, fs)
    X = d["X"][:, d["cell_ok"] >= 1.0]

    print("=== pilot 第二轮：置换 null + τ 诊断 ===", flush=True)
    print("block %s / %s / %s ；T=%d ；fs=%.2f ；细胞 %d"
          % (d["mouse"], d["phase"], d["design"], X.shape[0], fs, X.shape[1]), flush=True)
    print("配置 K=%s × 去趋势=%s，各 %d 轮；置换 %d 次；事件 cue=%d 给水=%d\n"
          % (a.K, DETRENDS, a.iters, N_PERM,
             len(d["idx_TrialStart"]), len(d["idx_GiveWater"])), flush=True)

    rows = []
    for det in DETRENDS:
        Z = rd.zscore_cols(X if det == "原始" else rd.detrend_bleach(X, fs))
        Y, _ = rd.factor_analysis(Z, N_OBS, seed=a.seed)
        for K in a.K:
            np.random.seed(a.seed)
            m = ssm.SLDS(N_OBS, K, D_LATENT, M=u.shape[1],
                         transitions="recurrent", dynamics="diagonal_gaussian",
                         emissions="gaussian_orthog", single_subspace=True)
            t0 = time.time()
            m.initialize(Y, inputs=u)
            t_init = time.time() - t0
            mag_before = eig_report(m.dynamics.As)

            t0 = time.time()
            elbos, q = m.fit(Y, inputs=u, method="laplace_em",
                             variational_posterior="structured_meanfield",
                             initialize=False, num_iters=a.iters, alpha=0.0, verbose=0)
            t_fit = time.time() - t0
            elbos = np.asarray(elbos, dtype=np.float64)
            x_hat = q.mean_continuous_states[0]
            Ez = np.asarray(q.mean_discrete_states[0], dtype=np.float64)
            z = np.asarray(m.most_likely_states(x_hat, Y, input=u))

            mag_after = eig_report(m.dynamics.As)
            tau_after = tau_from_eig(mag_after, fs)
            occ, nsw, segs = state_metrics(z, K, fs)

            t_cue, P_cue, obs_cue, p_s, p_r, q95_s = psp_test(
                Ez, d["idx_TrialStart"], fs, PSP_SEC, N_PERM, rng)
            _, P_rew, obs_rew, p_s_r, p_r_r, q95_r = psp_test(
                Ez, d["idx_GiveWater"], fs, PSP_SEC, N_PERM, rng)

            np.savez_compressed(
                os.path.join(OUTDIR, "pilot2_%s_K%d.npz" % (det.replace("去趋势", ""), K)),
                Ez=Ez, z=z, As=m.dynamics.As, bs=m.dynamics.bs,
                sigmasq=m.dynamics.sigmasq, Rs=m.transitions.Rs, Ws=m.transitions.Ws,
                log_Ps=m.transitions.log_Ps, elbos=elbos, fs=fs,
                t_cue=t_cue, P_cue=P_cue, t_rew=t_cue, P_rew=P_rew)

            print("── %s K=%d ──  init %.1f s + fit %.1f s（%.2f s/轮）"
                  % (det, K, t_init, t_fit, t_fit / elbos.size), flush=True)
            print("   ELBO 轨迹（每 %d 轮）：%s" % (max(1, a.iters // 10),
                  np.round(elbos[::max(1, a.iters // 10)], 0).tolist()), flush=True)
            nt = int(min(20, max(1, elbos.size - 1)))   # 窗口随实际轮数收缩（干跑 --iters 3）
            print("   末 %d 轮相对变化 %.2e" % (nt, float(np.nanmax(np.abs(
                elbos[-nt:] - elbos[-nt - 1:-1]) / np.maximum(np.abs(elbos[-nt - 1:-1]), 1e-9)))), flush=True)
            print("   |λ| 拟合前 %s" % np.round(mag_before, 3).tolist(), flush=True)
            print("   |λ| 拟合后 %s   （≥1 的个数：前 %d / 后 %d）"
                  % (np.round(mag_after, 3).tolist(),
                     int((mag_before >= 1).sum()), int((mag_after >= 1).sum())), flush=True)
            print("   τ(s) = %s ；σ² = %s"
                  % (np.round(tau_after, 1).tolist(), np.round(m.dynamics.sigmasq, 3).tolist()),
                  flush=True)
            print("   占用率 %s ；切换 %d（%.1f/min）；驻留中位 %s s"
                  % (np.round(occ, 3).tolist(), nsw, nsw / (len(z) / fs / 60),
                     [round(float(np.median(s)), 2) if s else None for s in segs]), flush=True)
            print("   cue  PSP ptp %s  vs null95 %s  →  p = %s"
                  % (np.round(obs_cue, 3).tolist(), np.round(q95_s, 3).tolist(),
                     np.round(np.maximum(p_s, p_r), 3).tolist()), flush=True)
            print("   给水 PSP ptp %s  vs null95 %s  →  p = %s\n"
                  % (np.round(obs_rew, 3).tolist(), np.round(q95_r, 3).tolist(),
                     np.round(np.maximum(p_s_r, p_r_r), 3).tolist()), flush=True)

            rows.append(dict(
                detrend=det, K=K, iters=a.iters, t_init_sec=t_init, t_fit_sec=t_fit,
                elbo_trace=elbos[::max(1, a.iters // 10)].tolist(),
                elbo_final=float(elbos[-1]), elbo_per_pt=float(elbos[-1]) / len(z),
                mag_before=mag_before.tolist(), mag_after=mag_after.tolist(),
                n_eig_ge1_before=int((mag_before >= 1).sum()),
                n_eig_ge1_after=int((mag_after >= 1).sum()),
                tau_after=tau_after.tolist(), sigmasq=m.dynamics.sigmasq.tolist(),
                occupancy=[float(v) for v in occ], n_switch=nsw,
                switch_per_min=nsw / (len(z) / fs / 60),
                dwell_median_s=[float(np.median(s)) if s else np.nan for s in segs],
                psp_cue_ptp=[float(v) for v in obs_cue],
                psp_cue_p_shift=[float(v) for v in p_s], psp_cue_p_rand=[float(v) for v in p_r],
                psp_rew_ptp=[float(v) for v in obs_rew],
                psp_rew_p_shift=[float(v) for v in p_s_r], psp_rew_p_rand=[float(v) for v in p_r_r],
                psp_cue_null95=[float(v) for v in q95_s],
                W_norm=float(np.linalg.norm(m.transitions.Ws)),
                R_norm=float(np.linalg.norm(m.transitions.Rs)),
                F_norm=float(np.linalg.norm(np.asarray(m.emissions.Fs).reshape(-1))),
            ))

    with open(os.path.join(OUTDIR, "pilot2_summary.json"), "w", encoding="utf-8") as fh:
        json.dump(finite(rows), fh, ensure_ascii=False, indent=1)
    print("指标已存：%s" % os.path.join(OUTDIR, "pilot2_summary.json"), flush=True)

    # ---- 汇总判读 ----
    print("\n=== 置换 null 后的对齐结论 ===", flush=True)
    any_sig = False
    for r in rows:
        pc = min(min(r["psp_cue_p_shift"]), min(r["psp_cue_p_rand"]))
        pr = min(min(r["psp_rew_p_shift"]), min(r["psp_rew_p_rand"]))
        sig = min(pc, pr) < 0.05
        any_sig |= sig
        print("  %-12s K=%d  最小 p（cue）=%.3f  最小 p（给水）=%.3f  %s"
              % (r["detrend"], r["K"], pc, pr, "← 显著" if sig else ""), flush=True)
    print("⇒ %s" % ("有状态与事件显著锁相" if any_sig
                    else "**没有任何状态与 cue/给水显著锁相**（全部 p>0.05）"), flush=True)

    print("\n=== τ 诊断结论 ===", flush=True)
    for r in rows:
        print("  %-12s K=%d  |λ|≥1：拟合前 %d 个 / 拟合后 %d 个"
              % (r["detrend"], r["K"], r["n_eig_ge1_before"], r["n_eig_ge1_after"]), flush=True)

    make_figure(rows, d, fs, a.K)
    print("\nDONE", flush=True)
    return 0


def make_figure(rows, d, fs, Ks):
    n = len(rows)
    fig, axes = plt.subplots(2, n, figsize=(4.0 * n, 7), squeeze=False)
    for j, r in enumerate(rows):
        tag = "%s K=%d" % (r["detrend"], r["K"])
        npz = np.load(os.path.join(
            OUTDIR, "pilot2_%s_K%d.npz" % (r["detrend"].replace("去趋势", ""), r["K"])))
        ax = axes[0][j]
        for k in range(r["K"]):
            ax.plot(npz["t_cue"], npz["P_cue"][k], lw=1.3, label="k=%d" % k)
        ax.axvline(0, color="k", lw=0.6, ls=":")
        ax.axhline(0, color="gray", lw=0.4)
        ax.set_title("%s\nPSP(cue)  p_min=%.3f"
                     % (tag, min(min(r["psp_cue_p_shift"]), min(r["psp_cue_p_rand"]))))
        ax.set_xlabel("相对 cue (s)")
        if j == 0:
            ax.set_ylabel("P(z=k)")
        ax.legend(fontsize=7, frameon=False)

        ax = axes[1][j]
        mags = np.array(r["mag_after"])
        for k in range(r["K"]):
            ax.plot(np.arange(1, mags.shape[1] + 1), mags[k], "o-", ms=4, lw=1, label="k=%d" % k)
        ax.axhline(1.0, color="r", lw=1, ls="--")
        ax.text(0.02, 0.02, "红虚线 |λ|=1\n（以上=不收缩）", transform=ax.transAxes,
                fontsize=7, va="bottom")
        ax.set_title("%s\n|λ(A_k)|" % tag)
        ax.set_xlabel("特征值序号（降序）")
        if j == 0:
            ax.set_ylabel("|λ|")
        ax.legend(fontsize=7, frameon=False)
    fig.suptitle("pilot 第二轮：置换 null 后的 PSP 与 τ 诊断（%s %s）" % (d["mouse"], d["phase"]))
    fig.tight_layout()
    p = os.path.join(OUTDIR, "pilot2_psp_tau_%s.png" % d["mouse"])
    fig.savefig(p, dpi=130)
    plt.close(fig)
    print("图：%s" % p, flush=True)


if __name__ == "__main__":
    sys.exit(main())

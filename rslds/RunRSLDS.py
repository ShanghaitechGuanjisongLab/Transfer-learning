"""RunRSLDS.py —— Stage 1 pilot（见 rslds/RunPlan.md）

一句话：这是**标定 + 可行性检验**，不是证据。
它回答"这套东西在这份数据上跑出来是什么量级、流程有没有错"，
不回答"MOp 里有没有慢动机状态"。

跑什么：1 个 block × K∈{2,3,4} × 去趋势∈{原始, 双指数漂白} = 6 次拟合，各 150 轮。

用法：
    .venv\\Scripts\\python rslds\\RunRSLDS.py
    .venv\\Scripts\\python rslds\\RunRSLDS.py --iters 50
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time

import numpy as np
from scipy.stats import spearmanr
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
K_LIST = [2, 3, 4]
DETRENDS = ["原始", "漂白去趋势"]
N_OBS = 15         # 因子分析降到几维（= ssm.SLDS 的 N）
D_LATENT = 5       # 潜维（= ssm.SLDS 的 D）
# ⚠ ssm 的 GaussianOrthogonalEmissions 有 `assert N > D` —— 观测维必须**严格大于**潜维。
#   实测：FA 到 10 维 + 潜维 10 → 直接 AssertionError（干跑拓到过）。
BOX_SEC = 1.0      # cue / 给水 输入的方波宽度（s）
PSP_SEC = 3.0      # PSP 窗口 ±（s）


# --------------------------------------------------------------------------- #
# 输入与读数
# --------------------------------------------------------------------------- #
def build_inputs(d, fs):
    """u = [cue, 舔水率, 给水]。全部来自行为/刺激通道，与钙无信息重叠。"""
    T = d["X"].shape[0]
    u = np.zeros((T, 3))
    n_box = max(1, int(round(BOX_SEC * fs)))
    for col, key in [(0, "idx_TrialStart"), (2, "idx_GiveWater")]:
        for e in d[key]:
            e = int(e)
            if 0 <= e < T:
                u[e:min(T, e + n_box), col] = 1.0
    u[:, 1] = rd.smooth(rd.lick_indicator(d["cd2"]), n_box)
    return u, ["cue", "lick", "reward"]


def tau_spectrum(As, fs):
    """A_k 特征值 → 时间常数 τ（秒）。A_k 是满矩阵（diagonal_gaussian 只指噪声对角）。"""
    K, D, _ = np.shape(As)
    tau = np.full((K, D), np.nan)
    for k in range(K):
        lam = np.abs(np.linalg.eigvals(As[k]))
        with np.errstate(divide="ignore", invalid="ignore"):
            tau[k] = np.where(lam < 1.0,
                              (1.0 / fs) / -np.log(np.maximum(lam, 1e-12)),
                              np.inf)
    return np.sort(tau, axis=1)[:, ::-1]


def state_metrics(z, K, fs):
    """占用率、切换次数、逐状态连续驻留段时长（秒）。"""
    occ = np.array([(z == k).mean() for k in range(K)])
    edges = np.concatenate(([0], np.where(np.diff(z) != 0)[0] + 1, [len(z)]))
    segs = [[] for _ in range(K)]
    for a, b in zip(edges[:-1], edges[1:]):
        segs[int(z[a])].append((b - a) / fs)
    return occ, int(np.sum(np.diff(z) != 0)), [np.array(s) for s in segs]


def psp(Q, events, fs, win_sec):
    """事件锁定的状态概率曲线。Q 可以是 (T,K) 概率，也可以是 (T,) 硬指派。

    返回 (时间轴秒, (K, n) 矩阵)。
    """
    Q = np.asarray(Q, dtype=np.float64)
    if Q.ndim == 1:
        Q = np.eye(int(Q.max()) + 1)[Q.astype(int)]
    n = int(round(win_sec * fs))
    offs = np.arange(-n, n + 1)
    acc = np.zeros((offs.size, Q.shape[1]))
    cnt = 0
    for e in events:
        idx = int(e) + offs
        ok = (idx >= 0) & (idx < Q.shape[0])
        acc[ok] += Q[idx[ok]]
        cnt += 1
    return offs / fs, (acc / max(cnt, 1)).T


def occ_vs_time(Ez, fs, n_bins=30):
    """占用率沿 session 内时间的单调性：逐状态 Spearman(占用率, 时间)。"""
    T = Ez.shape[0]
    b = np.linspace(0, T, n_bins + 1).astype(int)
    tmid = (b[:-1] + b[1:]) / 2.0 / fs / 60.0
    out = []
    for k in range(Ez.shape[1]):
        o = np.array([Ez[b[i]:b[i + 1], k].mean() for i in range(n_bins)])
        rho = spearmanr(o, tmid).statistic
        out.append(0.0 if not np.isfinite(rho) else float(rho))
    return out


def finite(x):
    """把 nan/inf 换成 None，保证 JSON 合法。"""
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
# 单次拟合
# --------------------------------------------------------------------------- #
def run_one(Y, u, K, iters, seed=0):
    np.random.seed(seed)
    m = ssm.SLDS(Y.shape[1], K, D_LATENT, M=u.shape[1],
                 transitions="recurrent", dynamics="diagonal_gaussian",
                 emissions="gaussian_orthog", single_subspace=True)
    t0 = time.time()
    m.initialize(Y, inputs=u)
    t_init = time.time() - t0
    t0 = time.time()
    elbos, q = m.fit(Y, inputs=u, method="laplace_em",
                     variational_posterior="structured_meanfield",
                     initialize=False, num_iters=iters, alpha=0.0, verbose=0)
    t_fit = time.time() - t0
    x_hat = q.mean_continuous_states[0]
    Ez = np.asarray(q.mean_discrete_states[0], dtype=np.float64)
    z = np.asarray(m.most_likely_states(x_hat, Y, input=u))
    return dict(model=m, elbos=np.asarray(elbos, dtype=np.float64), Ez=Ez, z=z,
                t_init=t_init, t_fit=t_fit)


def summarize(res, K, detrend, fs, d):
    z, Ez, m = res["z"], res["Ez"], res["model"]
    occ, nsw, segs = state_metrics(z, K, fs)
    tau = tau_spectrum(m.dynamics.As, fs)
    t_cue, psp_cue = psp(Ez, d["idx_TrialStart"], fs, PSP_SEC)
    t_rew, psp_rew = psp(Ez, d["idx_GiveWater"], fs, PSP_SEC)
    lick = rd.smooth(rd.lick_indicator(d["cd2"]), max(1, int(round(fs))))
    elbos = res["elbos"]
    # 末段相对变化：窗口随实际轮数收缩（干跑 --iters 3 时 elbos 只有 4 个元素）
    nt = int(min(10, max(1, elbos.size - 1)))
    tail = np.abs(elbos[-nt:] - elbos[-nt - 1:-1]) / np.maximum(np.abs(elbos[-nt - 1:-1]), 1e-9)

    s = dict(
        detrend=detrend, K=K,
        elbo_final=float(elbos[-1]), elbo_per_pt=float(elbos[-1]) / len(z),
        elbo_tail_rel_change=float(np.nanmax(tail)),
        t_init_sec=res["t_init"], t_fit_sec=res["t_fit"], sec_per_iter=res["t_fit"] / elbos.size,
        occupancy=[float(o) for o in occ],
        n_switch=nsw, switch_per_min=nsw / (len(z) / fs / 60.0),
        dwell_median_s=[float(np.median(v)) if len(v) else np.nan for v in segs],
        dwell_p90_s=[float(np.percentile(v, 90)) if len(v) else np.nan for v in segs],
        tau_max_s=[float(t[0]) for t in tau],
        tau_all_s=[[float(v) for v in t] for t in tau],
        occ_vs_time_rho=occ_vs_time(Ez, fs),
        lick_rate_in_state=[float(lick[z == k].mean()) if (z == k).any() else np.nan
                            for k in range(K)],
        psp_cue_ptp=[float(np.ptp(psp_cue[k])) for k in range(K)],
        psp_rew_ptp=[float(np.ptp(psp_rew[k])) for k in range(K)],
        W_norm=float(np.linalg.norm(m.transitions.Ws)),
        R_norm=float(np.linalg.norm(m.transitions.Rs)),
        F_norm=float(np.linalg.norm(np.asarray(m.emissions.Fs).reshape(-1))),
        logPs_offdiag_mean=float(np.mean(m.transitions.log_Ps
                                         - np.diag(np.diag(m.transitions.log_Ps)))),
    )
    curve = dict(t_cue=t_cue, psp_cue=psp_cue, t_rew=t_rew, psp_rew=psp_rew, Ez=Ez, z=z)
    return s, curve


# --------------------------------------------------------------------------- #
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--iters", type=int, default=150)
    ap.add_argument("--block", default=BLOCK)
    ap.add_argument("--seed", type=int, default=0)
    a = ap.parse_args()

    os.makedirs(OUTDIR, exist_ok=True)
    path = os.path.join(rd.DATA_ROOT, "ALB", a.block)
    d = rd.load_block(path)
    assert rd.check_orientation(d), "X 方向不对，停止"
    fs, T = d["fs"], d["X"].shape[0]

    keep = d["cell_ok"] >= 1.0
    X = d["X"][:, keep]
    print("=== Stage 1 pilot ===", flush=True)
    print("block          : %s" % a.block, flush=True)
    print("鼠 / 阶段 / 设计: %s / %s / %s" % (d["mouse"], d["phase"], d["design"]), flush=True)
    print("时长           : %.1f min，fs=%.2f Hz，T=%d 点" % (d["dur_sec"] / 60, fs, T), flush=True)
    print("细胞           : %d（去掉 cellFiniteFrac<1 的 %d 个）"
          % (X.shape[1], int((~keep).sum())), flush=True)

    u, unames = build_inputs(d, fs)
    print("输入           : %s；非零占比 %s"
          % (unames, np.round((u > 0).mean(0), 4).tolist()), flush=True)
    print("事件           : cue=%d  给水=%d"
          % (len(d["idx_TrialStart"]), len(d["idx_GiveWater"])), flush=True)
    print("配置           : K=%s × 去趋势=%s，各 %d 轮，观测维=%d，潜维=%d，seed=%d\n"
          % (K_LIST, DETRENDS, a.iters, N_OBS, D_LATENT, a.seed), flush=True)

    rows, curves = [], {}
    for detrend in DETRENDS:
        Xd = X if detrend == "原始" else rd.detrend_bleach(X, fs)
        Z = rd.zscore_cols(Xd)
        t0 = time.time()
        Y, fa = rd.factor_analysis(Z, N_OBS, seed=a.seed)
        print("[%s] 因子分析 %.1f s；平均共性（%d 因子解释的细胞方差比）= %.3f"
              % (detrend, time.time() - t0, N_OBS,
                 float(np.mean(1 - fa.noise_variance_))), flush=True)
        for K in K_LIST:
            t0 = time.time()
            res = run_one(Y, u, K, a.iters, seed=a.seed)
            s, curve = summarize(res, K, detrend, fs, d)
            rows.append(s)
            curves[(detrend, K)] = curve
            print("  K=%d  ELBO=%9.0f (%.2f/点)  init %4.1f s + fit %6.1f s  "
                  "切换%5d (%.1f/min)  驻留中位 %s s  τ_max %s s"
                  % (K, s["elbo_final"], s["elbo_per_pt"], s["t_init_sec"], s["t_fit_sec"],
                     s["n_switch"], s["switch_per_min"],
                     [None if v is None else round(v, 1) for v in finite(s["dwell_median_s"])],
                     [None if v is None else round(v, 1) for v in finite(s["tau_max_s"])]),
                  flush=True)
            print("         占用率 %s | 状态内舔水率 %s | cue锁相幅度 %s | 时间趋势ρ %s"
                  % (np.round(s["occupancy"], 3).tolist(),
                     [None if v is None else round(v, 3) for v in finite(s["lick_rate_in_state"])],
                     [round(v, 3) for v in s["psp_cue_ptp"]],
                     [round(v, 2) for v in s["occ_vs_time_rho"]]), flush=True)

    with open(os.path.join(OUTDIR, "pilot_summary.json"), "w", encoding="utf-8") as fh:
        json.dump(finite(rows), fh, ensure_ascii=False, indent=1)
    print("\n指标已存：%s" % os.path.join(OUTDIR, "pilot_summary.json"), flush=True)
    make_figures(curves, d, fs)

    print("\n=== 验收门槛（四条全过才放开 Stage 2）===", flush=True)
    ok = True
    for r in rows:
        checks = [("单次<5min", (r["t_init_sec"] + r["t_fit_sec"]) < 300),
                  ("非逐帧切换", r["switch_per_min"] < 60),
                  ("ELBO已平台", r["elbo_tail_rel_change"] < 0.01),
                  ("PSP有结构", max(r["psp_cue_ptp"] + r["psp_rew_ptp"]) > 0.05)]
        print("  %-14s %s" % ("%s K=%d" % (r["detrend"], r["K"]),
                              "  ".join("%s:%s" % (n, "OK" if v else "×") for n, v in checks)),
              flush=True)
        ok &= all(v for _, v in checks)
    print("\n%s" % ("PILOT_OK 四条门槛全过" if ok
                    else "PILOT_WARN 有门槛未过 → 按 RunPlan 停下来报告，不自行放开门槛"), flush=True)
    return 0


def make_figures(curves, d, fs):
    fig, axes = plt.subplots(len(DETRENDS), len(K_LIST), figsize=(13, 6.5), squeeze=False)
    for i, det in enumerate(DETRENDS):
        for j, K in enumerate(K_LIST):
            c = curves[(det, K)]
            ax = axes[i][j]
            for k in range(K):
                ax.plot(c["t_cue"], c["psp_cue"][k], lw=1.2, label="k=%d" % k)
            ax.axvline(0, color="k", lw=0.6, ls=":")
            ax.set_ylim(-0.03, 1.03)
            ax.set_title("%s / K=%d" % (det, K))
            if i == len(DETRENDS) - 1:
                ax.set_xlabel("相对 cue 时间 (s)")
            if j == 0:
                ax.set_ylabel("P(z=k)")
            ax.legend(fontsize=7, frameon=False)
    fig.suptitle("PSP：状态概率相对 cue（%s %s）" % (d["mouse"], d["phase"]))
    fig.tight_layout()
    p1 = os.path.join(OUTDIR, "pilot_psp_%s.png" % d["mouse"])
    fig.savefig(p1, dpi=130)
    plt.close(fig)

    fig, axes = plt.subplots(len(DETRENDS), len(K_LIST), figsize=(13, 5.5), squeeze=False)
    for i, det in enumerate(DETRENDS):
        for j, K in enumerate(K_LIST):
            c = curves[(det, K)]
            ax = axes[i][j]
            ax.imshow(c["Ez"].T, aspect="auto", origin="lower", interpolation="nearest",
                      extent=[0, c["Ez"].shape[0] / fs / 60.0, -0.5, K - 0.5])
            for e in d["idx_TrialStart"]:
                ax.axvline(e / fs / 60.0, color="k", lw=0.25, alpha=0.35)
            ax.set_title("%s / K=%d" % (det, K))
            if i == len(DETRENDS) - 1:
                ax.set_xlabel("session 内时间 (min)")
            if j == 0:
                ax.set_ylabel("状态 k")
    fig.suptitle("后验状态概率随时间（竖线 = cue；%s %s）" % (d["mouse"], d["phase"]))
    fig.tight_layout()
    p2 = os.path.join(OUTDIR, "pilot_states_%s.png" % d["mouse"])
    fig.savefig(p2, dpi=130)
    plt.close(fig)
    print("图：%s\n图：%s" % (p1, p2), flush=True)


if __name__ == "__main__":
    sys.exit(main())

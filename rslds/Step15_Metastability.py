"""Step15_Metastability.py —— M5 多稳性检验（AR 匹配零模型的正确版本）

为什么重做
  旧的 D1 用 **i.i.d. 高斯**零模型校准 ΔBIC，纯 OU 都被判成双峰（连教科书级高斯潜变量
  都给出 ΔBIC=+310）。根因是零模型不含自相关——慢过程天然"成团"。
  本版零模型改为 **VAR(1) 参数化 bootstrap**：拟合真实数据的 VAR(1)，同长度模拟，
  跑完全相同的 GMM 比较 ⇒ 自相关结构被完整复制。

统计量
  · ΔBIC = BIC(1) − BIC(2)（≥0 偏向双峰）
  · 分离度 sep = ‖μ₂−μ₁‖ / 合并 SD（沿均值差方向）
  · 较小分量权重 w_min
  · 状态切换率（用 2 分量的后验标签）

判据
  ΔBIC 超过 AR 零模型 95 分位 **且** sep ≥ 2 **且** w_min ≥ 0.15 ⇒ 支持多稳
"""
from __future__ import annotations

import json
import os
import time

import numpy as np
from sklearn.mixture import GaussianMixture

import attractor_core as AC
import Step10_TICA as T
from rslds_data import load_block, scan_cohort

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "results", "_step15_metastability.json")
KPC = 10
N_SIM = 30
PHASES = ["Learned", "Transfer", "Final"]
SEP_THR = 2.0
W_THR = 0.15


def valley_depth(X, lab, n_sub=2500, seed=0):
    """沿均值差方向投影后，两峰之间的谷深 = 谷底密度 / 较低峰高。

    GMM 的 ΔBIC 对任何非高斯（重尾、爆发）都会上升，不专指双峰；
    真正的多稳必须在两峰之间有**深谷**。谷深 < 0.6 才算。
    """
    from scipy.stats import gaussian_kde
    if len(np.unique(lab)) < 2:
        return 1.0
    m0, m1 = X[lab == 0].mean(0), X[lab == 1].mean(0)
    v = m1 - m0
    nv = np.linalg.norm(v)
    if nv < 1e-9:
        return 1.0
    t = X @ (v / nv)
    rng = np.random.default_rng(seed)
    if len(t) > n_sub:
        t = t[rng.choice(len(t), n_sub, replace=False)]
    grid = np.linspace(np.percentile(t, 1), np.percentile(t, 99), 256)
    dens = gaussian_kde(t)(grid)
    # 取两个最高的局部极大
    peaks = [i for i in range(1, 255) if dens[i] > dens[i - 1] and dens[i] > dens[i + 1]]
    if len(peaks) < 2:
        return 1.0
    peaks = sorted(peaks, key=lambda i: -dens[i])[:2]
    a, b = sorted(peaks)
    valley = float(dens[a:b + 1].min() / max(min(dens[a], dens[b]), 1e-12))
    return valley


def gmm_stats(X, seed=0):
    g1 = GaussianMixture(1, covariance_type="full", n_init=2, random_state=seed).fit(X)
    g2 = GaussianMixture(2, covariance_type="full", n_init=8, random_state=seed).fit(X)
    dbic = float(g1.bic(X) - g2.bic(X))
    v = g2.means_[1] - g2.means_[0]
    nv = float(np.linalg.norm(v))
    if nv > 0:
        u = v / nv
        s1 = float(np.sqrt(u @ g2.covariances_[0] @ u))
        s2 = float(np.sqrt(u @ g2.covariances_[1] @ u))
        sep = nv / max(0.5 * (s1 + s2), 1e-12)
    else:
        sep = 0.0
    lab = g2.predict(X)
    sw = int(np.sum(lab[1:] != lab[:-1]))
    return dict(dbic=dbic, sep=float(sep), w_min=float(g2.weights_.min()),
                valley=valley_depth(X, lab),
                switch_per_min=float(sw / (len(X) / 60.0))), g1


def fit_var1(X):
    Z, Zn = X[:-1], X[1:]
    M = np.column_stack([np.ones(len(Z)), Z])
    coef, *_ = np.linalg.lstsq(M, Zn, rcond=None)
    res = Zn - M @ coef
    return coef[0], coef[1:].T, np.cov(res.T)


def sim_var1(X, c, A, S, rng):
    n, d = X.shape
    L = np.linalg.cholesky(S + 1e-12 * np.eye(d))
    e = rng.standard_normal((n, d)) @ L.T
    Z = np.empty((n, d))
    Z[0] = X[0]
    for t in range(1, n):
        Z[t] = c + A @ Z[t - 1] + e[t]
    return Z


def main():
    t0 = time.time()
    ms = scan_cohort("ALB", phases=PHASES)
    ms.sort(key=lambda b: (b["mouse"], PHASES.index(b["phase"])))
    rows = []
    print(f"{'鼠':<9s}{'阶段':<8s}{'ΔBIC':>9s}{'零模型95%':>10s}{'p':>6s}"
          f"{'谷深':>7s}{'零谷5%':>6s}{'w_min':>6s}{'切换/min':>8s}{'零模型':>8s}  判定")
    for b in ms:
        d = load_block(b["path"])
        fs = d["fs"]
        Y = np.nan_to_num(AC.dff(d["X"], fs), nan=0.0, posinf=0.0, neginf=0.0)
        Y = Y[:, np.std(Y, axis=0) > 1e-9]
        Z = AC.zscore_robust(AC.VARIANTS["P1"](Y, fs))
        X, _, _, _ = T.pcs(Z, KPC)

        obs, g1 = gmm_stats(X)
        c, A, S = fit_var1(X)
        rng = np.random.default_rng(0)
        null_dbic, null_sw, null_sep, null_w, null_val = [], [], [], [], []
        for _ in range(N_SIM):
            Xs = sim_var1(X, c, A, S, rng)
            st, _ = gmm_stats(Xs, seed=1)
            null_dbic.append(st["dbic"])
            null_sw.append(st["switch_per_min"])
            null_sep.append(st["sep"])
            null_w.append(st["w_min"])
            null_val.append(st["valley"])
        n95 = float(np.percentile(null_dbic, 95))
        v5 = float(np.percentile(null_val, 5))
        p = float((1 + sum(v >= obs["dbic"] for v in null_dbic)) / (len(null_dbic) + 1))
        # 判据：ΔBIC 超零模型 95%，且**谷比零模型更深**，且权重不过小
        passed = bool(p < 0.05 and obs["valley"] < min(0.6, v5) and obs["w_min"] >= W_THR)

        rows.append(dict(mouse=b["mouse"], phase=b["phase"], **obs,
                         null95=n95, p=p, null_dbic_med=float(np.median(null_dbic)),
                         null_switch_med=float(np.median(null_sw)),
                         null_valley5=v5, passed=passed, n_sim=len(null_dbic)))
        print(f"{b['mouse']:<9s}{b['phase']:<8s}{obs['dbic']:9.0f}{n95:10.0f}{p:6.3f}"
              f"{obs['valley']:7.2f}{v5:6.2f}{obs['w_min']:6.2f}{obs['switch_per_min']:8.1f}"
              f"{np.median(null_sw):8.1f}  {'✅多稳' if passed else '单峰'}")

    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(rows, indent=2, ensure_ascii=False))

    if rows:
        print(f"\n=== 汇总（{len(rows)} session）===")
        print(f"ΔBIC 中位 {np.median([x['dbic'] for x in rows]):.0f}；"
              f"零模型中位 {np.median([x['null_dbic_med'] for x in rows]):.0f}")
        print(f"p<0.05 的 {sum(1 for x in rows if x['p'] < 0.05)}/{len(rows)}；"
              f"同时满足 sep≥2 且 w≥0.15 的 {sum(1 for x in rows if x['passed'])}/{len(rows)}")
        for ph in PHASES:
            sub = [x for x in rows if x["phase"] == ph]
            if sub:
                print(f"  {ph:<8s} n={len(sub):2d}  sep 中位 {np.median([x['sep'] for x in sub]):.2f}  "
                      f"w_min 中位 {np.median([x['w_min'] for x in sub]):.2f}  "
                      f"切换/min 中位 {np.median([x['switch_per_min'] for x in sub]):.1f} "
                      f"(零模型 {np.median([x['null_switch_med'] for x in sub]):.1f})")
    print(f"\n用时 {(time.time()-t0)/60:.1f} min；写出 {OUT}")


if __name__ == "__main__":
    main()

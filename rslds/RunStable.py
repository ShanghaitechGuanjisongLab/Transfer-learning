"""RunStable.py —— 给 A_k 加稳定性约束（|λ| ≤ ρ_max）重拟，看 ΔK 还活不活

背景（笔记 (x)）：未加约束的拟合在 **11/11 只鼠**上都把某个特征值推到 λ≈1
（min|1−λ| = 0.002–0.012，det(I−A) 小到 1e−7~1e−12）⇒ 该状态**没有定点**，
"坑/吸引子"这套词用不了。最可能的解释是模型在用单位根追数据里已知的慢漂移。

本脚本：每次 M 步之后把每个 A_k 的**谱半径**压到 ≤ ρ_max（等比缩放整个矩阵，
特征值模长线性缩放，故必然满足；且保持特征向量与旋转结构不变）。
**不改 ssm 源码**——用子类覆盖 `m_step`。

判据（事先声明）：
  · 约束后 **ΔK 崩掉** ⇒ "2 状态"是建立在单位根上的伪结构
  · 约束后 **ΔK 保住** ⇒ 体制切换是真的，才可以谈景观

用法：  .venv\\Scripts\\python rslds\\RunStable.py [--rho 0.99] [--only 2]
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time

import numpy as np
import ssm
from ssm import observations as obs

import rslds_data as rd
from RunFig1 import OUTDIR, K_LIST
from RunRSLDS2 import N_OBS, D_LATENT, build_inputs, state_metrics

HERE = os.path.dirname(os.path.abspath(__file__))
OUTDIR = os.path.join(HERE, "results", "fig1")


class StableARDynamics(obs.AutoRegressiveDiagonalNoiseObservations):
    """把每个 $A_k$ 的谱半径压到 <= rho_max（等比缩放）。

    等比缩放：$A\\to (\\rho_{max}/\\rho)A$。特征值随之线性缩放，故 $|\\lambda|\\le\\rho_{max}$ 必然成立，
    且特征向量、旋转（复特征值）结构不变。是最简单、最不易出数值问题的一种约束。
    """

    def __init__(self, K, D, M=0, rho_max=0.99, **kw):
        super().__init__(K, D, M=M, **kw)
        self.rho_max = float(rho_max)

    def m_step(self, expectations, datas, inputs, masks, tags, **kwargs):
        super().m_step(expectations, datas, inputs, masks, tags, **kwargs)
        A = np.array(self._As, dtype=float)
        for k in range(self.K):
            r = np.max(np.abs(np.linalg.eigvals(A[k])))
            if r > self.rho_max:
                A[k] *= self.rho_max / r
        self._As = A


def fit_stable(Y, u, K, iters, seed, rho):
    np.random.seed(seed)
    dyn = StableARDynamics(K, D_LATENT, M=u.shape[1], rho_max=rho)
    m = ssm.SLDS(N_OBS, K, D_LATENT, M=u.shape[1], transitions="recurrent",
                 dynamics=dyn, emissions="gaussian_orthog", single_subspace=True)
    m.initialize(Y, inputs=u)
    t0 = time.time()
    elbos, q = m.fit(Y, inputs=u, method="laplace_em",
                     variational_posterior="structured_meanfield",
                     initialize=False, num_iters=iters, alpha=0.0, verbose=0)
    t_fit = time.time() - t0
    elbos = np.asarray(elbos, dtype=np.float64)
    x = np.asarray(q.mean_continuous_states[0], dtype=np.float64)
    z = np.asarray(m.most_likely_states(x, Y, input=u))
    return m, elbos, x, z, t_fit


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--iters", type=int, default=300)
    ap.add_argument("--seed", type=int, default=0)
    ap.add_argument("--rho", type=float, default=0.99)
    ap.add_argument("--only", type=int, default=None)
    a = ap.parse_args()
    os.makedirs(OUTDIR, exist_ok=True)

    real = json.load(open(os.path.join(OUTDIR, "fig1_summary.json"), encoding="utf-8"))
    by_mouse = {r["mouse"]: r for r in real}
    blocks = [b for b in rd.scan_cohort("ALB", phases=["Transfer"])
              if b["design"] == "LightWater"]
    if a.only:
        blocks = blocks[:a.only]

    print("=== 稳定性约束重拟：ρ_max = %.3f（τ 上限 ≈ %.1f s @8 Hz）==="
          % (a.rho, (1.0 / 8.0) / -np.log(a.rho)), flush=True)
    print("%d 只鼠 × K=%s × %d 轮\n" % (len(blocks), K_LIST, a.iters), flush=True)

    rows = []
    for i, b in enumerate(blocks):
        d = rd.load_block(b["path"])
        assert rd.check_orientation(d)
        fs = d["fs"]
        u = build_inputs(d, fs)
        X = d["X"][:, d["cell_ok"] >= 1.0]
        Z = rd.zscore_cols(rd.detrend_bleach(X, fs))
        Y, _ = rd.factor_analysis(Z, N_OBS, seed=a.seed)
        ep, info = {}, {}
        for K in K_LIST:
            t0 = time.time()
            m, elbos, x, z, t_fit = fit_stable(Y, u, K, a.iters, a.seed, a.rho)
            ep[K] = float(elbos[-1]) / len(z)
            rho_k = np.array([np.max(np.abs(np.linalg.eigvals(A)))
                              for A in np.array(m.dynamics.As)])
            ncap = int((rho_k > a.rho - 1e-6).sum())
            occ, nsw, segs = state_metrics(z, K, fs)
            info[K] = dict(elbo_per_pt=ep[K], rho_k=rho_k.tolist(), n_at_cap=ncap,
                           occupancy=[float(v) for v in occ], n_switch=nsw,
                           switch_per_min=nsw / (len(z) / fs / 60),
                           dwell_median_s=[float(np.median(v)) if v else np.nan for v in segs])
            np.savez_compressed(
                os.path.join(OUTDIR, "stable_%s_K%d_rho%.3f.npz" % (b["mouse"], K, a.rho)),
                x=x, z=z, As=np.array(m.dynamics.As), bs=m.dynamics.bs, elbos=elbos, fs=fs)
            print("  [%2d/%d] %-9s K=%d  ELBO/点 %8.3f  %.0f s  ρ=%s（触顶 %d/%d）"
                  % (i + 1, len(blocks), b["mouse"], K, ep[K], t_fit,
                     np.round(rho_k, 3).tolist(), ncap, K), flush=True)
        dK_s = ep[2] - ep[1]
        dK_u = by_mouse[b["mouse"]]["dK"] if b["mouse"] in by_mouse else np.nan
        print("         ΔK_约束 %+.3f   ΔK_无约束 %+.3f   变化 %+.3f\n"
              % (dK_s, dK_u, dK_s - dK_u), flush=True)
        rows.append(dict(mouse=b["mouse"], rho_max=a.rho, dK_stable=dK_s, dK_free=dK_u,
                         delta=dK_s - dK_u, K1=info[1], K2=info[2]))

    smfile = os.path.join(OUTDIR, "stable_summary.json")
    old = json.load(open(smfile, encoding="utf-8")) if os.path.exists(smfile) else []
    keys = {r["mouse"] for r in rows}
    allrows = [r for r in old if r["mouse"] not in keys] + rows
    allrows.sort(key=lambda r: r["mouse"])
    with open(smfile, "w", encoding="utf-8") as fh:
        json.dump(allrows, fh, ensure_ascii=False, indent=1)

    dks = np.array([r["dK_stable"] for r in allrows], dtype=float)
    dkf = np.array([r["dK_free"] for r in allrows], dtype=float)
    ok = np.isfinite(dks)
    print("=== 汇总（%d 只）===" % ok.sum(), flush=True)
    print("%-9s %11s %11s %9s" % ("鼠", "ΔK_约束", "ΔK_无约束", "变化"), flush=True)
    for r in allrows:
        print("%-9s %+11.3f %+11.3f %+9.3f"
              % (r["mouse"], r["dK_stable"], r["dK_free"], r["delta"]), flush=True)
    if ok.sum() >= 3:
        from scipy.stats import wilcoxon
        try:
            p = float(wilcoxon(dks[ok], alternative="greater").pvalue)
        except ValueError:
            p = float("nan")
        npos = int((dks[ok] > 0).sum())
        print("\n约束后 ΔK：中位 %+.3f，均值 %+.3f，>0 的 %d/%d，Wilcoxon 单侧 p = %.4f"
              % (np.median(dks[ok]), dks[ok].mean(), npos, ok.sum(), p), flush=True)
        print("无约束  ΔK：中位 %+.3f" % np.median(dkf[np.isfinite(dkf)]), flush=True)
        n1 = sum(r["K1"]["n_at_cap"] for r in allrows)
        n2 = sum(r["K2"]["n_at_cap"] for r in allrows)
        print("ρ 触顶的状态数（约束在起作用的程度）：K1 %d/%d、K2 %d/%d"
              % (n1, len(allrows), n2, 2 * len(allrows)), flush=True)
    print("\nDONE", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())

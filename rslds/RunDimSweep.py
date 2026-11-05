"""RunDimSweep.py —— 把潜维度从 D=5 抬到 10 / 14，看结论是否还站得住。

**为什么必须做**（见笔记 (aa) 第 4 条）：
`gaussian_orthog` 的发射矩阵是 $N\\times D$ 正交列，所以模型只能解释 $D$ 个观测维。
我们一直用 $N=15,D=5$ ⇒ 逐维 $R^2$ 恰好 5 个 1、10 个 0，**15 维白化 FA 输出里有 10 维被当噪声**。
而且 sklearn `FactorAnalysis.transform` 是**白化**的（15 维等方差、无排序），
所以"被建模的 5 维"是**任意的**（实测每只鼠挑中的维度都不同）。

于是所有既有结论都只是"某个任意 5 维子空间"的描述。
这里把 $D$ 抬到 10 和 14（`ssm` 要求 $N>D$，故上限 14），检查：
  · $\\Delta K$（K=2 相对 K=1 的 ELBO 增益/点）是否还在、有多大
  · 谱半径 $\\rho$ 是否还是往 1⁺ 跑
  · 占用率 / 切换率是否还是"两个体制"的样子
  · 被解释的观测维数是否真的变成 D

基线 $D=5$ 直接从 `fig1_<mouse>_K{1,2}.npz` 的 `elbos` 重算，保证算术完全一致。

用法：  .venv\\Scripts\\python rslds\\RunDimSweep.py [--only 3] [--dims 10 14] [--iters 300]
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time

import numpy as np

import rslds_data as rd
from RunRSLDS2 import N_OBS, BOX_SEC, build_inputs, state_metrics
import ssm

HERE = os.path.dirname(os.path.abspath(__file__))
FIGDIR = os.path.join(HERE, "results", "fig1")
K_LIST = [1, 2]


def fit(Y, u, K, D, iters, seed):
    np.random.seed(seed)
    m = ssm.SLDS(N_OBS, K, D, M=u.shape[1], transitions="recurrent",
                 dynamics="diagonal_gaussian", emissions="gaussian_orthog",
                 single_subspace=True)
    m.initialize(Y, inputs=u)
    elbos, q = m.fit(Y, inputs=u, method="laplace_em",
                     variational_posterior="structured_meanfield",
                     initialize=False, num_iters=iters, alpha=0.0, verbose=0)
    elbos = np.asarray(elbos, dtype=np.float64)
    x = np.asarray(q.mean_continuous_states[0], dtype=np.float64)
    z = np.asarray(m.most_likely_states(x, Y, input=u))
    return m, elbos, x, z


def baseline_dk(mouse):
    """从 D=5 的既有 npz 重算 ELBO/点 差，保证与本次算术一致。"""
    out = {}
    for K in K_LIST:
        f = os.path.join(FIGDIR, "fig1_%s_K%d.npz" % (mouse, K))
        if not os.path.exists(f):
            return np.nan
        z = np.load(f)
        out[K] = float(z["elbos"][-1]) / z["z"].shape[0]
    return out[2] - out[1]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--iters", type=int, default=300)
    ap.add_argument("--seed", type=int, default=0)
    ap.add_argument("--only", type=int, default=3)
    ap.add_argument("--dims", type=int, nargs="+", default=[10, 14])
    a = ap.parse_args()
    os.makedirs(FIGDIR, exist_ok=True)

    blocks = [b for b in rd.scan_cohort("ALB", phases=["Transfer"])
              if b["design"] == "LightWater"]
    blocks = blocks[:a.only]

    print("=== 潜维度扫描：D=%s → %s（对照 D=5，%d 轮，无稳定性约束）==="
          % (5, a.dims, a.iters), flush=True)
    rows = []
    for i, b in enumerate(blocks):
        d = rd.load_block(b["path"])
        assert rd.check_orientation(d)
        fs = d["fs"]
        u = build_inputs(d, fs)
        X = d["X"][:, d["cell_ok"] >= 1.0]
        Z = rd.zscore_cols(rd.detrend_bleach(X, fs))
        Y, _ = rd.factor_analysis(Z, N_OBS, seed=a.seed)
        dk5 = baseline_dk(b["mouse"])
        print("\n[%d/%d] %-9s  D=5 的 ΔK = %+.3f（既有）" % (i + 1, len(blocks), b["mouse"], dk5),
              flush=True)

        for D in a.dims:
            ep, info = {}, {}
            for K in K_LIST:
                t0 = time.time()
                m, elbos, x, z = fit(Y, u, K, D, a.iters, a.seed)
                ep[K] = float(elbos[-1]) / len(z)
                As = np.array(m.dynamics.As)
                rho = [float(np.max(np.abs(np.linalg.eigvals(A)))) for A in As]
                occ, nsw, segs = state_metrics(z, K, fs)
                info[K] = dict(elbo_per_pt=ep[K], rho=rho,
                               n_unstable=int(sum(r > 1 for r in rho)),
                               occupancy=[float(v) for v in occ], n_switch=int(nsw),
                               switch_per_min=float(nsw / (len(z) / fs / 60)),
                               dwell_median_s=[float(np.median(v)) if v else np.nan
                                               for v in segs])
                np.savez_compressed(
                    os.path.join(FIGDIR, "dim_%s_D%d_K%d.npz" % (b["mouse"], D, K)),
                    x=x, z=z, As=As, bs=np.array(m.dynamics.bs), elbos=elbos, fs=fs)
                print("  %-9s D=%2d K=%d  ELBO/点 %8.3f  %5.0f s  ρ=%s"
                      % (b["mouse"], D, K, ep[K], time.time() - t0,
                         np.round(rho, 3).tolist()), flush=True)
            dkD = ep[2] - ep[1]
            print("         → D=%2d 的 ΔK = %+.3f  （D=5 是 %+.3f，变化 %+.3f）"
                  % (D, dkD, dk5, dkD - dk5), flush=True)
            rows.append(dict(mouse=b["mouse"], D=D, dK=dkD, dK_D5=dk5,
                             delta=dkD - dk5, K1=info[1], K2=info[2]))

    sm = os.path.join(FIGDIR, "dim_sweep.json")
    old = json.load(open(sm, encoding="utf-8")) if os.path.exists(sm) else []
    keys = {(r["mouse"], r["D"]) for r in rows}
    allrows = [r for r in old if (r["mouse"], r["D"]) not in keys] + rows
    allrows.sort(key=lambda r: (r["mouse"], r["D"]))
    with open(sm, "w", encoding="utf-8") as fh:
        json.dump(allrows, fh, ensure_ascii=False, indent=1)

    print("\n=== 汇总 ===", flush=True)
    print("%-9s %3s %10s %10s %9s %7s %7s"
          % ("鼠", "D", "ΔK", "ΔK(D=5)", "变化", "不稳定态", "切换/min"), flush=True)
    for r in allrows:
        print("%-9s %3d %+10.3f %+10.3f %+9.3f %7d %7.1f"
              % (r["mouse"], r["D"], r["dK"], r["dK_D5"], r["delta"],
                 r["K2"]["n_unstable"], r["K2"]["switch_per_min"]), flush=True)

    for D in sorted({r["D"] for r in allrows}):
        v = np.array([r["dK"] for r in allrows if r["D"] == D], dtype=float)
        nu = np.array([r["K2"]["n_unstable"] for r in allrows if r["D"] == D], dtype=float)
        print("\nD=%2d：ΔK 中位 %+.3f（%d/%d >0）；K=2 里不稳定状态数 中位 %.0f/2"
              % (D, np.median(v), int((v > 0).sum()), len(v), np.median(nu)), flush=True)
    v5 = np.array([r["dK_D5"] for r in allrows if r["D"] == allrows[0]["D"]], dtype=float)
    print("D= 5：ΔK 中位 %+.3f（%d/%d >0）" % (np.median(v5), int((v5 > 0).sum()), len(v5)),
          flush=True)
    print("\n判据：若 D 抬到 14 后 ΔK 仍显著 >0 且 ρ 仍往 1⁺ 跑 ⇒ 之前的结论不是 5 维子空间的假象",
          flush=True)
    print("DONE", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())

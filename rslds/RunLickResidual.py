"""RunLickResidual.py —— 两个"稳定工作点"到底是不是「舔 / 不舔」？

做法：在同一份 FA 输出 Y(T×15) 上，
  ① **真回归**：用**时间平移过的舔水轨**（滞后 −1…+1 s 共 17 个回归量，覆盖 GCaMP 卷积滞后）
     把舔水相关方差从 Y 里回归掉 → refit K=1/K=2 → ΔK_real_resid
  ② **伪回归（对照）**：把舔水轨**整体循环平移**一个大随机量（自相关完全相同、但不再与钙对齐），
     同样回归 → ΔK_sham
  ③ 参考：不回归的 **ΔK_stable**（来自 `stable_summary.json`，同样是 ρ≤0.99 约束）

为什么必须有 ②：回归掉任何东西都会减少方差，ΔK 可能**仅仅因为信号变少而下降**。
只有「真回归的下降 ≫ 伪回归的下降」才能说明"工作点就是舔水"。

事先声明的判据：
  · ΔK_real_resid ≈ 0 且 ≪ ΔK_sham  ⇒ 两个工作点**就是**舔 / 不舔
  · ΔK_real_resid ≈ ΔK_sham          ⇒ 工作点与舔水**无关**，另有来源

拟合用与 (y) 相同的稳定性约束（ρ ≤ 0.99），保持可比。

用法：  .venv\\Scripts\\python rslds\\RunLickResidual.py [--only 2] [--iters 300]
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time

import numpy as np

import rslds_data as rd
from RunFig1 import OUTDIR
from RunStable import StableARDynamics
from RunRSLDS2 import N_OBS, D_LATENT, BOX_SEC, build_inputs, state_metrics
import ssm

HERE = os.path.dirname(os.path.abspath(__file__))
OUTDIR = os.path.join(HERE, "results", "fig1")
K_LIST = [1, 2]
RHO = 0.99
LAGS = list(range(-8, 9))       # ±1 s @8 Hz，覆盖钙卷积滞后


def lagged(x, L):
    T = len(x)
    if L == 0:
        return x.copy()
    v = np.zeros(T)
    if L > 0:
        v[L:] = x[:T - L]
    else:
        v[:T + L] = x[-L:]
    return v


def project_out(Y, regs):
    """把 regs（T×m，含常数项）张成的空间从 Y 的每一列里投影掉。"""
    Q, _ = np.linalg.qr(regs)
    return Y - Q @ (Q.T @ Y)


def fit(Y, u, K, iters, seed):
    np.random.seed(seed)
    dyn = StableARDynamics(K, D_LATENT, M=u.shape[1], rho_max=RHO)
    m = ssm.SLDS(N_OBS, K, D_LATENT, M=u.shape[1], transitions="recurrent",
                 dynamics=dyn, emissions="gaussian_orthog", single_subspace=True)
    m.initialize(Y, inputs=u)
    elbos, q = m.fit(Y, inputs=u, method="laplace_em",
                     variational_posterior="structured_meanfield",
                     initialize=False, num_iters=iters, alpha=0.0, verbose=0)
    elbos = np.asarray(elbos, dtype=np.float64)
    return float(elbos[-1]) / Y.shape[0]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--iters", type=int, default=300)
    ap.add_argument("--seed", type=int, default=0)
    ap.add_argument("--only", type=int, default=None)
    a = ap.parse_args()
    os.makedirs(OUTDIR, exist_ok=True)

    st = json.load(open(os.path.join(OUTDIR, "stable_summary.json"), encoding="utf-8"))
    dk_stable = {r["mouse"]: r["dK_stable"] for r in st}
    blocks = [b for b in rd.scan_cohort("ALB", phases=["Transfer"])
              if b["design"] == "LightWater"]
    if a.only:
        blocks = blocks[:a.only]

    print("=== 舔水回归：真回归 vs 伪回归（ρ_max=%.2f，%d 轮，滞后 %d…%d 样本）==="
          % (RHO, a.iters, LAGS[0], LAGS[-1]), flush=True)
    rows = []
    for i, b in enumerate(blocks):
        d = rd.load_block(b["path"])
        assert rd.check_orientation(d)
        fs = d["fs"]
        u = build_inputs(d, fs)
        X = d["X"][:, d["cell_ok"] >= 1.0]
        Z = rd.zscore_cols(rd.detrend_bleach(X, fs))
        Y, _ = rd.factor_analysis(Z, N_OBS, seed=a.seed)
        T = Y.shape[0]

        lick = rd.smooth(rd.lick_indicator(d["cd2"]), max(1, int(round(BOX_SEC * fs))))
        rng = np.random.default_rng(a.seed + 7 * i)
        shift = int(rng.integers(T // 4, 3 * T // 4))
        lick_sham = np.roll(lick, shift)

        out = {}
        for name, reg in [("real", lick), ("sham", lick_sham)]:
            B = np.column_stack([np.ones(T)] + [lagged(reg, L) for L in LAGS])
            Yr = project_out(Y, B)
            removed = float(1 - Yr.var(axis=0).sum() / Y.var(axis=0).sum())
            ep = {}
            for K in K_LIST:
                t0 = time.time()
                ep[K] = fit(Yr, u, K, a.iters, a.seed)
                print("  [%2d/%d] %-9s %-4s K=%d  ELBO/点 %8.3f  %.0f s（去掉方差 %.1f%%）"
                      % (i + 1, len(blocks), b["mouse"], name, K, ep[K],
                         time.time() - t0, 100 * removed), flush=True)
            out[name] = dict(dK=ep[2] - ep[1], var_removed=removed)
        print("         ΔK_真回归 %+.3f   ΔK_伪回归 %+.3f   ΔK_不回归 %+.3f   shift=%d\n"
              % (out["real"]["dK"], out["sham"]["dK"], dk_stable.get(b["mouse"], np.nan), shift),
              flush=True)
        rows.append(dict(mouse=b["mouse"], dK_real_resid=out["real"]["dK"],
                         dK_sham_resid=out["sham"]["dK"],
                         dK_stable=dk_stable.get(b["mouse"], np.nan),
                         var_removed_real=out["real"]["var_removed"],
                         var_removed_sham=out["sham"]["var_removed"], shift=shift))

    smfile = os.path.join(OUTDIR, "lick_residual.json")
    old = json.load(open(smfile, encoding="utf-8")) if os.path.exists(smfile) else []
    keys = {r["mouse"] for r in rows}
    allrows = [r for r in old if r["mouse"] not in keys] + rows
    allrows.sort(key=lambda r: r["mouse"])
    with open(smfile, "w", encoding="utf-8") as fh:
        json.dump(allrows, fh, ensure_ascii=False, indent=1)

    print("=== 汇总（%d 只）===" % len(allrows), flush=True)
    print("%-9s %11s %11s %11s %8s %8s"
          % ("鼠", "ΔK_真回归", "ΔK_伪回归", "ΔK_不回归", "去方差真", "去方差伪"), flush=True)
    for r in allrows:
        print("%-9s %+11.3f %+11.3f %+11.3f %8.3f %8.3f"
              % (r["mouse"], r["dK_real_resid"], r["dK_sham_resid"], r["dK_stable"],
                 r["var_removed_real"], r["var_removed_sham"]), flush=True)

    r = np.array([x["dK_real_resid"] for x in allrows], dtype=float)
    s = np.array([x["dK_sham_resid"] for x in allrows], dtype=float)
    ok = np.isfinite(r) & np.isfinite(s)
    if ok.sum() >= 3:
        from scipy.stats import wilcoxon
        d = r[ok] - s[ok]
        try:
            p = float(wilcoxon(r[ok], s[ok], alternative="less").pvalue)
        except ValueError:
            p = float("nan")
        print("\n真回归 vs 伪回归（单侧「真更小」）：中位差 %+.3f，Wilcoxon p = %.4f"
              % (np.median(d), p), flush=True)
        print("真回归 ΔK：中位 %+.3f，>0 的 %d/%d" % (np.median(r[ok]), (r[ok] > 0).sum(), ok.sum()),
              flush=True)
        print("伪回归 ΔK：中位 %+.3f，>0 的 %d/%d" % (np.median(s[ok]), (s[ok] > 0).sum(), ok.sum()),
              flush=True)
        print("\n判据：ΔK_真回归 ≈ 0 且 ≪ 伪回归 ⇒ 两个工作点就是舔/不舔；两者相近 ⇒ 与舔水无关",
              flush=True)
    print("\nDONE", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())

"""RunSurrogatePaired.py —— B：逐鼠配对的替代数据，给 ΔK 一个零假设

问题：`fig1` 里 11 只鼠的 ΔK 全为正（中位 +0.348），但参照的替代基线只有
**1 次实现、1 个 block（+0.021）**。而 ΔK 本身变异极大（鼠间 13 倍；同一只鼠的两个 block
也能差 2.5 倍）。所以单点基线没用。

做法：对**每一只鼠的同一个 Transfer block** 生成一份多变量相位随机化替代数据
（每个频率对所有通道乘同一随机相位 ⇒ 全部自/互协方差精确保留、非高斯状态结构被破坏），
用**同样的流水线和超参**重拟 K=1、K=2，得到 ΔK_替代。

统计：逐鼠配对
    ΔK_真实  （来自 fig1_summary.json，已算好）
    ΔK_替代  （本脚本）
    交互 = ΔK_真实 − ΔK_替代
对 11 个交互做单样本检验（Wilcoxon 符号秩 + 符号检验）。

用法：  .venv\\Scripts\\python rslds\\RunSurrogatePaired.py
        .venv\\Scripts\\python rslds\\RunSurrogatePaired.py --only 2   # 先跑 2 只鼠验证
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time

import numpy as np

import rslds_data as rd
from RunControl import phase_randomize
from RunFig1 import OUTDIR, K_LIST, fit_one
from RunRSLDS2 import N_OBS, BOX_SEC, build_inputs

HERE = os.path.dirname(os.path.abspath(__file__))
OUTDIR = os.path.join(HERE, "results", "fig1")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--iters", type=int, default=300)
    ap.add_argument("--seed", type=int, default=0)
    ap.add_argument("--only", type=int, default=None)
    a = ap.parse_args()
    os.makedirs(OUTDIR, exist_ok=True)

    real = json.load(open(os.path.join(OUTDIR, "fig1_summary.json"), encoding="utf-8"))
    by_mouse = {r["mouse"]: r for r in real}
    blocks = [b for b in rd.scan_cohort("ALB", phases=["Transfer"])
              if b["design"] == "LightWater"]
    if a.only:
        blocks = blocks[:a.only]

    print("=== B：逐鼠配对替代（%d 只鼠 × K=%s × %d 轮）===" % (len(blocks), K_LIST, a.iters),
          flush=True)

    rows = []
    for i, b in enumerate(blocks):
        d = rd.load_block(b["path"])
        assert rd.check_orientation(d)
        fs = d["fs"]
        u = build_inputs(d, fs)
        X = d["X"][:, d["cell_ok"] >= 1.0]
        Z = rd.zscore_cols(rd.detrend_bleach(X, fs))
        # ⚠ 替代数据在 **z-score 之后、因子分析之前** 生成：FA 是线性的，
        #   这样保证替代数据经过同一套预处理，二阶结构不被这一步改变。
        Zs = phase_randomize(Z, np.random.default_rng(a.seed + 991))
        Y, fa = rd.factor_analysis(Zs, N_OBS, seed=a.seed)
        ep = {}
        for K in K_LIST:
            t0 = time.time()
            r = fit_one(Y, u, K, a.iters, a.seed)
            ep[K] = float(r["elbos"][-1]) / len(r["z"])
            print("  [%2d/%d] %-9s 替代 K=%d  ELBO/点 %8.3f  %.0f s"
                  % (i + 1, len(blocks), b["mouse"], K, ep[K], time.time() - t0), flush=True)
        dK_sur = ep[2] - ep[1]
        dK_real = by_mouse[b["mouse"]]["dK"] if b["mouse"] in by_mouse else np.nan
        inter = dK_real - dK_sur
        print("         ΔK_真实 %+.3f   替代 %+.3f   **交互 %+.3f**   共性=%.3f"
              % (dK_real, dK_sur, inter, float(np.mean(1 - fa.noise_variance_))), flush=True)
        rows.append(dict(mouse=b["mouse"], elbo_k1=ep[1], elbo_k2=ep[2],
                         dK_sur=dK_sur, dK_real=dK_real, interaction=inter,
                         communality=float(np.mean(1 - fa.noise_variance_))))

    # 合并写入（可分批跑）
    smfile = os.path.join(OUTDIR, "surrogate_paired.json")
    old = json.load(open(smfile, encoding="utf-8")) if os.path.exists(smfile) else []
    keys = {(r["mouse"],) for r in rows}
    allrows = [r for r in old if (r["mouse"],) not in keys] + rows
    allrows.sort(key=lambda r: r["mouse"])
    with open(smfile, "w", encoding="utf-8") as fh:
        json.dump(allrows, fh, ensure_ascii=False, indent=1)

    print("\n=== 逐鼠配对汇总（%d 只）===" % len(allrows), flush=True)
    print("%-9s %10s %10s %10s" % ("鼠", "ΔK_真实", "ΔK_替代", "交互"), flush=True)
    for r in allrows:
        print("%-9s %+10.3f %+10.3f %+10.3f"
              % (r["mouse"], r["dK_real"], r["dK_sur"], r["interaction"]), flush=True)
    it = np.array([r["interaction"] for r in allrows], dtype=float)
    it = it[np.isfinite(it)]
    if it.size >= 3:
        from scipy.stats import wilcoxon
        try:
            p_w = float(wilcoxon(it, alternative="greater").pvalue)
        except ValueError:
            p_w = float("nan")
        from scipy.stats import binomtest
        npos = int((it > 0).sum())
        p_s = float(binomtest(npos, it.size, 0.5, alternative="greater").pvalue)
        print("\n交互：中位 %+.3f，均值 %+.3f，范围 %+.3f ~ %+.3f，>0 的 %d/%d"
              % (np.median(it), it.mean(), it.min(), it.max(), npos, it.size), flush=True)
        print("Wilcoxon 单侧 p = %.4f ；符号检验 p = %.4f" % (p_w, p_s), flush=True)
    print("\nDONE", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())

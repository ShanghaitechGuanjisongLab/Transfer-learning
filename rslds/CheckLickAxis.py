"""CheckLickAxis.py —— 「两个工作点」的差别里，有多少能被舔水线性解释？

`RunLickResidual.py` 给的是二元判断（回归掉舔水后 ΔK 掉不掉），这里给**效应量**：

  1. 取稳定性约束后的 K=2 拟合（`stable_<mouse>_K2_rho0.990.npz`），用后验责任 z 算出
     两个状态的**条件均值** $m_0,m_1\\in\\mathbb{R}^{15}$（在 FA 输出空间里），
     状态轴 $d=\\dfrac{m_1-m_0}{\\|m_1-m_0\\|}$，状态轴分数 $s(t)=Y_t\\cdot d$。
  2. 用滞后 −1…+1 s 的舔水轨（17 个回归量 + 截距）线性预测 $s(t)$。
  3. 关键量：**舔水能解释两个状态均值之差的多大比例**
     $$\\text{frac}=\\frac{\\hat s_1-\\hat s_0}{s_1-s_0}$$
     其中 $\\hat s_k$ 是状态 $k$ 内部的预测值均值。frac≈1 ⇒ 状态轴就是舔水；
     frac≈0 ⇒ 状态轴与舔水无关。
  4. 伪对照：舔水轨循环平移后重做（自相关相同、与钙断对齐），给出 frac 的噪声底。

另外报告状态内舔水率、状态轴间距（以数据标准差为单位）。

用法：  .venv\\Scripts\\python rslds\\CheckLickAxis.py [--only 2]
"""

from __future__ import annotations

import argparse
import glob
import json
import os
import sys

import numpy as np

import rslds_data as rd
from RunLickResidual import LAGS, lagged
from RunRSLDS2 import N_OBS, BOX_SEC, build_inputs

HERE = os.path.dirname(os.path.abspath(__file__))
FIGDIR = os.path.join(HERE, "results", "fig1")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--seed", type=int, default=0)
    ap.add_argument("--only", type=int, default=None)
    a = ap.parse_args()

    blocks = [b for b in rd.scan_cohort("ALB", phases=["Transfer"])
              if b["design"] == "LightWater"]
    if a.only:
        blocks = blocks[:a.only]

    print("=== 状态轴 vs 舔水：舔水能解释两状态均值之差的多大比例 ===", flush=True)
    print("%-9s %8s %8s %9s %9s %9s %9s"
          % ("鼠", "舔率0", "舔率1", "间距σ", "frac舔", "frac伪", "R2舔"), flush=True)
    rows = []
    for i, b in enumerate(blocks):
        f = os.path.join(FIGDIR, "stable_%s_K2_rho0.990.npz" % b["mouse"])
        if not os.path.exists(f):
            print("  %-9s 缺少 %s" % (b["mouse"], os.path.basename(f)), flush=True)
            continue
        d = rd.load_block(b["path"])
        assert rd.check_orientation(d)
        fs = d["fs"]
        X = d["X"][:, d["cell_ok"] >= 1.0]
        Z = rd.zscore_cols(rd.detrend_bleach(X, fs))
        Y, _ = rd.factor_analysis(Z, N_OBS, seed=a.seed)
        z = np.load(f)["z"]

        T = Y.shape[0]
        assert z.shape[0] == T
        hard = np.asarray(z, dtype=int)                      # T，硬状态标签
        w = np.zeros((T, 2))
        w[np.arange(T), hard] = 1.0                          # one-hot
        w /= w.sum(axis=0, keepdims=True)                    # 变成「状态内平均」权重
        m = np.array([w[:, k] @ Y for k in range(2)])        # 2×15 条件均值
        v = m[1] - m[0]
        gap = float(np.linalg.norm(v))
        ax = v / gap
        s = Y @ ax
        s_mean = np.array([w[:, k] @ s for k in range(2)])
        gap_sd = gap / float(s.std())

        lick = rd.smooth(rd.lick_indicator(d["cd2"]), max(1, int(round(BOX_SEC * fs))))
        rng = np.random.default_rng(a.seed + 7 * i)
        shift = int(rng.integers(T // 4, 3 * T // 4))

        out = {}
        for name, reg in [("lick", lick), ("sham", np.roll(lick, shift))]:
            B = np.column_stack([np.ones(T)] + [lagged(reg, L) for L in LAGS])
            coef = np.linalg.lstsq(B, s, rcond=None)[0]
            sh = B @ coef
            r2 = float(1 - (s - sh).var() / s.var())
            sh_mean = np.array([w[:, k] @ sh for k in range(2)])
            out[name] = dict(frac=float((sh_mean[1] - sh_mean[0]) / (s_mean[1] - s_mean[0])), r2=r2)

        print("%-9s %8.3f %8.3f %9.2f %+9.3f %+9.3f %9.4f"
              % (b["mouse"], lick[hard == 0].mean(), lick[hard == 1].mean(), gap_sd,
                 out["lick"]["frac"], out["sham"]["frac"], out["lick"]["r2"]),
              flush=True)
        rows.append(dict(mouse=b["mouse"], lick_rate=[float(lick[hard == 0].mean()),
                                                      float(lick[hard == 1].mean())],
                         gap_sd=gap_sd, frac_lick=out["lick"]["frac"],
                         frac_sham=out["sham"]["frac"], r2_lick=out["lick"]["r2"],
                         shift=shift))

    if rows:
        fl = np.array([r["frac_lick"] for r in rows])
        fsh = np.array([r["frac_sham"] for r in rows])
        r2 = np.array([r["r2_lick"] for r in rows])
        print("\nfrac舔：中位 %+.3f（范围 %+.3f…%+.3f）   >0.5 的鼠数 %d/%d"
              % (np.median(fl), fl.min(), fl.max(), int((fl > 0.5).sum()), len(fl)), flush=True)
        print("frac伪：中位 %+.3f（范围 %+.3f…%+.3f）"
              % (np.median(fsh), fsh.min(), fsh.max()), flush=True)
        print("R2舔：中位 %.4f（范围 %.4f…%.4f）" % (np.median(r2), r2.min(), r2.max()), flush=True)
        with open(os.path.join(FIGDIR, "lick_axis.json"), "w", encoding="utf-8") as fh:
            json.dump(rows, fh, ensure_ascii=False, indent=1)
    print("DONE", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())

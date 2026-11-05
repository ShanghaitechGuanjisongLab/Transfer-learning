"""CheckInputShift.py —— 一步变化里，输入项 vs 自回归项，谁在主导？

**为什么不用定点**：模型是 $x_{t+1}=A_kx_t+b_k+V_ku_t$，定点 $x^*=(I-A_k)^{-1}(b_k+V_ku)$。
当 $\\rho\\to1$ 时 $I-A_k$ 病态（$\\rho=0.99$ 条件数 ~100，$\\rho=0.998$ ~500），
$x^*$ 就成了一个**数值上无意义**的量 —— 实测：输入依赖的定点会移动 16–73 σ，
而真实潜状态跟它的相关只有 0.03–0.18。所以在近单位根的模型里，
**"定点在哪、移动多少"都不能当证据**（这条同时打掉"定点在数据中央"那个说法的分量）。

改用良态的口径：把一步预测变化拆成两项
  · 自回归（回复）项  $D_t=(A_k-I)x_t+b_k$
  · 输入项            $I_t=V_ku_t$
比较 $\\|I_t\\|/\\|D_t\\|$：
  · $\\ll1$ ⇒ 动力学由回复项主导，$x$ 被拉在一个慢流形上，"吸引子"式描述自洽
  · $\\gg1$ ⇒ 系统基本被输入推着走，"自主动力学/吸引子"的描述就没有立足点

另报 $I-A$ 的条件数，作为"定点类结论不可用"的量化依据。

用法：  .venv\\Scripts\\python rslds\\CheckInputShift.py [--only 2] [--K 1 2]
"""

from __future__ import annotations

import argparse
import json
import os
import sys

import numpy as np

import rslds_data as rd

HERE = os.path.dirname(os.path.abspath(__file__))
FIGDIR = os.path.join(HERE, "results", "fig1")
INPUT_NAMES = ["cue", "lick1s", "water", "lickOnset", "lickRate", "lick^2", "lick0.25s", "lick2s"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", type=int, default=None)
    ap.add_argument("--K", type=int, nargs="+", default=[1, 2])
    a = ap.parse_args()

    blocks = [b for b in rd.scan_cohort("ALB", phases=["Transfer"])
              if b["design"] == "LightWater"]
    if a.only:
        blocks = blocks[:a.only]

    print("=== 一步变化：输入项 vs 自回归（回复）项 ===", flush=True)
    print("%-9s %2s %2s %7s %8s %10s %10s %9s %8s  %s"
          % ("鼠", "K", "状", "|λ|", "cond", "‖回复‖中位", "‖输入‖中位", "比值中位",
             "输入>回复", "主贡献输入"), flush=True)
    rows = []
    for b in blocks:
        for K in a.K:
            f = os.path.join(FIGDIR, "rich_%s_K%d.npz" % (b["mouse"], K))
            if not os.path.exists(f):
                continue
            z = np.load(f)
            x, As, bs, Vs, u = z["x"], z["As"], z["bs"], z["Vs"], z["u"]
            if Vs.ndim == 2:
                Vs = Vs[None]
            lab = z["z"].astype(int)
            T, D = x.shape
            occ = np.array([(lab == k).mean() for k in range(K)])

            for k in range(K):
                sel = lab == k
                if sel.sum() < 20:
                    continue
                M = np.eye(D) - As[k]
                cond = float(np.linalg.cond(M))
                rho = float(np.max(np.abs(np.linalg.eigvals(As[k]))))
                xk = x[sel]
                uk = u[sel]
                Dv = xk @ (As[k] - np.eye(D)).T + bs[k]          # 回复项
                Iv = uk @ Vs[k].T                                 # 输入项
                dn = np.linalg.norm(Dv, axis=1)
                inn = np.linalg.norm(Iv, axis=1)
                ratio = inn / (dn + 1e-12)
                # 各输入列的贡献
                colnorm = np.array([np.median(np.abs(uk[:, j]) * np.abs(Vs[k][:, j]).sum())
                                    for j in range(u.shape[1])])
                jmax = int(np.argmax(colnorm))
                print("%-9s %2d %2d %7.3f %8.0f %10.4f %10.4f %9.3f %7.0f%%  %s"
                      % (b["mouse"], K, k, rho, cond, np.median(dn), np.median(inn),
                         np.median(ratio), 100 * (ratio > 1).mean(), INPUT_NAMES[jmax]),
                      flush=True)
                rows.append(dict(mouse=b["mouse"], K=K, state=k, rho=rho, occ=float(occ[k]),
                                 cond_IA=cond, drift_median=float(np.median(dn)),
                                 input_median=float(np.median(inn)),
                                 ratio_median=float(np.median(ratio)),
                                 frac_input_dominates=float((ratio > 1).mean()),
                                 dominant_input=INPUT_NAMES[jmax],
                                 col_contrib={INPUT_NAMES[j]: float(colnorm[j])
                                              for j in range(len(INPUT_NAMES))}))

    sm = os.path.join(FIGDIR, "input_shift.json")
    blob = json.dumps(rows, ensure_ascii=False, indent=1)
    with open(sm, "w", encoding="utf-8") as fh:
        fh.write(blob)

    print("\n=== 汇总（%d 个状态）===" % len(rows), flush=True)
    g = lambda key, K=None: np.array([r[key] for r in rows
                                      if (K is None or r["K"] == K)], dtype=float)
    for K in a.K:
        r_ = g("ratio_median", K)
        if r_.size == 0:
            continue
        print("K=%d：‖输入‖/‖回复‖ 中位 %.3f（%.2f–%.2f）；>1 的状态 %d/%d"
              % (K, np.median(r_), r_.min(), r_.max(), int((r_ > 1).sum()), r_.size), flush=True)
    print("I−A 条件数：中位 %.0f（%.0f–%.0f）"
          % (np.median(g("cond_IA")), g("cond_IA").min(), g("cond_IA").max()), flush=True)
    print("主贡献输入：%s"
          % ", ".join("%s×%d" % (k, sum(1 for r in rows if r["dominant_input"] == k))
                      for k in sorted({r["dominant_input"] for r in rows})), flush=True)
    print("\n判据：比值 ≪1 ⇒ 回复项主导，慢流形/吸引子式描述自洽；≫1 ⇒ 基本被输入推着走",
          flush=True)
    print("DONE", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())

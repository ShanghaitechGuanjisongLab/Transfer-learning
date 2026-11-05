"""CheckStableWells.py —— 约束之后，两个定点在哪、数据是否双峰？

约束掉 |λ|≤0.99 之后 $I-A_k$ 不再奇异，**定点重新存在**。于是可以回答：
  · 定点是否落在数据实际覆盖的范围内？
  · 沿两定点连线方向，潜状态分布是否双峰（两个盆地）还是连续体？
  · 两定点相距多少个标准差（太近 = 谈不上两个坑）

统计：
  ΔBIC = BIC(2 成分 GMM) − BIC(1 成分)，负 = 支持双峰
  分离度 = 后验责任 > 0.8 的比例
  间距 = |投影(Δ定点)| / 投影的标准差

用法：  .venv\\Scripts\\python rslds\\CheckStableWells.py
"""

from __future__ import annotations

import glob
import json
import os

import numpy as np
from sklearn.mixture import GaussianMixture

HERE = os.path.dirname(os.path.abspath(__file__))
FIGDIR = os.path.join(HERE, "results", "fig1")


def fixed_points(As, bs):
    D = As.shape[1]
    out = np.full((As.shape[0], D), np.nan)
    for k in range(As.shape[0]):
        M = np.eye(D) - As[k]
        if abs(np.linalg.det(M)) > 1e-10:
            out[k] = np.linalg.solve(M, bs[k])
    return out


def main():
    files = sorted(glob.glob(os.path.join(FIGDIR, "stable_*_K2_*.npz")))
    print("=== 约束后（|λ|≤ρ_max）的两个定点与双峰性 ===", flush=True)
    print("%-9s %10s %8s %9s %8s %7s | %s"
          % ("鼠", "ρ(每状态)", "定点%1", "定点%2", "ΔBIC", "分离", "间距σ"), flush=True)
    rows = []
    for f in files:
        z = np.load(f)
        mouse = os.path.basename(f).split("_")[1]
        As, bs, x = z["As"], z["bs"], z["x"]
        rho = [float(np.max(np.abs(np.linalg.eigvals(A)))) for A in As]
        fp = fixed_points(As, bs)
        if not np.all(np.isfinite(fp)):
            print("%-9s %s 定点仍不全" % (mouse, np.round(rho, 3).tolist()), flush=True)
            continue
        e1 = fp[1] - fp[0]
        e1 = e1 / np.linalg.norm(e1)
        t = x @ e1
        pos = [float((t < (fp[k] @ e1)).mean() * 100) for k in range(2)]
        gap = float(abs((fp[1] - fp[0]) @ e1) / (t.std() + 1e-12))
        tt = t[:, None]
        g1 = GaussianMixture(1, random_state=0).fit(tt)
        g2 = GaussianMixture(2, n_init=5, random_state=0).fit(tt)
        dbic = float(g2.bic(tt) - g1.bic(tt))
        sep = float((g2.predict_proba(tt).max(axis=1) > 0.8).mean())
        print("%-9s %10s %8.1f %9.1f %9.1f %7.3f | 间距 %.2fσ"
              % (mouse, np.round(rho, 3).tolist(), pos[0], pos[1], dbic, sep, gap), flush=True)
        rows.append(dict(mouse=mouse, rho=rho, fp_percentiles=pos, gap_sd=gap,
                         dBIC=dbic, separation=sep))

    if rows:
        g = np.array([r["gap_sd"] for r in rows])
        s = np.array([r["separation"] for r in rows])
        pin = np.mean([[0 < p < 100 for p in r["fp_percentiles"]] for r in rows], axis=1)
        print("\n两定点间距：中位 %.2f σ（范围 %.2f–%.2f）" % (np.median(g), g.min(), g.max()), flush=True)
        print("分离度 >0.8 的鼠数：%d/%d" % ((s > 0.8).sum(), len(s)), flush=True)
        print("两个定点都落在数据内的鼠数：%d/%d" % (int((pin == 1).sum()), len(rows)), flush=True)
        with open(os.path.join(FIGDIR, "stable_wells.json"), "w", encoding="utf-8") as fh:
            json.dump(rows, fh, ensure_ascii=False, indent=1)
    print("DONE", flush=True)


if __name__ == "__main__":
    raise SystemExit(main())

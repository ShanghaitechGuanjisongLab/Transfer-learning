"""CheckBimodality.py —— 数据支撑"两个坑"吗？还是只是一个连续体被切成两段？

背景：ΔK 的配对检验通过了（11/11，p=0.0005），说明"2 个线性动力学体制"显著优于 1 个。
**但"两个体制"不等于"两个吸引子"**。要称"坑"，至少还需要两条：

 (1) **潜状态沿两定点连线方向（轴 e1）是双峰的**：
     若双峰 → 数据真的在两组之间来回，像两个盆地；
     若单峰/平坦 → 只是把一个连续体切成两段，"坑"是模型的措辞而不是数据的性质。

 (2) **定点落在数据实际覆盖的范围内**：
     若某定点远在数据分布之外，它不可能是"坑"——数据从没到过那儿。

统计：
 · ΔBIC = BIC(2 成分高斯混合) − BIC(1 成分)。**负值 = 支持双峰**。
 · 分离度 = 后验责任 > 0.8 的样本占比（1 = 两组完全分开）。
 · 定点在投影轴上的百分位（0–100）。落在 ~0–100 之外 = 在数据外。

用法：  .venv\\Scripts\\python rslds\\CheckBimodality.py
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
        if abs(np.linalg.det(M)) > 1e-8:
            out[k] = np.linalg.solve(M, bs[k])
    return out


def main():
    files = sorted(glob.glob(os.path.join(FIGDIR, "fig1_*_K2.npz")))
    print("=== 数据是否支撑「两个坑」===", flush=True)
    print("%-9s %8s %9s %9s %9s %8s %8s | %s"
          % ("鼠", "|λ|max", "min|1-λ|", "det(I-A)", "ΔBIC", "分离度", "定点%", "判读"),
          flush=True)
    rows = []
    for f in files:
        z = np.load(f)
        mouse = os.path.basename(f).split("_")[1]
        As, bs, x = z["As"], z["bs"], z["x"]
        D, K = As.shape[1], As.shape[0]
        evs = [np.linalg.eigvals(As[k]) for k in range(K)]
        lmax = float(np.abs(np.concatenate(evs)).max())
        d1 = float(np.min(np.abs(1 - np.concatenate(evs))))
        dmin = float(np.min([abs(np.linalg.det(np.eye(D) - As[k])) for k in range(K)]))
        fp = fixed_points(As, bs)
        ok = np.all(np.isfinite(fp), axis=1)
        if ok.sum() < 2:
            print("%-9s %8.3f %9.4f %9.1e %9s %9s %8s | **无定点（近积分器 λ≈1）**"
                  % (mouse, lmax, d1, dmin, "-", "-", "-"), flush=True)
            rows.append(dict(mouse=mouse, lambda_max=lmax, min_dist_to_1=d1,
                             det_min=dmin, dBIC=None, separation=None,
                             fp_percentiles=None, verdict="无定点（近积分器）"))
            continue
        e1 = fp[1] - fp[0]
        e1 = e1 / np.linalg.norm(e1)
        t = x @ e1
        tt = t[:, None]

        g1 = GaussianMixture(1, random_state=0).fit(tt)
        g2 = GaussianMixture(2, n_init=5, random_state=0).fit(tt)
        dbic = float(g2.bic(tt) - g1.bic(tt))
        resp = g2.predict_proba(tt)
        sep = float((resp.max(axis=1) > 0.8).mean())
        pos = [float((t < (fp[k] @ e1)).mean() * 100) for k in range(2)]
        lmax = float(np.abs(np.linalg.eigvals(As)).max())

        if dbic < -10 and sep > 0.8 and all(0 < p < 100 for p in pos):
            verdict = "像两个坑"
        elif dbic < -10:
            verdict = "双峰但分离差 / 定点在外"
        else:
            verdict = "**单峰/连续体**"
        print("%-9s %8.3f %9.4f %9.1e %9.1f %9.3f %8.1f | %s"
              % (mouse, lmax, d1, dmin, dbic, sep, pos[0], verdict), flush=True)
        rows.append(dict(mouse=mouse, lambda_max=lmax, min_dist_to_1=d1, det_min=dmin,
                         dBIC=dbic, separation=sep, fp_percentiles=pos, verdict=verdict))

    n_nofp = sum(1 for r in rows if r["dBIC"] is None)
    n_bimodal = sum(1 for r in rows if r["dBIC"] is not None and r["dBIC"] < -10)
    n_sep = sum(1 for r in rows if r["separation"] is not None and r["separation"] > 0.8)
    n_conv = sum(1 for r in rows if r["lambda_max"] < 1.0)
    n_int = sum(1 for r in rows if r["min_dist_to_1"] < 0.02)
    print("\n无定点（近积分器 λ≈1）：%d/%d" % (n_nofp, len(rows)), flush=True)
    print("至少一个状态 min|1-λ|<0.02（近积分器）：%d/%d" % (n_int, len(rows)), flush=True)
    print("所有状态都收缩（|λ|max < 1）：%d/%d" % (n_conv, len(rows)), flush=True)
    print("支持双峰（ΔBIC < −10）：%d/%d" % (n_bimodal, len(rows)), flush=True)
    print("两组分离度 > 0.8：%d/%d" % (n_sep, len(rows)), flush=True)
    with open(os.path.join(FIGDIR, "bimodality.json"), "w", encoding="utf-8") as fh:
        json.dump(rows, fh, ensure_ascii=False, indent=1)
    print("DONE", flush=True)


if __name__ == "__main__":
    raise SystemExit(main())

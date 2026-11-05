"""Step0c_CopyCheck.py —— 「100% 细胞交集 + 完全有限」是真实的，还是填充/拷贝的？（只读）

如果导出时对某些细胞做了拷贝或前向填充，它们两场的均值/标准差会**完全相同**。
判据：统计 mean 与 sd 在两场之间「相对差 < 1e-6」的细胞数。真实独立记录应为 0。
同时报跨细胞的相关，确认是同一批细胞（应高度相关但不完全相同）。
"""
from __future__ import annotations

import json
import os

import numpy as np

from rslds_data import load_block, scan_cohort

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "results", "_step0c_copycheck.json")

TOL = 1e-6


def main():
    ms = scan_cohort("ALB")
    by_mouse = {}
    for m in ms:
        by_mouse.setdefault(m["mouse"], {}).setdefault(m["phase"], []).append(m)

    rows = []
    for mouse in sorted(by_mouse):
        ph = by_mouse[mouse]
        if "Learned" not in ph or "Transfer" not in ph:
            continue
        dL = load_block(ph["Learned"][0]["path"])
        dT = load_block(ph["Transfer"][0]["path"])
        XL, XT = dL["X"], dT["X"]

        iL = {int(u): i for i, u in enumerate(dL["cell_uid"])}
        iT = {int(u): i for i, u in enumerate(dT["cell_uid"])}
        common = sorted(set(iL) & set(iT))
        cL = np.array([iL[u] for u in common])
        cT = np.array([iT[u] for u in common])

        mL, sL = np.nanmean(XL[:, cL], 0), np.nanstd(XL[:, cL], 0)
        mT, sT = np.nanmean(XT[:, cT], 0), np.nanstd(XT[:, cT], 0)

        rel_m = np.abs(mL - mT) / np.maximum(np.abs(mT), 1e-12)
        rel_s = np.abs(sL - sT) / np.maximum(np.abs(sT), 1e-12)

        rows.append(dict(
            mouse=mouse, n=len(common),
            n_mean_identical=int((rel_m < TOL).sum()),
            n_sd_identical=int((rel_s < TOL).sum()),
            corr_mean=float(np.corrcoef(mL, mT)[0, 1]),
            corr_sd=float(np.corrcoef(sL, sT)[0, 1]),
            mean_ratio_median=float(np.median(mL / np.maximum(mT, 1e-12))),
            sd_ratio_median=float(np.median(sL / np.maximum(sT, 1e-12))),
        ))

    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(rows, indent=2, ensure_ascii=False))

    hdr = (f"{'mouse':<9s}{'n':>5s}{'meanId':>8s}{'sdId':>6s}"
           f"{'corrMean':>10s}{'corrSD':>9s}{'meanRat':>9s}{'sdRat':>8s}")
    print(hdr)
    print("-" * len(hdr))
    for r in rows:
        print(f"{r['mouse']:<9s}{r['n']:5d}{r['n_mean_identical']:8d}{r['n_sd_identical']:6d}"
              f"{r['corr_mean']:10.3f}{r['corr_sd']:9.3f}"
              f"{r['mean_ratio_median']:9.3f}{r['sd_ratio_median']:8.3f}")
    print(f"\n写出：{OUT}")


if __name__ == "__main__":
    main()

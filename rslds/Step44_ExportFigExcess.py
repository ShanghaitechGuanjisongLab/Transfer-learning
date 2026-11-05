"""Step44_ExportFigExcess.py —— 为 FigAttractorSchematic 导出逐鼠严格口径超额

不产生新估计，只从 results/_step32_m6_variants.json 抽 (MOp2/3, 指定 variant) 的
res_excess（扣定型弧后的超额，严格口径）成作图用的长表。

用法:  python Step44_ExportFigExcess.py [P0|P1|P2]   （默认 P1 = 主分析）
"""
from __future__ import annotations

import csv
import json
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
RES = os.path.join(HERE, "results")
PHASES = ["Learned", "Transfer", "Final"]


def main():
    variant = sys.argv[1] if len(sys.argv) > 1 else "P1"
    with open(os.path.join(RES, "_step32_m6_variants.json"), encoding="utf-8") as fh:
        data = json.load(fh)

    rows = [x for x in data if x["group"] == "MOp2/3" and x["variant"] == variant]
    rows.sort(key=lambda x: (PHASES.index(x["phase"]), x["mouse"]))

    out = os.path.join(RES, "_fig_excess_by_phase.csv")
    with open(out, "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(["mouse", "phase", "res_excess", "res_null", "res_p95", "n_cell"])
        for x in rows:
            w.writerow([x["mouse"], x["phase"],
                        f"{x['res_excess']:.6f}", f"{x['res_null']:.6f}",
                        f"{x['res_p95']:.6f}", x["n_cell"]])

    print(f"variant = {variant}   group = MOp2/3   rows = {len(rows)}")
    for ph in PHASES:
        v = np.array([x["res_excess"] for x in rows if x["phase"] == ph], dtype=float)
        n = len(v)
        if n == 0:
            continue
        from scipy.stats import wilcoxon
        print(f"  {ph:<9s} n={n:2d}  median={np.median(v):+.4f}  "
              f"mean={v.mean():+.4f}  n>0={int((v > 0).sum())}/{n}")
    a = np.array([x["res_excess"] for x in rows if x["phase"] == "Learned"], dtype=float)
    b = np.array([x["res_excess"] for x in rows if x["phase"] == "Transfer"], dtype=float)
    if len(a) == len(b) and len(a) >= 5:
        from scipy.stats import wilcoxon
        print(f"  L vs T paired Wilcoxon p = {wilcoxon(a, b).pvalue:.4g}")
    print(f"wrote {out}")


if __name__ == "__main__":
    main()

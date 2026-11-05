"""Step0e_BrightnessStratified.py —— 分层看跨场身份相关，排除"暗细胞噪声主导"这一良性解释

Step0d 发现部分鼠 Learned↔Transfer 的逐细胞平均荧光相关很低（vtf0353 仅 0.075）。
CellUID 既然是全局身份，低相关只可能有两种原因：
  (i) 良性：某场整体偏暗，弱表达细胞的均值被散粒噪声主导 → 只看亮的细胞应恢复高相关
  (ii) 真问题：ROI 配准错位 / 视野变化 → 亮细胞的相关也仍然低

判据：按参照场（Learned）的细胞亮度取前 100% / 50% / 25% / 10% 分层，分别算相关。
"""
from __future__ import annotations

import json
import os

import numpy as np
import pandas as pd

from rslds_data import load_block, scan_cohort

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "results", "_step0e_brightness.json")
FRACS = [1.0, 0.5, 0.25, 0.10]


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
        sL = pd.Series(np.nanmean(dL["X"], 0), index=[int(u) for u in dL["cell_uid"]])
        sT = pd.Series(np.nanmean(dT["X"], 0), index=[int(u) for u in dT["cell_uid"]])
        idx = sL.index.intersection(sT.index)
        sL, sT = sL.loc[idx], sT.loc[idx]

        # 参照 = Learned 场亮度；亮度即基线表达量，跨场应稳定
        order = np.argsort(-sL.values)
        rec = dict(mouse=mouse, n_common=int(len(idx)))
        for f in FRACS:
            k = max(5, int(round(len(idx) * f)))
            sel = order[:k]
            rec[f"r_top{int(f*100)}"] = float(np.corrcoef(sL.values[sel], sT.values[sel])[0, 1])
        # 亮度本身在两场的分布比（判断是否某场整体偏暗）
        rec["bright_ratio_median"] = float(np.median(sL.values / np.maximum(sT.values, 1e-12)))
        rows.append(rec)

    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(rows, indent=2, ensure_ascii=False))

    hdr = (f"{'mouse':<9s}{'n':>5s}{'r_all':>8s}{'r_top50':>9s}{'r_top25':>9s}"
           f"{'r_top10':>9s}{'brightRat':>11s}")
    print(hdr)
    print("-" * len(hdr))
    for r in rows:
        print(f"{r['mouse']:<9s}{r['n_common']:5d}{r['r_top100']:8.3f}{r['r_top50']:9.3f}"
              f"{r['r_top25']:9.3f}{r['r_top10']:9.3f}{r['bright_ratio_median']:11.3f}")
    print(f"\n写出：{OUT}")


if __name__ == "__main__":
    main()

"""Step0d_PairCorr.py —— 逐场之间「细胞亮度模式」的相关（判定跨场细胞身份是否可靠）

对每只鼠：以该鼠**第一场**为参照，算每一场与之的 corr(逐细胞平均荧光)。
同一批真实细胞在任意两场之间应保持 r ≈ 0.8-0.99（亮度/深度不变）。
若某场突然掉到 ~0.1，说明该场的「同 UID 细胞」实际上不是同一批细胞。
"""
from __future__ import annotations

import json
import os

import numpy as np
import pandas as pd

from rslds_data import load_block, scan_cohort

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "results", "_step0d_paircorr.json")


def main():
    ms = scan_cohort("ALB")
    by_mouse = {}
    for m in ms:
        by_mouse.setdefault(m["mouse"], []).append(m)

    blob = {}
    for mouse in sorted(by_mouse):
        sess = sorted(by_mouse[mouse], key=lambda x: x["datetime"])
        means, labels = [], []
        for m in sess:
            d = load_block(m["path"])
            means.append(pd.Series(np.nanmean(d["X"], 0),
                                   index=[int(u) for u in d["cell_uid"]]))
            labels.append(f"{m['phase'] or '-'}/{m['design']}@{m['datetime'][5:16]}"
                          f" [n={len(d['cell_uid'])}]")
        ref = means[0]
        cors = []
        for x in means:
            idx = ref.index.intersection(x.index)
            cors.append(float(np.corrcoef(ref.loc[idx].values, x.loc[idx].values)[0, 1]))
        blob[mouse] = dict(labels=labels, corr_vs_first=cors,
                           mean_min=float(min(cors)), mean_max=float(max(cors)))
        print(f"\n{mouse}  （{'n='+str(len(sess))}，参照=第一场）")
        for lab, c in zip(labels, cors):
            flag = "  <-- 低" if c < 0.6 else ""
            print(f"   r={c:6.3f}  {lab}{flag}")

    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(blob, indent=2, ensure_ascii=False))
    print(f"\n写出：{OUT}")


if __name__ == "__main__":
    main()

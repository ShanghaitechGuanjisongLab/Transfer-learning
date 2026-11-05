"""_check_signal_scale.py —— 判断导出的 X 是 raw F 还是 ΔF/F

判据（决定性）：
  raw F      : 全部 >= 0，有大的直流偏置，细胞均值量级 1e2~1e4
  ΔF/F       : 均值 ≈ 0，约 40~50% 的值为负
另报：细胞间均值差异（raw F 会很大，ΔF/F 已归一化）
"""
import glob
import json
import os
import sys

import h5py
import numpy as np

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "results", "_signal_scale.json")
os.makedirs(os.path.dirname(OUT), exist_ok=True)

rows = []
for cohort in ["ALB", "LightAudioBaseline"]:
    files = sorted(glob.glob(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                          "data", cohort, "*.mat")))
    for fp in files[:3]:
        with h5py.File(fp, "r") as f:
            A = f["X"][:]  # (nSamp, nCell)  —— v7.3 转置后即 T×N
            fs = float(np.squeeze(f["fs"][:]))
        A = np.asarray(A, dtype=float)
        cm = np.nanmean(A, axis=0)
        cs = np.nanstd(A, axis=0)
        rows.append(dict(
            file=os.path.basename(fp), cohort=cohort,
            shape=list(A.shape), fs=fs,
            frac_neg=float(np.mean(A < 0)),
            glob_min=float(np.nanmin(A)), glob_max=float(np.nanmax(A)),
            glob_median=float(np.nanmedian(A)),
            cellmean_median=float(np.median(cm)),
            cellmean_min=float(np.min(cm)), cellmean_max=float(np.max(cm)),
            cellstd_median=float(np.median(cs)),
            cv_across_cells=float(np.std(cm) / max(abs(np.mean(cm)), 1e-12)),
            frac_cellmean_neg=float(np.mean(cm < 0)),
        ))

blob = json.dumps(rows, indent=2, ensure_ascii=False)
with open(OUT, "w", encoding="utf-8") as fh:
    fh.write(blob)
print(blob)

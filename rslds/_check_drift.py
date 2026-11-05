"""_check_drift.py —— raw F 的慢漂移有多大？（决定新方法要不要先去趋势）

对每个文件、每个细胞：
  trend_pct   : 线性趋势在整段 session 上的相对变化（% of mean）
  slow_r2_cub : 三次多项式（= 极慢漂移代理）解释的方差比例
然后取细胞中位数。另给出群体均值轨迹的 1/f 低频能量占比。
"""
import glob
import json
import os

import h5py
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "results", "_drift.json")
os.makedirs(os.path.dirname(OUT), exist_ok=True)

rows = []
for cohort in ["ALB", "LightAudioBaseline"]:
    files = sorted(glob.glob(os.path.join(HERE, "data", cohort, "*.mat")))
    for fp in files[:3]:
        with h5py.File(fp, "r") as f:
            A = np.asarray(f["X"][:], dtype=float)  # T x N
            fs = float(np.squeeze(f["fs"][:]))
        T, N = A.shape
        t = np.linspace(-1, 1, T)
        V = np.vander(t, 4)                      # 1, t, t^2, t^3
        trend, r2c = [], []
        for j in range(N):
            y = A[:, j]
            if not np.all(np.isfinite(y)):
                continue
            m = y.mean()
            b = np.polyfit(t, y, 1)
            trend.append(100.0 * b[0] * 2.0 / max(abs(m), 1e-9))   # 整段相对变化 %
            beta, *_ = np.linalg.lstsq(V, y - y.mean(), rcond=None)
            res = (y - y.mean()) - V @ beta
            r2c.append(1.0 - res.var() / max((y - y.mean()).var(), 1e-12))
        pop = A.mean(axis=1)
        P = np.abs(np.fft.rfft(pop - pop.mean())) ** 2
        fr = np.fft.rfftfreq(len(pop), d=1.0 / fs)
        lo = (fr > 0) & (fr < 0.02)              # < 0.02 Hz ≈ 50 s 以上
        rows.append(dict(
            file=os.path.basename(fp), cohort=cohort, fs=round(fs, 3),
            nCell=N, durMin=round(T / fs / 60, 1),
            trend_abs_pct_median=float(np.median(np.abs(trend))),
            trend_abs_pct_p90=float(np.percentile(np.abs(trend), 90)),
            trend_abs_pct_max=float(np.max(np.abs(trend))),
            cub_r2_median=float(np.median(r2c)),
            cub_r2_p90=float(np.percentile(r2c, 90)),
            lowfreq_frac_pop=float(P[lo].sum() / max(P.sum(), 1e-30)),
        ))

blob = json.dumps(rows, indent=2, ensure_ascii=False)
with open(OUT, "w", encoding="utf-8") as fh:
    fh.write(blob)
print(blob)

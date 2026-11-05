"""AnalyzePilot2.py —— 用 RunRSLDS2.py 存下的 npz 做补充检验（不重拟合）

补的是第一轮里漏掉的一半：状态除了 cue/给水，与**舔水**有关吗？
判据同样用置换 null：把舔水轨整体循环平移一个随机量再重算，
统计量 = 各状态舔水率的极差（max-min），p = (1+#{null>=obs})/(n_perm+1)。

另外算一个"状态到底有没有把舔水切开"的直观量：状态内舔水率的极差。

用法：  .venv\\Scripts\\python rslds\\AnalyzePilot2.py
"""

from __future__ import annotations

import glob
import json
import os

import numpy as np

import rslds_data as rd

HERE = os.path.dirname(os.path.abspath(__file__))
OUTDIR = os.path.join(HERE, "results")
BLOCK = "ALB_yqn0133_20240517-0835_AudioWater.mat"
N_PERM = 500
BOX_SEC = 1.0


def main():
    d = rd.load_block(os.path.join(rd.DATA_ROOT, "ALB", BLOCK))
    fs = d["fs"]
    lick = rd.smooth(rd.lick_indicator(d["cd2"]), max(1, int(round(BOX_SEC * fs))))
    rng = np.random.default_rng(0)

    print("=== 状态 × 舔水（置换 null，%d 次）===" % N_PERM, flush=True)
    rows = []
    for f in sorted(glob.glob(os.path.join(OUTDIR, "pilot2_*.npz"))):
        tag = os.path.basename(f)[len("pilot2_"):-len(".npz")]
        npz = np.load(f)
        z = npz["z"].astype(int)
        K = int(z.max()) + 1
        T = z.size
        rate = np.array([lick[z == k].mean() if (z == k).any() else np.nan for k in range(K)])
        obs = float(np.nanmax(rate) - np.nanmin(rate))
        null = np.empty(N_PERM)
        for i in range(N_PERM):
            s = int(rng.integers(0, T))
            lk = np.roll(lick, s)
            r2 = np.array([lk[z == k].mean() if (z == k).any() else np.nan for k in range(K)])
            null[i] = np.nanmax(r2) - np.nanmin(r2)
        p = (1 + (null >= obs).sum()) / (N_PERM + 1)
        print("  %-16s 状态内舔水率 %s  |  极差 %.3f  vs null95 %.3f  →  p=%.3f"
              % (tag, np.round(rate, 3).tolist(), obs, float(np.percentile(null, 95)), p), flush=True)
        rows.append(dict(tag=tag, lick_rate_in_state=[float(v) for v in rate],
                         spread=obs, p_perm=float(p)))

    with open(os.path.join(OUTDIR, "pilot2_lick_test.json"), "w", encoding="utf-8") as fh:
        json.dump(rows, fh, ensure_ascii=False, indent=1)

    sig = [r for r in rows if r["p_perm"] < 0.05]
    print("\n⇒ %s" % ("有状态与舔水显著关联：%s" % [r["tag"] for r in sig] if sig
                      else "**没有任何状态与舔水显著关联**（全部 p>0.05）"), flush=True)
    print("DONE", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

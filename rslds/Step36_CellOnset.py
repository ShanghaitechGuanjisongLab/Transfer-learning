"""Step36_CellOnset.py —— 逐细胞响应起始潜伏期分布

Step34/35 已确认
  · idx_cue ≡ CD1 上升沿（偏移 0–0.13 s，990/990 <0.5 s）⇒ 无对齐偏移
  · 给水中位潜伏期 21.8 s（IQR 9.8–31.6）⇒ 晚峰不是给水锁定
  · miss trial 的晚峰与 hit 相当（PSTH@3s: miss 0.077 vs hit 0.049）⇒ 不是奖赏
  · 群体平均曲线在 1.5 s 之后是**宽平台**，argmax 在不同口径下 1.85–3.25 s

本脚本回答最后一个问题：**单个细胞什么时候开始响应？**
  · 基线：[−1.0, 0] s 的均值与稳健 SD（1.4826×MAD）
  · 起始：τ>0 首次连续 3 帧 |z − base| > 3σ 的时刻
  · 同时给出逐细胞峰潜伏期（对 z 做 0.15 s 平滑后）
  · 按层（MOp2/3 vs MOp5）分开统计
"""
from __future__ import annotations

import json
import os

import numpy as np

import attractor_core as AC
from rslds_data import load_block, scan_cohort

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "results", "_step36_onset.json")
PHASES = ["Learned", "Transfer", "Final"]
MIN_CELL = 40
STEP = 0.05
TAUS = np.arange(-1.0, 5.0 + 1e-9, STEP)


def smooth(x, n=3):
    k = np.ones(n) / n
    return np.convolve(x, k, mode="same")


def main():
    ms = scan_cohort("ALB", phases=PHASES)
    onset = {0: [], 1: [], 2: []}
    peak = {0: [], 1: [], 2: []}
    ncell = {0: 0, 1: 0, 2: 0}
    for b in ms:
        d = load_block(b["path"])
        fs = d["fs"]
        Y0 = np.nan_to_num(AC.dff(d["X"], fs), nan=0.0, posinf=0.0, neginf=0.0)
        ok = np.std(Y0, axis=0) > 1e-9
        if int(ok.sum()) < MIN_CELL:
            continue
        cue = np.sort(np.asarray(d.get("idx_cue", []), dtype=np.int64))
        if len(cue) < 10:
            continue
        zl = np.asarray(d.get("z_layer", np.zeros(Y0.shape[1], dtype=np.int64)))[ok]
        Z = AC.zscore_robust(AC.VARIANTS["P1"](Y0[:, ok], fs))
        rows = []
        for c in cue:
            a = int(c) + int(round(TAUS[0] * fs))
            bb = int(c) + int(round(TAUS[-1] * fs))
            if a < 0 or bb > len(Z):
                continue
            base = Z[a]
            seg = np.empty((len(TAUS), Z.shape[1]))
            for k, tau in enumerate(TAUS):
                seg[k] = Z[int(c) + int(round(tau * fs))]
            rows.append(seg - base)
        if len(rows) < 10:
            continue
        R = np.median(np.stack(rows), axis=0)          # (nTau, nCell)
        pre = TAUS < 0
        base_m = np.median(R[pre], axis=0)
        base_sd = 1.4826 * np.median(np.abs(R[pre] - base_m), axis=0)
        base_sd = np.maximum(base_sd, 1e-3)
        post = np.where(TAUS >= 0)[0]
        for j, lc in enumerate(zl):
            lc = int(lc) if int(lc) in (1, 2) else 0
            ncell[lc] += 1
            d_ = R[:, j] - base_m[j]
            thr = 3.0 * base_sd[j]
            above = np.abs(d_) > thr
            run = np.convolve(above.astype(int), np.ones(3, dtype=int), mode="valid")
            hit = np.where(run >= 3)[0]
            if len(hit):
                onset[lc].append(float(TAUS[hit[0]]))
            sm = smooth(d_, 3)
            if np.isfinite(sm[post]).all():
                peak[lc].append(float(TAUS[post][int(np.argmax(np.abs(sm[post])))]))
        print(f"  {b['mouse']:<9s}{b['phase']:<9s} nCell={int(ok.sum())}")

    print(f"\n=== 逐细胞起始潜伏期（3σ 连续 3 帧准则）===")
    print(f"{'层':<10s}{'nCell':>7s}{'有响应':>8s}{'起始中位':>10s}"
          f"{'IQR':>16s}{'<1s':>8s}{'1-2s':>8s}{'>2s':>8s}{'峰中位':>9s}")
    res = {}
    names = {0: "pooled", 1: "MOp2/3", 2: "MOp5"}
    for lc in (0, 1, 2):
        o = np.array(onset[lc])
        p = np.array(peak[lc])
        if len(o) < 20:
            continue
        print(f"{names[lc]:<10s}{ncell[lc]:7d}{len(o):8d}{np.median(o):10.2f}"
              f"{('%0.2f–%0.2f' % (np.percentile(o,25), np.percentile(o,75))):>16s}"
              f"{100*np.mean(o<1):7.0f}%{100*np.mean((o>=1)&(o<2)):7.0f}%"
              f"{100*np.mean(o>=2):7.0f}%{np.median(p):9.2f}")
        res[names[lc]] = dict(n=len(o), frac=ncell[lc], onset_med=float(np.median(o)),
                              onset_iqr=[float(np.percentile(o, 25)), float(np.percentile(o, 75))],
                              f_lt1=float(np.mean(o < 1)), f_1_2=float(np.mean((o >= 1) & (o < 2))),
                              f_ge2=float(np.mean(o >= 2)), peak_med=float(np.median(p)))
    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(res, indent=2, ensure_ascii=False))
    print(f"\n写出 {OUT}")


if __name__ == "__main__":
    main()

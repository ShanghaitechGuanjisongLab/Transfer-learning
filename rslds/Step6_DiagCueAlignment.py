"""Step6_DiagCueAlignment.py —— 诊断 cue 对齐与细胞级稀疏性

两个待查项
  ① cue 下标是否系统性偏移：EventLog 派生的 idx_SoundOn 与 CD1 模拟通道上升沿比较
  ② 细胞级稀疏性：cue 后有多少比例的细胞反应超过 3 SD

输出
  · 偏移分布（秒）
  · 细胞级响应比例（在 0–1 s / 1–2 s / 2–3 s 三个窗）
  · 用 CD1 对齐后的群体响应时间进程（只取响应细胞）
"""
from __future__ import annotations

import json
import os

import numpy as np

import attractor_core as AC
from rslds_data import load_block, scan_cohort

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "results", "_step6_alignment.json")

WINS = [(0.0, 1.0), (1.0, 2.0), (2.0, 3.0)]


def cd_onsets(cd, fs, min_gap_s=2.0):
    cd = np.asarray(cd, float)
    lo, hi = np.percentile(cd, 1), np.percentile(cd, 99)
    if hi - lo < 1e-6:
        return np.array([], int)
    thr = lo + 0.5 * (hi - lo)
    on = np.where(np.diff((cd > thr).astype(np.int8)) == 1)[0] + 1
    keep = []
    for i in on:
        if not keep or (i - keep[-1]) > min_gap_s * fs:
            keep.append(i)
    return np.array(keep, int)


def main():
    ms = scan_cohort("ALB")
    by = {}
    for x in ms:
        by.setdefault(x["mouse"], {}).setdefault(x["phase"], []).append(x)

    rows = []
    print(f"{'鼠':<9s}{'nEvt':>5s}{'nCD1':>5s}{'offset中位':>10s}{'offsetIQR':>10s}"
          f"{'frac>3sd 0-1s':>14s}{'1-2s':>7s}{'2-3s':>7s}")
    for mouse in sorted(by):
        if "Learned" not in by[mouse]:
            continue
        m = load_block(by[mouse]["Learned"][0]["path"])
        fs = m["fs"]
        ev = np.sort(m["idx_SoundOn"])
        on = cd_onsets(m["cd1"], fs)
        if len(ev) < 5 or len(on) < 5:
            continue

        # ① 每个事件最近的 CD1 上升沿，取偏移
        off = []
        for e in ev:
            j = np.argmin(np.abs(on - e))
            if abs(on[j] - e) < 3 * fs:
                off.append((on[j] - e) / fs)
        off = np.array(off) if off else np.array([np.nan])

        # ② 细胞级稀疏性（用 CD1 对齐）
        Y = AC.dff(m["X"], fs)
        Y = np.nan_to_num(Y, nan=0.0, posinf=0.0, neginf=0.0)
        Z = AC.zscore_robust(AC.VARIANTS["P1"](Y, fs))
        base = np.concatenate([Z[int(c - 2.5 * fs):int(c - 1.0 * fs)]
                               for c in on if int(c - 2.5 * fs) >= 0])
        mu, sd = np.median(base, 0), 1.4826 * np.median(np.abs(base - np.median(base, 0)), 0)
        sd = np.where(sd > 1e-9, sd, 1.0)
        fracs = []
        for (a, b) in WINS:
            segs = [Z[int(c + a * fs):int(c + b * fs)] for c in on if int(c + b * fs) <= len(Z)]
            if not segs:
                fracs.append(np.nan)
                continue
            S = np.stack(segs)                       # trials × T × N
            resp = (S.mean(0) - mu) / sd             # 每细胞在该窗的响应（z 单位）
            fracs.append(float(np.mean(np.abs(resp) > 3.0)))

        rows.append(dict(mouse=mouse, fs=fs, n_evt=int(len(ev)), n_cd1=int(len(on)),
                         offset_med=float(np.median(off)),
                         offset_q1=float(np.percentile(off, 25)),
                         offset_q3=float(np.percentile(off, 75)),
                         frac_01=fracs[0], frac_12=fracs[1], frac_23=fracs[2]))
        r = rows[-1]
        print(f"{mouse:<9s}{r['n_evt']:5d}{r['n_cd1']:5d}{r['offset_med']:10.2f}"
              f"{r['offset_q3']-r['offset_q1']:10.2f}"
              f"{r['frac_01']*100:13.1f}%{r['frac_12']*100:6.1f}%{r['frac_23']*100:6.1f}%")

    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(rows, indent=2, ensure_ascii=False))
    print(f"\n写出 {OUT}")


if __name__ == "__main__":
    main()

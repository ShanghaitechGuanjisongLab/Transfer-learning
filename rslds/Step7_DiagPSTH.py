"""Step7_DiagPSTH.py —— 无模型 PSTH + 细胞级稀疏性（两个修正）

修正 A：用**窗内峰值**而不是窗内平均（短暂瞬变会被平均稀释）
修正 B：不用 CD1（阈值不可靠），直接看模型无关的群体 PSTH 在 **idx_SoundOn 对齐下**
        的峰值时刻；若峰值不在 0–1 s，才说明下标有问题。
"""
from __future__ import annotations

import json
import os

import numpy as np

import attractor_core as AC
from rslds_data import load_block, scan_cohort

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "results", "_step7_psth.json")

TS = np.arange(-2.0, 4.01, 0.25)
WINS = {"0-1s": (0.0, 1.0), "1-2s": (1.0, 2.0), "2-3s": (2.0, 3.0), "-2-0s": (-2.0, 0.0)}


def prep(m):
    Y = AC.dff(m["X"], m["fs"])
    Y = np.nan_to_num(Y, nan=0.0, posinf=0.0, neginf=0.0)
    return AC.zscore_robust(AC.VARIANTS["P1"](Y, m["fs"])), m["fs"]


def psth(Z, idx, fs, ts=TS, base=(-2.0, -0.5)):
    n = int(round((ts[-1] - ts[0]) * fs)) + 1
    tgrid = ts[0] + np.arange(n) / fs
    segs = []
    for c in idx:
        a = int(round(c + ts[0] * fs))
        if a < 0 or a + n >= len(Z):
            continue
        segs.append(Z[a:a + n])
    if not segs:
        return None, None
    S = np.stack(segs)                                   # trials × T × N
    bmask = (tgrid >= base[0]) & (tgrid <= base[1])
    R = S - S[:, bmask].mean(1, keepdims=True)            # 逐试次基线校正
    return R, tgrid


def main():
    ms = scan_cohort("ALB")
    by = {}
    for x in ms:
        by.setdefault(x["mouse"], {}).setdefault(x["phase"], []).append(x)

    rows = []
    print(f"{'鼠':<9s}{'对齐':<8s}{'nTr':>4s}{'峰值t(s)':>9s}{'峰z':>7s}"
          f"{'  细胞>3sd: ':<12s}" + "".join(f"{k:>9s}" for k in WINS))
    for mouse in sorted(by):
        if "Learned" not in by[mouse]:
            continue
        m = load_block(by[mouse]["Learned"][0]["path"])
        Z, fs = prep(m)
        for name, idx in [("cue", np.sort(m["idx_SoundOn"])), ("lick", np.sort(m["idx_GiveWater"]))]:
            if len(idx) < 8:
                continue
            R, tg = psth(Z, idx, fs)
            if R is None:
                continue
            A = R.mean(0)                                # T × N  试次平均
            pop = A.mean(1)
            ip = int(np.argmax(np.abs(pop)))
            fracs = {}
            for k, (aa, bb) in WINS.items():
                mm = (tg >= aa) & (tg <= bb)
                if mm.sum() < 2:
                    fracs[k] = np.nan
                    continue
                peak = np.abs(A[mm]).max(0)
                fracs[k] = float(np.mean(peak > 3.0))
            rows.append(dict(mouse=mouse, align=name, n_trial=int(R.shape[0]),
                             peak_t=float(tg[ip]), peak_z=float(pop[ip]), **fracs))
            r = rows[-1]
            print(f"{mouse:<9s}{name:<8s}{r['n_trial']:4d}{r['peak_t']:9.2f}{r['peak_z']:7.2f}"
                  f"{'':12s}" + "".join(f"{fracs[k]*100:8.1f}%" for k in WINS))

    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(rows, indent=2, ensure_ascii=False))
    print(f"\n写出 {OUT}")


if __name__ == "__main__":
    main()

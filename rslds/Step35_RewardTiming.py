"""Step35_RewardTiming.py —— 晚峰是 cue 诱发还是给水/舔水相关？

Step34 发现：常规 PSTH 从 0.6 s 起就上升，但曲线在 1.5–5 s 是宽平台，
argmax 在不同口径下落在 1.85–3.25 s（"3.0 s"应撤回）。

本脚本判定这个晚峰的性质。三个与行为对齐的判据：

  1. **给水潜伏期**：每个 cue 之后最近一次 GiveWater 的时间分布。
     若给水中位潜伏期落在 2–3 s，晚峰极可能是**奖赏相关**而非 cue 诱发。

  2. **Hit vs Miss 分拆**：命中 trial 有给水，未命中没有。
     若晚峰只在 hit 出现、miss 消失 ⇒ 晚峰是**奖赏/舔水**成分。

  3. **以 GiveWater 为事件重对齐**：把群体响应按给水时刻对齐。
     若此时峰变得又尖又早 ⇒ 说明先前看到的"慢坡"是被**试次间给水时刻抖动**抹宽/拖晚的结果。

口径
  · 只用 AudioWater 刺激的 trial（有给水的设计），按 stim_code 过滤
  · 舔水：CD2 上升沿，阈值 = median + 0.5×(max−median)，最小间隔 0.15 s
  · 基线：事件前 0.5 s 单帧
"""
from __future__ import annotations

import json
import os

import numpy as np

import attractor_core as AC
from rslds_data import load_block, scan_cohort

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "results", "_step35_reward.json")
PHASES = ["Learned", "Transfer", "Final"]
MIN_CELL = 40
BASE_S = -0.5
STEP = 0.05
TAUS = np.arange(BASE_S, 6.0 + 1e-9, STEP)


def rising_edges(cd, fs, frac=0.5, min_gap_s=0.15):
    cd = np.asarray(cd, float)
    thr = np.median(cd) + frac * (cd.max() - np.median(cd))
    above = cd > thr
    e = np.where(np.diff(above.astype(np.int8)) == 1)[0] + 1
    if not len(e):
        return e
    gap = int(min_gap_s * fs)
    keep = [e[0]]
    for x in e[1:]:
        if x - keep[-1] >= gap:
            keep.append(x)
    return np.array(keep)


def aligned(Y, ev, fs):
    rows = []
    for c in ev:
        a = int(c) + int(round(BASE_S * fs))
        b = int(c) + int(round(TAUS[-1] * fs))
        if a < 0 or b > len(Y):
            continue
        base = Y[a]
        seg = np.empty((len(TAUS), Y.shape[1]))
        for k, tau in enumerate(TAUS):
            seg[k] = Y[int(c) + int(round(tau * fs))]
        rows.append(seg - base)
    return np.stack(rows) if len(rows) >= 8 else None


def curve(R):
    z = np.median(R, axis=0)
    psth = z.mean(1)
    absp = np.abs(z).mean(1)
    rms = np.linalg.norm(z, axis=1) / np.sqrt(z.shape[1])
    return psth, absp, rms


def lat(curve, lo=0.0, hi=5.0):
    m = (TAUS >= lo) & (TAUS <= hi)
    return float(TAUS[m][int(np.argmax(curve[m]))]) if m.any() else np.nan


def main():
    ms = scan_cohort("ALB", phases=PHASES)
    gw_lat, lick_prof = [], []
    hits, misses, allc = {}, {}, {}
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
        Z = AC.zscore_robust(AC.VARIANTS["P1"](Y0[:, ok], fs))

        # 刺激过滤：只用 AudioWater（若编码可用）
        code = np.asarray(d.get("stim_code", []), dtype=np.int64)
        sn = d.get("stim_names", [])
        names = sn if isinstance(sn, list) else (str(sn).split(",") if sn else [])
        sel_t = np.ones(len(cue), bool)
        if len(code) == len(cue) and "AudioWater" in names:
            sel_t = code == (names.index("AudioWater") + 1)
        cue_use = cue[sel_t]
        if len(cue_use) < 8:
            cue_use = cue

        gw = np.sort(np.asarray(d.get("idx_GiveWater", []), dtype=np.int64))
        hit = np.sort(np.asarray(d.get("idx_Hit", []), dtype=np.int64))
        mis = np.sort(np.asarray(d.get("idx_Miss", []), dtype=np.int64))

        # 1) 给水潜伏期
        for c in cue_use:
            k = np.searchsorted(gw, c)
            if k < len(gw):
                gw_lat.append((gw[k] - c) / fs)

        # 2) 舔水率时程（相对 cue）
        cd2 = d.get("CD2")
        if cd2 is not None and len(cd2):
            le = rising_edges(cd2, fs)
            pr = []
            for tau in TAUS:
                cnt = []
                for c in cue_use:
                    t0 = c + int(round(tau * fs))
                    if t0 < 0:
                        continue
                    cnt.append(int(np.sum((le > t0) & (le <= t0 + int(round(0.25 * fs))))))
                pr.append(np.mean(cnt) / 0.25 if cnt else np.nan)
            lick_prof.append(np.array(pr, float))

        # 3) hit / miss 分拆
        def tag(ev, c0, c1):
            k = np.searchsorted(ev, c0)
            return k < len(ev) and ev[k] < c1
        ev_h, ev_m = [], []
        for i, c in enumerate(cue_use):
            c1 = int(cue_use[i + 1]) if i + 1 < len(cue_use) else len(Z)
            if tag(hit, int(c), c1):
                ev_h.append(int(c))
            elif tag(mis, int(c), c1):
                ev_m.append(int(c))
        Rh = aligned(Z, np.array(ev_h), fs) if len(ev_h) >= 8 else None
        Rm = aligned(Z, np.array(ev_m), fs) if len(ev_m) >= 8 else None
        Ra = aligned(Z, cue_use, fs)
        for nm, R, store in (("hit", Rh, hits), ("miss", Rm, misses), ("all", Ra, allc)):
            if R is not None:
                store.setdefault(nm, []).append(curve(R))
        print(f"  {b['mouse']:<9s}{b['phase']:<9s} nCue={len(cue_use)} "
              f"hit={len(ev_h):2d} miss={len(ev_m):2d}")

    if "all" not in allc:
        print("无数据")
        return
    gwl = np.array(gw_lat)
    print("\n=== 1) cue → 最近一次 GiveWater 的潜伏期 ===")
    print(f"n={len(gwl)}；中位 {np.median(gwl):.2f} s；"
          f"IQR {np.percentile(gwl,25):.2f}–{np.percentile(gwl,75):.2f} s；"
          f"10–90% {np.percentile(gwl,10):.2f}–{np.percentile(gwl,90):.2f} s")

    if lick_prof:
        L = np.median(np.stack(lick_prof), axis=0)
        print(f"\n=== 2) 舔水率时程（次/秒，相对 cue）===")
        print(f"{'τ(s)':>6s}{'舔水率':>10s}")
        for tau in (-0.4, 0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 4.0, 5.0):
            j = int(np.argmin(np.abs(TAUS - tau)))
            print(f"{TAUS[j]:6.2f}{L[j]:10.3f}")

    print(f"\n=== 3) 分拆后的峰潜伏期 ===")
    print(f"{'子集':<8s}{'nSess':>7s}{'PSTH峰':>9s}{'|z|峰':>9s}{'RMS峰':>9s}"
          f"{'PSTH@1s':>10s}{'PSTH@3s':>10s}")
    res = {}
    for nm, store in (("hit", hits), ("miss", misses), ("all", allc)):
        if nm not in store:
            continue
        P = np.median(np.stack([c[0] for c in store[nm]]), axis=0)
        A = np.median(np.stack([c[1] for c in store[nm]]), axis=0)
        M = np.median(np.stack([c[2] for c in store[nm]]), axis=0)
        j1 = int(np.argmin(np.abs(TAUS - 1.0)))
        j3 = int(np.argmin(np.abs(TAUS - 3.0)))
        print(f"{nm:<8s}{len(store[nm]):7d}{lat(P):9.2f}{lat(A):9.2f}{lat(M):9.2f}"
              f"{P[j1]:10.3f}{P[j3]:10.3f}")
        res[nm] = dict(n=len(store[nm]), psth_peak=lat(P), abs_peak=lat(A),
                       rms_peak=lat(M), psth_at_1s=float(P[j1]), psth_at_3s=float(P[j3]))

    res["givewater_lat_median"] = float(np.median(gwl))
    res["givewater_lat_iqr"] = [float(np.percentile(gwl, 25)), float(np.percentile(gwl, 75))]
    if lick_prof:
        res["lick_peak_tau"] = float(TAUS[int(np.nanargmax(L))])
        res["lick_rate_peak"] = float(np.nanmax(L))
    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(res, indent=2, ensure_ascii=False))
    print(f"\n写出 {OUT}")


if __name__ == "__main__":
    main()

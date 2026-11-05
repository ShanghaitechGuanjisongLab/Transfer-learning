"""Step18b_CueInvariant.py —— cue 不变的不动点（v2，有界统计量）

> 本脚本取代 `Step18_CueInvariantFixedPoint.py`（v1）。v1 用 VAR 求 x*=(I−A)⁻¹c，
> 在 3 s 回落窗上 A 近奇异、估计爆炸（D_floor 中位 12.4 > D_obs），不可用。详见下方说明。

问题
  用户提出的洞察：cue 本身就是扰动协议。若各种 cue 激发的偏移最终都回到**同一个**点，
  则该不动点是内部状态，而不是某条感觉通路的产物。这直接对抗"所谓吸引子只是刺激响应"。

v1 失败原因（保留记录）
  每刺激局部 VAR(1) 求不动点 x* = (I−A)⁻¹c。回落窗仅 ~3 s ⇒ A 的最大特征值 ≈0.99 ⇒
  (I−A) 近奇异，x* 对 A 的微小误差呈爆炸放大。实测 D_floor（同种刺激奇偶分半）
  中位 12.4，**比 D_obs 还大**。与 vtf0233/Transfer 的 dist=3184 同一病理。

v2 做法（有界、可解释）
  同一参考系下算两种刺激的平均轨迹，直接看分离曲线

      D(τ) = ‖ m_A(τ) − m_B(τ) ‖ / spread ,   τ ∈ [0, 3.5] s

  · D_peak = max_{τ≤2.5s} D(τ)     —— 两种扰动在峰值时差多少（"扰动的信号量"）
  · D_late = mean_{2.0≤τ≤3.0s} D(τ) —— 回落后的残差（"不动点是否同一个"）
  · ratio  = D_late / D_peak

判读（**等价性检验**，不是差异检验）
  要主张"同一个不动点"，必须证明 D_late **足够小**，而不只是"不显著大于 0"：
  · ratio < 0.30 且 D_late ≤ max(2×地板, 0.05) ⇒ 支持同一不动点 ✅
  · ratio > 0.60                              ⇒ 两种 cue 通往不同终点 ❌
  · 峰/SE < 2                                 ⇒ **功效不足，判不可判定**，不得报阳性

噪声地板
  同种刺激奇偶分半，各自算平均轨迹后取 D_floor(τ)，取晚窗均值作为可分辨下限。
  地板随细胞数、trial 数、信噪比而变，所以必须**每个刺激对各自比**，不能跨对比较绝对 D。

输出 results/_step18b_cue_invariant.json
"""
from __future__ import annotations

import json
import os
import time

import numpy as np

import attractor_core as AC
import Step10_TICA as T
from rslds_data import load_block, scan_cohort

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "results", "_step18b_cue_invariant.json")

KPC = 10
TRACE_WIN = 3.5
PEAK_WIN = 2.5
LATE_WIN = (2.0, 3.0)
MIN_TRIAL = 8
DESIGNS = ("LAu", "LAuW")
RATIO_THR = 0.30
SNR_THR = 2.0


def mean_traces(X, cues, fs, n):
    traces = []
    for c in cues:
        a = int(c)
        b = int(min(c + TRACE_WIN * fs, n))
        if a >= 0 and b - a >= int(TRACE_WIN * fs * 0.6):
            traces.append(X[a:b])
    if len(traces) < MIN_TRIAL:
        return None
    L = min(len(t) for t in traces)
    return np.stack([t[:L] for t in traces])


def main():
    t0 = time.time()
    bs = [b for b in scan_cohort("ALB") if b["design"] in DESIGNS]
    bs.sort(key=lambda x: x["mouse"])
    rows = []
    print(f"{'鼠':<9s}{'设计':<7s}{'刺激对':<25s}{'Dpeak':>7s}{'Dlate':>7s}"
          f"{'ratio':>7s}{'地板':>7s}{'峰/SE_A':>9s}{'峰/SE_B':>9s}  判定")
    for b in bs:
        d = load_block(b["path"])
        fs = d["fs"]
        Y = np.nan_to_num(AC.dff(d["X"], fs), nan=0.0, posinf=0.0, neginf=0.0)
        Y = Y[:, np.std(Y, axis=0) > 1e-9]
        Z = AC.zscore_robust(AC.VARIANTS["P1"](Y, fs))
        X, _, _, _ = T.pcs(Z, KPC)
        X = X / max(np.median(np.linalg.norm(X, axis=1)), 1e-12)

        cue = np.sort(np.asarray(d.get("idx_cue", []), dtype=np.int64))
        sc = np.asarray(d.get("stim_code", []), dtype=np.int64)
        names = d.get("stim_names", [])
        if len(cue) != len(sc) or len(names) < 2:
            continue
        groups = {}
        for i, k in enumerate(sc):
            groups.setdefault(int(k), []).append(i)
        usable = {k: np.array(v) for k, v in groups.items() if len(v) >= MIN_TRIAL}
        if len(usable) < 2:
            continue

        spread = float(np.median(np.linalg.norm(X - np.median(X, axis=0), axis=1)))
        iA, iB = int(LATE_WIN[0] * fs), int(LATE_WIN[1] * fs)

        for a_k, b_k in [(list(usable)[i], list(usable)[j])
                         for i in range(len(usable)) for j in range(i + 1, len(usable))]:
            MA = mean_traces(X, cue[usable[a_k]], fs, len(X))
            MB = mean_traces(X, cue[usable[b_k]], fs, len(X))
            if MA is None or MB is None:
                continue
            L = min(len(MA[0]), len(MB[0]))
            MA, MB = MA[:, :L], MB[:, :L]
            mAt = MA.mean(0)
            mBt = MB.mean(0)
            seA = MA.std(0, ddof=1) / np.sqrt(len(MA))
            seB = MB.std(0, ddof=1) / np.sqrt(len(MB))

            Dt = np.linalg.norm(mAt - mBt, axis=1) / spread
            npk = min(len(Dt), int(PEAK_WIN * fs))
            D_peak = float(Dt[:max(npk, 1)].max())
            sl = slice(iA, min(iB, len(Dt)))
            D_late = float(Dt[sl].mean()) if Dt[sl].size else np.nan

            snrA = float(np.linalg.norm(mAt[:npk].max(0)) / max(np.median(np.linalg.norm(seA[:npk], axis=1)), 1e-12))
            snrB = float(np.linalg.norm(mBt[:npk].max(0)) / max(np.median(np.linalg.norm(seB[:npk], axis=1)), 1e-12))

            floors = []
            for idx in (usable[a_k], usable[b_k]):
                ev, od = idx[0::2], idx[1::2]
                if len(ev) < 4 or len(od) < 4:
                    continue
                M1 = mean_traces(X, cue[ev], fs, len(X))
                M2 = mean_traces(X, cue[od], fs, len(X))
                if M1 is None or M2 is None:
                    continue
                Lf = min(len(M1[0]), len(M2[0]), len(Dt))
                df = np.linalg.norm(M1[:, :Lf].mean(0) - M2[:, :Lf].mean(0), axis=1) / spread
                slf = slice(iA, min(iB, Lf))
                if df[slf].size:
                    floors.append(float(df[slf].mean()))
            D_floor = float(np.median(floors)) if floors else np.nan

            ratio = D_late / max(D_peak, 1e-12)
            if min(snrA, snrB) < SNR_THR:
                verdict = "不可判定(功效)"
            elif ratio < RATIO_THR and (not np.isfinite(D_floor) or D_late <= max(2 * D_floor, 0.05)):
                verdict = "同一不动点"
            elif ratio > 0.60:
                verdict = "不同终点"
            else:
                verdict = "不确定"

            nA = names[a_k - 1] if a_k - 1 < len(names) else str(a_k)
            nB = names[b_k - 1] if b_k - 1 < len(names) else str(b_k)
            rows.append(dict(mouse=b["mouse"], design=b["design"], stimA=nA, stimB=nB,
                             pair=f"{nA} vs {nB}", nA_tr=int(len(usable[a_k])),
                             nB_tr=int(len(usable[b_k])), D_peak=D_peak, D_late=D_late,
                             ratio=float(ratio), D_floor=D_floor, snrA=snrA, snrB=snrB,
                             verdict=verdict, spread=spread, n_dim=int(X.shape[1])))
            print(f"{b['mouse']:<9s}{b['design']:<7s}{nA+' vs '+nB:<25s}"
                  f"{D_peak:7.3f}{D_late:7.3f}{ratio:7.3f}{D_floor:7.3f}"
                  f"{snrA:9.1f}{snrB:9.1f}  {verdict}")

    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(rows, indent=2, ensure_ascii=False))

    if rows:
        print(f"\n=== 汇总（{len(rows)} 个刺激对）===")
        print(f"  D_peak 中位 {np.nanmedian([r['D_peak'] for r in rows]):.3f}"
              f"   D_late 中位 {np.nanmedian([r['D_late'] for r in rows]):.3f}"
              f"   ratio 中位 {np.nanmedian([r['ratio'] for r in rows]):.2f}")
        print(f"  D_floor 中位 {np.nanmedian([r['D_floor'] for r in rows]):.3f}")
        from collections import Counter
        for k, v in Counter(r["verdict"] for r in rows).items():
            print(f"    {k}: {v}/{len(rows)}")
    print(f"\n用时 {(time.time()-t0)/60:.1f} min；写出 {OUT}")


if __name__ == "__main__":
    main()

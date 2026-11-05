"""Step13_Qfactor.py —— 系统计算阻尼品质因子 Q，判定「螺旋」到底有多普遍

定义（对复特征值 λ = |λ|e^{iθ}）
    Q       = |Im λ| / |ln|λ||          >0.5 才算欠阻尼（转得比衰减快）
    每 e 折转角 = θ / |ln|λ||  （弧度；>π/2 ≈ 90° 才像"螺旋"）
    周期    = 2π·(lag/fs)/θ

输出：每 session 前 5 个特征值里 Q 最大的那一个；并做 A/B 两半的一致性检查。
"""
from __future__ import annotations

import json
import os
import time

import numpy as np

import attractor_core as AC
import Step10_TICA as T
import Step12_TICA_NonReversible as S
from rslds_data import load_block, scan_cohort

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "results", "_step13_qfactor.json")
LAG = 16
PHASES = ["Learned", "Transfer", "Final"]


def q_stats(w, lag, fs):
    """返回前 5 个特征值中 Q 最大者及其周期/转角。"""
    best = dict(Q=0.0, period=np.inf, ang_per_efold=0.0, mag=0.0)
    for k in range(min(5, len(w))):
        mag = abs(w[k])
        if mag < 0.3 or mag >= 1.0:
            continue
        im = abs(np.imag(w[k]))
        if im <= 1e-6:
            continue
        lnm = abs(np.log(mag))
        Q = im / max(lnm, 1e-12)
        if Q > best["Q"]:
            th = abs(np.angle(w[k]))
            best = dict(Q=float(Q), mag=float(mag),
                        period=float(2 * np.pi * lag / fs / th),
                        ang_per_efold=float(th / max(lnm, 1e-12)))
    return best


def main():
    t0 = time.time()
    ms = scan_cohort("ALB", phases=PHASES)
    ms.sort(key=lambda b: (b["mouse"], PHASES.index(b["phase"])))
    rows = []
    print(f"{'鼠':<9s}{'阶段':<8s}{'Q':>6s}{'周期(s)':>9s}{'每e折转角(°)':>13s}"
          f"{'|λ|':>6s}{'Q_B':>7s}  判定")
    for b in ms:
        d = load_block(b["path"])
        fs = d["fs"]
        Y = np.nan_to_num(AC.dff(d["X"], fs), nan=0.0, posinf=0.0, neginf=0.0)
        Y = Y[:, np.std(Y, axis=0) > 1e-9]
        Z = AC.zscore_robust(AC.VARIANTS["P1"](Y, fs))
        cue = np.sort(d.get("idx_cue", []))
        if len(cue) < 10:
            continue
        trials = [(int(c), int(cue[i + 1]) if i + 1 < len(cue) else len(Z))
                  for i, c in enumerate(cue)]
        trials = [(s, e) for s, e in trials if e - s > int(2 * fs)]
        segA, segB = T.split_trials(Z, trials, np.random.default_rng(0))
        X, _, _, _ = T.pcs(Z)

        C0a, Cta = S.cov_pair(X, segA, LAG)
        C0b, Ctb = S.cov_pair(X, segB, LAG)
        if C0a is None or C0b is None:
            continue
        wa, _, _ = S.spec(C0a, Cta, LAG, fs)
        wb, _, _ = S.spec(C0b, Ctb, LAG, fs)
        qa, qb = q_stats(wa, LAG, fs), q_stats(wb, LAG, fs)

        verdict = ("螺旋" if qa["Q"] > 1.0 else
                   "欠阻尼" if qa["Q"] > 0.5 else
                   "旋转" if qa["Q"] > 0.2 else "过阻尼")
        rows.append(dict(mouse=b["mouse"], phase=b["phase"], Q=qa["Q"],
                         period=qa["period"], ang_per_efold=qa["ang_per_efold"],
                         mag=qa["mag"], Q_B=qb["Q"], verdict=verdict))
        print(f"{b['mouse']:<9s}{b['phase']:<8s}{qa['Q']:6.2f}{min(qa['period'],9999):9.1f}"
              f"{np.degrees(qa['ang_per_efold']):13.0f}{qa['mag']:6.3f}{qb['Q']:7.2f}  {verdict}")

    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(rows, indent=2, ensure_ascii=False))

    if rows:
        q = np.array([x["Q"] for x in rows])
        print(f"\n=== 汇总（{len(rows)} session）===")
        print(f"Q 中位 {np.median(q):.2f}（{q.min():.2f}–{q.max():.2f}）")
        for lo, nm in [(1.0, "螺旋 Q>1"), (0.5, "欠阻尼 Q>0.5"), (0.2, "有旋转 Q>0.2")]:
            sel = [x for x in rows if x["Q"] > lo]
            print(f"  {nm}: {len(sel)}/{len(rows)}  " +
                  ", ".join(f"{x['mouse']}/{x['phase']}" for x in sel))
        for ph in PHASES:
            sub = [x["Q"] for x in rows if x["phase"] == ph]
            if sub:
                print(f"  {ph:<8s} n={len(sub):2d}  Q 中位 {np.median(sub):.2f}  "
                      f"Q>0.5 的 {sum(v > 0.5 for v in sub)} 个")
    print(f"\n用时 {(time.time()-t0)/60:.1f} min；写出 {OUT}")


if __name__ == "__main__":
    main()

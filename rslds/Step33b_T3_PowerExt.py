"""Step33b_T3_PowerExt.py —— 功效延伸：多大的隐藏驱动才能被检出？

Step33 已知（B=40，33 session）
  β=0.15 时功效：0-12 → 0.69；7-16 → 0.27；9-18 → 0.10；12-22 → 0.04
  即**没有任何窗口达到 0.8，三个回落相窗口全部 < 0.5**。

本脚本回答唯一还没答的问题
  "隐藏驱动要多大，T3 才可能检出？"
  做法：把 β 推到 0.3 / 0.6 / 1.2（都以 sd(Δz over 1 s) 为单位），并同时给出
  **oracle R²** —— 只用真实 u_t 去预测 Δz 的交叉验证 R²。这是效应量的客观标尺，
  不受检验统计量影响。

判读（预先声明）
  · 若 7-16 / 9-18 要到 β>=0.6 才达 0.8 功效
        ⇒ 论文写：可检出的最小隐藏驱动 ≈ 相当于逐帧注入 0.6×典型 1 s 状态变化，
          即**比信号本身还大**。本数据无法回答自治性问题。
  · 若 β=0.3 就能达 0.8
        ⇒ 可考虑用该 β 作正向对照门槛重签协议。
"""
from __future__ import annotations

import json
import os
import time

import numpy as np

import attractor_core as AC
import Step14_Unified as S14
import Step33_T3_PowerScan as P
from rslds_data import load_block, scan_cohort

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "results", "_step33b_power_ext.json")

PHASES = ["Learned", "Transfer", "Final"]
MIN_CELL = 40
LAG_S = 1.0
TAU_DRIVE_S = 20.0
WINDOWS = [(0.0, 12.0), (7.0, 16.0), (9.0, 18.0)]
BETAS_K = [0.0, 1.0, 3.0, 9.0]
B = 30


def masks_for(cue, n, fs, lag, win):
    tid = np.full(n, -1, dtype=np.int64)
    sidx = np.zeros(n, dtype=np.int64)
    for ti, c in enumerate(cue):
        c = int(c)
        end = int(cue[ti + 1]) if ti + 1 < len(cue) else n
        tid[c:end] = ti
        sidx[c:end] = np.arange(end - c)
    ok = np.zeros(n, dtype=bool)
    for ti, c in enumerate(cue):
        c = int(c)
        end = int(cue[ti + 1]) if ti + 1 < len(cue) else n
        ok[c:max(c, end - lag)] = True
    i0, i1 = int(round(win[0] * fs)), int(round(win[1] * fs))
    return tid, sidx, ok & (sidx >= i0) & (sidx < i1), i0, i1


def oracle_r2(Zs, y, rows, groups, u):
    """只用 u_t 预测 Δz 的按 trial 分组 CV R²（客观效应量标尺）。"""
    X = np.column_stack([np.ones(len(rows)), u[rows]])
    sse = P.fit_cv(X, y[rows], groups)
    tot = float(((y[rows] - y[rows].mean(0)) ** 2).sum())
    return 1.0 - sse / tot if tot > 0 else np.nan


def main():
    t0 = time.time()
    ms = scan_cohort("ALB", phases=PHASES)
    ms.sort(key=lambda b: (b["mouse"], PHASES.index(b["phase"])))
    rec = []
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
        Zc = AC.zscore_robust(AC.VARIANTS["P1"](Y0[:, ok], fs))
        gaps = np.diff(cue)
        K = int(min(20.0 * fs, gaps.min()))
        pre = int(round(0.5 * fs))
        if K < 50:
            continue
        rows_resp = []
        for c in cue[:-1]:
            a, bb = int(c), int(c) + K
            if a - pre < 0 or bb > len(Zc):
                continue
            rows_resp.append(Zc[a:bb] - Zc[a - pre])
        if len(rows_resp) < 10:
            continue
        Rk = np.median(np.stack(rows_resp), axis=0)
        _, _, Vt = np.linalg.svd(Rk, full_matrices=False)
        V2 = Vt[:2].T
        Z2 = Zc @ V2
        Z2 = Z2 / max(np.median(np.linalg.norm(Z2, axis=1)), 1e-12)
        mu2 = Rk @ V2

        c_, A_, S_ = S14.fit_var1(Z2)
        lag = int(round(LAG_S * fs))
        n = len(Z2)
        if n <= lag + 10:
            continue
        scale = float(np.median(np.linalg.norm(Z2[lag:] - Z2[:-lag], axis=1)))
        y = np.full_like(Z2, np.nan)
        y[:-lag] = Z2[lag:] - Z2[:-lag]

        wins = {}
        for win in WINDOWS:
            tid, sidx, mask, i0, i1 = masks_for(cue, n, fs, lag, win)
            rel = np.clip((sidx - i0) / max(i1 - i0, 1), 0, 0.999999)
            oh = np.zeros((n, P.S_BINS))
            oh[np.arange(n), (rel * P.S_BINS).astype(int)] = 1.0
            wins[f"{win[0]:g}-{win[1]:g}"] = (tid, mask, oh)

        a_ar = np.exp(-1.0 / (fs * TAU_DRIVE_S))
        L = np.linalg.cholesky(S_ + 1e-12 * np.eye(2))
        rng = np.random.default_rng(0)
        for bk in BETAS_K:
            beta = bk * scale
            for _ in range(B):
                u = np.zeros(n)
                inn = rng.standard_normal(n)
                e = rng.standard_normal((n, 2)) @ L.T
                dirn = rng.standard_normal(2)
                dirn /= max(np.linalg.norm(dirn), 1e-12)
                Zs = np.empty_like(Z2)
                Zs[0] = Z2[0]
                for t in range(1, n):
                    u[t] = a_ar * u[t - 1] + np.sqrt(1 - a_ar ** 2) * inn[t]
                    Zs[t] = c_ + A_ @ Zs[t - 1] + beta * u[t] * dirn + e[t]
                for cc in cue:
                    a2 = int(cc)
                    bb2 = min(a2 + len(mu2), n)
                    if a2 >= 0 and bb2 > a2:
                        Zs[a2:bb2] += mu2[: bb2 - a2]
                ys = np.full_like(Zs, np.nan)
                ys[:-lag] = Zs[lag:] - Zs[:-lag]
                for wname, (tid, mask, oh) in wins.items():
                    rr = np.where(mask)[0]
                    rr = rr[~np.isnan(ys[rr, 0])]
                    if len(rr) < 60:
                        continue
                    dr, nrow = P.delta_r2(Zs, np.nan_to_num(ys), rr, tid[rr], oh)
                    rec.append(dict(mouse=b["mouse"], phase=b["phase"], window=wname,
                                    beta_k=bk, dR2=dr, n_row=nrow,
                                    oracle=oracle_r2(Zs, np.nan_to_num(ys), rr, tid[rr],
                                                     u if bk > 0 else np.zeros(n))))
        print(f"  {b['mouse']:<9s}{b['phase']:<9s} ({(time.time()-t0)/60:.1f} min)")

    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(rec, indent=2, ensure_ascii=False))

    print("\n=== 功效延伸（B=40，33 session）===")
    print(f"{'窗口':<9s}{'beta':>6s}{'ΔR²中位':>10s}{'oracleR²':>10s}{'功效':>7s}")
    summary = {}
    for win in WINDOWS:
        wname = f"{win[0]:g}-{win[1]:g}"
        st = {}
        for x in rec:
            if x["window"] == wname and x["beta_k"] == 0.0 and np.isfinite(x["dR2"]):
                st.setdefault((x["mouse"], x["phase"]), []).append(x["dR2"])
        st = {k: (float(np.mean(v)), float(np.std(v, ddof=1)) + 1e-12)
              for k, v in st.items() if len(v) >= 10}
        for bk in BETAS_K:
            zs, raw, orc = [], [], []
            for x in rec:
                if x["window"] != wname or x["beta_k"] != bk or not np.isfinite(x["dR2"]):
                    continue
                k = (x["mouse"], x["phase"])
                if k not in st:
                    continue
                zs.append((x["dR2"] - st[k][0]) / st[k][1])
                raw.append(x["dR2"])
                if np.isfinite(x.get("oracle", np.nan)):
                    orc.append(x["oracle"])
            if not zs:
                continue
            pw = float(np.mean(np.array(zs) > 1.645))
            print(f"{wname:<9s}{bk:6.2f}{np.median(raw):10.4f}"
                  f"{np.median(orc) if orc else np.nan:10.3f}{pw:7.2f}")
            summary[f"{wname}|{bk}"] = dict(power=pw, dR2_med=float(np.median(raw)),
                                            oracle=float(np.median(orc)) if orc else None,
                                            n=len(zs))
        print()
    with open(os.path.join(HERE, "results", "_step33b_summary.json"), "w",
              encoding="utf-8") as fh:
        fh.write(json.dumps(summary, indent=2, ensure_ascii=False))
    print(f"用时 {(time.time()-t0)/60:.1f} min；写出 {OUT}")


if __name__ == "__main__":
    main()

"""Step33_T3_PowerScan.py —— T3 的功效预扫（**只用合成数据**，不碰真实 ΔR²）

为什么要先做这个
  PreReg_T3 原稿把功效门槛放在**最后**（跑完看功效，<0.5 判不可判定）。顺序不对：
  它允许"试了很多窗口，恰好有一个显著"。本脚本把功效提前，做到**看真实结果之前**。

回答三个问题
  ① 哪些时间窗口内，"同状态、不同未来"的检验**有能力**检出已知隐藏驱动？
  ② H1（距 cue 时间 s）因与状态共线被吃掉多少功效？
  ③ 若所有窗口都无功效 ⇒ T3 直接判"不可判定"，不必跑。

生成结构（全部来自实测）
  · 状态空间：cue 锁时平均响应 R(k) 的前 2 个右奇异向量（= T3 的 S2 口径）
  · 动力学：在该 2 维空间拟合 VAR(1) → (c, A, Σ)
  · 诱发响应：实测 R(k) 投影到该子空间得 mu2，逐 cue 加上
  · 隐藏驱动：AR(1)，tau=20 s，注入 z_{t+1} = c + A z_t + beta*u_t*d + eps

统计量（与 T3 稿一致）
  Δz^tau = z_{t+tau} − z_t，tau = 1.0 s
  M0: 二次多项式(z)；M1: M0 + s 的 4 分箱 one-hot
  ΔR² = (SSE0 − SSE1)/SSTOT，**按 trial 分组 5 折**，岭回归（训练折内标化）

功效
  用 beta=0 的 ΔR² 估每个 (session, 窗口) 的 null 均值/SD，把 beta>0 的 ΔR² 标化后
  与单侧 95% 分位 z=1.645 比较。

判读（预先声明）
  · 存在窗口功效 >= 0.8 ⇒ 用该窗口，写进 S1 后再签协议、再跑真实数据
  · 所有窗口 < 0.5      ⇒ T3 判"不可判定（本数据无功效）"，不跑
"""
from __future__ import annotations

import json
import os
import time

import numpy as np

import attractor_core as AC
import Step14_Unified as S14
from rslds_data import load_block, scan_cohort

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "results", "_step33_powerscan.json")

PHASES = ["Learned", "Transfer", "Final"]
MIN_CELL = 40
LAG_S = 1.0
TAU_DRIVE_S = 20.0
WINDOWS = [(0.0, 12.0), (7.0, 16.0), (9.0, 18.0), (12.0, 22.0)]
BETAS_K = [0.0, 0.02, 0.06, 0.15]
B = 40
S_BINS = 4
N_FOLD = 5
RIDGE = 1e-2


def quad(z):
    d = z.shape[1]
    cols = [np.ones(len(z))]
    for i in range(d):
        cols.append(z[:, i])
    for i in range(d):
        for j in range(i, d):
            cols.append(z[:, i] * z[:, j])
    return np.column_stack(cols)


def fit_cv(X, y, groups, n_fold=N_FOLD):
    ug = np.unique(groups)
    rng = np.random.default_rng(0)
    idx = rng.permutation(len(ug))
    fold_of = {ug[idx[i]]: i % n_fold for i in range(len(ug))}
    f = np.array([fold_of[g] for g in groups])
    sse = 0.0
    for k in range(n_fold):
        tr, te = f != k, f == k
        if te.sum() < 5 or tr.sum() < 20:
            continue
        Xa, ya = X[tr], y[tr]
        mu = Xa.mean(0)
        sd = Xa.std(0)
        sd[sd < 1e-9] = 1.0
        Xs = (Xa - mu) / sd
        ym = ya.mean(0)
        G = Xs.T @ Xs
        G[np.diag_indices_from(G)] += RIDGE * len(Xs)
        W = np.linalg.solve(G, Xs.T @ (ya - ym))
        pred = ((X[te] - mu) / sd) @ W + ym
        sse += float(((y[te] - pred) ** 2).sum())
    return sse


def build_masks(cue, n, fs, lag):
    """返回 trial_id(T,)、sidx(T,)（距 cue 帧数）、以及每个窗口的布尔掩码。"""
    tid = np.full(n, -1, dtype=np.int64)
    sidx = np.zeros(n, dtype=np.int64)
    for ti, c in enumerate(cue):
        end = int(cue[ti + 1]) if ti + 1 < len(cue) else n
        c = int(c)
        tid[c:end] = ti
        sidx[c:end] = np.arange(end - c)
    ok = np.zeros(n, dtype=bool)
    for ti, c in enumerate(cue):
        c = int(c)
        end = int(cue[ti + 1]) if ti + 1 < len(cue) else n
        ok[c:max(c, end - lag)] = True
    masks = {}
    for win in WINDOWS:
        i0, i1 = int(round(win[0] * fs)), int(round(win[1] * fs))
        masks[f"{win[0]:g}-{win[1]:g}"] = ok & (sidx >= i0) & (sidx < i1)
    return tid, sidx, masks


def delta_r2(Z, y_lag, rows, groups, sbin):
    Zs = Z[rows]
    Ys = y_lag[rows]
    X0 = quad(Zs)
    X1 = np.column_stack([X0, sbin[rows]])
    if len(rows) < 60:
        return np.nan, len(rows)
    sse0 = fit_cv(X0, Ys, groups)
    sse1 = fit_cv(X1, Ys, groups)
    tot = float(((Ys - Ys.mean(0)) ** 2).sum())
    if tot <= 0:
        return np.nan, len(rows)
    return float((sse0 - sse1) / tot), len(rows)


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
        if len(Z2) <= lag + 10:
            continue
        step = Z2[lag:] - Z2[:-lag]
        scale = float(np.median(np.linalg.norm(step, axis=1)))

        n = len(Z2)
        tid, sidx, masks = build_masks(cue, n, fs, lag)
        y_lag = np.full_like(Z2, np.nan)
        y_lag[:-lag] = Z2[lag:] - Z2[:-lag]
        groups_all = tid
        # 每个窗口的 s 分箱（按距 cue 帧数在窗口内均分）
        sbins = {}
        for win in WINDOWS:
            wname = f"{win[0]:g}-{win[1]:g}"
            i0, i1 = int(round(win[0] * fs)), int(round(win[1] * fs))
            rel = np.clip((sidx - i0) / max(i1 - i0, 1), 0, 0.999999)
            oh = np.zeros((n, S_BINS))
            oh[np.arange(n), (rel * S_BINS).astype(int)] = 1.0
            sbins[wname] = oh

        a_ar = np.exp(-1.0 / (fs * TAU_DRIVE_S))
        L = np.linalg.cholesky(S_ + 1e-12 * np.eye(2))
        rng = np.random.default_rng(0)
        for bk in BETAS_K:
            beta = bk * scale
            for _ in range(B):
                u = np.zeros(n)
                u[0] = rng.standard_normal()
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
                for win in WINDOWS:
                    wname = f"{win[0]:g}-{win[1]:g}"
                    rows = np.where(masks[wname])[0]
                    rows = rows[~np.isnan(y_lag[rows, 0])]
                    if len(rows) < 60:
                        continue
                    dr, nrow = delta_r2(Zs, np.nan_to_num(y_lag), rows,
                                        groups_all[rows], sbins[wname])
                    rec.append(dict(mouse=b["mouse"], phase=b["phase"], window=wname,
                                    beta_k=bk, dR2=dr, n_row=nrow))
        print(f"  {b['mouse']:<9s}{b['phase']:<9s} ({(time.time()-t0)/60:.1f} min)")

    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(rec, indent=2, ensure_ascii=False))

    print("\n=== T3 功效预扫 ===")
    print(f"{'窗口':<10s}{'beta':>6s}{'ΔR²中位':>10s}{'零均值':>9s}{'零SD':>8s}"
          f"{'功效':>7s}{'n':>7s}")
    summary = {}
    for win in WINDOWS:
        wname = f"{win[0]:g}-{win[1]:g}"
        st = {}
        for x in rec:
            if x["window"] != wname or x["beta_k"] != 0.0 or not np.isfinite(x["dR2"]):
                continue
            st.setdefault((x["mouse"], x["phase"]), []).append(x["dR2"])
        st = {k: (float(np.mean(v)), float(np.std(v, ddof=1)) + 1e-12)
              for k, v in st.items() if len(v) >= 10}
        for bk in BETAS_K:
            zs = []
            for x in rec:
                if x["window"] != wname or x["beta_k"] != bk or not np.isfinite(x["dR2"]):
                    continue
                k = (x["mouse"], x["phase"])
                if k in st:
                    zs.append((x["dR2"] - st[k][0]) / st[k][1])
            if not zs:
                continue
            pw = float(np.mean(np.array(zs) > 1.645))
            print(f"{wname:<10s}{bk:6.2f}{np.median([x['dR2'] for x in rec if x['window'] == wname and x['beta_k'] == bk and np.isfinite(x['dR2'])]):10.4f}"
                  f"{np.median([v[0] for v in st.values()]):9.4f}"
                  f"{np.median([v[1] for v in st.values()]):8.4f}{pw:7.2f}{len(zs):7d}")
            summary[f"{wname}|{bk}"] = dict(power=pw, n=len(zs))
        print()
    with open(os.path.join(HERE, "results", "_step33_summary.json"), "w",
              encoding="utf-8") as fh:
        fh.write(json.dumps(summary, indent=2, ensure_ascii=False))
    print("判读：功效>=0.8 的窗口可用；全部 <0.5 ⇒ T3 判不可判定（本数据无功效）")
    print(f"用时 {(time.time()-t0)/60:.1f} min；写出 {OUT}")


if __name__ == "__main__":
    main()

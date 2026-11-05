"""Step14_Unified.py —— 统一状态空间：把 M1（非线性回复）与 M6（环流）接到同一个对象上

为什么需要
  之前 M1 测在 2 维响应子空间、M6 测在前 10 PC，两者不是同一个动力学对象，
  不能合并成"一个非梯度稳定点"。本脚本**全部在同一个 10 维 PC 空间**里重算。

在同一个空间里一次给出
  ① 线性化不动点 x*        （VAR(1): X_{t+1}=X_t A + c ⇒ x* = c (I−A)⁻¹）
  ② 回归目标 x0            （cue 前 2.5–1.0 s 的中位状态）
  ③ dist = ‖x* − x0‖ / 数据尺度   ← **核心判据**：<1 说明是同一个点
  ④ A 的特征值 → τ 谱、τ1/τ2、Q
  ⑤ M1：幅度 vs 1 s 后残留的 Spearman ρ（VAR(1) 零模型）
  ⑥ ρ_rot（沿用 Step12 同一空间的数值）

判读
  · dist < 1 且 ρ 显著为负  → "回归目标"就是"动力学不动点" ⇒ 单一对象成立
  · dist ≫ 1                → 两者不是同一个点，之前的合并是错的
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
OUT = os.path.join(HERE, "results", "_step14_unified.json")
PRE = (-2.5, -1.0)
POST = 4.0
PEAK_WIN = (0.0, 1.5)
LAG1S = 1.0
KPC = 10
PHASES = ["Learned", "Transfer", "Final"]
N_SIM = 30


def fit_var1(X):
    Z, Zn = X[:-1], X[1:]
    M = np.column_stack([np.ones(len(Z)), Z])
    coef, *_ = np.linalg.lstsq(M, Zn, rcond=None)
    res = Zn - M @ coef
    return coef[0], coef[1:].T, np.cov(res.T)     # c, A, Σ


def fixed_point(c, A):
    d = A.shape[0]
    try:
        return np.linalg.solve((np.eye(d) - A).T, c)
    except np.linalg.LinAlgError:
        return np.full(d, np.nan)


def pre_state(X, cue, fs):
    seg = []
    for c in cue:
        a, b = int(c + PRE[0] * fs), int(c + PRE[1] * fs)
        if a >= 0 and b <= len(X) and b > a:
            seg.append(X[a:b])
    if not seg:
        return None
    return np.median(np.concatenate(seg), axis=0)


def trials_rho(X, cue, x0, fs):
    """幅度 vs 峰值后 1 s 的归一化残留。"""
    A, R = [], []
    i0, i1 = int(PEAK_WIN[0] * fs), int(PEAK_WIN[1] * fs)
    lag = int(LAG1S * fs)
    for c in cue:
        a, b = int(c), int(c + POST * fs)
        if a < 0 or b > len(X):
            continue
        d = X[a:b] - x0
        m = np.linalg.norm(d, axis=1)
        if len(m) <= i1 + lag:
            continue
        ip = int(np.argmax(m[i0:i1])) + i0
        amp = float(m[ip])
        if amp <= 0 or ip + lag >= len(m):
            continue
        u = d[ip] / amp
        A.append(amp)
        R.append(float((d[ip + lag] @ u) / amp))
    if len(A) < 10:
        return np.nan, len(A)
    from scipy.stats import spearmanr
    return float(spearmanr(A, R).correlation), len(A)


def sim_var1(X, cue, mu, c, A, S, rng):
    n, d = X.shape
    L = np.linalg.cholesky(S + 1e-12 * np.eye(d))
    e = rng.standard_normal((n, d)) @ L.T
    Z = np.empty((n, d))
    Z[0] = X[0]
    for t in range(1, n):
        Z[t] = c + A @ Z[t - 1] + e[t]
    if mu is not None:
        for cue_i in cue:
            a = int(cue_i)
            b = min(a + len(mu), n)
            if a >= 0 and b > a:
                Z[a:b] += mu[: b - a]
    return Z


def main():
    t0 = time.time()
    ms = scan_cohort("ALB", phases=PHASES)
    ms.sort(key=lambda b: (b["mouse"], PHASES.index(b["phase"])))

    # 复用 Step12 同空间的 ρ_rot
    try:
        s12 = {(x["mouse"], x["phase"]): x for x in
               json.load(open(os.path.join(HERE, "results", "_step12_nonrev.json"), encoding="utf-8"))}
    except Exception:
        s12 = {}

    rows = []
    print(f"{'鼠':<9s}{'阶段':<8s}{'dist':>6s}{'|λ1|':>6s}{'τ1/τ2':>6s}{'Q':>6s}"
          f"{'M1 ρ':>7s}{'p':>6s}{'nTr':>4s}{'ρ_rot':>7s}")
    for b in ms:
        d = load_block(b["path"])
        fs = d["fs"]
        Y = np.nan_to_num(AC.dff(d["X"], fs), nan=0.0, posinf=0.0, neginf=0.0)
        Y = Y[:, np.std(Y, axis=0) > 1e-9]
        Z = AC.zscore_robust(AC.VARIANTS["P1"](Y, fs))
        X, _, _, _ = T.pcs(Z, KPC)
        X = X / max(np.median(np.linalg.norm(X, axis=1)), 1e-12)

        cue = np.sort(d.get("idx_cue", []))
        if len(cue) < 10:
            continue
        x0 = pre_state(X, cue, fs)
        if x0 is None:
            continue
        c, A, S = fit_var1(X)
        xs = fixed_point(c, A)

        spread = float(np.median(np.linalg.norm(X - x0, axis=1)))
        dist = float(np.linalg.norm(xs - x0) / max(spread, 1e-12)) if np.all(np.isfinite(xs)) else np.nan

        ev = np.linalg.eigvals(A)
        mag = np.clip(np.abs(ev), 1e-12, 1 - 1e-12)
        tau = -(1.0 / fs) / np.log(mag)
        o = np.argsort(-tau)
        tau = tau[o]
        tau_ratio = float(tau[0] / tau[1]) if len(tau) > 1 else np.nan
        Q = 0.0
        for e in ev:
            if abs(e) < 0.3 or abs(e) >= 1 or abs(np.imag(e)) < 1e-6:
                continue
            Q = max(Q, float(abs(np.imag(e)) / max(abs(np.log(abs(e))), 1e-12)))

        rho, ntr = trials_rho(X, cue, x0, fs)

        # 零模型：VAR(1) + 真实 trial 平均响应
        resp = []
        for cue_i in cue:
            a, bb = int(cue_i), int(cue_i + POST * fs)
            if a >= 0 and bb <= len(X):
                resp.append(X[a:bb] - x0)
        mu = np.median(np.stack(resp), axis=0) if len(resp) >= 5 else None
        rng = np.random.default_rng(0)
        null = []
        for _ in range(N_SIM):
            Xs = sim_var1(X, cue, mu, c, A, S, rng)
            r2, _ = trials_rho(Xs, cue, x0, fs)
            if np.isfinite(r2):
                null.append(r2)
        p = (float((1 + sum(v <= rho for v in null)) / (len(null) + 1))
             if null and np.isfinite(rho) else np.nan)

        r12 = s12.get((b["mouse"], b["phase"]), {})
        rows.append(dict(mouse=b["mouse"], phase=b["phase"], dist=dist,
                         mag1=float(mag[o][0]), tau_ratio=tau_ratio, Q=Q,
                         rho=rho, p=p, n_trial=int(ntr),
                         null_med=float(np.median(null)) if null else np.nan,
                         rho_rot=r12.get("rho_rot", np.nan),
                         spread=spread,
                         x_star=[float(v) for v in xs], x0=[float(v) for v in x0]))
        print(f"{b['mouse']:<9s}{b['phase']:<8s}{dist:6.2f}{mag[o][0]:6.3f}{tau_ratio:6.2f}"
              f"{Q:6.2f}{rho:7.2f}{p:6.3f}{ntr:4d}{r12.get('rho_rot', float('nan')):7.3f}")

    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(rows, indent=2, ensure_ascii=False))

    if rows:
        dd = np.array([x["dist"] for x in rows])
        pp = np.array([x["p"] for x in rows])
        tr = np.array([x["tau_ratio"] for x in rows])
        print(f"\n=== 统一空间汇总（{len(rows)} session）===")
        print(f"dist = ‖x*−x0‖/尺度：中位 {np.nanmedian(dd):.2f}"
              f"（{np.nanmin(dd):.2f}–{np.nanmax(dd):.2f}）；<1 的 {int((dd < 1).sum())}/{len(dd)}")
        print(f"M1 ρ：中位 {np.nanmedian([x['rho'] for x in rows]):.2f}；"
              f"显著(p<0.05) {int((pp < 0.05).sum())}/{len(pp)}")
        print(f"τ1/τ2：中位 {np.nanmedian(tr):.2f}；Q>0.5 的 "
              f"{sum(1 for x in rows if x['Q'] > 0.5)}/{len(rows)}")
    print(f"\n用时 {(time.time()-t0)/60:.1f} min；写出 {OUT}")


if __name__ == "__main__":
    main()

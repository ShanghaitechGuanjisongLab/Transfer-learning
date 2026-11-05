"""Step10_TICA.py —— 用 TICA 无模型地检验「谱隙 / 慢流形」（替代 rSLDS 的 ③）

为什么换方法
  rSLDS 的 D=5 是任意选的，谱隙结论建在它上面不牢。TICA 直接在时间滞后统计上
  解广义特征值问题，不需要状态数、不需要变分推断：
      C(τ) v = λ C(0) v ,   τ_i = −τ·Δt / ln|λ_i|

设计（2026-10-23 用户确认）
  · 特征：ΔF/F → P1（剔共模超慢，防漂移占据慢模式）→ 逐细胞 z-score → 前 K 个 PC
  · 滞后：1/2/4/8/16/32/64 帧（0.125–8 s）
  · 拆半：按 trial 长度配对分 A/B，各自独立算谱，检验可复现性
  · 零模型：逐细胞相位随机化（保自协方差、毁跨细胞时序）

判据
  · τ1/τ2 < 2                      → 无谱隙
  · τ1/τ2 ≥ 5 且两半一致且超过零模型 → 存在慢流形
  · 慢模式与群体均值强相关          → 判定为漂移，不算
"""
from __future__ import annotations

import json
import os
import time

import numpy as np
from scipy.linalg import eig as geig

import attractor_core as AC
from rslds_data import load_block, scan_cohort

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "results", "_step10_tica.json")

LAGS = [1, 2, 4, 8, 16, 32, 64]
KPC = 10
N_PERM = 20
REF_LAG = 16
PHASES = ["Learned", "Transfer", "Final"]


# --------------------------------------------------------------------------- #
def prep(Z):
    return Z


def pcs(Z, k=KPC):
    Zc = Z - Z.mean(0)
    G = Zc.T @ Zc / max(len(Zc) - 1, 1)
    ev, V = np.linalg.eigh(G)
    o = np.argsort(ev)[::-1]
    ev, V = ev[o], V[:, o]
    k = min(k, Z.shape[1])
    X = Zc @ V[:, :k]
    pm = Zc.mean(1)
    for j in range(k):
        if np.corrcoef(X[:, j], pm)[0, 1] < 0:
            X[:, j] *= -1
    return X, ev[:k], V[:, :k], pm


def split_trials(Z, trials, rng):
    """按长度排序两两配对，随机分给 A/B，截断到等长；返回段的 (start, len)。"""
    order = np.argsort([e - s for s, e in trials])
    A, B = [], []
    for p in range(0, len(order) - 1, 2):
        i, j = order[p], order[p + 1]
        L = min(trials[i][1] - trials[i][0], trials[j][1] - trials[j][0])
        if rng.random() < 0.5:
            i, j = j, i
        A.append((trials[i][0], L))
        B.append((trials[j][0], L))
    return A, B


def covs(X, segs, lag):
    C0 = np.zeros((X.shape[1], X.shape[1]))
    Ct = np.zeros_like(C0)
    n = 0
    for s, L in segs:
        if L <= lag + 1:
            continue
        a = X[s:s + L - lag]
        b = X[s + lag:s + L]
        C0 += a.T @ a
        Ct += a.T @ b
        n += len(a)
    if n < 50:
        return None, None
    return C0 / n, Ct / n


def tica_times(X, segs, lags, fs, ridge=1e-8):
    """返回 {lag: (timescales, eigvals, eigvecs)}，timescales 降序。"""
    out = {}
    for lag in lags:
        C0, Ct = covs(X, segs, lag)
        if C0 is None:
            continue
        C0 = 0.5 * (C0 + C0.T)
        Ct = 0.5 * (Ct + Ct.T)
        tr = np.trace(C0) / len(C0)
        C0 = C0 + ridge * tr * np.eye(len(C0))
        try:
            w, v = geig(Ct, C0)
        except Exception:
            continue
        w = w.real
        mag = np.clip(np.abs(w), 1e-12, 1 - 1e-12)
        ts = -(lag / fs) / np.log(mag)
        o = np.argsort(-ts)
        out[lag] = (ts[o], w[o], v.real[:, o])
    return out


def phase_rand(Z, rng):
    F = np.fft.rfft(Z, axis=0)
    ph = rng.uniform(0, 2 * np.pi, size=F.shape)
    ph[0] = 0.0
    return np.fft.irfft(np.abs(F) * np.exp(1j * (np.angle(F) + ph)), n=Z.shape[0], axis=0)


# --------------------------------------------------------------------------- #
def main():
    t0 = time.time()
    ms = scan_cohort("ALB", phases=PHASES)
    ms.sort(key=lambda b: (b["mouse"], PHASES.index(b["phase"])))
    rows = []

    print(f"{'鼠':<9s}{'阶段':<8s}{'τ1(s)':>8s}{'τ2(s)':>8s}{'τ1/τ2':>7s}"
          f"{'A/B谱一致':>10s}{'A/B载荷':>9s}{'零模型τ1/τ2':>12s}{'漂移相关':>9s}")
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

        rng = np.random.default_rng(0)
        segA, segB = split_trials(Z, trials, rng)
        XA, evA, VA, pmA = pcs(Z)
        XB = XA.copy()
        # A/B 用同一 PC 基（两半来自同一 session，基应共享），只用各自的段
        tA = tica_times(XA, segA, LAGS, fs)
        tB = tica_times(XB, segB, LAGS, fs)
        if REF_LAG not in tA or REF_LAG not in tB:
            continue

        tsA, _, vA = tA[REF_LAG]
        tsB, _, vB = tB[REF_LAG]
        r_ab = float(tsA[0] / tsA[1]) if len(tsA) > 1 else np.nan
        r_abB = float(tsB[0] / tsB[1]) if len(tsB) > 1 else np.nan
        # 谱一致：前 5 个 log τ 的相关
        n5 = min(5, len(tsA), len(tsB))
        consist = float(np.corrcoef(np.log(tsA[:n5]), np.log(tsB[:n5]))[0, 1]) if n5 >= 3 else np.nan
        # 载荷重合：最慢特征向量
        u, w = vA[:, 0], vB[:, 0]
        ovl = float(abs(u @ w) / max(np.linalg.norm(u) * np.linalg.norm(w), 1e-12))

        # 慢模式与群体均值相关（判漂移）
        proj = XA @ vA[:, 0]
        driftcorr = float(abs(np.corrcoef(proj, pmA)[0, 1]))

        # 零模型（只在半 A 上做，省时）
        null_ratio = []
        for _ in range(N_PERM):
            Zn = phase_rand(Z, rng)
            Xn, _, _, _ = pcs(Zn)
            tn = tica_times(Xn, segA, [REF_LAG], fs)
            if REF_LAG in tn and len(tn[REF_LAG][0]) > 1:
                tt = tn[REF_LAG][0]
                null_ratio.append(float(tt[0] / tt[1]))
        null_med = float(np.median(null_ratio)) if null_ratio else np.nan
        p = ((1 + sum(v >= r_ab for v in null_ratio)) / (len(null_ratio) + 1)
             if null_ratio and np.isfinite(r_ab) else np.nan)

        rows.append(dict(mouse=b["mouse"], phase=b["phase"], fs=fs,
                         tau1=float(tsA[0]), tau2=float(tsA[1]), ratio=r_ab,
                         ratio_B=r_abB, consist=consist, loading_overlap=ovl,
                         drift_corr=driftcorr, null_ratio_med=null_med, p=p,
                         n_perm=len(null_ratio),
                         tau_profile={str(l): float(tA[l][0][0]) for l in tA}))
        print(f"{b['mouse']:<9s}{b['phase']:<8s}{tsA[0]:8.1f}{tsA[1]:8.1f}{r_ab:7.2f}"
              f"{consist:10.2f}{ovl:9.2f}{null_med:12.2f}{driftcorr:9.2f}")

    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(rows, indent=2, ensure_ascii=False))

    if rows:
        r = np.array([x["ratio"] for x in rows])
        print(f"\n=== 汇总（{len(rows)} 个 session）===")
        print(f"τ1/τ2：中位 {np.median(r):.2f}（{r.min():.2f}–{r.max():.2f}）；"
              f"≥5 的占 {100*np.mean(r>=5):.0f}%；≥2 的占 {100*np.mean(r>=2):.0f}%")
        dr = np.array([x["drift_corr"] for x in rows])
        print(f"慢模式-群体均值 |corr|：中位 {np.median(dr):.2f}；>0.6 的占 {100*np.mean(dr>0.6):.0f}%")
    print(f"\n用时 {(time.time()-t0)/60:.1f} min；写出 {OUT}")


if __name__ == "__main__":
    main()

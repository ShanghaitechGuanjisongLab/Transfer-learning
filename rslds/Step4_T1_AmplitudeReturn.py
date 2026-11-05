"""Step4_T1_AmplitudeReturn.py —— T1：cue 作扰动后，「回归时间常数是否随偏离幅度变小」

逻辑
  线性 OU：回归 τ 与推出多远**无关**（这正是线性系统的定义性质）
  有 basin 边界的非线性吸引子：推得越远，回复越快 ⇒ τ 随幅度下降

零模型（关键）
  不能用相位随机化（会把 cue 响应一起毁掉，必然"显著"）。
  改用**参数化 bootstrap**：
     ① 保留真实的 trial 平均 cue 响应 μ(Δ)
     ② 用 VAR(1) 拟合残差波动（= 线性动力学）
     ③ 合成 = μ + VAR(1) 噪声，与真实等长、同 trial 数、同噪声水平
     ④ 跑**完全相同**的分析
  ⇒ 线性动力学下 Δτ 应为 0（只含噪声底造成的偏差）；真实 Δτ 显著更负即为非线性证据。

统计量
  Δτ = τ(低幅度三分位) − τ(高幅度三分位)   （>0 表示高幅度回得更快）
"""
from __future__ import annotations

import json
import os

import numpy as np

import attractor_core as AC
from rslds_data import load_block, scan_cohort

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "results", "_step4_t1.json")

FS_FALLBACK = 8.0
D = 2
PRE = (-3.0, -0.5)      # 基线窗（秒，相对 cue）
POST = 4.0              # 刺激后窗（秒）
PEAK_WIN = (0.0, 1.5)   # 峰搜索窗
TAU_GRID = np.arange(0.0, 2.01, 0.125)   # 相对峰值的时间网格
# ⚠ 不要超过峰值后可用长度：POST=4 s、峰值最晚 1.5 s ⇒ 只剩 ~2.4 s。
# 之前设到 3.0 s 会让 np.interp 产生 NaN，导致所有 trial 被误丢。
N_SIM = 100


# --------------------------------------------------------------------------- #
def baseline_state(X, cue_idx, fs):
    seg = []
    for tc in cue_idx:
        a, b = int(tc + PRE[0] * fs), int(tc + PRE[1] * fs)
        if a >= 0 and b <= len(X):
            seg.append(X[a:b])
    if not seg:
        return None, np.nan
    S = np.concatenate(seg)
    x0 = np.median(S, axis=0)
    m = np.linalg.norm(S - x0, axis=1)
    sd = 1.4826 * np.median(np.abs(m - np.median(m)))
    return x0, float(max(sd, 1e-9))


def trial_curves(X, cue_idx, x0, sd_base, fs):
    """返回每个 trial 的 (A, t_peak, 相对峰值的归一化衰减曲线)。"""
    out = []
    i0, i1 = int(PEAK_WIN[0] * fs), int(PEAK_WIN[1] * fs)
    for tc in cue_idx:
        a, b = int(tc), int(tc + POST * fs)
        if a < 0 or b > len(X):
            continue
        d = X[a:b] - x0
        m = np.linalg.norm(d, axis=1)
        if len(m) <= i1:
            continue
        ip = int(np.argmax(m[i0:i1])) + i0
        A = float(m[ip])
        if A < 3.0 * sd_base:
            continue
        u = d[ip] / A
        s = d @ u                      # 沿峰值方向的有符号投影
        # 相对峰值的衰减曲线（只在峰值之后）
        rel = s[ip:] / A
        dt = np.arange(len(rel)) / fs
        grid = np.interp(TAU_GRID, dt, rel, left=np.nan, right=np.nan)
        out.append(dict(A=A, t_peak=ip / fs, curve=grid))
    return out


LAG = 1.0        # 峰值后固定滞后（秒）——比拟合 τ 稳定得多
MIN_TRIAL = 10


def rho_stat(trials, lag=LAG):
    """幅度 A vs 「峰值后 lag 秒处的归一化衰减」的 Spearman 相关。

    OU（线性）：衰减与幅度无关 ⇒ ρ ≈ 0
    超线性：推得越远回得越快 ⇒ r(lag) 随 A 下降 ⇒ ρ < 0
    比拟合 τ 稳定（后者在 low-amplitude 组常因曲线未跌破阈值而失败）。
    """
    from scipy.stats import spearmanr
    A, R = [], []
    for t in trials:
        c = t["curve"]
        if not np.all(np.isfinite(c)):
            continue
        v = float(np.interp(lag, TAU_GRID, c))
        A.append(t["A"])
        R.append(v)
    if len(A) < MIN_TRIAL:
        return np.nan, len(A)
    rho = spearmanr(A, R).correlation
    return float(rho), len(A)


def delta_tau(trials):
    """兼容旧接口：返回 (rho, nan, nan)"""
    rho, n = rho_stat(trials)
    return rho, np.nan, float(n)


# --------------------------------------------------------------------------- #
def fit_var1(X):
    Z, Zn = X[:-1], X[1:]
    A = np.column_stack([np.ones(len(Z)), Z])
    coef, *_ = np.linalg.lstsq(A, Zn, rcond=None)
    res = Zn - A @ coef
    return coef, np.cov(res.T)


def simulate_var1(X, cue_idx, mu, coef, cov, rng, fs):
    """μ 为 trial 平均 cue 响应（长度 = POST 帧数，d 维），叠加到 VAR(1) 轨迹上。"""
    n, d = X.shape
    L = np.linalg.cholesky(cov + 1e-12 * np.eye(d))
    z = np.zeros((n, d), dtype=float)
    c0, B = coef[0], coef[1:].T          # B: d×d
    e = rng.standard_normal((n, d)) @ L.T
    z[0] = X[0]
    for t in range(1, n):
        z[t] = c0 + B @ z[t - 1] + e[t]
    if mu is not None:
        for tc in cue_idx:
            a = int(tc)
            b = min(a + len(mu), n)
            if a >= 0 and b > a:
                z[a:b] += mu[: b - a]
    return z


# --------------------------------------------------------------------------- #
def cue_col(m):
    """权威 cue 下标（Trials.SampleRange.Tag → idx_cue）；缺失时退回 CD1 上升沿。

    绝不用 idx_SoundOn / idx_LightOn（EventLog 派生，与钙不同步）。
    """
    if len(m.get("idx_cue", [])) >= 8:
        return np.sort(m["idx_cue"]), "idx_cue"
    import event_align as EA
    on = EA.channel_onsets(m.get("cd1", []), m["fs"], min_gap_s=2.0)
    return on, "CD1"


def analyse_one(mouse, phase, want_sims=N_SIM, seed=0):
    ms = scan_cohort("ALB")
    rec = [x for x in ms if x["mouse"] == mouse and x["phase"] == phase]
    if not rec:
        return None
    m = load_block(rec[0]["path"])
    fs = m["fs"]
    cue, kind = cue_col(m)
    if len(cue) < 9:
        return None

    Y = AC.dff(m["X"], fs)
    Y = np.nan_to_num(Y, nan=0.0, posinf=0.0, neginf=0.0)
    Y = Y[:, np.std(Y, axis=0) > 1e-9]
    Zs = AC.zscore_robust(AC.VARIANTS["P1"](Y, fs))

    # ---- 响应子空间（不是总方差 PCA）----
    segs = []
    for tc in cue:
        a, b = int(tc - 1.0 * fs), int(tc + POST * fs)
        if a >= 0 and b <= len(Zs):
            segs.append(Zs[a:b])
    if len(segs) < 8:
        return None
    R = np.median(np.stack(segs), axis=0)
    R = R - R[: int(1.0 * fs)].mean(axis=0, keepdims=True)
    _u, sv, Vt = np.linalg.svd(R, full_matrices=False)
    U = Vt[:D].T                      # (N, k) —— 细胞空间里的响应方向
    X = Zs @ U
    evr = sv[:D] ** 2 / max((sv ** 2).sum(), 1e-30)

    x0, sd_base = baseline_state(X, cue, fs)
    if x0 is None:
        return None
    trials = trial_curves(X, cue, x0, sd_base, fs)
    d_obs, t_lo, t_hi = delta_tau(trials)

    # trial 平均响应
    nPost = int(POST * fs)
    resp = []
    for tc in cue:
        a, b = int(tc), int(tc + nPost)
        if a >= 0 and b <= len(X):
            resp.append(X[a:b] - x0)
    mu = np.median(np.stack(resp), axis=0) if resp else None

    coef, cov = fit_var1(X)
    rng = np.random.default_rng(seed)
    null = []
    for _ in range(want_sims):
        Xs = simulate_var1(X, cue, mu, coef, cov, rng, fs)
        ts = trial_curves(Xs, cue, x0, sd_base, fs)
        dv, _, _ = delta_tau(ts)
        if np.isfinite(dv):
            null.append(dv)
    null = np.array(null)
    p = (1 + (null <= d_obs).sum()) / (len(null) + 1) if len(null) and np.isfinite(d_obs) else np.nan
    return dict(mouse=mouse, phase=phase, cue=kind, n_trial_used=int(t_hi),
                n_cue=int(len(cue)), resp_evr=float(np.sum(evr)),
                rho=d_obs,
                null_med=float(np.median(null)) if len(null) else np.nan,
                null_p5=float(np.percentile(null, 5)) if len(null) else np.nan,
                p=float(p), n_sim=int(len(null)))


def main():
    rows = []
    phases = ["Learned", "Transfer", "Final"]
    print(f"{'鼠':<9s}{'phase':<9s}{'cue':<6s}{'nTr':>4s}{'nCue':>5s}{'respVar':>8s}"
          f"{'rho':>8s}{'null中位':>9s}{'null5%':>9s}{'p':>7s}")
    ms = scan_cohort("ALB")
    mice = sorted({x["mouse"] for x in ms})
    for mouse in mice:
        for ph in phases:
            r = analyse_one(mouse, ph)
            if r is None:
                continue
            rows.append(r)
            print(f"{r['mouse']:<9s}{r['phase']:<9s}{r['cue']:<6s}{r['n_trial_used']:4d}"
                  f"{r['n_cue']:5d}{r['resp_evr']*100:7.1f}%"
                  f"{r['rho']:8.3f}{r['null_med']:9.3f}{r['null_p5']:9.3f}{r['p']:7.3f}")

    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(rows, indent=2, ensure_ascii=False))
    print(f"\n写出 {OUT}")


if __name__ == "__main__":
    main()

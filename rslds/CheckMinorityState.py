"""CheckMinorityState.py —— 那个「少数状态」是第二个体制，还是 4 帧的瞬态/噪声？

(bb) 发现 11/11 只鼠的 K=2 都是一边占 80–99 %、另一边占 1–20 %，
少数状态驻留中位只有 0.48 s ≈ 8 Hz 下 4 个采样点。这必须查清楚。

四个判据：

  ① **寿命（帧数）**：少数 run 的长度分布、单帧/双帧占比。
  ② **是否被事件诱发**：少数状态的**占用率 PSTH**（不是只看切换时刻 ——
     每只鼠只有 26–30 个试次，落在窗口里的切换常常不足 8 个，锁时检验没有功效）。
     PSTH 用全部时间点；null = **循环平移整个状态序列** 1000 次。
  ③ **两次进入是否真的分开**：每个少数 run 的潜均值相对多数状态均值的 Mahalanobis 距离；
     null = **同样长度的连续窗**从多数状态里抽
     （5 维里单个随机点的马氏距离期望就是 √5≈2.24，不做长度匹配的 null 会得出错误印象）。
  ④ **寿命 vs 数据自相关时间**：$\\tau_{ac}$ = FA 输出的自相关 e 折时间。

用法：  .venv\\Scripts\\python rslds\\CheckMinorityState.py [--only 2] [--nperm 1000]
"""

from __future__ import annotations

import argparse
import json
import os
import sys

import numpy as np

import rslds_data as rd
from RunRSLDS2 import N_OBS

HERE = os.path.dirname(os.path.abspath(__file__))
FIGDIR = os.path.join(HERE, "results", "fig1")
WIN = (-1.0, 3.0)          # 事件相对时间窗（秒）
N_AMP = 200                # 幅度零分布的重复次数


def runs_of(mask):
    m = np.concatenate([[False], np.asarray(mask, bool), [False]]).astype(np.int8)
    d = np.diff(m)
    st = np.where(d == 1)[0]
    en = np.where(d == -1)[0]
    return st, en - st


def autocorr_time(Y, fs, max_s=120.0):
    Yc = Y - Y.mean(axis=0)
    T = Yc.shape[0]
    n = 1 << int(np.ceil(np.log2(2 * T)))
    F = np.fft.rfft(Yc, n=n, axis=0)
    ac = np.fft.irfft(F * np.conj(F), n=n, axis=0)[:T]
    ac /= ac[0]
    acf = ac.mean(axis=1)
    nl = int(min(T - 1, round(max_s * fs)))
    below = np.where(acf[:nl] < np.exp(-1))[0]
    return float(below[0] / fs) if below.size else float(nl / fs)


def lick_onsets(cd2, fs, thr=5.0, min_gap=0.8, min_dur=0.05):
    lick = cd2 > np.median(cd2) + thr
    st, ln = runs_of(lick)
    keep = ln >= max(1, int(round(min_dur * fs)))
    st = st[keep]
    if st.size < 2:
        return st
    gap = np.diff(st) / fs
    out = [st[0]]
    for j in range(1, st.size):
        if gap[j - 1] >= min_gap:
            out.append(st[j])
    return np.asarray(out)


def psth_test(mask, events, T, fs, rng, nperm):
    """少数状态占用率的 PSTH 检验；null = 循环平移状态序列。"""
    lo, hi = WIN
    offs = np.arange(int(round(lo * fs)), int(round(hi * fs)) + 1)
    if events.size < 5 or offs.size < 5:
        return dict(z=np.nan, p=np.nan, peak_s=np.nan, n_ev=int(events.size))

    def stat(m):
        idx = (events[:, None] + offs[None, :]) % T
        p = m[idx].mean(axis=0)
        base = m.mean()
        se = np.sqrt(base * (1 - base) / max(1, events.size)) + 1e-6
        zz = (p - base) / se
        j = int(np.argmax(np.abs(zz)))
        return float(zz[j]), float(offs[j] / fs)

    z0, pk = stat(mask)
    nullz = np.array([abs(stat(np.roll(mask, int(rng.integers(1, T))))[0])
                      for _ in range(nperm)])
    p = float((nullz >= abs(z0)).mean()) if np.isfinite(z0) else np.nan
    return dict(z=z0, p=p, peak_s=pk, n_ev=int(events.size))


def amp_vs_null(x, mask, runs, nrep, rng):
    """少数 run 的潜均值相对多数状态均值；null = 同长度连续窗。"""
    maj = x[~mask]
    if maj.shape[0] < 20:
        return np.nan, np.nan, np.nan
    mu = maj.mean(axis=0)
    Ci = np.linalg.inv(np.cov(maj.T) + 1e-6 * np.eye(x.shape[1]))
    st, ln = runs

    def d_of(win):
        dm = win.mean(axis=0) - mu
        return float(np.sqrt(dm @ Ci @ dm))

    obs = np.array([d_of(x[s0:s0 + l0]) for s0, l0 in zip(st, ln)])
    mst, mln = runs_of(~mask)
    if mst.size == 0:
        return float(np.median(obs)), np.nan, np.nan
    nulls = np.empty(nrep)
    for r in range(nrep):
        draws = []
        for l0 in ln:
            ok = np.where(mln >= l0)[0]
            if ok.size == 0:
                continue
            j = ok[rng.integers(0, ok.size)]
            s0 = mst[j] + int(rng.integers(0, mln[j] - l0 + 1))
            draws.append(d_of(x[s0:s0 + l0]))
        nulls[r] = np.median(draws) if draws else np.nan
    o = float(np.median(obs))
    return o, float(np.nanmedian(nulls)), float((nulls >= o).mean())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--seed", type=int, default=0)
    ap.add_argument("--only", type=int, default=None)
    ap.add_argument("--nperm", type=int, default=1000)
    a = ap.parse_args()

    blocks = [b for b in rd.scan_cohort("ALB", phases=["Transfer"])
              if b["design"] == "LightWater"]
    if a.only:
        blocks = blocks[:a.only]

    print("=== 少数状态：寿命 / 诱发 / 幅度（D=5, K=2）===", flush=True)
    print("%-9s %5s %6s %7s %7s %6s %8s %7s %7s %16s %16s %16s %7s %5s"
          % ("鼠", "run", "占率", "驻留帧", "1帧%", "τac", "驻留/τac", "幅度σ", "零中位",
             "PSTH cue", "PSTH 水", "PSTH 舔", "p(幅度)", "事件"), flush=True)
    rows = []
    rng = np.random.default_rng(a.seed)
    for i, b in enumerate(blocks):
        d = rd.load_block(b["path"])
        assert rd.check_orientation(d)
        fs = d["fs"]
        X = d["X"][:, d["cell_ok"] >= 1.0]
        Z = rd.zscore_cols(rd.detrend_bleach(X, fs))
        Y, _ = rd.factor_analysis(Z, N_OBS, seed=a.seed)
        z = np.load(os.path.join(FIGDIR, "fig1_%s_K2.npz" % b["mouse"]))
        lab, x = z["z"], z["x"]
        T = lab.size
        occ = np.array([(lab == k).mean() for k in range(2)])
        mn = int(np.argmin(occ))
        mask = lab == mn
        rn = runs_of(mask)
        dur_f = rn[1]
        tau = autocorr_time(Y, fs)
        amp, amp_null, amp_p = amp_vs_null(x, mask, rn, N_AMP, rng)

        ev = {
            "cue": np.unique(np.concatenate([d["idx_SoundOn"], d["idx_LightOn"]])),
            "water": d["idx_GiveWater"],
            "lick": lick_onsets(d["cd2"], fs),
        }
        pl = {k: psth_test(mask, v, T, fs, rng, a.nperm) for k, v in ev.items()}
        n_ev = max(pl[k]["n_ev"] for k in pl)

        print("%-9s %5d %6.2f %7.1f %7.1f %6.1f %8.3f %7.2f %7.2f %16s %16s %16s %7.3f %5d"
              % (b["mouse"], len(dur_f), occ[mn], float(np.median(dur_f)),
                 100 * float((dur_f <= 1).mean()), tau,
                 float(np.median(dur_f)) / fs / tau, amp, amp_null,
                 "z=%.1f p=%.3f" % (pl["cue"]["z"], pl["cue"]["p"]),
                 "z=%.1f p=%.3f" % (pl["water"]["z"], pl["water"]["p"]),
                 "z=%.1f p=%.3f" % (pl["lick"]["z"], pl["lick"]["p"]),
                 amp_p, n_ev), flush=True)
        rows.append(dict(mouse=b["mouse"], n_run=int(len(dur_f)), occ_minor=float(occ[mn]),
                         dwell_frames_median=float(np.median(dur_f)),
                         dwell_s_median=float(np.median(dur_f) / fs),
                         frac_len1=float((dur_f <= 1).mean()),
                         frac_len2=float((dur_f <= 2).mean()),
                         tau_ac_s=tau, dwell_over_tau=float(np.median(dur_f)) / fs / tau,
                         amp_sigma=amp, amp_null_median=amp_null, amp_p=amp_p,
                         psth=pl, n_events=int(n_ev), fs=fs,
                         dur_min=float(T / fs / 60)))

    sm = os.path.join(FIGDIR, "minority_state.json")
    old = json.load(open(sm, encoding="utf-8")) if os.path.exists(sm) else []
    keys = {r["mouse"] for r in rows}
    allrows = [r for r in old if r["mouse"] not in keys] + rows
    allrows.sort(key=lambda r: r["mouse"])
    with open(sm, "w", encoding="utf-8") as fh:
        json.dump(allrows, fh, ensure_ascii=False, indent=1)

    g = lambda k: np.array([r[k] for r in allrows], dtype=float)
    df, l1, ta, rt = g("dwell_frames_median"), g("frac_len1"), g("tau_ac_s"), g("dwell_over_tau")
    am, an, ap = g("amp_sigma"), g("amp_null_median"), g("amp_p")
    print("\n=== 汇总（%d 只鼠）===" % len(allrows), flush=True)
    print("少数状态驻留：中位 %.1f 帧 = %.2f s（%.1f–%.1f 帧）"
          % (np.median(df), np.median(df) / 8, df.min(), df.max()), flush=True)
    print("≤1 帧的 run 占比：中位 %.0f%%（最高 %.0f%%）" % (100 * np.median(l1), 100 * l1.max()), flush=True)
    print("数据自相关 e 折时间 τac：中位 %.1f s" % np.median(ta), flush=True)
    print("驻留 / τac：中位 %.3f" % np.median(rt), flush=True)
    print("幅度：观测中位 %.2f σ vs 同长度零分布中位 %.2f σ；p<0.05 的 %d/%d"
          % (np.nanmedian(am), np.nanmedian(an), int((ap < 0.05).sum()), int(np.isfinite(ap).sum())),
          flush=True)
    for k, lb in [("cue", "cue"), ("water", "给水"), ("lick", "舔水起始")]:
        Z = np.array([r["psth"][k]["z"] for r in allrows], dtype=float)
        P = np.array([r["psth"][k]["p"] for r in allrows], dtype=float)
        ok = np.isfinite(P)
        print("PSTH %-6s：最大 |z| 中位 %.1f；p<0.05 的 %d/%d"
              % (lb, np.nanmedian(np.abs(Z)), int((P[ok] < 0.05).sum()), int(ok.sum())), flush=True)
    print("\n判据：单帧占比高 / 幅度≈零分布 / PSTH 无峰 ⇒ 少数状态是瞬态或噪声，不是第二个体制",
          flush=True)
    print("DONE", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())

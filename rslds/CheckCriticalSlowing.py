"""CheckCriticalSlowing.py —— 切换前有没有「临界慢化」？还是干脆是诱发出来的？

如果状态切换是**吸引子之间的噪声驱动跃迁**，经典的 early-warning signal 是：
接近切换时
  · 波动**方差**上升（盆底变平）
  · **一阶自相关 / 恢复率变慢**（AR1 → 1）
  · 且这些是**逐渐**发生的（ramp），不是一步跳变

如果是**输入诱发的瞬态**，切换前不该有前兆——切换跟事件之间的潜伏期应该是
一个**窄而稳定的峰**，而不是靠噪声慢慢积累过去。

两个检验：
  ① **CSD**：把两次进入切换前的时间分成
        early = [t0−4 s, t0−2 s]、late = [t0−2 s, t0]
     各 2 s（都完全在切换之前，避免跨越切换把方差抬高），算线性去趋势后的
     方差与 AR1。统计量 = late/early 比值（方差）与 late−early 差（AR1）。
     null = **循环平移切换时刻**（200 次）。
  ② **锁时**：每个少数状态起点减去**最近的先前舔水起始**，看潜伏期分布；
     null 同样用循环平移。窄峰 = 诱发；宽而平 = 与事件无关。

用法：  .venv\\Scripts\\python rslds\\CheckCriticalSlowing.py [--only 2] [--nperm 200]
"""

from __future__ import annotations

import argparse
import json
import os
import sys

import numpy as np

import rslds_data as rd
from CheckMinorityState import runs_of, lick_onsets

HERE = os.path.dirname(os.path.abspath(__file__))
FIGDIR = os.path.join(HERE, "results", "fig1")
L_SEC = 2.0            # 每个窗口的长度（秒）
TAUS = (-3.0, -2.0, -1.0, 0.0)   # 窗口的右端相对切换时刻（秒）


def fixed_points(As, bs):
    D = As.shape[1]
    out = np.full((As.shape[0], D), np.nan)
    for k in range(As.shape[0]):
        M = np.eye(D) - As[k]
        if abs(np.linalg.det(M)) > 1e-10:
            out[k] = np.linalg.solve(M, bs[k])
    return out


def win_stats(series, t0, L, fs):
    """取 [t0-L, t0] 这一段，线性去趋势后返回 (均值, 方差, AR1)。"""
    n = int(round(L * fs))
    a = t0 - n
    if a < 0 or t0 > series.size:
        return None
    seg = series[a:t0].astype(np.float64)
    if seg.size < 6:
        return None
    t = np.arange(seg.size)
    seg = seg - np.polyval(np.polyfit(t, seg, 1), t)
    v = float(seg.var())
    if seg[:-1].std() < 1e-12 or seg[1:].std() < 1e-12:
        r1 = np.nan
    else:
        r1 = float(np.corrcoef(seg[:-1], seg[1:])[0, 1])
    return float(seg.mean()), v, r1


def profile(series, onsets, L, taus, fs):
    """在若干 τ 上取窗口，返回 {τ: (mean, var, ar1)} 的跨事件平均。"""
    out = {}
    for tau in taus:
        vals = []
        for t0 in onsets:
            r = win_stats(series, t0 + int(round(tau * fs)), L, fs)
            if r is not None:
                vals.append(r)
        if len(vals) >= 5:
            a = np.array(vals, dtype=float)
            out[tau] = tuple(np.nanmean(a, axis=0))
        else:
            out[tau] = (np.nan, np.nan, np.nan)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--seed", type=int, default=0)
    ap.add_argument("--only", type=int, default=None)
    ap.add_argument("--nperm", type=int, default=200)
    a = ap.parse_args()
    rng = np.random.default_rng(a.seed)

    blocks = [b for b in rd.scan_cohort("ALB", phases=["Transfer"])
              if b["design"] == "LightWater"]
    if a.only:
        blocks = blocks[:a.only]

    print("=== 切换前的临界慢化 + 锁时潜伏期 ===", flush=True)
    print("%-9s %5s %9s %9s %9s %9s %8s %9s %8s %8s"
          % ("鼠", "切入数", "var比值", "p(var)", "AR1差", "p(AR1)",
             "潜伏中位s", "IQR s", "p(潜伏)", "零中位s"), flush=True)
    rows = []
    for i, b in enumerate(blocks):
        f = os.path.join(FIGDIR, "stable_%s_K2_rho0.990.npz" % b["mouse"])
        if not os.path.exists(f):
            continue
        z = np.load(f)
        x, lab, As, bs = z["x"], z["z"].astype(int), z["As"], z["bs"]
        fs = float(z["fs"])
        occ = np.array([(lab == k).mean() for k in range(2)])
        maj, mnr = int(np.argmax(occ)), int(np.argmin(occ))
        fp = fixed_points(As, bs)
        if not np.all(np.isfinite(fp)):
            print("%-9s 定点不全，跳过" % b["mouse"], flush=True)
            continue
        d = np.linalg.norm(x - fp[maj], axis=1)          # 到多数状态定点的距离

        st, ln = runs_of(lab == mnr)
        T = lab.size
        if st.size < 5:
            print("%-9s 切入太少（%d），跳过" % (b["mouse"], st.size), flush=True)
            continue

        prof = profile(d, st, L_SEC, TAUS, fs)
        e, l = TAUS[0], TAUS[-1]
        var_e, var_l = prof[e][1], prof[l][1]
        ar_e, ar_l = prof[e][2], prof[l][2]
        vr = var_l / var_e if var_e and var_e > 0 else np.nan
        ad = ar_l - ar_e

        # null：循环平移切换时刻，且要求平移后落在多数状态
        nv, na = np.full(a.nperm, np.nan), np.full(a.nperm, np.nan)
        for k in range(a.nperm):
            sh = (st + int(rng.integers(1, T))) % T
            sh = np.sort(sh[lab[sh] == maj])
            if sh.size < 5:
                continue
            pr = profile(d, sh, L_SEC, (e, l), fs)
            if pr[e][1] and pr[e][1] > 0:
                nv[k] = pr[l][1] / pr[e][1]
                na[k] = pr[l][2] - pr[e][2]
        pv = float((nv >= vr).mean()) if np.isfinite(vr) else np.nan
        pa = float((na >= ad).mean()) if np.isfinite(ad) else np.nan

        # 锁时：切入时刻 − 最近的先前舔水起始
        dd = rd.load_block(b["path"])
        lick = lick_onsets(dd["cd2"], fs)
        lat = []
        for t0 in st:
            prev = lick[lick <= t0]
            if prev.size:
                lat.append((t0 - prev[-1]) / fs)
        lat = np.asarray(lat)
        med = float(np.median(lat)) if lat.size else np.nan
        iqr = float(np.subtract(*np.percentile(lat, [75, 25]))) if lat.size else np.nan
        # null：平移后的切入时刻的潜伏期中位
        nl = np.full(a.nperm, np.nan)
        for k in range(a.nperm):
            sh = (st + int(rng.integers(1, T))) % T
            sh = np.sort(sh[lab[sh] == maj])
            v = [(t0 - lick[lick <= t0][-1]) / fs for t0 in sh if lick[lick <= t0].size]
            if len(v) >= 5:
                nl[k] = np.median(v)
        # 单侧：实测潜伏期比随机时刻更短 ⇒ 被舔水触发
        pl = float((nl <= med).mean()) if np.isfinite(med) else np.nan
        nl_med = float(np.nanmedian(nl))

        print("%-9s %5d %9.2f %9.3f %+9.3f %9.3f %8.2f %9.2f %8.3f %8.2f"
              % (b["mouse"], st.size, vr, pv, ad, pa, med, iqr, pl, nl_med), flush=True)
        rows.append(dict(mouse=b["mouse"], n_onset=int(st.size), var_ratio=vr, p_var=pv,
                         ar1_diff=ad, p_ar1=pa, lat_median_s=med, lat_iqr_s=iqr,
                         p_lat=pl, lat_null_median_s=nl_med, fs=fs,
                         profile={str(k): dict(mean=float(v[0]), var=float(v[1]),
                                               ar1=float(v[2]))
                                  for k, v in prof.items()}))

    sm = os.path.join(FIGDIR, "critical_slowing.json")
    old = json.load(open(sm, encoding="utf-8")) if os.path.exists(sm) else []
    keys = {r["mouse"] for r in rows}
    allrows = [r for r in old if r["mouse"] not in keys] + rows
    allrows.sort(key=lambda r: r["mouse"])
    blob = json.dumps(allrows, ensure_ascii=False, indent=1)   # 先序列化，避免写一半
    with open(sm, "w", encoding="utf-8") as fh:
        fh.write(blob)

    g = lambda k: np.array([r[k] for r in allrows], dtype=float)
    vr, pv_, ad, pa, med, iqr, nullmed = (g("var_ratio"), g("p_var"), g("ar1_diff"),
                                          g("p_ar1"), g("lat_median_s"), g("lat_iqr_s"),
                                          g("lat_null_median_s"))
    print("\n=== 汇总（%d 只鼠）===" % len(allrows), flush=True)
    print("方差 late/early：中位 %.2f；>1 的 %d/%d；p<0.05 的 %d/%d"
          % (np.nanmedian(vr), int((vr > 1).sum()), len(vr),
             int((pv_ < 0.05).sum()), int(np.isfinite(pv_).sum())), flush=True)
    print("AR1 late−early：中位 %+.3f；>0 的 %d/%d；p<0.05 的 %d/%d"
          % (np.nanmedian(ad), int((ad > 0).sum()), len(ad),
             int((pa < 0.05).sum()), int(np.isfinite(pa).sum())), flush=True)
    print("切换到最近先前舔水起始的潜伏期：中位 %.2f s；IQR 中位 %.2f s；零中位 %.2f s；p<0.05 的 %d/%d"
          % (np.nanmedian(med), np.nanmedian(iqr), np.nanmedian(nullmed),
             int((g("p_lat") < 0.05).sum()), len(allrows)), flush=True)
    print("\n判据：方差↑且AR1↑且潜伏期呈窄峰 ⇒ 更像噪声驱动的吸引子跃迁；", flush=True)
    print("      无前兆且潜伏期窄而固定 ⇒ 更像输入诱发的瞬态", flush=True)
    print("DONE", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())

"""Step21_A4_BehaviorMatch.py —— A4 行为匹配：C3-b 的 ρ 是不是"同一套舔水细胞"造成的

为什么必须做（预注册 §5-A4）
  Learned 与 Transfer 两个阶段，小鼠都在"线索→舔水→得水"。若部分细胞的 a_i 高只是
  因为它们**编码舔舐/运动**，那么 ρ(a_L, a_T) 高就是平凡的：反映共享的舔水相关活动，
  而不是同一个内部状态。若不排除，C3-b 的 ρ=0.42 随时可以被推翻。

两种做法（都做）
  A4a **分层匹配重算**：按每帧的前 2 s 舔水率分箱，箱内抽样使两阶段的舔水率分布匹配，
      然后在匹配后的帧子集上**重跑整条流水线**（ΔF/F → P1 → z → PCA → core → a）
  A4b **回归剔除**：把每个细胞的 z 对舔水率做线性回归取残差，再算 a
  另外报告**诊断**：吸引子核心帧的舔水率 vs 全体帧 —— 若核心帧本来就几乎无舔水，
  混淆按构造就很小，A4 会"轻松通过"，这一点必须写清楚，不能冒充成强证据。

舔水率定义
  从 CD2 检测舔水起始（阈值 median + 0.5×(max−median)，最小间隔 0.15 s；本项目一贯口径），
  每帧的舔水率 = 该帧之前 2 s 内的舔水次数。

判据（预注册）
  ρ 下降 < 50% ⇒ 相似性不是舔水活动造成的。

输出 results/_step21_a4.json
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
OUT = os.path.join(HERE, "results", "_step21_a4.json")

PHASES = ["Learned", "Transfer", "Final"]
KPC = 10
CORE_FRAC = 0.3
LICK_WIN = 2.0
MIN_GAP_S = 0.15
N_BIN = 5
MIN_CELL = 40


def lick_rate(cd2, fs):
    """每帧前 LICK_WIN 秒内的舔水次数。"""
    cd2 = np.asarray(cd2, dtype=float)
    thr = np.median(cd2) + 0.5 * (cd2.max() - np.median(cd2))
    above = cd2 > thr
    on = np.flatnonzero(above[1:] & ~above[:-1]) + 1
    if len(on) > 1:
        keep = [on[0]]
        for x in on[1:]:
            if x - keep[-1] > MIN_GAP_S * fs:
                keep.append(x)
        on = np.array(keep)
    w = int(LICK_WIN * fs)
    lo = on - w
    hi = on
    rate = np.zeros(len(cd2))
    if len(on):
        # 差分累加：每个 onset 给 [lo, hi) 区间 +1
        d = np.zeros(len(cd2) + 1)
        np.add.at(d, np.clip(lo, 0, len(cd2)), 1)
        np.add.at(d, np.clip(hi, 0, len(cd2)), -1)
        rate = np.cumsum(d)[: len(cd2)]
    return rate, len(on)


def a_from_frames(Y, fs, frames=None):
    """在给定帧子集上跑整条流水线，返回 a。frames=None 表示用全部。"""
    if frames is not None:
        Y = Y[frames]
    Z = AC.zscore_robust(AC.VARIANTS["P1"](Y, fs))
    X, _, _, _ = T.pcs(Z, KPC)
    r = np.linalg.norm(X - np.median(X, axis=0), axis=1)
    core = r <= np.percentile(r, 100 * CORE_FRAC)
    return Z[core].mean(0) - Z.mean(0), core


def main():
    t0 = time.time()
    bs = scan_cohort("ALB", phases=PHASES)
    by = {}
    for b in bs:
        by.setdefault(b["mouse"], {})[b["phase"]] = b

    rng = np.random.default_rng(0)
    rows = []
    print(f"{'鼠':<9s}{'nCell':>6s}{'舔水率 core/全体 (L)':>22s}{' (T)':>14s}"
          f"{'ρ_full':>8s}{'ρ_A4a':>7s}{'ρ_A4b':>7s}{'变化a':>7s}{'变化b':>7s}")
    for m, pm in sorted(by.items()):
        if not all(p in pm for p in PHASES):
            continue
        dat = {}
        for ph in PHASES:
            d = load_block(pm[ph]["path"])
            fs = d["fs"]
            Y = np.nan_to_num(AC.dff(d["X"], fs), nan=0.0, posinf=0.0, neginf=0.0)
            rate, n_lick = lick_rate(d["cd2"], fs)
            dat[ph] = dict(Y=Y, fs=fs, ok=np.std(Y, axis=0) > 1e-9,
                           zl=np.asarray(d["z_layer"]), rate=rate, uid=d["cell_uid"],
                           n_lick=n_lick)

        uid = set(dat[PHASES[0]]["uid"].tolist())
        for ph in PHASES[1:]:
            uid &= set(dat[ph]["uid"].tolist())
        uid = np.array(sorted(uid))
        sel, common = {}, None
        for ph in PHASES:
            dd = dat[ph]
            io = {int(v): i for i, v in enumerate(dd["uid"])}
            s = np.array([io[u] for u in uid])
            k = dd["ok"][s] & (dd["zl"][s] == 1)      # MOp2/3 主分析
            sel[ph] = s
            common = k if common is None else (common & k)
        n = int(common.sum())
        if n < MIN_CELL:
            continue

        # --- 诊断：核心帧的舔水率 ---
        diag = {}
        for ph in ("Learned", "Transfer"):
            dd = dat[ph]
            Yc = dd["Y"][:, sel[ph][common]]
            _, core = a_from_frames(Yc, dd["fs"])
            full = dd["rate"]
            core_rate = float(np.mean(full[core]))
            all_rate = float(np.mean(full))
            diag[ph] = (core_rate, all_rate)

        # --- A4a：分层匹配重算 ---
        allrate = np.concatenate([dat[ph]["rate"] for ph in ("Learned", "Transfer")])
        edges = np.unique(np.percentile(allrate, np.linspace(0, 100, N_BIN + 1)))
        pick = {}
        for ph in ("Learned", "Transfer"):
            pick[ph] = []
        for bi in range(len(edges) - 1):
            idx = {}
            for ph in ("Learned", "Transfer"):
                r = dat[ph]["rate"]
                idx[ph] = np.flatnonzero((r >= edges[bi]) & (r < edges[bi + 1]))
            nb = min(len(idx["Learned"]), len(idx["Transfer"]))
            if nb < 20:
                continue
            for ph in ("Learned", "Transfer"):
                pick[ph].append(rng.choice(idx[ph], nb, replace=False))
        frames = {ph: (np.sort(np.concatenate(pick[ph])) if pick[ph] else None)
                  for ph in ("Learned", "Transfer")}

        # --- 计算三种 ρ ---
        A_full, A_a, A_b = {}, {}, {}
        for ph in PHASES:
            dd = dat[ph]
            Yc = dd["Y"][:, sel[ph][common]]
            A_full[ph] = a_from_frames(Yc, dd["fs"])[0]
            if ph in frames and frames[ph] is not None:
                A_a[ph] = a_from_frames(Yc, dd["fs"], frames[ph])[0]
            # A4b：回归剔除舔水率
            Z = AC.zscore_robust(AC.VARIANTS["P1"](Yc, dd["fs"]))
            r = dd["rate"]
            r0 = r - r.mean()
            beta = (Z * r0[:, None]).mean(0) / max((r0 ** 2).mean(), 1e-12)
            Zr = Z - np.outer(r0, beta)
            Xr, _, _, _ = T.pcs(Zr, KPC)
            rr = np.linalg.norm(Xr - np.median(Xr, axis=0), axis=1)
            cored = rr <= np.percentile(rr, 100 * CORE_FRAC)
            A_b[ph] = Zr[cored].mean(0) - Zr.mean(0)

        def rho(D):
            if "Learned" not in D or "Transfer" not in D:
                return np.nan
            return float(np.corrcoef(D["Learned"], D["Transfer"])[0, 1])

        r_full = rho(A_full)
        r_a = rho(A_a)
        r_b = rho(A_b)
        ch_a = (r_full - r_a) / abs(r_full) if np.isfinite(r_a) and abs(r_full) > 1e-9 else np.nan
        ch_b = (r_full - r_b) / abs(r_full) if abs(r_full) > 1e-9 else np.nan

        rows.append(dict(mouse=m, n_cell=n, rho_full=r_full, rho_A4a=float(r_a),
                         rho_A4b=r_b, drop_A4a=float(ch_a), drop_A4b=float(ch_b),
                         core_rate_L=diag["Learned"][0], all_rate_L=diag["Learned"][1],
                         core_rate_T=diag["Transfer"][0], all_rate_T=diag["Transfer"][1],
                         n_lick_L=dat["Learned"]["n_lick"],
                         n_lick_T=dat["Transfer"]["n_lick"],
                         frac_matched=float(len(frames["Learned"]) / max(len(dat['Learned']['rate']), 1))
                         if frames["Learned"] is not None else np.nan))
        print(f"{m:<9s}{n:6d}"
              f"{diag['Learned'][0]:10.2f} / {diag['Learned'][1]:8.2f}"
              f"{diag['Transfer'][0]:8.2f} / {diag['Transfer'][1]:5.2f}"
              f"{r_full:8.3f}{r_a:7.3f}{r_b:7.3f}{ch_a:+7.0%}{ch_b:+7.0%}")

    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(rows, indent=2, ensure_ascii=False))

    if rows:
        rf = np.array([r["rho_full"] for r in rows])
        ra = np.array([r["rho_A4a"] for r in rows])
        rb = np.array([r["rho_A4b"] for r in rows])
        print(f"\n=== 汇总（{len(rows)} 只鼠）===")
        print(f"  ρ_full 中位 {np.median(rf):.3f}"
              f"   ρ_A4a(匹配) 中位 {np.nanmedian(ra):.3f}"
              f"   ρ_A4b(剔除) 中位 {np.median(rb):.3f}")
        for nm, v in (("A4a", ra), ("A4b", rb)):
            d = (rf - v) / np.maximum(np.abs(rf), 1e-9)
            keep = np.mean([(np.isfinite(x) and x < 0.5) for x in d])
            print(f"  {nm}: 下降中位 {np.nanmedian(d):+.0%}；"
                  f"下降<50% 的鼠 {int(np.sum(np.isfinite(d) & (d < 0.5)))}/{len(d)}")
        print(f"\n  诊断：核心帧舔水率 (L) 中位 "
              f"{np.median([r['core_rate_L'] for r in rows]):.2f} vs 全体 "
              f"{np.median([r['all_rate_L'] for r in rows]):.2f}")
        print(f"        核心帧舔水率 (T) 中位 "
              f"{np.median([r['core_rate_T'] for r in rows]):.2f} vs 全体 "
              f"{np.median([r['all_rate_T'] for r in rows]):.2f}")
    print(f"\n用时 {(time.time()-t0)/60:.1f} min；写出 {OUT}")


if __name__ == "__main__":
    main()

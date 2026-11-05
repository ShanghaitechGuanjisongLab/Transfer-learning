"""Step39_TrainingSeries.py —— 训练进度（会话序号）序列分析

背景
  A.22 发现三阶段的"观测旋转量"相同，但"相对于自身零基线"不同：
  Transfer 1.38、Final 1.13、Learned 1.11。两个"晚期/熟练"状态都落在 1.1，
  只有"首次接触新关联"的 Transfer 落在 1.4。
  假设：**非梯度结构追踪的是新奇性/不确定性，而不是固定的阶段属性。**

检验方式
  导出数据里有 48 场**未标注的中间训练场次**。按 (鼠, design) 内的时间顺序排成序列，
  AudioWater：rank1 = Naive（首次声-水），最后 = Learned
  LightWater：rank1 = Transfer（首次光-水），最后 = Final
  若上述假设成立，超额应随 rank **单调下降**；若只是阶段标签不同则不会。

方法
  · MOp2/3；三档预处理 P0/P1/P2
  · 每场：去弧（trial 锁时平均轨迹）→ 10 维 PC → 滞后协方差反对称比
  · 零基线：相位随机化 N_PERM=100（SE ≈ 0.006，足以分辨 0.05 量级差）
  · 统计量：比值 ratio = rho_res / 零基线（尺度无关，A.22 采用）

判读（预先声明）
  · 同一 design 内 逐鼠 Spearman(rank, ratio) 中位显著为负 且 首末配对显著下降
        ⇒ 支持"新奇性假设"
  · 无单调趋势但首末有差 ⇒ 只能说明"首次 vs 稳定"，不能说"随训练单调"
  · 无差异 ⇒ 假设不成立，Learned 弱的原因仍未定
"""
from __future__ import annotations

import glob
import json
import os
import time

import numpy as np
from scipy import stats

import attractor_core as AC
import Step10_TICA as T
import Step12_TICA_NonReversible as S12
from rslds_data import load_block

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "results", "_step39_training.json")
KPC = 10
LAG = 16
N_PERM = 100
MIN_CELL = 40
ARC_MAX_S = 25.0
VARIANTS = ["P0", "P1", "P2"]


def rho_of(X, tr):
    C0, Ct = S12.cov_pair(X, tr, LAG)
    if C0 is None:
        return np.nan
    return float(S12.rho_rot(Ct))


def one(path):
    d = load_block(path)
    fs = d["fs"]
    Y0 = np.nan_to_num(AC.dff(d["X"], fs), nan=0.0, posinf=0.0, neginf=0.0)
    ok = np.std(Y0, axis=0) > 1e-9
    zl = np.asarray(d.get("z_layer", np.zeros(Y0.shape[1], dtype=np.int64)))
    if zl.size != Y0.shape[1]:
        zl = np.zeros(Y0.shape[1], dtype=np.int64)
    sel = ok & (zl == 1)
    if int(sel.sum()) < MIN_CELL:
        return None
    cue = np.sort(np.asarray(d.get("idx_cue", []), dtype=np.int64))
    if len(cue) < 10:
        return None
    K = int(min(ARC_MAX_S * fs, np.diff(cue).min()))
    if K < int(LAG * 2):
        return None
    res = {}
    for v in VARIANTS:
        Z = AC.zscore_robust(AC.VARIANTS[v](Y0[:, sel], fs))
        Xr, _, _, _ = T.pcs(Z, min(KPC, int(sel.sum()) - 2))
        X = Xr / max(np.median(np.linalg.norm(Xr, axis=1)), 1e-12)
        tr = [(int(cue[i]), K) for i in range(len(cue) - 1)
              if int(cue[i]) + K <= len(X)]
        if len(tr) < 10:
            continue
        R = np.zeros((K, X.shape[1]))
        for a, _ in tr:
            R += X[a:a + K]
        R /= len(tr)
        Xr2 = X.copy()
        for a, _ in tr:
            Xr2[a:a + K] = X[a:a + K] - R
        ro, rr = rho_of(X, tr), rho_of(Xr2, tr)
        if not np.isfinite(ro):
            continue
        rng = np.random.default_rng(0)
        null = []
        for _ in range(N_PERM):
            u = rho_of(T.phase_rand(Xr2, rng), tr)
            if np.isfinite(u):
                null.append(u)
        nm = float(np.median(null)) if null else np.nan
        res[v] = dict(rho_obs=ro, rho_res=rr, res_null=nm,
                      excess=float(rr - nm) if np.isfinite(nm) else np.nan,
                      ratio=float(rr / nm) if np.isfinite(nm) and nm > 0 else np.nan)
    if not res:
        return None
    return dict(mouse=d.get("mouse", ""), phase=d.get("phase", ""),
                design=d.get("design", ""), dt=d.get("datetime", ""),
                n_cell=int(sel.sum()), data=res)


def main():
    t0 = time.time()
    files = sorted(glob.glob(os.path.join(HERE, "data", "ALB", "*.mat")))
    rows = []
    for p in files:
        r = one(p)
        if r:
            rows.append(r)
    print(f"  载入 {len(rows)}/{len(files)} 场  ({(time.time()-t0)/60:.1f} min)")

    # 按 (鼠, design) 内时间排序 → rank
    groups = {}
    for r in rows:
        groups.setdefault((r["mouse"], r["design"]), []).append(r)
    for k, g in groups.items():
        g.sort(key=lambda x: x["dt"])
        for i, r in enumerate(g):
            r["rank"] = i + 1
            r["n_in_design"] = len(g)

    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(rows, indent=2, ensure_ascii=False))

    for v in VARIANTS:
        print(f"\n================ {v} ================")
        for des in ("AudioWater", "LightWater"):
            sub = [r for r in rows if r["design"] == des and v in r["data"]]
            if not sub:
                continue
            print(f"-- {des}（{len(sub)} 场，{len({r['mouse'] for r in sub})} 只鼠）")
            print(f"{'鼠':<9s} {'rank':>10s} {'phase':<9s} {'ratio':>7s} {'超额':>8s}")
            for r in sorted(sub, key=lambda x: (x["mouse"], x["rank"])):
                dd = r["data"][v]
                print(f"{r['mouse']:<9s} {r['rank']}/{r['n_in_design']:<8d}"
                      f" {(r['phase'] or '—'):<9s} {dd['ratio']:7.3f} {dd['excess']:+8.4f}")
            # 逐鼠 Spearman(rank, ratio)
            sp = []
            for m in sorted({r["mouse"] for r in sub}):
                g = sorted([r for r in sub if r["mouse"] == m], key=lambda x: x["rank"])
                if len(g) < 4:
                    continue
                x = np.array([r["rank"] for r in g], float)
                y = np.array([r["data"][v]["ratio"] for r in g], float)
                msk = np.isfinite(y)
                if msk.sum() < 4:
                    continue
                sp.append(float(stats.spearmanr(x[msk], y[msk]).statistic))
            # 首末配对
            fa, la = [], []
            for m in sorted({r["mouse"] for r in sub}):
                g = sorted([r for r in sub if r["mouse"] == m], key=lambda x: x["rank"])
                if len(g) < 2:
                    continue
                a = g[0]["data"][v]["ratio"]
                b = g[-1]["data"][v]["ratio"]
                if np.isfinite(a) and np.isfinite(b):
                    fa.append(a)
                    la.append(b)
            print(f"   逐鼠 Spearman(rank, ratio)：n={len(sp)} 中位 {np.median(sp) if sp else np.nan:+.3f}"
                  f"  为负 {int(np.nansum(np.array(sp) < 0))}/{len(sp)}")
            if len(fa) >= 5:
                pv = stats.wilcoxon(fa, la).pvalue
                print(f"   首 vs 末配对：{np.median(fa):.3f} → {np.median(la):.3f}"
                      f"  降 {int(np.nansum(np.array(la) < np.array(fa)))}/{len(fa)}  p={pv:.4f}")

    print(f"\n用时 {(time.time()-t0)/60:.1f} min；写出 {OUT}")


if __name__ == "__main__":
    main()

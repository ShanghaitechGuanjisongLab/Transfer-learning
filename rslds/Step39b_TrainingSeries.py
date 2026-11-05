"""Step39b_TrainingSeries.py —— 训练进度序列（兼容早期导出文件）

与 Step39 相同设计，但用 `rslds_compat.load_compat` 补齐
`idxCue`（→ CD1 上升沿）与 `zLayerCode`（→ 逐细胞层表 CSV），
使 47 个早期导出的中间训练场次也能纳入。

设计（同 Step39）
  · 按 (鼠, design) 内 datetime 顺序 → rank
  · AudioWater：rank1 = Naive（首次声-水），末 = Learned
  · LightWater：rank1 = Transfer（首次光-水），末 = Final
  · 统计量 ratio = rho_res / 零基线（尺度无关）
  · 假设：非梯度结构追踪"新奇性"，故 ratio 随 rank 下降

判读（预先声明，与 Step39 相同）
  · 两 design 均出现"逐鼠 Spearman 为负"+"首末配对显著下降" ⇒ 支持新奇性假设
  · 只有 LightWater 下降 ⇒ 是光任务迁移特有的过程，不能推广为通用训练效应
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
from rslds_compat import load_compat, load_layer_map

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "results", "_step39b_training.json")
KPC = 10
LAG = 16
N_PERM = 60
MIN_CELL = 40
ARC_MAX_S = 25.0
VARIANTS = ["P0", "P1", "P2"]


def rho_of(X, tr):
    C0, Ct = S12.cov_pair(X, tr, LAG)
    if C0 is None:
        return np.nan
    return float(S12.rho_rot(Ct))


def one(path, layer_map):
    d = load_compat(path, layer_map)
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
                block_uid=int(d.get("block_uid", 0)) if "block_uid" in d else 0,
                n_cell=int(sel.sum()), n_trial=len(tr),
                compat=d.get("compat_src", ""), data=res)


def main():
    t0 = time.time()
    layer_map = load_layer_map()
    files = sorted(glob.glob(os.path.join(HERE, "data", "ALB", "*.mat")))
    rows = []
    for p in files:
        r = one(p, layer_map)
        if r:
            rows.append(r)
    n_old = sum(1 for r in rows if "CD1" in r["compat"])
    print(f"  载入 {len(rows)}/{len(files)} 场（其中 {n_old} 场用兼容路径）"
          f"  ({(time.time()-t0)/60:.1f} min)")

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
            mice = sorted({r["mouse"] for r in sub})
            print(f"-- {des}: {len(sub)} 场 / {len(mice)} 只鼠")
            sp, fa, la, fm, mids = [], [], [], [], []
            for m in mice:
                g = sorted([r for r in sub if r["mouse"] == m], key=lambda x: x["rank"])
                seq = [r["data"][v]["ratio"] for r in g]
                ph = "".join((r["phase"] or "-")[:2] + " " for r in g)
                print("   %-9s n=%d ratio %s  [%s]" % (
                    m, len(g), " ".join("%.2f" % x for x in seq), ph.strip()))
                y = np.array(seq, float)
                x = np.array([r["rank"] for r in g], float)
                msk = np.isfinite(y)
                if msk.sum() >= 4:
                    sp.append(float(stats.spearmanr(x[msk], y[msk]).statistic))
                if msk.sum() >= 2:
                    fa.append(y[msk][0])
                    la.append(y[msk][-1])
                    if msk.sum() > 2:
                        fm.append(y[msk][0])
                        mids.append(float(np.median(y[msk][1:-1])))
            if sp:
                print(f"   逐鼠 Spearman(rank,ratio): n={len(sp)} 中位 "
                      f"{np.median(sp):+.3f}  为负 {int(np.nansum(np.array(sp)<0))}/{len(sp)}")
            if len(fa) >= 5:
                p1 = stats.wilcoxon(fa, la).pvalue
                p2 = (stats.wilcoxon(fm, mids).pvalue if len(mids) >= 5 else np.nan)
                print(f"   首 {np.median(fa):.3f} → 中 {np.median(mids) if mids else np.nan:.3f}"
                      f" → 末 {np.median(la):.3f}   首-末 p={p1:.4f}  首-中 p={p2:.4f}"
                      f"   末<首 {int(np.nansum(np.array(la)<np.array(fa)))}/{len(fa)}")

    print(f"\n用时 {(time.time()-t0)/60:.1f} min；写出 {OUT}")


if __name__ == "__main__":
    main()

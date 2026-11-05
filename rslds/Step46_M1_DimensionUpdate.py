"""Step46_M1_DimensionUpdate.py —— M1（非线性回复 ρ）按最新 10 维口径重算

背景
  早期 M1 的 ρ 是在"2 维响应子空间"上算的（-0.16，25/33 负，符号检验 p=0.0015）。
  现行主分析链统一为 KPC = 10 的 PCA 潜空间（Step10/14/16/17b/26 全为 10）。
  本脚本在**同一批 session、同一预处理**下同时算 2 维与 10 维的 ρ，直接给出
  "换维度后 M1 是否还成立"，而不是靠跨脚本数字对比。

口径
  · ρ = Spearman(响应幅度 A, 峰值后 1 s 的归一化残留 R)   （Step14.trials_rho）
  · 负 ρ = 幅度越大、残留越小 ⇒ 回复越强（非线性回复）
  · 预处理：P0 / P1 / P2 三档（AC.VARIANTS）
  · 层：MOp2/3（code=1）、MOp5（code=2）
  · 检验：① 符号检验 vs 0（binomtest）② Wilcoxon signed-rank vs 0
  · 不重算置换零模型（那是 Step26 的 p 字段，单位是"每 session vs 自身零模型"）

用法:  python Step46_M1_DimensionUpdate.py
"""
from __future__ import annotations

import numpy as np
from scipy.stats import binomtest, wilcoxon

import attractor_core as AC
import Step10_TICA as T
import Step14_Unified as S14
from rslds_data import load_block, scan_cohort

PHASES = ["Learned", "Transfer", "Final"]
MIN_CELL = 40
KPC_MAX = 10
DIMS = [2, 10]
GROUPS = [("MOp2/3", 1), ("MOp5", 2)]
VARIANTS = ["P0", "P1", "P2"]


def sign_test(v):
    v = np.asarray(v, dtype=float)
    v = v[np.isfinite(v)]
    n = len(v)
    if n == 0:
        return 0, 0, np.nan
    k = int((v < 0).sum())
    p = binomtest(k, n, 0.5, alternative="two-sided").pvalue if n > 0 else np.nan
    return n, k, float(p)


def rows_for(verbose=True):
    out = []
    for b in scan_cohort("ALB", phases=PHASES):
        d = load_block(b["path"])
        fs = d["fs"]
        Y0 = np.nan_to_num(AC.dff(d["X"], fs), nan=0.0, posinf=0.0, neginf=0.0)
        ok = np.std(Y0, axis=0) > 1e-9
        zl = np.asarray(d.get("z_layer", np.zeros(Y0.shape[1], dtype=np.int64)))
        if zl.size != Y0.shape[1]:
            zl = np.zeros(Y0.shape[1], dtype=np.int64)
        cue = np.sort(np.asarray(d.get("idx_cue", []), dtype=np.int64))
        if len(cue) < 10:
            continue
        for gname, code in GROUPS:
            sel = ok & (zl == code)
            n = int(sel.sum())
            if n < MIN_CELL:
                continue
            for v in VARIANTS:
                Z = AC.zscore_robust(AC.VARIANTS[v](Y0[:, sel], fs))
                X, *_ = T.pcs(Z, min(KPC_MAX, n - 2))
                X = X / max(np.median(np.linalg.norm(X, axis=1)), 1e-12)
                for k in DIMS:
                    Xk = X[:, :k]
                    x0 = S14.pre_state(Xk, cue, fs)
                    if x0 is None:
                        continue
                    rho, ntr = S14.trials_rho(Xk, cue, x0, fs)
                    if not np.isfinite(rho):
                        continue
                    out.append(dict(mouse=b["mouse"], phase=b["phase"], group=gname,
                                    variant=v, dim=k, rho=float(rho), n_trial=int(ntr)))
        if verbose:
            print(f"  {b['mouse']:<9s}{b['phase']:<9s} done")
    return out


def main():
    rows = rows_for()
    print(f"\n=== M1 ρ：2 维 vs 10 维（{len(rows)//2} 个 session×层×档）===\n")

    for gname, _ in GROUPS:
        for v in VARIANTS:
            for k in DIMS:
                vv = np.array([r["rho"] for r in rows
                               if r["group"] == gname and r["variant"] == v and r["dim"] == k])
                n, kneg, psign = sign_test(vv)
                if n < 5:
                    continue
                try:
                    pw = float(wilcoxon(vv, alternative="less").pvalue)
                except ValueError:
                    pw = np.nan
                print(f"{gname:<8s}{v:<4s}{k:>2d}D  n={n:2d}  "
                      f"median={np.median(vv):+.3f}  neg={kneg}/{n}  "
                      f"sign p={psign:.2g}  wilcoxon(<0) p={pw:.2g}")
        print()

    # 三档是否同向
    print("=== 三档方向一致性（中位数符号） ===")
    for gname, _ in GROUPS:
        for k in DIMS:
            meds = []
            for v in VARIANTS:
                vv = [r["rho"] for r in rows
                      if r["group"] == gname and r["variant"] == v and r["dim"] == k]
                meds.append(np.median(vv) if vv else np.nan)
            s = "一致" if len({np.sign(m) for m in meds if np.isfinite(m)}) == 1 else "**不一致**"
            print(f"{gname:<8s}{k:>2d}D  P0={meds[0]:+.3f}  P1={meds[1]:+.3f}  "
                  f"P2={meds[2]:+.3f}  -> {s}")

    # 2D 与 10D 的逐 session 相关
    print("\n=== 2D 与 10D 的逐 session 一致性 ===")
    for gname, _ in GROUPS:
        for v in VARIANTS:
            a = {(r["mouse"], r["phase"]): r["rho"] for r in rows
                 if r["group"] == gname and r["variant"] == v and r["dim"] == 2}
            b = {(r["mouse"], r["phase"]): r["rho"] for r in rows
                 if r["group"] == gname and r["variant"] == v and r["dim"] == 10}
            ks = sorted(set(a) & set(b))
            if len(ks) < 5:
                continue
            va = np.array([a[k] for k in ks])
            vb = np.array([b[k] for k in ks])
            r = np.corrcoef(va, vb)[0, 1]
            same = int((np.sign(va) == np.sign(vb)).sum())
            print(f"{gname:<8s}{v:<4s}r(2D,10D)={r:+.3f}  "
                  f"符号一致 {same}/{len(ks)}")


if __name__ == "__main__":
    main()

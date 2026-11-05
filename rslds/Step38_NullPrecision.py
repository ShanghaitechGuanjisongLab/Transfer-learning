"""Step38_NullPrecision.py —— 提高零模型精度，判定"Learned 是否真的更弱"

问题
  A.18.1 报告的逐阶段结果里，Learned 未达显著而 Transfer/Final 显著。
  但同鼠配对比较（`Step32` 的已有数据）显示：
      rho_obs   L 0.253 vs T 0.252   p=0.58   ← 无差异
      rho_res   L 0.180 vs T 0.181   p=0.41   ← 无差异
      res_null  L 0.122 vs T 0.115   p=0.083  ← 边缘
      res_excess L 0.020 vs T 0.077  p=0.014  ← 看似"显著"
  即"Learned 更弱"几乎完全由**零基线高 0.016** 造成。
  而 `Step32` 的零基线只用 **N_PERM=20**，其标准误约 1.25·sd/√20 ≈ 0.014
  与这个差值同量级 ⇒ **差值本身不可靠**。

本脚本
  · 只做 MOp2/3，三档预处理
  · 把 res 的相位随机化零模型提高到 **N_PERM=200**（标准误降为 1/√10）
  · 输出逐阶段 rho_obs / rho_res / res_null / excess，以及**同鼠配对** L vs T、L vs F
  · 仍在 10 维 PC 空间做（与 Step31/32 一致），故计算便宜

判读（预先声明）
  · 提高精度后若配对 res_null 差异仍不显著 ⇒ **不主张阶段间差异**
  · 若变得显著 ⇒ "Learned 的非梯度结构确实更弱"，需另找解释
"""
from __future__ import annotations

import json
import os
import time

import numpy as np
from scipy import stats

import attractor_core as AC
import Step10_TICA as T
import Step12_TICA_NonReversible as S12
from rslds_data import load_block, scan_cohort

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "results", "_step38_nullprec.json")
PHASES = ["Learned", "Transfer", "Final"]
VARIANTS = ["P0", "P1", "P2"]
KPC = 10
LAG = 16
N_PERM = 200
MIN_CELL = 40
ARC_MAX_S = 25.0


def rho_of(X, tr):
    C0, Ct = S12.cov_pair(X, tr, LAG)
    if C0 is None:
        return np.nan
    return float(S12.rho_rot(Ct))


def main():
    t0 = time.time()
    rows = []
    for b in scan_cohort("ALB", phases=PHASES):
        d = load_block(b["path"])
        fs = d["fs"]
        Y0 = np.nan_to_num(AC.dff(d["X"], fs), nan=0.0, posinf=0.0, neginf=0.0)
        ok = np.std(Y0, axis=0) > 1e-9
        zl = np.asarray(d.get("z_layer", np.zeros(Y0.shape[1], dtype=np.int64)))
        if zl.size != Y0.shape[1]:
            zl = np.zeros(Y0.shape[1], dtype=np.int64)
        sel = ok & (zl == 1)
        if int(sel.sum()) < MIN_CELL:
            continue
        cue = np.sort(np.asarray(d.get("idx_cue", []), dtype=np.int64))
        if len(cue) < 10:
            continue
        gaps = np.diff(cue)
        K = int(min(ARC_MAX_S * fs, gaps.min()))
        if K < int(LAG * 2):
            continue
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
            X_res = X.copy()
            for a, _ in tr:
                X_res[a:a + K] = X[a:a + K] - R
            r_obs = rho_of(X, tr)
            r_res = rho_of(X_res, tr)
            if not np.isfinite(r_obs):
                continue
            rng = np.random.default_rng(0)
            null = []
            for _ in range(N_PERM):
                u = rho_of(T.phase_rand(X_res, rng), tr)
                if np.isfinite(u):
                    null.append(u)
            null = np.array(null)
            rows.append(dict(mouse=b["mouse"], phase=b["phase"], variant=v,
                             n_cell=int(sel.sum()), rho_obs=r_obs, rho_res=r_res,
                             res_null=float(np.median(null)),
                             res_p95=float(np.percentile(null, 95)),
                             res_excess=float(r_res - np.median(null)),
                             n_perm=len(null)))
        print(f"  {b['mouse']:<9s}{b['phase']:<9s} ({(time.time()-t0)/60:.1f} min)")

    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(rows, indent=2, ensure_ascii=False))

    d = {(x["mouse"], x["variant"], x["phase"]): x for x in rows}
    ms = sorted({x["mouse"] for x in rows})
    print(f"\n=== MOp2/3 逐阶段（N_PERM={N_PERM}）===")
    print(f"{'档':<4s}{'阶段':<10s}{'n':>4s}{'rho_obs':>9s}{'rho_res':>9s}"
          f"{'零基线':>9s}{'超额':>9s}{'>0':>7s}")
    out = {}
    for v in VARIANTS:
        for ph in PHASES:
            gg = [x for x in rows if x["variant"] == v and x["phase"] == ph]
            if len(gg) < 5:
                continue
            print(f"{v:<4s}{ph:<10s}{len(gg):4d}{np.median([x['rho_obs'] for x in gg]):9.3f}"
                  f"{np.median([x['rho_res'] for x in gg]):9.3f}"
                  f"{np.median([x['res_null'] for x in gg]):9.3f}"
                  f"{np.median([x['res_excess'] for x in gg]):+9.4f}"
                  f"{int(np.nansum([x['res_excess'] > 0 for x in gg])):4d}/{len(gg):<3d}")
            out[f"{v}|{ph}"] = dict(n=len(gg),
                                    rho_obs=float(np.median([x["rho_obs"] for x in gg])),
                                    rho_res=float(np.median([x["rho_res"] for x in gg])),
                                    res_null=float(np.median([x["res_null"] for x in gg])),
                                    excess=float(np.median([x["res_excess"] for x in gg])),
                                    n_pos=int(np.nansum([x["res_excess"] > 0 for x in gg])))
        print()

    print("=== 同鼠配对（提高精度后）===")
    print(f"{'档':<4s}{'对比':<16s}{'量':<11s}{'前者':>9s}{'后者':>9s}{'差':>9s}{'p':>9s}")
    for v in VARIANTS:
        for p1, p2 in (("Learned", "Transfer"), ("Learned", "Final"), ("Transfer", "Final")):
            key = [(m) for m in ms if (m, v, p1) in d and (m, v, p2) in d]
            if len(key) < 5:
                continue
            for f in ("rho_obs", "rho_res", "res_null", "res_excess"):
                a = np.array([d[(m, v, p1)][f] for m in key])
                b = np.array([d[(m, v, p2)][f] for m in key])
                try:
                    pw = stats.wilcoxon(a, b).pvalue
                except Exception:
                    pw = np.nan
                print(f"{v:<4s}{p1[:1] + '-' + p2[:2]:<16s}{f:<11s}"
                      f"{np.median(a):9.4f}{np.median(b):9.4f}{np.median(b - a):+9.4f}{pw:9.4f}")
            print()
    with open(os.path.join(HERE, "results", "_step38_summary.json"), "w", encoding="utf-8") as fh:
        fh.write(json.dumps(out, indent=2, ensure_ascii=False))
    print(f"用时 {(time.time()-t0)/60:.1f} min；写出 {OUT}")


if __name__ == "__main__":
    main()

"""Step32_M6_ArcDecompVariants.py —— M6 轨迹几何分解 × 预处理三档（P0/P1/P2）

要补的缺口（A.18 §已知缺陷 4）
  A.17 观察到 ρ_rot 的**超额**随高通变激进单调上升（MOp2/3 +0.043→+0.076→+0.119）。
  但 A.18 发现定型诱发轨迹本身就能产生很大 ρ_rot。
  而 P2（更强高通）会让诱发瞬变更锐、弧更定型 ⇒ **P2 的超额上升完全可能是 arc 变强造成的**。
  因此必须把 obs / arc / res 三分解在**同一档位内**各做一遍，看 res 超额是否也单调上升。

设计
  与 Step31b 完全一致（同帧、lag=16、25 s 截断段、obs 与 res 各配自身相位随机化零模型，
  N_PERM=20），只外加一层 variant 循环。

判读（预先声明）
  · 若 res 超额在三档下都显著 >0 且量级相近
        ⇒ 非梯度结构不是预处理的产物（A.17.4 的"正面加强"在严格口径下也成立）
  · 若 res 超额只在 P2 显著，或随高通单调上升
        ⇒ 说明 A.17 的"越去漂移越清楚"是 arc 效应，须写明
  · 若 res 超额在 P0/P1 显著、P2 消失
        ⇒ 与 M1 同样的"预处理依赖"问题，M6 也要降级
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
OUT = os.path.join(HERE, "results", "_step32_m6_variants.json")

PHASES = ["Learned", "Transfer", "Final"]
KPC = 10
LAG = 16
N_PERM = 20
MIN_CELL = 40
ARC_MAX_S = 25.0
GROUPS = [("pooled", None), ("MOp2/3", 1), ("MOp5", 2)]
VARIANTS = ["P0", "P1", "P2"]


def rho_of(X, tr):
    C0, Ct = S12.cov_pair(X, tr, LAG)
    if C0 is None:
        return np.nan
    return float(S12.rho_rot(Ct))


def null_of(X, tr, n_perm, seed=0):
    rng = np.random.default_rng(seed)
    out = []
    for _ in range(n_perm):
        v = rho_of(T.phase_rand(X, rng), tr)
        if np.isfinite(v):
            out.append(v)
    return out


def main():
    t0 = time.time()
    ms = scan_cohort("ALB", phases=PHASES)
    ms.sort(key=lambda b: (b["mouse"], PHASES.index(b["phase"])))
    rows = []
    for b in ms:
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
        gaps = np.diff(cue)
        if len(gaps) < 10:
            continue
        for v in VARIANTS:
            for gname, code in GROUPS:
                sel = ok if code is None else (ok & (zl == code))
                n = int(sel.sum())
                if n < MIN_CELL:
                    continue
                Z = AC.zscore_robust(AC.VARIANTS[v](Y0[:, sel], fs))
                Xr, _, _, _ = T.pcs(Z, min(KPC, n - 2))
                X = Xr / max(np.median(np.linalg.norm(Xr, axis=1)), 1e-12)

                K = int(min(ARC_MAX_S * fs, gaps.min()))
                if K < int(LAG * 2):
                    continue
                tr = [(int(cue[i]), K) for i in range(len(cue) - 1)
                      if int(cue[i]) + K <= len(X)]
                if len(tr) < 10:
                    continue

                R = np.zeros((K, X.shape[1]))
                for a, _ in tr:
                    R += X[a:a + K]
                R /= len(tr)
                X_res = X.copy()
                X_arc = np.zeros_like(X)
                for a, _ in tr:
                    X_arc[a:a + K] = R
                    X_res[a:a + K] = X[a:a + K] - R

                r_obs, r_arc, r_res = rho_of(X, tr), rho_of(X_arc, tr), rho_of(X_res, tr)
                if not np.isfinite(r_obs):
                    continue
                nl_o = null_of(X, tr, N_PERM)
                nl_r = null_of(X_res, tr, N_PERM)
                rows.append(dict(
                    variant=v, mouse=b["mouse"], phase=b["phase"], group=gname, n_cell=n,
                    rho_obs=r_obs, rho_arc=r_arc, rho_res=r_res,
                    obs_null=float(np.median(nl_o)) if nl_o else np.nan,
                    obs_p95=float(np.percentile(nl_o, 95)) if nl_o else np.nan,
                    obs_excess=(r_obs - float(np.median(nl_o))) if nl_o else np.nan,
                    res_null=float(np.median(nl_r)) if nl_r else np.nan,
                    res_p95=float(np.percentile(nl_r, 95)) if nl_r else np.nan,
                    res_excess=(r_res - float(np.median(nl_r))) if nl_r else np.nan))
        print(f"  {b['mouse']:<9s}{b['phase']:<9s} ({(time.time()-t0)/60:.1f} min)")

    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(rows, indent=2, ensure_ascii=False))

    print(f"\n=== M6 三分解 × 预处理三档（{len(rows)} 行）===")
    print(f"{'层':<8s}{'档':<4s}{'n':>4s}{'obs':>7s}{'超额obs':>9s}{'超95%':>7s}"
          f"{'arc':>7s}{'res':>7s}{'超额res':>9s}{'超95%':>7s}{'r>0':>7s}"
          f"{'res p':>10s}{'arc份额':>8s}")
    summary = {}
    for gname, _ in GROUPS:
        for v in VARIANTS:
            gg = [x for x in rows if x["group"] == gname and x["variant"] == v]
            if len(gg) < 5:
                continue
            o = np.array([x["rho_obs"] for x in gg])
            a = np.array([x["rho_arc"] for x in gg])
            r = np.array([x["rho_res"] for x in gg])
            eo = np.array([x["obs_excess"] for x in gg])
            er = np.array([x["res_excess"] for x in gg])
            so = int(np.nansum(o > np.array([x["obs_p95"] for x in gg])))
            sr = int(np.nansum(r > np.array([x["res_p95"] for x in gg])))
            npos = int(np.nansum(er > 0))
            pr = stats.wilcoxon(er).pvalue if len(er) > 5 else np.nan
            share = 1.0 - float(np.median(er)) / max(float(np.median(eo)), 1e-12)
            print(f"{gname:<8s}{v:<4s}{len(gg):4d}{np.median(o):7.3f}{np.median(eo):9.3f}"
                  f"{so:4d}/{len(gg):<3d}{np.median(a):7.3f}{np.median(r):7.3f}"
                  f"{np.median(er):9.3f}{sr:4d}/{len(gg):<3d}{npos:4d}/{len(gg):<3d}"
                  f"{pr:10.2e}{share:8.2f}")
            summary[f"{gname}|{v}"] = dict(
                n=len(gg), obs=float(np.median(o)), obs_null=float(np.median([x["obs_null"] for x in gg])),
                excess_obs=float(np.median(eo)), n_sig_obs=so,
                p_obs=float(stats.binomtest(so, len(gg), 0.05, alternative="greater").pvalue),
                arc=float(np.median(a)), res=float(np.median(r)),
                res_null=float(np.median([x["res_null"] for x in gg])),
                excess_res=float(np.median(er)), n_sig_res=sr,
                p_res_binom=float(stats.binomtest(sr, len(gg), 0.05, alternative="greater").pvalue),
                p_res_wilcoxon=float(pr), n_pos=npos, arc_share=float(share))
        print()
    with open(os.path.join(HERE, "results", "_step32_summary.json"), "w", encoding="utf-8") as fh:
        fh.write(json.dumps(summary, indent=2, ensure_ascii=False))
    print(f"用时 {(time.time()-t0)/60:.1f} min；写出 {OUT}")


if __name__ == "__main__":
    main()

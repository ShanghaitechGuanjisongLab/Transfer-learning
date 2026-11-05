"""Step31b_M6_ArcDecomp.py —— 同口径分解：obs / arc / res 各配自身零模型

Step31 只给了 res 的零模型，obs 的零模型来自 Step17（用的是**全长** trial 段），
而本脚本用的是**截断到 25 s** 的段 ⇒ obs 值不同（0.252 vs 0.218），不能直接相减。
本脚本在同一批帧上同时给 obs 与 res 各建相位随机化零模型，从而得到可比的
"超额分解"：

    excess_obs = obs − null(obs)
    excess_res = res − null(res)
    arc 份额   = 1 − excess_res / excess_obs

判读（与 Step31 一致）
  · excess_res 仍显著 > 0（二项检验超零 95% 的计数远超期望 5%）
        ⇒ M6 部分成立：定型轨迹解释了一部分，但残差里还有非梯度结构
  · excess_res ≈ 0  ⇒ M6 应整体撤回
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
OUT = os.path.join(HERE, "results", "_step31b_decomp.json")

PHASES = ["Learned", "Transfer", "Final"]
KPC = 10
LAG = 16
N_PERM = 20
MIN_CELL = 40
ARC_MAX_S = 25.0
GROUPS = [("pooled", None), ("MOp2/3", 1), ("MOp5", 2)]


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
        for gname, code in GROUPS:
            sel = ok if code is None else (ok & (zl == code))
            n = int(sel.sum())
            if n < MIN_CELL:
                continue
            Z = AC.zscore_robust(AC.VARIANTS["P1"](Y0[:, sel], fs))
            Xr, _, _, _ = T.pcs(Z, min(KPC, n - 2))
            X = Xr / max(np.median(np.linalg.norm(Xr, axis=1)), 1e-12)

            gaps = np.diff(cue)
            K = int(min(ARC_MAX_S * fs, gaps.min()))
            if len(gaps) < 10 or K < int(LAG * 2):
                continue
            tr = [(int(cue[i]), K) for i in range(len(cue) - 1) if int(cue[i]) + K <= len(X)]
            if len(tr) < 10:
                continue

            R = np.zeros((K, X.shape[1]))
            for a, _ in tr:
                R += X[a:a + K]
            R /= len(tr)
            X_arc = np.zeros_like(X)
            X_res = X.copy()
            for a, _ in tr:
                X_arc[a:a + K] = R
                X_res[a:a + K] = X[a:a + K] - R

            r_obs, r_arc, r_res = rho_of(X, tr), rho_of(X_arc, tr), rho_of(X_res, tr)
            if not np.isfinite(r_obs):
                continue
            nl_o = null_of(X, tr, N_PERM)
            nl_r = null_of(X_res, tr, N_PERM)
            rows.append(dict(
                mouse=b["mouse"], phase=b["phase"], group=gname, n_cell=n,
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

    print(f"\n=== M6 超额分解（{len(rows)} 个 session×层，lag=16，P1，截断 25 s）===")
    print(f"{'层':<8s}{'n':>4s}{'obs':>8s}{'零(obs)':>9s}{'超额obs':>9s}{'超95%':>8s}"
          f"{'arc':>8s}{'res':>8s}{'零(res)':>9s}{'超额res':>9s}{'超95%':>8s}{'arc份额':>9s}")
    summary = {}
    for gname, _ in GROUPS:
        gg = [x for x in rows if x["group"] == gname]
        if len(gg) < 5:
            continue
        o = np.array([x["rho_obs"] for x in gg])
        a = np.array([x["rho_arc"] for x in gg])
        r = np.array([x["rho_res"] for x in gg])
        eo = np.array([x["obs_excess"] for x in gg])
        er = np.array([x["res_excess"] for x in gg])
        so = int(np.nansum(o > np.array([x["obs_p95"] for x in gg])))
        sr = int(np.nansum(r > np.array([x["res_p95"] for x in gg])))
        share = 1.0 - float(np.median(er)) / max(float(np.median(eo)), 1e-12)
        pb_o = stats.binomtest(so, len(gg), 0.05, alternative="greater").pvalue
        pb_r = stats.binomtest(sr, len(gg), 0.05, alternative="greater").pvalue
        print(f"{gname:<8s}{len(gg):4d}{np.median(o):8.3f}{np.median([x['obs_null'] for x in gg]):9.3f}"
              f"{np.median(eo):9.3f}{so:4d}/{len(gg):<3d}{np.median(a):8.3f}{np.median(r):8.3f}"
              f"{np.median([x['res_null'] for x in gg]):9.3f}{np.median(er):9.3f}"
              f"{sr:4d}/{len(gg):<3d}{share:9.2f}")
        summary[gname] = dict(n=len(gg), obs=float(np.median(o)), obs_null=float(np.median([x['obs_null'] for x in gg])),
                              excess_obs=float(np.median(eo)), n_sig_obs=so, binom_p_obs=float(pb_o),
                              arc=float(np.median(a)), res=float(np.median(r)),
                              res_null=float(np.median([x['res_null'] for x in gg])),
                              excess_res=float(np.median(er)), n_sig_res=sr, binom_p_res=float(pb_r),
                              arc_share=float(share))
    print("\n判读：超额res 的二项 p 若仍极小 ⇒ M6 部分成立（定型轨迹只解释了 arc份额 那一部分）。")
    with open(os.path.join(HERE, "results", "_step31b_summary.json"), "w", encoding="utf-8") as fh:
        fh.write(json.dumps(summary, indent=2, ensure_ascii=False))
    print(f"用时 {(time.time()-t0)/60:.1f} min；写出 {OUT}")


if __name__ == "__main__":
    main()

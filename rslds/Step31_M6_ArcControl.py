"""Step31_M6_ArcControl.py —— M6 是否为"定型诱发轨迹"的几何产物？

要检验的替代解释
  ρ_rot = ‖A‖_F/‖S‖_F（C_τ 的反对称/对称比）不需要"旋转流场"就能非零：
  若每个 trial 都沿**同一条可重复弧线**遍历（3 s 升、15 s 落），
  这条弧反复被走过，滞后协方差天然不对称 ⇒ ρ_rot > 0。
  相位随机化零模型会摧毁跨通道相位对齐，因此判成"显著"。

三个量（同一批帧，同一 lag=16，同一奇偶分半 seed）
  obs : 原始 10 维 PC 轨迹                —— 复现既有结果
  arc : 只保留 trial 锁时平均轨迹（把 R(k) 复制到每个 trial，无 trial 间变异）
  res : 原始 − R(k)，即**去掉定型轨迹后的残差**

判读（预先声明）
  · ρ_arc ≈ ρ_obs 且 ρ_res ≈ 自身零模型      ⇒ M6 完全是轨迹几何，**降级/撤回**
  · ρ_res 显著 > 自身零模型                  ⇒ 残差里仍有非梯度结构，M6 成立且更硬
  · 中间情形                                  ⇒ 部分来自轨迹，报告两个数

为什么 res 也要配零模型
  减掉均值后自由度减少、谱也变了，必须用**残差自己的**相位随机化零模型，
  不能套用 obs 的零模型。
"""
from __future__ import annotations

import json
import os
import time

import numpy as np

import attractor_core as AC
import Step10_TICA as T
import Step12_TICA_NonReversible as S12
from rslds_data import load_block, scan_cohort

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "results", "_step31_m6_arc.json")

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
            Xraw, _, _, _ = T.pcs(Z, min(KPC, n - 2))
            sc = max(np.median(np.linalg.norm(Xraw, axis=1)), 1e-12)
            X = Xraw / sc

            gaps = np.diff(cue)
            if len(gaps) < 10:
                continue
            K = int(min(ARC_MAX_S * fs, gaps.min()))
            if K < int(LAG * 2):
                continue
            # covs/split_trials 的段格式是 (start, length)
            tr = [(int(cue[i]), K) for i in range(len(cue) - 1) if int(cue[i]) + K <= len(X)]
            if len(tr) < 10:
                continue

            # trial 锁时平均轨迹 R(k)
            R = np.zeros((K, X.shape[1]))
            for a, _ in tr:
                R += X[a:a + K]
            R /= len(tr)

            X_arc = np.zeros_like(X)
            X_res = X.copy()
            for a, _ in tr:
                X_arc[a:a + K] = R
                X_res[a:a + K] = X[a:a + K] - R

            r_obs = rho_of(X, tr)
            r_arc = rho_of(X_arc, tr)
            r_res = rho_of(X_res, tr)
            if not np.isfinite(r_obs):
                continue

            # 残差的自身零模型：直接在 PC 空间对残差做逐维相位随机化
            # （保留每一维的功率谱，摧毁跨维相位对齐 —— 与既有零模型同构）
            null = []
            rng = np.random.default_rng(0)
            for _ in range(N_PERM):
                Xn = T.phase_rand(X_res, rng)
                v = rho_of(Xn, tr)
                if np.isfinite(v):
                    null.append(v)
            rows.append(dict(mouse=b["mouse"], phase=b["phase"], group=gname,
                             n_cell=n, rho_obs=r_obs, rho_arc=r_arc, rho_res=r_res,
                             res_null_med=float(np.median(null)) if null else np.nan,
                             res_excess=(r_res - float(np.median(null))) if null else np.nan,
                             res_p=(float((1 + sum(v >= r_res for v in null)) / (len(null) + 1))
                                    if null else np.nan),
                             n_perm=len(null)))
        print(f"  {b['mouse']:<9s}{b['phase']:<9s} ({(time.time()-t0)/60:.1f} min)")

    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(rows, indent=2, ensure_ascii=False))

    print(f"\n=== M6 三分解（{len(rows)} 个 session×层，lag=16，P1）===")
    print(f"{'层':<8s}{'n':>4s}{'obs':>8s}{'arc':>8s}{'res':>8s}"
          f"{'res零中位':>11s}{'res超额':>9s}{'res>零95%':>11s}")
    summary = {}
    for gname, _ in GROUPS:
        gg = [x for x in rows if x["group"] == gname]
        if len(gg) < 5:
            continue
        o = np.array([x["rho_obs"] for x in gg])
        a = np.array([x["rho_arc"] for x in gg])
        r = np.array([x["rho_res"] for x in gg])
        nm = np.array([x["res_null_med"] for x in gg])
        ex = r - nm
        nsig = int(np.nansum(np.array([x["res_p"] for x in gg]) <= 0.05))
        print(f"{gname:<8s}{len(gg):4d}{np.median(o):8.3f}{np.median(a):8.3f}"
              f"{np.median(r):8.3f}{np.median(nm):11.3f}{np.median(ex):9.3f}"
              f"{nsig:6d}/{len(gg):<4d}")
        summary[gname] = dict(n=len(gg), obs=float(np.median(o)), arc=float(np.median(a)),
                             res=float(np.median(r)), res_null=float(np.median(nm)),
                             res_excess=float(np.median(ex)), n_sig=nsig,
                             frac_arc_explained=float(np.median(a) / max(np.median(o), 1e-12)))
    print("\n判读：arc 越接近 obs ⇒ 越可能只是定型轨迹；res 超额越接近 0 ⇒ M6 应降级。")
    with open(os.path.join(HERE, "results", "_step31_summary.json"), "w", encoding="utf-8") as fh:
        fh.write(json.dumps(summary, indent=2, ensure_ascii=False))
    print(f"用时 {(time.time()-t0)/60:.1f} min；写出 {OUT}")


if __name__ == "__main__":
    main()

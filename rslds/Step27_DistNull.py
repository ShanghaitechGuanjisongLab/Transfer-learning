"""Step27_DistNull.py —— `dist` 是否真的有判别力？（参数化自举零模型）

问题
  `Step14` 把 dist = ‖x* − x0‖ / median‖X − x0‖ 当作"点吸引子"的核心判据，报告
  32/33 < 1、中位 0.39/0.33。但注意：
    · x* = (I−A)⁻¹ c 是 VAR(1) 的**无条件均值** μ
    · x0 是 cue 前 [−2.5, −1.0] s 的中位状态
    · spread 是全体数据到 x0 的中位距离
  ⇒ dist 实际测的是"**基线离平稳均值有多远**（以典型偏离为单位）"。
  对任何无持续漂移的平稳过程，基线必在平稳均值附近 ⇒ dist 天然 < 1。
  这与已被判定失效的"不动点 + basin=1.00（OU 本身就是稳定吸引子）"是**同一类陷阱**。

本脚本的检验
  零模型 H0 = "数据就是它自己被拟合出来的 VAR(1)"。
  逐 session 用拟合的 (c,A,Σ) 生成同长度合成数据，跑完全相同的 dist 流程。
  若 dist_sim ≈ dist_obs ⇒ dist 无法区分"有吸引子"与"纯线性平稳"⇒ 判据降级为
  **一致性检查**（确认 M1 的"回归目标"与 M6 的"不动点"是同一个对象），
  而不是吸引子存在的证据。

判读规则（预先声明）
  · dist_sim 中位与 dist_obs 中位之差 < 0.10 且分布重叠 ⇒ **无判别力**
  · dist_obs 显著小于 dist_sim ⇒ 观测比线性平稳更靠近不动点 ⇒ 有弱的判别力
"""
from __future__ import annotations

import json
import os
import time

import numpy as np

import attractor_core as AC
import Step10_TICA as T
import Step14_Unified as S14
from rslds_data import load_block, scan_cohort

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "results", "_step27_distnull.json")

PHASES = ["Learned", "Transfer", "Final"]
KPC = 10
N_SIM = 20
MIN_CELL = 40
GROUPS = [("pooled", None), ("MOp2/3", 1), ("MOp5", 2)]


def dist_of(X, cue, fs):
    x0 = S14.pre_state(X, cue, fs)
    if x0 is None:
        return np.nan, np.nan
    c, A, S = S14.fit_var1(X)
    xs = S14.fixed_point(c, A)
    if not np.all(np.isfinite(xs)):
        return np.nan, np.nan
    spread = float(np.median(np.linalg.norm(X - x0, axis=1)))
    return float(np.linalg.norm(xs - x0) / max(spread, 1e-12)), float(np.linalg.norm(xs - x0))


def simulate(c, A, S, n, rng, x_init):
    d = len(c)
    L = np.linalg.cholesky(S + 1e-12 * np.eye(d))
    Xs = np.empty((n, d))
    x = np.asarray(x_init, float).copy()
    for t in range(n):
        x = A @ x + c + L @ rng.standard_normal(d)
        Xs[t] = x
    return Xs


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
            X, _, _, _ = T.pcs(Z, min(KPC, n - 2))
            X = X / max(np.median(np.linalg.norm(X, axis=1)), 1e-12)

            d_obs, _ = dist_of(X, cue, fs)
            if not np.isfinite(d_obs):
                continue
            c, A, S = S14.fit_var1(X)
            x0r = S14.pre_state(X, cue, fs)
            rng = np.random.default_rng(0)
            sims = []
            for _ in range(N_SIM):
                Xs = simulate(c, A, S, len(X), rng, x0r)
                Xs = Xs / max(np.median(np.linalg.norm(Xs, axis=1)), 1e-12)
                ds, _ = dist_of(Xs, cue, fs)
                if np.isfinite(ds):
                    sims.append(ds)
            if len(sims) < 5:
                continue
            rows.append(dict(mouse=b["mouse"], phase=b["phase"], group=gname,
                             n_cell=n, dist_obs=float(d_obs),
                             dist_sim_med=float(np.median(sims)),
                             dist_sim_p95=float(np.percentile(sims, 95)),
                             p=float((1 + sum(v <= d_obs for v in sims)) / (len(sims) + 1)),
                             n_sim=len(sims)))
        print(f"  {b['mouse']:<9s}{b['phase']:<9s} ({(time.time()-t0)/60:.1f} min)")

    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(rows, indent=2, ensure_ascii=False))

    print(f"\n=== dist 对 VAR(1) 零模型的判别力（{len(rows)} 个 session×层）===")
    print(f"{'层':<8s}{'n':>4s}{'dist_obs':>10s}{'dist_sim':>10s}{'差':>8s}"
          f"{'obs<p05':>9s}{'obs<1':>7s}")
    summary = {}
    for gname, _ in GROUPS:
        gg = [x for x in rows if x["group"] == gname]
        if len(gg) < 5:
            continue
        o = np.array([x["dist_obs"] for x in gg])
        s = np.array([x["dist_sim_med"] for x in gg])
        p = np.array([x["p"] for x in gg])
        print(f"{gname:<8s}{len(gg):4d}{np.median(o):10.3f}{np.median(s):10.3f}"
              f"{np.median(o)-np.median(s):8.3f}"
              f"{int(np.nansum(p <= 0.05)):5d}/{len(gg):<3d}{int(np.nansum(o < 1)):5d}/{len(gg):<3d}")
        summary[gname] = dict(n=len(gg), dist_obs=float(np.median(o)),
                              dist_sim=float(np.median(s)),
                              n_sig=int(np.nansum(p <= 0.05)),
                              n_lt1=int(np.nansum(o < 1)))
    print("\n判读：若 dist_obs ≈ dist_sim（差<0.10、obs<p05 计数≈期望 5%）⇒ dist 无判别力，")
    print("      它只能作为 M1 回归目标与 M6 不动点的**一致性检查**，不能当作点吸引子的证据。")
    with open(os.path.join(HERE, "results", "_step27_summary.json"), "w", encoding="utf-8") as fh:
        fh.write(json.dumps(summary, indent=2, ensure_ascii=False))
    print(f"用时 {(time.time()-t0)/60:.1f} min；写出 {OUT}")


if __name__ == "__main__":
    main()

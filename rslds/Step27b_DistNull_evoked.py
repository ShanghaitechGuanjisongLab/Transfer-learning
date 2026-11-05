"""Step27b_DistNull_evoked.py —— 正确规格的 `dist` 零模型（含诱发放应）

Step27 的教训（必须记录）
  Step27 用的零模型是 x_{t+1}=A x_t + c + ε，**不含 cue 诱发的瞬变**。
  真实数据有诱发放应，合成数据没有 ⇒ 合成数据的 pre-cue 基线是泛型样本（贴均值），
  而真实数据的基线是"静息态"，与整体均值有系统差异。
  结果 dist_sim=0.19 vs dist_obs=0.39（p=1.0，obs 永远更大）——这个差是
  **"零模型里没有诱发放应"造成的，不是"真实数据更有吸引子结构"。**
  ⇒ Step27 的结论作废，须用含诱发响应的零模型重做。

本脚本的 H0
  "数据 = 线性 VAR(1) + 每次 cue 加同一个平均诱发响应 mu"（与 M1 的零模型完全一致）
  用 S14.sim_var1(X, cue, mu, c, A, S, rng) 生成合成数据，跑完全相同的 dist 流程。

判读（预先声明）
  · dist_sim 中位与 dist_obs 中位差 < 0.10 ⇒ dist 对"线性+诱发"无判别力 ⇒ 降级为一致性检查
  · dist_obs 显著 < dist_sim（p<=0.05 计数远低于期望 5% 才算反向）⇒ 观测更贴近不动点
  · 注意 p 的定义：p=(1+#(sim<=obs))/(n+1)，p 小 ⇒ obs 小于零模型（更像吸引子）；
    p 大（接近 1）⇒ obs 大于零模型
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
OUT = os.path.join(HERE, "results", "_step27b_distnull_evoked.json")

PHASES = ["Learned", "Transfer", "Final"]
KPC = 10
N_SIM = 20
MIN_CELL = 40
GROUPS = [("pooled", None), ("MOp2/3", 1), ("MOp5", 2)]


def dist_of(X, cue, fs):
    x0 = S14.pre_state(X, cue, fs)
    if x0 is None:
        return np.nan
    c, A, S = S14.fit_var1(X)
    xs = S14.fixed_point(c, A)
    if not np.all(np.isfinite(xs)):
        return np.nan
    spread = float(np.median(np.linalg.norm(X - x0, axis=1)))
    return float(np.linalg.norm(xs - x0) / max(spread, 1e-12))


def mean_response(X, cue, x0, fs):
    resp = []
    for ci in cue:
        a, b = int(ci), int(ci + S14.POST * fs)
        if a >= 0 and b <= len(X):
            resp.append(X[a:b] - x0)
    if len(resp) < 5:
        return None
    return np.median(np.stack(resp), axis=0)


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

            x0 = S14.pre_state(X, cue, fs)
            if x0 is None:
                continue
            d_obs = dist_of(X, cue, fs)
            mu = mean_response(X, cue, x0, fs)
            if not np.isfinite(d_obs) or mu is None:
                continue
            c, A, S = S14.fit_var1(X)
            rng = np.random.default_rng(0)
            sims = []
            for _ in range(N_SIM):
                Xs = S14.sim_var1(X, cue, mu, c, A, S, rng)
                Xs = Xs / max(np.median(np.linalg.norm(Xs, axis=1)), 1e-12)
                ds = dist_of(Xs, cue, fs)
                if np.isfinite(ds):
                    sims.append(ds)
            if len(sims) < 5:
                continue
            rows.append(dict(mouse=b["mouse"], phase=b["phase"], group=gname, n_cell=n,
                             dist_obs=float(d_obs), dist_sim_med=float(np.median(sims)),
                             dist_sim_lo=float(np.percentile(sims, 5)),
                             dist_sim_hi=float(np.percentile(sims, 95)),
                             p=float((1 + sum(v <= d_obs for v in sims)) / (len(sims) + 1)),
                             n_sim=len(sims)))
        print(f"  {b['mouse']:<9s}{b['phase']:<9s} ({(time.time()-t0)/60:.1f} min)")

    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(rows, indent=2, ensure_ascii=False))

    print(f"\n=== dist 对「线性 VAR(1)+诱发响应」零模型的判别力（{len(rows)}）===")
    print(f"{'层':<8s}{'n':>4s}{'obs':>8s}{'sim中位':>9s}{'sim 5–95%':>16s}"
          f"{'差':>8s}{'obs<p05':>8s}{'obs>p95':>8s}")
    summary = {}
    for gname, _ in GROUPS:
        gg = [x for x in rows if x["group"] == gname]
        if len(gg) < 5:
            continue
        o = np.array([x["dist_obs"] for x in gg])
        s = np.array([x["dist_sim_med"] for x in gg])
        lo = np.median([x["dist_sim_lo"] for x in gg])
        hi = np.median([x["dist_sim_hi"] for x in gg])
        nlo = int(np.nansum(o < np.array([x["dist_sim_lo"] for x in gg])))
        nhi = int(np.nansum(o > np.array([x["dist_sim_hi"] for x in gg])))
        print(f"{gname:<8s}{len(gg):4d}{np.median(o):8.3f}{np.median(s):9.3f}"
              f"{lo:8.3f}–{hi:<7.3f}{np.median(o)-np.median(s):8.3f}"
              f"{nlo:4d}/{len(gg):<3d}{nhi:4d}/{len(gg):<3d}")
        summary[gname] = dict(n=len(gg), dist_obs=float(np.median(o)),
                              dist_sim=float(np.median(s)),
                              diff=float(np.median(o) - np.median(s)),
                              n_below=int(nlo), n_above=int(nhi))
    print("\n判读：差<0.10 且 obs<p05 计数≈期望(1.65/33) ⇒ dist 无判别力，只能作一致性检查。")
    with open(os.path.join(HERE, "results", "_step27b_summary.json"), "w", encoding="utf-8") as fh:
        fh.write(json.dumps(summary, indent=2, ensure_ascii=False))
    print(f"用时 {(time.time()-t0)/60:.1f} min；写出 {OUT}")


if __name__ == "__main__":
    main()

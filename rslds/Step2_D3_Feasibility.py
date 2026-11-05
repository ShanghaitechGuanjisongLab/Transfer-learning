"""Step2_D3_Feasibility.py —— D3「超线性径向回复」的可行性检验

核心问题：D3 能不能把**非线性吸引子**与**OU（线性平稳过程）**分开？

D3 的逻辑
  OU：E[Δz·û]/Δt = −r/τ   ⇒  p/r 与 r 无关（线性）
  有 basin 边界的非线性势阱：远处回归**更快** ⇒ p/r 随 r 增大

关键：本检验**不用局部线性回归**，直接用条件矩 E[Δz·û | r]，
      因此没有「回归到局部均值」的伪迹。

五类数据
  N-A1  纯共模漂移（OU 型平稳）       → 期望 superlinear_index ≈ 1
  P-C   线性 OU 吸引子 (τ=10/40)      → 期望 ≈ 1（与 N-A1 无法区分，这是**预期**）
  P-NL  非线性超线性势阱              → 期望 > 1  ← 唯一有判别力的对照
  P-L   线吸引子 (τ=8/∞)              → 期望 ≈ 1
  N-C   极限环                        → 径向剖面应变形
"""
from __future__ import annotations

import json
import os

import numpy as np

import attractor_core as AC
import Step1_Calibration as CAL

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "results", "_step2_d3.json")
N_SIM = 6
VARIANTS = ["P0", "P1"]
D = 2


def gen_nonlin_well(src, rng, R=1.0, k=1.0 / 15.0):
    """z' = −k·z·(1 + (|z|/R)^2) + 噪声 ⇒ 远处比线性回归更快。"""
    T, fs = src["Y"].shape[0], src["fs"]
    dt = 1.0 / fs
    z = np.zeros((T, 2))
    sq = np.sqrt(dt) * 0.5
    for t in range(1, T):
        rr = np.linalg.norm(z[t - 1]) / R
        z[t] = z[t - 1] - dt * k * z[t - 1] * (1.0 + rr ** 2) + sq * rng.standard_normal(2)
    return CAL._plant(z, rng)


def main():
    srcs = CAL.load_real_sources(1)
    rng = np.random.default_rng(5)

    conds = [("N-A1", CAL.gen_null_common), ("P-C", CAL.gen_point),
             ("P-NL", gen_nonlin_well), ("P-L", CAL.gen_line),
             ("N-C", CAL.gen_null_ring)]

    rec = []
    for name, gen in conds:
        for variant in VARIANTS:
            idxs, cub, r2l, r2c, taus = [], [], [], [], []
            for _ in range(N_SIM):
                Y = gen(srcs[0], rng)
                Yp = AC.VARIANTS[variant](Y, srcs[0]["fs"])
                Zs = AC.zscore_robust(Yp)
                X, evr = AC.pca_reduce(Zs, D)
                zb = AC.kde_mode(X)
                rp = AC.radial_profile(X, zb, srcs[0]["fs"])
                if not np.isfinite(rp.get("superlinear_index", np.nan)):
                    continue
                idxs.append(rp["superlinear_index"])
                cub.append(rp["cubic_coef"])
                r2l.append(rp["r2_lin"])
                r2c.append(rp["r2_cub"])
                taus.append(rp["tau_eff"])
            if not idxs:
                print(f"{name:<6s} {variant}  无有效结果")
                continue
            rec.append(dict(cond=name, variant=variant, n=len(idxs),
                            sl_index_med=float(np.median(idxs)),
                            sl_index_lo=float(np.percentile(idxs, 5)),
                            sl_index_hi=float(np.percentile(idxs, 95)),
                            cubic_med=float(np.median(cub)),
                            r2_lin=float(np.median(r2l)),
                            r2_cub=float(np.median(r2c)),
                            tau_eff=float(np.nanmedian(taus))))
            r = rec[-1]
            print(f"{name:<6s} {variant}  n={r['n']}  "
                  f"超线性指数={r['sl_index_med']:.2f} "
                  f"[{r['sl_index_lo']:.2f},{r['sl_index_hi']:.2f}]  "
                  f"三次项={r['cubic_med']:+.3f}  "
                  f"R²lin={r['r2_lin']:.2f}→cub={r['r2_cub']:.2f}  τ_eff={r['tau_eff']:.1f}s")

    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(rec, indent=2, ensure_ascii=False))
    print(f"\n写出 {OUT}")


if __name__ == "__main__":
    main()

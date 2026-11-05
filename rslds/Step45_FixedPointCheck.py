"""Step45_FixedPointCheck.py —— 核实 fixed_point() 的转置是否影响 dist

疑点
  ``Step14_Unified.fixed_point`` 写的是
      np.linalg.solve((np.eye(d) - A).T, c)
  即解 (I-A)^T x = c，得到 (I-A^T)^{-1} c。
  而 ``fit_var1`` 的模型约定是 x_{t+1} = A x_t + c（见 ``sim_var1`` 里 `Z[t] = c + A @ Z[t-1] + e`），
  真正的不动点应满足 (I-A) x = c，即 (I-A)^{-1} c。
  当 A 对称时二者相同；**A 非对称时不同**。

本脚本的判据（不依赖任何约定，只看向量是否真的是不动点）
  res(x) = ||A x + c - x|| / ||x||
  真正的不动点 res ≈ 0。谁的 res 小，谁就是对的。

同时报告 dist 的两种取值（dist = ||x* - x0|| / spread），看结论是否被改变。
"""
from __future__ import annotations

import os

import numpy as np

import attractor_core as AC
import Step10_TICA as T
import Step14_Unified as S14
from rslds_data import load_block, scan_cohort

PHASES = ["Learned", "Transfer", "Final"]
KPC = 10
MIN_CELL = 40
GROUP_CODE = 1          # MOp2/3
VARIANT = "P1"


def main():
    rows = []
    ms = scan_cohort("ALB", phases=PHASES)
    for b in ms:
        d = load_block(b["path"])
        fs = d["fs"]
        Y0 = np.nan_to_num(AC.dff(d["X"], fs), nan=0.0, posinf=0.0, neginf=0.0)
        ok = np.std(Y0, axis=0) > 1e-9
        zl = np.asarray(d.get("z_layer", np.zeros(Y0.shape[1], dtype=np.int64)))
        if zl.size != Y0.shape[1]:
            continue
        cue = np.sort(np.asarray(d.get("idx_cue", []), dtype=np.int64))
        if len(cue) < 10:
            continue
        sel = ok & (zl == GROUP_CODE)
        n = int(sel.sum())
        if n < MIN_CELL:
            continue

        Z = AC.zscore_robust(AC.VARIANTS[VARIANT](Y0[:, sel], fs))
        X, *_ = T.pcs(Z, min(KPC, n - 2))
        X = X / max(np.median(np.linalg.norm(X, axis=1)), 1e-12)
        x0 = S14.pre_state(X, cue, fs)
        if x0 is None:
            continue

        c, A, _ = S14.fit_var1(X)
        dm = A.shape[0]
        xs_code = S14.fixed_point(c, A)                    # 现有实现
        xs_true = np.linalg.solve(np.eye(dm) - A, c)       # (I-A)^{-1} c
        if not np.all(np.isfinite(xs_code)):
            continue

        spread = float(np.median(np.linalg.norm(X - x0, axis=1)))
        nrm = max(float(np.linalg.norm(xs_true)), 1e-12)
        rows.append(dict(
            mouse=b["mouse"], phase=b["phase"],
            asym=float(np.linalg.norm(A - A.T) / max(np.linalg.norm(A), 1e-12)),
            res_code=float(np.linalg.norm(A @ xs_code + c - xs_code) / nrm),
            res_true=float(np.linalg.norm(A @ xs_true + c - xs_true) / nrm),
            gap=float(np.linalg.norm(xs_code - xs_true) / max(spread, 1e-12)),
            dist_code=float(np.linalg.norm(xs_code - x0) / max(spread, 1e-12)),
            dist_true=float(np.linalg.norm(xs_true - x0) / max(spread, 1e-12)),
        ))
        print(f"  {b['mouse']:<9s}{b['phase']:<9s} done")

    if not rows:
        print("no sessions")
        return

    a = lambda k: np.array([r[k] for r in rows], dtype=float)
    print(f"\n=== n = {len(rows)} (MOp2/3, {VARIANT}) ===")
    print(f"A 非对称度  ||A-A^T||/||A||      中位 {np.median(a('asym')):.3f}")
    print(f"不动点残差 res(x)=||Ax+c-x||/||x||")
    print(f"  现有实现 (I-A)^T 求解           中位 {np.median(a('res_code')):.3e}")
    print(f"  正确 (I-A) 求解                 中位 {np.median(a('res_true')):.3e}")
    print(f"两不动点差异 / spread              中位 {np.median(a('gap')):.3f}")
    print(f"dist 现有实现                      中位 {np.median(a('dist_code')):.3f}"
          f"   <1 者 {int((a('dist_code') < 1).sum())}/{len(rows)}")
    print(f"dist 修正后                        中位 {np.median(a('dist_true')):.3f}"
          f"   <1 者 {int((a('dist_true') < 1).sum())}/{len(rows)}")
    if len(rows) > 2:
        r = np.corrcoef(a('dist_code'), a('dist_true'))[0, 1]
        print(f"两种 dist 的相关 r = {r:.4f}")
        print(f"逐 session 结论是否改变（<1 与否）: "
              f"{int(((a('dist_code') < 1) == (a('dist_true') < 1)).sum())}/{len(rows)} 一致")


if __name__ == "__main__":
    main()

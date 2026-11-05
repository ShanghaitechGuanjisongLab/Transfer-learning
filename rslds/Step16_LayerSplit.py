"""Step16_LayerSplit.py —— 分层稳健性检查：MOp2/3 vs MOp5 vs 合并

为什么需要
  此前 Step4–Step15 的所有结果都是在 **MOp2/3 + MOp5 合并** 的群体上算的
  （`ExportForRSLDS.m` 早期版本没有导出 `Cells.ZLayer`）。若两层的动力学不同，
  合并可能造出或抹掉效应。本脚本把同一套指标分别在三组上重算：

      pooled  全部细胞（= 此前所有结论的口径）
      MOp2/3  浅层
      MOp5    深层

指标（全部与 Step14 同一实现，保证可比）
  ① dist      = ‖x* − x0‖ / 数据尺度   （不动点 vs 回归目标）
  ② τ1/τ2     = VAR(1) 特征值时间常数比（M2 慢流形）
  ③ Q         = |Im λ| / |ln|λ||        （M3 焦点/振荡）
  ④ M1 ρ      = 幅度 vs 1 s 后归一化残留的 Spearman ρ，VAR(1) 零模型给 p
  ⑤ ρ_rot     = ‖Ct−Ctᵀ‖/‖Ct+Ctᵀ‖，lag=16，TICA 空间（M6 非梯度流）
                **只算观测值，不算置换零模型**（本步只问"分层是否改变结论"）

判读
  · 三层同号同量级  → 合并口径成立，此前结论不需修改
  · 两层差异大      → 合并是错的，必须分层报告
  · yqn1130 只有 MOp2/3，MOp5 组自动跳过
"""
from __future__ import annotations

import json
import os
import time

import numpy as np

import attractor_core as AC
import Step10_TICA as T
import Step12_TICA_NonReversible as S12
import Step14_Unified as S14
from rslds_data import load_block, scan_cohort

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "results", "_step16_layersplit.json")

PHASES = ["Learned", "Transfer", "Final"]
KPC = 10
LAG = 16
N_SIM = 30
MIN_CELL = 40          # 一个层少于这么多细胞就无法构建 10 维空间

GROUPS = [("pooled", None), ("MOp2/3", 1), ("MOp5", 2)]


def analyze(Y, fs, cue, kpc):
    """在给定细胞子集上算全套指标。Y 已经是该子集的 ΔF/F。"""
    Z = AC.zscore_robust(AC.VARIANTS["P1"](Y, fs))
    X, _, _, _ = T.pcs(Z, kpc)
    X = X / max(np.median(np.linalg.norm(X, axis=1)), 1e-12)

    x0 = S14.pre_state(X, cue, fs)
    if x0 is None:
        return None
    c, A, S = S14.fit_var1(X)
    xs = S14.fixed_point(c, A)

    spread = float(np.median(np.linalg.norm(X - x0, axis=1)))
    dist = (float(np.linalg.norm(xs - x0) / max(spread, 1e-12))
            if np.all(np.isfinite(xs)) else np.nan)

    ev = np.linalg.eigvals(A)
    mag = np.clip(np.abs(ev), 1e-12, 1 - 1e-12)
    tau = -(1.0 / fs) / np.log(mag)
    o = np.argsort(-tau)
    tau = tau[o]
    tau_ratio = float(tau[0] / tau[1]) if len(tau) > 1 else np.nan
    Q = 0.0
    for e in ev:
        if abs(e) < 0.3 or abs(e) >= 1 or abs(np.imag(e)) < 1e-6:
            continue
        Q = max(Q, float(abs(np.imag(e)) / max(abs(np.log(abs(e))), 1e-12)))

    rho, ntr = S14.trials_rho(X, cue, x0, fs)

    # ---- M1 零模型：VAR(1) + 真实 trial 平均响应 -------------------------------
    resp = []
    for ci in cue:
        a, b = int(ci), int(ci + S14.POST * fs)
        if a >= 0 and b <= len(X):
            resp.append(X[a:b] - x0)
    mu = np.median(np.stack(resp), axis=0) if len(resp) >= 5 else None
    rng = np.random.default_rng(0)
    null = []
    for _ in range(N_SIM):
        Xs = S14.sim_var1(X, cue, mu, c, A, S, rng)
        r2, _ = S14.trials_rho(Xs, cue, x0, fs)
        if np.isfinite(r2):
            null.append(r2)
    p = (float((1 + sum(v <= rho for v in null)) / (len(null) + 1))
         if null and np.isfinite(rho) else np.nan)

    # ---- M6：ρ_rot（只算观测值）--------------------------------------------
    # ⚠ split_trials 必须用**新鲜的 seed 0**，与 Step12 完全一致；
    #   否则 rng 已被上面的 VAR 零模型消耗，奇偶分半不同 → ρ_rot 与 Step12 不可比
    trials = [(int(cue[i]), int(cue[i + 1]) if i + 1 < len(cue) else len(Z))
              for i in range(len(cue))]
    trials = [(s, e) for s, e in trials if e - s > int(2 * fs)]
    segA, segB = T.split_trials(Z, trials, np.random.default_rng(0))
    C0a, Cta = S12.cov_pair(X, segA, LAG)
    C0b, Ctb = S12.cov_pair(X, segB, LAG)
    rho_rot = S12.rho_rot(Cta) if C0a is not None else np.nan
    rho_rot_B = S12.rho_rot(Ctb) if C0b is not None else np.nan

    return dict(dist=dist, tau_ratio=tau_ratio, Q=Q, rho=rho, p=p,
                rho_rot=rho_rot, rho_rot_B=rho_rot_B,
                n_trial=int(ntr), n_dim=int(X.shape[1]), spread=spread,
                null_med=float(np.median(null)) if null else np.nan)


def main():
    t0 = time.time()
    ms = scan_cohort("ALB", phases=PHASES)
    ms.sort(key=lambda b: (b["mouse"], PHASES.index(b["phase"])))
    rows = []

    print(f"{'鼠':<9s}{'阶段':<8s}{'层':<8s}{'nCell':>6s}{'dist':>7s}{'τ1/τ2':>7s}"
          f"{'Q':>6s}{'M1 ρ':>7s}{'p':>6s}{'ρ_rot':>7s}")
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

        for name, code in GROUPS:
            sel = ok if code is None else (ok & (zl == code))
            n_cell = int(sel.sum())
            if n_cell < MIN_CELL:
                continue
            kpc = min(KPC, n_cell - 2)
            if kpc < 3:
                continue
            r = analyze(Y0[:, sel], fs, cue, kpc)
            if r is None:
                continue
            rows.append(dict(mouse=b["mouse"], phase=b["phase"], group=name,
                             n_cell=n_cell, **r))
            print(f"{b['mouse']:<9s}{b['phase']:<8s}{name:<8s}{n_cell:6d}"
                  f"{r['dist']:7.2f}{r['tau_ratio']:7.2f}{r['Q']:6.2f}"
                  f"{r['rho']:7.2f}{r['p']:6.3f}{r['rho_rot']:7.3f}")

    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(rows, indent=2, ensure_ascii=False))

    if rows:
        print(f"\n=== 分层汇总（{len(rows)} 行）===")
        print(f"{'组':<9s}{'n':>4s}{'dist':>7s}{'τ1/τ2':>8s}{'Q':>7s}"
              f"{'M1 ρ':>8s}{'ρ_rot':>8s}")
        for name, _ in GROUPS:
            g = [x for x in rows if x["group"] == name]
            if not g:
                continue
            print(f"{name:<9s}{len(g):4d}"
                  f"{np.nanmedian([x['dist'] for x in g]):7.2f}"
                  f"{np.nanmedian([x['tau_ratio'] for x in g]):8.2f}"
                  f"{np.nanmedian([x['Q'] for x in g]):7.2f}"
                  f"{np.nanmedian([x['rho'] for x in g]):8.2f}"
                  f"{np.nanmedian([x['rho_rot'] for x in g]):8.3f}")

        # 配对比较：同一 session 的 pooled vs 各层
        print("\n=== 配对差（层 − pooled，只看该 session 三层都有的） ===")
        key = lambda x: (x["mouse"], x["phase"])
        byPair = {}
        for x in rows:
            byPair.setdefault(key(x), {})[x["group"]] = x
        for name, _ in GROUPS[1:]:
            diffs = {m: [] for m in ["dist", "tau_ratio", "Q", "rho", "rho_rot"]}
            for k, v in byPair.items():
                if "pooled" not in v or name not in v:
                    continue
                for m in diffs:
                    a, bb = v[name][m], v["pooled"][m]
                    if np.isfinite(a) and np.isfinite(bb):
                        diffs[m].append(a - bb)
            if not diffs["dist"]:
                continue
            s = "  ".join(f"{m}: 中位差 {np.median(v):+.3f} (n={len(v)})"
                          for m, v in diffs.items() if v)
            print(f"  {name:<8s}{s}")

    print(f"\n用时 {(time.time()-t0)/60:.1f} min；写出 {OUT}")


if __name__ == "__main__":
    main()

"""Step26b_PreprocNulls.py —— P0/P2 两档的 ρ_rot 相位随机化零模型

为什么必需
  `S12.rho_rot(Ct) = ||(Ct-Ct')/2||_F / ||(Ct+Ct')/2||_F` 是范数比值 ⇒ **恒非负**。
  任何"符号一致性"对该指标都无意义；唯一有效判据是"观测 − 自身零模型超额"。
  而 Step26 发现 ρ_rot 随高通越激进单调升高（MOp2/3 0.143→0.218→0.305），
  这既可能是"高通去掉了稀释旋转的慢漂移"，也可能是"滤波器本身制造了旋转"。
  零模型保留功率谱（因此也保留了滤波器对谱的全部作用），正好区分这两种解释：
    · 若零模型同步升高、超额不变 ⇒ 旋转是真的，升高来自可比性口径
    · 若零模型不动、只有观测升高 ⇒ ρ_rot 是滤波产物 ⇒ 指标降级

设计（与 Step17 完全一致，只改 VARIANTS）
  N_PERM=20；lag=16；split_trials 用 fresh default_rng(0)（保证与 Step12/16/17 可比）
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
OUT = os.path.join(HERE, "results", "_step26b_null.json")

PHASES = ["Learned", "Transfer", "Final"]
KPC = 10
LAG = 16
N_PERM = 20
MIN_CELL = 40
GROUPS = [("pooled", None), ("MOp2/3", 1), ("MOp5", 2)]
VARIANTS = ["P0", "P2"]


def layer_null(Y, fs, cue, kpc, variant, rng):
    Z = AC.zscore_robust(AC.VARIANTS[variant](Y, fs))
    X, _, _, _ = T.pcs(Z, kpc)

    trials = [(int(cue[i]), int(cue[i + 1]) if i + 1 < len(cue) else len(Z))
              for i in range(len(cue))]
    trials = [(s, e) for s, e in trials if e - s > int(2 * fs)]
    segA, segB = T.split_trials(Z, trials, np.random.default_rng(0))

    C0a, Cta = S12.cov_pair(X, segA, LAG)
    if C0a is None:
        return None
    r_a = S12.rho_rot(Cta)
    C0b, Ctb = S12.cov_pair(X, segB, LAG)
    r_b = S12.rho_rot(Ctb) if C0b is not None else np.nan

    null = []
    for _ in range(N_PERM):
        Zn = T.phase_rand(Z, rng)
        Xn, _, _, _ = T.pcs(Zn, kpc)
        c0, ct = S12.cov_pair(Xn, segA, LAG)
        if c0 is not None:
            null.append(S12.rho_rot(ct))
    if not null:
        return None
    p = float((1 + sum(v >= r_a for v in null)) / (len(null) + 1))
    return dict(rho_rot=float(r_a), rho_rot_B=float(r_b),
                null_med=float(np.median(null)),
                null_p95=float(np.percentile(null, 95)),
                excess=float(r_a - np.median(null)),
                p=p, n_perm=len(null), n_dim=int(X.shape[1]))


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
        for v in VARIANTS:
            for gname, code in GROUPS:
                sel = ok if code is None else (ok & (zl == code))
                n = int(sel.sum())
                if n < MIN_CELL:
                    continue
                r = layer_null(Y0[:, sel], fs, cue, min(KPC, n - 2), v,
                               np.random.default_rng(0))
                if r is None:
                    continue
                rows.append(dict(mouse=b["mouse"], phase=b["phase"], group=gname,
                                 variant=v, n_cell=n, **r))
        print(f"  {b['mouse']:<9s}{b['phase']:<9s} ({(time.time()-t0)/60:.1f} min)")

    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(rows, indent=2, ensure_ascii=False))

    s17 = {(x["mouse"], x["phase"], x["group"]): x
           for x in json.load(open(os.path.join(HERE, "results", "_step17_layer_nulls.json"),
                                   encoding="utf-8"))}
    d26b = {(x["variant"], x["mouse"], x["phase"], x["group"]): x for x in rows}
    keys = sorted({(x["mouse"], x["phase"], x["group"]) for x in rows})

    print(f"\n=== ρ_rot 与其自身零模型（{len(keys)} 个 session×层）===")
    print(f"{'层':<8s}{'档':<5s}{'n':>4s}{'ρ_rot':>8s}{'零中位':>8s}{'超额':>8s}"
          f"{'零95%':>8s}{'超零95%':>9s}")
    out = {}
    for gname, _ in GROUPS:
        ks = [k for k in keys if k[2] == gname]
        if len(ks) < 5:
            continue
        line = {}
        for v, tag in (("P0", "P0"), ("P1", "P1"), ("P2", "P2")):
            if v == "P1":
                gg = [s17.get(k) for k in ks]
                gg = [x for x in gg if x]
            else:
                gg = [d26b.get((v,) + k) for k in ks]
                gg = [x for x in gg if x]
            if len(gg) < 5:
                continue
            r = np.array([x["rho_rot"] for x in gg])
            nm = np.array([x["null_med"] for x in gg])
            ex = r - nm
            n95 = sum(1 for x in gg if np.isfinite(x.get("null_p95", np.nan))
                      and x["rho_rot"] > x["null_p95"])
            print(f"{gname:<8s}{tag:<5s}{len(gg):4d}{np.median(r):8.3f}"
                  f"{np.median(nm):8.3f}{np.median(ex):8.3f}"
                  f"{np.median([x.get('null_p95', np.nan) for x in gg]):8.3f}"
                  f"{n95:5d}/{len(gg)}")
            line[tag] = dict(n=len(gg), rho=float(np.median(r)),
                             null=float(np.median(nm)), excess=float(np.median(ex)),
                             n_over=int(n95))
        out[gname] = line
        print()

    with open(os.path.join(HERE, "results", "_step26b_summary.json"), "w", encoding="utf-8") as fh:
        fh.write(json.dumps(out, indent=2, ensure_ascii=False))
    print(f"用时 {(time.time()-t0)/60:.1f} min；写出 {OUT}")


if __name__ == "__main__":
    main()

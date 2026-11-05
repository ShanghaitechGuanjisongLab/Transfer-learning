"""Step17_LayerNulls.py —— 分层版 ρ_rot 零模型（相位随机化）

为什么需要
  Step16 只算了分层后的**观测** ρ_rot，没给零模型，所以只能说"MOp2/3 的 ρ_rot 比 MOp5 高"，
  不能说"MOp2/3 显著超出自身零模型"。本脚本补这一步，口径与 Step12 完全一致：

    · lag = 16（TICA 时间尺度，避开 lag=1 的误差衰减问题）
    · 零模型 = **逐细胞相位随机化**（FFT，保功率谱 ⇒ 保自协方差，毁跨细胞时序）
    · N_PERM = 20（与 Step12 相同，最小可达 p = 1/21 = 0.048）
    · 奇偶分半用**新鲜 seed 0**，与 Step12/Step16 一致

  只跑 MOp2/3 与 MOp5 两层。`pooled` 的零模型 Step12 已经算过（`_step12_nonrev.json`），
  用 `--check` 可以核对 pooled 是否复现。

输出
  results/_step17_layer_nulls.json
  每个 (鼠, 阶段, 层)：rho_rot, rho_rot_B, null 中位, p, 以及是否超过自身零模型 95 分位

用法
  python Step17_LayerNulls.py            # 跑全部（约 20 min）
  python Step17_LayerNulls.py --check    # 只核 pooled 是否与 Step12 一致（约 1 min）
"""
from __future__ import annotations

import json
import os
import sys
import time

import numpy as np

import attractor_core as AC
import Step10_TICA as T
import Step12_TICA_NonReversible as S12
from rslds_data import load_block, scan_cohort

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "results", "_step17_layer_nulls.json")
S12_JSON = os.path.join(HERE, "results", "_step12_nonrev.json")

PHASES = ["Learned", "Transfer", "Final"]
LAG = 16
KPC = 10
N_PERM = 20
MIN_CELL = 40
GROUPS = [("MOp2/3", 1), ("MOp5", 2)]


def layer_rho_rot(Y, fs, cue, kpc, rng):
    """返回观测 ρ_rot(A/B)、零模型分布、p。Y 已是该层 ΔF/F。"""
    Z = AC.zscore_robust(AC.VARIANTS["P1"](Y, fs))
    X, _, _, _ = T.pcs(Z, kpc)

    trials = [(int(cue[i]), int(cue[i + 1]) if i + 1 < len(cue) else len(Z))
              for i in range(len(cue))]
    trials = [(s, e) for s, e in trials if e - s > int(2 * fs)]
    segA, segB = T.split_trials(Z, trials, np.random.default_rng(0))

    C0a, Cta = S12.cov_pair(X, segA, LAG)
    C0b, Ctb = S12.cov_pair(X, segB, LAG)
    if C0a is None:
        return None
    r_a = S12.rho_rot(Cta)
    r_b = S12.rho_rot(Ctb) if C0b is not None else np.nan

    null = []
    for _ in range(N_PERM):
        Zn = T.phase_rand(Z, rng)
        Xn, _, _, _ = T.pcs(Zn, kpc)
        c0, ct = S12.cov_pair(Xn, segA, LAG)
        if c0 is not None:
            null.append(S12.rho_rot(ct))
    p = (float((1 + sum(v >= r_a for v in null)) / (len(null) + 1))
         if null else np.nan)
    return dict(rho_rot=float(r_a), rho_rot_B=float(r_b),
                null_med=float(np.median(null)) if null else np.nan,
                null_p95=float(np.percentile(null, 95)) if null else np.nan,
                p=p, n_perm=len(null), n_dim=int(X.shape[1]))


def main():
    check_only = "--check" in sys.argv
    t0 = time.time()

    ms = scan_cohort("ALB", phases=PHASES)
    ms.sort(key=lambda b: (b["mouse"], PHASES.index(b["phase"])))

    s12 = {}
    if os.path.exists(S12_JSON):
        s12 = {(x["mouse"], x["phase"]): x
               for x in json.load(open(S12_JSON, encoding="utf-8"))}

    groups = [("pooled", None)] if check_only else GROUPS
    rows = []
    print(f"{'鼠':<9s}{'阶段':<9s}{'层':<8s}{'nCell':>6s}{'ρ_rot':>7s}"
          f"{'零中位':>7s}{'零95%':>7s}{'p':>6s}{'A/B':>7s}  超零模型")
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

        for name, code in groups:
            sel = ok if code is None else (ok & (zl == code))
            n_cell = int(sel.sum())
            if n_cell < MIN_CELL:
                continue
            kpc = min(KPC, n_cell - 2)
            if kpc < 3:
                continue
            r = layer_rho_rot(Y0[:, sel], fs, cue, kpc, np.random.default_rng(0))
            if r is None:
                continue
            rec = dict(mouse=b["mouse"], phase=b["phase"], group=name,
                       n_cell=n_cell, **r)
            rows.append(rec)
            over = "✓" if (np.isfinite(r["p"]) and r["p"] < 0.05) else " "
            print(f"{b['mouse']:<9s}{b['phase']:<9s}{name:<8s}{n_cell:6d}"
                  f"{r['rho_rot']:7.3f}{r['null_med']:7.3f}{r['null_p95']:7.3f}"
                  f"{r['p']:6.3f}{r['rho_rot_B']:7.3f}  {over}")

    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(rows, indent=2, ensure_ascii=False))

    if check_only and s12:
        print("\n=== 与 Step12 核对（pooled）===")
        dif = []
        for r in rows:
            k = (r["mouse"], r["phase"])
            if k in s12 and np.isfinite(s12[k].get("rho_rot", np.nan)):
                dif.append(abs(r["rho_rot"] - s12[k]["rho_rot"]))
        if dif:
            print(f"  n={len(dif)}  最大绝对差 {max(dif):.6f}  中位 {np.median(dif):.6f}")
        else:
            print("  没有可比的 session（检查 _step12_nonrev.json）")
        print(f"\n用时 {(time.time()-t0)/60:.1f} min；写出 {OUT}")
        return

    if rows:
        print(f"\n=== 分层 ρ_rot 汇总（{len(rows)} 行）===")
        print(f"{'组':<9s}{'n':>4s}{'ρ_rot 中位':>11s}{'零中位':>8s}"
              f"{'p<0.05':>8s}{'超零95%':>9s}")
        for name, _ in GROUPS:
            g = [x for x in rows if x["group"] == name]
            if not g:
                continue
            print(f"{name:<9s}{len(g):4d}"
                  f"{np.nanmedian([x['rho_rot'] for x in g]):11.3f}"
                  f"{np.nanmedian([x['null_med'] for x in g]):8.3f}"
                  f"{sum(1 for x in g if np.isfinite(x['p']) and x['p'] < 0.05):5d}/{len(g)}"
                  f"{sum(1 for x in g if np.isfinite(x['p']) and x['rho_rot'] > x['null_p95']):7d}/{len(g)}")

        print("\n=== 按阶段 ===")
        for name, _ in GROUPS:
            for ph in PHASES:
                g = [x for x in rows if x["group"] == name and x["phase"] == ph]
                if not g:
                    continue
                print(f"  {name:<8s}{ph:<9s}n={len(g):2d}  ρ_rot 中位 "
                      f"{np.nanmedian([x['rho_rot'] for x in g]):.3f}  零中位 "
                      f"{np.nanmedian([x['null_med'] for x in g]):.3f}  超零模型 "
                      f"{sum(1 for x in g if np.isfinite(x['p']) and x['rho_rot'] > x['null_p95'])}/{len(g)}")

    print(f"\n用时 {(time.time()-t0)/60:.1f} min；写出 {OUT}")


if __name__ == "__main__":
    main()

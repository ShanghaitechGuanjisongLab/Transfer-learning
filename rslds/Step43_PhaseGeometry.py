"""Step43_PhaseGeometry.py —— 分阶段几何量汇总（不重算任何东西，只重新汇总已有结果）

动机
  图 FigAttractorSchematic 需要在 (a) 里并排画 Learned vs Transfer 的几何差异。
  但分阶段只报告过 ρ_rot 的超额（A.18/A.18.1）。其余几何量（dist / τ1 / τ2 / Q / M1 ρ）
  其实 Step16/17b/26 都已逐 session 算过，只是从未按 phase 汇总。

数据源（全部已存在，本脚本不产生新的估计）
  - results/_step26_preproc.json          P0 / P2：dist, rho, tau1, tau_ratio, Q(lag16), rho_rot
  - results/_step16_layersplit.json       P1：dist, rho, p, rho_rot, n_trial
  - results/_step17b_layer_spectrum.json  P1：tau1, tau2, tau_ratio, Q_lag16

⚠ 口径纪律
  - Q 一律用 lag=16：P0/P2 取 step26 的 Q（代码 LAG=16），P1 取 step17b 的 Q_lag16。
    **绝不能用 step16 的 `Q`**（那是 lag=1，已撤回，样例值 1.354）。
  - τ1 同理：P1 取 step17b（lag=16），不取 step16。
  - rho_rot 是范数比值、恒非负；跨阶段裸值比较会混入零模型基线差异，
    故本脚本对 rho_rot 只报裸值供参考，**结论须用超额**（A.18/A.18.1）。

判读
  鼠内配对（每只鼠 Learned / Transfer / Final 各一场），Wilcoxon signed-rank。
  三档预处理若方向一致才可写"稳健"；只在一档显著 → 不可判定。
"""
from __future__ import annotations

import csv
import json
import os

import numpy as np
from scipy.stats import wilcoxon

HERE = os.path.dirname(os.path.abspath(__file__))
RES = os.path.join(HERE, "results")

PHASES = ["Learned", "Transfer", "Final"]
GROUPS = ["MOp2/3", "MOp5"]
VARIANTS = ["P0", "P1", "P2"]
METRICS = ["dist", "tau1", "tau_ratio", "Q", "rho", "rho_rot"]


def load_json(name):
    path = os.path.join(RES, name)
    if not os.path.exists(path):
        return []
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def build_table():
    """返回 {(mouse, phase, group, variant): {metric: value}}"""
    s26 = load_json("_step26_preproc.json")
    s16 = {(x["mouse"], x["phase"], x["group"]): x for x in load_json("_step16_layersplit.json")}
    s17 = {(x["mouse"], x["phase"], x["group"]): x for x in load_json("_step17b_layer_spectrum.json")}

    tab = {}
    # P0 / P2 —— 全部来自 step26
    for x in s26:
        key = (x["mouse"], x["phase"], x["group"], x["variant"])
        tab[key] = {m: float(x.get(m, np.nan)) for m in METRICS}
        tab[key]["n_cell"] = int(x.get("n_cell", 0))

    # P1 —— dist/rho/rho_rot 取 step16，tau/Q 取 step17b
    for k, x in s16.items():
        key = (k[0], k[1], k[2], "P1")
        if key in tab:
            continue
        row = {m: float(x.get(m, np.nan)) for m in ("dist", "rho", "rho_rot")}
        row["n_cell"] = int(x.get("n_cell", 0))
        y = s17.get(k, {})
        row["tau1"] = float(y.get("tau1", np.nan))
        row["tau_ratio"] = float(y.get("tau_ratio", np.nan))
        row["Q"] = float(y.get("Q_lag16", np.nan))     # ← lag=16，唯一可用口径
        tab[key] = row
    return tab


def paired_test(tab, group, variant, metric, a, b):
    """鼠内配对：返回 n、中位差(b-a)、Wilcoxon p、同向数"""
    mice = sorted({k[0] for k in tab if k[2] == group and k[3] == variant})
    va, vb = [], []
    for m in mice:
        ka = (m, a, group, variant)
        kb = (m, b, group, variant)
        if ka in tab and kb in tab:
            x, y = tab[ka].get(metric, np.nan), tab[kb].get(metric, np.nan)
            if np.isfinite(x) and np.isfinite(y):
                va.append(x)
                vb.append(y)
    va, vb = np.array(va), np.array(vb)
    n = len(va)
    if n < 5:
        return n, np.nan, np.nan, 0
    d = vb - va
    med = float(np.median(d))
    try:
        p = float(wilcoxon(va, vb).pvalue)
    except ValueError:
        p = np.nan
    npos = int((d > 0).sum())
    return n, med, p, npos


def main():
    tab = build_table()
    print(f"sessions assembled: {len(tab)}")

    rows_out = []
    for k, v in sorted(tab.items()):
        rows_out.append(dict(mouse=k[0], phase=k[1], group=k[2], variant=k[3],
                             n_cell=v.get("n_cell", 0),
                             **{m: v.get(m, np.nan) for m in METRICS}))
    out1 = os.path.join(RES, "_step43_phase_geometry.csv")
    with open(out1, "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=["mouse", "phase", "group", "variant", "n_cell"] + METRICS)
        w.writeheader()
        w.writerows(rows_out)

    print("\n=== medians by phase (MOp2/3) ===")
    hdr = f"{'metric':<10s}{'variant':<4s}" + "".join(f"{p:>10s}" for p in PHASES) + \
          f"{'L→T p':>9s}{'n':>4s}{'T→F p':>9s}{'n':>4s}"
    print(hdr)
    print("-" * len(hdr))
    summ = []
    for metric in METRICS:
        for variant in VARIANTS:
            med = {}
            for ph in PHASES:
                vals = [tab[k][metric] for k in tab
                        if k[2] == "MOp2/3" and k[3] == variant and k[1] == ph
                        and np.isfinite(tab[k].get(metric, np.nan))]
                med[ph] = float(np.median(vals)) if vals else np.nan
            nLT, dLT, pLT, kLT = paired_test(tab, "MOp2/3", variant, metric, "Learned", "Transfer")
            nTF, dTF, pTF, kTF = paired_test(tab, "MOp2/3", variant, metric, "Transfer", "Final")
            print(f"{metric:<10s}{variant:<4s}" + "".join(f"{med[p]:10.3f}" for p in PHASES) +
                  f"{pLT:9.4f}{nLT:4d}{pTF:9.4f}{nTF:4d}")
            summ.append(dict(group="MOp2/3", variant=variant, metric=metric,
                             med_learned=med["Learned"], med_transfer=med["Transfer"],
                             med_final=med["Final"],
                             n_LT=nLT, d_LT=dLT, p_LT=pLT, npos_LT=kLT,
                             n_TF=nTF, d_TF=dTF, p_TF=pTF, npos_TF=kTF))
        print()

    out2 = os.path.join(RES, "_step43_phase_summary.csv")
    with open(out2, "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=list(summ[0].keys()))
        w.writeheader()
        w.writerows(summ)

    print(f"wrote {out1}\nwrote {out2}")


if __name__ == "__main__":
    main()

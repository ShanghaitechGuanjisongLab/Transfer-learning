"""Step0b_CellObservability.py —— 检查「100% 细胞交集」是否真实（只读）

Step0 发现：同一只鼠的**所有**会话细胞数完全相同（如 vtf0233 每场都是 550），
CellUID 交集恒为 100%。这有两种可能：
  (a) 慢性成像配准真的每场都追踪到全部细胞 —— 那就太好了，C3 可直接比群体向量
  (b) 导出时用固定「注册细胞表」，某场没分到的细胞被填成 NaN 或常数 —— 那 100% 是假象

判据：逐细胞看 cellFiniteFrac 与 std。
  · 若「Learned 有、Transfer 没有」的细胞在 Transfer 里 finiteFrac≈0 或 std≈0 → 是 (b)
  · 若两场都 finiteFrac≈1、std 正常 → 是 (a)

同时输出 Learned → Transfer 的时间间隔。
"""
from __future__ import annotations

import json
import os
from datetime import datetime

import numpy as np

from rslds_data import load_block, scan_cohort

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "results", "_step0b_observability.json")
os.makedirs(os.path.dirname(OUT), exist_ok=True)

FIN_THR = 0.99


def cell_stats(path):
    d = load_block(path)                     # 需要 X，读全量
    X = d["X"]                               # (T, N)
    fin = np.mean(np.isfinite(X), axis=0)    # 逐细胞有限比例（重算，不信存的值）
    with np.errstate(all="ignore"):
        sd = np.nanstd(X, axis=0)
    ok = (fin >= FIN_THR) & (sd > 0)
    return dict(uid=d["cell_uid"], fin=fin, sd=sd, ok=ok,
                finite_frac_stored=d["cell_ok"],
                n=d["n_cell"], fs=d["fs"], dur_min=d["dur_sec"] / 60,
                datetime=d["datetime"], phase=d["phase"], design=d["design"])


def main():
    ms = scan_cohort("ALB")
    by_mouse = {}
    for m in ms:
        by_mouse.setdefault(m["mouse"], {})
        by_mouse[m["mouse"]].setdefault(m["phase"], []).append(m)

    rows = []
    for mouse in sorted(by_mouse):
        ph = by_mouse[mouse]
        if "Learned" not in ph or "Transfer" not in ph:
            continue
        L = ph["Learned"][0]
        T = ph["Transfer"][0]
        sL = cell_stats(L["path"])
        sT = cell_stats(T["path"])

        # 按 CellUID 对齐（顺序可能不同，必须用 UID 建索引）
        iL = {int(u): i for i, u in enumerate(sL["uid"])}
        iT = {int(u): i for i, u in enumerate(sT["uid"])}
        common = sorted(set(iL) & set(iT))
        cL = np.array([iL[u] for u in common])
        cT = np.array([iT[u] for u in common])

        okL = sL["ok"][cL]
        okT = sT["ok"][cT]
        both = okL & okT

        hL = sL["datetime"][:16]
        hT = sT["datetime"][:16]
        dt_h = (datetime.strptime(hT, "%Y-%m-%dT%H:%M")
                - datetime.strptime(hL, "%Y-%m-%dT%H:%M")).total_seconds() / 3600.0

        rows.append(dict(
            mouse=mouse,
            n_uid_learned=int(sL["n"]), n_uid_transfer=int(sT["n"]),
            n_uid_common=len(common),
            learned_ok=int(okL.sum()), transfer_ok=int(okT.sum()), both_ok=int(both.sum()),
            both_ok_frac=float(both.sum() / len(common)),
            # 只在一边可用的细胞数（若很大，100% 交集就是假象）
            only_one_side=int((okL ^ okT).sum()),
            learned_fin_median=float(np.median(sL["fin"][cL])),
            transfer_fin_median=float(np.median(sT["fin"][cT])),
            learned_std0=int((sL["sd"][cL] <= 0).sum()),
            transfer_std0=int((sT["sd"][cT] <= 0).sum()),
            learned_dur_min=round(sL["dur_min"], 1), transfer_dur_min=round(sT["dur_min"], 1),
            learned_at=hL, transfer_at=hT, gap_hours=round(dt_h, 2),
        ))

    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(rows, indent=2, ensure_ascii=False))

    hdr = (f"{'mouse':<9s}{'nUID':>6s}{'L_ok':>6s}{'T_ok':>6s}{'both':>6s}"
           f"{'both%':>7s}{'LxorT':>7s}{'fin_L':>7s}{'fin_T':>7s}"
           f"{'sd0_L':>6s}{'sd0_T':>6s}{'Lmin':>6s}{'Tmin':>6s}{'gap_h':>7s}")
    print(hdr)
    print("-" * len(hdr))
    for r in rows:
        print(f"{r['mouse']:<9s}{r['n_uid_common']:6d}{r['learned_ok']:6d}"
              f"{r['transfer_ok']:6d}{r['both_ok']:6d}{r['both_ok_frac']*100:6.1f}%"
              f"{r['only_one_side']:7d}{r['learned_fin_median']:7.3f}"
              f"{r['transfer_fin_median']:7.3f}{r['learned_std0']:6d}{r['transfer_std0']:6d}"
              f"{r['learned_dur_min']:6.1f}{r['transfer_dur_min']:6.1f}{r['gap_hours']:7.2f}")
    print(f"\n写出：{OUT}")


if __name__ == "__main__":
    main()

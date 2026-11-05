"""Step0_DataFeasibility.py —— 第 0 步：数据可行性检查（只读，不改任何数据）

回答三个问题：
  P0-1 跨阶段细胞匹配率：同一只鼠在「学习阶段」与「迁移阶段」的会话里，
       有多少 CellUID 是同一个细胞？（C3「两个吸引子是否相同」的全部前提）
  P0-2 每个会话的 trial 数 / 时长 / 采样率
  P0-4 细胞 QC：细胞数、有限值比例

输出：
  results/_step0_feasibility.json   机器可读
  results/_step0_feasibility.txt    人可读表格
"""
from __future__ import annotations

import collections
import itertools
import json
import os

import numpy as np

from rslds_data import scan_cohort

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_JSON = os.path.join(HERE, "results", "_step0_feasibility.json")
OUT_TXT = os.path.join(HERE, "results", "_step0_feasibility.txt")
os.makedirs(os.path.dirname(OUT_JSON), exist_ok=True)


def n_events(m, key):
    v = m.get("idx_" + key)
    return int(len(v)) if v is not None else -1


def main():
    lines = []
    blob = {}

    for cohort in ["ALB", "LightAudioBaseline"]:
        ms = scan_cohort(cohort)
        lines.append(f"\n{'='*100}\n队列 {cohort}：{len(ms)} 个会话\n{'='*100}")

        # ---- 阶段 / 设计 的取值清单 ----
        ph = collections.Counter((m["phase"], m["design"]) for m in ms)
        lines.append("\n[阶段 × 设计] 会话数：")
        for (p, d), c in sorted(ph.items()):
            lines.append(f"  Phase={p:<12s} Design={d:<14s} n={c}")

        by_mouse = collections.defaultdict(list)
        for m in ms:
            by_mouse[m["mouse"]].append(m)
        for k in by_mouse:
            by_mouse[k].sort(key=lambda x: x["datetime"])

        blob[cohort] = {"phase_design_counts": {f"{p}|{d}": c for (p, d), c in ph.items()},
                        "mice": {}}

        for mouse in sorted(by_mouse):
            sess = by_mouse[mouse]
            lines.append(f"\n--- {mouse}（{len(sess)} 个会话）---")
            lines.append(f"  {'datetime':<17s} {'phase':<12s} {'design':<14s} "
                         f"{'nCell':>6s} {'durMin':>7s} {'fs':>7s} "
                         f"{'nCue':>5s} {'nSound':>7s} {'nLight':>7s} {'nWater':>7s} {'nHit':>5s}")
            for m in sess:
                lines.append(
                    f"  {m['datetime']:<17s} {m['phase']:<12s} {m['design']:<14s} "
                    f"{m['n_cell']:6d} {m['dur_sec']/60:7.1f} {m['fs']:7.3f} "
                    f"{n_events(m,'TrialStart'):5d} {n_events(m,'SoundOn'):7d} "
                    f"{n_events(m,'LightOn'):7d} {n_events(m,'GiveWater'):7d} "
                    f"{n_events(m,'Hit'):5d}")

            # ---- 所有会话两两的 CellUID 交集 ----
            sets = {m["datetime"]: set(int(u) for u in m["cell_uid"]) for m in sess}
            pairs = []
            for a, b in itertools.combinations(sess, 2):
                sa, sb = sets[a["datetime"]], sets[b["datetime"]]
                inter = len(sa & sb)
                small = min(len(sa), len(sb))
                pairs.append(dict(
                    a=f"{a['phase']}/{a['design']}@{a['datetime']}",
                    b=f"{b['phase']}/{b['design']}@{b['datetime']}",
                    n_a=len(sa), n_b=len(sb), n_common=inter,
                    frac_of_smaller=(inter / small) if small else 0.0,
                    jaccard=(inter / len(sa | sb)) if (sa | sb) else 0.0,
                ))
            blob[cohort]["mice"][mouse] = dict(
                n_sessions=len(sess),
                sessions=[dict(datetime=m["datetime"], phase=m["phase"], design=m["design"],
                               n_cell=m["n_cell"], dur_min=round(m["dur_sec"] / 60, 2),
                               fs=m["fs"], decim_k=m["decim_k"],
                               n_trial=int(len(m.get("idx_TrialStart", []))),
                               n_sound=int(len(m.get("idx_SoundOn", []))),
                               n_light=int(len(m.get("idx_LightOn", []))),
                               n_water=int(len(m.get("idx_GiveWater", []))),
                               n_hit=int(len(m.get("idx_Hit", []))))
                          for m in sess],
                pairs=pairs,
            )

            # 打印：按交集比例排序的前 6 对 + 各类阶段组合的最大值
            pairs_sorted = sorted(pairs, key=lambda r: -r["frac_of_smaller"])
            lines.append("  细胞交集（前 6 对，按占较小集合比例）：")
            for r in pairs_sorted[:6]:
                lines.append(f"    {r['frac_of_smaller']*100:5.1f}%  "
                             f"({r['n_common']:4d}/{r['n_a']:d}~{r['n_b']:d})  "
                             f"{r['a']}  ×  {r['b']}")

    with open(OUT_JSON, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(blob, indent=2, ensure_ascii=False))
    with open(OUT_TXT, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))
    print("\n".join(lines))
    print(f"\n写出：{OUT_JSON}\n写出：{OUT_TXT}")


if __name__ == "__main__":
    main()

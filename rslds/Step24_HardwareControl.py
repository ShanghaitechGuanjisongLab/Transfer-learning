"""Step24_HardwareControl.py —— C3 的"共享硬件"对照：四重比较

问题
  C3-b 发现两阶段的吸引子核心群体构型相似（ρ=0.47）。但同一只鼠、同一批细胞、
  同一指示剂，跨阶段必然相似 —— 这个相似性可能来自**细胞固有属性（硬件）**，
  与"是否共享同一个状态"无关。细胞标签置换零模型排除不了它，因为硬件与状态都以细胞为索引。

需要一个"同硬件、不同状态"的对照
  主对照 A：LAu / LAuW —— AudioOnly / LightOnly，**完全不给水、无配对、无学习**
            （ALB 实测命中率 0.00–0.08），是这批数据里最彻底的"未学"状态。
  主对照 B：Naive AudioWater —— 同一线索、学习曲线之前（但行为上多数已学会，中位 0.83）
  外部对照 C：LAB 的 Naive LightWater vs Learned LightWater —— 镜像队列，
            naive 行为学未学（2/4 命中率 0.00）且无光响应，但 n 只有 3（yqn1013 的
            Learned 因"2 次中断拍摄"已排除）。

判据
  主 ρ(L, T1) 必须**显著高于对照 A 与 B**（同鼠、同层、同零模型）；
  若 ρ(LAu, Learned) ≈ ρ(L, T1)，则所谓相似性就是硬件，C3-b 的主张撤回。

统计量（与 Step20/22 完全一致）
  a_i = E[z_i | 吸引子核心（最低 30% 距离）] − E[z_i | 全帧]，N1 逐场 z-score
  零模型 = 同鼠内细胞标签置换（N=500）
  每个配对各用自己的细胞交集，因此每个配对的 nCell 可能不同
"""
from __future__ import annotations

import json
import os
import time

import numpy as np

import attractor_core as AC
import Step10_TICA as T
from rslds_data import load_block, scan_cohort

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "results", "_step24_hardware.json")

KPC = 10
CORE_FRAC = 0.3
MIN_CELL = 40
N_PERM = 500
GROUPS = [("MOp2/3", 1), ("MOp5", 2)]


def core_vec(Z):
    X, _, _, _ = T.pcs(Z, KPC)
    r = np.linalg.norm(X - np.median(X, axis=0), axis=1)
    core = r <= np.percentile(r, 100 * CORE_FRAC)
    return Z[core].mean(0) - Z.mean(0)


def load_session(b):
    d = load_block(b["path"])
    fs = d["fs"]
    Y = np.nan_to_num(AC.dff(d["X"], fs), nan=0.0, posinf=0.0, neginf=0.0)
    return dict(Z=AC.zscore_robust(AC.VARIANTS["P1"](Y, fs)),
                ok=np.std(Y, axis=0) > 1e-9,
                zl=np.asarray(d["z_layer"]), uid=d["cell_uid"],
                cue=len(d.get("idx_cue", [])), perf=d.get("performance", np.nan))


def build_index(cohort, labeler):
    """labeler(mouse, phase, design) -> 标签 或 None"""
    idx = {}
    for b in scan_cohort(cohort):
        lab = labeler(b["mouse"], b["phase"], b["design"])
        if lab is None:
            continue
        idx.setdefault(b["mouse"], {})[lab] = b
    return idx


def alb_label(mouse, phase, design):
    if phase == "Learned":
        return "L"
    if phase == "Transfer":
        return "T"
    if phase == "Final":
        return "F"
    if phase == "Naive":
        if design in ("LAu", "LAuW"):
            return "LA"
        if design == "AudioWater":
            return "N_AW"
    return None


def lab_label(mouse, phase, design):
    """LAB 有两种设计序列，语义等价，统一成一套标签：
         plain 序列  : LightWater → AudioWater
         LLw 序列    : LLw（=LightWater+LightOnly） → AuAuw（=AudioWater+AudioOnly）
       两者都是"光水学会 → 迁移到声水"，故合并。
    """
    light_pair = design in ("LightWater", "LLw")
    audio_pair = design in ("AudioWater", "AuAuw")
    if phase == "Naive":
        if design == "LAuW":
            return "LA"
        if light_pair:
            return "N_LW"
    if phase == "Learned" and light_pair:
        return "L_LW"
    if phase == "Transfer" and audio_pair:
        return "T_AW"
    if phase == "Final" and audio_pair:
        return "F_AW"
    return None


PAIRS = [
    ("main",     "ALB", "L",    "T"),      # 主：学成 vs 迁移
    ("ctl_LA",   "ALB", "LA",   "L"),      # 对照 A：未配对未给水 vs 学成
    ("ctl_NAW",  "ALB", "N_AW", "L"),      # 对照 B：第一次声水 vs 学成
    ("lab_main", "LAB", "L_LW", "T_AW"),   # LAB 主：学成光 → 迁移声
    ("lab_NL",   "LAB", "N_LW", "L_LW"),   # 对照 C：镜像队列 naive vs learned（同线索）
    ("lab_NAW",  "LAB", "N_LW", "F_AW"),   # 对照 C'：未学光 vs 学成声
    ("alb_LF",   "ALB", "L",    "F"),      # 参考：学成 vs 学成（不同线索）
]


def main():
    t0 = time.time()
    idx = {"ALB": build_index("ALB", alb_label),
           "LAB": build_index("LightAudioBaseline", lab_label)}
    cache = {}
    rng = np.random.default_rng(0)
    rows = []
    print(f"{'配对':<10s}{'队列':<5s}{'鼠':<9s}{'组':<8s}{'nCell':>6s}"
          f"{'ρ':>8s}{'零95%':>8s}{'超零':>5s}")
    for name, coh, la, lb in PAIRS:
        for m, sess in sorted(idx[coh].items()):
            if la not in sess or lb not in sess:
                continue
            key = []
            for lab in (la, lb):
                k = (coh, m, lab)
                if k not in cache:
                    cache[k] = load_session(sess[lab])
                key.append(cache[k])
            A, B = key
            if A["cue"] < 8 or B["cue"] < 8:
                continue
            for gname, code in GROUPS:
                com = None
                for s in (A, B):
                    io = {int(v): i for i, v in enumerate(s["uid"])}
                    common_uid = np.array(sorted(set(A["uid"].tolist()) & set(B["uid"].tolist())))
                    ia = np.array([{int(v): i for i, v in enumerate(A["uid"])}[u] for u in common_uid])
                    ib = np.array([{int(v): i for i, v in enumerate(B["uid"])}[u] for u in common_uid])
                    break
                keep = (A["ok"][ia] & B["ok"][ib]
                        & (A["zl"][ia] == code) & (B["zl"][ib] == code))
                n = int(keep.sum())
                if n < MIN_CELL:
                    continue
                aA = core_vec(A["Z"][:, ia[keep]])
                aB = core_vec(B["Z"][:, ib[keep]])
                r = float(np.corrcoef(aA, aB)[0, 1])
                null = np.array([float(np.corrcoef(aA, aB[rng.permutation(n)])[0, 1])
                                 for _ in range(N_PERM)])
                p95 = float(np.percentile(null, 95))
                rows.append(dict(pair=name, cohort=coh, mouse=m, group=gname,
                                 n_cell=n, rho=r, null95=p95, over=bool(r > p95)))
                print(f"{name:<10s}{coh:<5s}{m:<9s}{gname:<8s}{n:6d}"
                      f"{r:8.3f}{p95:8.3f}{'  ✓' if r > p95 else '   '}")

    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(rows, indent=2, ensure_ascii=False))

    print(f"\n=== 汇总 ===")
    print(f"{'配对':<10s}{'队列':<5s}{'组':<8s}{'n':>4s}{'ρ中位':>9s}{'超零':>9s}")
    for name, coh, _, _ in PAIRS:
        for gname, _ in GROUPS:
            g = [x for x in rows if x["pair"] == name and x["group"] == gname]
            if not g:
                continue
            print(f"{name:<10s}{coh:<5s}{gname:<8s}{len(g):4d}"
                  f"{np.median([x['rho'] for x in g]):9.3f}"
                  f"{sum(1 for x in g if x['over']):6d}/{len(g)}")
    print(f"\n用时 {(time.time()-t0)/60:.1f} min；写出 {OUT}")


if __name__ == "__main__":
    main()

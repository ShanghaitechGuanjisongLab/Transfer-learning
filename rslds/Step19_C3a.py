"""Step19_C3a.py —— C3-a 不变式比较：两个阶段的吸引子是否"同一类、同时标度"

C3-a 与 C3-b 的分工
  C3-a **不需要细胞身份**，只比会话级描述子 ⇒ 只能主张"同一类型/同时标度"，
        不能主张"同一状态"。这也是文献（Nair 2023 / Mountoufaris 2024）唯一能做的口径。
  C3-b 需要细胞身份（同鼠同细胞），才可能主张"同一个吸引子"。

三个描述子（预注册 §6.1）
  S0 类型      —— 只作**描述**，不计入判据。原因：本项目已确定所有 session 都是
                  过阻尼稳定不动点（Q 0.18–0.29、0/33 螺旋）、无慢流形、无极限环，
                  类型一致率**必然 100%**，若计入就是又一个"恒真判据"（basin=1.00 同类陷阱）。
  S1 τ 谱      —— lag=16 广义特征分解取前 K 个 τ，排序后比 log τ 向量
                  相似度 = 1 − ‖Δlogτ‖/‖logτ‖
  S2 占据几何  —— r = ‖x − median(x)‖（**不用 (I−A)⁻¹c，见 A.12.1 的数值爆炸教训**），
                  以中位数归一后取分位数向量，相似度 = 1 − KS 距离

零模型
  不同鼠的 (L, T1) 随机配对。因为两个描述子都是**会话级**的，跨鼠配对是合法的
  （这与 C3-b 不同：C3-b 的参数是逐细胞的向量，跨鼠无法配对，必须用细胞标签置换）。

配对
  (L, T1) 迁移是否**即刻**复用
  (L, T2) 两条学习路径是否**殊途同归**
  (T1, T2) 新线索自身的学习方向

判据
  每对比较中，S1 与 S2 **至少一个**达到"同鼠相似度 > 跨鼠零分布 95 分位"，
  且以鼠为单位 ≥ 2/3 达到。
"""
from __future__ import annotations

import json
import os
import time

import numpy as np
from scipy.stats import ks_2samp

import attractor_core as AC
import Step10_TICA as T
import Step12_TICA_NonReversible as S12
from rslds_data import load_block, scan_cohort

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "results", "_step19_c3a.json")

PHASES = ["Learned", "Transfer", "Final"]
PAIR_NAMES = [("Learned", "Transfer"), ("Learned", "Final"), ("Transfer", "Final")]
LAG = 16
KPC = 10
NTAU = 5
MIN_CELL = 40
GROUPS = [("pooled", None), ("MOp2/3", 1), ("MOp5", 2)]
QN = np.linspace(5, 95, 19)


def descriptors(Y, fs):
    """返回 (log τ 向量, r 分位数向量, 描述性类型标签)。"""
    Z = AC.zscore_robust(AC.VARIANTS["P1"](Y, fs))
    X, _, _, _ = T.pcs(Z, KPC)
    cue_ok = None  # 不依赖 cue；描述子只用整段轨迹
    w, mag, tau = S12.spec(*S12.cov_pair(X, [(0, len(Z))], LAG), LAG, fs)
    logt = np.log(np.sort(tau)[::-1][:NTAU])

    r = np.linalg.norm(X - np.median(X, axis=0), axis=1)
    r = r / max(np.median(r), 1e-12)
    q = np.percentile(r, QN)

    # 描述性类型：Q>1 且 |Im| 显著 ⇒ 焦点；tau_ratio>5 ⇒ 慢流形；否则过阻尼不动点
    Q = 0.0
    for k in range(min(5, len(w))):
        if abs(w[k]) < 0.3 or abs(w[k]) >= 1:
            continue
        Q = max(Q, float(abs(np.imag(w[k])) / max(abs(np.log(abs(w[k]))), 1e-12)))
    tr = float(tau[0] / tau[1]) if len(tau) > 1 else np.nan
    kind = "spiral" if Q > 1 else ("slow-manifold" if tr > 5 else "over-damped-fp")
    return logt, q, kind


def sim_tau(a, b):
    n = min(len(a), len(b))
    return float(1.0 - np.linalg.norm(a[:n] - b[:n]) / max(np.linalg.norm(a[:n]), 1e-12))


def main():
    t0 = time.time()
    bs = scan_cohort("ALB", phases=PHASES)
    byMouse = {}
    for b in bs:
        byMouse.setdefault(b["mouse"], {})[b["phase"]] = b

    feats = {}   # (mouse, phase, group) -> (logt, q, kind)
    for m, ph_map in sorted(byMouse.items()):
        for ph in PHASES:
            if ph not in ph_map:
                continue
            d = load_block(ph_map[ph]["path"])
            fs = d["fs"]
            Y0 = np.nan_to_num(AC.dff(d["X"], fs), nan=0.0, posinf=0.0, neginf=0.0)
            ok = np.std(Y0, axis=0) > 1e-9
            zl = np.asarray(d.get("z_layer", np.zeros(Y0.shape[1], dtype=np.int64)))
            if zl.size != Y0.shape[1]:
                zl = np.zeros(Y0.shape[1], dtype=np.int64)
            for gname, code in GROUPS:
                sel = ok if code is None else (ok & (zl == code))
                if int(sel.sum()) < MIN_CELL:
                    continue
                logt, q, kind = descriptors(Y0[:, sel], fs)
                feats[(m, ph, gname)] = (logt, q, kind)

    rows = []
    for gname, _ in GROUPS:
        mice = sorted({m for (m, ph, g) in feats if g == gname})
        have3 = [m for m in mice if all((m, ph, gname) in feats for ph in PHASES)]
        if len(have3) < 4:
            continue
        print(f"\n===== 组 {gname}（三层齐全的鼠：{len(have3)}）=====")
        kinds = [feats[(m, ph, gname)][2] for m in have3 for ph in PHASES]
        print(f"  类型分布（描述性，不计入判据）: " +
              ", ".join(f"{k}={kinds.count(k)}" for k in sorted(set(kinds))))
        for pa, pb in PAIR_NAMES:
            for metric in ("tau", "geom"):
                within, null = [], []
                for m in have3:
                    fa = feats[(m, pa, gname)]
                    fb = feats[(m, pb, gname)]
                    f = sim_tau if metric == "tau" else (
                        lambda x, y: float(1.0 - ks_2samp(x, y).statistic))
                    within.append(f(fa[0] if metric == "tau" else fa[1],
                                    fb[0] if metric == "tau" else fb[1]))
                    for m2 in have3:
                        if m2 == m:
                            continue
                        fb2 = feats[(m2, pb, gname)]
                        null.append(f(fa[0] if metric == "tau" else fa[1],
                                      fb2[0] if metric == "tau" else fb2[1]))
                within = np.array(within)
                null = np.array(null)
                p95 = float(np.percentile(null, 95))
                p = float((1 + np.sum(null >= np.median(within))) / (len(null) + 1))
                n_over = int(np.sum(within > p95))
                rows.append(dict(group=gname, pair=f"{pa}-{pb}", metric=metric,
                                 n_mouse=len(have3),
                                 within_med=float(np.median(within)),
                                 null_med=float(np.median(null)), null_p95=p95,
                                 p=p, n_over=n_over))
                print(f"  {pa[:4]}-{pb[:4]:<5s}{metric:<5s} 同鼠中位 {np.median(within):.3f}"
                      f"  跨鼠中位 {np.median(null):.3f}  95% {p95:.3f}"
                      f"  超 95% 的鼠 {n_over}/{len(have3)}  p={p:.4f}")

    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(rows, indent=2, ensure_ascii=False))
    print(f"\n用时 {(time.time()-t0)/60:.1f} min；写出 {OUT}")


if __name__ == "__main__":
    main()

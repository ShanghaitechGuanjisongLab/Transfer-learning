"""Step19b_C3a_perm.py —— C3-a 的组水平置换检验（τ 谱）

为什么需要
  `Step19_C3a.py` 按预注册的"每只鼠 > 跨鼠零分布 95 分位"判据，所有比较都 p>0.05。
  但该判据有两个结构性问题：
    1. 跨鼠零分布很宽（不同鼠的 τ 谱偶然相近），95 分位高达 0.84–0.93，
       而观测的同鼠相似度中位就有 0.80–0.90 —— 判据几乎没有余量。
    2. "每只鼠单独达标"要求 11 次独立成功，对 n=11 极其严格。
  真正该问的是：**"同鼠配对"这件事是否携带信息**，即
      median_i sim(mouse i 的阶段A, mouse i 的阶段B)
   是否显著高于
      median_i sim(mouse i 的阶段A, mouse π(i) 的阶段B),  π 为随机置换
  这是配对设计的标准置换检验，也是功效最高的形式。

另修一处
  `Step19_C3a.py` 的 S2（占据几何）在三种配对下相似度只取 0.895/0.921/0.947 三个值，
  完全退化（KS 距离对 19 个分位点不敏感）⇒ **宣告为不可用作判据**，同 S0 类型。

两个 τ 描述子
  abs   : log τ_i              —— 含整体快慢
  shape : log(τ_i / τ_1)       —— 只留谱形状，去掉整体速度

输出 results/_step19b_c3a_perm.json
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
OUT = os.path.join(HERE, "results", "_step19b_c3a_perm.json")

PHASES = ["Learned", "Transfer", "Final"]
PAIRS = [("Learned", "Transfer"), ("Learned", "Final"), ("Transfer", "Final")]
LAG = 16
KPC = 10
NTAU = 5
MIN_CELL = 40
N_PERM = 5000
GROUPS = [("pooled", None), ("MOp2/3", 1), ("MOp5", 2)]


def tau_feats(Y, fs):
    Z = AC.zscore_robust(AC.VARIANTS["P1"](Y, fs))
    X, _, _, _ = T.pcs(Z, KPC)
    C0, Ct = S12.cov_pair(X, [(0, len(Z))], LAG)
    if C0 is None:
        return None
    _, _, tau = S12.spec(C0, Ct, LAG, fs)
    t = np.sort(tau)[::-1][:NTAU]
    return np.log(t), np.log(t / t[0])


def sim(a, b):
    n = min(len(a), len(b))
    return float(1.0 - np.linalg.norm(a[:n] - b[:n]) / max(np.linalg.norm(a[:n]), 1e-12))


def main():
    t0 = time.time()
    bs = scan_cohort("ALB", phases=PHASES)
    byMouse = {}
    for b in bs:
        byMouse.setdefault(b["mouse"], {})[b["phase"]] = b

    feats = {}
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
                r = tau_feats(Y0[:, sel], fs)
                if r is not None:
                    feats[(m, ph, gname)] = r

    rng = np.random.default_rng(0)
    rows = []
    for gname, _ in GROUPS:
        mice = sorted({m for (m, ph, g) in feats if g == gname})
        have3 = [m for m in mice if all((m, ph, gname) in feats for ph in PHASES)]
        if len(have3) < 5:
            continue
        print(f"\n===== 组 {gname}（三层齐全 {len(have3)} 只鼠）=====")
        for pa, pb in PAIRS:
            for which, k in (("abs", 0), ("shape", 1)):
                A = np.array([feats[(m, pa, gname)][k] for m in have3])
                B = np.array([feats[(m, pb, gname)][k] for m in have3])
                n = len(have3)
                obs = np.median([sim(A[i], B[i]) for i in range(n)])
                null = np.empty(N_PERM)
                for t in range(N_PERM):
                    pi = rng.permutation(n)
                    null[t] = np.median([sim(A[i], B[pi[i]]) for i in range(n)])
                p = float((1 + np.sum(null >= obs)) / (N_PERM + 1))
                z = (obs - null.mean()) / max(null.std(), 1e-12)
                rows.append(dict(group=gname, pair=f"{pa}-{pb}", feature=which,
                                 n_mouse=n, obs_med=float(obs),
                                 null_med=float(np.median(null)),
                                 null_p95=float(np.percentile(null, 95)),
                                 p=p, z=float(z)))
                print(f"  {pa[:4]}-{pb[:4]:<5s} {which:<6s} 观测中位 {obs:.3f}"
                      f"  置换中位 {np.median(null):.3f}  95% {np.percentile(null,95):.3f}"
                      f"  p={p:.4f}  z={z:+.2f}")

    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(rows, indent=2, ensure_ascii=False))
    print(f"\n用时 {(time.time()-t0)/60:.1f} min；写出 {OUT}")


if __name__ == "__main__":
    main()

"""CheckSplitHalfDim.py —— 高维是真的，还是噪声把本征值抬平的？（**流形叙事的门禁**）

问题：7/11 只鼠 PR/细胞 = 38–59 %，看起来"不低维"。但有两种解释
  (a) 活动真高维  ⇒ 这些鼠里流形叙事不成立
  (b) 独立噪声把本征值抬平 ⇒ 流形还在，只是被盖住

判别：**split-half**。按试次奇偶把 session 切成两半 A/B
（按试次而不是按时间，避免慢漂移造成虚假的结构差异），然后：

  ① **信号协方差** $C_{\\rm sig}=\\tfrac12(C_{AB}+C_{AB}^{\\top})$，其中 $C_{AB}=Z_A^{\\top}Z_B/T$
     （独立噪声在跨半乘积里期望为 0，所以 $C_{\\rm sig}$ 是噪声无关的估计）
     → 比 ${\\rm PR}(C_{\\rm sig})$ 与 ${\\rm PR}(C_{\\rm raw})$
  ② **信号占比** ${\\rm tr}C_{\\rm sig}/{\\rm tr}C_{\\rm raw}$
  ③ **子空间重叠** ${\\rm overlap}(k)=\\|V_A^{\\top}V_B\\|_F^2/k$（$V$ = 前 k 个载荷）
     机会水平 = $k/N$；接近 1 = 两半给出同一个 k 维子空间

判据（事先声明）
  · ${\\rm PR}(C_{\\rm sig})\\ll{\\rm PR}(C_{\\rm raw})$ 且 overlap 远高于机会 ⇒ **噪声抬平的，流形有数**
  · ${\\rm PR}(C_{\\rm sig})\\approx{\\rm PR}(C_{\\rm raw})$ 且 overlap≈机会 ⇒ **真的高维**

用法：  .venv\\Scripts\\python rslds\\CheckSplitHalfDim.py [--only 2]
"""

from __future__ import annotations

import argparse
import json
import os
import sys

import numpy as np

import rslds_data as rd

HERE = os.path.dirname(os.path.abspath(__file__))
FIGDIR = os.path.join(HERE, "results", "fig1")
KS = (5, 15, 30, 50)


def pr(lam):
    lam = np.clip(np.asarray(lam, float), 0, None)
    s = lam.sum()
    return float(s ** 2 / ((lam ** 2).sum() + 1e-30)) if s > 0 else np.nan


def trials_of(d, T):
    """用**权威 cue 下标**（idx_cue / SampleRange.Tag）切 trial。

    ⚠ 不要用 idx_TrialStart（EventLog 派生，与钙数据不同步，
      见 /memories/repo/data-alignment.md）。
    """
    st = np.unique(d.get("idx_cue", []))
    if len(st) < 8:
        st = np.unique(d["idx_TrialStart"])
    st = st[(st >= 0) & (st < T)]
    en = np.append(st[1:], T)
    return [(int(a), int(b)) for a, b in zip(st, en) if b - a > 1]


def topk_basis(X, k):
    Xc = X - X.mean(axis=0)
    _, _, Vt = np.linalg.svd(Xc, full_matrices=False)
    return Vt[:k].T          # N×k


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", type=int, default=None)
    a = ap.parse_args()

    # 2026-10-23 更正：原版只跑了 Transfer。现改为三个阶段全跑，
    # 因为「信号占比 19%」是否适用于 Learned/Final 从未测过。
    blocks = rd.scan_cohort("ALB", phases=["Learned", "Transfer", "Final"])
    order_p = {"Learned": 0, "Transfer": 1, "Final": 2}
    blocks.sort(key=lambda b: (b["mouse"], order_p.get(b["phase"], 9)))
    if a.only:
        blocks = blocks[:a.only]

    print("=== split-half 维度检验 ===", flush=True)
    hdr = "%-9s %-8s %5s %8s %9s %8s" % ("鼠", "阶段", "细胞", "PR_raw", "PR_signal", "信号占比")
    for k in KS:
        hdr += " %12s" % ("ovl@%d(chance)" % k)
    print(hdr, flush=True)

    rows = []
    for b in blocks:
        d = rd.load_block(b["path"])
        assert rd.check_orientation(d)
        X = d["X"][:, d["cell_ok"] >= 1.0]
        Z = rd.zscore_cols(rd.detrend_bleach(X, d["fs"]))
        T, N = Z.shape
        tr = trials_of(d, T)
        if len(tr) < 10:
            print("%-9s 试次太少（%d）" % (b["mouse"], len(tr)), flush=True)
            continue
        # 按长度排序后两两配对，每对随机分给 A/B，并截到两者较短的长度
        # ⇒ A、B 的试次长度构成完全匹配，样本数完全相等
        order = np.argsort([e - s for s, e in tr])
        rng = np.random.default_rng(0)
        segA, segB = [], []
        for p in range(0, len(order) - 1, 2):
            i, j = order[p], order[p + 1]
            L = min(tr[i][1] - tr[i][0], tr[j][1] - tr[j][0])
            if rng.random() < 0.5:
                i, j = j, i
            segA.append(Z[tr[i][0]:tr[i][0] + L])
            segB.append(Z[tr[j][0]:tr[j][0] + L])
        if not segA:
            print("%-9s 配对失败" % b["mouse"], flush=True)
            continue
        ZA = np.concatenate(segA, axis=0)
        ZB = np.concatenate(segB, axis=0)
        assert ZA.shape == ZB.shape, (ZA.shape, ZB.shape)
        if ZA.shape[0] < 200:
            print("%-9s 半样本太少" % b["mouse"], flush=True)
            continue

        C_raw = (Z.T @ Z) / T
        C_ab = (ZA.T @ ZB) / ZA.shape[0]
        C_sig = 0.5 * (C_ab + C_ab.T)
        lam_raw = np.linalg.eigvalsh(C_raw)
        lam_sig = np.linalg.eigvalsh(C_sig)
        pr_raw, pr_sig = pr(lam_raw), pr(np.clip(lam_sig, 0, None))
        frac_sig = float(np.clip(lam_sig, 0, None).sum() / lam_raw.sum())

        line = "%-9s %-8s %5d %8.1f %9.1f %7.1f%%" % (
            b["mouse"], b["phase"], N, pr_raw, pr_sig, 100 * frac_sig)
        ovl = {}
        for k in KS:
            kk = min(k, N)
            VA = topk_basis(ZA, kk)
            VB = topk_basis(ZB, kk)
            o = float((np.linalg.norm(VA.T @ VB) ** 2) / kk)
            chance = kk / N
            ovl[k] = (o, chance)
            line += "  %5.2f(%4.2f)" % (o, chance)
        print(line, flush=True)
        rows.append(dict(mouse=b["mouse"], phase=b["phase"], n_cell=int(N),
                         pr_raw=pr_raw, pr_signal=pr_sig, signal_fraction=frac_sig,
                         overlap={str(k): dict(obs=v[0], chance=v[1]) for k, v in ovl.items()},
                         n_trial=len(tr)))

    sm = os.path.join(FIGDIR, "split_half_dim.json")
    blob = json.dumps(rows, ensure_ascii=False, indent=1)
    with open(sm, "w", encoding="utf-8") as fh:
        fh.write(blob)

    g = lambda k: np.array([r[k] for r in rows], float)
    print("\n=== 汇总（%d 只鼠）===" % len(rows), flush=True)
    print("PR_raw：中位 %.1f（%.1f–%.1f）" % (np.median(g("pr_raw")), g("pr_raw").min(), g("pr_raw").max()),
          flush=True)
    print("PR_signal：中位 %.1f（%.1f–%.1f）" % (np.median(g("pr_signal")),
                                                g("pr_signal").min(), g("pr_signal").max()), flush=True)
    print("PR_signal / PR_raw：中位 %.2f" % np.median(g("pr_signal") / g("pr_raw")), flush=True)
    print("信号占比：中位 %.0f%%（%.0f–%.0f%%）"
          % (100 * np.median(g("signal_fraction")), 100 * g("signal_fraction").min(),
             100 * g("signal_fraction").max()), flush=True)
    for k in KS:
        o = np.array([r["overlap"][str(k)]["obs"] for r in rows])
        c = np.array([r["overlap"][str(k)]["chance"] for r in rows])
        print("overlap@%2d：观测中位 %.2f vs 机会 %.2f；比值中位 %.1f×"
              % (k, np.median(o), np.median(c), np.median(o / c)), flush=True)
    print("\n判据：PR_signal ≪ PR_raw 且 overlap ≫ 机会 ⇒ 低维是真的；"
          "PR_signal ≈ PR_raw ⇒ 高维是真的", flush=True)
    print("DONE", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())

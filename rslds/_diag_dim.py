"""_diag_dim.py —— 数据在**线性**意义上有多低维？（协方差谱的有效维数）

participation ratio  PR = (Σλ)² / Σλ²      λ = 去趋势+z-score 后细胞协方差的特征值
  PR = 1   ⇒ 完全一维
  PR = N   ⇒ 完全各向同性（没有低维结构）

另报前 k 个主成分解释的方差比例。

注意：相位随机化保持协方差不变，所以这个指标**不能**用来区分非线性结构；
它只回答"协方差本身是不是接近低秩"。
"""

import os

import numpy as np

import rslds_data as rd

blocks = [b for b in rd.scan_cohort("ALB", phases=["Transfer"]) if b["design"] == "LightWater"]
print("%-9s %5s %6s %8s %8s %8s %8s %8s"
      % ("鼠", "细胞", "PR", "top5%", "top15%", "top30%", "top60%", "top100%"))
prs, ncs = [], []
for b in blocks:
    d = rd.load_block(b["path"])
    X = d["X"][:, d["cell_ok"] >= 1.0]
    Z = rd.zscore_cols(rd.detrend_bleach(X, d["fs"]))
    C = (Z.T @ Z) / Z.shape[0]
    lam = np.sort(np.linalg.eigvalsh(C))[::-1]
    lam = np.clip(lam, 0, None)
    tot = lam.sum()
    cum = np.cumsum(lam) / tot
    pr = float(tot ** 2 / (lam ** 2).sum())
    n = lam.size
    g = lambda k: 100 * cum[min(k, n) - 1]
    print("%-9s %5d %6.1f %7.1f%% %7.1f%% %7.1f%% %7.1f%% %7.1f%%"
          % (b["mouse"], n, pr, g(5), g(15), g(30), g(60), g(100)))
    prs.append(pr)
    ncs.append(n)

prs = np.array(prs)
ncs = np.array(ncs)
print()
print("PR：中位 %.1f（%.1f–%.1f）；细胞数中位 %d" % (np.median(prs), prs.min(), prs.max(), int(np.median(ncs))))
print("PR / 细胞数：中位 %.1f%%（%.1f–%.1f%%）"
      % (100 * np.median(prs / ncs), 100 * (prs / ncs).min(), 100 * (prs / ncs).max()))

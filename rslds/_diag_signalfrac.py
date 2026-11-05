"""_diag_signalfrac.py —— 自查「信号占比」这个数到底在量什么

对照四种口径：
  A. tr(C_sig+)/tr(C_raw)          ← CheckSplitHalfDim.py 用的
  B. tr(C_sig)/tr(C_raw)           ← 不截断负特征值（无偏但可能偏低）
  C. 逐细胞 split-half 相关的中位数  ← 最直观；z-score 后应 ≈ A
  D. 群体响应向量的 split-half 相关  ← 最接近"论文里说的可重复性"

另报负特征值总量，量化截断带来的高估。
"""
from __future__ import annotations

import numpy as np

import rslds_data as rd
from CheckSplitHalfDim import trials_of

PHASE = "Learned"
FSD = 0.0


def pr(lam):
    lam = np.clip(np.asarray(lam, float), 0, None)
    s = lam.sum()
    return float(s ** 2 / ((lam ** 2).sum() + 1e-30)) if s > 0 else np.nan


def main():
    blocks = [b for b in rd.scan_cohort("ALB", phases=[PHASE])]
    print(f"{'鼠':<9s}{'N':>5s}{'trRaw':>8s}{'A截断':>8s}{'B不截断':>9s}"
          f"{'C逐细胞r':>9s}{'D群体r':>8s}{'负特征值占比':>12s}")
    for b in sorted(blocks, key=lambda x: x["mouse"]):
        d = rd.load_block(b["path"])
        X = d["X"][:, d["cell_ok"] >= 1.0]
        Z = rd.zscore_cols(rd.detrend_bleach(X, d["fs"]))
        T, N = Z.shape
        tr_ = trials_of(d, T)
        if len(tr_) < 10:
            continue
        order = np.argsort([e - s for s, e in tr_])
        rng = np.random.default_rng(0)
        segA, segB = [], []
        for p in range(0, len(order) - 1, 2):
            i, j = order[p], order[p + 1]
            L = min(tr_[i][1] - tr_[i][0], tr_[j][1] - tr_[j][0])
            if rng.random() < 0.5:
                i, j = j, i
            segA.append(Z[tr_[i][0]:tr_[i][0] + L])
            segB.append(Z[tr_[j][0]:tr_[j][0] + L])
        ZA = np.concatenate(segA, axis=0)
        ZB = np.concatenate(segB, axis=0)

        C_raw = (Z.T @ Z) / T
        C_ab = (ZA.T @ ZB) / ZA.shape[0]
        C_sig = 0.5 * (C_ab + C_ab.T)
        lam_sig = np.linalg.eigvalsh(C_sig)
        tr_raw = float(np.trace(C_raw))
        A = float(np.clip(lam_sig, 0, None).sum() / tr_raw)
        Bv = float(lam_sig.sum() / tr_raw)
        neg = float(np.clip(-lam_sig, 0, None).sum() / max(np.clip(lam_sig, 0, None).sum(), 1e-12))

        # C. 逐细胞 split-half 相关（在 trial 对齐的时间段上）
        cc = []
        for i in range(N):
            a, bb = ZA[:, i], ZB[:, i]
            if a.std() > 1e-9 and bb.std() > 1e-9:
                cc.append(np.corrcoef(a, bb)[0, 1])
        Cv = float(np.median(cc))

        # D. 群体响应向量：奇/偶 trial 各自算「cue 后 0–1 s 相对基线」的跨细胞均值，再相关
        cue = np.sort(d.get("idx_cue", []))
        fs = d["fs"]

        def resp(idxs):
            R, B0 = [], []
            for c in idxs:
                i0, i1 = int(c), int(c + 1.0 * fs)
                j0, j1 = int(c - 1.0 * fs), int(c)
                if i0 >= 0 and i1 <= len(Z) and j0 >= 0:
                    R.append(Z[i0:i1].mean(0))
                    B0.append(Z[j0:j1].mean(0))
            if len(R) < 6:
                return None
            return np.mean(R, 0) - np.mean(B0, 0)

        r_odd, r_even = resp(cue[0::2]), resp(cue[1::2])
        Dv = (float(np.corrcoef(r_odd, r_even)[0, 1])
              if r_odd is not None and r_even is not None else np.nan)

        print(f"{b['mouse']:<9s}{N:5d}{tr_raw:8.1f}{A*100:7.1f}%{Bv*100:8.1f}%"
              f"{Cv:9.3f}{Dv:8.3f}{neg*100:11.0f}%")


if __name__ == "__main__":
    main()

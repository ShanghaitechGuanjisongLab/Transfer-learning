"""Step20_C3b_ceiling.py —— C3-b 的可靠性上限（先验功率评估，15 min 级）

为什么先做这个
  C3-b 主张"同一批细胞以相同相对权重表达同一状态"，核心统计量是跨细胞的
  Pearson ρ(a_L, a_T)。但跨细胞相关会被单细胞噪声严重衰减。若可靠性上限本身就低，
  ρ 再高也无法解释 ⇒ C3-b 直接判"不可判定"，不必投入 2 小时做完整分析。

状态向量的定义（避开 z-score 抹平陷阱）
  ⚠ 不能用"吸引子占据帧上逐细胞 z-score 的均值"：z-score 用该场自身 median/MAD，
    而主导吸引子上的帧**就是**该细胞的中位水平 ⇒ a ≈ 0，ρ 变成噪声之比。
  改用**调谐斜率**：
    1. 在该阶段的 10 维 PC 空间里，取 cue 锁时平均响应方向 u（单位向量）
    2. 标量状态坐标 s_t = x_t · u
    3. a_i = cov(z_i, s) / var(s)   —— 细胞 i 沿该状态的调谐强度
  a 是细胞空间向量，跨阶段可比；数值有界，不会被基线归一化抹掉。

可靠性上限（细胞半分法）
  把交集细胞随机分两半，用一半估 L 的 a、另一半估 T 的 a，算 ρ ⇒ 同一状态、
  但只剩一半细胞时的期望值。取两个方向（1→2, 2→1）均值后作 Spearman-Brown 校正：

      ρ_ceiling = 2ρ_split / (1 + ρ_split)

  报告 ρ_full / ρ_ceiling。

输出 results/_step20_c3b_ceiling.json
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
OUT = os.path.join(HERE, "results", "_step20_c3b_ceiling.json")

PHASES = ["Learned", "Transfer", "Final"]
PRE = (-2.5, -1.0)
RESP = (0.0, 1.5)
KPC = 10
MIN_CELL = 40
N_SPLIT = 200
GROUPS = [("MOp2/3", 1), ("MOp5", 2)]


def tuning_vector(Y, fs, cue, cells_keep=None):
    """返回 (a 全长细胞向量, 使用到的细胞掩码)。"""
    Z = AC.zscore_robust(AC.VARIANTS["P1"](Y, fs))
    X, _, _, _ = T.pcs(Z, KPC)
    cue = cue[(cue > int(3 * fs)) & (cue < len(X) - int(3 * fs))]
    if len(cue) < 10:
        return None, None
    R = []
    for c in cue:
        a, b = int(c + RESP[0] * fs), int(c + RESP[1] * fs)
        p, q = int(c + PRE[0] * fs), int(c + PRE[1] * fs)
        if a < 0 or b > len(X) or p < 0:
            continue
        R.append(X[a:b].mean(0) - X[p:q].mean(0))
    if len(R) < 8:
        return None, None
    u = np.mean(R, axis=0)
    nu = np.linalg.norm(u)
    if nu < 1e-12:
        return None, None
    u = u / nu
    s = X @ u                          # 标量状态坐标
    s = s - s.mean()
    vs = float(np.var(s))
    if vs < 1e-12:
        return None, None
    a = (Z * s[:, None]).mean(0) / vs   # cov(z_i, s)/var(s)
    return a, u


def main():
    t0 = time.time()
    bs = scan_cohort("ALB", phases=PHASES)
    byMouse = {}
    for b in bs:
        byMouse.setdefault(b["mouse"], {})[b["phase"]] = b

    rng = np.random.default_rng(0)
    rows = []
    print(f"{'鼠':<9s}{'组':<8s}{'nCell':>6s}{'ρ(L,T)':>8s}{'ρ(L,F)':>8s}"
          f"{'ρ_split':>9s}{'上限':>7s}{'full/ceiling(L,T)':>19s}")
    for m, ph_map in sorted(byMouse.items()):
        if not all(p in ph_map for p in PHASES):
            continue
        data = {}
        for ph in PHASES:
            d = load_block(ph_map[ph]["path"])
            fs = d["fs"]
            Y0 = np.nan_to_num(AC.dff(d["X"], fs), nan=0.0, posinf=0.0, neginf=0.0)
            ok = np.std(Y0, axis=0) > 1e-9
            zl = np.asarray(d.get("z_layer", np.zeros(Y0.shape[1], dtype=np.int64)))
            if zl.size != Y0.shape[1]:
                zl = np.zeros(Y0.shape[1], dtype=np.int64)
            cue = np.sort(np.asarray(d.get("idx_cue", []), dtype=np.int64))
            data[ph] = dict(Y0=Y0, fs=fs, ok=ok, zl=zl, cue=cue, uid=d["cell_uid"])

        # 三阶段 UID 交集
        uids = set(data[PHASES[0]]["uid"].tolist())
        for ph in PHASES[1:]:
            uids &= set(data[ph]["uid"].tolist())
        uids = np.array(sorted(uids))
        if len(uids) < MIN_CELL:
            continue

        for gname, code in GROUPS:
            # 先在**所有阶段**上取共同的细胞掩膜，否则各阶段的 a 长度不同、无法配对
            common = None
            sel_of = {}
            for ph in PHASES:
                dd = data[ph]
                idx_of = {int(v): i for i, v in enumerate(dd["uid"])}
                sel = np.array([idx_of[u] for u in uids], dtype=int)
                keep = dd["ok"][sel]
                if code is not None:
                    keep = keep & (dd["zl"][sel] == code)
                sel_of[ph] = sel
                common = keep if common is None else (common & keep)
            if common is None or int(common.sum()) < MIN_CELL:
                continue
            n = int(common.sum())

            vecs, okall = {}, True
            for ph in PHASES:
                dd = data[ph]
                a, _ = tuning_vector(dd["Y0"][:, sel_of[ph][common]], dd["fs"], dd["cue"])
                if a is None:
                    okall = False
                    break
                vecs[ph] = a
            if not okall:
                continue

            def rho(x, y):
                return float(np.corrcoef(x, y)[0, 1])

            r_LT = rho(vecs["Learned"], vecs["Transfer"])
            r_LF = rho(vecs["Learned"], vecs["Final"])

            # 细胞半分：随机分半（等长），跨阶段交叉配对
            sp = []
            m_even = (n // 2) * 2
            for _ in range(N_SPLIT):
                perm = rng.permutation(n)[:m_even]
                h1, h2 = perm[: m_even // 2], perm[m_even // 2:]
                sp.append(0.5 * (rho(vecs["Learned"][h1], vecs["Transfer"][h2])
                                 + rho(vecs["Learned"][h2], vecs["Transfer"][h1])))
            r_sp = float(np.median(sp))
            ceiling = 2 * r_sp / (1 + r_sp) if r_sp > -1 else np.nan

            rows.append(dict(mouse=m, group=gname, n_cell=int(n), rho_LT=r_LT,
                             rho_LF=r_LF, rho_split=r_sp, ceiling=float(ceiling),
                             frac_of_ceiling=float(r_LT / ceiling) if ceiling else np.nan))
            print(f"{m:<9s}{gname:<8s}{n:6d}{r_LT:8.3f}{r_LF:8.3f}{r_sp:9.3f}"
                  f"{ceiling:7.3f}{r_LT/max(ceiling,1e-12):19.2f}")

    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(rows, indent=2, ensure_ascii=False))

    if rows:
        print(f"\n=== 汇总（{len(rows)} 行）===")
        for gname, _ in GROUPS:
            g = [r for r in rows if r["group"] == gname]
            if not g:
                continue
            print(f"  {gname:<8s} n={len(g):2d}  ρ(L,T) 中位 {np.nanmedian([r['rho_LT'] for r in g]):+.3f}"
                  f"  ρ_split 中位 {np.nanmedian([r['rho_split'] for r in g]):.3f}"
                  f"  上限 中位 {np.nanmedian([r['ceiling'] for r in g]):.3f}")
    print(f"\n用时 {(time.time()-t0)/60:.1f} min；写出 {OUT}")


if __name__ == "__main__":
    main()

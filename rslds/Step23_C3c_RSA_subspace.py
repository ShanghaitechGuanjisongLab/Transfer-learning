"""Step23_C3c_RSA_subspace.py —— C3 的第三、第四条独立证据线

已有
  C3-a 不变量比较        ⛔ 不可判定（描述子退化 + 制备混淆）
  C3-b 群体状态向量      🟡 N1 下成立（ρ=0.47, 10/11），N2 下不成立（增益污染）

本脚本补两条与 C3-b **假设几乎不重叠**的检验，用来交叉验证：

① RSA（表征不相似矩阵）
   不需要定义"状态向量"，因而不受符号规范、也不受"核心如何定义"影响。
   条件 = cue 锁时的 12 个时间窗（−1 ~ +2 s，每 0.25 s 一窗）
   每阶段构 细胞 × 条件 矩阵 M，RDM = 1 − 条件间跨细胞相关
   相似度 = Spearman(RDM_L 上三角, RDM_T 上三角)        ↔ 零模型：细胞标签置换
   可靠性 = 试次奇偶分半各自算 RDM，两者的 Spearman

② 子空间主夹角
   每阶段的 PC 载荷矩阵 W（细胞 × d，列正交）
   M = W_Lᵀ W_T 的奇异值 = cos θ_i
   overlap = mean(cos²θ_i) ∈ [0,1]，= 1 表示两个子空间完全重合
   ↔ 零模型同上

判据
  两者都需：观测 > 自身零模型 95 分位，且以鼠为单位 ≥7/9。
  若 RSA / 主夹角 / C3-b 三者一致 ⇒ 相似性结论稳固。
"""
from __future__ import annotations

import json
import os
import time

import numpy as np
from scipy.stats import spearmanr

import attractor_core as AC
import Step10_TICA as T
from rslds_data import load_block, scan_cohort

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "results", "_step23_rsa_subspace.json")

PHASES = ["Learned", "Transfer", "Final"]
PAIRS = [("Learned", "Transfer"), ("Learned", "Final"), ("Transfer", "Final")]
KPC = 10
BIN_EDGES = np.arange(-1.0, 2.0 + 1e-9, 0.25)   # 12 个窗
MIN_CELL = 40
MIN_TRIAL = 8
N_PERM = 500
GROUPS = [("MOp2/3", 1), ("MOp5", 2)]


def cond_matrix(Z, fs, cue):
    """细胞 × 条件（时间窗）。条件 = cue 后固定时间窗内的跨试次平均。"""
    mats = []
    for lo, hi in zip(BIN_EDGES[:-1], BIN_EDGES[1:]):
        vecs = []
        for c in cue:
            a, b = int(c + lo * fs), int(c + hi * fs)
            if a >= 0 and b <= len(Z) and b > a:
                vecs.append(Z[a:b].mean(0))
        mats.append(np.mean(vecs, 0) if len(vecs) >= MIN_TRIAL else np.full(Z.shape[1], np.nan))
    return np.array(mats).T      # (nCell, nCond)


def rdm(M):
    """1 − 条件间跨细胞相关；返回上三角。"""
    k = M.shape[1]
    C = np.corrcoef(M.T)
    iu = np.triu_indices(k, 1)
    return 1.0 - C[iu]


def rsa(Ma, Mb):
    ra, rb = rdm(Ma), rdm(Mb)
    ok = np.isfinite(ra) & np.isfinite(rb)
    if ok.sum() < 10:
        return np.nan
    return float(spearmanr(ra[ok], rb[ok]).correlation)


def pcs_loadings(Z, d=KPC):
    Zc = Z - Z.mean(0)
    _, _, Vt = np.linalg.svd(Zc, full_matrices=False)
    return Vt[:d].T              # (nCell, d)，列正交


def subspace_overlap(Wa, Wb):
    M = Wa.T @ Wb
    s = np.linalg.svd(M, compute_uv=False)
    return float(np.mean(np.clip(s, 0, 1) ** 2))


def main():
    t0 = time.time()
    bs = scan_cohort("ALB", phases=PHASES)
    by = {}
    for b in bs:
        by.setdefault(b["mouse"], {})[b["phase"]] = b

    rng = np.random.default_rng(0)
    rows = []
    MATS = {}
    print(f"{'鼠':<9s}{'组':<8s}{'nCell':>6s}{'RSA(L,T1)':>10s}{'零95%':>8s}"
          f"{'overlap':>9s}{'零95%':>8s}{'RSA可靠':>9s}")
    for m, pm in sorted(by.items()):
        if not all(p in pm for p in PHASES):
            continue
        dat = {}
        for ph in PHASES:
            d = load_block(pm[ph]["path"])
            fs = d["fs"]
            Y = np.nan_to_num(AC.dff(d["X"], fs), nan=0.0, posinf=0.0, neginf=0.0)
            dat[ph] = dict(Z=AC.zscore_robust(AC.VARIANTS["P1"](Y, fs)), fs=fs,
                           ok=np.std(Y, axis=0) > 1e-9,
                           zl=np.asarray(d["z_layer"]), uid=d["cell_uid"],
                           cue=np.sort(np.asarray(d.get("idx_cue", []), dtype=np.int64)))

        uid = set(dat[PHASES[0]]["uid"].tolist())
        for ph in PHASES[1:]:
            uid &= set(dat[ph]["uid"].tolist())
        uid = np.array(sorted(uid))

        for gname, code in GROUPS:
            sel, common = {}, None
            for ph in PHASES:
                dd = dat[ph]
                io = {int(v): i for i, v in enumerate(dd["uid"])}
                s = np.array([io[u] for u in uid])
                k = dd["ok"][s] & (dd["zl"][s] == code)
                sel[ph] = s
                common = k if common is None else (common & k)
            n = int(common.sum())
            if n < MIN_CELL:
                continue

            M, W = {}, {}
            okall = True
            for ph in PHASES:
                dd = dat[ph]
                Zp = dd["Z"][:, sel[ph][common]]
                cue = dd["cue"][(dd["cue"] > int(2 * dd["fs"])) &
                                (dd["cue"] < len(Zp) - int(2.5 * dd["fs"]))]
                if len(cue) < MIN_TRIAL:
                    okall = False
                    break
                M[ph] = cond_matrix(Zp, dd["fs"], cue)
                W[ph] = pcs_loadings(Zp)
            if not okall:
                continue

            r_LT = rsa(M["Learned"], M["Transfer"])
            ov_LT = subspace_overlap(W["Learned"], W["Transfer"])

            # ⚠ RSA 的零模型**不能**用细胞标签置换：RDM 是"条件间跨细胞相关"，
            #   对细胞行做置换是数学不变量（实测观测值恰好等于零模型 95%）。
            #   RDM 属于**条件空间**，与细胞无关 ⇒ 正确零模型是**跨鼠配对**（在循环外统一算）。
            # 子空间 overlap 的零模型可以用细胞置换：置换载荷行会改变张成的子空间。
            no = []
            for _ in range(N_PERM):
                p = rng.permutation(n)
                no.append(subspace_overlap(W["Learned"], W["Transfer"][p]))
            no = np.array(no)
            o95 = float(np.percentile(no, 95))

            # RSA 可靠性：试次奇偶分半
            dd = dat["Learned"]
            ZL = dd["Z"][:, sel["Learned"][common]]
            cue = dd["cue"][(dd["cue"] > int(2 * dd["fs"])) &
                            (dd["cue"] < len(ZL) - int(2.5 * dd["fs"]))]
            r1 = rsa(cond_matrix(ZL, dd["fs"], cue[0::2]),
                     cond_matrix(ZL, dd["fs"], cue[1::2]))

            rows.append(dict(mouse=m, group=gname, n_cell=n,
                             rsa_LT=r_LT, rsa_null95=np.nan, rsa_reliab=r1,
                             ov_LT=ov_LT, ov_null95=o95,
                             rsa_over=False, ov_over=bool(ov_LT > o95)))
            MATS.setdefault(gname, {})[m] = M
            print(f"{m:<9s}{gname:<8s}{n:6d}{r_LT:10.3f}{'-':>8s}"
                  f"{ov_LT:9.3f}{o95:8.3f}{r1:9.3f}")

    # ---- RSA 的跨鼠零模型 -------------------------------------------------
    for gname, _ in GROUPS:
        d = MATS.get(gname, {})
        ms = sorted(d)
        if len(ms) < 4:
            continue
        for rec in rows:
            if rec["group"] != gname:
                continue
            m = rec["mouse"]
            null = [rsa(d[m]["Learned"], d[o]["Transfer"]) for o in ms if o != m]
            null = [x for x in null if np.isfinite(x)]
            if len(null) < 3:
                continue
            p95 = float(np.percentile(null, 95))
            rec["rsa_null95"] = p95
            rec["rsa_null_med"] = float(np.median(null))
            rec["rsa_cross"] = True
            rec["rsa_over"] = bool(np.isfinite(rec["rsa_LT"]) and rec["rsa_LT"] > p95)
    print("\n（RSA 零模型为**跨鼠配对**，95% 分位见下表）")

    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(rows, indent=2, ensure_ascii=False))

    if rows:
        print(f"\n=== 汇总 ===")
        print(f"{'组':<8s}{'n':>4s}{'RSA中位':>9s}{'RSA超零':>9s}"
              f"{'overlap中位':>12s}{'超零':>8s}{'RSA可靠性中位':>13s}")
        for gname, _ in GROUPS:
            g = [x for x in rows if x["group"] == gname]
            if not g:
                continue
            print(f"{gname:<8s}{len(g):4d}"
                  f"{np.nanmedian([x['rsa_LT'] for x in g]):9.3f}"
                  f"{sum(1 for x in g if x['rsa_over']):6d}/{len(g)}"
                  f"{np.nanmedian([x['ov_LT'] for x in g]):12.3f}"
                  f"{sum(1 for x in g if x['ov_over']):5d}/{len(g)}"
                  f"{np.nanmedian([x['rsa_reliab'] for x in g]):13.3f}")
    print(f"\n用时 {(time.time()-t0)/60:.1f} min；写出 {OUT}")


if __name__ == "__main__":
    main()

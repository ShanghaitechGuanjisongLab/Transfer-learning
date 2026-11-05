"""Step37_CrossPhase_Antisym.py —— 目标 2：跨阶段反对称算子的直接比较

为什么要这条路线
  `ρ_rot` 把反对称结构压成一个标量，已被证明缺乏判别力（RSA/谱/RDM 全部失败）。
  但 `A_τ = (C_τ − C_τ^T)/2` 是**每个细胞对上的一个数**，保留了空间结构。
  在 CellUID 交集上，两阶段的 `A_τ` 可以**逐元素比较**，从而直接回答
  "Learned 与 Transfer/Final 的非梯度结构是不是同一个"。

设计
  · 细胞：三阶段 CellUID 交集，且三阶段均为 MOp2/3（不足 40 则退回全部交集）
  · 预处理：P1 → 逐细胞稳健 z-score（这一步很关键：使每个细胞方差可比，避免少数细胞主导）
  · **扣除定型诱发轨迹**（A.18/A.18.1 证明它会自己产生反对称）：
        R(k) = mean_trials Z[cue+k]，残差 = Z − R(t−cue)
  · lag = 16 帧（τ ≈ 2 s）
  · 相似性 = 两阶段 A_τ 的**上三角**逐元素 Pearson r
  · 零模型 = 打乱一阶段的细胞标签（P A P^T），N_PERM=300
       —— 这里标签置换是**有效**的，因为要检验的正是"同标签对应"
  · **可靠性天花板**：阶段内奇偶分半各算一次 A_τ，求上三角相关，Spearman-Brown 校正
        r_full = 2r_half / (1 + r_half)
     没有这个天花板，跨阶段 r 无法解释（与 C3-b、A.16 的教训相同）

判读（预先声明）
  · 两阶段可靠性都 >= 0.5 且 跨阶段 r > 自身零模型 95%
        ⇒ 该配对共享反对称结构 ✅
  · 可靠性 >= 0.5 但 r 未超零模型 ⇒ 不共享
  · 任一可靠性 < 0.5 ⇒ **不可判定**（估计不可靠）
"""
from __future__ import annotations

import json
import os
import time

import numpy as np

import attractor_core as AC
from rslds_data import load_block

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "results", "_step37_crossphase_antisym.json")
PHASES = ["Learned", "Transfer", "Final"]
MIN_CELL = 40
LAG = 16
ARC_MAX_S = 25.0
N_PERM = 300
MIN_RELIAB = 0.5


def load_phase(path):
    d = load_block(path)
    fs = d["fs"]
    Y = np.nan_to_num(AC.dff(d["X"], fs), nan=0.0, posinf=0.0, neginf=0.0)
    Z = AC.zscore_robust(AC.VARIANTS["P1"](Y, fs))
    rec = dict(fs=fs, Z=Z, uid=np.asarray(d["cell_uid"], dtype=np.int64),
               layer=np.asarray(d.get("z_layer", np.zeros(Z.shape[1], dtype=np.int64))),
               cue=np.sort(np.asarray(d.get("idx_cue", []), dtype=np.int64)),
               mouse=d.get("mouse", ""), phase=d.get("phase", ""))
    return rec


def build_segments(cue, fs, K, n):
    return [(int(c), K) for c in cue[:-1] if int(c) + K <= n]


def residual(Z, cue, fs, segs, K, which=None):
    """扣除 trial 锁时平均轨迹；which 给出用于估 R 的 trial 子集下标。"""
    idx = np.arange(len(segs)) if which is None else which
    R = np.zeros((K, Z.shape[1]))
    n = 0
    for j in idx:
        s, _ = segs[j]
        R += Z[s:s + K]
        n += 1
    if n == 0:
        return None
    R /= n
    Zr = Z.copy()
    for s, _ in segs:
        Zr[s:s + K] = Z[s:s + K] - R
    return Zr


def antisym(Zr, segs):
    n, p = Zr.shape
    C0 = np.zeros((p, p))
    Ct = np.zeros((p, p))
    m = 0
    for s, L in segs:
        if L <= LAG + 1:
            continue
        a = Zr[s:s + L - LAG]
        b = Zr[s + LAG:s + L]
        C0 += a.T @ a
        Ct += a.T @ b
        m += len(a)
    if m < 100:
        return None
    C0 /= m
    Ct /= m
    A = 0.5 * (Ct - Ct.T)
    return A, float(np.linalg.norm(A) / max(np.linalg.norm(0.5 * (Ct + Ct.T)), 1e-12))


def tri(A):
    return A[np.triu_indices(A.shape[0], 1)]


def corr(a, b):
    sa, sb = a.std(), b.std()
    if sa < 1e-15 or sb < 1e-15:
        return np.nan
    return float(((a - a.mean()) * (b - b.mean())).mean() / (sa * sb))


def main():
    t0 = time.time()
    # 找齐三阶段的鼠
    bymouse = {}
    from rslds_data import scan_cohort
    for b in scan_cohort("ALB", phases=PHASES):
        bymouse.setdefault(b["mouse"], {})[b["phase"]] = b["path"]
    full = {m: v for m, v in bymouse.items() if all(ph in v for ph in PHASES)}
    out = []
    for mouse, paths in sorted(full.items()):
        P = {}
        for ph in PHASES:
            P[ph] = load_phase(paths[ph])
        common = set(P[PHASES[0]]["uid"])
        for ph in PHASES[1:]:
            common &= set(P[ph]["uid"])
        common = sorted(common)
        if not common:
            continue
        # 优先 MOp2/3
        sel_uid = None
        for code, tag in ((1, "MOp2/3"), (None, "pooled")):
            ok = []
            for u in common:
                g = True
                for ph in PHASES:
                    k = int(np.where(P[ph]["uid"] == u)[0][0])
                    if code is not None and int(P[ph]["layer"][k]) != code:
                        g = False
                        break
                if g:
                    ok.append(u)
            if len(ok) >= MIN_CELL:
                sel_uid, group = ok, tag
                break
        if sel_uid is None:
            print(f"  {mouse}: 交集不足，跳过")
            continue
        uid_arr = np.array(sel_uid)
        A, info = {}, {}
        for ph in PHASES:
            idx = [int(np.where(P[ph]["uid"] == u)[0][0]) for u in uid_arr]
            Zp = P[ph]["Z"][:, idx]
            fs = P[ph]["fs"]
            cue = P[ph]["cue"]
            K = int(min(ARC_MAX_S * fs, np.diff(cue).min()))
            segs = build_segments(cue, fs, K, len(Zp))
            if len(segs) < 10:
                A[ph] = None
                continue
            Zr = residual(Zp, cue, fs, segs, K)
            r = antisym(Zr, segs)
            A[ph] = r[0] if r else None
            info[ph] = dict(rho_rot=r[1] if r else np.nan, n_seg=len(segs), K=K)
            # 奇偶分半可靠性
            h1 = np.arange(0, len(segs), 2)
            h2 = np.arange(1, len(segs), 2)
            res = []
            for h in (h1, h2):
                if len(h) < 5:
                    res.append(None)
                    continue
                Zh = residual(Zp, cue, fs, segs, K, which=h)
                sg = [segs[j] for j in h]
                rr = antisym(Zh, sg)
                res.append(rr[0] if rr else None)
            if res[0] is not None and res[1] is not None:
                rh = corr(tri(res[0]), tri(res[1]))
                info[ph]["rel_half"] = rh
                info[ph]["rel_full"] = (2 * rh / (1 + rh)) if np.isfinite(rh) and rh > -1 else np.nan
            else:
                info[ph]["rel_half"] = np.nan
                info[ph]["rel_full"] = np.nan
        avail = [ph for ph in PHASES if A[ph] is not None]
        rec = dict(mouse=mouse, group=group, n_cell=len(sel_uid),
                   rel={ph: info[ph]["rel_full"] for ph in PHASES},
                   rho={ph: info[ph]["rho_rot"] for ph in PHASES})
        pairs = {}
        for i in range(len(avail)):
            for j in range(i + 1, len(avail)):
                p1, p2 = avail[i], avail[j]
                r = corr(tri(A[p1]), tri(A[p2]))
                rng = np.random.default_rng(0)
                null = []
                n_ = A[p2].shape[0]
                for _ in range(N_PERM):
                    pm = rng.permutation(n_)
                    Ap = A[p2][np.ix_(pm, pm)]
                    null.append(corr(tri(A[p1]), tri(Ap)))
                null = np.array([v for v in null if np.isfinite(v)])
                pairs[f"{p1}-{p2}"] = dict(
                    r=float(r) if np.isfinite(r) else np.nan,
                    null_med=float(np.median(null)) if len(null) else np.nan,
                    null_p95=float(np.percentile(null, 95)) if len(null) else np.nan,
                    p=float((1 + np.sum(null >= r)) / (len(null) + 1)) if len(null) else np.nan)
        rec["pairs"] = pairs
        out.append(rec)
        rs = "  ".join(f"{k[0]}~{k[-1]}:r={v['r']:+.3f}(p={v['p']:.3f})" for k, v in pairs.items())
        rel = " ".join(f"{ph[:1]}={rec['rel'][ph]:.2f}" if np.isfinite(rec['rel'][ph]) else f"{ph[:1]}=nan"
                       for ph in PHASES)
        print(f"  {mouse:<9s}{group:<7s}nCell={len(sel_uid):4d} 可靠性 {rel}   {rs}  "
              f"({(time.time()-t0)/60:.1f} min)")

    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(out, indent=2, ensure_ascii=False))

    print(f"\n=== 汇总（{len(out)} 只鼠）===")
    print(f"{'鼠':<9s}{'组':<7s}{'nCell':>6s}{'rel L':>7s}{'rel T1':>7s}{'rel T2':>7s}"
          f"{'r(L,T1)':>9s}{'零95%':>8s}{'p':>7s}{'判定':>10s}")
    n_ok = n_bad = n_und = 0
    for rec in out:
        pr = rec["pairs"].get("Learned-Transfer", {})
        relL = rec["rel"].get("Learned", np.nan)
        relT = rec["rel"].get("Transfer", np.nan)
        r = pr.get("r", np.nan)
        p = pr.get("p", np.nan)
        pk = pr.get("null_p95", np.nan)
        if not np.isfinite(relL) or not np.isfinite(relT) or min(relL, relT) < MIN_RELIAB:
            verdict = "不可判定"
            n_und += 1
        elif np.isfinite(r) and r > pk:
            verdict = "共享 ✅"
            n_ok += 1
        else:
            verdict = "不共享"
            n_bad += 1
        print(f"{rec['mouse']:<9s}{rec['group']:<7s}{rec['n_cell']:6d}{relL:7.2f}{relT:7.2f}"
              f"{rec['rel'].get('Final', np.nan):7.2f}{r:9.3f}{pk:8.3f}{p:7.3f}{verdict:>10s}")
    print(f"\n共享 {n_ok} / 不共享 {n_bad} / 不可判定 {n_und}")
    print(f"用时 {(time.time()-t0)/60:.1f} min；写出 {OUT}")


if __name__ == "__main__":
    main()

"""Step40_RotationSubspace.py —— 用"旋转子空间"代替逐元素比较（目标 2，低维统计量）

为什么换
  A.21（`Step37`）逐元素比较 45k 个 A_τ 上三角元素，但**奇偶分半可靠性中位仅 0.16**
  （1/33 ≧0.5）⇒ 什么都不能确认。问题不在零模型，在**统计量的自由度远大于数据**。

新统计量
  反对称矩阵 A_τ=(C_τ−C_τᵀ)/2 是实斜对称的，其奇异值成对出现，每对张成一个**旋转平面**。
  取前 m 个右奇异向量 V_m（m=2 → 一个平面；m=4 → 两个平面），用**子空间重叠**比较阶段：

      overlap(W₁,W₂) = mean( s²(W₁ᵀW₂) ) = ‖W₁ᵀW₂‖_F² / m   ∈ [m/n, 1]

  自由度从 45k 降到几个数，且**子空间对向量符号/规范无歧义**（这正是 C3-b 栽过的坑）。

三重对照（这是能解释的关键）
  · **天花板** ceiling：阶段内奇偶分半两个子空间的重叠 —— 同一批数据能达到的上限
  · **跨阶段** cross：两阶段全量子空间的重叠
  · **零模型** null：把一阶段细胞标签打乱（P A Pᵀ）后重算，N_PERM=200

判读（预先声明）
  · cross ≈ ceiling 且 明显 > null ⇒ **共享旋转子空间** ✅
  · cross ≈ null ⇒ 不共享
  · ceiling ≈ null（天花板塌到地面）⇒ **不可判定**（该子空间本身估不出来）
"""
from __future__ import annotations

import json
import os
import time

import numpy as np

import attractor_core as AC
from rslds_compat import load_compat, load_layer_map
from rslds_data import scan_cohort

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "results", "_step40_rotsubspace.json")
PHASES = ["Learned", "Transfer", "Final"]
MIN_CELL = 40
LAG = 16
ARC_MAX_S = 25.0
M_LIST = [2, 4]
N_PERM = 200


def build(path, layer_map):
    d = load_compat(path, layer_map)
    fs = d["fs"]
    Y = np.nan_to_num(AC.dff(d["X"], fs), nan=0.0, posinf=0.0, neginf=0.0)
    return d, fs, Y


def antisym(Zp, segs, lag=LAG):
    n, p = Zp.shape
    C0 = np.zeros((p, p))
    Ct = np.zeros((p, p))
    m = 0
    for s, L in segs:
        if L <= lag + 1:
            continue
        a = Zp[s:s + L - lag]
        b = Zp[s + lag:s + L]
        C0 += a.T @ a
        Ct += a.T @ b
        m += len(a)
    if m < 100:
        return None
    C0 /= m
    Ct /= m
    return 0.5 * (Ct - Ct.T)


def residual(Z, segs, K, which=None):
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


def top_vecs(A, m):
    if A is None:
        return None
    U, s, Vt = np.linalg.svd(A, full_matrices=False)
    return Vt[:m].T, s


def overlap(W1, W2):
    if W1 is None or W2 is None:
        return np.nan
    M = W1.T @ W2
    return float((M ** 2).sum() / W1.shape[1])


def main():
    t0 = time.time()
    layer_map = load_layer_map()
    bymouse = {}
    for ph in PHASES:
        for b in scan_cohort("ALB", phases=[ph]):
            bymouse.setdefault(b["mouse"], {})[ph] = b["path"]
    full = {m: v for m, v in bymouse.items() if all(p in v for p in PHASES)}

    out = []
    for mouse, paths in sorted(full.items()):
        P = {}
        for ph in PHASES:
            d, fs, Y = build(paths[ph], layer_map)
            ok = np.std(Y, axis=0) > 1e-9
            zl = np.asarray(d.get("z_layer", np.zeros(Y.shape[1], dtype=np.int64)))
            if zl.size != Y.shape[1]:
                zl = np.zeros(Y.shape[1], dtype=np.int64)
            P[ph] = dict(d=d, fs=fs, Z=AC.zscore_robust(AC.VARIANTS["P1"](Y, fs)),
                         ok=ok, layer=zl)
        common = set(P[PHASES[0]]["d"]["cell_uid"])
        for ph in PHASES[1:]:
            common &= set(P[ph]["d"]["cell_uid"])
        sel_uid = []
        for u in sorted(common):
            good = True
            for ph in PHASES:
                k = int(np.where(P[ph]["d"]["cell_uid"] == u)[0][0])
                if int(P[ph]["layer"][k]) != 1:
                    good = False
                    break
            if good:
                sel_uid.append(u)
        if len(sel_uid) < MIN_CELL:
            continue
        uid = np.array(sel_uid)

        rec = dict(mouse=mouse, n_cell=len(uid))
        Vs = {}
        for ph in PHASES:
            idx = [int(np.where(P[ph]["d"]["cell_uid"] == u)[0][0]) for u in uid]
            Z = P[ph]["Z"][:, idx]
            fs, cue = P[ph]["fs"], P[ph]["d"]["idx_cue"]
            K = int(min(ARC_MAX_S * fs, np.diff(cue).min()))
            segs = [(int(cue[i]), K) for i in range(len(cue) - 1)
                    if int(cue[i]) + K <= len(Z)]
            if len(segs) < 10:
                Vs[ph] = None
                continue
            Zr = residual(Z, segs, K)
            A = antisym(Zr, segs)
            Vs[ph] = dict(A=A, half=[])
            for h in (np.arange(0, len(segs), 2), np.arange(1, len(segs), 2)):
                if len(h) < 5:
                    Vs[ph]["half"].append(None)
                    continue
                Zh = residual(Z, segs, K, which=h)
                Vs[ph]["half"].append(antisym(Zh, [segs[j] for j in h]))
        for m in M_LIST:
            ceil, cross, nulls = {}, {}, {}
            for ph in PHASES:
                if Vs[ph] is None:
                    continue
                W = top_vecs(Vs[ph]["A"], m)
                Vs[ph][f"W{m}"] = W[0] if W else None
                h1, h2 = Vs[ph]["half"]
                W1 = top_vecs(h1, m)
                W2 = top_vecs(h2, m)
                ceil[ph] = overlap(W1[0] if W1 else None, W2[0] if W2 else None)
            av = [ph for ph in PHASES if Vs[ph] is not None]
            pairs = {}
            for i in range(len(av)):
                for j in range(i + 1, len(av)):
                    p1, p2 = av[i], av[j]
                    r = overlap(Vs[p1][f"W{m}"], Vs[p2][f"W{m}"])
                    A2 = Vs[p2]["A"]
                    rng = np.random.default_rng(0)
                    nl = []
                    if A2 is not None:
                        for _ in range(N_PERM):
                            pm = rng.permutation(A2.shape[0])
                            Wp = top_vecs(A2[np.ix_(pm, pm)], m)
                            nl.append(overlap(Vs[p1][f"W{m}"], Wp[0] if Wp else None))
                    nl = np.array([v for v in nl if np.isfinite(v)])
                    pairs[f"{p1}-{p2}"] = dict(
                        r=r, null_med=float(np.median(nl)) if len(nl) else np.nan,
                        null_p95=float(np.percentile(nl, 95)) if len(nl) else np.nan)
            rec[f"m{m}"] = dict(ceiling=ceil, pairs=pairs)
        out.append(rec)
        c = " ".join("%s=%.2f" % (p[:1], rec["m2"]["ceiling"].get(p, np.nan)) for p in PHASES)
        cr = rec["m2"]["pairs"].get("Learned-Transfer", {})
        print(f"  {mouse:<9s} nCell={len(uid):4d}  天花板 {c}  "
              f"r(L,T1)={cr.get('r', np.nan):.3f} (null95={cr.get('null_p95', np.nan):.3f})"
              f"  ({(time.time()-t0)/60:.1f} min)")

    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(out, indent=2, ensure_ascii=False))

    for m in M_LIST:
        print(f"\n=== m={m} ===")
        print(f"{'鼠':<9s}{'ceil L':>8s}{'ceil T1':>8s}{'ceil T2':>8s}"
              f"{'r(L,T1)':>9s}{'r(L,T2)':>9s}{'r(T1,T2)':>9s}{'零95%':>8s}")
        for rec in out:
            d = rec[f"m{m}"]
            c = d["ceiling"]
            p = d["pairs"]
            print(f"{rec['mouse']:<9s}{c.get('Learned', np.nan):8.2f}"
                  f"{c.get('Transfer', np.nan):8.2f}{c.get('Final', np.nan):8.2f}"
                  f"{p.get('Learned-Transfer', {}).get('r', np.nan):9.3f}"
                  f"{p.get('Learned-Final', {}).get('r', np.nan):9.3f}"
                  f"{p.get('Transfer-Final', {}).get('r', np.nan):9.3f}"
                  f"{p.get('Learned-Transfer', {}).get('null_p95', np.nan):8.3f}")
        lt = [rec[f"m{m}"]["pairs"].get("Learned-Transfer", {}).get("r", np.nan) for rec in out]
        nl = [rec[f"m{m}"]["pairs"].get("Learned-Transfer", {}).get("null_p95", np.nan) for rec in out]
        cl = [rec[f"m{m}"]["ceiling"].get("Learned", np.nan) for rec in out]
        ct = [rec[f"m{m}"]["ceiling"].get("Transfer", np.nan) for rec in out]
        lt = np.array(lt)
        nl = np.array(nl)
        print(f"中位：天花板 L {np.nanmedian(cl):.2f} / T {np.nanmedian(ct):.2f}；"
              f"r(L,T1) {np.nanmedian(lt):.3f}；零95% {np.nanmedian(nl):.3f}；"
              f"超零 {int(np.nansum(lt > nl))}/{len(lt)}")
    print(f"\n用时 {(time.time()-t0)/60:.1f} min；写出 {OUT}")


if __name__ == "__main__":
    main()

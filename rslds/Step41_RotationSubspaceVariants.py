"""Step41_RotationSubspaceVariants.py —— C3-e 的预处理三档复核

A.24（`Step40`）在 P1 下得到"部分共享"：cross 显著 > 置换零模型（8–11/11），
但只有阶段内天花板（0.21–0.25）的 50–60%。A.17/A.18 已证明 ρ_rot 对预处理档位敏感，
所以这条结论必须在 **P0/P1/P2** 三档下都成立才能写进论文。

两处加速（不改变定义）
  ① 置换零模型无需重做 SVD：对斜对称 A，SVD 为 A=UΣVᵀ；令 A'=PAPᵀ=(PU)Σ(PV)ᵀ，
     故 V' = P V。于是
         overlap(W₁, V') = ‖W₁ᵀ P V₂‖_F²/m = ‖(PᵀW₁)ᵀ V₂‖_F²/m
     直接把 W₁ 的行打乱即可，O(n·m) 而非 O(n³)。所以 N_PERM 可提到 500。
  ② 每档只算一次 A 与两个半段 A。

判读（预先声明）
  · 三档均满足 cross>零95%、且 cross/天花板 明显 <1
        ⇒ "部分共享"稳健，可写入论文
  · 仅部分档位成立，或某档 cross≈零
        ⇒ 判"预处理依赖"，降级
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
OUT = os.path.join(HERE, "results", "_step41_rotsub_var.json")
PHASES = ["Learned", "Transfer", "Final"]
VARIANTS = ["P0", "P1", "P2"]
MIN_CELL = 40
LAG = 16
ARC_MAX_S = 25.0
M_LIST = [2, 4]
N_PERM = 500


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
    return 0.5 * (Ct / m - (Ct / m).T)


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
    return np.linalg.svd(A, full_matrices=False)[2][:m].T


def ov(W1, W2):
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
            dd = load_compat(paths[ph], layer_map)
            ff = dd["fs"]
            yy = np.nan_to_num(AC.dff(dd["X"], ff), nan=0.0, posinf=0.0, neginf=0.0)
            ok = np.std(yy, axis=0) > 1e-9
            zl = np.asarray(dd.get("z_layer", np.zeros(yy.shape[1], dtype=np.int64)))
            if zl.size != yy.shape[1]:
                zl = np.zeros(yy.shape[1], dtype=np.int64)
            P[ph] = dict(d=dd, fs=ff, Y=yy, ok=ok, layer=zl)
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
        for v in VARIANTS:
            Vs = {}
            for ph in PHASES:
                idx = [int(np.where(P[ph]["d"]["cell_uid"] == u)[0][0]) for u in uid]
                Y = P[ph]["Y"][:, idx]
                fs, cue = P[ph]["fs"], P[ph]["d"]["idx_cue"]
                K = int(min(ARC_MAX_S * fs, np.diff(cue).min()))
                segs = [(int(cue[i]), K) for i in range(len(cue) - 1)
                        if int(cue[i]) + K <= len(Y)]
                if len(segs) < 10:
                    Vs[ph] = None
                    continue
                Z = AC.zscore_robust(AC.VARIANTS[v](Y, fs))
                A = antisym(residual(Z, segs, K), segs)
                halves = []
                for h in (np.arange(0, len(segs), 2), np.arange(1, len(segs), 2)):
                    if len(h) < 5:
                        halves.append(None)
                        continue
                    halves.append(antisym(residual(Z, segs, K, which=h),
                                          [segs[j] for j in h]))
                Vs[ph] = dict(A=A, halves=halves)
            res = {}
            for m in M_LIST:
                ceil, pairs = {}, {}
                W = {}
                for ph in PHASES:
                    if Vs[ph] is None:
                        continue
                    W[ph] = top_vecs(Vs[ph]["A"], m)
                    ceil[ph] = ov(top_vecs(Vs[ph]["halves"][0], m),
                                  top_vecs(Vs[ph]["halves"][1], m))
                av = [ph for ph in PHASES if ph in W]
                rng = np.random.default_rng(0)
                for i in range(len(av)):
                    for j in range(i + 1, len(av)):
                        p1, p2 = av[i], av[j]
                        r = ov(W[p1], W[p2])
                        n = W[p1].shape[0]
                        nl = []
                        for _ in range(N_PERM):
                            pm = rng.permutation(n)
                            nl.append(ov(W[p1][pm, :], W[p2]))
                        nl = np.array(nl)
                        pairs[f"{p1}-{p2}"] = dict(
                            r=r, null_med=float(np.median(nl)),
                            null_p95=float(np.percentile(nl, 95)))
                res[f"m{m}"] = dict(ceiling=ceil, pairs=pairs)
            rec[v] = res
        out.append(rec)
        c = rec["P1"]["m4"]["ceiling"]
        p4 = rec["P1"]["m4"]["pairs"].get("Learned-Transfer", {})
        print(f"  {mouse:<9s} n={len(uid):4d}  P1 天花板 L={c.get('Learned', np.nan):.2f}"
              f" T={c.get('Transfer', np.nan):.2f}  r(L,T1)={p4.get('r', np.nan):.3f}"
              f" ({(time.time()-t0)/60:.1f} min)")

    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(out, indent=2, ensure_ascii=False))

    for m in M_LIST:
        print(f"\n===== m={m} =====")
        print(f"{'档':<4s}{'零95%':>8s}{'天花板':>8s}{'r(L,T1)':>9s}{'r(L,T2)':>9s}"
              f"{'r(T1,T2)':>9s}{'>零L-T1':>9s}{'ratio':>8s}")
        for v in VARIANTS:
            nl, ce, r1, r2, r3, cnt, rat = [], [], [], [], [], [], []
            for rec in out:
                d = rec[v][f"m{m}"]
                p = d["pairs"]
                nl.append(p.get("Learned-Transfer", {}).get("null_p95", np.nan))
                ce.append(max(d["ceiling"].get("Learned", np.nan),
                              d["ceiling"].get("Transfer", np.nan)))
                r1.append(p.get("Learned-Transfer", {}).get("r", np.nan))
                r2.append(p.get("Learned-Final", {}).get("r", np.nan))
                r3.append(p.get("Transfer-Final", {}).get("r", np.nan))
                x = p.get("Learned-Transfer", {})
                if np.isfinite(x.get("r", np.nan)) and np.isfinite(x.get("null_p95", np.nan)):
                    cnt.append(x["r"] > x["null_p95"])
                if np.isfinite(x.get("r", np.nan)) and np.isfinite(ce[-1]) and ce[-1] > 0:
                    rat.append(x["r"] / ce[-1])
            print(f"{v:<4s}{np.nanmedian(nl):8.3f}{np.nanmedian(ce):8.3f}"
                  f"{np.nanmedian(r1):9.3f}{np.nanmedian(r2):9.3f}{np.nanmedian(r3):9.3f}"
                  f"{sum(cnt):5d}/{len(cnt):<3d}{np.median(rat):8.2f}")
    print(f"\n用时 {(time.time()-t0)/60:.1f} min；写出 {OUT}")


if __name__ == "__main__":
    main()

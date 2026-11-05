"""Step42_LAB_Replication.py —— 在 LAB 队列做外部复现

为什么要做
  A.18/A.25 的全部正面结论都来自 ALB（声水→光水，11 只鼠）。
  LAB（光水→声水）**任务顺序相反**，是天然的独立复现：若同样的非梯度结构与跨阶段共享
  也出现在 LAB，就不再是 ALB 单队列的偶然。

LAB 的设计（与 ALB 相反）
  Learned  = 最后一场 LightWater（LLw 或 LightWater）
  Transfer = 第一场 AudioWater（AuAuw 或 AudioWater）
  Final    = 最后一场 AudioWater

规模警告
  LAB 只有 6 只鼠，Final 仅 5 只 ⇒ 三阶段交集只有 5 只。
  **因此本脚本只做方向性核对，不做显著性主张**（n=5 无法支持 ">=8/11" 这类门槛）。

两件事
  ① 目标 1 的方向：MOp2/3 的扣弧后旋转比（ratio = rho_res / 零基线）在
     Learned / Transfer / Final 三阶段的量级，与 ALB（1.11 / 1.38 / 1.13）对照
  ② 目标 2 的方向：旋转子空间重叠（m=2/4）+ 天花板 + 置换零模型，看
     "cross 高于零、但低于天花板"这一模式是否重现
"""
from __future__ import annotations

import json
import os
import time

import numpy as np

import attractor_core as AC
import Step10_TICA as T
import Step12_TICA_NonReversible as S12
import Step41_RotationSubspaceVariants as S41
from rslds_data import load_block, scan_cohort

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "results", "_step42_lab.json")
COHORT = "LightAudioBaseline"
PHASES = ["Learned", "Transfer", "Final"]
VARIANTS = ["P0", "P1", "P2"]
M_LIST = [2, 4]
N_PERM_EXC = 200
MIN_CELL = 40
ARC_MAX_S = 25.0


def prep(path, variant):
    d = load_block(path)
    fs = d["fs"]
    Y = np.nan_to_num(AC.dff(d["X"], fs), nan=0.0, posinf=0.0, neginf=0.0)
    ok = np.std(Y, axis=0) > 1e-9
    zl = np.asarray(d.get("z_layer", np.zeros(Y.shape[1], dtype=np.int64)))
    if zl.size != Y.shape[1]:
        zl = np.zeros(Y.shape[1], dtype=np.int64)
    sel = ok & (zl == 1)
    cue = np.sort(np.asarray(d.get("idx_cue", []), dtype=np.int64))
    if int(sel.sum()) < MIN_CELL or len(cue) < 10:
        return None
    Z = AC.zscore_robust(AC.VARIANTS[variant](Y[:, sel], fs))
    K = int(min(ARC_MAX_S * fs, np.diff(cue).min()))
    segs = [(int(cue[i]), K) for i in range(len(cue) - 1)
            if int(cue[i]) + K <= len(Z)]
    if len(segs) < 10:
        return None
    return dict(fs=fs, Z=Z, segs=segs, K=K, cue=cue, n_cell=int(sel.sum()))


def main():
    t0 = time.time()
    rows = []
    for ph in PHASES:
        for b in scan_cohort(COHORT, phases=[ph]):
            d0 = load_block(b["path"], meta_only=True)
            if not len(d0.get("idx_cue", [])):
                print(f"  {b['mouse']} {ph}: 缺 idxCue，跳过")
                continue
            for v in VARIANTS:
                P = prep(b["path"], v)
                if P is None:
                    continue
                Z, segs, K = P["Z"], P["segs"], P["K"]
                Zr = S41.residual(Z, segs, K)
                r_obs = S41.antisym(Z, segs)
                r_res = S41.antisym(Zr, segs)
                if r_obs is None or r_res is None:
                    continue
                C0, Ct = S12.cov_pair(Z, segs, S41.LAG)
                rho_obs = S12.rho_rot(Ct) if C0 is not None else np.nan
                C0, Ct = S12.cov_pair(Zr, segs, S41.LAG)
                rho_res = S12.rho_rot(Ct) if C0 is not None else np.nan
                rng = np.random.default_rng(0)
                null = []
                for _ in range(N_PERM_EXC):
                    c0, ctn = S12.cov_pair(T.phase_rand(Zr, rng), segs, S41.LAG)
                    if c0 is None:
                        continue
                    u = S12.rho_rot(ctn)
                    if np.isfinite(u):
                        null.append(u)
                nm = float(np.median(null)) if null else np.nan
                rows.append(dict(mouse=b["mouse"], phase=ph, variant=v,
                                 design=d0.get("design", ""), n_cell=P["n_cell"],
                                 n_trial=len(segs), rho_obs=rho_obs, rho_res=rho_res,
                                 res_null=nm,
                                 ratio=float(rho_res / nm) if np.isfinite(nm) and nm > 0 else np.nan,
                                 excess=float(rho_res - nm) if np.isfinite(nm) else np.nan))
            print(f"  {b['mouse']:<9s}{ph:<9s} ({(time.time()-t0)/60:.1f} min)")

    # ② 旋转子空间（三阶段交集）
    bymouse = {}
    for ph in PHASES:
        for b in scan_cohort(COHORT, phases=[ph]):
            bymouse.setdefault(b["mouse"], {})[ph] = b["path"]
    full = {m: v for m, v in bymouse.items() if all(p in v for p in PHASES)}
    sub = []
    for mouse, paths in sorted(full.items()):
        Ps = {}
        for ph in PHASES:
            d = load_block(paths[ph])
            fs = d["fs"]
            Y = np.nan_to_num(AC.dff(d["X"], fs), nan=0.0, posinf=0.0, neginf=0.0)
            ok = np.std(Y, axis=0) > 1e-9
            zl = np.asarray(d.get("z_layer", np.zeros(Y.shape[1], dtype=np.int64)))
            if zl.size != Y.shape[1]:
                zl = np.zeros(Y.shape[1], dtype=np.int64)
            Ps[ph] = dict(d=d, fs=fs, Y=Y, ok=ok, layer=zl)
        common = set(Ps[PHASES[0]]["d"]["cell_uid"])
        for ph in PHASES[1:]:
            common &= set(Ps[ph]["d"]["cell_uid"])
        uid = []
        for u in sorted(common):
            if all(int(Ps[ph]["layer"][int(np.where(Ps[ph]["d"]["cell_uid"] == u)[0][0])]) == 1
                   for ph in PHASES):
                uid.append(u)
        if len(uid) < MIN_CELL:
            print(f"  {mouse}: MOp2/3 交集仅 {len(uid)}，跳过子空间分析")
            continue
        uid = np.array(uid)
        rec = dict(mouse=mouse, n_cell=len(uid))
        for v in VARIANTS:
            V = {}
            for ph in PHASES:
                idx = [int(np.where(Ps[ph]["d"]["cell_uid"] == u)[0][0]) for u in uid]
                Y = Ps[ph]["Y"][:, idx]
                fs, cue = Ps[ph]["fs"], Ps[ph]["d"]["idx_cue"]
                K = int(min(ARC_MAX_S * fs, np.diff(cue).min()))
                segs = [(int(cue[i]), K) for i in range(len(cue) - 1)
                        if int(cue[i]) + K <= len(Y)]
                if len(segs) < 10:
                    V[ph] = None
                    continue
                Z = AC.zscore_robust(AC.VARIANTS[v](Y, fs))
                A = S41.antisym(S41.residual(Z, segs, K), segs)
                hl = [S41.antisym(S41.residual(Z, segs, K, which=h), [segs[j] for j in h])
                      for h in (np.arange(0, len(segs), 2), np.arange(1, len(segs), 2))]
                V[ph] = dict(A=A, hl=hl)
            r2 = {}
            for m in M_LIST:
                ceil, pairs = {}, {}
                W = {}
                for ph in PHASES:
                    if V[ph] is None:
                        continue
                    W[ph] = S41.top_vecs(V[ph]["A"], m)
                    ceil[ph] = S41.ov(S41.top_vecs(V[ph]["hl"][0], m),
                                      S41.top_vecs(V[ph]["hl"][1], m))
                av = [p for p in PHASES if p in W]
                rng = np.random.default_rng(0)
                for i in range(len(av)):
                    for j in range(i + 1, len(av)):
                        p1, p2 = av[i], av[j]
                        r = S41.ov(W[p1], W[p2])
                        nl = []
                        for _ in range(500):
                            pm = rng.permutation(W[p1].shape[0])
                            nl.append(S41.ov(W[p1][pm, :], W[p2]))
                        pairs[f"{p1}-{p2}"] = dict(r=r, null_p95=float(np.percentile(nl, 95)),
                                                   null_med=float(np.median(nl)))
                r2[f"m{m}"] = dict(ceiling=ceil, pairs=pairs)
            rec[v] = r2
        sub.append(rec)
        print(f"  {mouse:<9s} 子空间 n={len(uid)} 完成 ({(time.time()-t0)/60:.1f} min)")

    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(dict(excess=rows, subspace=sub), indent=2, ensure_ascii=False))

    print("\n=== ① 目标 1 方向核对（MOp2/3，ratio = rho_res/零基线）===")
    print(f"{'档':<4s}{'阶段':<10s}{'n':>3s}{'rho_res':>9s}{'零基线':>9s}{'ratio':>8s}{'超额':>9s}")
    for v in VARIANTS:
        for ph in PHASES:
            g = [x for x in rows if x["variant"] == v and x["phase"] == ph]
            if not g:
                continue
            print(f"{v:<4s}{ph:<10s}{len(g):3d}{np.median([x['rho_res'] for x in g]):9.3f}"
                  f"{np.median([x['res_null'] for x in g]):9.3f}"
                  f"{np.nanmedian([x['ratio'] for x in g]):8.3f}"
                  f"{np.median([x['excess'] for x in g]):+9.4f}")
        print()

    print("=== ② 目标 2 方向核对（旋转子空间重叠）===")
    for m in M_LIST:
        for v in VARIANTS:
            r1, ce, nl = [], [], []
            for rec in sub:
                d = rec[v][f"m{m}"]
                p = d["pairs"].get("Learned-Transfer", {})
                r1.append(p.get("r", np.nan))
                nl.append(p.get("null_p95", np.nan))
                ce.append(max(d["ceiling"].get("Learned", np.nan),
                              d["ceiling"].get("Transfer", np.nan)))
            if not r1:
                continue
            cnt = int(np.nansum(np.array(r1) > np.array(nl)))
            print(f"m={m} {v}: r(L,T1) 中位 {np.nanmedian(r1):.3f}  零95% {np.nanmedian(nl):.3f}"
                  f"  天花板 {np.nanmedian(ce):.3f}  >零 {cnt}/{len(r1)}"
                  f"  ratio {np.nanmedian(np.array(r1) / np.array(ce)):.2f}")
    print(f"\n用时 {(time.time()-t0)/60:.1f} min；写出 {OUT}")


if __name__ == "__main__":
    main()

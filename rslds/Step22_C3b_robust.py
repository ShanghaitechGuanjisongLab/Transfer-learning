"""Step22_C3b_robust.py —— C3-b 的两项稳健性：N1/N2 双归一化 + MOp5 对照

N1/N2 的定义（均需事先固定，不得事后挑）
  N1  逐场 z-score —— 每个阶段各自用自身的 median / MAD 归一（迄今所有结果的口径）
  N2  逐细胞跨阶段合并标准化 —— 把同一细胞在**三个阶段**的 P1 后轨迹拼起来求
      median / MAD，三者共用这一套尺度。好处：吸收细胞自身的增益/亮度，保留跨阶段差异。

  判据：N1 与 N2 下 ρ 都成立才算数；若相反 ⇒ 判"归一化依赖"，不得挑一个报。

MOp5 对照
  同一定义、同一零模型，只把细胞集换成 MOp5。MOp5 的 M1 反号、M6 弱、可靠性 0.34，
  因此若 C3-b 在 MOp5 也成立，说明相似性与"非线性/环流"无关，只反映共享的静态配置；
  若只在 MOp2/3 成立，则与 M1/M6 的分层结论一致。

共同口径
  · a_i = E[z_i | 吸引子核心（最低 30% 距离）] − E[z_i | 全帧]
  · 零模型 = 同鼠内**细胞标签置换**（N=500）
  · 可靠性 = 时间前半/后半各自估 a 的相关，跨阶段取几何平均作上限

输出 results/_step22_c3b_robust.json
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
OUT = os.path.join(HERE, "results", "_step22_c3b_robust.json")

PHASES = ["Learned", "Transfer", "Final"]
PAIRS = [("Learned", "Transfer"), ("Learned", "Final"), ("Transfer", "Final")]
KPC = 10
CORE_FRAC = 0.3
MIN_CELL = 40
N_PERM = 500
GROUPS = [("MOp2/3", 1), ("MOp5", 2)]
NORMS = ["N1", "N2"]


def core_vec(Z, kpc=KPC):
    X, _, _, _ = T.pcs(Z, kpc)
    r = np.linalg.norm(X - np.median(X, axis=0), axis=1)
    core = r <= np.percentile(r, 100 * CORE_FRAC)
    return Z[core].mean(0) - Z.mean(0)


def main():
    t0 = time.time()
    bs = scan_cohort("ALB", phases=PHASES)
    by = {}
    for b in bs:
        by.setdefault(b["mouse"], {})[b["phase"]] = b

    rng = np.random.default_rng(0)
    rows = []
    print(f"{'鼠':<9s}{'组':<8s}{'归一':<5s}{'nCell':>6s}"
          f"{'ρ(L,T1)':>9s}{'ρ(L,T2)':>9s}{'ρ(T1,T2)':>10s}{'零模型95%':>10s}{'可靠性':>8s}")
    for m, pm in sorted(by.items()):
        if not all(p in pm for p in PHASES):
            continue
        dat = {}
        for ph in PHASES:
            d = load_block(pm[ph]["path"])
            fs = d["fs"]
            Y = np.nan_to_num(AC.dff(d["X"], fs), nan=0.0, posinf=0.0, neginf=0.0)
            P = AC.VARIANTS["P1"](Y, fs)
            dat[ph] = dict(P=P, fs=fs, ok=np.std(Y, axis=0) > 1e-9,
                           zl=np.asarray(d["z_layer"]), uid=d["cell_uid"])

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
            Psub = {ph: dat[ph]["P"][:, sel[ph][common]] for ph in PHASES}

            for norm in NORMS:
                if norm == "N1":
                    Zs = {ph: AC.zscore_robust(Psub[ph]) for ph in PHASES}
                else:
                    pool = np.vstack([Psub[ph] for ph in PHASES])
                    mu = np.median(pool, axis=0)
                    sd = 1.4826 * np.median(np.abs(pool - mu), axis=0)
                    # ⚠ 必须有**相对**地板：P1 去共模后，低活动细胞的合并 MAD 可以接近 0，
                    # 只挡 `sd <= 0` 会让 (P−mu)/sd 爆炸（实测 yqn0240 的 std(a) 达 7.3e6）。
                    floor = max(0.05 * np.median(sd[sd > 0]), 1e-9) if np.any(sd > 0) else 1e-9
                    sd = np.maximum(sd, floor)
                    Zs = {ph: (Psub[ph] - mu) / sd for ph in PHASES}

                A = {ph: core_vec(Zs[ph]) for ph in PHASES}
                r = {f"{a}-{b}": float(np.corrcoef(A[a], A[b])[0, 1]) for a, b in PAIRS}

                null = []
                perm = rng.permutation(n)
                for _ in range(N_PERM):
                    p = rng.permutation(n)
                    null.append(float(np.corrcoef(A["Learned"], A["Transfer"][p])[0, 1]))
                p95 = float(np.percentile(null, 95))

                rel = []
                for ph in ("Learned", "Transfer"):
                    L = Zs[ph].shape[0]
                    h = L // 2
                    a1 = core_vec(Zs[ph][:h])
                    a2 = core_vec(Zs[ph][h:])
                    rel.append(float(np.corrcoef(a1, a2)[0, 1]))
                ceiling = float(np.sqrt(max(rel[0], 0) * max(rel[1], 0)))

                rec = dict(mouse=m, group=gname, norm=norm, n_cell=n,
                           p95=p95, ceiling=ceiling,
                           r_LT=r["Learned-Transfer"], r_LF=r["Learned-Final"],
                           r_TF=r["Transfer-Final"],
                           over_null=bool(r["Learned-Transfer"] > p95))
                rows.append(rec)
                print(f"{m:<9s}{gname:<8s}{norm:<5s}{n:6d}"
                      f"{rec['r_LT']:9.3f}{rec['r_LF']:9.3f}{rec['r_TF']:10.3f}"
                      f"{p95:10.3f}{ceiling:8.3f}")

    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(rows, indent=2, ensure_ascii=False))

    if rows:
        print(f"\n=== 汇总 ===")
        print(f"{'组':<8s}{'归一':<5s}{'n':>4s}{'ρ(L,T1)中位':>12s}"
              f"{'ρ(L,T2)中位':>12s}{'超零模型':>10s}{'可靠性中位':>10s}")
        for gname, _ in GROUPS:
            for norm in NORMS:
                g = [x for x in rows if x["group"] == gname and x["norm"] == norm]
                if not g:
                    continue
                print(f"{gname:<8s}{norm:<5s}{len(g):4d}"
                      f"{np.median([x['r_LT'] for x in g]):12.3f}"
                      f"{np.median([x['r_LF'] for x in g]):12.3f}"
                      f"{sum(1 for x in g if x['over_null']):7d}/{len(g)}"
                      f"{np.median([x['ceiling'] for x in g]):10.3f}")
    print(f"\n用时 {(time.time()-t0)/60:.1f} min；写出 {OUT}")


if __name__ == "__main__":
    main()

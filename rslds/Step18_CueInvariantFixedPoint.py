"""Step18_CueInvariantFixedPoint.py —— cue 不变的不动点：不同刺激通道是否收敛到同一点

问题
  用户提出的关键洞察：cue 本身就是一种**扰动协议**。若各种 cue 激发的偏移最终都回到
  **同一个**不动点，则该不动点是内部状态，而不是某条感觉通路的产物。这直接对抗
  "所谓吸引子其实只是刺激响应"这个最强反驳。

为什么不能用"平均轨迹回到 0"
  若以全帧中位为参考，任何周期信号的平均轨迹都会回到 0 —— 那是**恒真**的，
  正是本项目此前 basin=1.00 类失败的同一陷阱。

做法（不恒真的版本）
  对**每一种刺激** s，只在它自己的 cue 后回落相内拟合局部线性动力系统

      Δx_t = c_s + A_s x_t + ε ,   x_s* = (I − A_s)⁻¹ c_s

  x_s* 是该刺激所激发轨迹的**局部收缩中心**。它由动力学决定，不由均值决定，
  因此不会自动相等。比较不同刺激的 x_s*。

三个参照（缺一不可）
  D_floor  同种刺激的奇偶试次分半，各估一个 x* ⇒ **测量噪声地板**（下限）
  D_obs    不同刺激之间的 ‖x_A* − x_L*‖ / spread  ⇒ 观测值
  D_null   把 cue 时刻做 ≥5 s 的环形平移后重算 ⇒ **破坏刺激特异锁时但保留自相关**
           的零模型（本项目一贯口径）

判读
  · D_obs ≈ D_floor ≪ D_null  → 不同 cue 收敛到**同一个**不动点 ✅
  · D_obs ≫ D_floor 且接近 D_null → 各 cue 有各自的不动点 ❌
  · 峰/SE < 2 的刺激类型不参与（功效不足，记为不可判定）

输出 results/_step18_cue_invariant.json
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
OUT = os.path.join(HERE, "results", "_step18_cue_invariant.json")

KPC = 10
FIT_WIN = (1.0, 4.0)      # 拟合窗：cue 后 1–4 s（回落相）
PEAK_WIN = (0.0, 2.5)
MIN_TRIAL = 8
N_SHIFT = 100
DESIGNS = ("LAu", "LAuW")


def fit_fixed_point(X, segs):
    """在给定帧段上拟合 VAR(1)，返回 (c, A, x*)。"""
    Z, Zn = [], []
    for s, e in segs:
        if e - s < 3:
            continue
        Z.append(X[s:e - 1])
        Zn.append(X[s + 1:e])
    if not Z:
        return None
    Z = np.vstack(Z)
    Zn = np.vstack(Zn)
    if len(Z) < X.shape[1] * 5:
        return None
    M = np.column_stack([np.ones(len(Z)), Z])
    coef, *_ = np.linalg.lstsq(M, Zn, rcond=None)
    c, A = coef[0], coef[1:].T
    try:
        xs = np.linalg.solve((np.eye(A.shape[0]) - A).T, c)
    except np.linalg.LinAlgError:
        return None
    return c, A, xs


def segs_for(cues, n, fs):
    out = []
    for i, c in enumerate(cues):
        s = int(c + FIT_WIN[0] * fs)
        e = int(min(c + FIT_WIN[1] * fs,
                    cues[i + 1] if i + 1 < len(cues) else n))
        out.append((s, e))
    return [(s, e) for s, e in out if s >= 0 and e <= n and e - s >= 3]


def peak_se(X, cues, fs):
    """cue 锁时的群体平均偏移峰值与其 SE（功效诊断）。"""
    xr = np.median(X, axis=0)
    post = []
    for c in cues:
        a, b = int(c), int(c + PEAK_WIN[1] * fs)
        if a >= 0 and b <= len(X):
            post.append(X[a:b] - xr)
    if len(post) < MIN_TRIAL:
        return np.nan, np.nan
    M = np.stack(post)
    m = M.mean(0)
    se = M.std(0, ddof=1) / np.sqrt(len(post))
    amp = np.linalg.norm(m, axis=1)
    ser = np.linalg.norm(se, axis=1)
    ip = int(np.argmax(amp))
    return float(amp[ip]), float(ser[ip])


def main():
    t0 = time.time()
    bs = [b for b in scan_cohort("ALB") if b["design"] in DESIGNS]
    bs.sort(key=lambda x: x["mouse"])
    rows = []
    print(f"{'鼠':<9s}{'设计':<7s}{'刺激对':<22s}{'D_floor':>8s}{'D_obs':>8s}{'D_null':>8s}"
          f"{'obs/floor':>10s}{'峰/SE_A':>9s}{'峰/SE_B':>9s}")
    for b in bs:
        d = load_block(b["path"])
        fs = d["fs"]
        Y = np.nan_to_num(AC.dff(d["X"], fs), nan=0.0, posinf=0.0, neginf=0.0)
        Y = Y[:, np.std(Y, axis=0) > 1e-9]
        Z = AC.zscore_robust(AC.VARIANTS["P1"](Y, fs))
        X, _, _, _ = T.pcs(Z, KPC)
        X = X / max(np.median(np.linalg.norm(X, axis=1)), 1e-12)

        cue = np.sort(np.asarray(d.get("idx_cue", []), dtype=np.int64))
        sc = np.asarray(d.get("stim_code", []), dtype=np.int64)
        names = d.get("stim_names", [])
        if len(cue) != len(sc) or len(names) < 2:
            continue
        # 按刺激分组（cue 顺序保持不变，供 segs_for 取"到下一 cue"的边界）
        groups = {}
        for i, (c, k) in enumerate(zip(cue, sc)):
            groups.setdefault(int(k), []).append(i)
        usable = {k: v for k, v in groups.items() if len(v) >= MIN_TRIAL}
        if len(usable) < 2:
            continue

        spread = float(np.median(np.linalg.norm(X - np.median(X, axis=0), axis=1)))
        rng = np.random.default_rng(0)

        for a_k, b_k in [(list(usable)[i], list(usable)[j])
                         for i in range(len(usable)) for j in range(i + 1, len(usable))]:
            ia, ib = usable[a_k], usable[b_k]
            cA, cB = cue[ia], cue[ib]
            nA = names[a_k - 1] if a_k - 1 < len(names) else str(a_k)
            nB = names[b_k - 1] if b_k - 1 < len(names) else str(b_k)
            pkA, seA = peak_se(X, cA, fs)
            pkB, seB = peak_se(X, cB, fs)
            if not (np.isfinite(pkA) and np.isfinite(pkB)):
                continue
            snrA, snrB = pkA / max(seA, 1e-12), pkB / max(seB, 1e-12)

            # 观测
            fa = fit_fixed_point(X, segs_for(cA, len(X), fs))
            fb = fit_fixed_point(X, segs_for(cB, len(X), fs))
            if fa is None or fb is None:
                continue
            D_obs = float(np.linalg.norm(fa[2] - fb[2]) / max(spread, 1e-12))

            # 噪声地板：同种刺激奇偶分半
            floors = []
            for idx in (ia, ib):
                ev, od = idx[0::2], idx[1::2]
                if len(ev) < 4 or len(od) < 4:
                    continue
                f1 = fit_fixed_point(X, segs_for(cue[ev], len(X), fs))
                f2 = fit_fixed_point(X, segs_for(cue[od], len(X), fs))
                if f1 is not None and f2 is not None:
                    floors.append(float(np.linalg.norm(f1[2] - f2[2]) / max(spread, 1e-12)))
            D_floor = float(np.median(floors)) if floors else np.nan

            # 零模型：cue 时刻环形平移 ≥5 s
            nulls = []
            min_shift = int(5 * fs)
            for _ in range(N_SHIFT):
                sh = int(rng.integers(min_shift, max(min_shift + 1, len(X) - min_shift)))
                cAs = np.sort((cA + sh) % len(X))
                cBs = np.sort((cB + sh) % len(X))
                f1 = fit_fixed_point(X, segs_for(cAs, len(X), fs))
                f2 = fit_fixed_point(X, segs_for(cBs, len(X), fs))
                if f1 is not None and f2 is not None:
                    nulls.append(float(np.linalg.norm(f1[2] - f2[2]) / max(spread, 1e-12)))
            D_null = float(np.median(nulls)) if nulls else np.nan

            ratio = D_obs / max(D_floor, 1e-12) if np.isfinite(D_floor) else np.nan
            rows.append(dict(mouse=b["mouse"], design=b["design"],
                             pair=f"{nA} vs {nB}", stimA=nA, stimB=nB,
                             nA=len(cA), nB=len(cB),
                             D_obs=D_obs, D_floor=D_floor, D_null=D_null,
                             ratio=ratio, peakA=pkA, peakB=pkB,
                             snrA=float(snrA), snrB=float(snrB),
                             spread=spread, n_dim=int(X.shape[1])))
            ok = "✓" if (np.isfinite(D_floor) and D_obs <= max(D_floor * 2, 0.1)
                         and np.isfinite(D_null) and D_obs < D_null) else " "
            print(f"{b['mouse']:<9s}{b['design']:<7s}{nA+' vs '+nB:<22s}"
                  f"{D_floor:8.3f}{D_obs:8.3f}{D_null:8.3f}{ratio:10.2f}"
                  f"{snrA:9.1f}{snrB:9.1f} {ok}")

    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(rows, indent=2, ensure_ascii=False))

    if rows:
        print(f"\n=== 汇总（{len(rows)} 个刺激对）===")
        print(f"  D_floor 中位 {np.nanmedian([r['D_floor'] for r in rows]):.3f}")
        print(f"  D_obs   中位 {np.nanmedian([r['D_obs'] for r in rows]):.3f}")
        print(f"  D_null  中位 {np.nanmedian([r['D_null'] for r in rows]):.3f}")
        rr = [r for r in rows if np.isfinite(r["ratio"])]
        print(f"  obs/floor 中位 {np.nanmedian([r['ratio'] for r in rr]):.2f} "
              f"（≤2 视为与地板不可区分）")
        good = [r for r in rows if np.isfinite(r["D_null"]) and r["D_obs"] < r["D_null"]]
        print(f"  D_obs < D_null 的：{len(good)}/{len(rows)}")
        lowsnr = [r for r in rows if min(r["snrA"], r["snrB"]) < 2]
        print(f"  有刺激类型峰/SE<2（功效不足）的：{len(lowsnr)}/{len(rows)}")
    print(f"\n用时 {(time.time()-t0)/60:.1f} min；写出 {OUT}")


if __name__ == "__main__":
    main()

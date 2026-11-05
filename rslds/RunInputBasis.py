"""RunInputBasis.py —— 「第二个体制」是不是只是没建模好的输入非线性？

模型里输入是**线性**进入的：$x_t=A_kx_{t-1}+b_k+B_ku_t$。
所以舔水对动力学的影响只能通过 $u$ 的**线性组合**体现。如果真实的响应是
"舔水起始引发一次短暂的非线性偏转"，线性输入做不出来 —— 这正好可能就是 K=2 赢的原因。

做法：把输入从 3 维扩到 8 维（舔水的时间尺度、起始脉冲、导数、幅度非线性都囊括），
重拟 $K=1,2$，看 $\\Delta K$ 掉不掉。

**判据（事先声明）**
  · $\\Delta K_{\\rm rich} \\to 0$  ⇒ "第二个体制"只是输入非线性没建模好 ⇒ **不存在两个体制**
  · $\\Delta K_{\\rm rich} \\approx \\Delta K_{\\rm orig}$ ⇒ 切换不是输入能解释的 ⇒ 内在动力学证据更强

另外报"回收率" $= ({\\rm ELBO}_{K2}^{\\rm orig}-{\\rm ELBO}_{K1}^{\\rm rich})/
({\\rm ELBO}_{K2}^{\\rm orig}-{\\rm ELBO}_{K1}^{\\rm orig})$：
即"用更丰富的输入能买回多少第二个状态带来的增益"。

⚠ $\\Delta K$ 只能在**同一套输入**内比较（参数个数不同）。跨输入比较看的是符号与回收率。
⚠ ELBO/点 跨 M 只是近似可比（变分族相同、紧度可能略有差异）。

用法：  .venv\\Scripts\\python rslds\\RunInputBasis.py [--only 2] [--iters 300]
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time

import numpy as np

import rslds_data as rd
from RunRSLDS2 import N_OBS, D_LATENT, BOX_SEC, build_inputs, state_metrics
from CheckMinorityState import lick_onsets
import ssm

HERE = os.path.dirname(os.path.abspath(__file__))
FIGDIR = os.path.join(HERE, "results", "fig1")
K_LIST = [1, 2]


def build_inputs_rich(d, fs):
    """3 维原基 + 5 个舔水派生基，全部 z-score。"""
    T = d["X"].shape[0]
    u3 = build_inputs(d, fs)
    lick = u3[:, 1]
    n_fast = max(1, int(round(0.25 * fs)))
    n_slow = max(1, int(round(2.0 * fs)))
    imp = np.zeros(T)
    for e in lick_onsets(d["cd2"], fs):
        e = int(e)
        if 0 <= e < T:
            imp[e] = 1.0
    cols = [
        u3[:, 0],                                   # 回合开始（=cue）1 s 方波
        lick,                                       # 平滑舔水（1 s）
        u3[:, 2],                                   # 给水 1 s 方波
        rd.smooth(imp, n_fast),                     # 舔水起始脉冲（0.25 s）
        np.gradient(lick) * fs,                     # 舔水率
        lick ** 2,                                  # 幅度非线性
        rd.smooth(rd.lick_indicator(d["cd2"]), n_fast),   # 快时间尺度舔水
        rd.smooth(rd.lick_indicator(d["cd2"]), n_slow),   # 慢时间尺度舔水
    ]
    U = np.column_stack(cols).astype(np.float64)
    sd = U.std(axis=0)
    sd[sd < 1e-12] = 1.0
    return (U - U.mean(axis=0)) / sd


def fit(Y, u, K, iters, seed):
    np.random.seed(seed)
    m = ssm.SLDS(N_OBS, K, D_LATENT, M=u.shape[1], transitions="recurrent",
                 dynamics="diagonal_gaussian", emissions="gaussian_orthog",
                 single_subspace=True)
    m.initialize(Y, inputs=u)
    elbos, q = m.fit(Y, inputs=u, method="laplace_em",
                     variational_posterior="structured_meanfield",
                     initialize=False, num_iters=iters, alpha=0.0, verbose=0)
    elbos = np.asarray(elbos, dtype=np.float64)
    x = np.asarray(q.mean_continuous_states[0], dtype=np.float64)
    z = np.asarray(m.most_likely_states(x, Y, input=u))
    return m, elbos, x, z


def baseline(mouse):
    """从既有 D=5 的 npz 重算 K=1/K=2 的 ELBO/点（3 维输入）。"""
    out, ok = {}, True
    for K in K_LIST:
        f = os.path.join(FIGDIR, "fig1_%s_K%d.npz" % (mouse, K))
        if not os.path.exists(f):
            ok = False
            break
        z = np.load(f)
        out[K] = float(z["elbos"][-1]) / z["z"].shape[0]
    return out if ok else None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--iters", type=int, default=300)
    ap.add_argument("--seed", type=int, default=0)
    ap.add_argument("--only", type=int, default=None)
    a = ap.parse_args()
    os.makedirs(FIGDIR, exist_ok=True)

    blocks = [b for b in rd.scan_cohort("ALB", phases=["Transfer"])
              if b["design"] == "LightWater"]
    if a.only:
        blocks = blocks[:a.only]

    print("=== 输入基扩充：3 维 → 8 维（%d 轮，无稳定性约束）===" % a.iters, flush=True)
    rows = []
    for i, b in enumerate(blocks):
        base = baseline(b["mouse"])
        if base is None:
            print("  %-9s 缺 D=5 基线 npz，跳过" % b["mouse"], flush=True)
            continue
        d = rd.load_block(b["path"])
        assert rd.check_orientation(d)
        fs = d["fs"]
        X = d["X"][:, d["cell_ok"] >= 1.0]
        Z = rd.zscore_cols(rd.detrend_bleach(X, fs))
        Y, _ = rd.factor_analysis(Z, N_OBS, seed=a.seed)
        u = build_inputs_rich(d, fs)
        print("\n[%d/%d] %-9s  u 维数 %d" % (i + 1, len(blocks), b["mouse"], u.shape[1]), flush=True)

        ep, info = {}, {}
        for K in K_LIST:
            t0 = time.time()
            m, elbos, x, z = fit(Y, u, K, a.iters, a.seed)
            ep[K] = float(elbos[-1]) / len(z)
            occ, nsw, segs = state_metrics(z, K, fs)
            info[K] = dict(elbo_per_pt=ep[K], occupancy=[float(v) for v in occ],
                           switch_per_min=float(nsw / (len(z) / fs / 60)),
                           dwell_median_s=[float(np.median(v)) if v else np.nan for v in segs])
            np.savez_compressed(
                os.path.join(FIGDIR, "rich_%s_K%d.npz" % (b["mouse"], K)),
                x=x, z=z, As=np.array(m.dynamics.As), bs=np.array(m.dynamics.bs),
                Vs=np.array(m.dynamics.Vs), Rs=np.array(m.transitions.Rs),
                Ws=np.array(m.transitions.Ws), elbos=elbos, fs=fs, u=u)
            print("  %-9s rich K=%d  ELBO/点 %8.3f  %5.0f s" % (b["mouse"], K, ep[K],
                                                               time.time() - t0), flush=True)

        dk_o = base[2] - base[1]
        dk_r = ep[2] - ep[1]
        rec = (base[2] - ep[1]) / dk_o if abs(dk_o) > 1e-9 else np.nan
        print("         ΔK_原输入 %+.3f  →  ΔK_丰富输入 %+.3f   回收率 %.2f" % (dk_o, dk_r, rec),
              flush=True)
        rows.append(dict(mouse=b["mouse"], dK_orig=dk_o, dK_rich=dk_r, recovery=rec,
                         elbo_K1_orig=base[1], elbo_K2_orig=base[2],
                         elbo_K1_rich=ep[1], elbo_K2_rich=ep[2],
                         n_input=int(u.shape[1]), K1=info[1], K2=info[2]))

    sm = os.path.join(FIGDIR, "input_basis.json")
    old = json.load(open(sm, encoding="utf-8")) if os.path.exists(sm) else []
    keys = {r["mouse"] for r in rows}
    allrows = [r for r in old if r["mouse"] not in keys] + rows
    allrows.sort(key=lambda r: r["mouse"])
    blob = json.dumps(allrows, ensure_ascii=False, indent=1)
    with open(sm, "w", encoding="utf-8") as fh:
        fh.write(blob)

    do = np.array([r["dK_orig"] for r in allrows], dtype=float)
    dr = np.array([r["dK_rich"] for r in allrows], dtype=float)
    rc = np.array([r["recovery"] for r in allrows], dtype=float)
    print("\n=== 汇总（%d 只鼠）===" % len(allrows), flush=True)
    print("%-9s %11s %11s %8s" % ("鼠", "ΔK 原输入", "ΔK 丰富输入", "回收率"), flush=True)
    for r in allrows:
        print("%-9s %+11.3f %+11.3f %8.2f"
              % (r["mouse"], r["dK_orig"], r["dK_rich"], r["recovery"]), flush=True)
    print("\nΔK 原输入 ：中位 %+.3f；>0 的 %d/%d" % (np.median(do), int((do > 0).sum()), len(do)), flush=True)
    print("ΔK 丰富输入：中位 %+.3f；>0 的 %d/%d" % (np.median(dr), int((dr > 0).sum()), len(dr)), flush=True)
    print("回收率（丰富输入的 K=1 抵掉了多少 K=2 的增益）：中位 %.2f；>0.8 的 %d/%d"
          % (np.median(rc), int((rc > 0.8).sum()), len(rc)), flush=True)
    if len(do) >= 3:
        from scipy.stats import wilcoxon
        p = float(wilcoxon(do, dr, alternative="greater").pvalue)
        print("单侧「原输入 ΔK 更大」：Wilcoxon p = %.4f" % p, flush=True)
    print("\n判据：ΔK_丰富 → 0 ⇒ 第二个体制只是输入非线性；≈ ΔK_原 ⇒ 内在动力学", flush=True)
    print("DONE", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())

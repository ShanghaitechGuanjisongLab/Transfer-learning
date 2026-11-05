"""RunControl.py —— A/B 门控实验：这些"状态"是真的还是拟合器的性质？

背景（见笔记 (s)(t)）：pilot 得到"秒级驻留、与 cue/给水完全 null、只与舔水极弱关联"。
在投 2.3 h 去做跨鼠分布之前，必须先确定这些数字是**脑的性质**还是**拟合器的性质**。
pilot 的证据偏后者：ELBO 随 K 的增益极弱（+0.08/点）、驻留尺度与 1/f 自相关同量级、
拟合把 |λ| 推向 1+、观测共性只有 0.19–0.26。

**控制 A：多变量相位随机化替代数据**
 对每个频率 f 给**所有通道乘同一个**随机相位 e^{iφ_f}。
 性质：`<Yf_i(f) conj(Yf_j(f))>` 不变 ⇒ **全部自协方差与互协方差精确保留**，
 但相位被打乱 ⇒ 高阶（非高斯/离散状态）结构被破坏。
 这是"是否存在超越平稳高斯过程的离散状态"的**正确零假设**。
 （注意：不能用"各通道独立平移"——那会把互协方差一起毁掉，等于换了一份数据。）

**控制 B：K=1 基线（无切换的线性高斯 LDS）**
 同一份真实数据、同一转移类，只把状态数设为 1。若 K=2 不明显优于 K=1 ⇒ 没有状态。

事先声明的判读规则（写在 RunPlan 里，不看完数据再定）：
 替代数据的驻留/τ/占用率 ≈ 真实  → 状态是伪影 ⇒ 取消扩数据
 替代数据明显更差 且 K=2 明显优于 K=1 → 状态是真的 ⇒ 立刻开 2.3 h
 介于两者之间 → 停下来报告

用法：  .venv\\Scripts\\python rslds\\RunControl.py [--iters 300]
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time

import numpy as np

import rslds_data as rd
from RunRSLDS2 import (  # 复用第二轮里已经验证过的读数函数
    N_OBS, D_LATENT, BOX_SEC, build_inputs, eig_report, state_metrics,
    tau_from_eig, finite,
)

HERE = os.path.dirname(os.path.abspath(__file__))
OUTDIR = os.path.join(HERE, "results")
BLOCK = "ALB_yqn0133_20240517-0835_AudioWater.mat"
DETRENDS = ["原始", "漂白去趋势"]
N_PERM = 500


def phase_randomize(X, rng):
    """多变量相位随机化：每个频率对所有通道施加**同一个**随机相位。

    同一相位 ⇒ 互谱不变 ⇒ 自/互协方差全部精确保留；相位打乱 ⇒ 破坏非高斯状态结构。
    DC 与 Nyquist 必须保持实数，故相位取 0。
    """
    T, N = X.shape
    Yf = np.fft.rfft(np.asarray(X, dtype=np.float64), axis=0)     # (F, N)
    phi = rng.uniform(0.0, 2 * np.pi, size=Yf.shape[0])
    phi[0] = 0.0
    if T % 2 == 0:
        phi[-1] = 0.0
    Ys = np.fft.irfft(Yf * np.exp(1j * phi)[:, None], n=T, axis=0)
    return Ys.astype(np.float32)


def prepare(X, detrend, fs, seed, surrogate):
    Xd = X if detrend == "原始" else rd.detrend_bleach(X, fs)
    Z = rd.zscore_cols(Xd)
    if surrogate:
        Z = phase_randomize(Z, np.random.default_rng(seed + 991))
    Y, fa = rd.factor_analysis(Z, N_OBS, seed=seed)
    return Y, float(np.mean(1 - fa.noise_variance_))


def fit(Y, u, K, iters, seed, transitions):
    import ssm
    np.random.seed(seed)
    m = ssm.SLDS(N_OBS, K, D_LATENT, M=u.shape[1], transitions=transitions,
                 dynamics="diagonal_gaussian", emissions="gaussian_orthog",
                 single_subspace=True)
    t0 = time.time()
    m.initialize(Y, inputs=u)
    t_init = time.time() - t0
    t0 = time.time()
    elbos, q = m.fit(Y, inputs=u, method="laplace_em",
                     variational_posterior="structured_meanfield",
                     initialize=False, num_iters=iters, alpha=0.0, verbose=0)
    t_fit = time.time() - t0
    elbos = np.asarray(elbos, dtype=np.float64)
    z = np.asarray(m.most_likely_states(q.mean_continuous_states[0], Y, input=u))
    return m, elbos, z, t_init, t_fit


def lick_test(z, lick, K, rng):
    """状态内舔水率的极差 + 循环平移 null。"""
    rate = np.array([lick[z == k].mean() if (z == k).any() else np.nan for k in range(K)])
    obs = float(np.nanmax(rate) - np.nanmin(rate))
    null = np.empty(N_PERM)
    T = z.size
    for i in range(N_PERM):
        lk = np.roll(lick, int(rng.integers(0, T)))
        r2 = np.array([lk[z == k].mean() if (z == k).any() else np.nan for k in range(K)])
        null[i] = np.nanmax(r2) - np.nanmin(r2)
    return rate, obs, float((1 + (null >= obs).sum()) / (N_PERM + 1)), float(np.percentile(null, 95))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--iters", type=int, default=300)
    ap.add_argument("--seed", type=int, default=0)
    ap.add_argument("--only", nargs="*", default=None,
                    help="只跑指定的 tag（如 A_surK1），结果合并进 control_summary.json")
    ap.add_argument("--report", action="store_true",
                    help="不拟合，只用已存的 control_summary.json 出对照表")
    a = ap.parse_args()
    rng = np.random.default_rng(a.seed)

    # (tag, 显示名, 是否替代数据, K)
    configs = [("A_surK1", "A 替代 K=1", True, 1),
               ("A_surK2", "A 替代 K=2", True, 2),
               ("B_realK1", "B 真实 K=1", False, 1)]
    configs = [c for c in configs if a.only is None or c[0] in a.only]
    if a.report:
        configs = []

    d = rd.load_block(os.path.join(rd.DATA_ROOT, "ALB", BLOCK))
    assert rd.check_orientation(d)
    fs = d["fs"]
    u = build_inputs(d, fs)
    X = d["X"][:, d["cell_ok"] >= 1.0]
    lick = rd.smooth(rd.lick_indicator(d["cd2"]), max(1, int(round(BOX_SEC * fs))))

    print("=== A/B 门控实验（%d 轮）===" % a.iters, flush=True)
    print("block %s / %s / %s ；T=%d ；细胞 %d" % (d["mouse"], d["phase"], d["design"],
                                                 X.shape[0], X.shape[1]), flush=True)
    print("A = 多变量相位随机化替代数据（保留全部自/互协方差）", flush=True)
    print("B = K=1 基线（同数据、同转移类，只把状态数设为 1）\n", flush=True)

    rows = []
    for tag, label, surrogate, K in configs:
        for det in DETRENDS:
            Y, com = prepare(X, det, fs, a.seed, surrogate)
            m, elbos, z, t_init, t_fit = fit(Y, u, K, a.iters, a.seed, "recurrent")
            mag = eig_report(m.dynamics.As)
            tau = tau_from_eig(mag, fs)
            occ, nsw, segs = state_metrics(z, K, fs)
            rate, spread, p_lick, n95 = lick_test(z, lick, K, rng)
            elbo_pt = float(elbos[-1]) / len(z)
            nt = int(min(20, max(1, elbos.size - 1)))
            conv = float(np.nanmax(np.abs(elbos[-nt:] - elbos[-nt - 1:-1])
                                  / np.maximum(np.abs(elbos[-nt - 1:-1]), 1e-9)))

            print("── %s / %s ──  init %.1f s + fit %.1f s  末 %d 轮变化 %.1e"
                  % (label, det, t_init, t_fit, nt, conv), flush=True)
            print("   ELBO/点 %8.3f ；共性 %.3f ；占用率 %s"
                  % (elbo_pt, com, np.round(occ, 3).tolist()), flush=True)
            print("   切换 %5d（%.1f/min）；驻留中位 %s s"
                  % (nsw, nsw / (len(z) / fs / 60),
                     [round(float(np.median(v)), 2) if v else None for v in segs]), flush=True)
            print("   |λ|≥1：%d / %d ；τ(有限) %s"
                  % (int((mag >= 1).sum()), mag.size,
                     np.round(np.sort(tau[np.isfinite(tau)]), 1).tolist()), flush=True)
            print("   状态内舔水率 %s ；极差 %.3f vs null95 %.3f → p=%.3f\n"
                  % (np.round(rate, 3).tolist(), spread, n95, p_lick), flush=True)

            rows.append(dict(tag=tag, label=label, detrend=det, K=K, surrogate=surrogate,
                             elbo_per_pt=elbo_pt, communality=com,
                             occupancy=[float(v) for v in occ],
                             n_switch=nsw, switch_per_min=nsw / (len(z) / fs / 60),
                             dwell_median_s=[float(np.median(v)) if v else np.nan for v in segs],
                             n_eig_ge1=int((mag >= 1).sum()),
                             tau_finite_s=[float(v) for v in np.sort(tau[np.isfinite(tau)])],
                             lick_rate_in_state=[float(v) for v in rate],
                             lick_spread=spread, lick_p=p_lick, t_fit_sec=t_fit))

    # 合并写入（便于补跑单个配置后累积）
    #   ⚠ 早期版本的行没有 `tag` 字段，这里按 (surrogate, K) 反推，避免 KeyError
    smfile = os.path.join(OUTDIR, "control_summary.json")
    old = json.load(open(smfile, encoding="utf-8")) if os.path.exists(smfile) else []

    def tagof(r):
        return r.get("tag") or ("A_sur" if r["surrogate"] else "B_real") + "K%d" % r["K"]

    newkeys = {(n["tag"], n["detrend"]) for n in rows}
    keep = [r for r in old if (tagof(r), r["detrend"]) not in newkeys]
    for r in old:
        r["tag"] = tagof(r)
    allrows = keep + rows
    allrows.sort(key=lambda r: (r["surrogate"], r["K"], r["detrend"]))
    with open(smfile, "w", encoding="utf-8") as fh:
        json.dump(finite(allrows), fh, ensure_ascii=False, indent=1)
    print("本次跑了 %d 个；累计共 %d 个" % (len(rows), len(allrows)), flush=True)
    if not allrows:
        return 0

    # ---- 并排表 + 交互项 ----
    real = json.load(open(os.path.join(OUTDIR, "pilot2_summary.json"), encoding="utf-8"))
    have = {r["tag"] for r in allrows}
    need = {"A_surK1", "A_surK2", "B_realK1"}

    def cur(tag, det):
        if tag not in have:
            return None
        return [r for r in allrows if r["tag"] == tag and r["detrend"] == det][0]

    def real_k(K, det):
        return [r for r in real if r["K"] == K and r["detrend"] == det][0]

    def med(r):
        return round(float(np.nanmedian(r["dwell_median_s"])), 2) if r else None

    print("\n=== 并排表 ===", flush=True)
    print("%-14s %-11s %9s %9s %9s %8s" % ("来源", "去趋势", "ELBO/点", "切换/min", "驻留中位s", "|λ|≥1"),
          flush=True)
    for det in DETRENDS:
        r2, r3 = real_k(2, det), real_k(3, det)
        print("%-14s %-11s %9.3f %9.1f %9.2f %8s"
              % ("真实 K=2", det, r2["elbo_per_pt"], r2["switch_per_min"], med(r2), "1–2/10"), flush=True)
        print("%-14s %-11s %9.3f %9.1f %9.2f %8s"
              % ("真实 K=3", det, r3["elbo_per_pt"], r3["switch_per_min"], med(r3), "3–4/15"), flush=True)
        for tag, nm in [("B_realK1", "真实 K=1"), ("A_surK1", "替代 K=1"), ("A_surK2", "替代 K=2")]:
            c = cur(tag, det)
            if c is None:
                continue
            print("%-14s %-11s %9.3f %9.1f %9.2f %8s"
                  % (nm, det, c["elbo_per_pt"], c["switch_per_min"], med(c),
                     "%d/%d" % (c["n_eig_ge1"], c["n_eig_ge1"] + len(c["tau_finite_s"]))), flush=True)
        print("", flush=True)

    print("=== ⭐ 交互项：加状态带来的增益，在两种数据上差多少 ===", flush=True)
    for det in DETRENDS:
        r2 = real_k(2, det)
        b1, s1, s2 = cur("B_realK1", det), cur("A_surK1", det), cur("A_surK2", det)
        if b1 is None or s1 is None or s2 is None:
            print("  %s：（还缺格子，先跑 --only A_surK1）" % det, flush=True)
            continue
        dk_real = r2["elbo_per_pt"] - b1["elbo_per_pt"]
        dk_sur = s2["elbo_per_pt"] - s1["elbo_per_pt"]
        print("  %s：真实 K=2 − 真实 K=1 = %+.3f ；替代 K=2 − 替代 K=1 = %+.3f ；**交互 = %+.3f**"
              % (det, dk_real, dk_sur, dk_real - dk_sur), flush=True)
        print("      驻留：真实 K=2 %.2f s vs 替代 K=2 %.2f s（比 %.2f）"
              % (med(r2), med(s2), med(s2) / med(r2)), flush=True)
    print("\n  判据：交互 ≈ 0 或 <0 ⇒ 「加状态」的增益是参数量的代价，不是真结构 ⇒ 伪影", flush=True)
    print("\nDONE", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())

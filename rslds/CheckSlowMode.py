"""CheckSlowMode.py —— 近单位根到底是「神经积分器」还是「没去干净的全局漂移」？

背景：无约束拟合下 11/11 只鼠都有 |λ|→1 的慢根，`det(I−A)→1e−12`。
这有两种解释：
  ① **内部慢动力**（积分器 / 线吸引子）：慢模式是状态特异的神经活动方向；
  ② **残留漂移**（漂白残差、arousal、全局共模）：慢模式就是把所有细胞一起抬起来的那个东西。

判别办法：拿慢模式的时间过程 $s(t)$ 与**全细胞平均** $m(t)$ 对比。

  $Z$（细胞×时间，已 z-score）经 FA 降到 15 维：$Z_t \\approx Y_t L^{\\top}$，
  于是全细胞平均 $m(t)=\\frac1n\\sum_i Z_i(t)=Y_t\\cdot g$，其中 $g=L^{\\top}\\mathbf 1/n$。

  $s(t)$ 用**左**特征向量的对偶方向在潜空间上投影得到（$\\lambda$ 为复根时取 2 维不变子空间）。

  判据（事先声明）：
    · $|\\text{corr}(s,m)| \\to 1$  ⇒ 慢模式**就是**全局共模 ⇒ 解释 ②，我们该把它当噪声去掉
    · $|\\text{corr}(s,m)| \\approx$ 随机方向的零分布 ⇒ 解释 ①，慢模式是结构化的内部动力

另外报告：
  · 慢模式的 $\\tau$（离散 $|\\lambda|=e^{-1/(f_s\\tau)}$）
  · 慢模式与舔水的相关（漂移应当与行为无关）
  · 慢模式中被线性时间趋势解释的比例（漂移应当很高）
  · 细胞空间上慢模式载荷的集中度（PR、前 5% 细胞占的能量）

用法：  .venv\\Scripts\\python rslds\\CheckSlowMode.py [--only 2]
"""

from __future__ import annotations

import argparse
import json
import os
import sys

import numpy as np

import rslds_data as rd
from RunRSLDS2 import N_OBS, BOX_SEC, build_inputs

HERE = os.path.dirname(os.path.abspath(__file__))
FIGDIR = os.path.join(HERE, "results", "fig1")
K_LIST = [1, 2]
N_NULL = 2000


def slow_subspace(A):
    """返回 (基 V(5×m), λ, τ) —— A 里 |λ| 最大的那个不变子空间。"""
    D = A.shape[0]
    ev, Vc = np.linalg.eig(A)
    i = int(np.argmax(np.abs(ev)))
    lam = ev[i]
    if abs(lam.imag) < 1e-8:
        V = Vc[:, [i]].real
    else:
        V = np.column_stack([Vc[:, i].real, Vc[:, i].imag])
    V = np.linalg.qr(V)[0]
    return V, lam


def corr_mat(Xc, mc, W):
    """Xc 已中心化；W(5×M) 的每列是一个方向。返回各方向得分与 mc 的相关。"""
    num = W.T @ (Xc.T @ mc)
    den = np.sqrt(np.sum((Xc @ W) ** 2, axis=0)) * np.linalg.norm(mc) + 1e-30
    return num / den


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--seed", type=int, default=0)
    ap.add_argument("--only", type=int, default=None)
    a = ap.parse_args()

    blocks = [b for b in rd.scan_cohort("ALB", phases=["Transfer"])
              if b["design"] == "LightWater"]
    if a.only:
        blocks = blocks[:a.only]

    print("=== 慢模式 vs 全局共模（|corr| → 1 = 残留漂移；≈ 零分布 = 内部慢动力）===",
          flush=True)
    print("%-9s %2s %2s %8s %9s %8s %8s %9s %7s %7s %6s %6s %s"
          % ("鼠", "K", "状", "|λ|", "τ(s)", "|c|慢-全", "|c|零中位", "百分位",
             "|c|舔", "趋势R2", "低频占比", "g在内", "建模的Y维"), flush=True)
    rows = []
    dimmice = []
    rng = np.random.default_rng(a.seed)
    for i, b in enumerate(blocks):
        d = rd.load_block(b["path"])
        assert rd.check_orientation(d)
        fs = d["fs"]
        X = d["X"][:, d["cell_ok"] >= 1.0]
        Z = rd.zscore_cols(rd.detrend_bleach(X, fs))
        Y, fa = rd.factor_analysis(Z, N_OBS, seed=a.seed)
        L = fa.components_.T                                  # 细胞×15
        nCell = L.shape[0]
        g = L.sum(axis=0) / nCell                             # 15，全细胞平均的权重
        lick = rd.smooth(rd.lick_indicator(d["cd2"]), max(1, int(round(BOX_SEC * fs))))
        lick_c = lick - lick.mean()
        t = np.arange(Y.shape[0], dtype=np.float64)
        t_c = t - t.mean()
        Wnull = rng.standard_normal((5, N_NULL))
        Wnull /= np.linalg.norm(Wnull, axis=0, keepdims=True)
        dimsets = {}

        for K in K_LIST:
            f = os.path.join(FIGDIR, "fig1_%s_K%d.npz" % (b["mouse"], K))
            if not os.path.exists(f):
                continue
            z = np.load(f)
            x, As = z["x"], z["As"]
            T = x.shape[0]
            assert g.shape[0] == N_OBS
            Y = Y[:T] if Y.shape[0] > T else Y
            B = np.column_stack([np.ones(T), x])
            coef = np.linalg.lstsq(B, Y, rcond=None)[0]
            C = coef[1:].T                                    # 15×5
            per = 1 - ((Y - B @ coef) ** 2).sum(0) / ((Y - Y.mean(0)) ** 2).sum(0)
            dims = np.where(per > 0.9)[0]
            assert len(dims) == C.shape[1], "发射矩阵恢复失败：解释维度 %d" % len(dims)
            assert per[dims].mean() > 0.95, "发射矩阵恢复失败：R²=%.3f" % per[dims].mean()
            dimsets[K] = set(dims.tolist())
            Q = np.linalg.qr(C)[0]
            g_in = float(np.linalg.norm(Q.T @ g) / (np.linalg.norm(g) + 1e-30))
            m_sub = Y @ (Q @ (Q.T @ g))                       # 模型能看到的全局共模
            xc = x - x.mean(axis=0)
            mcx = m_sub - m_sub.mean()
            cn = corr_mat(xc, mcx, Wnull)
            for k in range(As.shape[0]):
                V, lam = slow_subspace(As[k])
                rho = float(abs(lam))
                tau = float(-1.0 / (fs * np.log(rho))) if 0 < rho < 1 else np.inf
                s = xc @ V
                cs = np.array([abs(float(s[:, j] @ mcx /
                                       (np.linalg.norm(s[:, j]) * np.linalg.norm(mcx) + 1e-30)))
                               for j in range(V.shape[1])])
                c_slow = float(cs.max())
                c_null = np.abs(cn)
                pct = float((c_null < c_slow).mean())
                # 舔水相关（零延迟，已足够判断"是否与行为无关"）
                cl = np.array([abs(float(s[:, j] @ lick_c /
                                        (np.linalg.norm(s[:, j]) * np.linalg.norm(lick_c) + 1e-30)))
                               for j in range(V.shape[1])])
                # 线性时间趋势能解释多少
                tr2 = np.array([np.corrcoef(t_c, s[:, j])[0, 1] ** 2 for j in range(V.shape[1])])
                # 慢模式功率里有多少集中在 f < 0.005 Hz（周期 > 200 s）——漂移的招牌
                spec = np.abs(np.fft.rfft(s - s.mean(axis=0), axis=0)) ** 2
                fr = np.fft.rfftfreq(T, 1.0 / fs)
                lowf = (spec[fr < 0.005].sum(axis=0) / (spec.sum(axis=0) + 1e-30))
                # 细胞空间载荷集中度
                u = L @ (C @ V)                               # nCell×m
                amp = np.sqrt((u ** 2).sum(axis=1))
                amp = amp / (amp.sum() + 1e-30)
                pr = float(1.0 / (nCell * (amp ** 2).sum()))   # 1=均匀，→0=稀疏
                print("%-9s %2d %2d %8.4f %9.1f %+8.3f %8.3f %9.3f %7.3f %7.3f %6.3f %6.2f %s"
                      % (b["mouse"], K, k, rho, tau, c_slow, np.median(c_null), pct,
                         float(cl.max()), float(tr2.max()), float(lowf.max()), g_in,
                         str(dims.tolist())), flush=True)
                rows.append(dict(mouse=b["mouse"], K=K, state=k, seed=a.seed,
                                 lam_abs=rho, lam_imag=float(abs(lam.imag)),
                                 tau_s=tau, corr_global=c_slow,
                                 corr_global_null_median=float(np.median(c_null)),
                                 corr_global_null_p95=float(np.quantile(c_null, 0.95)),
                                 pct_vs_null=pct, corr_lick=float(cl.max()),
                                 trend_r2=float(tr2.max()), lowf_frac=float(lowf.max()),
                                 g_in_subspace=g_in, dims=dims.tolist(),
                                 pr_cell=pr))
        if 1 in dimsets and 2 in dimsets:
            ov = len(dimsets[1] & dimsets[2])
            print("        → K1/K2 建模维度重叠 %d/5" % ov, flush=True)
            dimmice.append(dict(mouse=b["mouse"], overlap=ov,
                                dims_K1=sorted(dimsets[1]), dims_K2=sorted(dimsets[2])))

    sm = os.path.join(FIGDIR, "slow_mode.json")
    old = json.load(open(sm, encoding="utf-8")) if os.path.exists(sm) else []
    keys = {(r["mouse"], r["K"]) for r in rows}
    allrows = [r for r in old if (r["mouse"], r["K"]) not in keys] + rows
    allrows.sort(key=lambda r: (r["mouse"], r["K"], r["state"]))
    with open(sm, "w", encoding="utf-8") as fh:
        json.dump(allrows, fh, ensure_ascii=False, indent=1)

    cg = np.array([r["corr_global"] for r in allrows])
    pv = np.array([r["pct_vs_null"] for r in allrows])
    tk = np.array([r["corr_lick"] for r in allrows])
    tr = np.array([r["trend_r2"] for r in allrows])
    lf = np.array([r["lowf_frac"] for r in allrows])
    gi = np.array([r["g_in_subspace"] for r in allrows])
    print("\n共 %d 个状态" % len(allrows), flush=True)
    print("|corr(慢, 全细胞平均)|：中位 %.3f（范围 %.3f–%.3f）"
          % (np.median(cg), cg.min(), cg.max()), flush=True)
    print("  在随机方向零分布里的百分位：中位 %.3f；>0.95 的 %d/%d"
          % (np.median(pv), int((pv > 0.95).sum()), len(pv)), flush=True)
    print("|corr(慢, 舔水)|：中位 %.3f" % np.median(tk), flush=True)
    print("线性时间趋势 R²：中位 %.3f" % np.median(tr), flush=True)
    print("慢模式低频功率占比 (f<0.005 Hz)：中位 %.3f" % np.median(lf), flush=True)
    print("全局共模落在模型子空间里的比例：中位 %.2f（只有这部分模型看得到）"
          % np.median(gi), flush=True)
    if dimmice:
        ov = np.array([r["overlap"] for r in dimmice])
        print("K1 与 K2 建模的 5 个 Y 维重叠：中位 %d/5；完全相同 %d/%d"
              % (int(np.median(ov)), int((ov == 5).sum()), len(ov)), flush=True)
        with open(os.path.join(FIGDIR, "slow_mode_dims.json"), "w", encoding="utf-8") as fh:
            json.dump(dimmice, fh, ensure_ascii=False, indent=1)
    print("\n判据：|corr|→1 且百分位>0.95 ⇒ 残留漂移；百分位≈0.5 ⇒ 内部慢动力", flush=True)
    print("DONE", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())

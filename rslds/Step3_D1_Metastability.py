"""Step3_D1_Metastability.py —— D1 可行性与实测：2 维占据是否**双峰**

为什么用 GMM 而不是「偏离高斯」
  真实钙数据天然非高斯（爆发、偏斜），KS 检验会把任何数据都判成"显著"，没有信息量
  （实测首次尝试：KS_D 0.19–0.54，全部 p=0.005，但 PC1 只有一个峰 → 是重尾不是双峰）。
  因此改为直接检验**双峰**：
     · 拟合 1 分量 vs 2 分量高斯混合，ΔBIC = BIC(1) − BIC(2)
     · 用**同 n、同协方差的高斯重采样**校准 ΔBIC 的零分布（消除"n 大必然选 2 分量"的偏倚）
     · 同时要求两分量**分离度**（均值差 / 合并 SD）与**较小权重**达到实际意义门槛

对照组
  P-OU  线性 OU（= 任何线性平稳动力学）      → 期望单峰（p 不显著）
  P-TG  电报型双态（OU 切换，τ_state=20 s）   → 期望双峰（验证功效）
"""
from __future__ import annotations

import json
import os

import numpy as np
from sklearn.mixture import GaussianMixture

import attractor_core as AC

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "results", "_step3_d1.json")
T_MAX = 8000
N_BOOT = 40
D = 2
SEP_THR = 2.0        # 两分量分离度门槛（合并 SD 单位）
W_THR = 0.15         # 较小分量权重门槛


def gmm_test(X, n_boot=N_BOOT, seed=0):
    rng = np.random.default_rng(seed)
    g1 = GaussianMixture(1, covariance_type="full", random_state=0, n_init=2).fit(X)
    g2 = GaussianMixture(2, covariance_type="full", random_state=0, n_init=8).fit(X)
    dbic = float(g1.bic(X) - g2.bic(X))

    v = g2.means_[1] - g2.means_[0]
    nv = float(np.linalg.norm(v))
    if nv > 0:
        u = v / nv
        s1 = float(np.sqrt(u @ g2.covariances_[0] @ u))
        s2 = float(np.sqrt(u @ g2.covariances_[1] @ u))
        sep = nv / max(0.5 * (s1 + s2), 1e-12)
    else:
        sep = 0.0
    w = float(g2.weights_.min())

    n = len(X)
    null = np.empty(n_boot)
    for b in range(n_boot):
        Xs, _ = g1.sample(n)
        a1 = GaussianMixture(1, covariance_type="full", random_state=b, n_init=2).fit(Xs)
        a2 = GaussianMixture(2, covariance_type="full", random_state=b, n_init=8).fit(Xs)
        null[b] = a1.bic(Xs) - a2.bic(Xs)
    p = float((1 + (null >= dbic).sum()) / (n_boot + 1))
    return dict(dbic=dbic, p=p, sep=float(sep), w_min=w,
                dbic_null95=float(np.percentile(null, 95)), n=int(n),
                passed=bool(p < 0.05 and sep >= SEP_THR and w >= W_THR))


# ------------------------- 合成生成器 -------------------------
def _to_pc(z, rng):
    import Step1_Calibration as CAL
    Y = CAL._plant(z, rng)
    Zs = AC.zscore_robust(AC.VARIANTS["P1"](Y, 8.0))
    X, evr = AC.pca_reduce(Zs, D)
    return X, float(evr.sum())


def gen_ou(T=4000, fs=8.0, sig=0.5, seed=0):
    rng = np.random.default_rng(seed)
    dt = 1.0 / fs
    K = np.array([1 / 10.0, 1 / 40.0])
    z = np.zeros((T, 2))
    for t in range(1, T):
        z[t] = z[t - 1] - dt * K * z[t - 1] + np.sqrt(dt) * sig * rng.standard_normal(2)
    return z, rng


def gen_telegraph(T=4500, fs=8.0, R=1.2, tau_state=20.0, tau_ou=3.0,
                  sig=0.45, seed=0):
    rng = np.random.default_rng(seed)
    dt = 1.0 / fs
    p_sw = 1 - np.exp(-dt / tau_state)
    s = 1.0
    z = np.zeros((T, 2))
    z[0] = [R, 0.0]
    for t in range(1, T):
        if rng.random() < p_sw:
            s = -s
        z[t, 0] = z[t - 1, 0] + dt * (-(z[t - 1, 0] - s * R) / tau_ou) + sig * np.sqrt(dt) * rng.standard_normal()
        z[t, 1] = z[t - 1, 1] + dt * (-z[t - 1, 1] / tau_ou) + sig * np.sqrt(dt) * rng.standard_normal()
    return z, rng


def main():
    rec = []
    print("=== 合成对照 ===")
    for name, gen in [("P-OU 线性", gen_ou), ("P-TG 双态", gen_telegraph)]:
        z, rng = gen()
        X, evr = _to_pc(z, rng)
        s = gmm_test(X)
        s.update(cond=name, evr=evr)
        rec.append(s)
        print(f"  {name:<10s} ΔBIC={s['dbic']:8.1f} (null95={s['dbic_null95']:6.1f}) "
              f"p={s['p']:.3f} sep={s['sep']:.2f} w_min={s['w_min']:.2f} "
              f"evr={evr:.2f} → {'双峰' if s['passed'] else '单峰'}")

    print("\n=== 真实数据：ALB · Learned 场 · P1 · d=2 ===")
    from rslds_data import load_block, scan_cohort
    ms = scan_cohort("ALB")
    by = {}
    for m in ms:
        by.setdefault(m["mouse"], {}).setdefault(m["phase"], []).append(m)

    print(f"  {'鼠':<9s}{'T':>6s}{'N':>5s}{'evr':>6s}{'ΔBIC':>9s}{'null95':>9s}"
          f"{'p':>7s}{'sep':>6s}{'w_min':>7s}  判定")
    npass = 0
    for mouse in sorted(by):
        if "Learned" not in by[mouse]:
            continue
        d = load_block(by[mouse]["Learned"][0]["path"])
        Y = AC.dff(d["X"][:T_MAX], d["fs"])
        Y = np.nan_to_num(Y, nan=0.0, posinf=0.0, neginf=0.0)
        Y = Y[:, np.std(Y, axis=0) > 1e-9]
        Zs = AC.zscore_robust(AC.VARIANTS["P1"](Y, d["fs"]))
        X, evr = AC.pca_reduce(Zs, D)
        s = gmm_test(X)
        s.update(cond="real", mouse=mouse, evr=float(evr.sum()),
                 n_cell=int(Y.shape[1]), T=int(Y.shape[0]))
        rec.append(s)
        npass += int(s["passed"])
        print(f"  {mouse:<9s}{s['n']:6d}{s['n_cell']:5d}{s['evr']:6.2f}"
              f"{s['dbic']:9.1f}{s['dbic_null95']:9.1f}{s['p']:7.3f}"
              f"{s['sep']:6.2f}{s['w_min']:7.2f}  "
              f"{'✅双峰' if s['passed'] else '❌单峰'}")

    print(f"\n通过（p<0.05 且 sep≥{SEP_THR} 且 w≥{W_THR}）：{npass}/11")
    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(rec, indent=2, ensure_ascii=False))
    print(f"写出 {OUT}")


if __name__ == "__main__":
    main()

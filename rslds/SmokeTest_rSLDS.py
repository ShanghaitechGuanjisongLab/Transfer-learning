"""SmokeTest_rSLDS.py —— 碰真数据之前必须做完的三件冒烟测试

① 合成数据回归（标定）
   造一个已知 K 的 rSLDS（沿用仓库 examples/rslds.py 的 NASCAR 参数），再从数据拟合回去，
   看状态序列能否恢复。**如果连自己造的数据都拟合不回来，说明配置或代码有问题**，
   而不是"数据里没有动力学"。
② K=1 退化检查
   K=1 时 rSLDS 应退化成一个普通线性高斯 LDS：唯一状态被 100% 占据、转移数为 0。
③ 真实规模计时
   本机无 GPU、串行，真数据每块约 T≈11000、D_obs≈10。先量一次每轮迭代的秒数，
   才知道 Stage 1 试跑要跑多少轮、Stage 2 全场要多久。

用法：  .venv\\Scripts\\python rslds\\SmokeTest_rSLDS.py
"""

from __future__ import annotations

import sys
import time

import numpy as np
import autograd.numpy as anp
from scipy.optimize import linear_sum_assignment

import ssm
from ssm.util import random_rotation

RNG = np.random.RandomState(0)


def make_nascar_model(D_obs=10, K=4, D_latent=2, scale=1.0):
    """仓库 examples/rslds.py 里的 NASCAR 模型：4 个状态分居 2D 潜空间四象限。"""
    As = [random_rotation(D_latent, np.pi / 24.0), random_rotation(D_latent, np.pi / 48.0)]
    centers = [np.array([+2.0, 0.0]), np.array([-2.0, 0.0])]
    bs = [-(A - np.eye(D_latent)).dot(c) for A, c in zip(As, centers)]
    As.append(np.eye(D_latent)); bs.append(np.array([+0.1, 0.0]))
    As.append(np.eye(D_latent)); bs.append(np.array([-0.25, 0.0]))

    w1, b1 = np.array([+1.0, 0.0]), np.array([-2.0])
    w2, b2 = np.array([-1.0, 0.0]), np.array([-2.0])
    w3, b3 = np.array([0.0, +1.0]), np.array([0.0])
    w4, b4 = np.array([0.0, -1.0]), np.array([0.0])
    Rs = np.row_stack((100 * w1, 100 * w2, 10 * w3, 10 * w4))
    r = np.concatenate((100 * b1, 100 * b2, 10 * b3, 10 * b4))

    m = ssm.SLDS(D_obs, K, D_latent, transitions="recurrent_only",
                 dynamics="diagonal_gaussian", emissions="gaussian_orthog",
                 single_subspace=True)
    m.dynamics.mu_init = np.tile(np.array([[0.0, 1.0]]), (K, 1))
    m.dynamics.sigmasq_init = 1e-4 * np.ones((K, D_latent))
    m.dynamics.As = np.array(As)
    m.dynamics.bs = np.array(bs)
    m.dynamics.sigmasq = 1e-4 * np.ones((K, D_latent))
    m.transitions.Rs = Rs
    m.transitions.r = r
    m.emissions.inv_etas = np.log(1e-2) * np.ones((1, D_obs))
    return m, np.array(As), np.array(bs)


def make_random_rslds(D_obs=10, K=3, D_latent=5, seed=0, scale=0.95):
    """任意维数的 rSLDS：稳定动力学（正交阵乘 scale，谱半径 = scale < 1）。

    NASCAR 那个模型写死了 2D，@真实规模计时@ 需要 D_latent=5，故另写一个通用的。
    """
    rng = np.random.RandomState(seed)
    As = np.array([scale * np.linalg.qr(rng.randn(D_latent, D_latent))[0] for _ in range(K)])
    bs = rng.randn(K, D_latent) * 0.5
    Rs = rng.randn(K, D_latent) * 3.0
    m = ssm.SLDS(D_obs, K, D_latent, transitions="recurrent_only",
                 dynamics="diagonal_gaussian", emissions="gaussian_orthog",
                 single_subspace=True)
    m.dynamics.As = As
    m.dynamics.bs = bs
    m.dynamics.mu_init = np.zeros((K, D_latent))
    m.dynamics.sigmasq_init = 0.1 * np.ones((K, D_latent))
    m.dynamics.sigmasq = 0.1 * np.ones((K, D_latent))
    m.transitions.Rs = Rs
    # rSLDS 的可辨识性要求转移的偏置 r 固定为 0（否则 Rs 与 r 可以整体平移抵消）
    m.transitions.r = np.zeros(K)
    m.emissions.inv_etas = np.log(0.5) * np.ones((1, D_obs))
    return m


def fit_rslds(y, K, D_latent, num_iters, seed=0):
    """标准 rSLDS 拟合：recurrent_only 转移 + Laplace-EM。verbose=0 关掉 tqdm。"""
    np.random.seed(seed)
    m = ssm.SLDS(y.shape[1], K, D_latent, transitions="recurrent_only",
                 dynamics="diagonal_gaussian", emissions="gaussian_orthog",
                 single_subspace=True)
    m.initialize(y)
    t0 = time.time()
    elbos, q = m.fit(y, method="laplace_em",
                     variational_posterior="structured_meanfield",
                     initialize=False, num_iters=num_iters, alpha=0.0, verbose=0)
    return m, q, elbos, time.time() - t0


def occupancy(z, K):
    return np.array([(z == k).mean() for k in range(K)])


def n_switch(z):
    return int(np.sum(np.diff(z) != 0))


def dwell_seconds(z, fs):
    """每个状态的驻留段时长（秒）。"""
    if len(z) == 0:
        return {}
    edges = np.concatenate(([0], np.where(np.diff(z) != 0)[0] + 1, [len(z)]))
    out = {}
    for a, b in zip(edges[:-1], edges[1:]):
        out.setdefault(int(z[a]), []).append((b - a) / fs)
    return {k: np.array(v) for k, v in out.items()}


def match_accuracy(z_true, z_hat, K):
    """置换无关的状态序列一致率（Hungarian 最优匹配）。"""
    C = np.zeros((K, K))
    for a in range(K):
        for b in range(K):
            C[a, b] = np.sum((z_true == a) & (z_hat == b))
    r, c = linear_sum_assignment(-C)
    return C[r, c].sum() / len(z_true)


def test_synthetic(T=10000, K=4, D_obs=10, D_latent=2, num_iters=100):
    print("\n" + "=" * 78)
    print("① 合成数据回归：NASCAR rSLDS, T=%d, K=%d, D_obs=%d, D_latent=%d" % (T, K, D_obs, D_latent))
    print("=" * 78)
    true_m, As, bs = make_nascar_model(D_obs, K, D_latent)
    z_true, x_true, y = true_m.sample(T=T)
    print("  真值：占据率 %s，状态切换 %d 次"
          % (np.round(occupancy(z_true, K), 3).tolist(), n_switch(z_true)))

    m, q, elbos, dt = fit_rslds(y, K, D_latent, num_iters)
    x_hat = q.mean_continuous_states[0]
    z_hat = m.most_likely_states(x_hat, y)

    acc = match_accuracy(z_true, z_hat, K)
    print("  拟合 %.0f s（%d 轮，%.2f s/轮）" % (dt, num_iters, dt / num_iters))
    print("  ELBO: 首 %.0f -> 末 %.0f" % (elbos[0], elbos[-1]))
    print("  状态一致率（置换无关）= %.3f" % acc)
    print("  拟合模型占据率 = %s" % np.round(occupancy(z_hat, K), 3).tolist())
    print("  拟合模型切换次数 = %d（真值 %d）" % (n_switch(z_hat), n_switch(z_true)))

    # 恢复出的动力学与真值的距离（A 用谱范数差，b 用欧氏距离），按拟合状态取最近的真值状态
    print("  恢复的 b：\n%s" % np.round(m.dynamics.bs, 3))
    print("  真值  的 b：\n%s" % np.round(bs, 3))
    ok = acc > 0.5
    print("  -> %s（一致率 > 0.5 视为通过）" % ("通过" if ok else "**不通过**"))
    return ok


def test_k1(T=5000, D_obs=10, D_latent=2, num_iters=30):
    print("\n" + "=" * 78)
    print("② K=1 退化检查：应退化为普通线性高斯 LDS（单状态 100% 占据、0 次切换）")
    print("=" * 78)
    true_m, _, _ = make_nascar_model(D_obs, 4, D_latent)
    _, _, y = true_m.sample(T=T)
    m, q, elbos, dt = fit_rslds(y, 1, D_latent, num_iters)
    z_hat = m.most_likely_states(q.mean_continuous_states[0], y)
    occ = occupancy(z_hat, 1)
    print("  拟合 %.0f s；占据率 = %.3f；切换次数 = %d" % (dt, occ[0], n_switch(z_hat)))
    ok = abs(occ[0] - 1.0) < 1e-9
    print("  -> %s" % ("通过" if ok else "**不通过**"))
    return ok


def test_timing(T=11000, D_obs=10, D_latent=5, K=3, num_iters=20, fs=8.0):
    print("\n" + "=" * 78)
    print("③ 真实规模计时：T=%d（%.1f min @%g Hz）、D_obs=%d、D_latent=%d、K=%d"
          % (T, T / fs / 60, fs, D_obs, D_latent, K))
    print("=" * 78)
    true_m = make_random_rslds(D_obs, K, D_latent)
    _, _, y = true_m.sample(T=T)
    m, q, elbos, dt = fit_rslds(y, K, D_latent, num_iters)
    z_hat = m.most_likely_states(q.mean_continuous_states[0], y)
    d = dwell_seconds(z_hat, fs)
    print("  拟合 %.0f s（%d 轮，%.2f s/轮）" % (dt, num_iters, dt / num_iters))
    print("  占据率 = %s" % np.round(occupancy(z_hat, K), 3).tolist())
    print("  切换 %d 次；各状态驻留段中位时长 = %s"
          % (n_switch(z_hat), {k: round(float(np.median(v)), 2) for k, v in d.items()}))
    print("  外推：K=3、20 轮 ≈ %.1f min/block；44 个四阶段 block 全跑 ≈ %.1f h"
          % (dt / 60, 44 * dt / 3600))
    return True


def main():
    print("ssm 版本：%s（%s）" % (getattr(ssm, "__version__", "?"), ssm.__file__))
    from importlib.metadata import version as _pkgver
    print("numpy：%s；autograd：%s" % (np.__version__, _pkgver("autograd")))
    quick = "--quick" in sys.argv
    results = {}
    if quick:
        results["① 合成回归"] = test_synthetic(T=3000, num_iters=30)
        results["② K=1 退化"] = test_k1(T=1500, num_iters=10)
        # ③ 计时用**真实规模**（T=11000），否则外推没意义；只跑少量轮次
        results["③ 计时"] = test_timing(T=11000, num_iters=8)
    else:
        results["① 合成回归"] = test_synthetic()
        results["② K=1 退化"] = test_k1()
        results["③ 计时"] = test_timing(T=11000, num_iters=40)

    print("\n" + "=" * 78)
    ok = all(results.values())
    for k, v in results.items():
        print("  %-14s %s" % (k, "通过" if v else "**不通过**"))
    print("SMOKE_OK" if ok else "SMOKE_FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())

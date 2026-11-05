"""attractor_core.py —— 吸引子分析核心算子（对应 PreReg_Attractor.md §2–§5，已按校准结果修订）

修订要点（2026-10-22，校准后）
  1. 「散度 < 0」**不作为判据**：kNN 局部线性回归带局部截距，等价于以邻域均值为参照，
     对任何平稳数据都会给出负散度（实测 24/24 恒真）。散度只作**描述量**报告。
  2. 「网格最小 ‖f‖」不可靠（恒真项），改为
       · 多起点 Newton 找真正的**不动点**
       · 要求其雅可比全部特征值 Re λ < 0
       · 再用**前向积分**测 **basin 比例**（收敛后须停留，故极限环通不过）
  3. 全部统计量输出**绝对值**；显著性由外部与 surrogate 分布比对决定（见 Step1_Calibration）。
  4. 不做分半（surrogate 校正已同时消除偏倚与过拟合乐观，分半只会损失 √2 功效）。

对外
  FieldEstimator      : kNN 局部线性回归，可批量求 f(z) 与 J(z)
  find_fixed_points   : 多起点 Newton
  basin_fraction      : 前向积分的 basin 比例（限数据支撑区）
  analyze_Y           : 一键得到某 session 的全部**绝对**统计量
"""
from __future__ import annotations

import numpy as np
from scipy.signal import butter, filtfilt
from sklearn.neighbors import NearestNeighbors

# --------------------------------------------------------------------------- #
# §2  预处理
# --------------------------------------------------------------------------- #
def dff(X, fs, win_s=60.0, pct=8.0, stride=None):
    """raw F → ΔF/F；基线 F0 = 滑动窗 pct 分位。"""
    from scipy.ndimage import percentile_filter
    T, N = X.shape
    w = max(5, int(round(win_s * fs)))
    st = stride or max(1, w // 10)
    Xs = X[::st]
    F0s = percentile_filter(Xs, percentile=pct, size=(max(3, w // st), 1), mode="nearest")
    idx = np.arange(0, T, st)
    F0 = np.empty_like(X)
    for j in range(N):
        F0[:, j] = np.interp(np.arange(T), idx, F0s[:, j])
    return (X - F0) / np.maximum(F0, 1e-9)


def variant_p0(Y, fs):
    return Y.copy()


def variant_p1(Y, fs, fc=0.01, order=2):
    """只剔除「共模 + 超慢」成分（群体均值低通后逐细胞回归并减）。"""
    b, a = butter(order, fc / (fs / 2.0), "low")
    m = Y.mean(axis=1)
    ms = filtfilt(b, a, m)
    mc = ms - ms.mean()
    den = float((mc ** 2).sum())
    if den <= 0:
        return Y.copy()
    beta = (Y * mc[:, None]).sum(0) / den
    alpha = Y.mean(0) - beta * ms.mean()
    return Y - (alpha[None, :] + np.outer(ms, beta))


def variant_p2(Y, fs, fc=0.01, order=2):
    b, a = butter(order, fc / (fs / 2.0), "high")
    return filtfilt(b, a, Y, axis=0)


VARIANTS = dict(P0=variant_p0, P1=variant_p1, P2=variant_p2)


def zscore_robust(Y):
    med = np.median(Y, axis=0)
    mad = np.median(np.abs(Y - med), axis=0) * 1.4826
    mad = np.where(mad > 1e-9, mad, 1.0)
    return (Y - med) / mad


def pca_reduce(Z, d):
    """Z:(T,N) z-scored → (T,d)；符号约定：与群体均值正相关。"""
    Zc = Z - Z.mean(0)
    N = Zc.shape[1]
    G = Zc.T @ Zc / max(N - 1, 1)
    ev, V = np.linalg.eigh(G)
    o = np.argsort(ev)[::-1]
    ev, V = ev[o], V[:, o]
    X = Zc @ V[:, :d]
    pm = Zc.mean(1)
    for j in range(d):
        if np.corrcoef(X[:, j], pm)[0, 1] < 0:
            X[:, j] *= -1
    return X, ev[:d] / max(ev.sum(), 1e-30)


# --------------------------------------------------------------------------- #
# §4  漂移场（批量向量化）
# --------------------------------------------------------------------------- #
class FieldEstimator:
    """f(z) = E[ż|z]，kNN 加权局部线性回归（含截距）。"""

    def __init__(self, Z, dt, k=100, ridge=1e-6):
        self.Z = Z[:-1]
        self.dZ = np.diff(Z, axis=0) / dt
        self.d = Z.shape[1]
        self.k = int(min(k, len(self.Z) - 1))
        self.nn = NearestNeighbors(n_neighbors=self.k).fit(self.Z)
        self.ridge = ridge
        self.speed_median = float(np.median(np.linalg.norm(self.dZ, axis=1)))

    def __call__(self, pts):
        pts = np.atleast_2d(np.asarray(pts, float))
        dist, idx = self.nn.kneighbors(pts)
        dz = self.Z[idx] - pts[:, None, :]
        dy = self.dZ[idx]
        w = np.exp(-0.5 * (dist / np.maximum(dist[:, -1:], 1e-12)) ** 2)
        A = np.concatenate([np.ones((len(pts), self.k, 1)), dz], axis=2)
        AtWA = np.einsum("pk,pki,pkj->pij", w, A, A)
        AtWy = np.einsum("pk,pki,pkj->pij", w, A, dy)
        tr = np.trace(AtWA, axis1=1, axis2=2)
        AtWA = AtWA + self.ridge * np.maximum(tr, 1e-12)[:, None, None] * np.eye(self.d + 1)
        coef = np.linalg.solve(AtWA, AtWy)              # (P, d+1, d)
        f = coef[:, 0, :]
        J = np.transpose(coef[:, 1:, :], (0, 2, 1))     # J[i,j] = ∂f_i/∂z_j
        return f, J


def make_grid(fe, grid_n=20, pct=(2, 98)):
    lo, hi = np.percentile(fe.Z, list(pct), axis=0)
    hi = np.where(hi > lo, hi, lo + 1e-6)
    edges = [np.linspace(lo[j], hi[j], grid_n + 1) for j in range(fe.d)]
    centers = [0.5 * (e[:-1] + e[1:]) for e in edges]
    pts = np.stack(np.meshgrid(*centers, indexing="ij"), axis=-1).reshape(-1, fe.d)
    H, _ = np.histogramdd(fe.Z, bins=edges)
    return dict(edges=edges, pts=pts, occ=H.ravel().astype(float), lo=lo, hi=hi)


# --------------------------------------------------------------------------- #
# §5-A1'  不动点 + basin
# --------------------------------------------------------------------------- #
def find_fixed_points(fe, starts, n_iter=60, step_cap=0.5, tol=1e-6, bounds=None):
    """多起点 Newton。返回 z, f, J（逐起点）。"""
    z = np.asarray(starts, float).copy()
    for _ in range(n_iter):
        f, J = fe(z)
        try:
            step = np.linalg.solve(J, -f[..., None])[..., 0]
        except np.linalg.LinAlgError:
            break
        nrm = np.linalg.norm(step, axis=1, keepdims=True)
        step = step * np.minimum(1.0, step_cap / np.maximum(nrm, 1e-12))
        z = z + step
        if bounds is not None:
            z = np.clip(z, bounds[0], bounds[1])
        if np.all(nrm < tol):
            break
    f, J = fe(z)
    return z, f, J


def basin_fraction(fe, inits, spread, dt=0.25, t_max=60.0, check_frac=0.25,
                   drift_thr=0.10, move_thr=0.05):
    """前向积分的 basin 比例——**不预设吸引子类型**。

    到达条件（两条都需满足）：
      ① 末态漂移小：‖f(z)‖ < drift_thr × 中位速度  → 已进入不动点（流形）
      ② 末段静止：近 check_frac 段内位移 < move_thr × 尺度 → 不是极限环

    因此点吸引子、线吸引子都算通过；极限环（漂移恒非零）不通过。
    inits 应取自**数据支撑区**（观测到的帧），避免外推。
    """
    n_steps = max(8, int(t_max / dt))
    tail = max(1, int(n_steps * check_frac))
    z = np.asarray(inits, float).copy()
    z_tail = None
    for s in range(n_steps):
        k1, _ = fe(z)
        k2, _ = fe(z + 0.5 * dt * k1)
        k3, _ = fe(z + 0.5 * dt * k2)
        k4, _ = fe(z + dt * k3)
        z = z + (dt / 6.0) * (k1 + 2 * k2 + 2 * k3 + k4)
        if z_tail is None and s >= n_steps - tail:
            z_tail = z.copy()
    f_end, _ = fe(z)
    low_drift = np.linalg.norm(f_end, axis=1) < drift_thr * fe.speed_median
    moved = np.linalg.norm(z - z_tail, axis=1)
    still = moved < move_thr * spread
    return float(np.mean(low_drift & still)), z


def _pick_fixed_point(z, f, J, grid, fe, lam_neutral=0.01):
    """从 Newton 结果中挑：稳定（容许近中性）+ ‖f‖ 极小 + 附近占据率高。

    lam_neutral = 0.01 s^-1  ⇒ λ 在 [-0.01, 0.01] 视为中性（τ ≳ 100 s），
    因此**线吸引子**（一个近零特征值）不会被误判为不稳定。
    """
    occ, pts = grid["occ"], grid["pts"]
    speed = fe.speed_median
    stable, n_unstable = [], 0
    for k in range(len(z)):
        if np.linalg.norm(f[k]) > 0.05 * speed:
            continue
        ev = np.linalg.eigvals(J[k])
        if not np.all(ev.real < lam_neutral):
            n_unstable += 1
            continue
        stable.append(k)
    info = dict(n_found=int(len(z)), n_stable=int(len(stable)), n_unstable=int(n_unstable))
    if not stable:
        return None, info
    r_near = 0.15 * float(np.mean(grid["hi"] - grid["lo"]))
    best, best_occ = None, -1.0
    for k in stable:
        d2 = np.sum((pts - z[k]) ** 2, axis=1)
        near = float(occ[d2 <= r_near ** 2].sum())
        if near > best_occ:
            best, best_occ = k, near
    info["occ_near"] = float(best_occ)
    return best, info


# --------------------------------------------------------------------------- #
# 一键（只给绝对量，不做显著性判定）
# --------------------------------------------------------------------------- #
def analyze_Y(Y, fs, variant="P1", d=2, k=100, grid_n=20, n_init=80,
              t_max=60.0, seed=0):
    rng = np.random.default_rng(seed)
    Yp = VARIANTS[variant](Y, fs)
    Z = zscore_robust(Yp)
    X, evr = pca_reduce(Z, d)

    fe = FieldEstimator(X, dt=1.0 / fs, k=k)
    grid = make_grid(fe, grid_n=grid_n)
    fg, Jg = fe(grid["pts"])

    spread = float(np.mean(grid["hi"] - grid["lo"]))
    eps = 0.10 * spread

    starts = grid["pts"][np.argsort(-grid["occ"])[: max(10, min(25, len(grid["pts"])))]]
    z, f, J = find_fixed_points(fe, starts, bounds=(grid["lo"], grid["hi"]))
    best, info = _pick_fixed_point(z, f, J, grid, fe)

    out = dict(variant=variant, d=d, evr_sum=float(np.sum(evr)),
               evr=[float(x) for x in evr], n_stable=info["n_stable"],
               n_found=info["n_found"], n_unstable=info["n_unstable"],
               z_star=None, div=np.nan, eig_real_max=np.nan, basin=np.nan,
               radial_median=np.nan, speed_median=fe.speed_median,
               spread=spread, eps=eps, occ_near=info.get("occ_near", np.nan))
    if best is None:
        return out

    zs = z[best]
    ev = np.linalg.eigvals(J[best])
    out.update(z_star=[float(x) for x in zs],
               div=float(np.trace(J[best])),
               eig_real_max=float(np.max(ev.real)),
               eig=[[float(e.real), float(e.imag)] for e in ev])

    idx = rng.choice(len(fe.Z), size=min(n_init, len(fe.Z)), replace=False)
    init = fe.Z[idx]
    inb = np.all((init >= grid["lo"]) & (init <= grid["hi"]), axis=1)
    if inb.sum() >= 10:
        init = init[inb]
    out["basin"], _ = basin_fraction(fe, init, spread, dt=0.25, t_max=t_max)

    r_grid = np.linalg.norm(grid["pts"] - zs, axis=1)
    m = grid["occ"] > 0
    if m.sum() >= 5:
        lo_r, hi_r = np.percentile(r_grid[m], [20, 60])
        band = m & (r_grid >= lo_r) & (r_grid <= hi_r)
        if band.sum() >= 3:
            u = zs[None, :] - grid["pts"][band]
            u /= np.maximum(np.linalg.norm(u, axis=1, keepdims=True), 1e-12)
            out["radial_median"] = float(np.median(np.einsum("ij,ij->i", fg[band], u)))
    return out


# --------------------------------------------------------------------------- #
# §5-D3  径向回复剖面（**不用局部回归**，避免估计器伪迹）
# --------------------------------------------------------------------------- #
def kde_mode(Z, n_sub=3000, k=50, seed=0):
    """密度众数：kNN 密度最高的点，再做邻域均值精化。

    避开「局部线性回归 → 假不动点」的偏倚，直接给 z*。
    """
    rng = np.random.default_rng(seed)
    Zs = Z if len(Z) <= n_sub else Z[rng.choice(len(Z), n_sub, replace=False)]
    nn = NearestNeighbors(n_neighbors=min(k, len(Zs))).fit(Zs)
    dist, _ = nn.kneighbors(Zs)
    i = int(np.argmin(dist[:, -1]))          # k 邻域半径最小 = 密度最高
    z0 = Zs[i]
    _, idx = nn.kneighbors(z0[None, :], n_neighbors=min(4 * k, len(Zs)))
    return Zs[idx[0]].mean(axis=0)


def radial_profile(Z, z_star, fs, lag_s=0.5, n_bins=8, min_count=30):
    """直接估计 E[Δz·û | r] / Δ，不经过任何平滑回归。

    OU 过程：径向推进 p = −k·r（与 r 成正比）⇒ p/r 恒定。
    超线性势阱：p/r 随 r 增大 ⇒ 存在 basin 边界。

    返回 dict：r_mid, p_med, rate (=p/r), superlinear_index (=最大/最小 rate),
                cubic_coef (p = -a·r - b·r^3 的 b), r2 增益。
    """
    lag = max(1, int(round(lag_s * fs)))
    Z0 = Z[:-lag]
    dz = Z[lag:] - Z[:-lag]
    r = np.linalg.norm(Z0 - z_star, axis=1)
    good = r > 1e-9
    Z0, dz, r = Z0[good], dz[good], r[good]
    u = (z_star[None, :] - Z0) / r[:, None]
    p = np.einsum("ij,ij->i", dz, u) / (lag / fs)      # 每秒沿回心方向的位移

    qs = np.quantile(r, np.linspace(0, 1, n_bins + 1))
    r_mid, p_med, cnt = [], [], []
    for b in range(n_bins):
        m = (r >= qs[b]) & (r <= qs[b + 1] if b == n_bins - 1 else r < qs[b + 1])
        if m.sum() < min_count:
            continue
        r_mid.append(float(np.median(r[m])))
        p_med.append(float(np.median(p[m])))
        cnt.append(int(m.sum()))
    r_mid, p_med = np.array(r_mid), np.array(p_med)
    out = dict(n_bins_used=len(r_mid), r_mid=r_mid.tolist(), p_med=p_med.tolist(),
               count=cnt, superlinear_index=np.nan, cubic_coef=np.nan,
               r2_lin=np.nan, r2_cub=np.nan, tau_eff=np.nan)
    if len(r_mid) < 4:
        return out

    rate = p_med / np.maximum(r_mid, 1e-12)             # = −1/τ(r)
    out["superlinear_index"] = float(np.median(rate[-2:]) / np.median(rate[:2]))
    out["tau_eff"] = float(1.0 / max(np.median(-rate), 1e-12))

    # 线性 vs 三次：p = a1 r ; p = a1 r + a3 r^3
    A1 = np.column_stack([r_mid])
    A3 = np.column_stack([r_mid, r_mid ** 3])
    c1, *_ = np.linalg.lstsq(A1, p_med, rcond=None)
    c3, *_ = np.linalg.lstsq(A3, p_med, rcond=None)
    res1 = p_med - A1 @ c1
    res3 = p_med - A3 @ c3
    ss = max(((p_med - p_med.mean()) ** 2).sum(), 1e-30)
    out["r2_lin"] = float(1 - (res1 ** 2).sum() / ss)
    out["r2_cub"] = float(1 - (res3 ** 2).sum() / ss)
    out["cubic_coef"] = float(c3[1])
    return out

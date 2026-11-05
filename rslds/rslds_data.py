"""rslds_data.py —— 读取 `ExportForRSLDS.m` 的产物（.mat v7.3 / HDF5）并做预处理

方向约定（最容易踩的坑）
    MATLAB 用 `save -v7.3` 写数组时，HDF5 里声明的维度是反的，因此 h5py 读出来**直接就是
    转置**。实测：MATLAB 的 `A`(2x3) 在文件里读到的形状是 (3,2)，内容为 `A.T`。
    对 X(nCell x nSamp) 而言，这意味着 ``f['X'][:]`` 的**形状恰好是 (nSamp, nCell)**，
    也就是"时间 x 细胞"——正是建模要的方向，**不要再转置**。
    `ExportForRSLDS.m` 写进文件里的 ``probe = [X(1,1) X(1,end) X(end,1) X(end,end)]``
    把方向钉死，`CheckExport.py` 会逐文件核对。

下标约定
    MATLAB 侧事件下标是 **1 基**，本模块统一转成 **0 基** 后返回。
"""

from __future__ import annotations

import os

import numpy as np
import h5py

HERE = os.path.dirname(os.path.abspath(__file__))
DATA_ROOT = os.path.join(HERE, "data")


# --------------------------------------------------------------------------- #
# 底层：读 MATLAB v7.3 文件
# --------------------------------------------------------------------------- #
def _scalar(f, key):
    """MATLAB 标量（文件里形状是 (1,1)）→ Python float"""
    return float(np.asarray(f[key][:]).ravel()[0])


def _string(f, key):
    """MATLAB char 数组 → Python str（v7.3 存成 uint16 的字符码）

    ⚠ 不能读 MATLAB ``string`` 对象：它在 v7.3 里是 uint32 引用结构
    （``MATLAB_class='string'``），码元不是字符码。导出侧一律先 ``char()`` 再存。
    这里对这种情况返回空串而不是崩溃。
    """
    d = f[key]
    if d.attrs.get("MATLAB_empty", 0):
        return ""
    if d.attrs.get("MATLAB_class", b"") == b"string":
        return ""
    v = np.asarray(d[:]).ravel()
    if v.dtype.kind in "ui":
        if v.size and int(v.max()) > 0x10FFFF:
            return ""
        return "".join(chr(int(c)) for c in v)
    return str(v)


def _vec(f, key):
    """MATLAB 向量 → 1-D numpy 数组。

    ⚠ 空数组的坑：MATLAB v7.3 把**空**数组写成一个带 ``MATLAB_empty=1`` 属性的数据集，
    数据集里存的是**维度向量**（空列向量 ``0x1`` → 内容 ``[0, 1]``）。任何通用 HDF5 读取器
    照直读就会凭空多出两个元素（本项目实测到过：以为有 2 个「给水」事件，其实是 0 个）。
    所以先查属性。
    """
    d = f[key]
    if d.attrs.get("MATLAB_empty", 0):
        return np.zeros(0, dtype=np.float64)
    return np.asarray(d[:]).ravel()


def load_block(path, meta_only=False):
    """读一个导出文件，返回 dict。

    X          (T, N) float32  —— 时间 x 细胞；原始荧光，未 z、未去趋势
    cd1, cd2   (T,)   float32  —— cue 通道 / 舔水通道，与 X 同格
    fs         float           —— 导出后采样率（Hz）；30 Hz 的 block 已被抽到 ~7.5 Hz
    cue_idx 等 (n,)   int64    —— 事件样本下标（**0 基**）
    cell_ok    (N,)   float32  —— 每个细胞有限样本的占比，用来筛掉整段 NaN 的细胞
    stim_code  (n,)   int64    —— 每个 cue 的刺激类型（0 基编码，名称见 stim_names）
    z_layer    (N,)   int64    —— 每个细胞的 ZLayer 编码（1=MOp2/3, 2=MOp5, 3=L2）
    must_warn  str             —— 数据集 Blocks.MustWarn 的块级 QC 标记（多为空）
    performance float          —— 数据集 Blocks.Performance（会话命中率 0~1，可为 NaN）
    block_ri   int             —— 数据集 Blocks.BlockRI（同 Design 内的会话序号，1 起）

    ``meta_only=True`` 时不读 X/CD1/CD2（省时间和内存），用于扫目录。
    """
    with h5py.File(path, "r") as f:
        d = dict(
            cell_uid=_vec(f, "CellUID").astype(np.int64),
            cell_ok=_vec(f, "cellFiniteFrac").astype(np.float32),
            probe=_vec(f, "probe").astype(np.float32),
            fs=_scalar(f, "fs"),
            dur_sec=_scalar(f, "durSec"),
            n_cell=int(_scalar(f, "nCell")),
            n_samp=int(_scalar(f, "nSamp")),
            n_samp0=int(_scalar(f, "nSamp0")),
            decim_k=int(_scalar(f, "decimK")),
            mouse=_string(f, "Mouse"),
            phase=_string(f, "Phase"),
            design=_string(f, "Design"),
            datetime=_string(f, "DateTimeISO"),
            cohort=_string(f, "Cohort"),
            ev_sample=_vec(f, "evSample").astype(np.int64),
            ev_code=_vec(f, "evCode").astype(np.int64),
            ev_names=_string(f, "evNamesCSV").split(","),
        )
        # MATLAB 是 1 基 → 0 基
        for name in ["GiveWater", "Hit", "Miss", "TrialStart", "SoundOn", "LightOn"]:
            d["idx_" + name] = _vec(f, "idx" + name).astype(np.int64) - 1
        # 权威 cue 帧号（Trials.SampleRange.Tag）。EventLog 派生下标**不可**用于对齐，
        # 见笔记「时间基陷阱」与 /memories/repo/data-alignment.md
        if "idxCue" in f:
            d["idx_cue"] = _vec(f, "idxCue").astype(np.int64) - 1
        else:
            d["idx_cue"] = np.zeros(0, dtype=np.int64)
        d["ev_sample"] = d["ev_sample"] - 1
        # 每个 cue 的刺激类型编码（与 idx_cue **逐元素对齐**，由同一个 keepT 掩膜派生）。
        # 名称表见 stim_names；只有 LAu/LAuW 会话会出现多种刺激。
        if "stimCode" in f:
            d["stim_code"] = _vec(f, "stimCode").astype(np.int64)
            d["stim_names"] = [s for s in _string(f, "stimNamesCSV").split(",") if s]
        else:
            d["stim_code"] = np.zeros(0, dtype=np.int64)
            d["stim_names"] = []
        # 每细胞的 ZLayer 编码（1=MOp2/3, 2=MOp5, 3=L2）。用于分层复算。
        if "zLayerCode" in f:
            d["z_layer"] = _vec(f, "zLayerCode").astype(np.int64)
            d["z_layer_names"] = [s for s in _string(f, "zLayerNamesCSV").split(",") if s]
        else:
            d["z_layer"] = np.zeros(len(d["cell_uid"]), dtype=np.int64)
            d["z_layer_names"] = []
        # 块级 QC / 序号（数据集 Blocks 表的 MustWarn / Performance / BlockRI）
        d["must_warn"] = _string(f, "mustWarn") if "mustWarn" in f else ""
        d["performance"] = _scalar(f, "performance") if "performance" in f else float("nan")
        d["block_ri"] = int(_scalar(f, "blockRI")) if "blockRI" in f else 0
        if not meta_only:
            d["X"] = np.asarray(f["X"][:], dtype=np.float32)
            d["cd1"] = _vec(f, "CD1").astype(np.float32)
            d["cd2"] = _vec(f, "CD2").astype(np.float32)
    d["path"] = path
    return d


def scan_cohort(cohort="ALB", phases=None):
    """扫目录列出已导出的 block（**不依赖 manifest** —— 分块导出时 manifest 会被覆盖）。

    返回按 (鼠, 时间) 排序的元数据列表。``phases`` 非空时只保留这些阶段。
    """
    import glob

    paths = sorted(glob.glob(os.path.join(DATA_ROOT, cohort, "*.mat")))
    out = []
    for p in paths:
        m = load_block(p, meta_only=True)
        if phases is not None and m["phase"] not in phases:
            continue
        out.append(m)
    out.sort(key=lambda m: (m["mouse"], m["datetime"]))
    return out


def check_orientation(d, tol=1e-6):
    """核对 h5py 读出的 X 确实是想要的 (T, N) 方向。

    ``probe`` 在 MATLAB 侧按 **MATLAB 形状** ``X``(nCell x nSamp) 取角点：
        probe = [X(1,1), X(1,end), X(end,1), X(end,end)]
    Python 侧 ``A = f['X'][:]`` 形状是 (nSamp, nCell) 且 ``A = X.T``，即 ``A[i,j] = X[j,i]``。
    于是角点对应关系是
        X(1,1)   -> A[0,  0]        X(1,end)   -> A[-1, 0]
        X(end,1) -> A[0, -1]        X(end,end) -> A[-1,-1]
    注意后两个是**交叉**的 —— 照着 MATLAB 的顺序直写会对不上（本项目已踩过）。
    """
    A, p = d["X"], d["probe"]
    got = np.array([A[0, 0], A[-1, 0], A[0, -1], A[-1, -1]], dtype=np.float64)
    return bool(np.all(np.abs(got - p) <= tol * (1.0 + np.abs(p))))


# --------------------------------------------------------------------------- #
# 预处理
# --------------------------------------------------------------------------- #
def lick_indicator(cd2, thr=5.0):
    """CD2 高于基线 thr 记为"正在舔"，返回 0/1 的 float32。

    与 MATLAB 侧 Step1c/Step2 同口径：`CD2 > median(CD2) + 5`。
    阈值常数 5 是原始 ADC 单位，导出时未做任何缩放，故两边一致。
    """
    return (cd2 > np.median(cd2) + thr).astype(np.float32)


def detrend_bleach(X, fs, tau_fast=20.0, tau_slow=None):
    """逐细胞去掉双指数漂白成分（GCaMP 会话内的慢漂移）。

    做法：以 ``[1, exp(-t/tau_fast), exp(-t/tau_slow)]`` 为基做**逐细胞最小二乘**，
    减掉拟合值。时间常数固定、系数逐细胞解，所以非常快（一次 lstsq 搞定所有细胞）。
    常数项也在基里，故残差同时去掉了直流分量（后面还要 z-score，无妨）。

    tau_slow 默认取整个 session 时长的一半。想保留漂移时不要调用本函数。
    """
    T = X.shape[0]
    t = np.arange(T, dtype=np.float64) / fs
    if tau_slow is None:
        tau_slow = max(t[-1] / 2.0, 2 * tau_fast)
    B = np.column_stack([np.ones(T), np.exp(-t / tau_fast), np.exp(-t / tau_slow)])
    coef, *_ = np.linalg.lstsq(B, np.asarray(X, dtype=np.float64), rcond=None)
    return (np.asarray(X, dtype=np.float64) - B @ coef).astype(np.float32)


def detrend_linear(X):
    """逐细胞去掉线性趋势。"""
    T = X.shape[0]
    t = np.linspace(-1.0, 1.0, T)
    B = np.column_stack([np.ones(T), t])
    coef, *_ = np.linalg.lstsq(B, np.asarray(X, dtype=np.float64), rcond=None)
    return (np.asarray(X, dtype=np.float64) - B @ coef).astype(np.float32)


def zscore_cols(X):
    """逐细胞 z-score（对每列/每个细胞）。"""
    X = np.asarray(X, dtype=np.float64)
    mu = X.mean(axis=0, keepdims=True)
    sd = X.std(axis=0, keepdims=True)
    sd[sd == 0] = 1.0
    return ((X - mu) / sd).astype(np.float32)


def factor_analysis(X, n_dim, seed=0):
    """因子分析降到 n_dim 维，返回 (Y[T x n_dim], model)。

    为什么这里降到 ~10 维再交给 rSLDS
    本数据的细胞数（140~770）与 1 Hz 下的时间点数同量级，直接在高维上做
    状态推断既慢又不稳；Linderman 原论文用的也是 10 维左右的观测。
    """
    from sklearn.decomposition import FactorAnalysis

    fa = FactorAnalysis(n_components=n_dim, random_state=seed, max_iter=500)
    Y = fa.fit_transform(np.asarray(X, dtype=np.float64))
    return zscore_cols(Y), fa


def smooth(x, win):
    """因果无关的滑动平均（'same'，端点按可用样本平均）。"""
    win = int(max(1, win))
    if win == 1:
        return np.asarray(x, dtype=np.float64)
    k = np.ones(win) / win
    return np.convolve(np.asarray(x, dtype=np.float64).ravel(), k, mode="same")


# --------------------------------------------------------------------------- #
# 清单
# --------------------------------------------------------------------------- #
def list_blocks(cohort="ALB"):
    """列出某队列已导出的全部 block（按时间排序）。"""
    import csv

    man = os.path.join(DATA_ROOT, cohort, "manifest_%s.csv" % cohort)
    if not os.path.exists(man):
        raise FileNotFoundError("找不到清单：%s（先跑 ExportForRSLDS.m）" % man)
    with open(man, "r", encoding="utf-8-sig", newline="") as fh:
        rows = list(csv.DictReader(fh))
    for r in rows:
        r["path"] = os.path.join(DATA_ROOT, cohort, r["file"])
        for k in ["fsHz", "durMin", "nCell", "nGiveWater", "nTrialStart",
                  "cellFiniteFracMean", "cellFiniteFracMin"]:
            if k in r and r[k] not in ("", None):
                r[k] = float(r[k])
    rows.sort(key=lambda r: r["datetime"])
    return rows

"""CheckExport.py —— 校验 `ExportForRSLDS.m` 的产物（.mat v7.3 / HDF5）

为什么值得单独写一个校验脚本
    MATLAB 的 v7.3 就是 HDF5，但**维度方向与 MATLAB 相反**：MATLAB 的 `A`(m x n) 在文件里
    声明的形状是 (n, m)，于是 h5py 读出来直接是 `A.T`。整条 rSLDS 流水线都建立在这个约定
    上——一旦方向弄反，模型照样能跑、指标照样有数，只是全部无意义。所以在动真数据之前先用
    一个**已知的小矩阵**把方向钉死，再逐文件核对 `probe`、长度、下标范围。

用法：
    .venv\\Scripts\\python rslds\\CheckExport.py            # 默认队列 ALB
    .venv\\Scripts\\python rslds\\CheckExport.py TH
"""

from __future__ import annotations

import os
import sys

import numpy as np
import h5py

import rslds_data as rd

FAILS = []


def fail(msg):
    FAILS.append(msg)
    print("  [FAIL] " + msg)


def check_orientation_probe():
    """第一步：用已知的 2x3 矩阵钉死 HDF5 的维度方向。"""
    p = os.path.join(os.path.dirname(rd.HERE), "_h5test.mat")
    if not os.path.exists(p):
        fail("找不到 %s（先在 MATLAB 里 save A -v7.3）" % p)
        return
    with h5py.File(p, "r") as f:
        A = np.asarray(f["A"][:])
    # MATLAB: A = reshape(1:6,2,3) -> [[1,3,5],[2,4,6]]
    want = np.array([[1, 2], [3, 4], [5, 6]], dtype=A.dtype)
    print("=== 方向钉死测试 (_h5test.mat) ===")
    print("  h5py 读到的形状 = %s（MATLAB 侧是 (2,3)，故应为 (3,2)）" % (A.shape,))
    print("  h5py 读到 = %s" % (A.tolist(),))
    if A.shape == want.shape and np.array_equal(A, want):
        print("  [OK] 方向与预期一致：h5py 直接得到 MATLAB 数组的转置\n")
    else:
        fail("方向不符！期望 %s，实得 %s" % (want.tolist(), A.tolist()))


def check_block(path, quiet=False):
    name = os.path.basename(path)
    d = rd.load_block(path)
    X, cd1, cd2 = d["X"], d["cd1"], d["cd2"]
    ok = True

    def need(cond, msg):
        nonlocal ok
        if not cond:
            ok = False
            fail("%s: %s" % (name, msg))

    need(X.ndim == 2, "X 不是二维（%s）" % (X.shape,))
    need(len(cd1) == X.shape[0], "CD1 长度 %d != nSamp %d" % (len(cd1), X.shape[0]))
    need(len(cd2) == X.shape[0], "CD2 长度 %d != nSamp %d" % (len(cd2), X.shape[0]))
    need(len(d["cell_uid"]) == X.shape[1], "CellUID 数 %d != nCell %d" % (len(d["cell_uid"]), X.shape[1]))
    need(len(d["cell_ok"]) == X.shape[1], "cellFiniteFrac 数 != nCell")
    need(abs(d["fs"] * d["dur_sec"] - X.shape[0]) < 1.0, "fs*durSec(%.1f) != nSamp(%d)" % (d["fs"] * d["dur_sec"], X.shape[0]))
    need(rd.check_orientation(d), "probe 不一致 —— X 的方向不对！")
    with h5py.File(path, "r") as f:
        hs = f["X"].shape
    need(hs == (X.shape[0], X.shape[1]),
         "HDF5 里 X 的形状 %s != (nSamp, nCell)=(%d, %d)" % (hs, X.shape[0], X.shape[1]))

    for nm in ["GiveWater", "Hit", "Miss", "TrialStart", "SoundOn", "LightOn"]:
        v = d["idx_" + nm]
        need(np.all(v >= 0) and np.all(v < X.shape[0]),
             "idx_%s 下标越界（%s vs nSamp=%d）" % (nm, (v.min(), v.max()) if v.size else "空", X.shape[0]))
        need(v.size < 2 or np.all(np.diff(v) >= 0), "idx_%s 不是有序的" % nm)

    # 整段 NaN 的细胞占比：这些细胞必须由调用方剔除
    all_nan = int(np.sum(~np.isfinite(X).any(axis=0)))

    if not quiet:
        print("  %-46s T=%6d N=%3d fs=%5.2f %5.1fmin cue=%3d 给水=%3d NaN细胞=%d %s"
              % (name, X.shape[0], X.shape[1], d["fs"], d["dur_sec"] / 60.0,
                 d["idx_TrialStart"].size, d["idx_GiveWater"].size, all_nan,
                 "" if ok else "<-- 见上"))
    return d, ok


def main():
    cohort = sys.argv[1] if len(sys.argv) > 1 else "ALB"
    check_orientation_probe()

    rows = rd.list_blocks(cohort)
    print("=== %s：%d 个 block ===" % (cohort, len(rows)))
    if not rows:
        fail("清单为空")
    tot_min = 0.0
    n_bad_nan = 0
    for r in rows:
        if not os.path.exists(r["path"]):
            fail("缺少文件 %s" % r["file"])
            continue
        d, _ = check_block(r["path"])
        tot_min += d["dur_sec"] / 60.0
        if not np.isfinite(d["X"]).all(axis=0).all():
            n_bad_nan += 1
    print("\n总时长 %.1f h；含 NaN 细胞的 block %d 个" % (tot_min / 60.0, n_bad_nan))

    if FAILS:
        print("\n=== 失败 %d 项 ===" % len(FAILS))
        for m in FAILS[:40]:
            print("  - " + m)
        sys.exit(1)
    print("\nCHECK_OK 全部通过")


if __name__ == "__main__":
    main()

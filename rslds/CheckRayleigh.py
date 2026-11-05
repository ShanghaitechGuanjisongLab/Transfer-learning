"""CheckRayleigh.py —— 用已存的 fig1 npz 在**完整 5 维潜空间**重算方向一致性（不重拟合）

为什么必须重算：画图时把潜空间投到 2 维（轴1 = 两个定点连线方向），R 是在那个投影里算的。
如果线索响应落在被投影掉的方向上，投影里的 R 会**人为偏低**。
这里直接在 5 维里算 Rayleigh R = |mean(单位位移向量)|，p ≈ exp(-n·R²)。

用法：  .venv\\Scripts\\python rslds\\CheckRayleigh.py
"""

from __future__ import annotations

import glob
import os

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
FIGDIR = os.path.join(HERE, "results", "fig1")


def rayleigh(d):
    """d: (n, D) 位移向量。返回 (R, p, n)。"""
    n = np.linalg.norm(d, axis=1)
    ok = n > 1e-12
    if ok.sum() < 3:
        return np.nan, np.nan, int(ok.sum())
    u = d[ok] / n[ok, None]
    R = float(np.linalg.norm(u.mean(0)))
    return R, float(np.exp(-ok.sum() * R ** 2)), int(ok.sum())


def main():
    files = sorted(glob.glob(os.path.join(FIGDIR, "fig1_*_K2.npz")))
    print("=== cue 对齐位移的方向一致性（完整 5 维）===", flush=True)
    print("调试：%d 个文件，第一个的 keys = %s" % (len(files), np.load(files[0]).files), flush=True)
    print("%-9s %5s %9s %8s | %9s %8s | %9s %8s | %9s %8s"
          % ("鼠", "试次", "R(5维)", "p", "R(0~1s)", "p", "R(1.5~3s)", "p", "R(3~6s)", "p"), flush=True)
    out = []
    for f in files:
        z = np.load(f)
        x, ev, fs = z["x"], z["idxTrialStart"].astype(int), float(z["fs"])
        ev = ev[(ev >= 0) & (ev < len(x))]
        row = [os.path.basename(f).split("_")[1]]
        res = {}
        for name, (a0, a1) in [("5维", (1.5, 3.0)), ("0~1s", (0.0, 1.0)),
                               ("1.5~3s", (1.5, 3.0)), ("3~6s", (3.0, 6.0))]:
            n0, n1 = int(round(a0 * fs)), int(round(a1 * fs))
            d = []
            for c in ev:
                if c + n1 < len(x):
                    d.append(x[c + n1] - x[c + n0])
            R, p, n = rayleigh(np.asarray(d))
            res[name] = (R, p, n)
        r0, p0, n = res["5维"]
        print("%-9s %5d %9.3f %8.3f | %9.3f %8.3f | %9.3f %8.3f | %9.3f %8.3f"
              % (row[0], n, r0, p0, res["0~1s"][0], res["0~1s"][1],
                 res["1.5~3s"][0], res["1.5~3s"][1], res["3~6s"][0], res["3~6s"][1]), flush=True)
        out.append(dict(mouse=row[0], n=n, R5=r0, p5=p0,
                        R01=res["0~1s"][0], p01=res["0~1s"][1],
                        R36=res["3~6s"][0], p36=res["3~6s"][1]))
    R = np.array([o["R5"] for o in out])
    P = np.array([o["p5"] for o in out])
    print("\n5 维 R：中位 %.3f，范围 %.3f~%.3f；p<0.05 的鼠数 = %d/%d"
          % (np.median(R), R.min(), R.max(), (P < 0.05).sum(), len(R)), flush=True)
    print("DONE", flush=True)


if __name__ == "__main__":
    raise SystemExit(main())

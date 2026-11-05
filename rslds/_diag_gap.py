import glob
import os

import numpy as np

FIG = os.path.join(os.path.dirname(os.path.abspath(__file__)), "results", "fig1")
print("%-9s %-42s %-42s" % ("鼠", "stable(ρ≤0.99) 多数状态的 τ（s，降序）", "最大相邻比（谱隙）"))
gaps = []
for f in sorted(glob.glob(os.path.join(FIG, "stable_*_K2_rho0.990.npz"))):
    z = np.load(f)
    As, lab, fs = z["As"], z["z"].astype(int), float(z["fs"])
    occ = np.array([(lab == k).mean() for k in range(2)])
    maj = int(np.argmax(occ))
    r = np.sort(np.abs(np.linalg.eigvals(As[maj])))[::-1]
    tau = np.where((r > 0) & (r < 1), -1.0 / (fs * np.log(np.clip(r, 1e-9, 1 - 1e-12))), np.inf)
    ratio = r[:-1] / np.maximum(r[1:], 1e-12)
    gaps.append(ratio.max())
    name = os.path.basename(f).split("_")[1]
    print("%-9s %-42s %.2f  (在 τ=%.1f / %.1f s 之间)"
          % (name, np.round(tau, 1).tolist(), ratio.max(), tau[:-1][np.argmax(ratio)], tau[1:][np.argmax(ratio)]))

print()
print("最大相邻比：中位 %.2f（%.2f–%.2f）" % (np.median(gaps), min(gaps), max(gaps)))
print("⇒ 比值接近 1 表示**没有谱隙**（所有模式一样慢），慢流形就无从谈起")

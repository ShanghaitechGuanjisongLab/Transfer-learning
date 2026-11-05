"""Step34_PeakLatency.py —— 复核"峰在 3 s"：范数伪迹还是真实 PSTH？

问题
  Step29 报告"群体平均诱发响应峰在 cue 后 3.0 s"，用的是
      R(τ) = median_trials (Z_{c+τ} − Z_{c−0.5s}),   A(τ) = ‖R(τ)‖₂  （跨 ~500 细胞）
  但 ‖·‖₂ 在 z 化空间里**不是响应幅度**：
    · 它衡量"群体状态向量偏离基线多远"，会被**慢状态变化**（觉醒/运动/舔水预备）主导
    · z 化把低方差细胞放大到同等权重 ⇒ 噪声主导细胞也同等贡献
    · 少数大幅慢漂细胞可压过多数细胞的快速瞬变
  因此"3 s"可能是范数伪迹。本脚本用四种**与范数无关**的量复核：

  A. PSTH   : mean_i  z(τ,i)            —— 常规群体平均时程（类"总体发放率"）
  B. |PSTH| : mean_i |z(τ,i)|          —— 只取幅度，避免正负抵消
  C. RMS    : ‖R(τ)‖₂/√nCell           —— 与 A/B 同量纲的范数，便于比较
  D. 响应细胞子集 : 只取峰幅 >2 z 的细胞，重算 A
  E. 逐细胞峰潜伏期 : 每个细胞自己的 argmax，报中位/IQR

  另在 **未做逐细胞 z 化** 的 ΔF/F 上重做 A/B，排除 z 化的影响。
"""
from __future__ import annotations

import json
import os

import numpy as np

import attractor_core as AC
from rslds_data import load_block, scan_cohort

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "results", "_step34_peaklat.json")
PHASES = ["Learned", "Transfer", "Final"]
MIN_CELL = 40
BASE_S = -0.5
STEP = 0.05
TAUS = np.arange(BASE_S, 6.0 + 1e-9, STEP)


def stack_resp(Y, cue, fs):
    """返回 (nTrial, nTau, nCell) 的"减局部基线"对齐响应。"""
    rows = []
    for c in cue:
        a = int(c) + int(round(BASE_S * fs))
        b = int(c) + int(round(TAUS[-1] * fs))
        if a < 0 or b > len(Y):
            continue
        base = Y[a]
        seg = np.empty((len(TAUS), Y.shape[1]))
        for k, tau in enumerate(TAUS):
            seg[k] = Y[int(c) + int(round(tau * fs))]
        rows.append(seg - base)
    return np.stack(rows) if len(rows) >= 10 else None


def peak_lat(curve, lo=0.0, hi=4.0):
    m = (TAUS >= lo) & (TAUS <= hi)
    if not m.any():
        return np.nan
    return float(TAUS[m][int(np.argmax(curve[m]))])


def main():
    ms = scan_cohort("ALB", phases=PHASES)
    out = {}
    acc = {k: [] for k in ("psth", "abspsth", "rms", "resp_psth", "dff_psth", "dff_abs")}
    cell_lat = []
    for b in ms:
        d = load_block(b["path"])
        fs = d["fs"]
        Y0 = np.nan_to_num(AC.dff(d["X"], fs), nan=0.0, posinf=0.0, neginf=0.0)
        ok = np.std(Y0, axis=0) > 1e-9
        if int(ok.sum()) < MIN_CELL:
            continue
        cue = np.sort(np.asarray(d.get("idx_cue", []), dtype=np.int64))
        if len(cue) < 10:
            continue
        Zc = AC.zscore_robust(AC.VARIANTS["P1"](Y0[:, ok], fs))
        Dff = Y0[:, ok]
        dff_scale = max(float(np.median(np.abs(Dff))), 1e-12)

        Rz = stack_resp(Zc, cue, fs)
        Rd = stack_resp(Dff / dff_scale, cue, fs)
        if Rz is None or Rd is None:
            continue
        z = np.median(Rz, axis=0)              # (nTau, nCell)
        zf = np.median(Rd, axis=0)

        psth = z.mean(1)
        absp = np.abs(z).mean(1)
        rms = np.linalg.norm(z, axis=1) / np.sqrt(z.shape[1])
        amp = np.abs(z).max(0)
        sel = amp > 2.0
        if sel.sum() < 10:
            sel = amp >= np.percentile(amp, 90)
        resp_psth = z[:, sel].mean(1)
        dff_psth = zf.mean(1)
        dff_abs = np.abs(zf).mean(1)
        # 逐细胞峰潜伏期（只用幅度过阈的细胞）
        sub = z[:, sel]
        cell_lat.append(TAUS[np.argmax(np.abs(sub), axis=0)])

        acc["psth"].append(psth)
        acc["abspsth"].append(absp)
        acc["rms"].append(rms)
        acc["resp_psth"].append(resp_psth)
        acc["dff_psth"].append(dff_psth)
        acc["dff_abs"].append(dff_abs)
        print(f"  {b['mouse']:<9s}{b['phase']:<9s} nCell={int(ok.sum())} "
              f"响应细胞={int(sel.sum())}  PSTH峰={peak_lat(psth):.2f}s  "
              f"RMS峰={peak_lat(rms):.2f}s")

    if not acc["psth"]:
        print("无数据")
        return
    M = {k: np.median(np.stack(v), axis=0) for k, v in acc.items()}
    lat = np.concatenate(cell_lat) if cell_lat else np.array([np.nan])

    print(f"\n=== 峰值潜伏期对照（{len(acc['psth'])} session）===")
    print(f"{'量':<26s}{'峰潜伏期':>10s}")
    for k, lbl in (("psth", "A. mean_i z(τ,i)  [PSTH]"),
                   ("abspsth", "B. mean_i |z(τ,i)|"),
                   ("rms", "C. ‖R‖/√nCell  [原口径]"),
                   ("resp_psth", "D. 仅响应细胞 PSTH"),
                   ("dff_psth", "E. ΔF/F PSTH（未 z 化）"),
                   ("dff_abs", "F. ΔF/F mean|·|（未 z 化）")):
        print(f"{lbl:<26s}{peak_lat(M[k]):>10.2f}")
    print(f"{'G. 逐细胞峰潜伏期中位':<26s}{np.median(lat):>10.2f}"
          f"   (IQR {np.percentile(lat,25):.2f}–{np.percentile(lat,75):.2f})")

    print(f"\n{'τ(s)':>6s}{'A PSTH':>10s}{'B |z|':>10s}{'C RMS':>10s}"
          f"{'D 响应细胞':>12s}{'E ΔF/F':>10s}")
    for tau in (-0.4, -0.2, 0.0, 0.2, 0.4, 0.6, 0.8, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 5.0):
        j = int(np.argmin(np.abs(TAUS - tau)))
        print(f"{TAUS[j]:6.2f}{M['psth'][j]:10.3f}{M['abspsth'][j]:10.3f}"
              f"{M['rms'][j]:10.3f}{M['resp_psth'][j]:12.3f}{M['dff_psth'][j]:10.3f}")

    out = {k: float(peak_lat(M[k])) for k in M}
    out["cell_lat_median"] = float(np.median(lat))
    out["cell_lat_iqr"] = [float(np.percentile(lat, 25)), float(np.percentile(lat, 75))]
    out["n_session"] = len(acc["psth"])
    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(out, indent=2, ensure_ascii=False))
    print(f"\n写出 {OUT}")


if __name__ == "__main__":
    main()

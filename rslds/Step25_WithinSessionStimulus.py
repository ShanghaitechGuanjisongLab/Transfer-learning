"""Step25_WithinSessionStimulus.py —— 同会话内不同刺激的构型对比（唯一能控制全部 session 间差异的设计）

为什么这个设计最强
  之前所有跨 session 对照（C3-b、硬件对照）都排除不掉"同一只鼠、同一批细胞、同一增益"
  这个混淆。而在 LAu / LAuW 会话里，**同一 session、同一批细胞、同一天、同一增益**，
  只有输入不同：
      LAu  = AudioOnly + LightOnly
      LAuW = AudioOnly + LightOnly + WaterOnly
  因此这里的任何差异**只能**来自输入，任何相似性也**只能**来自"构型与输入无关"。

  若构型与输入无关 ⇒ 它是内部状态（正是"吸引子"需要的）
  若构型随输入改变 ⇒ 它是刺激响应

统计量（全部在**细胞空间**，不做 PCA，避免基不稳定的问题）
  a_s = E[z_i | 刺激 s 的后线索窗] − E[z_i | 全帧]
  可分辨性 D = sqrt(mean_i [ (a_A,i − a_B,i)² / (SE_A,i² + SE_B,i²) ])
      D ≈ 1 ⇒ 两个构型只差在噪声水平（不可区分）
      D ≫ 1 ⇒ 系统性不同
  相似度 ρ = Pearson(a_A, a_B) over cells
  可靠性 = 同刺激奇偶试次分半的 ρ（作为 ρ 的上限参照）

判据（等价性，不是差异检验）
  D < 2 且 ρ_cross ≥ 0.8×可靠性 ⇒ 构型与输入无关 ✅
  D ≫ 1 或 ρ_cross ≪ 可靠性    ⇒ 构型随输入改变 ❌
  两者都不满足                  ⇒ 不可判定
"""
from __future__ import annotations

import json
import os
import time

import numpy as np

import attractor_core as AC
from rslds_data import load_block, scan_cohort

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "results", "_step25_within_stim.json")

POST = (0.0, 1.5)
MIN_TRIAL = 8
MIN_CELL = 40


def stim_vectors(Z, fs, cue, code):
    """返回 {stim: (a, SE)}，全部为细胞空间向量。"""
    allmean = Z.mean(0)
    out = {}
    for k in np.unique(code):
        sel = cue[code == k]
        if len(sel) < MIN_TRIAL:
            continue
        vecs = []
        for c in sel:
            a, b = int(c + POST[0] * fs), int(c + POST[1] * fs)
            if a >= 0 and b <= len(Z) and b > a:
                vecs.append(Z[a:b].mean(0))
        if len(vecs) < MIN_TRIAL:
            continue
        V = np.stack(vecs)
        out[int(k)] = (V.mean(0) - allmean,
                       V.std(0, ddof=1) / np.sqrt(len(V)), len(vecs), V)
    return out


def main():
    t0 = time.time()
    rows = []
    print(f"{'队列':<6s}{'鼠':<9s}{'设计':<7s}{'nCell':>6s}{'刺激对':<24s}"
          f"{'ρ_cross':>8s}{'ρ_rel':>7s}{'D':>6s}  判定")
    for cohort, tag in (("ALB", "ALB"), ("LightAudioBaseline", "LAB")):
        bs = [b for b in scan_cohort(cohort) if b["design"] in ("LAu", "LAuW")]
        for b in sorted(bs, key=lambda x: x["mouse"]):
            d = load_block(b["path"])
            fs = d["fs"]
            Y = np.nan_to_num(AC.dff(d["X"], fs), nan=0.0, posinf=0.0, neginf=0.0)
            ok = np.std(Y, axis=0) > 1e-9
            zl = np.asarray(d.get("z_layer", np.zeros(Y.shape[1], dtype=np.int64)))
            if zl.size != Y.shape[1]:
                zl = np.zeros(Y.shape[1], dtype=np.int64)
            cue_all = np.sort(np.asarray(d.get("idx_cue", []), dtype=np.int64))
            sc = np.asarray(d.get("stim_code", []), dtype=np.int64)
            names = d.get("stim_names", [])
            if len(cue_all) != len(sc) or len(names) < 2:
                continue

            for lname, lcode in (("MOp2/3", 1), ("MOp5", 2)):
                keep = ok & (zl == lcode)
                n = int(keep.sum())
                if n < MIN_CELL:
                    continue
                Z = AC.zscore_robust(AC.VARIANTS["P1"](Y, fs))[:, keep]
                order = np.argsort(cue_all)
                cue = cue_all[order]
                code = sc[order]
                S = stim_vectors(Z, fs, cue, code)
                keys = sorted(S)
                if len(keys) < 2:
                    continue

                # 同刺激奇偶分半的可靠性
                rel = []
                for k, (a, se, ntr, V) in S.items():
                    h = ntr // 2
                    if h < 4:
                        continue
                    a1 = V[:h].mean(0) - Z.mean(0)
                    a2 = V[h:2 * h].mean(0) - Z.mean(0)
                    r = np.corrcoef(a1, a2)[0, 1]
                    if np.isfinite(r):
                        rel.append(r)
                r_rel = float(np.median(rel)) if rel else np.nan

                for i in range(len(keys)):
                    for j in range(i + 1, len(keys)):
                        aA, seA, _, _ = S[keys[i]]
                        aB, seB, _, _ = S[keys[j]]
                        denom = seA ** 2 + seB ** 2
                        zc = (aA - aB) ** 2 / np.maximum(denom, 1e-12)
                        D = float(np.sqrt(np.mean(np.minimum(zc, 1e4))))
                        rho = float(np.corrcoef(aA, aB)[0, 1])
                        if not np.isfinite(r_rel) or r_rel < 0.5:
                            # 估计本身不可靠时，任何 D / ρ 的解读都无意义
                            verdict = "不可判定(估计不可靠)"
                        elif D < 2 and rho >= 0.8 * r_rel:
                            verdict = "输入无关 ✅"
                        elif D > 3 or rho < 0.5 * r_rel:
                            verdict = "随输入改变 ❌"
                        else:
                            verdict = "不确定"
                        nA = names[keys[i] - 1] if keys[i] - 1 < len(names) else str(keys[i])
                        nB = names[keys[j] - 1] if keys[j] - 1 < len(names) else str(keys[j])
                        rows.append(dict(cohort=tag, mouse=b["mouse"], design=b["design"],
                                         layer=lname, n_cell=n, stimA=nA, stimB=nB,
                                         rho=rho, rel=r_rel, D=D, verdict=verdict))
                        print(f"{tag:<6s}{b['mouse']:<9s}{b['design']:<7s}{n:6d}"
                              f"{nA+' vs '+nB:<24s}{rho:8.3f}{r_rel:7.3f}{D:6.2f}  {verdict}")

    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(rows, indent=2, ensure_ascii=False))

    if rows:
        from collections import Counter
        print(f"\n=== 汇总（{len(rows)} 个刺激对）===")
        for lname in ("MOp2/3", "MOp5"):
            g = [x for x in rows if x["layer"] == lname]
            if not g:
                continue
            print(f"  {lname:<8s} n={len(g):2d}  ρ_cross 中位 {np.median([x['rho'] for x in g]):.3f}"
                  f"  可靠性中位 {np.nanmedian([x['rel'] for x in g]):.3f}"
                  f"  D 中位 {np.median([x['D'] for x in g]):.2f}")
            for k, v in Counter(x["verdict"] for x in g).items():
                print(f"      {k}: {v}/{len(g)}")
    print(f"\n用时 {(time.time()-t0)/60:.1f} 分钟；写出 {OUT}")


if __name__ == "__main__":
    main()

"""Step5_CueDetectability.py —— cue 响应的「单试次可检测性」信号检测分析

问题
  cue 后峰值 < 3σ，究竟意味着「没有响应」还是「响应低于检测阈」？
  → 直接把 cue **前**与 cue **后**的峰值当成噪声分布/信号+噪声分布，做 ROC。

为什么需要交叉验证
  响应子空间若用全部 trial 的刺激后数据来定义，再在同一批数据上测峰值，
  会人为抬高响应。故按 trial 奇偶对半分：
      折 1：用奇数 trial 定子空间 → 在偶数 trial 上测峰值
      折 2：用偶数 trial 定子空间 → 在奇数 trial 上测峰值
  两折结果合并。

输出
  d'      = (μ_post − μ_pre)/合并 SD（在对数峰值上算）
  AUC     = P(peak_post > peak_pre)（Mann-Whitney）
  detect@5% = 在 cue 前峰值的 95 分位作为阈值时，cue 后峰值的超阈比例
  零模型：cue 时刻随机环形平移（≥5 s），重复 N_PERM 次
"""
from __future__ import annotations

import json
import os

import numpy as np
from scipy.stats import mannwhitneyu, wilcoxon

import attractor_core as AC
from rslds_data import load_block, scan_cohort

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "results", "_step5_cue_detect.json")

D = 2
# 2026-10-23 二次修正：此前「峰值在 2–3 s」是 idx_SoundOn 偏移造成的假象。
# 改用权威 cue 下标（idx_cue / CD1）后，响应确实在 0–1 s（与项目者经验一致）。
PRE = (-2.5, -1.0)
POST = (0.0, 1.5)
RESP = (-1.0, 3.0)
N_PERM = 100


def build_z(m):
    Y = AC.dff(m["X"], m["fs"])
    Y = np.nan_to_num(Y, nan=0.0, posinf=0.0, neginf=0.0)
    Y = Y[:, np.std(Y, axis=0) > 1e-9]
    return AC.zscore_robust(AC.VARIANTS["P1"](Y, m["fs"]))


def subspace(Z, cue, fs, trials, pre_abs=1.0):
    segs = []
    for j in trials:
        a, b = int(cue[j] + RESP[0] * fs), int(cue[j] + RESP[1] * fs)
        if a >= 0 and b <= len(Z):
            segs.append(Z[a:b])
    if len(segs) < 4:
        return None
    R = np.median(np.stack(segs), axis=0)
    i0 = max(1, int(pre_abs * fs))
    R = R - R[:i0].mean(axis=0, keepdims=True)
    _, _, Vt = np.linalg.svd(R, full_matrices=False)
    return Vt[:D].T


def pre_x0(X, cue, fs):
    segs = []
    for c in cue:
        a, b = int(c + PRE[0] * fs), int(c + PRE[1] * fs)
        if a >= 0 and b <= len(X) and b > a:
            segs.append(X[a:b])
    if not segs:
        return np.zeros(X.shape[1])
    return np.median(np.concatenate(segs), axis=0)


def peaks(X, cue, t_idx, x0, fs):
    """对给定 trial 下标，返回 (pre_peak, post_peak)。"""
    out = []
    for j in t_idx:
        a0, b0 = int(cue[j] + PRE[0] * fs), int(cue[j] + PRE[1] * fs)
        a1, b1 = int(cue[j] + POST[0] * fs), int(cue[j] + POST[1] * fs)
        if a0 < 0 or b1 > len(X) or b0 <= a0:
            continue
        m0 = np.linalg.norm(X[a0:b0] - x0, axis=1)
        m1 = np.linalg.norm(X[a1:b1] - x0, axis=1)
        if len(m0) < 3 or len(m1) < 3:
            continue
        out.append((float(m0.max()), float(m1.max())))
    return out


def stats_from_pairs(pairs):
    pre = np.array([p[0] for p in pairs])
    post = np.array([p[1] for p in pairs])
    if len(pre) < 8:
        return dict(n=len(pre), dp=np.nan, auc=np.nan, det05=np.nan, p_mwu=np.nan)
    lp, lq = np.log(pre), np.log(post)
    sd = np.sqrt(0.5 * (lp.var(ddof=1) + lq.var(ddof=1)))
    dp = float((lq.mean() - lp.mean()) / max(sd, 1e-12))
    u = mannwhitneyu(post, pre, alternative="greater")
    auc = float(u.statistic / (len(post) * len(pre)))
    thr = np.percentile(pre, 95)
    det = float(np.mean(post > thr))
    return dict(n=len(pre), dp=dp, auc=auc, det05=det, p_mwu=float(u.pvalue),
                pre_med=float(np.median(pre)), post_med=float(np.median(post)))


def run_session(m, cue, n_perm=N_PERM, seed=0):
    fs = m["fs"]
    Z = build_z(m)
    J = np.arange(len(cue))
    odd, even = J[J % 2 == 1], J[J % 2 == 0]

    pairs = []
    for tr, te in [(odd, even), (even, odd)]:
        U = subspace(Z, cue, fs, tr)
        if U is None:
            continue
        X = Z @ U
        x0 = pre_x0(X, cue, fs)
        pairs += peaks(X, cue, te, x0, fs)
    obs = stats_from_pairs(pairs)
    if not np.isfinite(obs["auc"]):
        return None

    # 零模型：cue 时刻整体环形平移
    rng = np.random.default_rng(seed)
    Uall = subspace(Z, cue, fs, J)
    if Uall is None:
        return None
    X = Z @ Uall
    x0 = pre_x0(X, cue, fs)
    null_auc, null_det = [], []
    for _ in range(n_perm):
        sh = rng.integers(int(5 * fs), len(Z) - int(6 * fs)) if len(Z) > 12 * fs else 1
        c2 = (cue + sh) % (len(Z) - int(6 * fs))
        pr = peaks(X, c2, J, x0, fs)
        st = stats_from_pairs(pr)
        if np.isfinite(st["auc"]):
            null_auc.append(st["auc"])
            null_det.append(st["det05"])
    obs["p_auc"] = float((1 + sum(a >= obs["auc"] for a in null_auc)) / (len(null_auc) + 1)) \
        if null_auc else np.nan
    obs["null_auc_med"] = float(np.median(null_auc)) if null_auc else np.nan
    obs["null_det_med"] = float(np.median(null_det)) if null_det else np.nan
    obs["null_det95"] = float(np.percentile(null_det, 95)) if null_det else np.nan
    obs["n_perm"] = len(null_auc)
    return obs


def main():
    ms = scan_cohort("ALB")
    by = {}
    for x in ms:
        by.setdefault(x["mouse"], {}).setdefault(x["phase"], []).append(x)

    rows = []
    PHASES = ["Learned", "Transfer", "Final"]
    print(f"{'鼠':<9s}{'阶段':<8s}{'cue':<8s}{'nTr':>4s}{'dprime':>8s}{'AUC':>7s}{'p':>7s}"
          f"{'det@5%':>8s}{'null det':>9s}{'null95':>8s}")
    for mouse in sorted(by):
        for phase in PHASES:
            if phase not in by[mouse]:
                continue
            m = load_block(by[mouse][phase][0]["path"])
            # 权威 cue 下标（Trials.SampleRange.Tag）；缺失时退回 CD1 上升沿。
            # 绝不用 idx_SoundOn / idx_LightOn（EventLog 派生，与钙不同步）。
            if len(m.get("idx_cue", [])) >= 12:
                cue = np.sort(m["idx_cue"])
                kind = "idx_cue"
            else:
                import event_align as EA
                cue = EA.channel_onsets(m["cd1"], m["fs"], min_gap_s=2.0)
                kind = "CD1"
            if len(cue) < 12:
                continue
            r = run_session(m, np.sort(cue))
            if r is None:
                print(f"{mouse:<9s}{phase:<8s}{kind:<8s}  数据不足")
                continue
            r.update(mouse=mouse, phase=phase, cue=kind)
            rows.append(r)
            print(f"{mouse:<9s}{phase:<8s}{kind:<8s}{r['n']:4d}{r['dp']:8.2f}{r['auc']:7.3f}"
                  f"{r['p_auc']:7.3f}{r['det05']:8.2f}{r['null_det_med']:9.2f}"
                  f"{r['null_det95']:8.2f}")

    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(rows, indent=2, ensure_ascii=False))
    print(f"\n写出 {OUT}")


if __name__ == "__main__":
    main()

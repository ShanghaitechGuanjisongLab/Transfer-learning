"""Step26_PreprocSensitivity.py —— 预处理敏感性：P0 / P1 / P2 三档

为什么要做（预注册 §2.2 / §8）
  钙成像原始荧光的漂移几乎全是"共模 + <0.02 Hz"。任何"慢动力学"结论都可能是漂移的产物，
  这是审稿人对钙成像动力学研究最标准的一击。三档预先声明：

    P0  原始（只做 ΔF/F + z-score）               —— 漂移全保留，最保守
    P1  只剔共模超慢成分（对群体均值 0.01 Hz 低通后逐细胞回归相减）—— **主分析**
    P2  因果 Butterworth 0.01 Hz 高通（τ≈16 s）   —— 最激进，明确删除 τ>16 s

判据（§8 停止规则）
  · 若某指标在 P1 或 P2 任一档下不成立 → 结论降级
  · 若 P1 与 P2 结论**相反** → 判"预处理依赖"，降级为"在 τ ≤ 16 s 尺度上……"，明写不可识别

预期
  M1（1 s 回复）与 ρ_rot（lag=16 ≈ 2 s）应远离漂移与截止 ⇒ 预期存活；
  τ1（9.8–17.3 s）落在 P2 截止附近 ⇒ 预期被截断；
  dist 在 P0 下可能变大（漂移污染 x*）。

只跑 P0 与 P2。P1 的结果直接复用 `_step16_layersplit.json`（dist / M1 ρ / p / ρ_rot）
与 `_step17b_layer_spectrum.json`（lag=16 的 τ 与 Q），避免重复计算。
"""
from __future__ import annotations

import json
import os
import time

import numpy as np

import attractor_core as AC
import Step10_TICA as T
import Step12_TICA_NonReversible as S12
import Step14_Unified as S14
from rslds_data import load_block, scan_cohort

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "results", "_step26_preproc.json")

PHASES = ["Learned", "Transfer", "Final"]
KPC = 10
LAG = 16
N_SIM = 30
MIN_CELL = 40
GROUPS = [("pooled", None), ("MOp2/3", 1), ("MOp5", 2)]
VARIANTS = ["P0", "P2"]


def analyze(Y, fs, cue, kpc, variant):
    Z = AC.zscore_robust(AC.VARIANTS[variant](Y, fs))
    X, _, _, _ = T.pcs(Z, kpc)
    X = X / max(np.median(np.linalg.norm(X, axis=1)), 1e-12)

    x0 = S14.pre_state(X, cue, fs)
    if x0 is None:
        return None
    c, A, S = S14.fit_var1(X)
    xs = S14.fixed_point(c, A)
    spread = float(np.median(np.linalg.norm(X - x0, axis=1)))
    dist = (float(np.linalg.norm(xs - x0) / max(spread, 1e-12))
            if np.all(np.isfinite(xs)) else np.nan)

    # M1
    rho, ntr = S14.trials_rho(X, cue, x0, fs)
    resp = []
    for ci in cue:
        a, b = int(ci), int(ci + S14.POST * fs)
        if a >= 0 and b <= len(X):
            resp.append(X[a:b] - x0)
    mu = np.median(np.stack(resp), axis=0) if len(resp) >= 5 else None
    rng = np.random.default_rng(0)
    null = []
    for _ in range(N_SIM):
        Xs = S14.sim_var1(X, cue, mu, c, A, S, rng)
        r2, _ = S14.trials_rho(Xs, cue, x0, fs)
        if np.isfinite(r2):
            null.append(r2)
    p = (float((1 + sum(v <= rho for v in null)) / (len(null) + 1))
         if null and np.isfinite(rho) else np.nan)

    # lag=16 谱（τ 与 Q，可靠口径）
    trials = [(int(cue[i]), int(cue[i + 1]) if i + 1 < len(cue) else len(Z))
              for i in range(len(cue))]
    trials = [(s, e) for s, e in trials if e - s > int(2 * fs)]
    segA, _ = T.split_trials(Z, trials, np.random.default_rng(0))
    C0a, Cta = S12.cov_pair(X, segA, LAG)
    tau1 = tau_ratio = Q = rho_rot = np.nan
    if C0a is not None:
        w, mag, tau = S12.spec(C0a, Cta, LAG, fs)
        tau1 = float(tau[0])
        tau_ratio = float(tau[0] / tau[1]) if len(tau) > 1 else np.nan
        best = 0.0
        for k in range(min(5, len(w))):
            if abs(w[k]) < 1e-12:
                continue
            best = max(best, float(abs(np.imag(w[k])) / max(abs(np.log(abs(w[k]))), 1e-12)))
        Q = best
        rho_rot = S12.rho_rot(Cta)

    return dict(dist=dist, rho=rho, p=p, tau1=tau1, tau_ratio=tau_ratio, Q=Q,
                rho_rot=rho_rot, n_trial=int(ntr), n_dim=int(X.shape[1]))


def main():
    t0 = time.time()
    ms = scan_cohort("ALB", phases=PHASES)
    ms.sort(key=lambda b: (b["mouse"], PHASES.index(b["phase"])))
    rows = []
    for b in ms:
        d = load_block(b["path"])
        fs = d["fs"]
        Y0 = np.nan_to_num(AC.dff(d["X"], fs), nan=0.0, posinf=0.0, neginf=0.0)
        ok = np.std(Y0, axis=0) > 1e-9
        zl = np.asarray(d.get("z_layer", np.zeros(Y0.shape[1], dtype=np.int64)))
        if zl.size != Y0.shape[1]:
            zl = np.zeros(Y0.shape[1], dtype=np.int64)
        cue = np.sort(np.asarray(d.get("idx_cue", []), dtype=np.int64))
        if len(cue) < 10:
            continue
        for v in VARIANTS:
            for gname, code in GROUPS:
                sel = ok if code is None else (ok & (zl == code))
                n = int(sel.sum())
                if n < MIN_CELL:
                    continue
                r = analyze(Y0[:, sel], fs, cue, min(KPC, n - 2), v)
                if r is None:
                    continue
                rows.append(dict(mouse=b["mouse"], phase=b["phase"], group=gname,
                                 variant=v, n_cell=n, **r))
        print(f"  {b['mouse']:<9s}{b['phase']:<9s} done  ({(time.time()-t0)/60:.1f} min)")

    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(rows, indent=2, ensure_ascii=False))

    # 载入 P1 的两个已有结果
    def load(p):
        fp = os.path.join(HERE, "results", p)
        return json.load(open(fp, encoding="utf-8")) if os.path.exists(fp) else []

    s16 = {(x["mouse"], x["phase"], x["group"]): x for x in load("_step16_layersplit.json")}
    s17b = {(x["mouse"], x["phase"], x["group"]): x for x in load("_step17b_layer_spectrum.json")}

    def get(v, m, ph, g, field):
        if v == "P1":
            if field in ("tau1", "tau_ratio", "Q"):
                return s17b.get((m, ph, g), {}).get(
                    {"tau1": "tau1", "tau_ratio": "tau_ratio", "Q": "Q_lag16"}[field], np.nan)
            return s16.get((m, ph, g), {}).get(field, np.nan)
        for x in rows:
            if x["mouse"] == m and x["phase"] == ph and x["group"] == g and x["variant"] == v:
                return x.get(field, np.nan)
        return np.nan

    keys = sorted({(x["mouse"], x["phase"], x["group"]) for x in rows})
    print(f"\n=== 三档对照（{len(keys)} 个 session×层）===")
    print(f"{'层':<8s}{'指标':<10s}{'P0 中位':>9s}{'P1 中位':>9s}{'P2 中位':>9s}"
          f"{'P1→P2 同向':>11s}")
    summary = {}
    for gname, _ in GROUPS:
        ks = [k for k in keys if k[2] == gname]
        if len(ks) < 5:
            continue
        for field in ("dist", "rho", "p", "rho_rot", "tau1", "tau_ratio", "Q"):
            v = {vv: np.array([get(vv, m, ph, g, field) for m, ph, g in ks], dtype=float)
                 for vv in ("P0", "P1", "P2")}
            same = ""
            if field in ("rho", "rho_rot"):
                s1 = np.sign(np.nanmedian(v["P1"]))
                s2 = np.sign(np.nanmedian(v["P2"]))
                same = "是" if s1 == s2 else "**相反**"
            print(f"{gname:<8s}{field:<10s}{np.nanmedian(v['P0']):9.3f}"
                  f"{np.nanmedian(v['P1']):9.3f}{np.nanmedian(v['P2']):9.3f}{same:>11s}")
            summary[f"{gname}|{field}"] = {vv: float(np.nanmedian(v[vv])) for vv in v}
        print()

    with open(os.path.join(HERE, "results", "_step26_summary.json"), "w", encoding="utf-8") as fh:
        fh.write(json.dumps(summary, indent=2, ensure_ascii=False))
    print(f"用时 {(time.time()-t0)/60:.1f} min；写出 {OUT}")


if __name__ == "__main__":
    main()

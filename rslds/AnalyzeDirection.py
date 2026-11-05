"""AnalyzeDirection.py —— A：图 1「轨迹方向」要素的替代定义（用已存 npz，不重拟合）

背景：按 **cue 对齐**的潜位移方向一致性已被否（Rayleigh R 中位 0.192，0/11 只鼠 p<0.05；
见 `CheckRayleigh.py` 与笔记 (v)）。这里试两个替代定义：

**(1) 换对齐事件：按行为（舔水）而不是按线索**
   舔水是动物自己产生的，不受刺激时刻约束。若"方向一致性"只对自发行为成立，
   那图 1 的语义应从"线索驱动"改成"行为驱动"。
   同时给"给水"做一份作对照。

**(2) 换读法：不看位移方向，看状态内动力学的**旋转**成分**
   线性系统 x_{t+1}=A_k x_t+b_k 的性质完全由 A_k 的特征值决定：
   · 实特征值 → 纯衰减/漂移（梯度流，有吸引子）
   · **共轭复特征值 → 旋转（振荡）**，周期 = 2π/(arg λ · fs)
   这是尺度不变量，且能回答"坑到底是坑还是涡"。

**(3) 追加：状态内舔水率的置换检验**（直接问"两个状态是不是就是舔/不舔"）

用法：  .venv\\Scripts\\python rslds\\AnalyzeDirection.py
"""

from __future__ import annotations

import glob
import json
import os

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
FIGDIR = os.path.join(HERE, "results", "fig1")
N_PERM = 500


def rayleigh(d):
    n = np.linalg.norm(d, axis=1)
    ok = n > 1e-12
    if ok.sum() < 3:
        return np.nan, np.nan, int(ok.sum())
    u = d[ok] / n[ok, None]
    R = float(np.linalg.norm(u.mean(0)))
    return R, float(np.exp(-ok.sum() * R ** 2)), int(ok.sum())


def disp_at(x, events, fs, a0, a1):
    n0, n1 = int(round(a0 * fs)), int(round(a1 * fs))
    ev = np.asarray(events, dtype=int)
    ev = ev[(ev + n1 < len(x)) & (ev + n0 >= 0)]
    if ev.size == 0:
        return np.zeros((0, x.shape[1]))
    return x[ev + n1] - x[ev + n0]


def lick_bouts(cd2, fs, thr=5.0, min_gap=0.8):
    lick = (cd2 > np.median(cd2) + thr).astype(np.int8)
    dd = np.diff(np.concatenate(([0], lick, [0])))
    st, en = np.where(dd == 1)[0], np.where(dd == -1)[0]
    ks, ke = [], []
    for s, e in zip(st, en):
        if ke and (s - ke[-1]) / fs < min_gap:
            ke[-1] = e
        else:
            ks.append(s); ke.append(e)
    return np.array(ks, dtype=int), np.array(ke, dtype=int), lick


def main():
    files = sorted(glob.glob(os.path.join(FIGDIR, "fig1_*_K2.npz")))
    rng = np.random.default_rng(0)

    print("=== (1) 换对齐事件：位移方向一致性（完整 5 维，窗 0→+3 s）===", flush=True)
    print("%-9s %6s | %7s %6s %5s | %7s %6s %5s | %7s %6s %5s | %8s"
          % ("鼠", "试次", "R(cue)", "p", "n", "R(舔)", "p", "n", "R(给水)", "p", "n", "cos(cue,舔)"),
          flush=True)
    tab1, tab2, tab3 = [], [], []
    for f in files:
        z = np.load(f)
        x, fs = z["x"], float(z["fs"])
        mouse = os.path.basename(f).split("_")[1]
        cue = z["idxTrialStart"].astype(int)
        rew = z["idxGiveWater"].astype(int)
        on, _, lick = lick_bouts(z["cd2"], fs)

        Rc, pc, nc = rayleigh(disp_at(x, cue, fs, 0.0, 3.0))
        Rl, pl, nl = rayleigh(disp_at(x, on, fs, 0.0, 3.0))
        Rw, pw, nw = rayleigh(disp_at(x, rew, fs, 0.0, 3.0))

        dc = disp_at(x, cue, fs, 0.0, 3.0).mean(0)
        dl = disp_at(x, on, fs, 0.0, 3.0).mean(0)
        cs = float(dc @ dl / (np.linalg.norm(dc) * np.linalg.norm(dl) + 1e-12))
        print("%-9s %6d | %7.3f %6.3f %5d | %7.3f %6.3f %5d | %7.3f %6.3f %5d | %8.2f"
              % (mouse, nc, Rc, pc, nc, Rl, pl, nl, Rw, pw, nw, cs), flush=True)
        tab1.append(dict(mouse=mouse, R_cue=Rc, p_cue=pc, n_cue=nc,
                         R_lick=Rl, p_lick=pl, n_lick=nl,
                         R_rew=Rw, p_rew=pw, n_rew=nw, cos_cue_lick=cs))

        # ---- (2) A_k 的特征值结构 ----
        As = z["As"]
        st = []
        for k in range(As.shape[0]):
            ev = np.linalg.eigvals(As[k])
            mag = np.abs(ev)
            # ⚠ 必须用**虚部>0** 判定"真复特征值"。用 angle>0 会把**实负特征值**（角=π）
            #   误判成复的，并算出一个假的短周期（2/fs）——踩过。
            sel = np.imag(ev) > 1e-6
            per = 2 * np.pi / (np.angle(ev)[sel] * fs) if sel.any() else np.array([])
            st.append(dict(k=k, lambda_max=float(mag.max()), n_ge1=int((mag >= 1).sum()),
                           has_complex=bool(sel.any()),
                           periods_s=sorted(float(v) for v in per if np.isfinite(v))))
        tab2.append(dict(mouse=mouse, states=st))

        # ---- (3) 状态内舔水率 ----
        zz = z["z"].astype(int)
        rate = [float(lick[zz == k].mean()) if (zz == k).any() else np.nan
                for k in range(As.shape[0])]
        obs = float(np.nanmax(rate) - np.nanmin(rate))
        null = np.empty(N_PERM)
        for i in range(N_PERM):
            lk = np.roll(lick, int(rng.integers(0, len(zz))))
            r = [lk[zz == k].mean() if (zz == k).any() else np.nan for k in range(As.shape[0])]
            null[i] = np.nanmax(r) - np.nanmin(r)
        pl2 = float((1 + (null >= obs).sum()) / (N_PERM + 1))
        tab3.append(dict(mouse=mouse, lick_rate_in_state=rate, spread=obs,
                         null95=float(np.percentile(null, 95)), p=pl2))

    print("\n=== (2) 状态内动力学：复特征值（旋转）还是实特征值（衰减）===", flush=True)
    for r in tab2:
        bits = []
        for s in r["states"]:
            tag = "复" if s["has_complex"] else "实"
            per = ("T=%s s" % ",".join("%.1f" % v for v in s["periods_s"][:2])) if s["periods_s"] else ""
            bits.append("k%d |λ|max=%.3f %s %s" % (s["k"], s["lambda_max"], tag, per))
        ncomp = sum(1 for s in r["states"] if s["has_complex"])
        print("  %-9s 复状态 %d/%d ： %s" % (r["mouse"], ncomp, len(r["states"]), " ; ".join(bits)),
              flush=True)

    print("\n=== (3) 状态内舔水率（置换 null 500 次）===", flush=True)
    print("%-9s %-22s %7s %7s %7s" % ("鼠", "各状态舔水率", "极差", "null95", "p"), flush=True)
    for r in tab3:
        print("%-9s %-22s %7.3f %7.3f %7.3f"
              % (r["mouse"], str(np.round(r["lick_rate_in_state"], 3).tolist()),
                 r["spread"], r["null95"], r["p"]), flush=True)

    out = dict(align=tab1, eigen=tab2, lick_state=tab3)
    with open(os.path.join(FIGDIR, "direction_alts.json"), "w", encoding="utf-8") as fh:
        json.dump(out, fh, ensure_ascii=False, indent=1)

    R = np.array([t["R_lick"] for t in tab1])
    P = np.array([t["p_lick"] for t in tab1])
    print("\n舔水对齐 R：中位 %.3f，范围 %.3f~%.3f；p<0.05 的鼠数 = %d/%d"
          % (np.median(R), R.min(), R.max(), (P < 0.05).sum(), len(R)), flush=True)
    R2 = np.array([t["R_cue"] for t in tab1])
    print("cue 对齐 R：中位 %.3f（对照）" % np.median(R2), flush=True)
    nc = sum(1 for r in tab2 for s in r["states"] if s["has_complex"])
    nt = sum(len(r["states"]) for r in tab2)
    print("复特征值状态：%d/%d（有旋转成分）" % (nc, nt), flush=True)
    nsig = sum(1 for r in tab3 if r["p"] < 0.05)
    print("状态内舔水率显著：%d/%d 只鼠" % (nsig, len(tab3)), flush=True)
    print("DONE", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

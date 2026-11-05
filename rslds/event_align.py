"""event_align.py —— 事件对齐工具（**唯一正确**的对齐方式）

数据来源（项目者说明，2026-10-23）
    数据库由两部分合并而成：
      · 成像记录：`BlockTags` 里的模拟通道（CD1 = cue，CD2 = 舔水/给水）
      · 行为学记录：`EventLog`、`Trials` 等
    钙成像通常**早于**行为学记录开始，且**晚于**行为学记录结束，
    两套记录的时钟也不完全同步 ⇒ 二者之间存在**逐会话不同**的偏移。

规则
    ① 能与钙数据直接对齐的，只有 `BlockTags`（CD 通道），**永远优先用它**
    ② `EventLog` 派生的下标（`idx_SoundOn` 等）**不得直接用于对齐**
    ③ 若某事件在 CD 通道里没有对应脉冲，则用**同一会话**内 CD1↔EventLog cue 的
       保序匹配估出偏移量，再把该偏移套用到其它 EventLog 事件上
    ④ 偏移量是**逐会话**的，绝不可硬编码（历史笔记里的 1.56 s 只是一次的截距）
"""
from __future__ import annotations

import numpy as np


def channel_onsets(v, fs, frac=0.5, min_gap_s=0.5):
    """模拟通道的上升沿。

    ⚠ CD 通道是**围绕 512 的模拟信号**（基线≈512，脉冲峰值≈750），
      不能用 0/1 绝对阈值。阈值按「基线 + frac ×(峰值−基线)」定义。
    """
    v = np.asarray(v, float)
    if v.size == 0:
        return np.array([], int)
    med = float(np.nanmedian(v))
    hi = float(np.nanmax(v))
    if not np.isfinite(hi) or hi - med < 1e-3 * max(abs(med), 1.0):
        return np.array([], int)
    thr = med + frac * (hi - med)
    b = (v > thr).astype(np.int8)
    on = np.where(np.diff(b) == 1)[0] + 1
    out = []
    for i in on:
        if not out or (i - out[-1]) > min_gap_s * fs:
            out.append(int(i))
    return np.array(out, int)


def match_offset(ev, on, fs, max_shift_s=20.0):
    """EventLog 事件下标 ↔ CD 上升沿，估出偏移（样本），正 = 事件下标偏早。

    优先**保序一一匹配**（两者数量相等时，最稳健）；
    数量不等时退回「每个事件找最近的沿」并要求位移 < max_shift_s。
    """
    ev = np.sort(np.asarray(ev, int))
    if len(ev) == 0 or len(on) == 0:
        return np.nan, np.nan, 0
    if len(ev) == len(on):
        d = (on - ev) / fs
        return float(np.median(d)), float(np.percentile(d, 75) - np.percentile(d, 25)), len(d)
    d = []
    for e in ev:
        j = int(np.argmin(np.abs(on - e)))
        s = (on[j] - e) / fs
        if abs(s) <= max_shift_s:
            d.append(s)
    if len(d) < max(5, len(ev) // 3):
        return np.nan, np.nan, len(d)
    d = np.array(d)
    return float(np.median(d)), float(np.percentile(d, 75) - np.percentile(d, 25)), len(d)


def aligned_onsets(block, fs, what="cue"):
    """返回可直接用于对齐钙数据的 cue / 给水 下标。

    what="cue"  → CD1 上升沿
    what="water"→ CD2 上升沿
    若 CD 通道不可用，则用 EventLog 事件 + 估出的会话偏移作兜底。
    """
    ch = {"cue": "cd1", "water": "cd2"}[what]
    ev_name = {"cue": "idx_SoundOn", "water": "idx_GiveWater"}[what]
    on = channel_onsets(block.get(ch, []), fs, min_gap_s=2.0 if what == "cue" else 0.2)
    n_ev = len(block.get(ev_name, []))
    info = dict(what=what, n_cd=len(on), n_evt=n_ev,
                offset_s=np.nan, offset_iqr_s=np.nan, source="cd")
    if len(on) >= 8:
        if n_ev:
            off, iqr, _ = match_offset(block[ev_name], on, fs)
            info.update(offset_s=off, offset_iqr_s=iqr)
        return on, info
    # 兜底：用 EventLog + 会话偏移
    ev = np.sort(np.asarray(block.get(ev_name, []), int))
    off = np.nan
    if what != "cue":
        c_on = channel_onsets(block.get("cd1", []), fs, min_gap_s=2.0)
        if len(c_on) >= 8 and len(block.get("idx_SoundOn", [])) >= 8:
            off, _, _ = match_offset(block["idx_SoundOn"], c_on, fs)
    if np.isfinite(off) and len(ev):
        info.update(source="event+offset")
        return np.round(ev + off * fs).astype(int), info
    info.update(source="event_raw")
    return ev, info

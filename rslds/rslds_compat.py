"""rslds_compat.py —— 兼容早期导出文件（缺 idxCue / zLayerCode）

背景
  `data/ALB` 里有 47 个 session 是**早期导出的**，缺两个字段：
    · `idxCue`      —— 权威 cue 帧号（Trials.SampleRange.Tag）
    · `zLayerCode`  —— 逐细胞层编码
  这两者缺失会让分析静默丢掉这些 session（`idx_cue` 为空 ⇒ cue<10 ⇒ 跳过）。

补齐方式（均有依据，不是猜测）
  · cue：`PreReg_Attractor.md` §3 规定"`idx_cue` 缺失时用 CD1 上升沿"。
        已实测 CD1 上升沿与 `idxCue` 偏移 0–0.13 s、990/990 < 0.5 s。
  · 层：MATLAB 侧用 `DS.Cells`+`DS.BlockSignals` 生成 `data/ALB_block_cell_layer.csv`
        （BlockUID, CellUID, ZLayer），按 (BlockUID, CellUID) 连接。
        实测老文件映射命中 550/550。
"""
from __future__ import annotations

import os

import h5py
import numpy as np
import pandas as pd

from rslds_data import load_block

LAYER_CSV = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                         "data", "ALB_block_cell_layer.csv")
LAYER_CODE = {"MOp2/3": 1, "MOp5": 2, "L2": 3}


def load_layer_map(path=LAYER_CSV):
    tab = pd.read_csv(path)
    return {(int(b), int(c)): LAYER_CODE.get(str(z), 0)
            for b, c, z in zip(tab.BlockUID, tab.CellUID, tab.ZLayer)}


def rising_edges(cd, fs, frac=0.5, min_gap_s=0.15):
    cd = np.asarray(cd, float)
    thr = np.median(cd) + frac * (cd.max() - np.median(cd))
    a = cd > thr
    e = np.where(np.diff(a.astype(np.int8)) == 1)[0] + 1
    if not len(e):
        return e
    gap = int(min_gap_s * fs)
    keep = [e[0]]
    for x in e[1:]:
        if x - keep[-1] >= gap:
            keep.append(x)
    return np.array(keep)


def load_compat(path, layer_map):
    """返回 load_block 的字典，并保证含 idx_cue 与 z_layer。"""
    d = load_block(path)
    with h5py.File(path, "r") as f:
        keys = set(k for k in f.keys() if not k.startswith("#"))
        src = []
        if "idxCue" not in keys:
            cd1 = np.asarray(f["CD1"]).ravel().astype(float)
            d["idx_cue"] = rising_edges(cd1, d["fs"]).astype(np.int64)
            src.append("cue=CD1")
        if "zLayerCode" not in keys:
            bu = int(np.asarray(f["blockUID"]).ravel()[0]) if "blockUID" in keys else -1
            d["z_layer"] = np.array([layer_map.get((bu, int(u)), 0)
                                     for u in d["cell_uid"]], dtype=np.int64)
            src.append("layer=CSV")
    d["compat_src"] = ";".join(src)
    return d

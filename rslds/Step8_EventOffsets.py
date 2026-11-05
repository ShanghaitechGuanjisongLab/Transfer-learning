"""Step8_EventOffsets.py —— 实测每个会话的 EventLog↔CD 偏移

验证项目者说明：钙记录通常早于行为学开始，故偏移应**为正**且**逐会话不同**。
"""
from __future__ import annotations

import json
import os

import numpy as np

import event_align as EA
from rslds_data import load_block, scan_cohort

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "results", "_step8_offsets.json")


def main():
    ms = scan_cohort("ALB")
    rows = []
    print(f"{'鼠':<9s}{'phase':<9s}{'nEvt':>5s}{'nCD1':>5s}{'nCD2':>5s}"
          f"{'cue偏移':>9s}{'IQR':>6s}{'CD2/事件':>9s}")
    for m in sorted(ms, key=lambda x: (x["mouse"], x["phase"] or "", x["datetime"])):
        if m["phase"] not in ("Learned", "Transfer", "Final"):
            continue
        b = load_block(m["path"])
        fs = b["fs"]
        on1 = EA.channel_onsets(b["cd1"], fs, min_gap_s=2.0)
        on2 = EA.channel_onsets(b["cd2"], fs, min_gap_s=0.2)
        off, iqr, n = EA.match_offset(b["idx_SoundOn"], on1, fs) if len(b["idx_SoundOn"]) else (np.nan, np.nan, 0)
        ratio = (len(on2) / len(b["idx_GiveWater"])) if len(b["idx_GiveWater"]) else np.nan
        rows.append(dict(mouse=m["mouse"], phase=m["phase"], datetime=m["datetime"],
                         n_evt=len(b["idx_SoundOn"]), n_cd1=len(on1), n_cd2=len(on2),
                         offset_s=off, offset_iqr=iqr, n_matched=n,
                         cd2_per_water=float(ratio)))
        print(f"{m['mouse']:<9s}{m['phase']:<9s}{len(b['idx_SoundOn']):5d}{len(on1):5d}{len(on2):5d}"
              f"{off:9.2f}{iqr:6.2f}{ratio:9.2f}")

    o = np.array([r["offset_s"] for r in rows if np.isfinite(r["offset_s"])])
    if len(o):
        print(f"\n偏移：n={len(o)}  中位 {np.median(o):+.2f}s  "
              f"范围 {o.min():+.2f} ~ {o.max():+.2f}s  正值占比 {np.mean(o>0)*100:.0f}%")
    with open(OUT, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(rows, indent=2, ensure_ascii=False))
    print(f"写出 {OUT}")


if __name__ == "__main__":
    main()

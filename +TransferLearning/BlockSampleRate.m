function r = BlockSampleRate(DS, B, bMouse)
%BLOCKSAMPLERATE 逐 block 估计真实采样率（Hz）
%
%   为什么不能用 `DateTimes.SeriesInterval`
%     它给**所有** block 存同一个值，无法区分本项目实测的两档采样率（≈8 Hz 与 ≈30 Hz）。
%     直接拿它当 `dt` 会在 25 min 的会话上累积出秒级时间漂移，舔水事件与钙信号错位。
%
%   估计法
%     同一 block 内，`diff(Trials.SampleRange.Tag)` 是**帧数**、`diff(Trials.Time)` 是**秒数**，
%     逐 trial 求比值，单位就是 Hz；取中位以抗离群。再按 (鼠, 采样率聚类) 取中位，抹掉单
%     block 噪声。聚类阈值 15 Hz —— 本项目只有 ≈8 Hz 与 ≈30 Hz 两档。
%
%   输入
%     DS     : 数据源（需有 `Trials` 表，含 `BlockUID`、`Time`、`SampleRange`）
%     B      : `Blocks` 表（用其 `BlockUID` 与行数）
%     bMouse : 每行 block 的鼠名（`TransferLearning.AlignBlockMeta` 的输出）
%   输出
%     r : 与 `B` 同行数的 double 列向量，单位 Hz
%
%   兜底：trial 太少或 `Tag` 非单调的 block 取 8 Hz。

r = nan(height(B), 1);
for i = 1:height(B)
	sel = DS.Trials.BlockUID == B.BlockUID(i);
	tt = DS.Trials.Time(sel);
	sr = DS.Trials.SampleRange(sel, :);
	if numel(tt) < 5 || ~istable(sr); continue; end
	n = min(numel(tt), height(sr));
	dR = diff(double(sr.Tag(1:n)));
	dT = seconds(diff(tt(1:n)));
	ok = dT > 0 & dR > 0;
	if sum(ok) < 4; continue; end
	r(i) = median(dR(ok) ./ dT(ok));
end

for m = reshape(unique(bMouse), 1, [])
	if m == ""; continue; end
	sel = find(bMouse == m & isfinite(r));
	if isempty(sel); continue; end
	for g = [false, true]
		s = sel((r(sel) >= 15) == g);
		if ~isempty(s); v = median(r(s)); r(s) = v; end
	end
end

r(isnan(r)) = 8;
end

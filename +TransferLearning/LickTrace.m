function [Lick, OnsetTime, TagTime] = LickTrace(TrialTags, Options)
% LickTrace  从标通道信号的CD2列提取二值化舔舐序列与舔舐起始时刻。
%
% TrialTags为DataSet.Trials.ResampledTags中若干行组成的cell数组，每个元素为table，
% 含CD1(刺激标记)与CD2(行为标通道)两列，行数一致。重采样后的标通道关于线索时刻
% 对称，行数n对应时间linspace(-3,3,n)，中点为线索onset(0 s)。
%
% 输出：
%   Lick      nTrial x nTag 逻辑矩阵，CD2超过阈值处为true
%   OnsetTime nTrial x 1，线索后首个超阈值时刻(秒，相对线索onset)，无舔舐为NaN
%   TagTime   1 x nTag，标通道时间轴(秒，相对线索onset)

arguments
	TrialTags cell
	Options.Window double = [-3 3]
	Options.ThresholdMultiple double = 3
end

nTrial = numel(TrialTags);
nTag = height(TrialTags{1});
TagTime = linspace(Options.Window(1), Options.Window(2), nTag);
PreCue = TagTime < 0;

Lick = false(nTrial, nTag);
OnsetTime = nan(nTrial, 1);
for i = 1:nTrial
	trace = double(TrialTags{i}.CD2(:).');
	baseline = median(trace(PreCue));
	noise = median(abs(trace(PreCue) - baseline));
	overThreshold = trace > baseline + max(Options.ThresholdMultiple * noise, 1);
	Lick(i, :) = overThreshold;
	k = find(overThreshold & ~PreCue, 1);
	if ~isempty(k)
		OnsetTime(i) = TagTime(k);
	end
end
end

function T = TrialLevelSlopePerMouse(sessions, options)
%TRIALLEVELSLOPEPERMOUSE 逐 trial 惩罚 sigmoid 求每鼠学习斜率
%
%   T = TransferLearning.Metrics.TrialLevelSlopePerMouse(sessions)
%
%   sessions：TransferLearning.BehaviorSessions.LightWaterLearningSessions() 的输出
%             （列 Group | Mouse | DateTime | Performance | Phase | Source | Session）
%
%   与 FitSigmoidPerMouse（会话均值最小二乘）不同，这里把每只鼠在该组会话内的
%   **全部 LightWater trial 的 0/1 结果**作为二项似然，会话序号（Session）作 block，
%   用 TransferLearning.FitPenalizedSigmoid(..., FixLowerZero=true) 求斜率 k
%   —— 即 Fig1C 的 trial 级惩罚版算法（下限固定 0、上限固定 1，斜率与中点自由）。
%
%   会话窗口沿用 sessions 里的既有筛选（Phase 区间、污染鼠剔除等），不额外过滤。
%   不足 2 个会话（k 不可辨识）的鼠被跳过。
%
%   输出列：Group | Mouse | NBlocks | NTrials | Slope | AtSlopeBoundary
%   （AtSlopeBoundary=true 表示拟合停在斜率上界，数值不可靠，绘图时可自行剔除）
arguments
	sessions table
	options.FixLowerZero (1,1) logical = true
end

pool = {TransferLearning.LightAudioBaseline(), "Naive"; ...
	TransferLearning.LAInterspersed(), "Naive"; ...
	TransferLearning.AudioLightBaseline(), "Transfer"; ...
	TransferLearning.Vacation7(), "7dayTransfer"};

groups = unique(string(sessions.Group), 'stable');
T = table(strings(0, 1), strings(0, 1), zeros(0, 1), zeros(0, 1), zeros(0, 1), false(0, 1), ...
	'VariableNames', {'Group', 'Mouse', 'NBlocks', 'NTrials', 'Slope', 'AtSlopeBoundary'});

for g = groups.'
	S = sessions(string(sessions.Group) == g, :);
	mice = unique(string(S.Mouse), 'stable');
	for m = mice.'
		Sm = S(string(S.Mouse) == m, :);
		dt = iNormDT(Sm.DateTime);
		blk = double(Sm.Session);
		DS = iFindDataSet(pool, g, m);
		if isempty(DS)
			continue;
		end
		Tq = DS.TableQuery(["Mouse", "DateTime", "Stimulus", "Behavior"], ...
			Mouse = m, Stimulus = "LightWater");
		if isempty(Tq)
			continue;
		end
		tDT = iNormDT(Tq.DateTime);
		y = double(Tq.Behavior);
		[~, loc] = ismember(tDT, dt);
		ok = isfinite(y) & loc > 0;
		if nnz(ok) < 2 || numel(unique(blk(loc(ok)))) < 2
			continue;
		end
		x = blk(loc(ok));
		fit = TransferLearning.FitPenalizedSigmoid(x, y(ok), FixLowerZero = options.FixLowerZero);
		T = [T; table(g, m, numel(unique(x)), nnz(ok), fit.Slope, fit.AtSlopeBoundary, ...
			'VariableNames', {'Group', 'Mouse', 'NBlocks', 'NTrials', 'Slope', 'AtSlopeBoundary'})]; %#ok<AGROW>
	end
end
end

function DS = iFindDataSet(pool, group, mouse)
DS = [];
for i = 1:size(pool, 1)
	if string(pool{i, 2}) ~= group
		continue;
	end
	if any(unique(string(pool{i, 1}.DateTimes.Mouse)) == mouse)
		DS = pool{i, 1};
		return;
	end
end
end

function dt = iNormDT(dt)
dt = datetime(dt);
if ~isempty(dt.TimeZone)
	dt.TimeZone = '';
end
end

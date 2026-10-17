function data = BuildChoiceDecoderDataDelayed()
% Build choice (hit/miss) decoder data on TransferLearning.ALDelayed
% (声水转光水，延迟任务) for English FigS2E / FigS2F / FigS2G.
%
% Choice decoder training pool: AudioLearnWater（声水训练全部会话），
%   AudioLearnWaterAlways（总是给水）不参与（用户口径），label = Behavior (hit = 1, miss = 0)。
% Choice weights: w = (m1 - m0) ./ sp^2 at t = +1.5 s（延迟任务名义给水时刻，
%   BuildCueChoiceDecoderData 的 1.0 s 取点的延迟版），每细胞一个值
%   （w > 0 = prefer hit，w < 0 = prefer miss）。类别平衡（多数类逐次下采样到少数类
%   数量后计算权重，100 次抽样取平均），使用局部随机流，不消耗全局 rng 流。
%
% Returns struct:
%   tVec      - time vector (s, TransferLearning.Xs)
%   idx1p5    - index of t = +1.5 s in the full time vector（TrialSignal 直接取点用）
%   choice{i} - struct('Mouse', 'cellUIDs', 'w1p5')

rng(42);
DS = TransferLearning.ALDelayed();
xs = TransferLearning.Xs;
if isduration(xs)
	xsSec = seconds(xs);
else
	xsSec = double(xs);
end
nTime = numel(xsSec);
[~, idx1p5] = min(abs(xsSec - 1.5));

T = DS.TableQuery(["Mouse", "TrialUID", "Stimulus"]);
T.Mouse = string(T.Mouse);
T.Stimulus = string(T.Stimulus);
T = T(T.Stimulus == "AudioLearnWater", :);
mice = unique(T.Mouse);

wStrm = RandStream('Threefry', 'Seed', 42);
choice = cell(0, 1);
for iM = 1:numel(mice)
	m = mice(iM);
	r = DS.QueryNTS(struct('Mouse', m, 'Stimulus', "AudioLearnWater"), UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns', ["Behavior"]);
	if isempty(r)
		continue;
	end
	if iscell(r)
		parts = r(~cellfun(@isempty, r));
		if isempty(parts)
			continue;
		end
		t = vertcat(parts{:});
	else
		t = r;
	end
	if isempty(t) || ~ismember('TrialSignal', string(t.Properties.VariableNames))
		continue;
	end
	t.CellUID = uint64(t.CellUID);
	t.TrialUID = uint64(t.TrialUID);
	beh = iTrialLabel(t, 'Behavior');
	if sum(beh == 1) < 3 || sum(beh == 0) < 3
		continue;
	end
	cellUIDs = unique(t.CellUID);
	if numel(cellUIDs) < 10
		continue;
	end
	F = iTrialCellTimeSlice(t, cellUIDs, idx1p5);
	if isempty(F)
		continue;
	end
	okB = isfinite(beh);
	w1p5 = iWeightBalanced(F(okB, :), beh(okB), wStrm, 100).';
	choice{end + 1, 1} = struct('Mouse', m, 'cellUIDs', cellUIDs, 'w1p5', w1p5); %#ok<AGROW>
end

data = struct('tVec', xsSec(:)', 'idx1p5', idx1p5, 'choice', {choice});
fprintf('BuildChoiceDecoderDataDelayed: choice mice = %d\n', numel(choice));
end

function F = iTrialCellTimeSlice(rawTbl, cellUIDs, idxT)
% trials × cells 矩阵，取第 idxT 个时间采样（同 BuildCueChoiceDecoderData 的单时刻口径）
tu = unique(rawTbl.TrialUID);
F = nan(numel(tu), numel(cellUIDs));
sig = double(rawTbl.TrialSignal);
for iR = 1:height(rawTbl)
	[tf, ci] = ismember(rawTbl.CellUID(iR), cellUIDs);
	if ~tf
		continue;
	end
	ti = find(tu == rawTbl.TrialUID(iR));
	F(ti, ci) = sig(iR, idxT);
end
end

function y = iTrialLabel(rawTbl, varName)
tu = unique(rawTbl.TrialUID);
y = nan(numel(tu), 1);
for iT = 1:numel(tu)
	v = rawTbl.(varName)(rawTbl.TrialUID == tu(iT));
	v = double(v);
	v = v(isfinite(v));
	if isempty(v)
		continue;
	end
	y(iT) = mode(v);
end
end

function w = iWeight(F, y)
m0 = mean(F(y == 0, :), 1);
m1 = mean(F(y == 1, :), 1);
s0 = std(F(y == 0, :), 0, 1);
s1 = std(F(y == 1, :), 0, 1);
sp = sqrt((s0.^2 + s1.^2) / 2);
sp(sp == 0) = 1;
w = (m1 - m0) ./ sp.^2;
end

function w = iWeightBalanced(F, y, strm, nDraws)
% 类别平衡权重（与 BuildCueChoiceDecoderData 的 iWeightBalanced 口径一致）：
% 每次抽样将多数类下采样到少数类数量后计算 iWeight，nDraws 次取平均；局部随机流 strm。
if nargin < 4 || isempty(nDraws)
	nDraws = 1;
end
idx1 = find(y == 1);
idx0 = find(y == 0);
nMin = min(numel(idx1), numel(idx0));
if nMin < 1
	w = nan(1, size(F, 2));
	return;
end
wAcc = zeros(1, size(F, 2));
yBal = [ones(nMin, 1); zeros(nMin, 1)];
for iDraw = 1:nDraws
	s1 = idx1(randperm(strm, numel(idx1), nMin));
	s0 = idx0(randperm(strm, numel(idx0), nMin));
	wAcc = wAcc + iWeight(F([s1; s0], :), yBal);
end
w = wAcc / nDraws;
end

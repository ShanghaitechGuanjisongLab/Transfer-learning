function data = BuildCueChoiceDecoderData()
% Build cue / choice decoder data (cfg2) for English Figure 2 panels B-E.
%
% Cue decoder (cfg2): trained on AudioOnly + LightOnly calibration blocks,
%   label = Cue (audio = 0, light = 1).
% Choice decoder (cfg2): trained on AudioWater blocks (Naive + Learned +
%   unlabeled), label = Behavior (hit = 1, miss = 0).
% Test set for both: Transfer LightWater (true held-out).
%
% Pipeline (identical to 信息编码/Cfg2Figure_15.m and WeightHistogram.m):
%   per-time-point naive-Gaussian GLM decoder, class-balanced training,
%   baseline (t < 0) subtraction, window -1 .. +1.5 s, rng(42), K = 5 folds.
% Choice weights: w = (m1 - m0) ./ sp^2 at t = 0.7 s, one value per cell
%   (w > 0 = prefer hit, w < 0 = prefer miss).
%
% Returns struct:
%   tVec      - time vector (s)
%   pk07      - index of t = 0.7 s in tVec
%   cue{i}    - struct('X2', trials x cells x time, 'Xt', 'y2', 'typ2', 'behT')
%   choice{i} - struct('Xtr2', 'Xte', 'behTr2', 'behTe', 'cellUIDs', 'w07')

rng(42);

DS = TransferLearning.AudioLightBaseline();
xs = TransferLearning.Xs;
if isduration(xs)
	xsSec = seconds(xs);
else
	xsSec = double(xs);
end
nTime = numel(xsSec);
tIdxFull = find((xsSec >= -1) & (xsSec <= 1.5));
tVec = xsSec(tIdxFull);
[~, pk07] = min(abs(tVec - 0.7));

Blk = DS.Blocks;
Blk.Design = string(Blk.Design);
DT = DS.DateTimes(:, {'DateTime', 'Mouse', 'Phase'});
DT.DateTime = datetime(DT.DateTime);
if ~isempty(DT.DateTime.TimeZone)
	DT.DateTime.TimeZone = '';
end
DT.Mouse = string(DT.Mouse);
DT.Phase = string(DT.Phase);
blkDT = datetime(Blk.DateTime);
if ~isempty(blkDT.TimeZone)
	blkDT.TimeZone = '';
end
ph = repmat("<missing>", height(Blk), 1);
for i = 1:height(Blk)
	idx = find(DT.DateTime == blkDT(i), 1);
	if ~isempty(idx)
		ph(i) = DT.Phase(idx);
	end
end
Blk.Phase = ph;
trainAW = Blk.BlockUID(Blk.Design == "AudioWater" & (ismember(Blk.Phase, ["Naive", "Learned"]) | ismissing(Blk.Phase)));
testLW = Blk.BlockUID(Blk.Design == "LightWater" & Blk.Phase == "Transfer");
calBlocks = Blk.BlockUID(ismember(Blk.Design, ["LAu", "LAuW"]) & ~ismember(Blk.Phase, ["Recall", "Final"]));
miceAll = unique(DT.Mouse);

% ---------- Cue cfg2 ----------
cue = cell(0, 1);
for iM = 1:numel(miceAll)
	m = miceAll(iM);
	trA = table(); trL = table(); teTrans = table();
	r = DS.QueryNTS(struct('Mouse', m, 'Stimulus', 'AudioOnly'), UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns', ["Behavior", "BlockUID"]);
	if ~isempty(r) && ~isempty(r{1})
		t = r{1};
		t = t(ismember(uint64(t.BlockUID), uint64(calBlocks)), :);
		if ~isempty(t)
			t.Cue = zeros(height(t), 1);
			t.Type = ones(height(t), 1);
			trA = t;
		end
	end
	r = DS.QueryNTS(struct('Mouse', m, 'Stimulus', 'LightOnly'), UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns', ["Behavior", "BlockUID"]);
	if ~isempty(r) && ~isempty(r{1})
		t = r{1};
		t = t(ismember(uint64(t.BlockUID), uint64(calBlocks)), :);
		if ~isempty(t)
			t.Cue = ones(height(t), 1);
			t.Type = 2 * ones(height(t), 1);
			trL = t;
		end
	end
	r = DS.QueryNTS(struct('Mouse', m, 'Stimulus', 'LightWater', 'Phase', 'Transfer'), UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns', ["Behavior", "BlockUID"]);
	if ~isempty(r) && ~isempty(r{1})
		teTrans = r{1};
		teTrans = teTrans(ismember(uint64(teTrans.BlockUID), uint64(testLW)), :);
	end
	okT = @(x) ~isempty(x) && ismember('TrialSignal', string(x.Properties.VariableNames));
	if ~okT(trA) || ~okT(trL) || ~okT(teTrans)
		continue;
	end
	trA = trA(~isnan(trA.Behavior), :);
	trL = trL(~isnan(trL.Behavior), :);
	teTrans = teTrans(~isnan(teTrans.Behavior), :);
	s2 = [trA; trL];
	y2 = iTrialLabel(s2, 'Cue');
	typ2 = iTrialLabel(s2, 'Type');
	if sum(y2 == 0) < 3 || sum(y2 == 1) < 3
		continue;
	end
	cellUIDs = uint64(unique([s2.CellUID; teTrans.CellUID]));
	if numel(cellUIDs) < 10
		continue;
	end
	X2 = iBuildTrialMatrix(s2, cellUIDs, tIdxFull);
	Xt = iBuildTrialMatrix(teTrans, cellUIDs, tIdxFull);
	if isempty(X2) || isempty(Xt)
		continue;
	end
	bI = find(tVec < 0);
	X2 = iBaselineNorm(X2, bI);
	Xt = iBaselineNorm(Xt, bI);
	cue{end + 1, 1} = struct('Mouse', m, 'X2', X2, 'Xt', Xt, 'y2', y2, 'typ2', typ2, 'behT', iTrialLabel(teTrans, 'Behavior'));
end

% ---------- Choice cfg2 ----------
choice = cell(0, 1);
for iM = 1:numel(miceAll)
	m = miceAll(iM);
	tr2 = table(); testTbl = table();
	r = DS.QueryNTS(struct('Mouse', m, 'Stimulus', 'AudioWater'), UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns', ["Behavior", "BlockUID"]);
	if ~isempty(r) && ~isempty(r{1})
		t = r{1};
		t = t(ismember(uint64(t.BlockUID), uint64(trainAW)), :);
		if ~isempty(t)
			tr2 = t;
		end
	end
	r = DS.QueryNTS(struct('Mouse', m, 'Stimulus', 'LightWater', 'Phase', 'Transfer'), UniExp.Flags.ZScore, 1:nTime, 'ExtraColumns', ["Behavior", "BlockUID"]);
	if ~isempty(r) && ~isempty(r{1})
		testTbl = r{1};
		testTbl = testTbl(ismember(uint64(testTbl.BlockUID), uint64(testLW)), :);
	end
	okT = @(x) ~isempty(x) && ismember('TrialSignal', string(x.Properties.VariableNames));
	if ~okT(tr2) || ~okT(testTbl)
		continue;
	end
	tr2 = tr2(~isnan(tr2.Behavior), :);
	testTbl = testTbl(~isnan(testTbl.Behavior), :);
	if isempty(tr2) || isempty(testTbl)
		continue;
	end
	cellUIDs = uint64(unique([tr2.CellUID; testTbl.CellUID]));
	if numel(cellUIDs) < 10
		continue;
	end
	Xtr2 = iBuildTrialMatrix(tr2, cellUIDs, tIdxFull);
	Xte = iBuildTrialMatrix(testTbl, cellUIDs, tIdxFull);
	if isempty(Xtr2) || isempty(Xte)
		continue;
	end
	bI = find(tVec < 0);
	Xtr2 = iBaselineNorm(Xtr2, bI);
	Xte = iBaselineNorm(Xte, bI);
	behTr2 = iTrialLabel(tr2, 'Behavior');
	behTe = iTrialLabel(testTbl, 'Behavior');
	if sum(behTr2 == 1) < 3 || sum(behTr2 == 0) < 3
		continue;
	end
	okB = ~isnan(behTr2);
	w07 = iWeight(Xtr2(okB, :, pk07), behTr2(okB)).';
	choice{end + 1, 1} = struct('Mouse', m, 'Xtr2', Xtr2, 'Xte', Xte, 'behTr2', behTr2, 'behTe', behTe, 'cellUIDs', cellUIDs, 'w07', w07);
end

data = struct('tVec', tVec, 'pk07', pk07, 'cue', {cue}, 'choice', {choice});
fprintf('BuildCueChoiceDecoderData: cue mice = %d, choice mice = %d\n', numel(cue), numel(choice));
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

function X = iBuildTrialMatrix(rawTbl, cellUIDs, tIdx)
sig = double(rawTbl.TrialSignal);
sig = sig(:, tIdx);
nts = table(uint64(rawTbl.CellUID), uint64(rawTbl.TrialUID), 'VariableNames', {'CellUID', 'TrialUID'});
sigCell = cell(size(sig, 1), 1);
for i = 1:size(sig, 1)
	sigCell{i} = sig(i, :);
end
nts.Signal = sigCell;
nts = nts(ismember(nts.CellUID, cellUIDs), :);
if isempty(nts)
	X = [];
	return;
end
tu = unique(nts.TrialUID);
X = zeros(numel(tu), numel(cellUIDs), size(sig, 2));
for iT = 1:numel(tu)
	rows = nts(nts.TrialUID == tu(iT), :);
	[~, loc] = ismember(rows.CellUID, cellUIDs);
	for iR = 1:height(rows)
		ci = loc(iR);
		if ci > 0
			X(iT, ci, :) = rows.Signal{iR};
		end
	end
end
end

function X = iBaselineNorm(X, baseIdx)
mu = mean(X(:, :, baseIdx), 3);
X = X - mu;
end

function y = iTrialLabel(rawTbl, varName)
tu = unique(uint64(rawTbl.TrialUID));
y = nan(numel(tu), 1);
for iT = 1:numel(tu)
	v = rawTbl.(varName)(uint64(rawTbl.TrialUID) == tu(iT));
	y(iT) = mode(v);
end
end

% 中文图333A：模仿英文图2A，只画2个代表性细胞
% - 一个取自声光迁移组：Learned AudioWater + Transfer LightWater，各3个活跃回合
% - 一个取自Naive LightWater：同一会话3个回合，至少1个活跃且至少1个1s z-score为负

if ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

xs = TransferLearning.Xs;
if isduration(xs)
	xsSec = seconds(xs);
else
	xsSec = double(xs);
end

plotMask = (xsSec >= -1) & (xsSec <= 2);
xsPlot = xsSec(plotMask);
baseMask = (xsSec >= -3) & (xsSec < 0);
kSigma = 3;
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
	error('中文图333A:No1s', 'Cannot find sample close to 1s.');
end

ALB = TransferLearning.AudioLightBaseline();
LAB = TransferLearning.LightAudioBaseline();
LAI = TransferLearning.LAInterspersed();
[naiveRep, transferRep] = iPickRepresentatives(LAB, LAI, ALB, baseMask, idx1s, kSigma);

palette = TransferLearning.FigurePalette(3);
colorNaive = palette(1, :);
colorLearned = palette(2, :);
colorTransfer = palette(3, :);

f = figure('Color', 'w', 'Name', '中文图333A 两个代表性细胞回合曲线');
f.Units = 'centimeters';
f.Position(3:4) = [9, 4];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 9, 4];
f.PaperSize = [9, 4];

tlo = tiledlayout(f, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile(tlo, 1);
iPlotTrialSet(ax1, xsPlot, naiveRep.Signals(:, plotMask), colorNaive);
title(ax1, sprintf('Naive\nCell %u', naiveRep.CellUID), 'FontSize', 6, 'FontWeight', 'normal');
ylabel(ax1, 'z-score', 'FontSize', 6);

ax2 = nexttile(tlo, 2);
iPlotTrialSet(ax2, xsPlot, transferRep.LearnedSignals(:, plotMask), colorLearned);
title(ax2, sprintf('Learned\nCell %u', transferRep.CellUID), 'FontSize', 6, 'FontWeight', 'normal');
ax2.YAxis.Visible = false;

ax3 = nexttile(tlo, 3);
iPlotTrialSet(ax3, xsPlot, transferRep.TransferSignals(:, plotMask), colorTransfer);
title(ax3, sprintf('Transfer\nCell %u', transferRep.CellUID), 'FontSize', 6, 'FontWeight', 'normal');
ax3.YAxis.Visible = false;

allAxes = [ax1, ax2, ax3];
for ax = allAxes
	ax.FontSize = 6;
	ax.LineWidth = 1;
	ax.TickDir = 'out';
	ax.FontName = 'Segoe UI Emoji';
	box(ax, 'off');
	grid(ax, 'off');
	xlim(ax, [xsPlot(1), xsPlot(end)]);
	xline(ax, 0, ':k', 'LineWidth', 1, 'HandleVisibility', 'off');
	xline(ax, 1, '-k', 'LineWidth', 1, 'HandleVisibility', 'off');
	ax.XTick = [0 1];
	if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
		ax.Toolbar.Visible = 'off';
	end
end

xlabel(tlo, 'Time (s)', 'FontSize', 6);

ax1.XTickLabel = {"💡", "💧"};
ax2.XTickLabel = {"🔊", "💧"};
ax3.XTickLabel = {"💡", "💧"};

MATLAB.Graphics.UnifyAxesLims(allAxes, @ylim);

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = fullfile(outDirUNC, '中文图Fig333A_TwoRepresentativeCellTraces.svg');
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig333A_NaiveRepresentative', naiveRep);
assignin('base', 'Fig333A_TransferRepresentative', transferRep);

function [naiveRep, transferRep] = iPickRepresentatives(LAB, LAI, ALB, baseMask, idx1s, kSigma)
naiveCandidates = iListNaiveCandidates(LAB, LAI, baseMask, idx1s, kSigma);
transferCandidates = iListTransferCandidates(ALB, baseMask, idx1s, kSigma);

bestScore = -inf;
naiveRep = struct();
transferRep = struct();
for iT = 1:numel(transferCandidates)
	tCand = transferCandidates(iT);
	naiveMeans = [naiveCandidates.Mean1s];
		maxOtherTrial1s = max([tCand.LearnedV1Selected(:); tCand.TransferV1Selected(:)], [], 'omitnan');
		naivePeak1s = arrayfun(@(c) max(c.V1Selected, [], 'omitnan'), naiveCandidates);
		validNaive = naiveMeans < tCand.TransferMean1s & naiveMeans < tCand.LearnedMean1s & tCand.TransferMean1s < tCand.LearnedMean1s & naivePeak1s > maxOtherTrial1s;
	if ~any(validNaive)
		continue;
	end
	idxNaive = find(validNaive);
	for iN = reshape(idxNaive, 1, [])
		nCand = naiveCandidates(iN);
		score = nCand.Score + tCand.Score + 2 * (tCand.LearnedMean1s - nCand.Mean1s) + (tCand.TransferMean1s - nCand.Mean1s);
		if score > bestScore
			bestScore = score;
			naiveRep = nCand;
			transferRep = tCand;
		end
	end
	end

	if ~isfield(naiveRep, 'CellUID') || ~isfield(transferRep, 'CellUID')
		error('中文图333A:NoOrderedRepresentatives', 'Cannot find representatives satisfying Naive 1 s mean < Transfer 1 s mean < Learned 1 s mean.');
	end
end

function candidates = iListTransferCandidates(DS, baseMask, idx1s, kSigma)
Learn = iRepresentativeSessionNTS(DS, struct('Phase', 'Learned', 'Stimulus', 'AudioWater'), "latest");
Tran = iRepresentativeSessionNTS(DS, struct('Phase', 'Transfer', 'Stimulus', 'LightWater'), "earliest");

commonCells = intersect(unique(uint64(Learn.CellUID)), unique(uint64(Tran.CellUID)));
if isempty(commonCells)
	error('中文图333A:NoTransferCommonCells', 'No common cells across Learned AudioWater and Transfer LightWater sessions.');
end

	candidates = repmat(iEmptyTransferCandidate(), 0, 1);
	for cellUID = reshape(commonCells, 1, [])
		rowsL = uint64(Learn.CellUID) == cellUID;
		rowsT = uint64(Tran.CellUID) == cellUID;
		sigL = double(Learn.TrialSignal(rowsL, :));
		sigT = double(Tran.TrialSignal(rowsT, :));
		if size(sigL, 1) < 3 || size(sigT, 1) < 3
			continue;
		end
		actL = iActiveTrials(sigL, baseMask, idx1s, kSigma);
		actT = iActiveTrials(sigT, baseMask, idx1s, kSigma);
		if sum(actL) < 3 || sum(actT) < 3
			continue;
		end
		v1L = sigL(:, idx1s);
		v1T = sigT(:, idx1s);
		idxPickL = iTopK(v1L, actL, 3, 'descend');
		idxPickT = iTopK(v1T, actT, 3, 'descend');
		learnedMean1s = mean(v1L(idxPickL), 'omitnan');
		transferMean1s = mean(v1T(idxPickT), 'omitnan');
		if ~(learnedMean1s > transferMean1s)
			continue;
		end
		rep = iEmptyTransferCandidate();
		rep.CellUID = uint64(cellUID);
		rep.Mouse = string(Learn.Mouse(find(rowsL, 1, 'first')));
		rep.LearnedDateTime = Learn.DateTime(find(rowsL, 1, 'first'));
		rep.TransferDateTime = Tran.DateTime(find(rowsT, 1, 'first'));
		rep.LearnedTrialUID = uint64(Learn.TrialUID(rowsL));
		rep.TransferTrialUID = uint64(Tran.TrialUID(rowsT));
		rep.LearnedPickedTrialUID = uint64(Learn.TrialUID(find(rowsL))); rep.LearnedPickedTrialUID = rep.LearnedPickedTrialUID(idxPickL);
		rep.TransferPickedTrialUID = uint64(Tran.TrialUID(find(rowsT))); rep.TransferPickedTrialUID = rep.TransferPickedTrialUID(idxPickT);
		rep.LearnedSignals = sigL(idxPickL, :);
		rep.TransferSignals = sigT(idxPickT, :);
		rep.LearnedV1Selected = v1L(idxPickL);
		rep.TransferV1Selected = v1T(idxPickT);
		rep.LearnedMean1s = learnedMean1s;
		rep.TransferMean1s = transferMean1s;
		rep.Score = learnedMean1s + transferMean1s;
		candidates(end + 1) = rep; %#ok<AGROW>
	end

	if isempty(candidates)
		error('中文图333A:NoTransferRepresentative', 'Cannot find a transfer-group cell whose Learned 1 s mean exceeds its Transfer 1 s mean while keeping 3 active trials in both sessions.');
	end
end

function candidates = iListNaiveCandidates(LAB, LAI, baseMask, idx1s, kSigma)
	joinedLAB = iRepresentativeSessionNTS(LAB, struct('Phase', 'Naive', 'Stimulus', 'LightWater'), "earliest");
	joinedLAB.Source = repmat("LAB", height(joinedLAB), 1);

	badNaive = iFindMiceWithAudioWaterInPhase(LAI, "Naive");
	qNaiveLAI = struct('Phase', 'Naive', 'Stimulus', 'LightWater');
	qNaiveLAI.Mouse = iMiceInPhaseStimulus(LAI, "Naive", "LightWater", badNaive);
	joinedLAI = iRepresentativeSessionNTS(LAI, qNaiveLAI, "earliest");
	joinedLAI.Source = repmat("LAI", height(joinedLAI), 1);

	joined = [joinedLAB; joinedLAI];
	allCells = unique(uint64(joined.CellUID));
	if isempty(allCells)
		error('中文图333A:NoNaiveCells', 'No Naive LightWater cells found.');
	end

	candidates = repmat(iEmptyNaiveCandidate(), 0, 1);
	for cellUID = reshape(allCells, 1, [])
		rows = uint64(joined.CellUID) == cellUID;
		sig = double(joined.TrialSignal(rows, :));
		if size(sig, 1) < 3
			continue;
		end
		act = iActiveTrials(sig, baseMask, idx1s, kSigma);
		v1 = sig(:, idx1s);
		neg = isfinite(v1) & (v1 < 0);
		if ~any(act) || ~any(neg)
			continue;
		end
		idxPick = iPickNaiveTrials(v1, act, neg);
		if numel(idxPick) < 3
			continue;
		end
		rep = iEmptyNaiveCandidate();
		rep.CellUID = uint64(cellUID);
		rep.Mouse = string(joined.Mouse(find(rows, 1, 'first')));
		rep.DateTime = joined.DateTime(find(rows, 1, 'first'));
		rep.Source = string(joined.Source(find(rows, 1, 'first')));
		trialUID = uint64(joined.TrialUID(rows));
		rep.PickedTrialUID = trialUID(idxPick);
		rep.Signals = sig(idxPick, :);
		rep.V1Selected = v1(idxPick);
		rep.Mean1s = mean(v1(idxPick), 'omitnan');
		rep.IsMeanInactive = iIsMeanInactive(rep.Signals, baseMask, idx1s, kSigma);
		rep.Score = max(v1(act), [], 'omitnan') - min(v1(neg), [], 'omitnan') + range(v1(idxPick));
		if ~rep.IsMeanInactive
			continue;
		end
		candidates(end + 1) = rep; %#ok<AGROW>
	end

	if isempty(candidates)
		error('中文图333A:NoNaiveRepresentative', 'Cannot find a Naive LightWater cell with at least one active and one negative-1s trial in the same session.');
	end
end

function joined = iRepresentativeSessionNTS(DS, queryStruct, pickMode)
	T = DS.TableQuery(["Mouse", "DateTime", "TrialUID", "TrialIndex"], queryStruct);
	if isempty(T)
		joined = T;
		joined.TrialSignal = zeros(0, numel(TransferLearning.Xs));
		joined.CellUID = uint64.empty(0, 1);
		return;
	end
	T.Mouse = string(T.Mouse);
	T.DateTime = iNormalizeDateTime(T.DateTime);
	if pickMode == "latest"
		DT = groupsummary(T(:, ["Mouse", "DateTime"]), "Mouse", "max", "DateTime");
		DT.Properties.VariableNames{end} = 'PickedDateTime';
	else
		DT = groupsummary(T(:, ["Mouse", "DateTime"]), "Mouse", "min", "DateTime");
		DT.Properties.VariableNames{end} = 'PickedDateTime';
	end
	T = innerjoin(T, DT, 'Keys', 'Mouse');
	T = T(T.DateTime == T.PickedDateTime, ["Mouse", "DateTime", "TrialUID", "TrialIndex"]);

	ntsCell = DS.QueryNTS(queryStruct, UniExp.Flags.ZScore, 1:24);
	nts = ntsCell{1};
	joined = innerjoin(nts, T, 'Keys', 'TrialUID');
	joined = sortrows(joined, ["Mouse", "DateTime", "TrialIndex", "CellUID"]);
end

function mask = iActiveTrials(sig, baseMask, idx1s, kSigma)
	baseMu = mean(sig(:, baseMask), 2, 'omitnan');
	baseSd = std(sig(:, baseMask), 0, 2, 'omitnan');
	v1 = sig(:, idx1s);
	mask = isfinite(v1) & isfinite(baseMu) & isfinite(baseSd) & (v1 > (baseMu + kSigma * baseSd));
end

function idxPick = iTopK(values, mask, k, direction)
	idx = find(mask);
	v = values(idx);
	[~, ord] = sort(v, direction, 'MissingPlacement', 'last');
	idxPick = idx(ord(1:k));
end

function idxPick = iPickNaiveTrials(v1, act, neg)
	idxAct = find(act);
	[~, ordAct] = sort(v1(idxAct), 'descend', 'MissingPlacement', 'last');
	idxNeg = find(neg);
	[~, ordNeg] = sort(v1(idxNeg), 'ascend', 'MissingPlacement', 'last');
	idxPick = unique([idxAct(ordAct(1)); idxNeg(ordNeg(1))], 'stable');
	idxPick = idxPick(:);
	remain = setdiff(find(isfinite(v1)), idxPick, 'stable');
	if isempty(remain)
		return;
	end
	[~, ordRemain] = sort(abs(v1(remain)), 'descend', 'MissingPlacement', 'last');
	extraIdx = remain(ordRemain(1:min(2, numel(ordRemain))));
	idxPick = [idxPick; extraIdx(:)];
	idxPick = idxPick(1:min(3, numel(idxPick)));
end

function iPlotTrialSet(ax, xsPlot, sig, colorMain)
	hold(ax, 'on');
	trialColor = 1 - (1 - colorMain) * 0.45;
	for i = 1:size(sig, 1)
		h = plot(ax, xsPlot, sig(i, :), '-', 'Color', trialColor, 'LineWidth', 0.5);
		setappdata(h, 'TransferLearningPreserveLineWidth', true);
	end
	hMean = plot(ax, xsPlot, mean(sig, 1, 'omitnan'), '-', 'Color', colorMain, 'LineWidth', 1);
	setappdata(hMean, 'TransferLearningPreserveLineWidth', true);
	ax.YTick = [];
end


function mice = iMiceInPhaseStimulus(DS, phaseName, stimulusName, excludeMice)
	T = DS.TableQuery("Mouse", Phase=phaseName, Stimulus=stimulusName);
	if isempty(T)
		mice = string.empty(0, 1);
		return;
	end
	mice = unique(string(T.Mouse));
	mice = mice(~ismember(mice, string(excludeMice(:))));
end

function badMice = iFindMiceWithAudioWaterInPhase(DS, phaseName)
	T = DS.TableQuery(["Mouse", "BlockUID"], Phase=phaseName);
	if isempty(T)
		badMice = strings(0, 1);
		return;
	end
	Tr = DS.Trials;
	TrStim = string(Tr.Stimulus);
	TrBU = uint64(Tr.BlockUID);
	T.Mouse = string(T.Mouse);
	blkBU = uint64(T.BlockUID);
	mice = unique(T.Mouse);
	bad = false(size(mice));
	for i = 1:numel(mice)
		bu = blkBU(T.Mouse == mice(i));
		rows = ismember(TrBU, bu);
		bad(i) = any(TrStim(rows) == "AudioWater");
	end
	badMice = mice(bad);
end

function dt = iNormalizeDateTime(dt)
	if isdatetime(dt)
		if ~isempty(dt.TimeZone)
			dt.TimeZone = '';
		end
		return;
	end
	if isduration(dt)
		dt = datetime(dt);
	else
		dt = datetime(dt, 'ConvertFrom', 'datenum');
	end
	if isdatetime(dt) && ~isempty(dt.TimeZone)
		dt.TimeZone = '';
	end
end

function tf = iIsMeanInactive(sig, baseMask, idx1s, kSigma)
	meanTrace = mean(sig, 1, 'omitnan');
	baseMu = mean(meanTrace(baseMask), 'omitnan');
	baseSd = std(meanTrace(baseMask), 0, 2, 'omitnan');
	thr = baseMu + kSigma * baseSd;
	tf = isfinite(meanTrace(idx1s)) && isfinite(thr) && (meanTrace(idx1s) <= thr);
end

function rep = iEmptyTransferCandidate()
	rep = struct( ...
		'CellUID', uint64(0), ...
		'Mouse', "", ...
		'LearnedDateTime', NaT, ...
		'TransferDateTime', NaT, ...
		'LearnedTrialUID', uint64.empty(0, 1), ...
		'TransferTrialUID', uint64.empty(0, 1), ...
		'LearnedPickedTrialUID', uint64.empty(0, 1), ...
		'TransferPickedTrialUID', uint64.empty(0, 1), ...
		'LearnedSignals', zeros(0, 0), ...
		'TransferSignals', zeros(0, 0), ...
		'LearnedV1Selected', zeros(0, 1), ...
		'TransferV1Selected', zeros(0, 1), ...
		'LearnedMean1s', NaN, ...
		'TransferMean1s', NaN, ...
		'Score', NaN);
end

function rep = iEmptyNaiveCandidate()
	rep = struct( ...
		'CellUID', uint64(0), ...
		'Mouse', "", ...
		'DateTime', NaT, ...
		'Source', "", ...
		'PickedTrialUID', uint64.empty(0, 1), ...
		'Signals', zeros(0, 0), ...
		'V1Selected', zeros(0, 1), ...
		'Mean1s', NaN, ...
		'IsMeanInactive', false, ...
		'Score', NaN);
end

function [idx, ok] = iFindTimeIndex(xsSec, targetSec, tolSec)
	[d, idx] = min(abs(xsSec(:) - targetSec));
	ok = isfinite(d) && d <= tolSec;
end
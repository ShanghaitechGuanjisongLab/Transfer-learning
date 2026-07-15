xsSec = seconds(TransferLearning.Xs);

plotMask = (xsSec >= -1) & (xsSec <= 2);
xsPlot = xsSec(plotMask);
[~, idx1s] = min(xsSec-1, [], ComparisonMethod='abs');

ALB = TransferLearning.AudioLightBaseline();
LAB = TransferLearning.LightAudioBaseline();
LAI = TransferLearning.LAInterspersed();
[naiveRep, transferRep] = iPickRepresentatives(LAB, LAI, ALB, (xsSec >= -3) & (xsSec < 0), idx1s, 3); %[output:839089ef]

colorNaive = TransferLearning.NaiveColor;
colorLearned = TransferLearning.LearnedColor;
colorTransfer = TransferLearning.ContinualColor;

f = figure('Name', '中文图44D 两个代表性细胞回合曲线', Units='centimeters'); %[output:858f9d83]
f.Position(3:4) = [9, 4]; %[output:858f9d83]

tlo = tiledlayout(f, 1, 3, TileSpacing='tight', Padding='tight'); %[output:858f9d83]

ax1 = nexttile(tlo, 1); %[output:858f9d83]
iPlotTrialSet(ax1, xsPlot, naiveRep.Signals(:, plotMask), colorNaive); %[output:858f9d83]
title(ax1, sprintf('Naive\nCell %u', naiveRep.CellUID)); %[output:858f9d83]
ylabel(ax1, 'z-score'); %[output:858f9d83]

ax2 = nexttile(tlo, 2); %[output:858f9d83]
iPlotTrialSet(ax2, xsPlot, transferRep.LearnedSignals(:, plotMask), colorLearned); %[output:858f9d83]
title(ax2, sprintf('Learned\nCell %u', transferRep.CellUID)); %[output:858f9d83]
ax2.YAxis.Visible = false; %[output:858f9d83]

ax3 = nexttile(tlo, 3); %[output:858f9d83]
iPlotTrialSet(ax3, xsPlot, transferRep.TransferSignals(:, plotMask), colorTransfer); %[output:858f9d83]
title(ax3, sprintf('Continual\nCell %u', transferRep.CellUID)); %[output:858f9d83]
ax3.YAxis.Visible = false; %[output:858f9d83]

allAxes = [ax1, ax2, ax3];
for ax = allAxes
	ax.FontName = 'Segoe UI Emoji'; %[output:858f9d83]
	ax.TickDir = "in";
	xline(ax, 0, '--', 'LineWidth', 2);
	xline(ax, 1, '--', 'LineWidth', 2);
	xlim(ax, [-1, 2]);
end

xlabel(tlo, 'Time (s)'); %[output:858f9d83]

ax1.XTickLabel(ismember(ax1.XTick, [0, 1])) = {"💡", "💧"}; %[output:858f9d83]
ax2.XTickLabel(ismember(ax2.XTick, [0, 1])) = {"🔊", "💧"}; %[output:858f9d83]
ax3.XTickLabel(ismember(ax3.XTick, [0, 1])) = {"💡", "💧"}; %[output:858f9d83]

MATLAB.Graphics.UnifyAxesLims(allAxes, @ylim); %[output:858f9d83]

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = '中文图Fig44D_TwoRepresentativeCellTraces.svg';
svgPath = TransferLearning.ExportStandardFigure(f, 1, svgPath); %[output:858f9d83]
fprintf('Wrote: %s\n', svgPath); %[output:4aae92ea]

assignin('base', 'Fig44D_NaiveRepresentative', naiveRep);
assignin('base', 'Fig44D_TransferRepresentative', transferRep);

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
	error('Fig44D:NoOrderedRepresentatives', 'Cannot find representatives satisfying Naive 1 s mean < Transfer 1 s mean < Learned 1 s mean.');
end
end

function candidates = iListTransferCandidates(DS, baseMask, idx1s, kSigma)
Learn = iRepresentativeSessionNTS(DS, struct('Phase', 'Learned', 'Stimulus', 'AudioWater'), "latest");
Tran = iRepresentativeSessionNTS(DS, struct('Phase', 'Transfer', 'Stimulus', 'LightWater'), "earliest");

commonCells = intersect(unique(uint64(Learn.CellUID)), unique(uint64(Tran.CellUID)));
if isempty(commonCells)
	error('Fig44D:NoTransferCommonCells', 'No common cells across Learned AudioWater and Transfer LightWater sessions.');
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
	error('Fig44D:NoTransferRepresentative', 'Cannot find a transfer-group cell whose Learned 1 s mean exceeds its Transfer 1 s mean while keeping 3 active trials in both sessions.');
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
	error('Fig44D:NoNaiveCells', 'No Naive LightWater cells found.');
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
	error('Fig44D:NoNaiveRepresentative', 'Cannot find a Naive LightWater cell with at least one active and one negative-1s trial in the same session.');
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

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline"}
%---
%[output:839089ef]
%   data: {"dataType":"warning","outputData":{"text":"警告: UniExp:Exception:Block_must_warn：\n    BlockUID       MustWarn   \n    ________    ______________\n\n      111       \"2\/5层亮度反相\"\n"}}
%---
%[output:858f9d83]
%   data: {"dataType":"image","outputData":{"dataUri":"data:image\/png;base64,iVBORw0KGgoAAAANSUhEUgAAAVQAAACXCAYAAABKmaMbAAAQAElEQVR4AeydB4AV1dWAz9vGrpRFBCwgApZojF0QgphfRaMhzcSEKBELii0FY1tARf0jmJAiFvQn2IOGmAIaGyKCIM2gKAkaE8HCGqQvnW3vn+\/u3mWY1\/u8twc9787ce247d9+355aZLQrqP7WAWkAtoBZIiwWKRP+pBdQCagG1QFosoEBNixm1ELWAWkAtILIXUAvNIP\/4xz\/kkUcekbq6OtM17hFz4\/p47rnnZMGCBa4YvcymBRgTJNN1rl27VqZPn57palpF+R999JHcddddUlVVJa+99lrcfa6trRVnbi2pfOdmzZolSNyVZlGxoIG6Zs0amTt3rhFsyj3CtVu+8Y1vyJe\/\/GV3lF5n0QKMCZLFKrWqFCzwwQcfyB\/\/+Ef52c9+JnfffbcMHDgwrtK2bdsm9913n2zfvl0K9TtX0EBllM877zzjfa5bt45bI0uXLpUHH3xQbrnlFpk\/f775bffyyy\/Lr3\/9a9m4caN8+umnMmnSJJk3b57ceeedcvvtt8vs2bNNXv3IvAW8dn\/hhRfk0UcflZtuukn4MuOdXHvttfKHP\/xBHn\/8cRk3bpz5oj700EPCl5Z7xnfMmDFSU1Mjv\/rVr2Ty5MlmzPkyZ74HhV3DwoUL5dxzz5WKigrT0ZKSEnnvvfeMt\/q4Mx6jR4+WrVu3hozNokWLzPfoiSeekBdffNF87xjLKsfLZSbJd+2zzz4z30MKJg3xfl9J86tEBqpfW5xgu9q1ayff\/OY395rqHXvssXLSSSdJly5dzBeUIouLi+XII4+U5cuXy5tvviknn3yymcocddRRJv6NN95ATSXDFqivrw+x+2mnnSaHHXaY+QJ\/8sknpgVf\/\/rX5Qc\/+IEEAgEZPHiwXHrppcbzeeutt6ShoUF69OghjOnixYtln332kREjRhidNm3amPz6kbwF1q9fL5WVlXsVwJLZ8OHD5eKLL5b+\/fvLO++8EzI2xxxzjJxxxhkybNgwKS0tbcn\/la98RS677DJp27atbNq0qSXeXoT7vto0v4UFD1QMftxxxwlfJH7Tcf\/YY48JX1wGknjikL59+8o\/\/\/lP+fzzz+ULX\/iC8Jv3xBNPND8EP\/3pT1FRybAFgKHb7tdcc43geXbt2nWvqaX9QgLNoqI9P8as0fXq1Uv69OkjP\/7xj+Xggw82Y0+zd+\/ebWDLtUryFsC+3jVvbOv+LlG6d2yICyd2LEmzY8k6K\/dIpO8raX6TPT+JfmtZGtsTCASEqT+wpNiysjJ5\/fXX5fe\/\/73wg0Ac0rlzZzNVwbvhNzBe6pQpU+T5558XpivoqGTGAk8++aQwVWTTyG33JUuWmF9+LLkwxY9V+5e+9CV59913zabHtGnTpFOnTuYX5P3332\/Gm1+kscrQ9OgWOPvss80sDidj1KhRZvp++umnm2UXpvzM8o4\/\/viQQsrLy2XLli0yc+bMlo1ir1KHDh1MGr9E7XhH+r568\/rhPk6g+qGpibdh0KBBgpCzffv2wtoN90xLWLdhbY2pBnFIIBCQm2++2UwhycMPzvjx481UkWviVNJvAWzPF5G1zyFDhgi2tnZnrY6xuvrqq4VfbuhaoSVDhw4VppIs7Vx\/\/fVywAEHyC9\/+Uth+vmjH\/1I9t9\/fwNqru+44w5Bn3wqyVsAW48dO1YmTpwojBNjxNLYhAkThO8WvxjRwdbuscFJYQy+853vmDVYO46EtIbx69atm3jHmzKJ835fyeM3KWig+s3Y2h61gFqgsC2gQC3s8dXeqQXUAlm0QDJAzWLztCq1gFpALZA\/FlCg5s9YaUvVAmoBn1ugYIDKubfbbrtN2HX0HulgDDggjEydOtWcNSUO4VwjT3uwkWEP\/3N0h519DpGjwxEODpvbY1ccHmcXkoPIHGhGRyU5CyQ7bozVPffcYw71cxic2m0c8ewme8fNprP5ZfOQTyU5C+jYhdotZaCGFpn9GJ524ngNO498WdhxjLcVBx54oNx4443y1a9+1Rz\/2Llzp9x7771CefZIFU9xcGzHHjrmCNUhhxwiV111lTkCEm9dqre3BVIZN57SufLKK+WCCy6Qp556Shg3TnH88Ic\/lJEjRwrHb7zj5s2zd2v0LhEL6NiFt1beAxUvBMDx5AwHiQOBgHlCBo8SDzLWY6McJOZx03\/\/+98CJPnSXXfddXLEEUeI\/ccRnAEDBthbOeigg8w5vFdeeUV69+7dEq8X8Vsg1XHjWA5jxUH+\/fbbT1atWiWcV1y2bJmsWLFCKN87bt488bdWNd0WwLapfOe841BIY5f3QN2xY4fwpeLxQjvoHN7mDTh4qkceeaREe2yUvCwRfPTRR9LY2GiLiBqix7IAby\/i2XB+wKJm0MQQC6Q6bhTIL0EO759\/\/vnmCSh+Mfbr1888L84jqOh4xZ3Hm6b38VlAxy6yndIL1Mj1ZCyF5385tL9y5cqWOoCd+\/FFnuhoSfRc4OXwlAfeDF82T3LYW2B9ySWXCIfFq6urZfPmzWH1NDKyBVIdN9bvmHayZs74MzvhkUi8H2YXrKF6a\/fm8abrfXwW0LGLbKe8Bypd4yUZvI2ItVDeSMSUz\/34ItMT9MIJm08PP\/ywebqmZ8+e4VRC4o4++mjz9qIHHnjAvHiDL3SIkkbEtEAq48YGIS8+Yd38d7\/7nXkZCjMG3jKFd8r4exvgzWPXyL16eh\/bAjp24W1UEEDlrVFsJPHoG7v1J5xwwl6PL\/IoI4+3IfZxOGsO3lSEd8ojdOjZeK8eeRHSeWMO+mx+8Egk3jDxKolZIJVx45FhTlqwCXnFFVcInukNN9wgjAePKdpfcowZQsu8ebwv80BHJT4L6NiFt1MGgRq+Qo1VC6gF1AKFagEFaqGOrPZLLaAWyLoFFKhZN7lWqBZQCxSqBZICKq\/tStAgGVF\/9tlnM1JuooX6pR2JtjtX+n6yl5\/akqvxSKReP9nLT22xNlSgWkukEPpxYFPoTsaz+slefmpLxg2fhgr8ZC8\/tcWaNimg2swaqgXUAmoBtcAeC+QEqHuq1yu1gFpALVA4FlCgFs5Yak\/UAmqBHFsgr4HK3xjKsf1M9X5ph2lMHnz4yV5+akseDJ35u15+aacfxy73QPXL6Gg71AJqAbVADAs0fLJYkEhqCtRIltF4tYBaQC3QbIFgTbXsnnevNDoh0hwdEihQQ0yiEWoBtYBaYI8FgGntu3+WkkNOkdJjviONm1fvSfRc+QyontbprVpALaAWyKEFmN4D07JjvyvFPU4xLQGsxJsbz4cC1WMQvVULqAXUAlgAaNZ\/vFiAaaCyG1FGiiq7C\/HmxvOR10C9\/PLLPd3Jza1f2pGb3ideq5\/s5ae2JG7J7Ofwk70y1RZAynop1m0z8CcScMGUOO6LOnYPuznlZ6DSdhW1gFpALZAVC7BW6gapneKHq7zIA1mro0C1ltBQLaAWaNUW8K6VRjMGsA037VegRrOapqkF1AKtwgJ1y\/9idvGZzsfb4XCbU3kD1Hg7qXpqAbWAWiARCzDV5ygUXmci+cLpKlDDWUXj1AJqgVZjgfpPmnbyE+0wAPZO+xWoiVpR9dUCaoGCsQDeKZ1JZKqPvhXvtD8\/gWp7o6FaQC2gFkjBAmxElTQf2E+mGLxUdz4Fqtsaeq0WUAu0Ggtw3pTzpMl6p9ZQbqgqUK1VNFQLqAVajQWY6rP+ybP56ex0AQA1nebQstQCaoHWYIHGmtXmmFS6+5rXQPXLC2b90o50\/3Bkqjw\/2ctPbcmUvdNZrp\/slUpb8E6LKrun0zSmrLwGqumBfqgF1AJqgQQswHQ\/HWun4aosNKCG66PGqQXUAmqBFgtw7jSVnf2WgsJcKFDDGEWj1AJqgcK0AN4pPQtEeLkJaamIAjUV62letYBaIK8skEnvFEPkNVBjvQ+RDmZD\/NKObPQ1HXX4yV5+aks6bJvpMvxkr0TbkmnvFNvnNVDpgIpaQC2gFojHApn2TmmDAhUrqKgF1AIFbYFseKcYsPUAld6qtAoL\/PXZPwlS\/dnqVtFf7WR0C\/CIaarP7EevYU+qAnWPLfSqACyw5O+LTC\/6ntxP\/jrjGbH3JlI\/Wp0FgGljTXXIH9rLlCEUqJmyrJabdQvgkS55c6Gc983zpdtB3eW8b31PTFwzZLPeIK0wpxbgLfw0gOf1M3VMivLd0kqB6jaBXheCBQAnHikQtf0xUHXgSpp6qtYqhR\/ilfLH9vhDeu43QWWj5wrUbFhZ68i4BQBm3z79jWfqrQyPlTh0CFUK1wLA1E7xsw1TrKpAxQoqeW0BC0rWTaN1hOWAaOmalr8WAKR4pfQgm1N86nOLAlXEbY+ErtctD8o\/n2pMKI8qp9cCwBRQWi80UunAFg8W\/Ug6Gp+fFgCmufRK3VYLC9S6ujpZt26dELqV\/Xadyuu70tGXtQ5QKefecVMIVOK0QLrGDTgamDqbT\/FUDVTRd+umqy3uMgv52k\/2+r\/brhA\/eKXu8Q4B6rZt22TChAnyxBNPyIoVK+Txxx+XjRs3uvPotWMBvNO2+wek6zEB2f550InR\/7NpATdM2XyKt271UuO1lL\/1cuWV1q+cF9UwIUDFMz300ENlwIABUlRUJKWlpVJTUyOt5V+8\/dy+VgxMuzhAtZ5qvHlVLzULJAtTag3npRKvkj8WAKa0NlNrpUAT2TVrnCDbJp8ryOaqtk54jiPnCum0wSshQO3evbt8+umnMn36dHnmmWdk+fLlcsABB3jzter7HQ5MMcA+XfkUwVPFY226089MWiAVmNp2xeOlctSKp63uf\/C34hbqt+VomH0L8Agp66Xp3sEHnMgeaJ7jwPQuA86S3gMFKR80RtqNeMl0ettk0seZa\/dHCFB37twpffv2lZtuuklGjhwp48aNk4qKCneeVn+NR8pU3xqibTNY7b2GmbGAhdmPrr4u7PGoeGu1XirABJzh8lEXSwnU5Rb0SQuXR+Myb4F0v+AETxOQ7pp1l2m8hWbHu7cL0m7Ei1I+aHSLANamuDEGuOQ1GZs\/QoDKNP\/999+XXbt2yb777iuBQKBZtRUGYbrs9U5R0Wk\/VsicADC8RGoAhoSpCFAkf3X1p+bxVC9YuQem4eoijo0tWwblqGTHAnaqn46nngAhgqdJ68sd77O8GZxAk7hogi7eKiAGylY3BKiNjY2yadMmuf\/++2XMmDHyi1\/8QrZs2WL1fRUm+j7EdDTe651SJu3AY9VpP9aILdgrtlaTBjDlCi8RmHGdisxf8LpM+9NU6dJlf\/No6vS\/PGeKox5ASkhEpLoMaPv0b7XvCEhk7LBjuoSpPn9Yz\/2nSxJtC+ADokzrASFtK3eBlPtEBPACVUKbLwSoHTp0kEsvvVSOPvpoOe644+Tqq68W4myG1hyG805bsz0y3Xe8QCQS3OKt\/+4J\/yuVXUuNDP72mXLHz2+REddcLFdee4n0PKT3XsVQXzxnWgGrhe9eBehNRixgpvqHnCLxeKcWmoDTLXijgBSIAJuobAAAEABJREFUMp0vb\/ZIU2mwG6aUU8SHW\/BOH3jgAbOOeuKJJxpPdevWrW6VVnotEs47tcbQab+1RPpCgAW4ki3RgnT8hDtl1I23yfPTX5WxY34ukyc9Zq7nvTFX\/vPhvwWA2npsGKtOIM\/UnzbG0tX01CyAd0oJdiMKYOJtBndsNJtGXBOHAFALTbxHr1iQUl4mJASomzdvli9+8Yty+OGHG+ndu7esXq3vlYzH+Drtj8dK8euwxgm44s\/RpOkFac3aOqm68Vbp1bO39Op1qAw5f6ic+uXTDFT\/8+EHgj71AFYg2VRK7E9zWuDNhbEVVSMlCxjvtMcppgygCTDxNoknRIgDrOXOFN5CE+\/RK6aQDH6EALVLly7CptTixYtl0aJF5tjUwQcfnMEm5E\/RHOC3R6Xyp9X52VKm3t26Jf5zBxytR2pBai2ANwk47T1QPezQIwR98hFvIBnn6\/4oKxF9yldJzAJ4p7w1iqm+hamFZumR55pjTHu80BfNbnxiNaRXOwSo7dq1M0emamtrzaOno0aNEuLSW23+lcb6KedNm1seNmDaz4H\/sIkamZAFvPCLJzNQBI6jnOl9leORuvNQHvfdDupO0CKHHXq4WQ4gH\/mBZEJe6sn9BH1bfkvBepEWC+CFNm5YZQ7T44UCz3Jn7ZMd\/+DOzRIoKZPg9nVNUlOdljpTKSQEqDwpNWPGDBk4cKCRmTNnml3\/VCppTXk5k6q7\/amNON4pJXjhR1wkAYZAcVQYmJIH6JnQ8T7tbr6tp8qB7ygnH\/m\/ft4gSdTrRJ+yVdJrAbxTpvHbpw2XYM1qqRg83oDTPr9va2PnHwG+vFQa2FoJOpBFrG6mwxCgcrDfXSn369evd0e1ymum+8AyVufxUtm8iqWn6ZEtgLeHpxhZY++UaDAFmpxhZfnAAtqWTZotqcqBKptWbFSd9bWBMu2ZqTbJhNSBAFyOXpnI5g9bHu1ujtIgDRaofftp2b1wsjONHyPtb1wuJc4uf+Pm1VLUsbvwtFSgoqOwUcVyAMKjqAasHy8WjlihA2T5e1JAGNimoVlRiwgB6kEHHWQ2oTiHOnHiRPn444+lZ8+eUQtpDYlM5SNN+b39180pr0Xiv7eQs\/CLlRPI4VkCQ6Do1qcs3uJPHNCzQtlc47VurtlEshHWVFl3HTjgKzLl0YcEeFI+R66oY8nfF5o\/qcLRK9K8YKU8U1CCH4AYSTBbQavXvf0H2fnSWCnpfZoD1NGCxwkky479rgBO1lWDW9eE2KDR8WQBbpuBPxF0UCAPwj1gzaTHGgLUkpISueGGG2TYsGFy0UUXCWuovCCFhqnEZwHrperUPz57ubUAC8Bzx0W6BmqADpgCQ7ce5QBT45k6m1vhyow0Vf\/bX2eZdVW8VR4COPP0s+SxKU9LlbMsQNrYW36+F1ipF0BTHvVyH4+gi\/eMLvkJW5sASi\/guGe9FJjymCc6FqZ4otgIz1RKysXtdaLX6EzxAa7VMR7rJ47H6gh5yhwg47W686Ebj9AuK5H0Q4C6du1a82IUXuM3evRouf3224XrSAXkMj6b72Zkyh9phz9cO\/BSdeof\/qcjnL2sZjxHpfAM8RrJg0cZDqZ4iwCO8jgOha5XgNj\/nHFq2Kee8HbvuuOXMvySKw1IKQN9wPyzn9wsby9+XyZPelyALl4sZZNOvXjG0QSQso6LDn8Di3zkzweJNnaJth8AkgfA4TkCOeI4BkV86VHnmvedemFKGvLw1D8ZL5Q8gA49AEqaFQAMYK13Sl3o2Hvyokt+rq1wj9h72sfSQaPjAVMGbSWdvG4JAWp9fb15\/+mcOXPkiiuukKOOOsq8fcqdqbVdx7PD32KT5gu8VKAaj5dK+Uhz1lYbABo8ymgGAKZMuZmW4y26dclvPT4eVQVYQNWt472Olk4ZSCTgDTn\/QuPJ4iXbcgEk7YgqzWdXgTSAtnlbUwioGh1vEq8R4DFFp\/87pl0uDRtWSsV3JwlxVgAj6V4hP3FADu8zmh5lAVN0qZulASC8B5bVFGUEHQQ9IsiLUB\/tteV4wRoC1AMPPFB4hR8vSeGAf+fOnUXPoWLSxAWoxvJSAe6qWY3mKSz+nMpHrwaFuMRry+8cwA\/vLhK86B2eIDAd1Tz1Jg4BXnh8XANIyqA8c39yP4KIgi71Wv2IihESqpzNLJJoGyGABJSRBB3aiOfMdWsUC1PAZPtP3C5nzdTA9Jw7nLXTgTYpZmghFwmm7gLQoV6AiJfKRhegBMboAViEaytFld3tZUsYqOxm1nJbIpovQoAaCATk7LPPlk6dOglT\/UGDBrX6c6hAMZ4d\/mab7hXgpQLJcB4o4KTsXoOKpOeZATn6wiLz0mo2wIDrXgUV+A1QBDQAKVxXARae4CgHplXNEEMPEAJE8gFHhHhTXgyYoodQL+VwnYyMctpE2+LJC0hpI3XSxnjyFJIO4MTrA2q2X8RZz7RN\/xFSdsIFNiljIUAExAiVcE+bgCsCcBGgy1TfO73nHs+WdPJSBhICVCKRHTt2SDCof9oDWyDx7vCju0dE8FKBKl4oALVpXFuYutdmuQau5EHH6hdyaGEGaML1MxpM2Xhimu3OC6gALBKuPG8ceYGyNz7e+yoH8L17HWoeYY2Wx7TL2SCLplPIaYCT\/gEuQgQwWZi2HfKw8UzdgEInF0IbEICL98r037afNgNZvFvS3e2LCNQ+ffpI+\/bt3bq+u0709V3JdoANqWh5Y7UDSOJ94nnirQJKrokjLVzZgBjgohsuPZ\/jvPYCNEAtXJ8iwRRdk69P\/5aXTQPmlql\/nN6pbUsyHiP1IbRlyPlDBS+V9nIfTtCd\/dorBryEqUA8XPnZiLP2SqQuQIQ3Rx43gIhnA4ppPk9ASUmZ4BWiF48k05Z4yvXqAFZ+CeBZs2YaCabkCwHqli1bZMGCBebPnvCm\/qVLl\/r2fah0IFsSCXyJ1I\/naZcOuI6VFy8VqMbSy+d0IEP7w3mTwAlIjXKm1FWOF4ieFcBJHgti4Iq36o6zuvGElENbKCeaPukIm1+EVmjfsKGXRcxK2U9OfUSecGT+grkGvrPnvBL2hEHEQvIsAU8OANFsvDwLUxtvPVNgWrxfb+HQPvBC348CVAG+uy\/edoYAlTf1\/+1vf5O7777bPHLK35cizpuxtdyz9pnsdN9jI3OL54mYmxgf6AHVQvRSbdeBIDCz9zZMFKZ4e96pvy0r3pCNJMAHrL15ACcQtfHs\/qMPwKmbeK75BUDb5y94Xaxw\/8Xje8mrjnc6yvnlwOkEzs5yj6dK3kISPE8ET441RkBqQWnj7QYUMOWNUI01q80TUH63A\/1AIrUzBKgo8jelRowYITwpxRuniFPJjQWAKssDhQhVIMUxKUDkti4AAkzAp8rjmZIHXSDMtYUcgPOWg16iYiHphir1AFoLbOq25XJtlwto6ygHmLSd0whWuOfhAM7MVjX3h7OzQJU0HlCw5eVzCCzt1J5+sLkDTLl2p9W996I5GmVhSjo763h\/XOezhACVdVPWT3mN36233irs8peXl+dzH1NqO1NuvMSUCkkxM\/UDVbv+itecYpE5zw6g8OwAkrsxsWBKPsDpBqm3DHd5yVxTHnUAVVuPBW248tCnL6QBTJ6q4qEAwhXLVrU8ZUW6W4AqL7zm4QC8WXdavl17p\/YWpEzvgSn9YRNn50u3S\/3K181r9\/BMiUeHM6HRPD\/08kFCgMq6abdu3Uzbi4uLDVD1T6AYc6T1I5HCWL9lzRWwkg\/Ic6wKwOYrXPH68PgAF31C4oEpeggeKSDjOhNC2UA03nqsl0pbyGf7xpIGce5+cm\/l1AFfER5lBa6Sp\/+AqXdqT1cAKdP++pXzpO6DV2XrpDNCYIoeO+iF4J3SlxCgEqmyxwLs8AO0PTG5u6IdLAEAV04IAFgLV5YE8gWuaz7\/r9mZd0MmFkzxADnDSR5gl7tRCF8zbaKNNtW2EyADWO5tmjskX1lpmTsqb67xLJniW5jahhO\/c8Z1wguhdz4\/yrzkBKiWN79N33qm6KNLWAjeKf0o4kMlvAX8DigAC1x5MIAlgfC98FcsniktAiSEgJTn8tn5Zk2RKTPxVpjiW1DhBdp8Nt1PIe2z\/bPtov2IvQ8Xso4cSydcvlzGAUK8T6bxdnoPQJGa8UeY1+7VfTBLgChrpbzkpHzQ6JAmF5J3SucUqFghiqRzhz9iNSkmWLASplhURrMDDeDYseO+ph42Y9iUGeVs5LDz7Z32AiemzAAHWPkZpnSI9tE\/08+\/LxLWX+kDYq\/R8wreK3m88X69t1N5C1Mgav84Hm0ub\/ZE3X\/biXivUA5xheKd0hcFKlaIIEz3IyRpdBIWACyAsbxNuTnczmaM9UoBCulW2BACTsAU4ACrJKrMehbWTvklQMV2us+Un3j6SL8ISbdC3+ijvc92CNjwOOOplz87gp7dwQemvGqv9IhB0v6a2Y5HOtoIOtGEOhtrqoWzndH08i1NgRplxJhGs04ZRUWT4rQAIAEawGPjpo3mYDsH4Ze9s7TFk6MoIIqgC4TQR0jLB6HdgNTbZuIBK\/EAF3vwy8PClfRc9M+Cjak3m0uRwIoe66W0ce8p\/l0OQMdI28tmmLfnkx5LqKNQjkl5+5rXQOXdjKxzsuPNpoy3c9m6px3pq6uwSgIYTHcBBjChd6\/Oe0549v2M08\/i1ggbTgak3Q4WC1LyIEYhQx\/ZHjv64wYuUMU+2ClDXdyrWMDoFjzM7VMvkobP3zePfQJWwAlcCa1QCE8IPTz1T8Lb9Jnis9HE+mi5szZqywSW6EYTu\/aa6lQ\/22MXrU82La+BSifY5bZepD1GRAhkgS06yQpTfve65Jq3g4IkW14h5wMM3v4BCbwxpvkWpqyboseLm4Eo8AQwVvDigA46hSz0EZvQX\/rOfab6a2EHHG0dwJBjTGwcMV1n2r592uUSaNtFACfHmJjWW8ErBYDAdPu04cYrZaOJHXvKx+OkbDeQw8EVUNu1V\/QLTfIaqAAT6HGUCOE5ed7qxCCx8811sp4r+SyoKQ956ZoGQR7rXy8vXdsgyx5uVMA6hjHT1zcXmqk71y0y4xnzF0QBh6PWsm56+aVXcWs80UyCxFRSQB+ACyAhXIcDFvEIOgAUsSYAjoCx7oNXzVEmQNp26JNS1udi4bV56PGyEv44HteUb4Uytz\/yLbEwxSslzZZvy2ZNFCCT38IVHSveI1boFZJkBKjAyArQy5TB3N4pdQBVwn8\/54DuraB5vyjroHisxMcrtJ18tjzyAdADTgzIOZOKjRC3xqnDDVh00uzBUo1vBQ\/UTFerPxW8ULxN21ggiudFSBzHo8ZPuFN4BJPD7HaziTSV+CwADPEcETZ0ABbgBGwI0LIloQPkEPIhpG2bfK7gjQJToAgAkbITfiAV59xuPE\/+ON62yefIjj9fI7vm\/KpJZo2TuuZjUOQDsHbqbsumfARPljIR6neLVxf9QpK0AhUQIYDOGkpiP+8AABAASURBVAkvMV6oAj6m6pRh80cKKdN6p1ZnwbhGefO+RqleHJTX72iQlS8FpeeZAcFzpWyrFy2kXNrv9k6BJPA8\/vIiOeCEgJFzHnDAirgAS7kAFs+V60IWpvhM5+kjIAWceJtMYYkj3YobphcNvUyY6qOPnkpiFgBWCLAKONNzqa9tAp4DPmmolaBzD7TQ8Za8bfK55kklvFGgiJ7V4ZppexvHWy0fNEYCld1NWbsXTt7rTGm5s14KvI3uwJ\/EvRFl6yn0MG1AdUOQp3jw7hCm3muXB2P+WQ+bH5ChH8vw6PzqpRFGDYAxDf\/A8UyB3iULS4QQqJJGO4CqrcNkivDBLwDa7F47XTalUfBOgak3G3G3PHCFWMBSL\/rU69X12731MAGfbRvXTNkJSbfx7pA0u4HEX3V4cuqjwuF81kd5Jh2oWmDe7XileKacNf3LtBdMMXNmzzdPSpmbHH9k652a6ehm\/cp5jnc5zgibQtscL5IpuIWe9Sy3GXDO26tK4oI1q83UHm8UgO6l4NywtonXCzRZH0U4S4rYzSfshY6d1jvZcvY\/bclZ5REqTgtQrfcHuBB3XYAJL5EpNHp4gO50rgEd6eiRH6iiS3w4j9WWUVwmTWuZDvC6nRKQ789wQDq8qUvHO6EbbpQLhCnT1kk5bqFO6qbN6CBu75T7WOKtN5Y+6cD3JWdNlrq4jyTpjAeKeJhM1YEjEGX6Th3AEJiSTjzX6CPco8+7PC+5\/AJz\/Ik8AJOQNywB1lUfrRReTccr6kiruvFWoRx0OlY2HeznWiV+CzQB9S6TgSk7nmbF4PGCsBZKSBzg3ObAdpsDVnbxgS9xZf2uMG\/EDwdTCiW+qLKbMJ3n3i1sPnEf3LpG0AnnAZPe2qWJPilYAUDh\/QGsaMUAS\/TwAAEXIEOf\/IAOkFmwzLuzUd56qFEI\/\/XXoHzoTN3Jgz5i9df9Q4Sp+Glji+XwbxSJBSFlI264AazGejFlAWlbDmXRJsTGkU59CN4mYMYTJT0ecdcbC5L0mTool+UC2hkrD7qpCGAkP2uchMBv\/htz5fjjTpLa2lrhHi+TdOBq9fE2n5z6iIwZe1PLuz3tK+kAJk87cVCfMgHreMc75Z404iiH8rhWSdwCvIQZcAbatHPWOkcLnqZdn2TNFK8R8AFOC1bWS8lHHDWyVEAYSYAq0\/lgTXWIigUtOiGJGmEskBJQgaEpxfl4ZaSzA+54WS81C1Nwrzw\/okE+fSMoW6uDAsAAFkDj8U6ggjC17n1OQNp3EyNA8v2\/NAF2+RONLUsHTO931wQFmO7cGHRaIAIIEdZWKZ\/2ATc2klBY+mCjUBZtWOoAu7FOBF1gzjIF0CdEiPvMWYtd42w8UQb54xVgfoQD+A7dAwIkI+WzMKV9ZsnAWY9FlzykcZ1uAWrAE+\/xhFOOlLO+NlCmPPqQkcHfPlOsMIVHrrz2EnnYSUcPb7Pvyf3Nn062IPW2j8dHASvpCPfoUC8h66yEKklYoKTMvNWeqTlQQ2wpeIwIwCS9qFMvKT\/nDjPF32fIFPPyZoBr9aOF5Gdaz4YXAlwRQBuo6Bgta6tPSxqowAoY4j3iSVY78MGaxaVi1hvx6hDActLVRYIc+Z0iATaADc8TWH22JChzbmkQAIk+8OrWN2A8Tq5PuqqoZVedfIAG0AHfykMCAkwBMt4va5\/AEG+ZkGUEoI13CbBYWwVetAFhjbXmYxH0abtbaA9Cu+mrOy3SNWUCdOyCnOi0HV1+yXi9Tu7pA32mfegR0k7aSBp9JT6cLHu4UaKlh8tDHCC9465bzFSdv4M06sbbBC8S4d2cvEqOa4TrsrIyM1Vnd\/6VF+bJRUMvNUJZ8QpTfZYJ8HrjzaN6oRbAC8UjdYM0VEvMRhFQLHKm7xXf+m2LCsBtuYlyQfkGzD1OMVrAtfbdP5vzqVJSbuL0I7wFkgYqxQFDPD68SAOrB4oFCJZWiABFwsqeIkUlDmSd3fFDzwnIF84LGK+SPOQFxECF\/OQFXmudTSw8REDH9Yb3gjLwtiJhnRR9QAeoJSCCHp4lupRJu6wQD2iBHOUCV1sW7aDeD55tFDfwgBSeNUAj\/ZhhRQKYyW\/LjRTSVtse6kaAI6D1ep3c443TZ295gJW6aQPt8aYTZ9KctWN327164e45sgQ4eQEycKxy1jbxIgEnab16HipcGyktkyoHuP\/3wGNy328nm+LwNBHWW1lPBZYmIcoH+pwEiKKiSXFYIF4gUhRQ5GgVHiaeJTAmPhGhPsCKAHLuE8nfGnWTBmq141kCN774eFVe41m44D3iOQI8BODgVTJVBzbkt1ABWuRD38IRTxMhL3p4ueSt7CnSpkN479LdFvJRHnHA1ZZFO4A+bSANwLlBagFPWs8zA0K7aB\/34QRoEk99hFaAI78MaDcQBIAIMA1nN5uPvmIb8uDN2ngLU9qNEE\/biec6lqxbv1YAJ4Bj0wnYAUby9T25nyAWknYNlTim6oR4mYhNs\/ltHspxC+nck59QJXsWAISNm1cL3qrCMDt2TxqoNI8vPF98rgGKBQ7QAmLAFBhZOKIHcIAZa5wdugWMR0s+vEjSyevWJ84KefFyATJllLW3KdFDyiMvYjW5BpIAD7ABJ\/rjBqnVJaQ\/6NNP7r1Cf2iTN5576qLdgycXc2s20qjL3ET5wLboAUzUgCaApa20G6Htx19eJMS7wYt+OAGGgBHAAUV0uCbOXlsd7qMJ+awu4ATMbrByrVP9aBbMfBqeJd5q5mvSGrBA0kA1X\/bhTdkBIkChQOBBCMQQrr2CDvAhD9Nw0gEW8VxHE3Ti1Y1WDmm0gbZzDZzoE9fhhL5QL222eazezvVNSw\/o2DhvSLsBMt410KY+dCgLG1jxAtu2Ca8WaFqYuvN17BkQPGB+QVFmIgJIkUTyeHUjgRXI4gl79fVeLVCoFmgiYpK940vt9iyBRrxFoQuggBrX0WDkLTMRXW9e7z3ro964SPfUiwdNHgAI\/BD06QNhNKGvnCqwOtiPsoi3AnSxKeVbPSDKBh7eKiAmH2k2D+GxFxe1HBsjLRfiBSv3SC7aonWqBXJhgaSBar\/UACYemITrHIBCwqVlI452Azjbl3jrZBmD9Vi8VaTMWcuNJy\/1oQcsgSbXlIUNrHCPTSkfHdoGRPFq8VbJSz7KsnlsSLyI5DwAonYpIOeN0QaoBbJogaSByhcayWJbQ6pKx\/sQ8e5CCo4jgr7jYSOPPjEljhxNKuQDluTjuik29JM0dPBggShgBbDkJS00R\/7EpGPc0tVbP7UlXX3KZDl+spef2mJtnjRQbQH5HgInptmx+gHQLNisbrKeIXWS15YTKUQHjxWIAlbgT95I+hqvFlAL5NYCrR6omB9QAUyuvUI8YqFrQ69eJu+BKGAlTLQe1VcLqAWyZwEFqmNrQOUGJRtNQBSx8axrAjWOghHvZNP\/1QJqAbXAXhZQoDabAy+VKT3rlBaiJAFSgMs1wvSbMJ0CwJF0lqllqQXUAtm3QF4DNZ3vQwSaQBWA4olyj3iHhDiA6\/ZSU2kHIOWkAOIu01uv9x74J6Jv8vvkIxV7pbsLfmpLuvuWifL8ZC8\/tcXaOq+BajuRrpBNoHjKArzx6MWjA5xZRrA7+vFAEghTNnnj0UdXRS2gFsi8BRSoSdg4nJdqi7Gws\/exQs7BAmhgjmfMbj7eZ7R8gJQ8CNfRdDVNLaAWyJ4FFKhJ2hqYubPiKdr1V67daZGugS\/eKTC1OkCVddpoZQBh8gB22hFN15YbGmqMWkAtkG4LKFCTtCgws95h7VYxb6MCbgDRxscqGj3yePUoG081HCgthG0egEw59l5DtYBaIHcWUKCmYHtgiFdKEWxmAUKuiQ8HQ9KsAEau8TQJvYKXGg6UxFG+1Sc\/97Hqs\/oaqgXUApmzgAI1BdsCUDaTvK8RJB7wRSuadEAYSYcySHeDMhKE0aW8SGXFEa8qagG1QBosoEBN0Yh4iOGK8MLQrRMJjG4drr2gBJqUS5pXiLfletP0Xi2gFsiOBRSoGbKzhWE4yEUDo7c5gNJ6qXYzyqvDPfVFgjvpKmoBtUDmLZDXQF21alXmLRRHDZHaAQyBoC0CMCLExQs\/QAmAOUrFBpQtK1w4ceLEcNEtcbHSrWKmw0j2ynS94cr3S1tijU2s9HB9y0ScX+xF3\/zSFvfYJAXUfv36Se\/evXMuGNTP7TjlW4ea3f9pdy0UNq9mP7tIMP43bjksIds9PfteAcI\/HXdh1HyLFy\/m5yyikO5ne+WibX75GWJsIg6ck0B6LuzjrdMv9qJdfmkLY+MMkfk\/KaA+9dRTsnLlSpU4bMCm1Rnf7CecAhgypr\/8fMrIhO1GHvLPePXpqHkZFzOqET5I13Hz588tYxNh2Ew06Tp2\/h+7pIBqRlg\/4rIAU3um7XEp+1FJ26QWUAvEbQEFatymUkW1gFpALRDdAgrU6PbRVLWAWkAtELcF8hOoa+eKvHO9yOonRHZ8HHdnM6X42zkrZeYn9Zkq3kflFlZTdNwSHE8ffe\/8OnZJATUYDMq8efNk6dKlCY5IGtTXLRBZcYfIPltFDvyaSP0SR2rSUHByRXyyaZesbru\/LAqWSM3u5MpIRy52PMeNGyf33XefbN3q2CZMoTkdt+b2bFi\/QWbPek0+WfWZibl\/yU4TZvvDL+NGv\/Ni7Hz0vfPz2CUF1EceeURmz54tmzZt4uchu7JurkhFheOZBkRW\/VqkbpVz\/V522+Cq7am310ugoq2IY8m\/VLsSsnzZsWNHufnmm+Wkk06SGTNmhK09l+O2ZMlb8tbf35G333xXSgMVsk\/bfWTDzkb50r5BuW\/JjrDtzWSkX8aNPvp97Gij+Oh75+exczBgzJXQx\/Dhw2XAgAEJ5UmbcrueIg1BR5wv4dZ1Ihv\/I1LSKW3FJ1LQ0pVbZU2b\/UQaRYqdjP8tFfk4vHPopGb2\/3333VeKi4ulrq5OuA5XW5rHLVwVkePqg1JWUi7tKiqddpZKY2NQGmtrZXbNPlLbiPUiZ013ip\/Gjb4xXr4eOxrpk++d38euCFvFEjzRmTNnymuvvSY7d+ZmitbSxh4XiFQe5XilW0W2rRVpc4zIPke0JGfz4oU3d0qwwfGWHaAGG0SKikWmf+LAPpuNcNW1YMECeeutt+Tss882sX4at6KiEikpKZUiR0qKSqR2V71s37BBKnfUy45Ntaa92frw27jRbz+PHe0Tn3zv\/D52cQGV36B8SU8\/\/XSpYLptLJzDj6OdqX4wIFLaQaTHj3PWkNq6TlK0XqTB+R2za4tIvSM7HKc5Fw2aNWuWrF+\/XkaOHCmlpaWmCX4at6DzS6ehrkhKi5vAWl\/XIOX7dpWS7TWysq6pvZKlf34aN7rs97GjjUZ88L3z+9gVGUPl2ccux0ue+d6psnz7sJy2vHtFiRStdZrwsbOU+6nIzn8Fpe2W3Hior7\/+usyZM0fGjBkj06ZNcxqV3f9j1XbYEb3JOBziAAADeklEQVSkc5f2Uis7pcH5r76+Vg7Yt1Q+3l0uvzjNce1jFZDGdD+NG93y+9jRRsQP3zu\/j13SQB00aJAgGDrb4vimUlt6pCx7Jzfwsv294Ksi+zkWLKkWCb4flPK1jXLJGU6EVchieOedd8pvfvMbYad\/yJAhEWtmzJCIChlK2LdzB9m\/+35ySv8T5UsnHC7tKytMTb\/5dlvp2rFUsvnPT+NGv\/0+drQR8cP3zu9jl5tvP6OTgrRxlh2+fulguehnDtFSKCfVrB3aiYweITLhepFfXh+QW68oFuJSLbfQ81dUlMv+B3XJWTcZIx23xM3vh++d38cuL4Ga+I+C5siqBbQytUArtYACtZUOvHZbLaAWSL8FFKjpt6mWqBZQC7RSCyhQW+nAZ6\/bWpNaoPVYQIHaesZae6oWUAtk2AIK1AwbWItXC6gFWo8FFKitZ6z90NOQNsyfP19OO+20Fhk8eLBMmjRJ3nsv+RfeVFdXm5f3iOcfL\/QhzROtt2qBtFlAgZo2U2pByVjg1FNPFZ4UuvDCC+W2226T559\/Xi6++GI57LDDZNu2beZVhOvWrTMvfSHcvXu3qaahoUG4R8dENH\/wikLKOPzww8XqbNmyxaQec8wxwjsp0DER+qEWSLMFFKhpNqgWl7oFpk+fLu+\/\/76MHz9eJk+eLA8++KDwpqwXX3xRbrjhBlmzZo2B7yuvvGKeDFu2bJnYf6QB0AMPPFDuuecemTt3rowdO1YWLVoknTt3lg0bNpj8Vl9DtUA6LaBATac1tayELBBLuUOHDvK9731PzjvvPDnzzDNl2LBh0rNnT\/nXv\/5lvNfKykrp0aOHvPzyy2L\/8YKYLl26SHFxseCJ8vYtHsXt06ePBAIBAbToWH0N1QLptIACNZ3W1LLSaoGSkhIpLy8X\/nFNiABLQAokzzrrLPn+979PdIvYV0xecMEFct1118mKFStk6tSpJr2+vt6E+qEWyIQFFKiZsKqWmVEL9OrVy6ypPvnkkzJx4kRhim8r7Natm2zfvt2snz799NPmT8KwwdW7d28Bpnin6Fh9DdUC6bSAAjWd1tSykrbAVVdd1fL2sqFDhwobSNdff7107drVXBMnzj\/iAGJVVZVwfe+998pxxx3npDT936lTJ0E+\/PBDs97Km5wmTJggbH7997\/\/NVN+0pu09VMtkF4L\/D8AAAD\/\/5AjFgMAAAAGSURBVAMA8nf175LNIYYAAAAASUVORK5CYII=","height":151,"width":340}}
%---
%[output:4aae92ea]
%   data: {"dataType":"text","outputData":{"text":"Wrote: \\\\Data-Server-2\\个人数据\\张天夫\\202607\\中文图Fig44D_TwoRepresentativeCellTraces.svg\n","truncated":false}}
%---

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
colorTransfer = TransferLearning.TransferColor;

f = figure('Name', '中文图44D 两个代表性细胞回合曲线', Units='centimeters'); %[output:3b858469]
f.Position(3:4) = [9, 4]; %[output:3b858469]

tlo = tiledlayout(f, 1, 3, TileSpacing='tight', Padding='tight'); %[output:3b858469]

ax1 = nexttile(tlo, 1); %[output:3b858469]
iPlotTrialSet(ax1, xsPlot, naiveRep.Signals(:, plotMask), colorNaive); %[output:3b858469]
title(ax1, sprintf('Naive\nCell %u', naiveRep.CellUID)); %[output:3b858469]
ylabel(ax1, 'z-score'); %[output:3b858469]

ax2 = nexttile(tlo, 2); %[output:3b858469]
iPlotTrialSet(ax2, xsPlot, transferRep.LearnedSignals(:, plotMask), colorLearned); %[output:3b858469]
title(ax2, sprintf('Learned\nCell %u', transferRep.CellUID)); %[output:3b858469]
ax2.YAxis.Visible = false; %[output:3b858469]

ax3 = nexttile(tlo, 3); %[output:3b858469]
iPlotTrialSet(ax3, xsPlot, transferRep.TransferSignals(:, plotMask), colorTransfer); %[output:3b858469]
title(ax3, sprintf('Transfer\nCell %u', transferRep.CellUID)); %[output:3b858469]
ax3.YAxis.Visible = false; %[output:3b858469]

allAxes = [ax1, ax2, ax3];
for ax = allAxes
	ax.FontName = 'Segoe UI Emoji'; %[output:3b858469]
	ax.TickDir = "in";
	xline(ax, 0, '--', 'LineWidth', 2);
	xline(ax, 1, '--', 'LineWidth', 2);
	xlim(ax, [-1, 2]);
end

xlabel(tlo, 'Time (s)'); %[output:3b858469]

ax1.XTickLabel(ismember(ax1.XTick, [0, 1])) = {"💡", "💧"}; %[output:3b858469]
ax2.XTickLabel(ismember(ax2.XTick, [0, 1])) = {"🔊", "💧"}; %[output:3b858469]
ax3.XTickLabel(ismember(ax3.XTick, [0, 1])) = {"💡", "💧"}; %[output:3b858469]

MATLAB.Graphics.UnifyAxesLims(allAxes, @ylim); %[output:3b858469]

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = '中文图Fig44D_TwoRepresentativeCellTraces.svg';
svgPath = TransferLearning.ExportStandardFigure(f, 1, svgPath); %[output:3b858469]
fprintf('Wrote: %s\n', svgPath); %[output:84c73696]

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
%[output:3b858469]
%   data: {"dataType":"image","outputData":{"dataUri":"data:image\/png;base64,iVBORw0KGgoAAAANSUhEUgAAAVQAAACXCAYAAABKmaMbAAAQAElEQVR4AeydB5xU1fX4z2xjV8oiAhYQKWI0Ro0FxCDmj6LRkOYvRqJELCi2xGBsFBX1r6AhRSzoj2APGj4mBjQ2RARBBBRFSdCYCFFZg\/Sls21+73t37\/J4U3b6vJk5q2fue\/ee285lvntueW+LgvqjFlALqAXUAimxQJHoj1pALaAWUAukxAIK1JSYUQtRC6gF1AIiewE13wzy97\/\/XR599FGpra01XeMeMTeujxdeeEEWLlzoitHLTFqAMUHSXefatWtlxowZ6a6moMp\/4403ZMyYMc2SzDjOmzdPRo0aJatXr85ZG+Y1UNesWSMMEsIIcY9w7Zbvf\/\/78q1vfcsdpdcZtABjgmSwSq0qRRYYOHCggel+++1nwm984xsJl\/zuu+\/Kr371K+natWvCZWQ7Y14DFeOeffbZxvtct24dt0aWLl0qDz30kNx8882yYMECmT17trz66qvy29\/+VjZu3ChffPGFTJ48WebPny933HGH3HbbbTJnzhyTVz\/SbwGv3V966SV57LHH5MYbb5RPPvnEjNfVV18tf\/rTn+SJJ56Q8ePHy\/333y8PP\/ywbNu2zdwzvmPHjpXq6mr5zW9+I1OmTDFjvn379vR3oIBreMIZj2uuucZ8n7A597feeqts2LDBjB8zRrzQ999\/X\/Bu+c4999xzwj3fMcbtnXfeMd\/Ne+65R\/74xz\/uNd5+N21koPq95TG2r02bNvKDH\/xgr6ne0UcfLccff7x06tTJfEEpqri4WA4\/\/HBZvny5MKAnnHCCGfAjjjjCxL\/11luoqaTZAnV1dSF2P+WUU+TQQw+ViooK+fzzz00Lvve978lPf\/pTCQQCMnjwYLn44osFWL733ntSX18v3bp1E8Z08eLFss8++8iIESOMTqtWrUx+\/UiPBQKBgAwfPly+853vmHHp2LGjcVK2bt0qeLHnnnuuDB06VFasWCGbNm2SDh06yBlnnCHHHnusnHrqqXLllVcKnmqvXr2kd+\/e8tFHH8nu3bvFjnd6Wp26UvMeqJjqmGOOEb5IeKbcP\/7448IX99vf\/raJJw7p27ev\/OMf\/5CvvvpKvva1r0lJSYkcd9xxZqB\/+ctfoqKSZgsAQ7fdr7rqKuN5du7cWQYMGNBce2lpqbkGmkVFe\/4Z19TUSI8ePaRPnz7yi1\/8Qg4++ODmMeaLSfkmo36kxQJ2PJjlTZs2TfhlyHhQGeNKaIXZY\/\/+\/eXOO+80cLXxjBFOz8knnyzXXXedGT873lbHr+Gef4l+bWEK2hUIBITBA5YUV1ZWJm+++aaZTvAlIw7htym\/SfFuKisrBS916tSp8uKLL8qiRYtQUUmTBZ566imzBsemkdvuS5YsMb\/8mA4yxW+petbwPvzwQ2Gjcfr06cYD4hfkAw88YMabX6QtlaHpyVsAsFZVVcmzzz4r1pHxlsoyDt+rdu3aiRuY\/OJkqWDWrFny8ssve7P5+j5GoPq6DxEbN2jQIEFQaNu2rTz55JPm\/sILLxTWcVhbu+SSS0wceoFAQG666SYzVSEPU5EJEyaYqSLXxKmk3gLYni8Qa6FDhgwxU0Br97POOsuMFVNBfrmha4WWMH086qijhKUdvJkDDjhAfv3rX5tp589\/\/nPZf\/\/9Dai5vv322810k3wqqbOAtT2hHY+DDjpIJk2aJHy\/nn76aenevbvxNtFhvNAjbdiwYWZ8iGf8mIkwo7zvvvvkZz\/7mRkv93inrtXpKSmvgZoek2mpagG1gFogvAUUqOHtorFqAbWAWiBuCyQC1Lgr0QxqAbWAWqAQLKBALYRR1j6qBdQCGbFA3gD1gw8+EA4Qjx49WsI9\/sbhfYSjHJw1tdblXOPdd99tNjLs4X+ObbCzzyFy9ILBoDnkb3crOTzOIXIO\/XNODh2VxCyQ6LgxVvfee685xP\/ll1+aym0c8Vu2bBHvuNl0Nr9sHpNRPxKygI5dqNmSBmpokZmP4WknjteMGzfOfME4jB9rKw488EC54YYbzEFkjmjs3LlT2GGkPHukiqc7OLbDQWTK5ajHIYccIldccYVwtIM4lfgtkMy4ccj\/8ssvl\/POO0\/YRWbcOMXBzvDIkSOFozjecfPmib\/FmsNaQMfOWmLvMOeBihcC4HiSgrNvgUDAPCHjfXxRIvxwKJzHTf\/1r38JkORLd+2118phhx3WnIMnPziAbCM4EsLTVK+99pr07NnTRmsYhwWSHTeO2TBWHOTnCZxVq1YJ54uXLVtmnsKhfO+4efPE0VxVdVkA2ybznfOOQz6NXc4DdceOHcKXiscL7ZhzeJvnhPFUDz\/8cIn22Ch5WSL4z3\/+Iw0NDbaIqCF6LAvw9iIed+QfWNQMmhhigWTHjQL5Jcjh\/XPOOcc8bsovxn79+pn3LvAIKjpecefxpul9bBbQsYtsp9QCNXI9aUtp3bq1cGh\/5cqVzXUAOx5zi+WxUbycgQMHmoPgfNmaC4lyAawvuugi4bA4T4Ns3rw5irYmhbNAsuPG+h3TTtbMGX9mJzziiPfD7II1VG+93jzedL2PzQI6dpHtlPNApWu8JIPH2FgL5Y1EvHjB\/fgi0xP0wgmbT4888ojZlOJpjnA63rgjjzzSvL3owQcfNC\/e4Avt1dH7li2QzLixQciLT1g3\/8Mf\/mBehsKMgbcV4Z0y\/t4WePPYNXKvnt63bAEdu\/A2ygug8tYoNpImTpxowMiba3hU1D6+yLV9fI1H3nj0zZqDNxWx1oYuejbeq2fzk85bcdBn84NHIvGGiVeJzwLJjBuPLXLSgh37yy67zDx6ev3115u3FfFYsf0l5x43bx5emBNfi1XbWkDHzlpi7zCNQN27Ir1TC6gF1AL5bgEFar6PsPZPLaAWyJgFFKgZM7VWpBZQC+S7BRICKq\/litMwaVF\/\/vnn01JuvIX6pR3xtjtb+n6yl5\/akq3xiKdeP9nLT22xNlSgWkskEfpxYJPoTtqz+slefmpL2g2fggr8ZC8\/tcWaNiGg2swaqgXUAmoBtcAeC2QFqHuq1yu1gFpALZA\/FlCg5s9Yak\/UAmqBLFsgp4HK3xjKsv1M9X5ph2lMDnz4yV5+aksODJ34yV5+aosdu+wD1bZEQ7WAWkAt4HML1H++WJBIzVSgRrKMxqsF1AJqgSYLBKurZPf8+6TBCZGm6JBAgRpiEo1QC6gF1AJ7LABMaz78i5QccqKUHvU\/0rB59Z5Ez5XPgOppnd6qBdQCaoEsWoDpPTAtO\/rHUtztRNMSwEq8ufF8KFA9BtFbtYBaQC2ABYBm3WeLBZgGKrsQZaSosqsQb248HzkN1EsvvdTTnezc+qUd2el9\/LX6yV5+akv8lsx8Dj\/ZK11tAaSsl2LdVgOukYALpsRxX9S+a9jNKT8DlbarqAXUAmqBjFiAtVI3SO0UP1zlRR7IWh0FqrWEhmoBtUBBW8C7VhrNGMA23LRfgRrNapqmFlALFIQFapc\/Z3bxmc7H2uFwm1M5A9RYO6l6agG1gFogHgsw1ecoFF5nPPnC6SpQw1lF49QCaoGCsUDd5407+fF2GAB7p\/0K1HitqPpqAbVA3lgA75TOxDPVR9+Kd9qfm0C1vdFQLaAWUAskYQE2okqaDuwnUgxeqjufAtVtDb1WC6gFCsYCnDflPGmi3qk1lBuqClRrFQ3VAmqBgrEAU33WP3k2P5WdzgOgptIcWpZaQC1QCBZoqF5tjkmluq85DVS\/vGDWL+1I9T+OdJXnJ3v5qS3psncqy\/WTvZJpC95pUWXXVJrGlJXTQDU90A+1gFpALRCHBZjup2LtNFyV+QbUcH3UOLWAWkAt0GwBzp0ms7PfXFCYCwVqGKNolFpALZCfFsA7pWeBCC83IS0ZUaAmYz3NqxZQC+SUBdLpnWKInAZqS+9DpIOZEL+0IxN9TUUdfrKXn9qSCtumuww\/2SvetqTbO8X2OQ1UOqCiFlALqAVisUC6vVPaoEDFCipqAbVAXlsgE94pBiwcoNJblYKwwF+f\/7MgVV+uLoj+aiejW4BHTJN9Zj96DXtSFah7bKFXeWCBJe8uMr3oe0I\/+evMZ8Xem0j9KDgLANOG6qqQP7SXLkMoUNNlWS034xbAI13yztty9g\/OkS4HdZWzf\/gTMXFNkM14g7TCrFqAt\/DTAJ7XT9cxKcp3S4EC1W0Cvc4HCwBOPFIgavtjoOrAlTT1VK1V8j\/EK+WP7fGH9NxvgspEzxWombCy1pF2CwDMvn1OMp6ptzI8VuLQIVTJXwsAUzvFzzRMsaoCFSuo5LQFLChZN43WEZYDoqVrWu5aAJDildKDTE7xqc8tClQRtz3iul63PCj\/eLohrjyqnFoLAFNAab3QSKUDWzxY9CPpaHxuWgCYZtMrdVstLFBra2tl3bp1QuhW9tt1Mq\/vSkVf1jpApZz7xk8lUInRAqkaN+BoYOpsPsVSNVBF362bqra4y8znaz\/Z639vvUz84JW6xzsEqNu2bZOJEyfKk08+KStWrJAnnnhCNm7c6M6j144F8E5b7x+QzkcFZPtXQSdG\/8+kBdwwZfMp1rrVS43VUv7Wy5ZXWrdyflTDhAAVz7RXr17Sv39\/KSoqktLSUqmurpZC+Ym1n9vXioFpJweo1lONNa\/qJWeBRGFKreG8VOJVcscCwJTWpmutFGgiu2aPF2TblLME2TyqtROe6chZQjpt8EoIULt27SpffPGFzJgxQ5599llZvny5HHDAAd58BX2\/w4EpBtinM58ieKp4rI13+plOCyQDU9uuWLxUjlrxtNUDD\/1e3EL9thwNM28BHiFlvTTVO\/iAE9kDzTMdmN5lwFnSc4Ag5YPGSpsRr5hOb5tC+nhz7f4IAerOnTulb9++cuONN8rIkSNl\/PjxUlFR4c5T8Nd4pEz1rSFaN4HV3muYHgtYmP38ymvDHo+KtVbrpQJMwBkuH3WxlEBdbkGftHB5NC79Fkj1C07wNAHprtl3mcZbaLa\/e7sgbUa8LOWDxjQLYG2MG2uAS16TsekjBKhM8z\/++GPZtWuX7LvvvhIIBJpUCzAI02Wvd4qKTvuxQvoEgOElUgMwJExGgCL5q6q+MI+nesHKPTANVxdxbGzZMihHJTMWsFP9VDz1BAgRPE1aX+54n+VN4ASaxEUTdPFWATFQtrohQG1oaJBNmzbJAw88IGPHjpV77rlHtmzZYvV9Fcb7PsRUNN7rnVIm7cBj1Wk\/1mhZsFfLWo0awJQrvERgxnUysmDhmzL9z9OkU6f9zaOpM557wRRHPYCUkIhIdRnQ9jmpYN8REM\/YYcdUCVN9\/rCe+0+XxNsWwAdEmdYDQtpW7gIp9\/EI4AWqhDZfCFDbtWsnF198sRx55JFyzDHHyJVXXinE2QyFHIbzTgvZHunuO14gEglusdZ\/98T\/L5WdS40M\/tFpcvudN8uIqy6Uy6++SLof0nOvYqgvljOtgNXCd68C9CYtFjBT\/UNOlFi8UwtNwOkWvFFACkSZzpc3eaTJNNgNU8opQr4HRQAAEABJREFU4sMteKcPPvigWUc97rjjjKe6detWt0qBXouE806tMXTaby2RuhBgAa5ES7QgnTDxDhl9w63y4ozXZdzYO2XK5MfN9fy35sm\/P\/2XAFBbjw1bqhPIM\/WnjS3panpyFsA7pQS7EQUw8TaDOzaaTSOuiUMAqIUm3qNXLEgpLx0SAtTNmzfL17\/+dendu7eRnj17yurV+l7JWIyv0\/5YrBS7DmucgCv2HI2aXpBWr62VUTfcIj2695QePXrJkHOGysnfOsVA9d+ffiLoUw9gBZKNpbT8aU4LvPN2y4qqkZQFjHfa7URTBtAEmHibxBMixAHWcmcKb6GJ9+gVU0gaP0KA2qlTJ2FTavHixbJo0SJzbOrggw9OYxNyp2gO8NujUrnT6txsKVPvLl3i\/3cHHK1HakFqLYA3CTjtPVA9tNdhgj75iDeQjPF1f5QVjz7lq8RnAbxT3hrFVN\/C1EKz9PCzzDGmPV7oy2Y3Pr4aUqsdAtQ2bdqYI1M1NTXm0dPRo0cLcamtNvdKY\/2U86ZNLQ8bMO3nwH\/YRI2MywJe+MWSGSgCx9HO9H6U45G681Ae910O6krQLIf26m2WA8hHfiAZl5d6Qj9B35bfXLBepMQCeKENG1aZw\/R4ocCz3Fn7ZMc\/uHOzBErKJLh9XaNUV6WkzmQKCQEqT0rNnDlTBgwYYGTWrFlm1z+ZSgopL2dSdbc\/uRHHO6UEL\/yIiyTAECiODgNT8gA9Ezrep93Nt\/WMcuA72slH\/u+dPUji9TrRp2yV1FoA75Rp\/PbpwyVYvVoqBk8w4LTP79va2PlHgC8vlQa2VoIOZBGrm+4wBKgc7HdXyv369evdUQV5zXQfWLbUebxUNq9a0tP0yBbA28NTjKyxd0o0mAJNzrCyfGABbcsmzZY0yoEqm1ZsVJ3+3QEy\/dlpNsmE1IEAXI5emcimD1se7W6K0iAFFqh5\/xnZ\/fYUZxo\/VtresFxKnF3+hs2rpah9V+FpqUBFe2GjiuUAhEdRDVg\/WywcsUIHyPL3pIAwsE1Bs6IWEQLUgw46yGxCcQ510qRJ8tlnn0n37t2jFlIIiUzlI035vf3XzSmvRWK\/t5Cz8GspJ5DDswSGQNGtT1m8xZ84oGeFsrnGa91cvYlkI6ypsu46oP+3ZepjDwvwpHyOXFHHknffNn9ShaNXpHnBSnmmoDg\/ADESZ7a8Vq99\/0+y85VxUtLzFAeoYwSPE0iWHf1jAZysqwa3rgmxQYPjyQLcVgOuEXRQIA\/CPWBNp8caAtSSkhK5\/vrrZdiwYXLBBRcIa6i8IIWGqcRmAeul6tQ\/Nnu5tQALwHPHRboGaoAOmAJDtx7lAFPjmTqbW+HKjDRV\/9tfZ5t1VbxVHgI4beDp8vjUZ2SUsyxA2rib79wLrNQLoCmPermPRdDFe0aX\/ISFJoDSCzjuWS8FpjzmiY6FKZ4oNsIzlZJycXud6DU4U3yAa3WMx\/q547E6Qp4yB8h4re586MYitMtKJP0QoK5du9a8GIXX+I0ZM0Zuu+024TpSAdmMz+S7GZnyR9rhD9cOvFSd+of\/1xHOXlYzlqNSeIZ4jeTBowwHU7xFAEd5HIdC1ytA7P+denLYp57wdu+6\/dcy\/KLLDUgpA33A\/KtrbpL3F38sUyY\/IUAXL5aySadePONoAkhZx0WHv4FFPvLngkQbu3jbDwDJA+DwHIEccRyDIr70iLPM+069MCUNeWTan40XSh5Ahx4AJc0KAAaw1julLnTsPXnRJT\/XVrhH7D3tY+mgwfGAKYO2kk5et4QAta6uzrz\/dO7cuXLZZZfJEUccYd4+5c5UaNex7PA326TpAi8VqMbipVI+0pS1YANAg0cZzQDAlCk303K8Rbcu+a3Hx6OqAAuounW819HSKQOJBLwh55xvPFm8ZFsugKQdUaXp7CqQBtA2byGFgKrB8SbxGgEeU3T6v2P6pVK\/YaVU\/HiyEGcFMJLuFfITB+TwPqPpURYwRZe6WRoAwntgWUVRRtBB0COCvAj10V5bjhesIUA98MADhVf48ZIUDvh37NhR9BwqJo1fgGpLXirAXTW7wTyFxZ9T+c\/rQSEu\/tpyOwfww7uLBC96hycITEc3Tb2JQ4AXHh\/XAJIyKM\/cn9CPIKKgS71WP6JihIRRzmYWSbSNEEACykiCDm3Ec+a6EMXCFDDZ\/hO3y1kzNTA983Zn7XSATWoxtJCLBFN3AehQL0DES2WjC1ACY\/QALMK1laLKrvayOQxUdjFruc0RTRchQA0EAnLGGWdIhw4dhKn+oEGDCv4cKlCMZYe\/yaZ7BXipQDKcBwo4KbvHoCLpflpAjjy\/yLy0mg0w4LpXQXl+AxQBDUAK11WAhSc42oHpqCaIoQcIASL5gCNCvCmvBZiih1Av5XCdiIx22kTbYskLSGkjddLGWPLkkw7gxOsDarZfxFnPtNVJI6Ts2PNsUtpCgAiIESrhnjYBVwTgIkCXqb53es89ni3p5KUMJASoRCI7duyQYFD\/tAe2QGLd4Ud3j4jgpQJVvFAAatO4tjB1r81yDVzJg47Vz+fQwgzQhOtnNJiy8cQ0250XUAFYJFx53jjyAmVvfKz3oxzA9+zRyzzCGi2PaZezQRZNJ5\/TACf9A1yECGCyMG095BHjmboBhU42hDYgABfvlem\/bT9tBrJ4t6S72xcRqH369JG2bdu6dX13He\/ruxLtABtS0fK21A4gifeJ54m3Cii5Jo60cGUDYoCLbrj0XI7z2gvQALVwfYoEU3RNvj4nNb9sGjA3T\/1j9E5tWxLxGKkPoS1DzhkqeKm0l\/twgu6cN14z4CVMBuLhys9EnLVXPHUBIrw58rgBRDwbUEzzeQJKSsoErxC9WCSRtsRSrlcHsPJLAM+aNdNIMCVfCFC3bNkiCxcuNH\/2hDf1L1261LfvQ6UDmZJI4IunfjxPu3TAdUt58VKBakt6uZwOZGh\/OG8SOAGp0c6UepTjBaJnBXCSx4IYuOKtuuOsbiwh5dAWyommTzrC5hehFdo3bOglEbNS9lPTHpUnHVmwcJ6B75y5r4U9YRCxkBxLwJMDQDQbL8\/C1MZbzxSYFu\/XUzi0D7zQ96MAVYDv7ou3nSFA5U39f\/vb3+Tuu+82j5zy96WI82YslHvWPhOd7ntsZG7xPBFz08IHekA1H71U23UgCMzsvQ3jhSnennfqb8uKNWQjCfABa28ewAlEbTy7\/+gDcOomnmt+AdD2BQvfFCvcf\/2bPeR1xzsd7fxy4HQCZ2e5x1Mlbz4JnieCJ8caIyC1oLTxdgMKmPJGqIbq1eYJKL\/bgX4gkdoZAlQU+ZtSI0aMEJ6U4o1TxKlkxwJAleWBfIQqkOKYFCByWxcAASbgM8rjmZIHXSDMtYUcgPOWg168YiHphir1AFoLbOq25XJtlwto62gHmLSd0whWuOfhAM7MjmrqD2dngSppPKBgy8vlEFjaqT39YHMHmHLtTqv96GVzNMrClHR21vH+uM5lCQEq66asn\/Iav1tuuUXY5S8vL8\/lPibVdqbceIlJFZJkZuoHqnb9Fa85ySKznh1A4dkBJHdjWoIp+QCnG6TeMtzlJXJNedQBVG09FrThykOfvpAGMHmqiocCCFcsW9X8lBXpbgGqvPCahwPwZt1puXbtndpbkDK9B6b0h02cna\/cJnUr3zSv3cMzJR4dzoRG8\/zQywUJASrrpl26dDFtLy4uNkDVP4FizJHSj3gKY\/2WNVfASj4gz7EqAJurcMXrw+MDXPQJiQWm6CF4pICM63QIZQPRWOuxXiptIZ\/tG0saxLn7yb2Vk\/t\/W3iUFbhKjv4AU+\/Unq4AUqb9dSvnS+0nr8vWyaeGwBQ9dtDzwTulLyFAJVJljwXY4Qdoe2Kyd0U7WAIArpwQALAWriwJ5Apc13z1X7Mz74ZMSzDFA+QMJ3mAXfZGIXzNtIk22lTbToAMYLm3ae6QfGWlZe6onLnGs2SKb2FqG078zpnXCi+E3vniaPOSE6Ba3vQ2feuZoo8uYT54p\/SjiA+V8BbwO6AALHDlwQCWBML3wl+xeKa0CJAQAlKey2fnmzVFpszEW2GKb0GFF2jz2XQ\/hbTP9s+2i\/Yj9j5cyDpySzrh8mUzDhDifTKNt9N7AIpUTzjMvHav9pPZAkRZK+UlJ+WDxoQ0OZ+8UzqnQMUKUSSVO\/wRq0kywYKVMMmi0podaADH9u33NfWwGcOmzGhnI4edb++0FzgxZQY4wMrPMKVDtI\/+mX6+u0hYf6UPiL1Gzyt4r+Txxvv13k7lLUyBqP3jeLS5vMkTdf9tJ+K9QjnE5Yt3Sl8UqFghgjDdj5Ck0QlYALAAxvJW5eZwO5sx1isFKKRbYUMIOAFTgAOsEqgy41lYO+WXABXb6T5TfuLpI\/0iJN0KfaOP9j7TIWDD44ylXv7sCHp2Bx+Y8qq90sMGSdur5jge6Rgj6EQT6myorhLOdkbTy7U0BWqUEWMazTplFBVNitECgARoAI+Nmzaag+0chF\/2wdJmT46igCiCLhBCHyEtF4R2A1Jvm4kHrMQDXOzBLw8LV9Kz0T8LNqbebC5FAit6rJfSxr2n+Hc5AB0rrS+Zad6eT3pLQh35ckzK29ecBirvZmSdkx1vNmW8ncvUPe1IXV35VRLAYLoLMIAJvXt9\/gvCs++nDjydWyNsOBmQdjlYLEjJgxiFNH1keuzojxu4QBX7YKc0dXGvYgGjW\/Awt0+7QOq\/+tg89glYASdwJbRCITwh9Mi0Pwtv02eKz0YT66PlztqoLRNYohtN7NprslP9TI9dtD7ZtJwGKp1gl9t6kfYYESGQBbboJCpM+d3rkmveDwqSaHn5nA8wePsHJPDGmOZbmLJuih4vbgaiwBPAWMGLAzro5LPQR2xCf+k79+nqr4UdcLR1AEOOMbFxxHSdafv26ZdKoHUnAZwcY2JabwWvFAAC0+3ThxuvlI0mduwpH4+Tst1ADgdXQG3XXtHPN8lpoAJMoMdRIoTn5HmrE4PEzjfXiXqu5LOgpjzklavqBXn8pDp55ep6WfZIgwLWMYyZvr7ztpm6c90sM581f0EUcDhqzeuml158BbfGE00nSEwlefQBuAASwnU4YBGPoANAEWsC4AgYaz953RxlAqSthz4lZX0uFF6bhx4vK+GP43FN+VYoc\/ujPxQLU7xS0mz5tmzWRAEy+S1c0bHiPWKFXj5JWoAKjKwAvXQZzO2dUgdQJfzXCw7o3gua94uyDorHSnysQtvJZ8sjHwA94LiAnDm52Ahxa5w63IBFJ8UeLNX4VvBAzXS16gvBC8XbtI0FonhehMRxPGrCxDuERzA5zG43m0hTic0CwBDPEWFDB2ABTsCGAC1bEjpADiEfQtq2KWcJ3igwBYoAECk79qdSceZtxvPkj+Ntm3Km7PjLVbJr7m8aZfZ4qW06BkU+AGun7rZsykfwZCkToX63eHXRzydJKVABEQLorJHwEmOFKuBjqk4ZNuzKlBMAABAASURBVH+kkDKtd2p1Fo5vkHfub5CqxUF58\/Z6WflKULqfFhA8V8q2etFCyqX9bu8USALPb15aJAccGzBy5oMOWBEXYCkXwOK5cp3PwhSf6Tx9BKSAE2+TKSxxpFtxw\/SCoZcIU3300VOJzwLACgFWAWd6LnU1jcBzwCf1NRJ07oEWOt6St005yzyphDcKFNGzOlwzbW\/leKvlg8ZKoLKrKWv321P2OlNa7qyXAm+jO+CamDeibD35HqYMqG4I8hQP3h3C1Hvt8mCLf9bD5gdk6LdkeHR+88oIowbAmIZ\/4nimQO+it0uEEKiSRjuAqq3DZIrwwS8A2uxeO102tUHwToGpNxtxNz94mVjAUi\/61OvV9du99TABn20b10zZCUm38e6QNLuBxF91eGraY8LhfNZHeSYdqFpg3u14pXimnDV9bvpLppi5cxaYJ6XMTZY\/MvVOzVR0s27lfMe7HG+ETaFtjhfJFNxCz3qW2ww45+9VJXHB6tVmao83CkD3UnBuWNvE6wWarI8inCVF7OYT9kLHTuudbFn7n7ZkrfIIFacEqNb7A1yIuy7AhJfIFBo9PEB3OteAjnT0yA9U0SU+nMdqyyguk8a1TAd4XU4MyLkzHZAOb+zSN53QDTfKBcKUaeukHLdQJ3XTZnQQt3fKfUvirbclfdKB7yvOmix1cR9JUhkPFPEwmaoDRyDK9J06gCEwJZ14rtFHuEefd3ledOl55vgTeQAmIW9YAqyr\/rNSeDUdr6gjbdQNtwjloNO+svFgP9cqsVugEah3mQxM2fE0KwZPEIS1UELiAOc2B7bbHLCyiw98iSvrd5l5I344mFIo8UWVXYTpPPduYfOJ++DWNYJOOA+Y9EKXRvokYQUAhfcHsKIVAyzRwwMEXIAMffIDOkBmwTL\/jgZ57+EGIfznX4PyqTN1Jw\/6iNVf93cRpuKnjCuW3t8vEgtCykbccANYDXViygLSthzKok2IjSOd+hC8TcCMJ0p6LOKutyVI0mfqoFyWC2hnS3nQTUYAI\/lZ4yQEfgvemiffPOZ4qampEe7xMkkHrlYfb\/OpaY\/K2HE3Nr\/b076SDmDytBMH9SkTsE5wvFPuSSOOciiPa5X4LcBLmAFnoFUbZ61zjOBp2vVJ1kzxGgEf4LRgZb2UfMRRI0sFhJEEqDKdD1ZXhahY0KITkqgRxgJJARUYmlKcj9dGOjvgjpf1SpMwBffKiyPq5Yu3grK1KigADGABNB7vBCoIU+ueZwakbRcxAiQ\/fq4RsMufbGheOmB6v7s6KMB058ag0wIRQIiwtkr5tA+4sZGEwtKHGoSyaMNSB9gNtSLoAnOWKYA+IULcl85a7Bpn44kyyB+rAPPDHMC36xoQIBkpn4Up7TNLBs56LLrkIY3rVAtQA554j8eeeLic\/t0BMvWxh40M\/tFpYoUpPHL51RfJI046enibfU84yfzpZAtSb\/t4fBSwko5wjw71ErLOSqiSgAVKysxb7ZmaAzXEloLHiABM0os69JDyM283U\/x9hkw1L28GuFY\/Wkh+pvVseCHAFQG0gYr20bIWfFrCQAVWwBDvEU+yyoEP1iwuFbPeiFeHAJbjrywS5PD\/KRJgA9jwPIHVl0uCMvfmegGQ6AOvLn0DxuPk+vgripp31ckHaAAd8K08JCDAFCDj\/bL2CQzxlglZRgDaeJcAi7VV4EUbENZYqz8TQZ+2u4X2ILSbvrrTIl1TJkDHLshxTtvR5ZeM1+vknj7QZ9qHHiHtpI2k0Vfiw8myRxokWnq4PMQB0tvvutlM1fk7SKNvuFXwIhHezcmr5LhGuC4rKzNTdXbnX3tpvlww9GIjlBWrMNVnmQCvN9Y8qhdqAbxQPFI3SEO1xGwUAcUiZ\/pe8cPfN6sA3OabKBeUb8Dc7USjBVxrPvyLOZ8qJeUmTj\/CWyBhoFIcMMTjw4s0sHqwWIBgaYUIUCSs7C5SVOJA1tkd73VmQL52dsB4leQhLyAGKuQnL\/Ba62xi4SECOq43fBSUAbcWCeuk6AM6QC0BEfTwLNGlTNplhXhAC+QoF7jasmgH9X7yfIO4gQek8KwBGulHDSsSwEx+W26kkLba9lA3AhwBrdfr5B5vnD57ywOs1E0baI83nTiT5qwdu9vu1Qt3z5ElwMkLkIHjKGdtEy8ScJLWo3sv4dpIaZmMcoD7vw8+Lvf\/foopDk8TYb2V9VRgaRKifKDPSYAoKpoUgwViBSJFAUWOVuFh4lkCY+LjEeoDrAgg5z6e\/IWomzBQqxzPErjxxcer8hrPwgXvEc8R4CEAB6+SqTqwIb+FCtAiH\/oWjniaCHnRw8slb2V3kVbtwnuX7raQj\/KIA662LNoB9GkDaQDODVILeNK6nxYQ2kX7uA8nQJN46iO0Ahz5ZUC7gSAARIBpOLvZfPQV25AHb9bGW5jSboR42k481y3JuvVrBXACODadgB1gJF\/fE\/oJYiFp11CJY6pOiJeJ2DSb3+ahHLeQzj35CVUyZwFA2LB5teCtKgwzY\/eEgUrz+MLzxecaoFjgAC0gBkyBkYUjegAHmLHG2a5LwHi05MOLJJ28bn3irJAXLxcgU0ZZW5sSPaQ88iJWk2sgCfAAG3CiP26QWl1C+oM+\/eTeK\/SHNnnjuacu2j14SjG3ZiONusxNlA9six7ARA1oAljaSrsR2v7NS4uEeDd40Q8nwBAwAjigiA7XxNlrq8N9NCGf1QWcgNkNVq51qh\/NgulPw7PEW01\/TVoDFkgYqObLPrwxO0AEKBQIPAiBGMK1V9ABPuRhGk46wCKe62iCTqy60cohjTbQdq6BE33iOpzQF+qlzTaP1du5vnHpAR0b5w1pN0DGuwba1IcOZWEDK15g2zbh1QJNC1N3vvbdA4IHzC8oyoxHACkSTx6vbiSwAlk8Ya++3qsF8tUCjURMsHd8qd2eJdCItSh0ARRQ4zoajLxlxqPrzeu9Z33UGxfpnnrxoMkDAIEfgj59IIwm9JVTBVYH+1EW8VaALjalfKsHRNnAw1sFxOQjzeYhPPrCouZjY6RlQ7xg5R7JRlu0TrVANiyQMFDtlxrAxAKTcJ0DUEi4tEzE0W4AZ\/sSa50sY7Aei7eKlDlrubHkpT70gCXQ5JqysIEV7rEp5aND24AoXi3eKnnJR1k2jw2JF5GsB0DULgVkvTHaALVABi2QMFD5QiMZbGtIVal4HyLeXUjBMUTQdzxs5LEnp8aQo1GFfMCSfFw3xoZ+koYOHiwQBawAlrykhebInZhUjFuqeuuntqSqT+ksx0\/28lNbrM0TBqotINdD4MQ0u6V+ADQLNqubqGdIneS15UQK0cFjBaKAFfiTN5K+xqsF1ALZtUDBAxXzAyqAybVXiEcsdG3o1UvnPRAFrITx1qP6agG1QOYsoEB1bA2o3KBkowmIIjaedU2gxlEw4p1s+r9aQC2gFtjLAgrUJnPgpTKlZ53SQpQkQApwuUaYfhOmUgA4ksoytSy1gFog8xbIaaCm8n2IQBOoAlA8Ue4R75AQB3DdXmoy7QCknBRA3GV66\/XeA\/949E1+n3wkY69Ud8FPbUl139JRnp\/s5ae2WFvnNFBtJ1IVsgkUS1mANxa9WHSAM8sIdkc\/FkgCYcombyz66KqoBdQC6beAAjUBG4fzUm0xFnb2vqWQc7AAGpjjGbObj\/cZLR8gJQ\/CdTRdTVMLqAUyZwEFaoK2BmburHiKdv2Va3dapGvgi3cKTK0OUGWdNloZQJg8gJ12RNO15YaGGqMWUAuk2gIK1AQtCsysd1izVczbqIAbQLTxLRWNHnm8epSNpxoOlBbCNg9Aphx7r6FaQC2QPQsoUJOwPTDEK6UINrMAIdfEh4MhaVYAI9d4moRewUsNB0riKN\/qk5\/7luqz+hqqBdQC6bOAAjUJ2wJQNpO8rxEkHvBFK5p0QBhJhzJId4MyEoTRpbxIZcUQrypqAbVACiygQE3SiHiI4YrwwtCtEwmMbh2uvaAEmpRLmleIt+V60\/ReLaAWyIwFFKhpsrOFYTjIRQOjtzmA0nqpdjPKq8M99UWCO+kqagG1QPotkNNAXbVqVfotFEMNkdoBDIGgLQIwIsTFCj9ACYA5SsUGlC0rXDhp0qRw0c1xLaVbxXSHkeyV7nrDle+XtrQ0Ni2lh+tbOuL8Yi\/65pe2uMcmIaD269dPevbsmXXBoH5ux4k\/7GV2\/6ff9baweTXn+UWC8b9\/86Fx2e6ZOfcJEP7l+POj5lu8eDH\/ziIK6X62Vzba5pd\/Q4xNxIFzEkjPhn28dfrFXrTLL21hbJwhMv8nBNSnn35aVq5cqRKDDdi0OvUH\/YRTAEPGniR3Th0Zt93IQ\/6Zrz8TNS\/jYkY1wgfpOm7+\/HfL2EQYNhNNuo6d\/8cuIaCaEdaPmCzA1J5pe0zKflTSNqkF1AIxW0CBGrOpVFEtoBZQC0S3gAI1un00VS2gFlALxGyB3ATq2nkiH1wnsvpJkR2fxdzZdCn+fu5KmfV5XbqK91G5+dUUHbc4x9NH3zu\/jl1CQA0GgzJ\/\/nxZunRpnCOSAvV1C0VW3C6yz1aRA78rUrfEkeoUFJxYEZ9v2iWrW+8vi4IlUr07sTJSkYsdz\/Hjx8v9998vW7c6tglTaFbHrak9G9ZvkDmz35DPV31pYh5YstOEmf7wy7jR75wYOx997\/w8dgkB9dFHH5U5c+bIpk2b+PeQWVk3T6SiwvFMAyKrfitSu8q5\/iizbXDV9vT76yVQ0VrEseRzVa6EDF+2b99ebrrpJjn++ONl5syZYWvP5rgtWfKevPfuB\/L+Ox9KaaBC9mm9j2zY2SDf2Dco9y\/ZEba96Yz0y7jRR7+PHW0UH33v\/Dx2DgaMueL6GD58uPTv3z+uPClTbtNdpD7oiPMl3LpOZOO\/RUo6pKz4eApaunKrrGm1n0iDSLGT8b+lIp+Fdw6d1PT+v++++0pxcbHU1tYK1+FqS\/G4hasiclxdUMpKyqVNRaXTzlJpaAhKQ02NzKneR2oasF7krKlO8dO40TfGy9djRyN98r3z+9gVYauWBE901qxZ8sYbb8jOndmZojW3sdt5IpVHOF7pVpFta0VaHSWyz2HNyZm8eOmdnRKsd7xlB6jBepGiYpEZnzuwz2QjXHUtXLhQ3nvvPTnjjDNMrJ\/GraioREpKSqXIkZKiEqnZVSfbN2yQyh11smNTjWlvpj78Nm70289jR\/vEJ987v49dTEDlNyhf0oEDB0oF021j4Sx+HOlM9YMBkdJ2It1+kbWG1NR2kKL1IvXO75hdW0TqHNnhOM3ZaNDs2bNl\/fr1MnLkSCktLTVN8NO4BZ1fOvW1RVJa3AjWutp6Kd+3s5Rsr5aVtY3tlQz9+Gnc6LLfx442GvHB987vY1dkDJVjH7scL3nWRyfL8u3DstryrhUlUrTWacJnzlLuFyI7\/xmU1luy46G++eabMnfuXBk7dqxMnz7daVRm\/2+ptkMP6yEdO7WVGtkp9c6ZDDH2AAADbklEQVR\/dXU1csC+pfLZ7nK55xTHtW+pgBSm+2nc6Jbfx442In743vl97BIG6qBBgwTB0JkWxzeVmtLDZdkH2YGX7e953xHZz7FgSZVI8OOglK9tkItOdSKsQgbDO+64Q373u98JO\/1DhgyJWDNjhkRUSFPCvh3byf5d95MTTzpOvnFsb2lbWWFq+t2PWkvn9qWSyR8\/jRv99vvY0UbED987v49ddr79jE4S0spZdvjexYPlgl85REuinGSztmsjMmaEyMTrRH59XUBuuaxYiEu23HzPX1FRLvsf1Clr3WSMdNziN78fvnd+H7ucBGr8\/xQ0R0YtoJWpBQrUAgrUAh147bZaQC2QegsoUFNvUy1RLaAWKFALKFALdOAz122tSS1QOBZQoBbOWGtP1QJqgTRbQIGaZgNr8WoBtUDhWECBWjhj7YeehrRhwYIFcsoppzTL4MGDZfLkyfLRR4m\/8Kaqqsq8vEc8P7zQhzRPtN6qBVJmAQVqykypBSVigZNPPll4Uuj888+XW2+9VV588UW58MIL5dBDD5Vt27aZVxGuW7fOvPSFcPfu3aaa+vp64R4dE9H0wSsKKaN3795idbZs2WJSjzrqKOGdFOiYCP1QC6TYAgrUFBtUi0veAjNmzJCPP\/5YJkyYIFOmTJGHHnpIeFPWyy+\/LNdff72sWbPGwPe1114zT4YtW7ZM7A9pAPTAAw+Ue++9V+bNmyfjxo2TRYsWSceOHWXDhg0mv9XXUC2QSgsoUFNpTS0rLgu0pNyuXTv5yU9+ImeffbacdtppMmzYMOnevbv885\/\/NN5rZWWldOvWTV599VWxP7wgplOnTlJcXCx4orx9i0dx+\/TpI4FAQAAtOlZfQ7VAKi2gQE2lNbWslFqgpKREysvLhR+uCRFgCUiB5Omnny7nnnsu0c1iXzF53nnnybXXXisrVqyQadOmmfS6ujoT6odaIB0WUKCmw6paZlot0KNHD7Om+tRTT8mkSZOEKb6tsEuXLrJ9+3azfvrMM8+YPwnDBlfPnj0FmOKdomP1NVQLpNICCtRUWlPLStgCV1xxRfPby4YOHSpsIF133XXSuXNnc02cOD\/EAcRRo0YJ1\/fdd58cc8wxTkrj\/x06dBDk008\/NeutvMlp4sSJwubXf\/\/7XzPlJ71RWz\/VAqm1wP8BAAD\/\/29kKlUAAAAGSURBVAMAqTDF7yRSBJMAAAAASUVORK5CYII=","height":151,"width":340}}
%---
%[output:84c73696]
%   data: {"dataType":"text","outputData":{"text":"Wrote: \\\\Data-Server-2\\个人数据\\张天夫\\202607\\中文图Fig44D_TwoRepresentativeCellTraces.svg\n","truncated":false}}
%---

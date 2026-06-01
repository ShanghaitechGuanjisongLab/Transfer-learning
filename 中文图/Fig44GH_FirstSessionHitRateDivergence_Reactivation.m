% Combined Chinese Fig44G/H: divergence correlations in a 1-by-2 layout.

LAB = TransferLearning.LightAudioBaseline();
LAI = TransferLearning.LAInterspersed();
ALB = TransferLearning.AudioLightBaseline();

xs = TransferLearning.Xs;
if isduration(xs)
	xsSec = seconds(xs);
else
	xsSec = double(xs);
end
[idx0, ok0] = iFindTimeIndex(xsSec, 0, 0.25);
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok0 || ~ok1s
	error('Fig44GH:TimeIndexMissing', 'Cannot find 0 s or 1 s sample in TransferLearning.Xs.');
end

naiveA = iCollectNaiveFirstSessionData(LAB, "LightAudioBaseline", strings(0, 1), idx0, idx1s);
badNaiveLai = iFindMiceWithAudioWaterInPhase(LAI, "Naive");
naiveB = iCollectNaiveFirstSessionData(LAI, "LAInterspersed", badNaiveLai, idx0, idx1s);
dataG = [naiveA; naiveB; iCollectTransferFirstSessionData(ALB, idx0, idx1s)];
dataG.Group = categorical(string(dataG.Group), ["Naive", "Continual"]);

reactivationTable = iBuildTransferReactivationTable(ALB);
if isempty(reactivationTable)
	error('Fig44GH:EmptyReuse', 'No valid mice for reactivation summary.');
end
divergenceH = iBuildTransferDivergenceTable(ALB, string(reactivationTable.Mouse), reactivationTable.DateTimeTransfer, idx0, idx1s);
dataH = outerjoin(reactivationTable(:, {'Mouse','DateTimeTransfer','Reactivation'}), divergenceH, 'Keys', 'Mouse', 'MergeKeys', true, 'Type', 'left');

groupColors = TransferLearning.GroupColors(["Naive", "Continual"]);
colorNaive = groupColors(1, :);
colorContinual = groupColors(2, :);

f = figure('Color', 'w', 'Name', 'Chinese Fig44GH divergence correlations');
f.Units = 'centimeters';
f.Position(3:4) = [12.4, 8];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 12.4, 8];
f.PaperSize = [12.4, 8];

layout = tiledlayout(f, 1, 2, 'TileSpacing','loose', 'Padding', 'tight');

axG = nexttile(layout, 1);
statsG = iPlotFirstSessionHitRateVsDivergence(axG, dataG, colorNaive, colorContinual);

axH = nexttile(layout, 2);
statsH = iPlotReactivationVsDivergence(axH, dataH, colorContinual);

for axItem = [axG, axH]
	if isprop(axItem, 'Toolbar') && ~isempty(axItem.Toolbar)
		axItem.Toolbar.Visible = 'off';
	end
end

svgPath = TransferLearning.ExportStandardFigure(f, 2, '中文图Fig44GH_FirstSessionHitRateDivergence_Reactivation.svg');
fprintf('Wrote: %s\n', svgPath);

fprintf('\n=== Fig44GH / panel G ===\n');
fprintf('Naive mice: %d\n', statsG.NNaive);
fprintf('Continual mice: %d\n', statsG.NContinual);
fprintf('Spearman rho=%.3f, p=%.4g\n', statsG.Rho, statsG.PValue);
fprintf('\n=== Fig44GH / panel H ===\n');
fprintf('n=%d, rho=%.3f, p=%.4g\n', statsH.N, statsH.Rho, statsH.PValue);

assignin('base', 'Fig44GH_FirstSessionData', dataG);
assignin('base', 'Fig44GH_FirstSessionStats', statsG);
assignin('base', 'Fig44GH_ReactivationData', dataH);
assignin('base', 'Fig44GH_ReactivationStats', statsH);

function stats = iPlotFirstSessionHitRateVsDivergence(ax, Data, colorNaive, colorContinual)
use = isfinite(Data.Divergence) & isfinite(Data.HitRate);
if nnz(use) < 3
	error('Fig44GH:TooFewPanelGPoints', 'Too few valid mice for panel G correlation.');
end

xAll = Data.Divergence(use);
yAll = Data.HitRate(use);
if std(xAll) <= 0 || std(yAll) <= 0
	error('Fig44GH:PanelGZeroVariance', 'Panel G mice have zero variance for correlation.');
end
[rho, pValue] = corr(xAll, yAll, 'Type', 'Spearman');

maskNaive = use & (string(Data.Group) == "Naive");
maskContinual = use & (string(Data.Group) == "Continual");

hold(ax, 'on');
box(ax, 'off');
ax.FontSize = 12;
ax.LineWidth = 2;
hNaive = scatter(ax, Data.Divergence(maskNaive), Data.HitRate(maskNaive), 5, colorNaive, 'o', 'filled', 'LineWidth', 0.2);
hContinual = scatter(ax, Data.Divergence(maskContinual), Data.HitRate(maskContinual), 5, colorContinual, 'o', 'filled', 'LineWidth', 0.2);
fitP = polyfit(xAll, yAll, 1);
xFit = [min(xAll), max(xAll)];
yFit = polyval(fitP, xFit);
plot(ax, xFit, yFit, '-', 'Color', 'k', 'LineWidth', 2);
xlabel(ax, 'Divergence', 'FontSize', 12);
ylabel(ax, 'First block hit rate', 'FontSize', 12);
legendHandle = legend(ax, [hNaive, hContinual], {'Naive', 'Continual'}, 'Location', 'northoutside', 'Orientation', 'horizontal');
legendHandle.FontSize = 12;
legendHandle.Box = 'off';
iText(ax, 0.97, 0.97, iPLabel(pValue), 'Units', 'normalized', ...
	'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', 'FontSize', 12);
grid(ax, 'off');

stats = table("G", rho, pValue, nnz(maskNaive), nnz(maskContinual), ...
	'VariableNames', {'Panel','Rho','PValue','NNaive','NContinual'});
end

function stats = iPlotReactivationVsDivergence(ax, Data, dotColor)
x = double(Data.Divergence);
y = double(Data.Reactivation);
use = isfinite(x) & isfinite(y);
if nnz(use) < 3
	error('Fig44GH:TooFewPanelHPoints', 'Too few valid mice for panel H after filtering.');
end

hold(ax, 'on');
box(ax, 'off');
ax.FontSize = 12;
ax.LineWidth = 2;
scatter(ax, x(use), y(use), 5, dotColor, 'o', 'filled', 'LineWidth', 0.2);
if nnz(use) >= 2 && std(x(use)) > 0
	fitP = polyfit(x(use), y(use), 1);
	xFit = [min(x(use)), max(x(use))];
	yFit = polyval(fitP, xFit);
	plot(ax, xFit, yFit, '-', 'Color', 'k', 'LineWidth', 2);
end
if std(x(use)) > 0 && std(y(use)) > 0
	[rho, pValue] = corr(x(use), y(use), 'Type', 'Spearman');
else
	rho = NaN;
	pValue = NaN;
end
xlabel(ax, 'Divergence', 'FontSize', 12);
ylabel(ax, 'Reactivation', 'FontSize', 12);
iText(ax, 0.97, 0.97, iPLabel(pValue), 'Units', 'normalized', ...
	'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', 'FontSize', 12);
grid(ax, 'off');

stats = table("H", rho, pValue, nnz(use), 'VariableNames', {'Panel','Rho','PValue','N'});
end

function out = iCollectTransferFirstSessionData(DS, idx0, idx1s)
T = DS.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex","Behavior","Stimulus","Phase"], Phase="Transfer");
if isempty(T)
	out = iEmptyFirstSessionOutputTable();
	return;
end
T.Mouse = string(T.Mouse);
T.Stimulus = string(T.Stimulus);
T.Phase = string(T.Phase);
T.DateTime = iNormalizeDateTime(T.DateTime);
T = T(T.Stimulus == "LightWater", :);

mice = unique(T.Mouse);
rows = cell(numel(mice), 1);
for iM = 1:numel(mice)
	mouseName = mice(iM);
	Tm = T(T.Mouse == mouseName, :);
	if isempty(Tm)
		rows{iM} = iEmptyFirstSessionOutputTable();
		continue;
	end
	dateTime = min(Tm.DateTime);
	sessionTable = sortrows(Tm(Tm.DateTime == dateTime, :), 'TrialIndex');
	rows{iM} = iFirstSessionRow(DS, mouseName, dateTime, sessionTable, "Continual", idx0, idx1s);
end
out = vertcat(rows{:});
end

function out = iCollectNaiveFirstSessionData(DS, sourceName, badMice, idx0, idx1s)
T = DS.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex","Behavior","Stimulus","Phase"], Phase="Naive");
if isempty(T)
	out = iEmptyFirstSessionOutputTable();
	return;
end
T.Mouse = string(T.Mouse);
T.Stimulus = string(T.Stimulus);
T.Phase = string(T.Phase);
T.DateTime = iNormalizeDateTime(T.DateTime);
if ~isempty(badMice)
	T = T(~ismember(T.Mouse, string(badMice)), :);
end

mice = unique(T.Mouse);
rows = cell(numel(mice), 1);
for iM = 1:numel(mice)
	mouseName = mice(iM);
	Tm = T(T.Mouse == mouseName, :);
	if isempty(Tm)
		rows{iM} = iEmptyFirstSessionOutputTable();
		continue;
	end
	sessions = sort(unique(Tm.DateTime), 'ascend');
	chosenDateTime = NaT;
	chosenTable = table();
	for iSession = 1:numel(sessions)
		Tss = Tm(Tm.DateTime == sessions(iSession), :);
		if any(Tss.Stimulus == "LightWater") && ~any(Tss.Stimulus == "AudioWater")
			chosenDateTime = sessions(iSession);
			chosenTable = sortrows(Tss(Tss.Stimulus == "LightWater", :), 'TrialIndex');
			break;
		end
	end
	if ismissing(chosenDateTime) || isempty(chosenTable)
		rows{iM} = iEmptyFirstSessionOutputTable();
		continue;
	end
	rows{iM} = iFirstSessionRow(DS, mouseName, chosenDateTime, chosenTable, "Naive", idx0, idx1s);
	rows{iM}.Source(:) = string(sourceName);
end
out = vertcat(rows{:});
end

function out = iFirstSessionRow(DS, mouseName, dateTime, sessionTable, groupName, idx0, idx1s)
out = iEmptyFirstSessionOutputTable();
trialUIDs = unique(uint64(sessionTable.TrialUID), 'stable');
if numel(trialUIDs) < 2
	return;
end

behavior = double(sessionTable.Behavior);
behavior = behavior(isfinite(behavior));
if isempty(behavior)
	return;
end
hitRate = mean(behavior);

nts = DS.QueryNTS(struct('Stimulus', "LightWater", 'Mouse', mouseName, 'DateTime', dateTime), UniExp.Flags.ZScore, 1:24);
if iscell(nts)
	nts = nts{1};
end
if isempty(nts)
	return;
end

[ctt, ~] = iBuildCTT(nts, trialUIDs, idx0);
if isempty(ctt) || size(ctt, 2) < 2
	return;
end

xAt1 = ctt(:, :, idx1s);
divValue = iAllCellDivergence(xAt1);
out = table(string(mouseName), string(groupName), double(hitRate), double(divValue), iNormalizeDateTime(dateTime), "", ...
	'VariableNames', {'Mouse','Group','HitRate','Divergence','DateTime','Source'});
end

function T = iEmptyFirstSessionOutputTable()
T = table(string.empty(0, 1), string.empty(0, 1), nan(0, 1), nan(0, 1), NaT(0, 1), string.empty(0, 1), ...
	'VariableNames', {'Mouse','Group','HitRate','Divergence','DateTime','Source'});
end

function R = iBuildTransferReactivationTable(DS)
xs = TransferLearning.Xs;
if isduration(xs)
	xsSec = seconds(xs);
else
	xsSec = double(xs);
end
baseMask = (xsSec >= -3) & (xsSec < 0);
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
	error('Fig44GH:No1s', 'Cannot find sample close to 1 s.');
end

learnedTable = DS.TableQuery(["Mouse","DateTime"], Phase="Learned", Stimulus="AudioWater", Design="AudioWater");
transferTable = DS.TableQuery(["Mouse","DateTime","Behavior"], Phase="Transfer", Stimulus="LightWater", Design="LightWater");
if isempty(learnedTable) || isempty(transferTable)
	R = iEmptyReactivationResult();
	return;
end

learnedTable.Mouse = string(learnedTable.Mouse);
learnedTable.DateTime = iNormalizeDateTime(learnedTable.DateTime);
transferTable.Mouse = string(transferTable.Mouse);
transferTable.DateTime = iNormalizeDateTime(transferTable.DateTime);

learnedDateTimes = groupsummary(learnedTable, "Mouse", "max", "DateTime");
learnedDateTimes.Properties.VariableNames{end} = 'DateTimeLearned';
transferDateTimes = groupsummary(transferTable(:, ["Mouse","DateTime"]), "Mouse", "min", "DateTime");
transferDateTimes.Properties.VariableNames{end} = 'DateTimeTransfer';

sessions = innerjoin(learnedDateTimes(:, ["Mouse","DateTimeLearned"]), transferDateTimes(:, ["Mouse","DateTimeTransfer"]), 'Keys', 'Mouse');
if isempty(sessions)
	R = iEmptyReactivationResult();
	return;
end

rows = repmat(iEmptyReactivationResult(), 0, 1);
for iRow = 1:height(sessions)
	mouseName = string(sessions.Mouse(iRow));
	dateTimeLearned = sessions.DateTimeLearned(iRow);
	dateTimeTransfer = sessions.DateTimeTransfer(iRow);

	learnedNtats = DS.QueryNTATS(struct('Mouse', mouseName, 'DateTime', dateTimeLearned, ...
		'Phase', 'Learned', 'Stimulus', 'AudioWater', 'Design', 'AudioWater'), ...
		UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
	transferNtats = DS.QueryNTATS(struct('Mouse', mouseName, 'DateTime', dateTimeTransfer, ...
		'Phase', 'Transfer', 'Stimulus', 'LightWater', 'Design', 'LightWater'), ...
		UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);

	[XLearn, cellLearn] = iExtractNtats2D(learnedNtats);
	[XTransfer, cellTransfer] = iExtractNtats2D(transferNtats);
	if isempty(XLearn) || isempty(XTransfer)
		continue;
	end

	[commonCells, idxLearn, idxTransfer] = intersect(cellLearn, cellTransfer, 'stable');
	if isempty(commonCells)
		continue;
	end

	XLearn = XLearn(idxLearn, :);
	XTransfer = XTransfer(idxTransfer, :);
	learnedActive = iIsActiveAt1s(XLearn, baseMask, idx1s, 3);
	transferActive = iIsActiveAt1s(XTransfer, baseMask, idx1s, 3);
	[nLearnedActive, reactivation] = iConditionalProb(learnedActive, transferActive);

	behavior = double(transferTable.Behavior(transferTable.Mouse == mouseName & transferTable.DateTime == dateTimeTransfer));
	transferHitRate = mean(behavior, 'omitnan');
	rows = [rows; table(mouseName, dateTimeLearned, dateTimeTransfer, transferHitRate, nLearnedActive, reactivation, "AudioLightBaseline", ...
		'VariableNames', iEmptyReactivationResult().Properties.VariableNames)]; %#ok<AGROW>
end

R = rows;
end

function T = iEmptyReactivationResult()
T = table(strings(0, 1), NaT(0, 1), NaT(0, 1), nan(0, 1), nan(0, 1), nan(0, 1), strings(0, 1), ...
	'VariableNames', {'Mouse','DateTimeLearned','DateTimeTransfer','TransferHitRate','NLearnedActive','Reactivation','Source'});
end

function Div = iBuildTransferDivergenceTable(DS, mice, dateTimes, idx0, idx1s)
Div = table(strings(0, 1), nan(0, 1), 'VariableNames', {'Mouse','Divergence'});
for iMouse = 1:numel(mice)
	mouseName = string(mice(iMouse));
	dateTime = iNormalizeDateTime(dateTimes(iMouse));
	T = DS.TableQuery(["TrialUID","TrialIndex","Mouse","DateTime","Stimulus","Phase"], Mouse=mouseName, DateTime=dateTime, Stimulus="LightWater", Phase="Transfer");
	if isempty(T)
		continue;
	end
	T = sortrows(T, 'TrialIndex');
	trialUIDs = unique(uint64(T.TrialUID), 'stable');
	if numel(trialUIDs) < 2
		continue;
	end
	nts = DS.QueryNTS(struct('Stimulus', "LightWater", 'Mouse', mouseName, 'DateTime', dateTime), UniExp.Flags.ZScore, 1:24);
	if iscell(nts)
		nts = nts{1};
	end
	if isempty(nts)
		continue;
	end
	[ctt, ~] = iBuildCTT(nts, trialUIDs, idx0);
	if isempty(ctt) || size(ctt, 2) < 2
		continue;
	end
	xAt1 = ctt(:, :, idx1s);
	divValue = iAllCellDivergence(xAt1);
	Div = [Div; table(mouseName, divValue, 'VariableNames', Div.Properties.VariableNames)]; %#ok<AGROW>
end
end

function div = iAllCellDivergence(xAt1)
if size(xAt1, 1) < 3
	div = NaN;
	return;
end
totalSignal = sum(mean(xAt1, 2).^2);
totalNoise = sum(var(xAt1, [], 2));
if totalSignal > 0
	div = sqrt(totalNoise / totalSignal);
else
	div = NaN;
end
end

function [ctt, cellUIDs] = iBuildCTT(nts, trialUIDs, idx0)
ctt = [];
cellUIDs = uint64([]);
keepTrial = ismember(uint64(nts.TrialUID), trialUIDs);
nts = nts(keepTrial, :);
if isempty(nts)
	return;
end
trialUIDs = trialUIDs(ismember(trialUIDs, unique(uint64(nts.TrialUID), 'stable')));
if numel(trialUIDs) < 2
	return;
end
allCells = unique(uint64(nts.CellUID), 'stable');
traceCell = cell(numel(allCells), 1);
keepUID = zeros(numel(allCells), 1, 'uint64');
nKeep = 0;
for iCell = 1:numel(allCells)
	cellUID = allCells(iCell);
	rows = uint64(nts.CellUID) == cellUID;
	rowTrialUID = uint64(nts.TrialUID(rows));
	signal = double(nts.TrialSignal(rows, :));
	[matched, loc] = ismember(trialUIDs, rowTrialUID);
	if ~all(matched)
		continue;
	end
	ordered = signal(loc, :);
	if any(~isfinite(ordered), 'all')
		continue;
	end
	nKeep = nKeep + 1;
	traceCell{nKeep} = ordered;
	keepUID(nKeep) = cellUID;
end
if nKeep < 1
	return;
end
traceCell = traceCell(1:nKeep);
cellUIDs = keepUID(1:nKeep);
nTrial = size(traceCell{1}, 1);
nTime = size(traceCell{1}, 2);
ctt = nan(nKeep, nTrial, nTime);
for iCell = 1:nKeep
	ctt(iCell, :, :) = traceCell{iCell};
end
ctt = ctt - ctt(:, :, idx0);
end

function [X, cellUID] = iExtractNtats2D(G)
cellUID = uint64([]);
X = [];
if isempty(G)
	return;
end
nt = G.NTATS;
cellUID = uint64(G.CellUID);
if isa(nt, 'MATLAB.DataTypes.NDTable')
	X = nt.Data;
else
	X = nt;
end
X = double(X);
if ndims(X) == 3
	X = squeeze(X(:, :, 1));
end
end

function active = iIsActiveAt1s(X, baseMask, idx1s, kSigma)
baseMu = mean(X(:, baseMask), 2, 'omitnan');
baseSd = std(X(:, baseMask), 0, 2, 'omitnan');
v1 = X(:, idx1s);
active = isfinite(v1) & isfinite(baseMu) & isfinite(baseSd) & (v1 > (baseMu + kSigma .* baseSd));
end

function [nLearned, prob] = iConditionalProb(learnedActive, transferActive)
use = learnedActive;
nLearned = nnz(use);
if nLearned < 1
	prob = NaN;
else
	prob = mean(double(transferActive(use)), 'omitnan');
end
end

function badMice = iFindMiceWithAudioWaterInPhase(DS, phaseName)
T = DS.TableQuery(["Mouse", "Stimulus", "Phase"], Phase=phaseName);
if isempty(T)
	badMice = strings(0, 1);
	return;
end
T.Mouse = string(T.Mouse);
T.Stimulus = string(T.Stimulus);
badMice = unique(T.Mouse(T.Stimulus == "AudioWater"));
end

function dateTime = iNormalizeDateTime(dateTime)
dateTime = datetime(dateTime);
if isdatetime(dateTime) && ~isempty(dateTime.TimeZone)
	dateTime.TimeZone = '';
end
end

function [idx, ok] = iFindTimeIndex(xsSec, targetSec, tolSec)
[distance, idx] = min(abs(xsSec(:) - targetSec));
ok = isfinite(distance) && (distance <= tolSec);
end

function txt = iPLabel(pValue)
if ~isfinite(pValue)
	txt = 'p = NaN';
elseif pValue < 0.001
	txt = 'p < 0.001';
elseif pValue < 0.01
	txt = sprintf('p = %.3f', pValue);
else
	txt = sprintf('p = %.2f', pValue);
end
end

function h = iText(varargin)
h = builtin('text', varargin{:});
end
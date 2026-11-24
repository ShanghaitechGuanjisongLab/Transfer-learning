% English Fig3C: 散度 ↔ 首 block 命中率；Fig3D: 复用（reactivation）↔ 散度
%
% 数据口径严格沿用中文图 Fig44GH_FirstSessionHitRateDivergence_Reactivation.m：
%   面板 G：Naive（LAB + LAI 剔除混入声水的鼠）首个纯光水会话 + Transfer（ALB）首个 Transfer 光水会话，
%           每鼠一个点（HitRate, Divergence@cue+1 s），Naive+Transfer 合并做 Spearman。
%   面板 H：Transfer 鼠的 Reactivation（Learned-AW 活跃细胞在 Transfer 首会话重新活跃的比例）vs 同一会话的散度。
% 配色：Naive = ColorNaive #F38BA8，12 h Transfer = Color12h #FAB387

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
dataG.Group = categorical(string(dataG.Group), ["Naive", "Transfer"]);

reactivationTable = iBuildTransferReactivationTable(ALB);
if isempty(reactivationTable)
	error('Fig44GH:EmptyReuse', 'No valid mice for reactivation summary.');
end
divergenceH = iBuildTransferDivergenceTable(ALB, string(reactivationTable.Mouse), reactivationTable.DateTimeTransfer, idx0, idx1s);
dataH = outerjoin(reactivationTable(:, {'Mouse','DateTimeTransfer','Reactivation'}), divergenceH, 'Keys', 'Mouse', 'MergeKeys', true, 'Type', 'left');
%% 

groupColors = [TransferLearning.ColorNaive; TransferLearning.Color12h] / 255;
colorNaive = groupColors(1, :);
colorTransfer = groupColors(2, :);

% 第三格的数据：Transfer 鼠的 Reactivation 与同一会话的首 block 命中率
Gt = dataG(string(dataG.Group) == "Transfer", :);
dataI = innerjoin(dataH(:, {'Mouse','Reactivation','Divergence'}), Gt(:, {'Mouse','HitRate'}), 'Keys', 'Mouse');

%% 三张单图分别导出（便于分放到不同 fig）
cA = ones(height(dataH), 1) * 2;   % 全部用 Transfer 色
cB = double(string(dataG.Group) == "Transfer") + 1;
cC = ones(height(dataI), 1) * 2;

spec = {
%   x                    y                     colIdx   x标签             y标签           输出文件名                                    分组标签 角落    顶部留白  p格式
	dataH.Reactivation, dataH.Divergence, cA, 'Reactivation', 'Divergence',  'English_Fig3_ReactivationVsDivergence.svg',  false,  '',     0,       '%.1e';
	dataG.Divergence,   dataG.HitRate,    cB, 'Divergence',   'First block', 'English_Fig3_DivergenceVsFirstBlock.svg',    true,   'east', 0.14,    '%.1e';
	dataI.Reactivation, dataI.HitRate,    cC, 'Reactivation', 'First block', 'English_Fig1_ReactivationVsFirstBlock.svg',  false,  '',     0,       '%.3f'};

nP = size(spec, 1);
S = cell(nP, 1);
fprintf('\n=== Fig3 散点三联（已拆为三张单图）===\n');
for k = 1:nP
	f = iNewFig(3.2, 3.6);                       %最终 32 × 36 mm
	ax = axes(f, 'Position', [0.255 0.175 0.705 0.760]);
	S{k} = iScatterCorr(ax, spec{k, 1}, spec{k, 2}, spec{k, 3}, groupColors, ...
		spec{k, 4}, spec{k, 5}, '', spec{k, 8}, spec{k, 9}, spec{k, 10});
	if spec{k, 7}
		text(ax, 0.03, 0.985, 'Naive', 'Units', 'normalized', 'HorizontalAlignment', 'left', ...
			'VerticalAlignment', 'top', 'FontSize', 5.5, 'Color', groupColors(1, :), 'FontWeight', 'bold');
		text(ax, 0.99, 0.985, '12 h', 'Units', 'normalized', 'HorizontalAlignment', 'right', ...
			'VerticalAlignment', 'top', 'FontSize', 5.5, 'Color', groupColors(2, :), 'FontWeight', 'bold');
	end
	pth = TransferLearning.ExportStandardFigure(f, 1, spec{k, 6});
	fprintf('Wrote: %s\n', pth);
	if ~exist('KeepOpen', 'var') || ~KeepOpen
		close(f);
	end
end

labels = {'Reactivation <-> Divergence ', 'Divergence <-> First block  ', 'Reactivation <-> First block'};
for k = 1:nP
	if k == 2
		fprintf('%s: rho=%.3f  p=%.4g  n=%d (Naive %d + 12h %d)\n', labels{k}, ...
			S{k}.Rho, S{k}.P, S{k}.N, S{k}.N1, S{k}.N2);
	else
		fprintf('%s: rho=%.3f  p=%.4g  n=%d\n', labels{k}, S{k}.Rho, S{k}.P, S{k}.N);
	end
end

%% ---------------- 通用：新建固定画布 ----------------
function f = iNewFig(w, h)
f = figure('Color', 'w');
f.Units = 'centimeters';
f.Position(3:4) = [w h];
f.PaperUnits = 'centimeters';
f.PaperSize = [w h];
f.PaperPosition = [0 0 w h];
f.PaperPositionMode = 'manual';
end

%% ---------------- 通用：散点 + 拟合线 + rho/p ----------------
function stats = iScatterCorr(ax, x, y, colIdx, cols, xlab, ylab, letter, cornerPref, headroom, pFmt)
if nargin < 9, cornerPref = ''; end
if nargin < 10, headroom = 0; end
if nargin < 11 || isempty(pFmt), pFmt = '%.1e'; end
x = double(x(:)); y = double(y(:)); colIdx = colIdx(:);
use = isfinite(x) & isfinite(y);
x = x(use); y = y(use); c = colIdx(use);
hold(ax, 'on');
for k = unique(c).'
	scatter(ax, x(c == k), y(c == k), 8, cols(k, :), 'o', 'filled');
end
if numel(x) >= 3 && std(x) > 0
	p = polyfit(x, y, 1);
	xx = linspace(min(x), max(x), 40).';
	plot(ax, xx, polyval(p, xx), '-', 'Color', [0.25 0.25 0.25], ...
		'LineWidth', 0.8, 'Tag', 'TransferLearningSupplementalLine');
end
if std(x) > 0 && std(y) > 0
	[rho, pv] = corr(x, y, 'Type', 'Spearman');
else
	rho = NaN; pv = NaN;
end
% 顶部留白（给分组标签/统计行腾出干净区域）
if headroom > 0
	yl = ax.YLim;
	ax.YLim = [yl(1), yl(2) + headroom * diff(yl)];
end
% 自动挑最空的角放统计标注，避免压到点/拟合线
px = median(x); py = median(y);
q = [nnz(x < px & y > py), nnz(x > px & y > py); ...
	 nnz(x < px & y < py), nnz(x > px & y < py)];
[~, qi] = min(q(:));
if strcmpi(cornerPref, 'above')
	text(ax, 0.02, 1.05, ['\rho = ' sprintf('%.2f', rho) ', p = ' sprintf(pFmt, pv)], ...
		'Units', 'normalized', 'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom', ...
		'FontSize', 5.5, 'Color', [0.2 0.2 0.2]);
else
	corner = {{0.05, 0.96, 'left', 'top'}, {0.95, 0.96, 'right', 'top'}, ...
		{0.05, 0.05, 'left', 'bottom'}, {0.95, 0.05, 'right', 'bottom'}, {0.97, 0.63, 'right', 'middle'}};
	names = {'northwest','northeast','southwest','southeast','east'};
	if ~isempty(cornerPref)
		qi = find(strcmp(names, cornerPref), 1);
	end
	cc = corner{qi};
	text(ax, cc{1}, cc{2}, ['\rho = ' sprintf('%.2f', rho) newline 'p = ' sprintf(pFmt, pv)], ...
		'Units', 'normalized', 'HorizontalAlignment', cc{3}, 'VerticalAlignment', cc{4}, ...
		'FontSize', 5.5, 'Color', [0.2 0.2 0.2]);
end
xlabel(ax, xlab, 'FontSize', 6);
if ~isempty(ylab)
	ylabel(ax, ylab, 'FontSize', 6);
end
if ~isempty(letter)
	text(ax, -0.26, 1.04, letter, 'Units', 'normalized', 'FontSize', 7, 'FontWeight', 'bold');
end
ax.FontSize = 6;
ax.LineWidth = 0.5;
box(ax, 'off');
grid(ax, 'off');
ax.XTickLabelRotation = 0;

stats = table(rho, pv, numel(x), nnz(c == 1), nnz(c == 2), ...
	'VariableNames', {'Rho','P','N','N1','N2'});
end

function stats = iPlotFirstSessionHitRateVsDivergence(ax, Data, colorNaive, colorTransfer)
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
maskTransfer = use & (string(Data.Group) == "Transfer");

hold(ax, 'on');
box(ax, 'off');
ax.FontSize = 12;
ax.LineWidth = 2;
hNaive = scatter(ax, Data.Divergence(maskNaive), Data.HitRate(maskNaive), 22, colorNaive, 'o');
hTransfer = scatter(ax, Data.Divergence(maskTransfer), Data.HitRate(maskTransfer), 22, colorTransfer, 'o');
fitP = polyfit(xAll, yAll, 1);
xFit = [min(xAll), max(xAll)];
yFit = polyval(fitP, xFit);
plot(ax, xFit, yFit, '-', 'Color', 'k', 'Tag', 'TransferLearningSupplementalLine');
    ylabel(ax, ' first block hit rate');
    legendHandle = legend(ax, [hNaive, hTransfer], {'Naive', 'Transfer'}, 'Location', 'northoutside', 'Orientation', 'horizontal');
    legendHandle.FontSize = 12;
    legendHandle.Box = 'off';
    iSLabel(ax, 0.97, 0.97, rho, pValue);
grid(ax, 'off');

stats = table("G", rho, pValue, nnz(maskNaive), nnz(maskTransfer), ...
	'VariableNames', {'Panel','Rho','PValue','NNaive','NTransfer'});
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
scatter(ax, x(use), y(use), 22, dotColor, 'o');
if nnz(use) >= 2 && std(x(use)) > 0
	fitP = polyfit(x(use), y(use), 1);
	xFit = [min(x(use)), max(x(use))];
	yFit = polyval(fitP, xFit);
plot(ax, xFit, yFit, '-', 'Color', 'k', 'Tag', 'TransferLearningSupplementalLine');
   end
   if std(x(use)) > 0 && std(y(use)) > 0
   	[rho, pValue] = corr(x(use), y(use), 'Type', 'Spearman');
   else
   	rho = NaN;
   	pValue = NaN;
   end
   ylabel(ax, 'Reactivation of  cells');
   iSLabel(ax, 0.97, 0.97, rho, pValue);
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
	rows{iM} = iFirstSessionRow(DS, mouseName, dateTime, sessionTable, "Transfer", idx0, idx1s);
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

function iSLabel(ax, x, y, rho, pValue)
if ~isfinite(pValue)
	pStr = 'p = NaN';
elseif pValue < 0.001
	pStr = 'p < 0.001';
elseif pValue < 0.01
	pStr = sprintf('p = %.3f', pValue);
else
	pStr = sprintf('p = %.2f', pValue);
end
labelStr = sprintf('Sp. ρ = %.2f\n%s', rho, pStr);
text(ax, x, y, labelStr, 'Units', 'normalized', ...
	'HorizontalAlignment', 'right', 'VerticalAlignment', 'top');
end

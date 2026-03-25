% 中文图333D：模仿英文图2G算法、英文图3I样式，比较首会话命中率与散度的相关性

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));

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
	error('Fig333D:TimeIndexMissing', 'Cannot find 0 s or 1 s sample in TransferLearning.Xs.');
end

naiveA = iCollectNaiveFirstSessionData(LAB, "LightAudioBaseline", strings(0, 1), idx0, idx1s);
badNaiveLai = iFindMiceWithAudioWaterInPhase(LAI, "Naive");
naiveB = iCollectNaiveFirstSessionData(LAI, "LAInterspersed", badNaiveLai, idx0, idx1s);
naive = [naiveA; naiveB];

transfer = iCollectTransferFirstSessionData(ALB, idx0, idx1s);

Data = [naive; transfer];
Data.Group = categorical(string(Data.Group), ["Naive", "Transfer"]);

palette3 = TransferLearning.FigurePalette(3);
colorNaive = palette3(1, :);
colorTransfer = palette3(2, :);
colorFit = palette3(3, :);

f = figure('Color', 'w', 'Name', 'Fig333D First-session hit rate vs divergence');
f.Units = 'centimeters';
f.Position(3:4) = [3, 4];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 3, 4];
f.PaperSize = [3, 4];

tl = tiledlayout(f, 1, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
xl = xlabel(tl, 'Divergence');
xl.FontSize = 6;

Stats = table("All", nan, nan, nan, nan, ...
	'VariableNames', {'Panel', 'Rho', 'PValue', 'NNaive', 'NTransfer'});

use = isfinite(Data.Divergence) & isfinite(Data.HitRate);
if nnz(use) < 3
	error('Fig333D:TooFewPoints', 'Too few valid mice for correlation.');
end

xAll = Data.Divergence(use);
yAll = Data.HitRate(use);
if std(xAll) <= 0 || std(yAll) <= 0
	error('Fig333D:ZeroVariance', 'All mice have zero variance for correlation.');
end
[rho, p] = corr(xAll, yAll, 'Type', 'Spearman');

maskNaive = use & (string(Data.Group) == "Naive");
maskTran = use & (string(Data.Group) == "Transfer");

ax = nexttile(tl, 1);
hold(ax, 'on');
box(ax, 'off');
ax.FontSize = 6;
ax.LineWidth = 1;
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end

hN = scatter(ax, Data.Divergence(maskNaive), Data.HitRate(maskNaive), 5, colorNaive, 'o', 'filled', 'LineWidth', 0.2);
hT = scatter(ax, Data.Divergence(maskTran), Data.HitRate(maskTran), 8, colorTransfer, '^', 'filled', 'LineWidth', 0.2);
ylabel(ax, 'First session hit rate', 'FontSize', 6);

fitP = polyfit(xAll, yAll, 1);
xFit = [min(xAll), max(xAll)];
yFit = polyval(fitP, xFit);
plot(ax, xFit, yFit, '-', 'Color', colorFit, 'LineWidth', 1);

text(ax, 0.97, 0.97, iPLabel(p), 'Units', 'normalized', ...
	'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', 'FontSize', 6);

Stats.Rho(1) = rho;
Stats.PValue(1) = p;
Stats.NNaive(1) = nnz(maskNaive);
Stats.NTransfer(1) = nnz(maskTran);

fprintf('\n=== Fig333D All cells ===\n');
fprintf('Naive mice: %d\n', nnz(maskNaive));
fprintf('Transfer mice: %d\n', nnz(maskTran));
fprintf('Spearman rho=%.3f, p=%.4g\n', rho, p);

svgPath = fullfile(outDirUNC, '中文图Fig333D_FirstSessionHitRateVsDivergence.svg');
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig333D_FirstSessionData', Data);
assignin('base', 'Fig333D_Stats', Stats);

function out = iCollectTransferFirstSessionData(DS, idx0, idx1s)
CellMap = iCellMap(DS);
T = DS.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex","Behavior","Stimulus","Phase"], Phase="Transfer");
if isempty(T)
	out = iEmptyOutputTable();
	return;
end
T.Mouse = string(T.Mouse);
T.Stimulus = string(T.Stimulus);
T.Phase = string(T.Phase);
T.DateTime = iNormalizeDateTime(T.DateTime);
T = T(T.Stimulus == "LightWater", :);

mice = unique(T.Mouse);
Rows = cell(numel(mice), 1);
for i = 1:numel(mice)
	m = mice(i);
	Tm = T(T.Mouse == m, :);
	if isempty(Tm)
		Rows{i} = iEmptyOutputTable();
		continue;
	end
	dt = min(Tm.DateTime);
	Ts = sortrows(Tm(Tm.DateTime == dt, :), 'TrialIndex');
	Rows{i} = iSessionLayerRows(DS, CellMap, m, dt, Ts, "Transfer", idx0, idx1s);
	end
out = vertcat(Rows{:});
end

function out = iCollectNaiveFirstSessionData(DS, sourceName, badMice, idx0, idx1s)
CellMap = iCellMap(DS);
T = DS.TableQuery(["Mouse","DateTime","TrialUID","TrialIndex","Behavior","Stimulus","Phase"], Phase="Naive");
if isempty(T)
	out = iEmptyOutputTable();
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
Rows = cell(numel(mice), 1);
for i = 1:numel(mice)
	m = mice(i);
	Tm = T(T.Mouse == m, :);
	if isempty(Tm)
		Rows{i} = iEmptyOutputTable();
		continue;
	end
	sess = sort(unique(Tm.DateTime), 'ascend');
	chosenDt = NaT;
	chosenTbl = table();
	for s = 1:numel(sess)
		Tss = Tm(Tm.DateTime == sess(s), :);
		if any(Tss.Stimulus == "LightWater") && ~any(Tss.Stimulus == "AudioWater")
			chosenDt = sess(s);
			chosenTbl = sortrows(Tss(Tss.Stimulus == "LightWater", :), 'TrialIndex');
			break;
		end
	end
	if ismissing(chosenDt) || isempty(chosenTbl)
		Rows{i} = iEmptyOutputTable();
		continue;
	end
	Rows{i} = iSessionLayerRows(DS, CellMap, m, chosenDt, chosenTbl, "Naive", idx0, idx1s);
	Rows{i}.Source(:) = string(sourceName);
	end
out = vertcat(Rows{:});
end

function out = iSessionLayerRows(DS, CellMap, mouseName, dt, SessTbl, groupName, idx0, idx1s)
out = iEmptyOutputTable();
trialUIDs = unique(uint64(SessTbl.TrialUID), 'stable');
if numel(trialUIDs) < 2
	return;
end

beh = double(SessTbl.Behavior);
beh = beh(isfinite(beh));
if isempty(beh)
	return;
end
hitRate = mean(beh);

nts = DS.QueryNTS(struct('Stimulus', "LightWater", 'Mouse', mouseName, 'DateTime', dt), UniExp.Flags.ZScore, 1:24);
if iscell(nts)
	nts = nts{1};
end
if isempty(nts)
	return;
end

[ctt, cellUIDs] = iBuildCTT(nts, trialUIDs, idx0);
if isempty(ctt) || size(ctt, 2) < 2
	return;
end

[~, loc] = ismember(cellUIDs, CellMap.CellUID);
zLayer = strings(numel(cellUIDs), 1);
	has = loc > 0;
	zLayer(has) = CellMap.ZLayer(loc(has));
	xAt1 = ctt(:, :, idx1s);

	divValue = iAllCellDivergence(xAt1, zLayer);
	out = iOneRow(mouseName, groupName, hitRate, divValue, dt);
end

function row = iOneRow(mouseName, groupName, hitRate, divValue, dt)
row = table(string(mouseName), string(groupName), double(hitRate), double(divValue), iNormalizeDateTime(dt), "", ...
	'VariableNames', {'Mouse','Group','HitRate','Divergence','DateTime','Source'});
end

function div = iAllCellDivergence(xAt1, zLayer)
mask = (zLayer == "MOp2/3") | (zLayer == "MOp5");
if nnz(mask) < 3
	div = NaN;
	return;
end
X = xAt1(mask, :);
totalSignal = sum(mean(X, 2).^2);
totalNoise = sum(var(X, [], 2));
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
for iC = 1:numel(allCells)
		cid = allCells(iC);
		rows = uint64(nts.CellUID) == cid;
		uid = uint64(nts.TrialUID(rows));
		sig = double(nts.TrialSignal(rows, :));
		[tf, loc] = ismember(trialUIDs, uid);
		if ~all(tf)
			continue;
		end
		ordered = sig(loc, :);
		if any(~isfinite(ordered), 'all')
			continue;
		end
		nKeep = nKeep + 1;
		traceCell{nKeep} = ordered;
		keepUID(nKeep) = cid;
	end
	if nKeep < 1
		return;
	end
	traceCell = traceCell(1:nKeep);
	keepUID = keepUID(1:nKeep);
	nTrial = size(traceCell{1}, 1);
	nTime = size(traceCell{1}, 2);
	ctt = nan(nKeep, nTrial, nTime);
	for iC = 1:nKeep
		ctt(iC, :, :) = traceCell{iC};
	end
	ctt = ctt - ctt(:, :, idx0);
	cellUIDs = keepUID;
end

function CellMap = iCellMap(DS)
CellMap = DS.Cells(:, {'CellUID', 'Mouse', 'ZLayer'});
CellMap.CellUID = uint64(CellMap.CellUID);
CellMap.Mouse = string(CellMap.Mouse);
CellMap.ZLayer = string(CellMap.ZLayer);
end

function T = iEmptyOutputTable()
T = table(string.empty(0, 1), string.empty(0, 1), nan(0, 1), nan(0, 1), NaT(0, 1), string.empty(0, 1), ...
	'VariableNames', {'Mouse','Group','HitRate','Divergence','DateTime','Source'});
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

function dt = iNormalizeDateTime(dt)
dt = datetime(dt);
if ~isempty(dt.TimeZone)
	dt.TimeZone = '';
end
end

function [idx, ok] = iFindTimeIndex(xsSec, targetSec, tolSec)
[d, idx] = min(abs(xsSec(:) - targetSec));
ok = isfinite(d) && (d <= tolSec);
end

function txt = iPLabel(p)
if p < 0.001
	txt = sprintf('p=%.1e', p);
elseif p < 0.01
	txt = sprintf('p=%.4f', p);
else
	txt = sprintf('p=%.2f', p);
end
end
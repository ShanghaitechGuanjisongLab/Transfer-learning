% 中文图333E：迁移光水散度与重激活率的相关性（合并层单 tile）

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202602";

R = TransferLearning.Fig37.iBuildProb_TransferGivenLearnedAudio_1s_PerMouseLayer();
if isempty(R)
	error('Fig333E:EmptyReuse', 'No valid mice for reactivation summary.');
end

ALB = TransferLearning.AudioLightBaseline();
CellMap = iCellMap(ALB);

xs = TransferLearning.Xs;
if isduration(xs)
	xsSec = seconds(xs);
else
	xsSec = double(xs);
end
[idx0, ok0] = iFindTimeIndex(xsSec, 0, 0.25);
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok0 || ~ok1s
	error('Fig333E:TimeIndexMissing', 'Cannot find 0 s or 1 s sample in TransferLearning.Xs.');
end

Div = iBuildTransferDivergenceTable(ALB, CellMap, string(R.Mouse), R.DateTimeTransfer, idx0, idx1s);
M = outerjoin(R(:, {'Mouse','Prob23','Prob5'}), Div, 'Keys', 'Mouse', 'MergeKeys', true, 'Type', 'left');
M.Reactivation = mean([double(M.Prob23), double(M.Prob5)], 2, 'omitnan');
M.Divergence = mean([double(M.Div23), double(M.Div5)], 2, 'omitnan');

palette3 = TransferLearning.FigurePalette(3);
dotColor = palette3(2, :);
fitColor = palette3(3, :);

f = figure('Color', 'w', 'Name', 'Fig333E Transfer divergence vs reactivation');
f.Units = 'centimeters';
f.Position(3:4) = [3, 4];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 3, 4];
f.PaperSize = [3, 4];

tl = tiledlayout(f, 1, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
xlabel(tl, 'Reactivation', 'FontSize', 6);
ylabel(tl, 'Divergence', 'FontSize', 6);

Stats = table("All", nan, nan, nan, 'VariableNames', {'Panel','Rho','PValue','N'});

ax = nexttile(tl, 1);
hold(ax, 'on');
box(ax, 'off');
ax.FontSize = 6;
ax.LineWidth = 1;
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end

x = double(M.Reactivation);
y = double(M.Divergence);
use = isfinite(x) & isfinite(y);
if nnz(use) < 3
	error('Fig333E:TooFewPoints', 'Too few valid mice after layer merge.');
end

scatter(ax, x(use), y(use), 5, dotColor, 'o', 'filled', 'LineWidth', 0.2);
if nnz(use) >= 2 && std(x(use)) > 0
	pFit = polyfit(x(use), y(use), 1);
	xFit = [min(x(use)), max(x(use))];
	yFit = polyval(pFit, xFit);
	plot(ax, xFit, yFit, '-', 'Color', fitColor, 'LineWidth', 1);
end
if std(x(use)) > 0 && std(y(use)) > 0
	[rho, p] = corr(x(use), y(use), 'Type', 'Spearman');
else
	rho = NaN;
	p = NaN;
end
text(ax, 0.97, 0.97, iPLabel(p), 'Units', 'normalized', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', 'FontSize', 6);

Stats.Rho(1) = rho;
Stats.PValue(1) = p;
Stats.N(1) = nnz(use);

fprintf('\n=== Fig333E All ===\n');
fprintf('n=%d, rho=%.3f, p=%.4g\n', nnz(use), rho, p);

svgPath = fullfile(outDirUNC, '中文图Fig333E_TransferDivergenceVsReactivation_ByLayer.svg');
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig333E_MergedData', M);
assignin('base', 'Fig333E_Stats', Stats);

function Div = iBuildTransferDivergenceTable(DS, CellMap, mice, dateTimes, idx0, idx1s)
Div = table(strings(0, 1), nan(0, 1), nan(0, 1), 'VariableNames', {'Mouse','Div23','Div5'});
for i = 1:numel(mice)
	m = string(mice(i));
	dt = iNormalizeDateTime(dateTimes(i));
	T = DS.TableQuery(["TrialUID","TrialIndex","Mouse","DateTime","Stimulus","Phase"], Mouse=m, DateTime=dt, Stimulus="LightWater", Phase="Transfer");
	if isempty(T)
		continue;
	end
	T = sortrows(T, 'TrialIndex');
	trialUIDs = unique(uint64(T.TrialUID), 'stable');
	if numel(trialUIDs) < 2
		continue;
	end
	nts = DS.QueryNTS(struct('Stimulus', "LightWater", 'Mouse', m, 'DateTime', dt), UniExp.Flags.ZScore, 1:24);
	if iscell(nts)
		nts = nts{1};
	end
	if isempty(nts)
		continue;
	end
	[ctt, cellUIDs] = iBuildCTT(nts, trialUIDs, idx0);
	if isempty(ctt) || size(ctt, 2) < 2
		continue;
	end
	[~, loc] = ismember(cellUIDs, CellMap.CellUID);
	z = strings(numel(cellUIDs), 1);
	has = loc > 0;
	z(has) = CellMap.ZLayer(loc(has));
	xAt1 = ctt(:, :, idx1s);
	div23 = iLayerDivergence(xAt1, z == "MOp2/3");
	div5 = iLayerDivergence(xAt1, z == "MOp5");
	Div = [Div; table(m, div23, div5, 'VariableNames', Div.Properties.VariableNames)]; %#ok<AGROW>
	end
end

function div = iLayerDivergence(xAt1, mask)
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
CellMap = DS.Cells(:, {'CellUID', 'ZLayer'});
CellMap.CellUID = uint64(CellMap.CellUID);
CellMap.ZLayer = string(CellMap.ZLayer);
end

function [idx, ok] = iFindTimeIndex(xsSec, targetSec, tolSec)
[d, idx] = min(abs(xsSec(:) - targetSec));
ok = isfinite(d) && (d <= tolSec);
end

function dt = iNormalizeDateTime(dt)
dt = datetime(dt);
if ~isempty(dt.TimeZone)
	dt.TimeZone = '';
end
end

function txt = iPLabel(p)
if ~isfinite(p)
	txt = 'p=NaN';
elseif p < 0.001
	txt = sprintf('p=%.1e', p);
elseif p < 0.01
	txt = sprintf('p=%.4f', p);
else
	txt = sprintf('p=%.2f', p);
end
end
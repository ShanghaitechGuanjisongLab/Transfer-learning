% 中文图342G：响应异质性 vs 路程/直线距离（全细胞，Naive/Transfer 分色）

if ~exist('TransferLearning', 'class') || ~exist('UniExp.DataSet', 'class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
svgName = "中文图Fig342G_ResponseHeterogeneityVsPathOverDirect_AllCells_v2.svg";

StateData = TransferLearning.Fig341.BuildStateSpaceSummary(false, UniExp.Flags.No_special_operation);
States = StateData.MouseStates;
Metrics = table(strings(0,1), strings(0,1), strings(0,1), nan(0,1), ...
	'VariableNames', {'Mouse', 'Group', 'Source', 'PathOverDirect'});
for iState = 1:numel(States)
	[pathLen, directLen, ratioVal] = iMetricsFromPoints(States(iState).Points); %#ok<ASGLU>
	Metrics = [Metrics; table(string(States(iState).Mouse), string(States(iState).Group), string(States(iState).Source), double(ratioVal), ...
		'VariableNames', Metrics.Properties.VariableNames)]; %#ok<AGROW>
end

xs = TransferLearning.Xs;
if isduration(xs)
	xsSec = seconds(xs);
else
	xsSec = double(xs);
end
[idx1s, ok1s] = iFindTimeIndex(xsSec, 1, 0.25);
if ~ok1s
	error('Fig342G:Bad1sIndex', 'Cannot find sample close to 1 s in TransferLearning.Xs.');
end

FirstSess = table(strings(0,1), strings(0,1), strings(0,1), NaT(0,1), ...
	'VariableNames', {'Mouse', 'Group', 'Source', 'DateTime'});
for iState = 1:numel(States)
	Sm = States(iState).SessionTable;
	if isempty(Sm) || height(Sm) < 1
		continue;
	end
	FirstSess = [FirstSess; table(string(States(iState).Mouse), string(States(iState).Group), string(States(iState).Source), Sm.DateTime(1), ...
		'VariableNames', FirstSess.Properties.VariableNames)]; %#ok<AGROW>
end

dsBySrc = struct();
dsBySrc.LAB = TransferLearning.LightAudioBaseline();
dsBySrc.LAI = TransferLearning.LAInterspersed();
dsBySrc.ALB = TransferLearning.AudioLightBaseline();
dsBySrc.ALI = TransferLearning.ALInterspersed();

Rows = repmat(iEmptyHetRow(), 0, 1);
srcList = ["LAB", "LAI", "ALB", "ALI"];
for iSrc = 1:numel(srcList)
	src = srcList(iSrc);
	DS = dsBySrc.(src);
	CellMap = iCellMap(DS);
	Rsrc = FirstSess(FirstSess.Source == src, :);
	for iRow = 1:height(Rsrc)
		mouseId = string(Rsrc.Mouse(iRow));
		dt = Rsrc.DateTime(iRow);
		G = DS.QueryNTATS(struct('Mouse', mouseId, 'DateTime', dt, 'Stimulus', 'LightWater'), UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
		if isempty(G) || ~all(ismember(["NTATS", "CellUID"], string(G.Properties.VariableNames)))
			continue;
		end
		M = iNtatsData(G.NTATS);
		if isempty(M) || idx1s > size(M, 2)
			continue;
		end
		z = iLookupZLayer(CellMap, uint64(G.CellUID));
		mask = (z == "MOp2/3") | (z == "MOp5");
		if nnz(mask) < 2
			continue;
		end
		v = double(M(mask, idx1s));
		v = v(isfinite(v) & v >= -1 & v <= 1);
		if numel(v) < 2
			continue;
		end
		row = iEmptyHetRow();
		row.Mouse = mouseId;
		row.Group = string(Rsrc.Group(iRow));
		row.Source = src;
		row.DateTime = dt;
		row.ResponseHeterogeneity = std(v, 0, 1, 'omitnan');
		row.NCells = numel(v);
		Rows(end + 1) = row; %#ok<AGROW>
	end
end

if isempty(Rows)
	error('Fig342G:NoHeterogeneityRows', 'No mouse-level response heterogeneity data were built.');
end

Het = struct2table(Rows);
Data = innerjoin(Het, Metrics, 'Keys', {'Mouse', 'Group', 'Source'});
if isempty(Data)
	error('Fig342G:NoMatchedRows', 'No matched rows between heterogeneity and PathOverDirect.');
end

palette2 = TransferLearning.FigurePalette(2);
colorNaive = palette2(1, :);
colorTransfer = palette2(2, :);

f = figure('Color', 'w', 'Name', '中文图342G Response heterogeneity vs Path/direct');
f.Units = 'centimeters';
f.Position(3:4) = [4.5 4.0];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 4.5, 4.0];
f.PaperSize = [4.5, 4.0];

tl = tiledlayout(f, 1, 1, 'TileSpacing', 'tight', 'Padding', 'tight');
Stats = table(nan(1,1), nan(1,1), nan(1,1), nan(1,1), nan(1,1), nan(1,1), nan(1,1), nan(1,1), ...
	'VariableNames', {'Rho', 'PValue', 'NAll', 'NNaive', 'NTransfer', 'NCellsAll', 'NCellsNaive', 'NCellsTransfer'});

use = isfinite(Data.PathOverDirect) & isfinite(Data.ResponseHeterogeneity);
if nnz(use) < 3
	error('Fig342G:TooFewPoints', 'Too few valid mice for all-cell correlation.');
end
R = Data(use, :);
x = double(R.PathOverDirect);
y = double(R.ResponseHeterogeneity);
maskNaive = string(R.Group) == "Naive";
maskTran = string(R.Group) == "Transfer";
[rho, p] = corr(x, y, 'Type', 'Spearman');
nCellsNaive = sum(R.NCells(maskNaive), 'omitnan');
nCellsTran = sum(R.NCells(maskTran), 'omitnan');
nCellsAll = sum(R.NCells, 'omitnan');

ax = nexttile(tl, 1);
hold(ax, 'on');
box(ax, 'off');
grid(ax, 'off');
ax.FontSize = 6;
ax.LineWidth = 1;
ax.TickDir = 'out';
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end

scatter(ax, x(maskNaive), y(maskNaive), 14, colorNaive, 'o', 'filled', 'LineWidth', 0.2);
scatter(ax, x(maskTran), y(maskTran), 18, colorTransfer, '^', 'filled', 'LineWidth', 0.2);
if numel(x) >= 2 && std(x, 0, 'omitnan') > 0
	fitP = polyfit(x, y, 1);
	xFit = [min(x), max(x)];
	yFit = polyval(fitP, xFit);
	plot(ax, xFit, yFit, '-', 'Color', [0 0 0], 'LineWidth', 1);
end
text(ax, 0.95, 0.95, iPLabel(p), 'Units', 'normalized', ...
	'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', 'FontSize', 6);
text(ax, 0.95, 0.87, 'Naive', 'Units', 'normalized', 'Color', colorNaive, ...
	'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', 'FontSize', 6);
text(ax, 0.95, 0.79, 'Continual', 'Units', 'normalized', 'Color', colorTransfer, ...
	'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', 'FontSize', 6);
title(ax, 'All cells', 'FontSize', 6, 'FontWeight', 'normal');
hold(ax, 'off');

ylabel(tl, 'Response heterogeneity', 'FontSize', 6);
xlabel(tl, 'Path / direct', 'FontSize', 6);

Stats.Rho(1) = rho;
Stats.PValue(1) = p;
Stats.NAll(1) = height(R);
Stats.NNaive(1) = nnz(maskNaive);
Stats.NTransfer(1) = nnz(maskTran);
Stats.NCellsAll(1) = nCellsAll;
Stats.NCellsNaive(1) = nCellsNaive;
Stats.NCellsTransfer(1) = nCellsTran;

fprintf('\n=== Fig342G All cells ===\n');
fprintf('Naive mice: %d, cells: %d\n', nnz(maskNaive), round(nCellsNaive));
fprintf('Continual mice: %d, cells: %d\n', nnz(maskTran), round(nCellsTran));
fprintf('Total cells: %d\n', round(nCellsAll));
fprintf('Spearman ρ=%.3f, p=%.4g\n', rho, p);

if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = svgName;
svgPath = TransferLearning.ExportStandardFigure(f, 1, svgPath);
fprintf('Wrote: %s\n', svgPath);

assignin('base', 'Fig342G_MatchedData', R);
assignin('base', 'Fig342G_Stats', Stats);

function row = iEmptyHetRow()
row = struct(...
	'Mouse', "", ...
	'Group', "", ...
	'Source', "", ...
	'DateTime', NaT, ...
	'ResponseHeterogeneity', NaN, ...
	'NCells', NaN);
end

function CellMap = iCellMap(DS)
if ~isprop(DS, 'Cells')
	error('Fig342G:MissingCells', 'DataSet %s has no Cells table.', class(DS));
end
CellMap = DS.Cells(:, {'CellUID', 'ZLayer'});
CellMap.CellUID = uint64(CellMap.CellUID);
CellMap.ZLayer = string(CellMap.ZLayer);
end

function z = iLookupZLayer(CellMap, cellUID)
cellUID = uint64(cellUID);
[has, loc] = ismember(cellUID, CellMap.CellUID);
z = strings(numel(cellUID), 1);
z(has) = CellMap.ZLayer(loc(has));
end

function M = iNtatsData(N)
try
	if isa(N, 'MATLAB.DataTypes.NDTable')
		M = double(N{:, :});
	elseif isnumeric(N)
		M = double(N);
	else
		M = double(N{:, :});
	end
catch
	try
		M = cell2mat(N);
	catch
		M = [];
	end
end
end

function [idx, ok] = iFindTimeIndex(xsSec, targetSec, tolSec)
[dtMin, idx] = min(abs(xsSec - double(targetSec)));
ok = ~isempty(idx) && isfinite(dtMin) && dtMin <= double(tolSec);
end

function s = iPLabel(p)
if ~isfinite(p)
	s = 'p = NaN';
elseif p < 0.001
	s = 'p < 0.001';
	elseif p < 0.01
	s = sprintf('p = %.3f', p);
else
	s = sprintf('p = %.2f', p);
end
end

function [pathLen, directLen, ratioVal] = iMetricsFromPoints(points)
dp = diff(points, 1, 1);
stepLens = sqrt(sum(dp.^2, 2));
pathLen = sum(stepLens, 'omitnan');
directLen = sqrt(sum((points(end, :) - points(1, :)).^2, 2));
if isfinite(pathLen) && isfinite(directLen) && directLen > 0
	ratioVal = pathLen / directLen;
else
	ratioVal = NaN;
end
end


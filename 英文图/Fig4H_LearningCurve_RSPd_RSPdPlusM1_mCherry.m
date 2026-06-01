rspPath     = "\\Data-Server-2\个人数据\张天夫\202505\RSP-Gi 化学遗传学抑制 声转光.v2.mat";
mopCtrlPath = "\\Data-Server-2\个人数据\张天夫\202409\Mop-Gi运动皮层化学遗传学抑制声光（无功能对照）.mat";
rspMoPath   = "\\data-server-2\个人数据\张天夫\202507\MOP+RSP化学遗传学抑制.v1.mat";

RSPd = UniExp.DataSet(rspPath);
RSPdTable = RSPd.TableQuery(["Mouse","DateTime","Performance"], Design="LightWater");
RSPdTable.Group(:) = "RSPd";

MOpControl = UniExp.DataSet(mopCtrlPath);
MOpControlTable = MOpControl.TableQuery(["Mouse","DateTime","Performance"], Design="LightWater");
ControlTable = MOpControlTable;
ControlTable.Group(:) = "mCherry";

RSPdMo = UniExp.DataSet(rspMoPath);
RSPdMoTable = RSPdMo.TableQuery(["Mouse","DateTime","Performance","Phase"], Design="LightWater");
RSPdMoTable.Group(:) = "RSPd+MOp";

Summary = UniExp.LearningSummarize(MATLAB.DataTypes.MergeTables(RSPdTable, ControlTable, RSPdMoTable));
Summary.Properties.RowNames = replace(Summary.Properties.RowNames, 'MOp', 'M1');
groupOrder = ["RSPd", "RSPd+M1", "mCherry"];
try
	Summary = Summary(groupOrder, :);
catch
end
Colors = [TransferLearning.ColorA; TransferLearning.ColorB; TransferLearning.ContinualColor];

f = figure('Color','w', 'Name','English Fig4H Learning Curve');
f.Units = 'centimeters';
f.Position(3:4) = [9, 8];

ax = axes(f);
hold(ax,'on');
ax.FontSize = 12;
ax.LineWidth = 2;
if isprop(ax.XAxis, 'LineWidth')
	ax.XAxis.LineWidth = 2;
	ax.YAxis.LineWidth = 2;
end
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end

meanCells = cellfun(@(C) C(1:min(10, numel(C))), Summary.MeanCurve, UniformOutput=false);
semCells  = cellfun(@(C) C(1:min(10, numel(C))), Summary.SemCurve,  UniformOutput=false);
Patches = MATLAB.Graphics.MultiShadowedLines(meanCells, semCells, 1/(height(Summary)+1), EdgeColors=Colors);
for iPatch = 1:numel(Patches)
	if isprop(Patches(iPatch), 'LineWidth')
		Patches(iPatch).LineWidth = 2;
	end
end

nEach = cellfun(@height, Summary.LearnedSessions);
labels = Summary.Properties.RowNames;

lg = legend(Patches, labels,Location='southeast');
lg.FontSize = 12;
lg.Box = 'off';
lg.Title.String = '💡💧';
lg.Title.FontSize = 12;

box(ax,'off');
grid(ax,'off');
ylabel(ax, 'Hit rate', 'FontSize', 12);
xlabel(ax, 'Block', 'FontSize', 12);
for ln = findobj(ax, 'Type', 'Line')'
	ln.LineWidth = 2;
end

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
if ~isfolder(outDirUNC), mkdir(outDirUNC); end
svgName = 'English_Fig4H_LearningCurve_RSPd_RSPdPlusM1_mCherry.svg';
svgPath = svgName;
svgPath = TransferLearning.ExportStandardFigure(f, 2, svgPath);
fprintf('Wrote: %s\n', svgPath);

Tn = table(Summary.Properties.RowNames, nEach(:), 'VariableNames', {'Group','N'});
disp(Tn);

rspFirst = iFirstSessionPerformance(RSPdTable);
mcherryFirst = iFirstSessionPerformance(ControlTable);

rn = string(Summary.Properties.RowNames);
rspColorIdx = find(rn == "RSPd", 1);
mcherryColorIdx = find(rn == "mCherry", 1);
if isempty(rspColorIdx), rspColorIdx = 1; end
if isempty(mcherryColorIdx), mcherryColorIdx = min(3, height(Summary)); end

f2 = figure('Color','none', 'Name','English Fig4H First-session performance');
f2.Units = 'centimeters';
f2.Position(3:4) = [4, 4];
f2.PaperUnits = 'centimeters';
f2.PaperSize = [4, 4];
f2.PaperPositionMode = 'auto';
tiledlayout(1,1,'TileSpacing','tight','Padding','tight');
nexttile;

DataCell = {rspFirst, mcherryFirst};
CompareGroup = table([1 2], 'VariableNames', {'GroupPair'});
[~, Optional2, Bars2, ErrorBars2] = UniExp.BarScatterCompare(DataCell, UniExp.Flags.empty, CompareGroup, UniExp.Flags.IndividualErrorbars, 'AsteriskThreshold', 0.05);

ax2 = gca;
ax2.FontSize = 12;
ax2.LineWidth = 2;
ax2.Color = 'none';
ax2.XAxis.Visible = 'off';
if isprop(ax2.XAxis, 'LineWidth')
	ax2.XAxis.LineWidth = 2;
	ax2.YAxis.LineWidth = 2;
end
ax2.XTick = [];
legend(ax2, 'off');

if isfield(Optional2, 'MultiCompare') && ismember('PText', Optional2.MultiCompare.Properties.VariableNames)
	for pt = Optional2.MultiCompare.PText(:)'
		pt.FontSize = 12;
	end
end
if isfield(Optional2, 'MultiCompare') && ismember('PLine', Optional2.MultiCompare.Properties.VariableNames)
	for pl = Optional2.MultiCompare.PLine(:)'
		pl.LineWidth = 2;
	end
end

barColorIdx = [rspColorIdx, mcherryColorIdx];
if isscalar(Bars2)
	Bars2.FaceColor = 'flat';
	Bars2.CData = Colors(barColorIdx, :);
	Bars2.BarWidth = 0.5;
	Bars2.LineWidth = 2;
	Bars2.EdgeColor = 'none';
	Bars2.FaceAlpha = 1/3;
else
	for ib = 1:min(2, numel(Bars2))
		Bars2(ib).FaceColor = Colors(barColorIdx(ib), :);
		Bars2(ib).LineWidth = 2;
		Bars2(ib).EdgeColor = 'none';
		Bars2(ib).FaceAlpha = 1/3;
	end
end
for eb = ErrorBars2.Object(:)'
	eb.LineWidth = 2;
end
ax2.XLim = [0.5, 2.5];
ylabel(ax2, 'Hit rate', 'FontSize', 12);
title(ax2, 'First block', 'FontSize', 12, 'FontWeight', 'normal');
box(ax2, 'off');
for ln = findobj(ax2, 'Type', 'Line')'
	ln.LineWidth = 2;
end
if isprop(ax2, 'Toolbar') && ~isempty(ax2.Toolbar)
	ax2.Toolbar.Visible = 'off';
end

svgPath2 = 'English_Fig4H_FirstSessionPerformance_RSPd_vs_mCherry.svg';
TransferLearning.Style.ApplyStandardFigureStyle(f2, 2);
iApplyBarColors(Bars2, ErrorBars2, Colors(barColorIdx, :));
MATLAB.Graphics.PLineRetune(Optional2.MultiCompare.PLine,Optional2.MultiCompare.PText);
svgPath2 = fullfile(outDirUNC, svgPath2);
print(f2, svgPath2, '-dsvg');
fprintf('Wrote: %s\n', svgPath2);

function perf = iFirstSessionPerformance(T)
T = sortrows(T, ["Mouse","DateTime"]);
mice = unique(T.Mouse, 'stable');
perf = nan(numel(mice), 1);
for i = 1:numel(mice)
	rows = T(T.Mouse == mice(i), :);
	firstDT = rows.DateTime(1);
	perf(i) = mean(double(rows.Performance(rows.DateTime == firstDT)), 'omitnan');
end
end

function iApplyBarColors(Bars, ErrorBars, colors)
if isscalar(Bars)
	Bars.FaceColor = 'flat';
	Bars.CData = colors;
	Bars.BarWidth = 0.5;
	Bars.EdgeColor = 'none';
	Bars.FaceAlpha = 1/3;
else
	for iB = 1:min(numel(Bars), size(colors, 1))
		Bars(iB).FaceColor = colors(iB, :);
		Bars(iB).EdgeColor = 'none';
		Bars(iB).FaceAlpha = 1/3;
	end
end
for iE = 1:height(ErrorBars)
	errorBar = ErrorBars.Object(iE);
	x = double(errorBar.XData(:));
	[~, colorIndex] = min(abs((1:size(colors, 1)).' - x(1)));
	errorBar.Color = colors(colorIndex, :);
end
end


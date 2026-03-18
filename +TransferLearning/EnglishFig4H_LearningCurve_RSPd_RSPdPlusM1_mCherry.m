function EnglishFig4H_LearningCurve_RSPd_RSPdPlusM1_mCherry()

rspPath     = "\\Data-Server-2\个人数据\张天夫\202505\RSP-Gi 化学遗传学抑制 声转光.v2.mat";
mopCtrlPath = "\\Data-Server-2\个人数据\张天夫\202409\Mop-Gi运动皮层化学遗传学抑制声光（无功能对照）.mat";
rspMoPath   = "\\data-server-2\个人数据\张天夫\202507\MOP+RSP化学遗传学抑制.v1.mat";

RSPd = UniExp.DataSet(rspPath);
RSPdTable = RSPd.TableQuery(["Mouse","DateTime","Performance"], Design="LightWater");
RSPdTable.Group(:) = "RSP";

MOpControl = UniExp.DataSet(mopCtrlPath);
MOpControlTable = MOpControl.TableQuery(["Mouse","DateTime","Performance"], Design="LightWater");
ControlTable = MOpControlTable;
ControlTable.Group(:) = "mCherry";

RSPdMo = UniExp.DataSet(rspMoPath);
RSPdMoTable = RSPdMo.TableQuery(["Mouse","DateTime","Performance","Phase"], Design="LightWater");
RSPdMoTable.Group(:) = "RSP+MOp";

Summary = UniExp.LearningSummarize(MATLAB.DataTypes.MergeTables(RSPdTable, ControlTable, RSPdMoTable));
palette3 = TransferLearning.FigurePalette(3);
RED = palette3(1,:);
BLUE = palette3(2,:);
GREEN = palette3(3,:);
rn = string(Summary.Properties.RowNames);
Colors = zeros(height(Summary), 3);
Colors(rn == "mCherry", :) = RED;
Colors(rn == "RSP",    :) = BLUE;
Colors(~(rn == "mCherry" | rn == "RSP"), :) = GREEN;

f = figure('Color','w', 'Name','English Fig4H Learning Curve');
f.Units = 'centimeters';
f.Position(3:4) = [9, 8];

ax = axes(f);
hold(ax,'on');
ax.FontSize = 12;
ax.Toolbar.Visible = 'off';

meanCells = cellfun(@(C) C(1:min(10, numel(C))), Summary.MeanCurve, UniformOutput=false);
semCells  = cellfun(@(C) C(1:min(10, numel(C))), Summary.SemCurve,  UniformOutput=false);
Patches = MATLAB.Graphics.MultiShadowedLines(meanCells, semCells, 1/(height(Summary)+1), EdgeColors=Colors);

nEach = cellfun(@height, Summary.LearnedSessions);
labels = Summary.Properties.RowNames + " n=" + string(nEach);

lg = legend(Patches, labels,Location='northeastoutside');
lg.FontSize = 12;
lg.Box = 'off';
lg.Title.String = '💡💧';
lg.Title.FontSize = 12;

box(ax,'off');
grid(ax,'off');
ylabel(ax, 'Hit rate', 'FontSize', 12);
xlabel(ax, 'Block', 'FontSize', 12);

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202602";
if ~isfolder(outDirUNC), mkdir(outDirUNC); end
svgName = 'English_Fig4H_LearningCurve_RSP_RSPPlusMOp_mCherry.svg';
svgPath = fullfile(outDirUNC, svgName);
TransferLearning.PrintFigure(f, svgPath, ForceLegendOrColorbar=true);
fprintf('Wrote: %s\n', svgPath);

Tn = table(Summary.Properties.RowNames, nEach(:), 'VariableNames', {'Group','N'});
disp(Tn);

rspFirst = iFirstSessionPerformance(RSPdTable);
mcherryFirst = iFirstSessionPerformance(ControlTable);

rn = string(Summary.Properties.RowNames);
rspColorIdx = find(rn == "RSP", 1);
mcherryColorIdx = find(rn == "mCherry", 1);
if isempty(rspColorIdx), rspColorIdx = 1; end
if isempty(mcherryColorIdx), mcherryColorIdx = 2; end

f2 = figure('Color','none', 'Name','English Fig4H First-session performance');
f2.Units = 'centimeters';
f2.Position(3:4) = [4, 4];
f2.PaperUnits = 'centimeters';
f2.PaperSize = [4, 4];
f2.PaperPositionMode = 'auto';
f2.InvertHardcopy = 'off';

tiledlayout(1,1,'TileSpacing','normal','Padding','normal');
nexttile;

DataCell = {rspFirst, mcherryFirst};
CompareGroup = table([1 2], 'VariableNames', {'GroupPair'});
[~, Optional2, Bars2, ErrorBars2] = UniExp.BarScatterCompare(DataCell, false, CompareGroup, 'AsteriskThreshold', 0.05);

ax2 = gca;
ax2.FontSize = 12;
ax2.Color = 'none';
ax2.XAxis.Visible = 'off';
ax2.XTick = [];
legend(ax2, 'off');

if isfield(Optional2, 'MultiCompare') && ismember('PText', Optional2.MultiCompare.Properties.VariableNames)
	for pt = Optional2.MultiCompare.PText(:)'
		pt.FontSize = 12;
	end
end

barColorIdx = [rspColorIdx, mcherryColorIdx];
if numel(Bars2) == 1
	Bars2.FaceColor = 'flat';
	Bars2.CData = Colors(barColorIdx, :);
	Bars2.BarWidth = 0.5;
	Bars2.LineWidth = 2;
	Bars2.FaceAlpha = 1/3;
else
	for ib = 1:min(2, numel(Bars2))
		Bars2(ib).FaceColor = Colors(barColorIdx(ib), :);
		Bars2(ib).LineWidth = 2;
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
ax2.Toolbar.Visible = 'off';

svgPath2 = fullfile(outDirUNC, 'English_Fig4H_FirstSessionPerformance_RSP_vs_mCherry.svg');
MATLAB.Graphics.PLineRetune(Optional2.MultiCompare.PLine,Optional2.MultiCompare.PText);
TransferLearning.PrintFigure(f2, svgPath2, ForceLegendOrColorbar=true);
fprintf('Wrote: %s\n', svgPath2);
end

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

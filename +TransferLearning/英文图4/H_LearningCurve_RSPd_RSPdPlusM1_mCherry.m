% English Fig4H: Learning curve – RSPd / RSPd+MOp / mCherry (LightWater)
%
% 3-group comparison using LearningSummarize + MultiShadowedLines.
% Data sources matched to WTMulti.m grouping.
%
% Execution:
%   TransferLearning.英文图4.H_LearningCurve_RSPd_RSPdPlusM1_mCherry

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";

% --- 1) Load datasets (match WTMulti.m)
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

% Summarize
Summary = UniExp.LearningSummarize(MATLAB.DataTypes.MergeTables(RSPdTable, ControlTable, RSPdMoTable));
Summary.Properties.RowNames = replace(Summary.Properties.RowNames, 'MOp', 'M1');
Colors = GlobalOptimization.ColorAllocate(height(Summary), [1,1,1;1,1,1;1,1,1]);

% --- 2) Plot
svgName = 'English_Fig4H_LearningCurve_RSPd_RSPdPlusM1_mCherry.svg';
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

box(ax,'off');
grid(ax,'off');
ylabel(ax, 'Hit rate');
xlabel(ax, 'Block');

% --- Export main learning curve
if ~isfolder(outDirUNC), mkdir(outDirUNC); end
svgPath = fullfile(outDirUNC, svgName);
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);

Tn = table(Summary.Properties.RowNames, nEach(:), 'VariableNames', {'Group','N'});
disp(Tn);

% --- First-session bar comparison (RSPd vs mCherry only, mimic Fig1B)
rspFirst = iFirstSessionPerformance(RSPdTable);
mcherryFirst = iFirstSessionPerformance(ControlTable);

% Match bar colors to learning curve colors
rn = string(Summary.Properties.RowNames);
rspColorIdx = find(rn == "RSPd", 1);
mcherryColorIdx = find(rn == "mCherry", 1);
if isempty(rspColorIdx), rspColorIdx = 1; end
if isempty(mcherryColorIdx), mcherryColorIdx = 2; end

%% 
f2 = figure('Color','none', 'Name','English Fig4H First-session performance');
f2.Units = 'centimeters';
pos2 = f2.Position;
pos2(3:4) = [4, 3];
f2.Position = pos2;
f2.PaperUnits = 'centimeters';
f2.PaperSize = [4, 3];
f2.PaperPositionMode = 'auto';
f2.InvertHardcopy = 'off';

tiledlayout(1,1,'TileSpacing','compact','Padding','compact');
nexttile;

DataCell = {rspFirst, mcherryFirst};
CompareGroup = table([1 2], 'VariableNames', {'GroupPair'});
[~, Optional2, Bars2, ErrorBars2] = UniExp.BarScatterCompare(DataCell, false, CompareGroup, 'AsteriskThreshold', 0.05);

ax2 = gca;
ax2.FontSize = 12/1.2;
ax2.Color = 'none';
ax2.XTick = [1, 2];
ax2.XTickLabel = {'RSPd', 'mCh.'};
legend(ax2, 'off');

% Asterisk font size
if isfield(Optional2, 'MultiCompare') && ismember('PText', Optional2.MultiCompare.Properties.VariableNames)
	for pt = Optional2.MultiCompare.PText(:)'
		pt.FontSize = 12/1.2;
	end
end

% Bar styling (match curve colors, FaceAlpha 1/3)
barColorIdx = [rspColorIdx, mcherryColorIdx];
if numel(Bars2) == 1
	Bars2.FaceColor = 'flat';
	Bars2.CData = Colors(barColorIdx, :);
	Bars2.BarWidth = 0.5;
	Bars2.LineWidth = 0.5;
	Bars2.FaceAlpha = 1/3;
else
	for ib = 1:min(2, numel(Bars2))
		Bars2(ib).FaceColor = Colors(barColorIdx(ib), :);
		Bars2(ib).LineWidth = 0.5;
		Bars2(ib).FaceAlpha = 1/3;
	end
end
for eb = ErrorBars2.Object(:)'
	eb.LineWidth = 0.5;
end
ax2.XLim = [0.5, 2.5];
ylabel(ax2, 'Hit rate');
title(ax2, 'First block');
box(ax2, 'off');
ax2.Toolbar.Visible = 'off';

svgPath2 = fullfile(outDirUNC, 'English_Fig4H_FirstSessionPerformance_RSPd_vs_mCherry.svg');
MATLAB.Graphics.PLineRetune(Optional2.MultiCompare.PLine,Optional2.MultiCompare.PText);
TransferLearning.PrintFigure(f2, svgPath2);
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

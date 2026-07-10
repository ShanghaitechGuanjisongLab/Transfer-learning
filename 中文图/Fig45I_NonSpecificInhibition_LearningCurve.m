% 中文图334D：Non-specific inhibition 学习曲线
% 数据源与算法：hM4D(Gi) vs mCherry 的 LightWater learning curve
% 样式：模仿英文图2K（颜色、线宽、ylabel、整体布局）



if ~exist('UniExp.DataSet','class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile,'file')
		matlab.project.loadProject(prjFile);
	end
end

pathGi = "\\Data-Server-2\个人数据\张天夫\202601\Mop-Gi运动皮层化学遗传学抑制 声水转光水.v3.mat";
pathmCh = "\\Data-Server-2\个人数据\张天夫\202601\Mop-Gi运动皮层化学遗传学抑制声光（无功能对照）.v2.mat";
DS_Gi = UniExp.DataSet(pathGi);
DS_mCh = UniExp.DataSet(pathmCh);

BInh = TransferLearning.BehaviorSessions.iQueryLightWaterBlocks(DS_Gi, false);
BCtrl = TransferLearning.BehaviorSessions.iQueryLightWaterBlocks(DS_mCh, false);
if isempty(BInh) || isempty(BCtrl)
	error('Fig334D:EmptyBehavior', 'Empty LightWater behavior in one of the datasets.');
end

BInh.Group = repmat("hM4D(Gi)", height(BInh), 1);
BCtrl.Group = repmat("mCherry", height(BCtrl), 1);
BInh.Mouse = string(BInh.Mouse);
BCtrl.Mouse = string(BCtrl.Mouse);
BInh.DateTime = TransferLearning.BehaviorSessions.iNormalizeDateTime(BInh.DateTime);
BCtrl.DateTime = TransferLearning.BehaviorSessions.iNormalizeDateTime(BCtrl.DateTime);

J = [BCtrl; BInh];
J.Group = string(J.Group);
Sess = TransferLearning.BehaviorSessions.iSessionizeByDateTime(J(:, intersect(J.Properties.VariableNames, {'Mouse','DateTime','Performance','Group','Phase'}, 'stable')));
Sess = sortrows(Sess, {'Group','Mouse','DateTime'});
Sess = TransferLearning.BehaviorSessions.iAddSessionIndex(Sess);
nControlMice = numel(unique(string(Sess.Mouse(Sess.Group == "mCherry"))));
nInhibitedMice = numel(unique(string(Sess.Mouse(Sess.Group == "hM4D(Gi)"))));

sessionForSummary = Sess(:, {'Mouse','DateTime','Performance','Group'});
sessionForSummary.Group = string(sessionForSummary.Group);
[SummaryL, pSumm] = UniExp.LearningSummarize(sessionForSummary);

grpOrder = ["mCherry", "hM4D(Gi)"];
grpLabels = ["Control", "Inhibited"];
SummaryPlot = SummaryL(grpOrder, :);
meanCells = cellfun(@(v) double(v(:))', SummaryPlot.MeanCurve, 'UniformOutput', false);
semCells = cellfun(@(v) double(v(:))', SummaryPlot.SemCurve, 'UniformOutput', false);

lmeTbl = table;
lmeTbl.Performance = double(Sess.Performance);
lmeTbl.Session = double(Sess.Session);
lmeTbl.Group = categorical(string(Sess.Group));
lmeTbl.Mouse = categorical(string(Sess.Mouse));
lmeModel = fitlme(lmeTbl, 'Performance ~ Session + Group + (1|Mouse)');
lmeAnova = anova(lmeModel);
rowGrp = find(string(lmeAnova.Term) == "Group", 1);
pCurve = NaN;
if ~isempty(rowGrp)
	pCurve = lmeAnova.pValue(rowGrp);
end
%% 

f = figure('Color','w', 'Name', '中文图334D Non-specific inhibition learning curve');
f.Units = 'centimeters';
f.Position(3:4) = [9, 8];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 9, 8];
f.PaperSize = [9, 8];

ax = axes(f);
hold(ax, 'on');
edgeColors = [TransferLearning.ContinualColor;TransferLearning.ColorB];
Patches = MATLAB.Graphics.MultiShadowedLines(meanCells, semCells, 1/(numel(grpOrder)+1), EdgeColors=edgeColors(1:2,:));
for p = Patches(:)'
	if isprop(p, 'LineWidth')
		p.LineWidth = 2;
	end
end

title(ax, 'Non-specific inhibition', 'FontSize', 12, 'FontWeight', 'normal');

% Horizontal P-value line spanning blocks 1-7
groupP = TransferLearning.Style.TwoWayAnovaGroupPValue(Sess, 'Performance', 'Session', 'Group', 'Mouse');
sessions7 = Sess(Sess.Session <= 7, :);
groupP7 = TransferLearning.Style.TwoWayAnovaGroupPValue(sessions7, 'Performance', 'Session', 'Group', 'Mouse');
max7Ctrl = max(meanCells{1}(1:min(7, end)), [], 'omitnan');
max7Inh = max(meanCells{2}(1:min(7, end)), [], 'omitnan');
yTop7 = max(max7Ctrl, max7Inh);
yl = ylim(ax); yrange = yl(2) - yl(1);
yPLine = yTop7 + 0.08 * yrange;
textY = yPLine + 0.1 * yrange;
plot(ax, [1, 7], [yPLine, yPLine], 'k-', 'LineWidth', 1);
if groupP7 < 0.001, starStr = '＊＊＊＊'; else, starStr = TransferLearning.Style.iFormatPText(groupP7); end
text(ax, 4, textY, starStr, ...
	'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', 'FontSize', 12);
yt = yticks(ax);
yticks(ax, yt(yt <= 1 + 1e-6));

lg = legend(ax, Patches(1:2), cellstr(grpLabels), 'Location', 'best');
lg.Box = 'off';
ax.FontSize = 12;
ax.LineWidth = 2;
if isprop(ax.XAxis, 'LineWidth')
	ax.XAxis.LineWidth = 2;
	ax.YAxis.LineWidth = 2;
end
xlabel(ax, 'Block', 'FontSize', 12);
ylabel(ax, 'Hit rate', 'FontSize', 12);
box(ax, 'off');
grid(ax, 'off');
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end

if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgName = "中文图Fig45I_NonSpecificInhibition_LearningCurve.svg";
svgPath = svgName;
svgPath = TransferLearning.ExportStandardFigure(f, 2, svgPath);
fprintf('Wrote: %s\n', svgPath);
fprintf('Two-way ANOVA Group P (all blocks) = %.4g\n', groupP);
fprintf('Two-way ANOVA Group P (blocks 1-7) = %.4g\n', groupP7);
fprintf('Fig334D mice: Control n = %d, hM4D(Gi) n = %d\n', nControlMice, nInhibitedMice);
fprintf('Fig334D learning curve LME group-effect p = %.4g\n', pCurve);

assignin('base', 'Fig334D_Sessions', Sess);
assignin('base', 'Fig334D_LearningSummarizeP', pSumm);
assignin('base', 'Fig334D_LMECurveP', pCurve);


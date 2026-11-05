% Fig1B｜Light-water 学习曲线（单独出图）
%
% 由 Fig1_TimeContinuityBehavior.m 中的 B 面板拆出，单独成图。
%   · 只画各组逐 block 实测均值 + SEM 误差棒（点 + error bar，**不连线**）
%   · 不画 Sigmoid 拟合曲线、不画任何"虚拟"连线
%   · 不做显著性标注
%
% 目标任务 X = LightWater（声→光方向）
%   Naive          直接学 LW            LightAudioBaseline + LAInterspersed
%   Transfer       先学 AW 再学 LW      · 12 h：AudioLightBaseline(Transfer→Final)
%                                       · 7 d ：Vacation7(Transfer→Final)

if ~exist('UniExp.DataSet', 'class')
	thisDir = fileparts(mfilename('fullpath'));
	prjFile = fullfile(thisDir, 'Transferlearning.prj');
	if ~exist(prjFile, 'file')
		prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	end
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end
warning('off', 'UniExp:Exception:Block_must_warn');

groupOrder = ["Naive", "Transfer", "7dayTransfer"];
groupLabels = ["Naive (LW direct)", "Transfer (AW→12 h→LW)", "Transfer (AW→7 d→LW)"];
colors = [TransferLearning.NaiveColor; TransferLearning.TransferColor; TransferLearning.ColorB];

% ---------- 组水平学习曲线 ----------
% 快路径：base 工作区已有 Fig1B_Data 时直接复用，跳过（很慢的）网络盘数据加载
if evalin('base', 'exist(''Fig1B_Data'',''var'')')
	D = evalin('base', 'Fig1B_Data');
	meanMat = D.Mean;
	semMat = D.Sem;
	fprintf('复用 base 工作区的 Fig1B_Data（跳过数据加载）\n');
else
	Sess = TransferLearning.BehaviorSessions.LightWaterLearningSessions();
	curveIn = Sess(:, {'Mouse','DateTime','Performance','Group'});
	[~, summaryL] = evalc('UniExp.LearningSummarize(curveIn)');
	rowNames = string(summaryL.Properties.RowNames);
	meanMat = cell(1, numel(groupOrder));
	semMat = cell(1, numel(groupOrder));
	for k = 1:numel(groupOrder)
		ix = find(rowNames == groupOrder(k), 1, 'first');
		mv = double(summaryL.MeanCurve{ix}(:));
		sv = double(summaryL.SemCurve{ix}(:));
		meanMat{k} = mv(1:find(isfinite(mv), 1, 'last')).';
		semMat{k} = sv(1:find(isfinite(sv), 1, 'last')).';
	end
end
xMax = min(10, max(cellfun(@numel, meanMat)));
for k = 1:numel(groupOrder)
	meanMat{k} = meanMat{k}(1:min(xMax, numel(meanMat{k})));
	semMat{k} = semMat{k}(1:min(xMax, numel(semMat{k})));
end

%% ---------- 出图（仅 B 面板） ----------
f = figure('Color', 'w', 'Name', 'Fig1B Light-water learning curve');
f.Units = 'centimeters';
f.Position(3:4) = [9, 8];
f.PaperUnits = 'centimeters';
f.PaperSize = [9, 8];
f.PaperPositionMode = 'auto';

axB = axes(f);
axB.Position = [0.150 0.135 0.825 0.830];
axB.FontSize = 8;
hold(axB, 'on');
for k = 1:numel(groupOrder)
	xk = (1:numel(meanMat{k})).';
	yk = meanMat{k}(:);
	ek = semMat{k}(:);
	errorbar(axB, xk, yk, ek, 'o-', 'Color', colors(k, :), ...
		'MarkerFaceColor', colors(k, :), 'MarkerSize', 4, ...
		'LineWidth', 1, 'CapSize', 2, 'HandleVisibility', 'off');
end

% 图例：点 + 连线代理
proxy = gobjects(numel(groupOrder), 1);
for k = 1:numel(groupOrder)
	proxy(k) = plot(axB, nan, nan, 'o-', 'Color', colors(k, :), ...
		'MarkerFaceColor', colors(k, :), 'MarkerSize', 4, 'LineWidth', 1);
end

xlabel(axB, 'Block');
ylabel(axB, 'Hit rate');
xlim(axB, [0.6, xMax + 0.4]);
ylim(axB, [0, 1]);
yticks(axB, 0:0.2:1);
xticks(axB, 1:xMax);
axB.XTickLabelRotation = 0;
box(axB, 'off');
lgLabels = {'Naive', 'Transfer 12 h', 'Transfer 7 d'};
lg = legend(axB, proxy, lgLabels, 'Location', 'southeast', ...
	'Orientation', 'vertical', 'NumColumns', 1);
lg.ItemTokenSize = [12, 9];
lg.Box = 'off';
lg.FontSize = 7.5;
lg.AutoUpdate = 'off';

if isprop(axB, 'Toolbar') && ~isempty(axB.Toolbar)
	axB.Toolbar.Visible = 'off';
end

outDir = fileparts(TransferLearning.StandardFigureSvgPath('Fig1B_TimeContinuityLearningCurve.svg'));
figPath = fullfile(outDir, 'Fig1B_TimeContinuityLearningCurve.fig');
savefig(f, figPath);
fprintf('Saved: %s\n', figPath);
svgPath = TransferLearning.ExportStandardFigure(f, 2, 'Fig1B_TimeContinuityLearningCurve.svg');
fprintf('Saved: %s\n', svgPath);

assignin('base', 'Fig1B_Data', struct('Mean', {meanMat}, 'Sem', {semMat}, ...
	'Group', groupOrder));

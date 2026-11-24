% Sup4A_THInhibit_RecallOldTask.m —— Sup Fig 4A：TH 抑制不影响已经学会的旧任务（Recall）
%
% 目的：TH（丘脑）抑制作用于新任务（光水）学习；旧任务（声水）在迁移后 Recall
%       仍保持天花板水平 ⇒ 迁移期缺陷不是"不会做/忘了旧任务"。
%
% 数据：Ctrl = AudioLightBaseline，TH = THInhibit；
%       Phase = Recall 的 AudioWater 试次，逐鼠命中率。
% 统计：Ctrl vs TH 的 ranksum。
%
% 输出：English_Sup4A_THInhibit_RecallOldTask.svg

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end
addpath(fullfile(thisDir, '..'));

DSs = {TransferLearning.AudioLightBaseline(), TransferLearning.THInhibit()};
grpName = ["Ctrl", "TH"];
cols = [TransferLearning.Color12h; TransferLearning.ColorTH] / 255;

Y = cell(1, 2);
for g = 1:2
	T = DSs{g}.TableQuery(["Mouse","DateTime","Phase","Stimulus","Behavior"]);
	T.Mouse = string(T.Mouse);
	T.Phase = fillmissing(string(T.Phase), 'constant', "<none>");
	T.Stimulus = fillmissing(string(T.Stimulus), 'constant', "<none>");
	T = T(T.Stimulus == "AudioWater" & T.Phase == "Recall", :);
	mice = unique(T.Mouse);
	v = nan(numel(mice), 1);
	for i = 1:numel(mice)
		s = T.Mouse == mice(i);
		if ~any(s), continue; end
		v(i) = mean(T.Behavior(s) == 1);
	end
	Y{g} = v(isfinite(v));
end

pVal = iRanksum(Y{1}, Y{2});
fprintf('\n=== 旧任务（声水）Recall 逐鼠命中率 ===\n');
fprintf('Ctrl n=%d mean=%.3f median=%.3f\n', numel(Y{1}), mean(Y{1}), median(Y{1}));
fprintf('TH   n=%d mean=%.3f median=%.3f\n', numel(Y{2}), mean(Y{2}), median(Y{2}));
fprintf('ranksum p = %.4g\n', pVal);

figW = 2.4; figH = 3.4;
f = figure('Color', 'w', 'Name', 'Sup4A TH old task recall');
f.Units = 'centimeters';
f.Position(3:4) = [figW figH];
f.PaperUnits = 'centimeters';
f.PaperSize = [figW figH];
f.PaperPosition = [0 0 figW figH];
f.PaperPositionMode = 'manual';

ax = axes(f, 'Position', [0.300 0.210 0.660 0.740]);
hold(ax, 'on');
bw = 0.50;
for g = 1:2
	v = Y{g};
	bar(ax, g, mean(v), bw, 'FaceColor', cols(g, :), 'EdgeColor', 'none');
	e = std(v) / sqrt(numel(v));
	plot(ax, [g g], [mean(v), mean(v) + e], '-', 'Color', [0.25 0.25 0.25], 'LineWidth', 0.5);
	jit = (rand(numel(v), 1) - 0.5) * 0.20;
	scatter(ax, g + jit, v, 5, 'o', 'filled', ...
		'MarkerFaceColor', cols(g, :) * 0.60, 'MarkerEdgeColor', 'none');
end
yBar = 1.015;
plot(ax, [1 2], [yBar yBar], '-', 'Color', [0.2 0.2 0.2], 'LineWidth', 0.5);
text(ax, 1.5, yBar, ['  ' TransferLearning.Style.iFormatPStars(pVal)], ...
	'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 5.5);

set(ax, 'XTick', [1 2], 'XTickLabel', grpName);
xlim(ax, [0.4 2.6]);
ylabel(ax, 'Recall hit rate', 'FontSize', 6);
ax.FontSize = 6; ax.LineWidth = 0.5; box(ax, 'off'); grid(ax, 'off');

TransferLearning.Style.ApplyStandardFigureStyle(f, 1);
% 标准格式会重置轴位与范围，需在其后重设，然后直接 print 出图
ax.Position = [0.300 0.210 0.660 0.740];
ylim(ax, [0.55 1.06]);
ax.YTick = 0.6:0.2:1.0;
set(ax, 'XTick', [1 2], 'XTickLabel', grpName);
svgPath = TransferLearning.StandardFigureSvgPath('English_Sup4A_THInhibit_RecallOldTask.svg');
print(f, svgPath, '-dsvg');
fprintf('Wrote: %s\n', svgPath);

function p = iRanksum(a, b)
a = a(isfinite(a)); b = b(isfinite(b));
if numel(a) < 3 || numel(b) < 3 || (all(a == a(1)) && all(b == b(1)))
	p = NaN;
else
	p = ranksum(a, b);
end
end

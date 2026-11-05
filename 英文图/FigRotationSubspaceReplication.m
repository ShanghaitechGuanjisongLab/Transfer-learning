function FigRotationSubspaceReplication()
%[text] 两队列复现：ALB（声水→光水）与 LAB（光水→声水，任务顺序相反）
%
% 数据来源：rslds/results/_fig_repl_goal1.csv、_fig_repl_goal2.csv
%   goal1 = MOp2/3 扣弧后 ratio = rho_res / 相位随机化零基线（P1 主分析），逐鼠逐阶段
%   goal2 = 旋转子空间重叠（m=4, P1）：cross（Learned–Transfer）、null（打乱细胞标签 95%）、
%           ceiling（阶段内奇偶分半）
%
% (a) 目标 1：比值按阶段 × 队列，看“Transfer 最高”是否在任务顺序相反的队列重现
% (b) 目标 2：cross / null / ceiling 按队列，看“高于零、低于天花板”是否重现
%
% 注意：两队列的零基线尺度不同（LAB 更高），故 (a) 只能比较阶段间排序，不能跨队列比绝对值。

if ~exist('TransferLearning','class') || ~exist('UniExp.DataSet','class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile,'file')
		matlab.project.loadProject(prjFile);
	end
end

T1 = readtable(TransferLearning.ProjectPath('rslds','results','_fig_repl_goal1.csv'), TextType="string");
T2 = readtable(TransferLearning.ProjectPath('rslds','results','_fig_repl_goal2.csv'), TextType="string");

cohorts = ["ALB","LAB"];
phases = ["Learned","Transfer","Final"];
cohCol = [0.20 0.35 0.65; 0.75 0.42 0.20];

f = figure('Color','w','Name','FigRotationSubspaceReplication');
f.Units = 'centimeters';
f.Position(3:4) = [16 8];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0 0 16 8];
f.PaperSize = [16 8];
layout = tiledlayout(f, 1, 2, 'TileSpacing','compact','Padding','compact');

% ---- (a) 目标 1
ax = nexttile(layout, 1);
hold(ax,'on');
hC = gobjects(1,2);
for ci = 1:numel(cohorts)
	xBase = (1:numel(phases)) + (ci-1.5)*0.18;
	for pi = 1:numel(phases)
		s = T1(T1.cohort == cohorts(ci) & T1.phase == phases(pi), :);
		if isempty(s); continue; end
		jit = 0.055*linspace(-1,1,height(s))';
		hC(ci) = plot(ax, xBase(pi)+jit, s.ratio, 'o', 'MarkerSize',2.8, ...
			'MarkerFaceColor','w','MarkerEdgeColor',cohCol(ci,:),'LineWidth',0.7);
		plot(ax, xBase(pi), median(s.ratio,'omitnan'), '_', 'Color',cohCol(ci,:), ...
			'MarkerSize',13, 'LineWidth',2);
	end
end
plot(ax,[0.5 numel(phases)+0.5],[1 1],'--','Color',[0.6 0.6 0.6],'LineWidth',0.8);
ax.XTick = 1:numel(phases);
ax.XTickLabel = {'Learned','Transfer','Final'};
ax.XTickLabelRotation = 0;
xlim(ax,[0.5 numel(phases)+0.5]); ylim(ax,[0.7 1.75]);
ylabel(ax,'Rotational excess / null  (P1)');
title(ax,'(a) Phase ordering');
iStyle(ax);
lgA = legend(ax, hC, {'ALB (audio→light)','LAB (light→audio)'}, 'Box','off', ...
	'Orientation','horizontal','NumColumns',2);
lgA.Layout.Tile = 'north';

% ---- (b) 目标 2
ax = nexttile(layout, 2);
hold(ax,'on');
fields = ["null","cross","ceiling"];
fieldLabels = ["null (95%)","cross-phase","within-phase ceiling"];
markers = {'v','o','s'};
for ci = 1:numel(cohorts)
	s = T2(T2.cohort == cohorts(ci), :);
	if isempty(s); continue; end
	for fi = 1:numel(fields)
		xc = ci + (fi-2)*0.22;
		v = s.(fields(fi));
		jit = 0.05*linspace(-1,1,height(s))';
		plot(ax, xc+jit, v, markers{fi}, 'MarkerSize',2.8, 'MarkerFaceColor','w', ...
			'MarkerEdgeColor',cohCol(ci,:), 'LineWidth',0.7);
		plot(ax, xc, median(v,'omitnan'), '_', 'Color',cohCol(ci,:), ...
			'MarkerSize',13, 'LineWidth',2);
	end
end
ax.XTick = 1:numel(cohorts);
ax.XTickLabel = cohorts;
ax.XTickLabelRotation = 0;
xlim(ax,[0.45 numel(cohorts)+0.55]); ylim(ax,[0 0.72]);
ylabel(ax,'Subspace overlap  (m = 4, P1)');
title(ax,'(b) Within-cohort ordering');
iStyle(ax);
hM = gobjects(1,3);
for fi = 1:3
	hM(fi) = plot(ax, nan, nan, markers{fi}, 'MarkerSize',4.5, 'MarkerFaceColor','w', ...
		'MarkerEdgeColor',[0.35 0.35 0.35], 'LineWidth',0.9);
end
lgB = legend(ax, hM, cellstr(fieldLabels), 'Box','off', ...
	'Orientation','horizontal','NumColumns',3);
lgB.Layout.Tile = 'south';

svgPath = TransferLearning.ExportStandardFigure(f, 2, 'FigRotationSubspaceReplication.svg');
fprintf('Wrote: %s\n', svgPath);
end

function iStyle(ax)
ax.Box = 'off';
ax.TickDir = 'out';
ax.Layer = 'top';
end

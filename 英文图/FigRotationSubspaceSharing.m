function FigRotationSubspaceSharing()
%[text] 旋转子空间跨阶段共享：ALB 三档预处理下的逐鼠结果（PreReg_Attractor §A.25）
%
% 数据来源：rslds/results/_step41_fig.csv（由 Step41_RotationSubspaceVariants.py 生成）
% 口径：三阶段 CellUID 交集、MOp2/3；去 trial 锁时平均轨迹后算 A_tau=(C_tau-C_tau')/2；
%       取前 m 个右奇异向量作子空间；overlap=||W1'W2||_F^2/m；
%       null = 打乱细胞标签（N_PERM=500）；ceiling = 阶段内奇偶分半重叠。
%
% 三块：(a) m=2，(b) m=4，(c) ratio = cross/ceiling（m=2 与 m=4 并列）。
% 陈述要点：跨阶段重叠稳定高于零模型（8-9/11 只鼠），但只有阶段内天花板的 41-75%
%           ⇒ 部分共享，且远非同一；该结论对预处理口径稳健。

% --- 0) Ensure project loaded
if ~exist('TransferLearning','class') || ~exist('UniExp.DataSet','class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile,'file')
		matlab.project.loadProject(prjFile);
	end
end

% --- 1) 读数
csvPath = TransferLearning.ProjectPath('rslds','results','_step41_fig.csv');
T = readtable(csvPath, TextType="string");
variants = ["P0","P1","P2"];
mList = [2 4];
panelTitle = ["(a) m = 2","(b) m = 4","(c) sharing fraction"];
mice = unique(T.mouse);

grayLine  = [0.60 0.60 0.60];
blackLine = [0.10 0.10 0.10];
nullColor = [0.20 0.45 0.75];
ceilColor = [0.85 0.45 0.15];
ratioCol  = [0.45 0.68 0.50; 0.10 0.32 0.18];

% --- 2) 画布
f = figure('Color','w','Name','FigRotationSubspaceSharing');
f.Units = 'centimeters';
f.Position(3:4) = [18 8];
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0 0 18 8];
f.PaperSize = [18 8];
layout = tiledlayout(f, 1, 3, 'TileSpacing','compact','Padding','compact');

% --- 3) (a)(b)
hMouse = []; hMed = []; hNull = []; hCeil = [];
for mi = 1:numel(mList)
	m = mList(mi);
	ax = nexttile(layout, mi);
	hold(ax,'on');
	for vi = 1:numel(variants)
		s = T(T.m == m & T.variant == variants(vi), :);
		s = iOrderByMouse(s, mice);
		jit = 0.07 * linspace(-1,1,height(s))';
		hMouse = plot(ax, repmat(vi,height(s),1), s.r_LT1, '-', ...
			'Color',[grayLine 0.45], 'LineWidth',0.4);
		plot(ax, vi + jit, s.r_LT1, 'o', 'MarkerSize',2.8, 'MarkerFaceColor','w', ...
			'MarkerEdgeColor',grayLine, 'LineWidth',0.5);
		hMed = plot(ax, vi, median(s.r_LT1,'omitnan'), '_', 'Color',blackLine, ...
			'MarkerSize',13, 'LineWidth',2);
		hNull = plot(ax, vi, median(s.null95,'omitnan'), 'v', 'Color',nullColor, ...
			'MarkerFaceColor','w','MarkerSize',4.5,'LineWidth',0.9);
		hCeil = plot(ax, vi, median(s.ceil_max,'omitnan'), 's', 'Color',ceilColor, ...
			'MarkerFaceColor','w','MarkerSize',4.5,'LineWidth',0.9);
	end
	iStyleAxes(ax, 1:numel(variants));
	set(ax,'XTickLabel',{'P0','P1','P2'});
	ylim(ax,[0 0.40]);
	title(ax, panelTitle(mi));
	ylabel(ax,'Cross-phase overlap');
end

% --- 4) (c)
ax = nexttile(layout, 3);
hold(ax,'on');
hRatio = gobjects(1, numel(mList));
for mi = 1:numel(mList)
	m = mList(mi);
	hRatio(mi) = plot(ax, nan, nan, 'o', 'MarkerSize',4, ...
		'MarkerFaceColor','w', 'MarkerEdgeColor',ratioCol(mi,:), 'LineWidth',0.9);
	for vi = 1:numel(variants)
		s = T(T.m == m & T.variant == variants(vi), :);
		if isempty(s); continue; end
		xc = vi + (mi-1.5)*0.17;
		plot(ax, xc*ones(height(s),1), s.ratio, 'o', 'MarkerSize',2.8, ...
			'MarkerFaceColor','w', 'MarkerEdgeColor',ratioCol(mi,:), 'LineWidth',0.6);
		plot(ax, xc, median(s.ratio,'omitnan'), '_', 'Color',ratioCol(mi,:), ...
			'MarkerSize',12, 'LineWidth',2);
	end
end
hDashR = plot(ax,[0.4 numel(variants)+0.6],[1 1],'--','Color',[0.75 0.15 0.15],'LineWidth',0.9);
iStyleAxes(ax, 1:numel(variants));
set(ax,'XTickLabel',{'P0','P1','P2'});
ylim(ax,[0 1.30]);
ylabel(ax,'Overlap / within-phase ceiling');
title(ax, panelTitle(3));
lgR = legend(ax, [hRatio, hDashR], {'m = 2','m = 4','complete sharing'}, ...
	'Orientation','horizontal','Box','off','NumColumns',3);
lgR.Layout.Tile = 'south';

% --- 5) 布局级标签与图例
xlabel(layout,'Preprocessing variant');
lg = legend([hMouse, hMed, hNull, hCeil], ...
	{'individual mice','median','label-permutation null (95%)','within-phase ceiling'}, ...
	'Orientation','horizontal','Box','off','NumColumns',2);
lg.Layout.Tile = 'north';

% --- 6) 导出
svgPath = TransferLearning.ExportStandardFigure(f, 2, 'FigRotationSubspaceSharing.svg');
fprintf('Wrote: %s\n', svgPath);
end

function s = iOrderByMouse(s, mice)
[~, pos] = ismember(s.mouse, mice);
[~, order] = sort(pos);
s = s(order, :);
end

function iStyleAxes(ax, xVals)
ax.XTick = xVals;
ax.XTickLabelRotation = 0;
ax.Box = 'off';
ax.TickDir = 'out';
ax.Layer = 'top';
xlim(ax, [0.55, numel(xVals) + 0.45]);
end

% [存档] 旧编号脚本（已去图号，不再对应正式面板），保留代码备查。
% Fig_Summary.m —— Fig 1 总结示意图（定性示意 + 实测首 block 命中率）
%
% 逻辑链：任务 A（声→水）在 MOp 建立 ensemble → 间隔（12 h / 7 d）→ 任务 B（光→水）
%         复用强弱不同 → 首 block 命中率不同。
%   Naive 行作为参照：没有任务 A，因此没有可复用的 ensemble。
%
% 数字口径（来自 Fig1C 的三组首 block 命中率，均值）：
%   Naive 0.160、12 h 0.524、7 d 0.133
% 其余元素（间隔箭头粗细、复用强弱）为定性示意，不标数字。

thisDir = fileparts(mfilename('fullpath'));
if ~exist('TransferLearning', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end
addpath(fullfile(thisDir, '..'));

cNaive = TransferLearning.ColorNaive / 255;
c12    = TransferLearning.Color12h / 255;
c7     = TransferLearning.Color7d / 255;
gEdge  = [0.45 0.45 0.45];
gText  = [0.15 0.15 0.15];

figW = 9.0; figH = 5.6;
f = figure('Color', 'w', 'Name', 'Fig1 summary schematic');
f.Units = 'centimeters';
f.Position(3:4) = [figW figH];
f.PaperUnits = 'centimeters';
f.PaperSize = [figW figH];
f.PaperPosition = [0 0 figW figH];
f.PaperPositionMode = 'manual';

ax = axes(f, 'Position', [0 0 1 1], 'Visible', 'off');
hold(ax, 'on');
xlim(ax, [0 1]);
ylim(ax, [0 1]);
figAR = figW / figH;   % 用于让箭头三角在非方形坐标系里保持形状

% 列几何
xTaskA = 0.015; wBox = 0.190;
xEns   = 0.335;
xTaskB = 0.650;
xBar   = 0.880; wBar = 0.045;
yRows  = [0.780 0.480 0.180];
hBox   = 0.165;
yBase  = -0.100;      % 柱底（相对行中心）
barScale = 0.205;

% 列标题
hdrs = {'Task A', 'Interval', 'MOp ensemble', 'Task B', 'First block'};
xh   = [xTaskA + wBox/2, 0.2675, xEns + wBox/2, xTaskB + wBox/2, xBar + wBar/2];
for i = 1:numel(hdrs)
	text(ax, xh(i), 0.985, hdrs{i}, 'HorizontalAlignment', 'center', ...
		'VerticalAlignment', 'top', 'FontSize', 5.5, 'Color', [0.2 0.2 0.2]);
end
plot(ax, [0.005 0.995], [0.935 0.935], '-', 'Color', [0.78 0.78 0.78], 'LineWidth', 0.4);

rows = struct( ...
	'grp',   {'Naive', '12 h', '7 d'}, ...
	'taskA', {'no prior task', 'sound \rightarrow water', 'sound \rightarrow water'}, ...
	'inter', {'',      '12 h',   '7 d'}, ...
	'reuse', {'',      'strong', 'weak'}, ...
	'bar',   {0.160,   0.524,    0.133}, ...
	'color', {cNaive,  c12,      c7}, ...
	'hasEns',{false,   true,     true});

for iR = 1:numel(rows)
	R = rows(iR);
	yc = yRows(iR);
	yB = yc - hBox/2;
	ls = '-';   edge = gEdge;
	if ~R.hasEns
		ls = '--'; edge = [0.72 0.72 0.72];
	end

	% --- Task A（组名放在框内，避免外侧旋转标签被裁）---
	iBox(ax, xTaskA, yB, wBox, hBox, edge, [0.975 0.975 0.975], ls);
	text(ax, xTaskA + wBox/2, yc + 0.050, R.grp, 'HorizontalAlignment', 'center', ...
		'VerticalAlignment', 'middle', 'FontSize', 5.5, 'FontWeight', 'bold', 'Color', R.color * 0.8);
	text(ax, xTaskA + wBox/2, yc - 0.030, R.taskA, 'HorizontalAlignment', 'center', ...
		'VerticalAlignment', 'middle', 'FontSize', 5, 'Color', gText);

	% --- 间隔箭头（12 h 粗 = 连续；7 d 细 = 长间隔）---
	lw = 1.5;  if iR == 3, lw = 0.6; end
	iArrow(ax, xTaskA + wBox + 0.008, xEns - 0.008, yc, lw, [0.35 0.35 0.35], ~R.hasEns, figAR);
	if ~isempty(R.inter)
		text(ax, 0.2675, yc + 0.048, R.inter, 'HorizontalAlignment', 'center', ...
			'VerticalAlignment', 'bottom', 'FontSize', 5, 'Color', R.color * 0.8, 'FontWeight', 'bold');
	end

	% --- MOp ensemble ---
	if R.hasEns
		iBox(ax, xEns, yB, wBox, hBox, gEdge, [1 1 1], '-');
		dx = wBox / 7.4;  dy = hBox / 3.8;
		for r2 = 1:2
			for c2 = 1:6
				xc  = xEns + wBox/2 + (c2 - 3.5) * dx;
				yc2 = yc + (1.5 - r2) * dy;
				plot(ax, xc, yc2, 'o', 'MarkerSize', 2.4, 'MarkerFaceColor', R.color, ...
					'MarkerEdgeColor', R.color * 0.7, 'LineWidth', 0.3);
			end
		end
	else
		iBox(ax, xEns, yB, wBox, hBox, [0.72 0.72 0.72], [0.99 0.99 0.99], '--');
		text(ax, xEns + wBox/2, yc, 'no ensemble', 'HorizontalAlignment', 'center', ...
			'VerticalAlignment', 'middle', 'FontSize', 5, 'Color', [0.5 0.5 0.5]);
	end

	% --- 复用箭头（粗细编码复用强弱）---
	lw2 = 1.5;
	if iR == 3, lw2 = 0.6; end
	if iR == 1, lw2 = 0.4; end
	iArrow(ax, xEns + wBox + 0.008, xTaskB - 0.008, yc, lw2, [0.35 0.35 0.35], iR == 1, figAR);
	if ~isempty(R.reuse)
		text(ax, 0.5875, yc + 0.048, R.reuse, 'HorizontalAlignment', 'center', ...
			'VerticalAlignment', 'bottom', 'FontSize', 5, 'Color', R.color * 0.8, 'FontWeight', 'bold');
	end

	% --- Task B ---
	iBox(ax, xTaskB, yB, wBox, hBox, gEdge, [0.975 0.975 0.975], '-');
	text(ax, xTaskB + wBox/2, yc, 'light \rightarrow water', 'HorizontalAlignment', 'center', ...
		'VerticalAlignment', 'middle', 'FontSize', 5, 'Color', gText);

	% --- 首 block 命中率柱 ---
	yb = yc + yBase;
	hBar = barScale * R.bar;
	rectangle(ax, 'Position', [xBar, yb, wBar, hBar], 'FaceColor', R.color, 'EdgeColor', 'none');
	text(ax, xBar + wBar/2, yb + hBar + 0.016, sprintf('%.2f', R.bar), ...
		'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
		'FontSize', 5, 'Color', gText);
	plot(ax, [xBar - 0.035, xBar + wBar + 0.035], [yb yb], '-', 'Color', gEdge, 'LineWidth', 0.5);
end

% 结论行
text(ax, 0.5, 0.030, 'Temporal continuity preserves MOp ensemble reuse and speeds up the new task', ...
	'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
	'FontSize', 5.5, 'FontAngle', 'italic', 'Color', [0.2 0.2 0.2]);

TransferLearning.Style.ApplyStandardFigureStyle(f, 1);
svgPath = TransferLearning.StandardFigureSvgPath('English_Fig_Summary.svg');
print(f, svgPath, '-dsvg');
fprintf('Wrote: %s\n', svgPath);

%% ========== local ==========
function iBox(ax, x, y, w, h, edgeC, fillC, ls)
rectangle(ax, 'Position', [x, y, w, h], 'Curvature', 0.16, 'EdgeColor', edgeC, ...
	'FaceColor', fillC, 'LineWidth', 0.5, 'LineStyle', ls);
end

function iArrow(ax, x1, x2, y, lw, col, dashed, ar)
% 手绘箭头：线 + 实心三角（annotation 的箭头头在这个尺寸下几乎不可见）
ls = '-';
if dashed, ls = '--'; end
hx = 0.015;
hy = hx * ar * 0.55;
xs = x2 - hx;
plot(ax, [x1 xs], [y y], 'LineStyle', ls, 'Color', col, 'LineWidth', lw);
patch(ax, [xs x2 xs], [y + hy y y - hy], col, 'EdgeColor', 'none');
end

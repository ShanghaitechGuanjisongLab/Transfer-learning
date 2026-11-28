% 英文图1K: Reactivation vs Transfer hit rate (layers merged)
%
% Reactivation = P(Transfer active | Learned active) at 1s
% Sessions (pure):
% - Learned AudioWater: last pure session
% - Transfer LightWater: first pure session
% Behavior: Transfer hit rate in the chosen Transfer session
%
% Execution:
%   TransferLearning.英文图1.L_ReactivationVsHitRate

% --- ensure project loaded
try
	if ~exist('UniExp.DataSet','class')
		thisFile = mfilename('fullpath');
		thisDir = fileparts(thisFile);
		prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
		if exist(prjFile,'file')
			try
				matlab.project.loadProject(prjFile);
			catch
			end
		end
	end
catch
end

R = iBuildProb_TransferGivenLearnedAudio_1s_PerMouseLayer();
if isempty(R)
	error('Fig1K:Empty', 'No valid mice for Reactivation.');
end

% 合并2/3和5层数据：按 learned-active 细胞数加权（= 两层细胞合并后重算 P(T|L)）
x23 = R.Prob23;
x5 = R.Prob5;
x = iPooledProb(R.NLearnedActive23, x23, R.NLearnedActive5, x5);
y = R.TransferHitRate;
mask = isfinite(x) & isfinite(y);
learnedActiveCells = R.NLearnedActive23 + R.NLearnedActive5;
nCells = sum(learnedActiveCells(mask), 'omitnan');
%% 


f = figure('Color','w', 'Name','English Fig1K Reactivation vs Hit rate');
f.Units = 'centimeters';
f.Position(3:4) = [3.0, 4.0]; % 30mm x 40mm
f.PaperUnits = 'centimeters';
f.PaperPositionMode = 'manual';
f.PaperPosition = [0, 0, 3, 4];
f.PaperSize = [3, 4];

ax = axes(f, 'Position', [0.225, 0.155, 0.705, 0.775]);
hold(ax,'on');

rho = NaN;
p = NaN;
if nnz(mask) >= 4 && std(x(mask)) > 0 && std(y(mask)) > 0
	[rho, p] = corr(x(mask), y(mask), 'type','Spearman');
end
fprintf('Spearman ρ = %.4f (n = %d)\n', rho, nnz(mask));

colData = TransferLearning.Color12h / 255;
colFit  = [0.62 0.62 0.62];      % 淡灰色拟合线

% ---- 散点（plot 圆点：避免 ScatterAxPadding 改写轴限）----
plot(ax, x(mask), y(mask), 'o', 'MarkerSize', 3.6, 'MarkerFaceColor', colData, ...
	'MarkerEdgeColor', 'none');

% ---- 线性拟合线（淡灰细线；不画置信带，显著性以 Spearman 为准）----
if nnz(mask) >= 3 && std(x(mask)) > 0
	pFit = polyfit(x(mask), y(mask), 1);
	xf = linspace(min(x(mask)), max(x(mask)), 60)';
	hFit = plot(ax, xf, polyval(pFit, xf), '-', 'Color', colFit, 'LineWidth', 0.5);
	setappdata(hFit, 'TransferLearningPreserveLineWidth', true);
end

% ---- 轴样式：L 形、朝外刻度、无上/右框 ----
ax.Box = 'off';
ax.LineWidth = 0.75;
ax.TickDir = 'out';
ax.TickLength = [0.025 0.025];
ax.FontSize = 6;
% 轴限留边：略低于 0 起始，散点不贴轴、原点两个 0 也不会挤在同一个角上
xPad = 0.06 * (max(x(mask)) - min(x(mask)));
xlim(ax, [min(x(mask)) - xPad, max(x(mask)) + xPad]);
ylim(ax, [-0.02, 1.00]);
xlabel(ax, 'reactivation');
ylabel(ax, 'hit rate');

% ---- 顶部彩色标题（对应 Fig3d 的 'CS period'）----
title(ax, 'transfer', 'Color', colData, 'FontWeight', 'bold', 'FontSize', 6);

% ---- 统计结果写在左上角 ----
if isfinite(p) && isfinite(rho)
	star = '';
	if p < 0.05, star = ' *'; end
	if p < 0.001
		labelStr = {sprintf('\\rho = %.2f%s', rho, star), 'p < 0.001'};
	else
		labelStr = {sprintf('\\rho = %.2f%s', rho, star), sprintf('p = %.3f', p)};
	end
	text(ax, 0.04, 0.96, labelStr, 'Units', 'normalized', 'FontSize', 6, ...
		'Color', [0.1 0.1 0.1], 'HorizontalAlignment', 'left', 'VerticalAlignment', 'top');
end

% Export

svgName = "English_Fig1K_ReactivationVsHitRate.svg";
try
	svgPath = TransferLearning.ExportStandardFigure(f, 1, svgName);
	fprintf('Wrote: %s\n', svgPath);
catch ME
	warning(ME.identifier, 'Export failed: %s', ME.message);
end

fprintf('\n=== English Fig1K Reactivation vs Hit rate ===\n');
fprintf('mice n = %d\n', nnz(mask));
fprintf('participating learned-active cells n = %d\n', nCells);
fprintf('Spearman rho = %.6g, p = %.6g\n', rho, p);

function p = iPooledProb(n23, p23, n5, p5)
%按 learned-active 细胞数加权合并 L2/3 与 L5 的 P(T|L)：
%   (n23*p23 + n5*p5) / (n23 + n5)，等价于把两层细胞合并成一池后重算。
%   缺失( NaN )的一层按 0 权重计；两层都缺失则返回 NaN。
n23 = double(n23(:));  n5 = double(n5(:));
n23(~isfinite(n23)) = 0;  n5(~isfinite(n5)) = 0;
w23 = n23 .* double(p23(:));  w23(~isfinite(w23)) = 0;
w5  = n5  .* double(p5(:));   w5(~isfinite(w5))  = 0;
nT = n23 + n5;
p = (w23 + w5) ./ nT;
p(nT == 0) = NaN;
end

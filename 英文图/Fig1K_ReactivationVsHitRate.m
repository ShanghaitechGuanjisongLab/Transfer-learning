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
		prjFile = fullfile(thisDir, '..', '..', 'Transferlearning.prj');
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
	error('Fig1L:Empty', 'No valid mice for Reactivation.');
end

% 合并2/3和5层数据：取各鼠每层的均值
x23 = R.Prob23;
x5 = R.Prob5;
x = nanmean([x23, x5], 2);
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

ax = axes(f);
hold(ax,'on');

rho = NaN;
p = NaN;
if nnz(mask) >= 4 && std(x(mask)) > 0 && std(y(mask)) > 0
	[rho, p] = corr(x(mask), y(mask), 'type','Spearman');
end
fprintf('Spearman ρ = %.4f (n = %d)\n', rho, nnz(mask));

% 散点：空心圆，边框0.2
scatterColor = TransferLearning.ContinualColor;
fitColor = TransferLearning.ContinualColor;
scatter(ax, x(mask), y(mask), 5, scatterColor);

% 拟合线：实线，打特殊标签供 ExportStandardFigure 减半宽度 & 淡化颜色
if nnz(mask) >= 2 && std(x(mask)) > 0
	pFit = polyfit(x(mask), y(mask), 1);
	xFit = [min(x(mask)) max(x(mask))];
	yFit = polyval(pFit, xFit);
	plot(ax, xFit, yFit, '-', 'Color', fitColor, 'Tag', 'TransferLearningSupplementalLine');
end
grid(ax,'off');
box(ax,'off');
xlabel(ax, '🔊 learned cells reactivation');
ylabel(ax, '💡💧 hit rate');

if isfinite(p) && isfinite(rho)
	if p < 0.001
		labelStr = sprintf('Spear. ρ = %.2f\np < 0.001', rho);
	else
		labelStr = sprintf('Spear. ρ = %.2f\np = %.3f', rho, p);
	end
	text(ax, 0.95, 0.05, labelStr, 'Units','normalized', ...
		'HorizontalAlignment','right', 'VerticalAlignment','bottom');
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

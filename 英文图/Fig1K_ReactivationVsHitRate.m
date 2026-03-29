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
try
	if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
		ax.Toolbar.Visible = 'off';
	end
catch
end
ax.LineWidth = 1;

p = NaN;
if nnz(mask) >= 4 && std(x(mask)) > 0 && std(y(mask)) > 0
	[~, p] = corr(x(mask), y(mask), 'type','Spearman');
end

% 散点：空心圆，边框0.2
palette2 = [1, 0, 0; 0, 0, 1];
scatter(ax, x(mask), y(mask), 5, palette2(2,:), 'LineWidth', 0.2);

% 拟合线：实线
if nnz(mask) >= 2 && std(x(mask)) > 0
	pFit = polyfit(x(mask), y(mask), 1);
	xFit = [min(x(mask)) max(x(mask))];
	yFit = polyval(pFit, xFit);
	plot(ax, xFit, yFit, '-', 'LineWidth', 1, 'Color', palette2(1,:));
end
grid(ax,'off');
box(ax,'off');
ax.FontSize = 6;
ax.FontName = 'Segoe UI Emoji';
xlabel(ax, 'Reactivation', 'FontSize', 6);
ylabel(ax, 'Hit rate', 'FontSize', 6);
title(ax, '💡💧', 'FontSize', 6, 'FontWeight', 'normal');

if isfinite(p)
	if p < 0.001
		pLabel = 'p < 0.001';
	elseif p < 0.01
		pLabel = sprintf('p = %.3f', p);
	else
		pLabel = sprintf('p = %.2f', p);
	end
	text(ax, 0.95, 0.95, pLabel, 'Units','normalized', ...
		'HorizontalAlignment','right', 'VerticalAlignment','top', 'FontSize', 6, 'FontWeight', 'bold');
end

% Export
try
outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
	if ~isfolder(outDirUNC)
		mkdir(outDirUNC);
	end
catch
end

svgName = "English_Fig1K_ReactivationVsHitRate.svg";
svgPath = fullfile(outDirUNC, svgName);
try
	print(f, svgPath, '-dsvg');
	fprintf('Wrote: %s\n', svgPath);
catch ME
	warning(ME.identifier, 'Export failed: %s', ME.message);
end

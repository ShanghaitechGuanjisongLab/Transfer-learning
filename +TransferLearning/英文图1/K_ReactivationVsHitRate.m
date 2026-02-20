% 英文图1K: Reactivation rate vs Transfer hit rate (layers merged)
%
% Reactivation rate = P(Transfer active | Learned active) at 1s
% Sessions (pure):
% - Learned AudioWater: last pure session
% - Transfer LightWater: first pure session
% Behavior: Transfer hit rate in the chosen Transfer session
%
% Execution:
%   TransferLearning.英文图1.L_ReactivationVsHitRate

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
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

R = TransferLearning.Fig37.iBuildProb_TransferGivenLearnedAudio_1s_PerMouseLayer();
if isempty(R)
	error('Fig1L:Empty', 'No valid mice for Reactivation rate.');
end

% 合并2/3和5层数据：取各鼠每层的均值
x23 = R.Prob23;
x5 = R.Prob5;
x = nanmean([x23, x5], 2);
y = R.TransferHitRate;
mask = isfinite(x) & isfinite(y);
%% 

svgName = "English_Fig1K_ReactivationVsHitRate.svg";

f = figure('Color','w', 'Name','English Fig1K Reactivation vs Hit rate');
f.Units = 'centimeters';
f.Position(3:4) = [3.0, 4.0]; % 30mm x 40mm

ax = axes(f);
hold(ax,'on');
try
	if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
		ax.Toolbar.Visible = 'off';
	end
catch
end

rho = NaN; p = NaN;
if nnz(mask) >= 4 && std(x(mask)) > 0 && std(y(mask)) > 0
	[rho, p] = corr(x(mask), y(mask), 'type','Spearman');
end

% 散点：空心圆，边框0.2
scatter(ax, x(mask), y(mask), 5, [0 0.4470 0.7410], 'LineWidth', 0.2);

% 拟合线：实线
if nnz(mask) >= 2 && std(x(mask)) > 0
	pFit = polyfit(x(mask), y(mask), 1);
	xFit = [min(x(mask)) max(x(mask))];
	yFit = polyval(pFit, xFit);
	plot(ax, xFit, yFit, '-', 'LineWidth', 1, 'Color', [0.85 0.325 0.098]);
end
grid(ax,'off');
box(ax,'off');
ax.FontSize = 6;
xlabel(ax, 'Reactivation rate', 'FontSize', 6);
ylabel(ax, 'Hit rate', 'FontSize', 6);

if isfinite(p)
	% Convert p to asterisk
	if p < 0.001
		pText = "***";
	elseif p < 0.01
		pText = "**";
	elseif p < 0.05
		pText = "*";
	else
		pText = "";
	end
	text(ax, 0.02, 0.98, sprintf('r=%.2f%s n=%d', rho, pText, nnz(mask)), 'Units','normalized', ...
		'HorizontalAlignment','left', 'VerticalAlignment','top', 'FontSize', 6);
end

% Export
try
	if ~isfolder(outDirUNC)
		mkdir(outDirUNC);
	end
catch
end

svgPath = fullfile(outDirUNC, svgName);
try
	TransferLearning.PrintFigure(f, svgPath);
	fprintf('Wrote: %s\n', svgPath);
catch ME
	warning(ME.identifier, 'Export failed: %s', ME.message);
end

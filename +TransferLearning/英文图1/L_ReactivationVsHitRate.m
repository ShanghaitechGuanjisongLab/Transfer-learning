% 英文图1L: Reactivation rate vs Transfer hit rate (split by layer)
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
svgName = "English_Fig1L_ReactivationVsHitRate.svg";

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

layerNames = string(["MOp2/3","MOp5"]);

f = figure('Color','w', 'Name','English Fig1L Reactivation vs Hit rate');
f.Units = 'centimeters';
f.Position(3:4) = [6.0, 4.5]; % 60mm x 45mm

TL = tiledlayout(1,2,'TileSpacing','compact','Padding','compact');
axesList = gobjects(numel(layerNames), 1);

for iZ = 1:numel(layerNames)
	zl = layerNames(iZ);
	ax = nexttile(TL, iZ);
	axesList(iZ) = ax;
	hold(ax,'on');
	try
		if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
			ax.Toolbar.Visible = 'off';
		end
	catch
	end

	if zl == "MOp2/3"
		x = R.Prob23;
	else
		x = R.Prob5;
	end
	y = R.TransferHitRate;
	mask = isfinite(x) & isfinite(y);

	rho = NaN; p = NaN;
	if nnz(mask) >= 4 && std(x(mask)) > 0 && std(y(mask)) > 0
		[rho, p] = corr(x(mask), y(mask), 'type','Spearman');
	end

	scatter(ax, x(mask), y(mask), 15, [0 0.4470 0.7410], 'filled');
	if nnz(mask) >= 2 && std(x(mask)) > 0
		pFit = polyfit(x(mask), y(mask), 1);
		xFit = [min(x(mask)) max(x(mask))];
		yFit = polyval(pFit, xFit);
		plot(ax, xFit, yFit, '-', 'LineWidth', 1, 'Color', [0.85 0.325 0.098]);
	end
	grid(ax,'on');
	box(ax,'off');
	title(ax, sprintf('%s n=%d', zl, nnz(mask)), 'FontSize', 6);
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
		text(ax, 0.02, 0.98, sprintf('r=%.2f%s', rho, pText), 'Units','normalized', ...
			'HorizontalAlignment','left', 'VerticalAlignment','top', 'FontSize', 6);
	end
	if iZ == 2
		try
			ax.YAxis.Visible = 'off';
		catch
			ax.YTickLabel = [];
		end
	end
end

% Unify axes limits
try
	MATLAB.Graphics.UnifyAxesLims(axesList, @xlim);
	MATLAB.Graphics.UnifyAxesLims(axesList, @ylim);
catch
end

xlabel(TL, 'Reactivation rate', 'FontSize', 6);
ylabel(TL, '💡💧 hit rate', 'FontSize', 6, 'FontName', 'Segoe UI Emoji');
title(TL, 'Reactivation vs behavior', 'FontSize', 6);

% Font size
for iA = 1:numel(axesList)
	axesList(iA).FontSize = 6;
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

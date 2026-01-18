% 图3.3c：0.3s（前馈）SD 与学习速率的关系（Naive vs Transfer，分 2/5 层）
%
% Implementation:
% - Use session-level table from:
%     TransferLearning.Scratch.SpeedVsSd2s_ByGroupLayerMissOnly(0.3)
% - Plot Spearman correlations for LearningSpeed_DeltaNext.
%
% Output:
% - SVG only to \\Data-Server-2\个人数据\张天夫\202601
%
% Execution:
%   TransferLearning.Fig33.C_SD0p3sVsLearningSpeed

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "Fig3_3c_SD0p3s_vs_LearningSpeed.svg";

% --- Ensure project loaded (for UniExp)
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

TransferLearning.Scratch.SpeedVsSd2s_ByGroupLayerMissOnly(0.3);
T = evalin('base', 'Scratch_SpeedVsSD0p3_Sessions');
if isempty(T)
	error('Fig3_3c:Empty', 'Scratch_SpeedVsSD0p3_Sessions is empty.');
end
T.Group = string(T.Group);

f = figure('Color','w', 'Name', 'Fig3.3c SD@0.3s vs learning speed');
try
	MATLAB.Graphics.FigureAspectRatio(10, 6, 1/2);
catch
end

tl = tiledlayout(f, 2, 2, 'TileSpacing','compact', 'Padding','compact');

axs = gobjects(2,2);

% Layout: rows = layer (MOp2/3, MOp5), cols = group (Naive, Transfer)
rowLayers = ["MOp2/3","MOp5"];
colGroups = ["Naive","Transfer"];
sdVars = containers.Map;
sdVars("MOp2/3") = "StdCells0p3_MOp23";
sdVars("MOp5")   = "StdCells0p3_MOp5";

for iR = 1:numel(rowLayers)
	for iC = 1:numel(colGroups)
		zl = rowLayers(iR);
		grp = colGroups(iC);
		ax = nexttile(tl, (iR-1)*2 + iC);
		axs(iR,iC) = ax;
		R = T(T.Group==grp, :);
		iScatter(ax, R.(sdVars(zl)), R.LearningSpeed_DeltaNext);
		if iR == 1
			title(ax, grp, 'Interpreter','none');
		end
		if iC == 1
			ylabel(ax, zl, 'Interpreter','none');
		else
			ax.YTickLabel = [];
			ax.YLabel.String = '';
		end
	end
end

% Hide top-row x axis
axs(1,1).XTickLabel = [];
axs(1,1).XLabel.String = '';
axs(1,2).XTickLabel = [];
axs(1,2).XLabel.String = '';

% Global x label (on tiledlayout)
xlabel(tl, 'Inter-cell SD @0.3s', 'Interpreter','none');

% Global y label (move from per-axes)
ylabel(tl, 'Learning speed (DeltaNext)', 'Interpreter','none');

% Unify X limits (all subplots)
iUnifyX(axs(:));

sgtitle(tl, '0.3s inter-cell SD vs learning speed (session-level)', 'Interpreter','none');

try
	if ~isfolder(outDirUNC)
		mkdir(outDirUNC);
	end
catch
end

svgPath = fullfile(outDirUNC, svgName);
try
	exportgraphics(f, svgPath, 'ContentType','vector');
	fprintf('Wrote: %s\n', svgPath);
catch ME
	warning(ME.identifier, 'Export failed: %s', ME.message);
end

%% --- helpers

function iScatter(ax, x, y)
	x = double(x);
	y = double(y);
	use = isfinite(x) & isfinite(y);

	hold(ax,'on');
	box(ax,'off');
	grid(ax,'on');
	try
		if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
			ax.Toolbar.Visible = 'off';
		end
	catch
	end

	scatter(ax, x(use), y(use), 26, 'filled', 'MarkerFaceAlpha', 0.75);

	% Fit line segment (linear)
	if nnz(use) >= 2 && std(x(use),'omitnan') > 0
		b = polyfit(x(use), y(use), 1);
		xLine = [min(x(use)), max(x(use))];
		yLine = polyval(b, xLine);
		plot(ax, xLine, yLine, 'k-', 'LineWidth', 1);
	end

	[rho, p] = iSpearman(x(use), y(use));
	subtitle(ax, sprintf('\\rho=%.2f, p=%.3g', rho, p), 'Interpreter','tex');
end

function iUnifyX(axs)
	try
		MATLAB.Graphics.UnifyAxesLims(axs, 'x');
		return;
	catch
	end
	try
		xl = nan(numel(axs),2);
		for i = 1:numel(axs)
			xl(i,:) = xlim(axs(i));
		end
		xl = [min(xl(:,1),[],'omitnan') max(xl(:,2),[],'omitnan')];
		for i = 1:numel(axs)
			xlim(axs(i), xl);
		end
	catch
	end
end

function [rho, p] = iSpearman(x, y)
	rho = NaN; p = NaN;
	if numel(x) < 4 || numel(y) < 4
		return;
	end
	if std(x,'omitnan') <= 0 || std(y,'omitnan') <= 0
		return;
	end
	try
		[rho, p] = corr(double(x(:)), double(y(:)), 'Type','Spearman', 'Rows','complete');
	catch
	end
end

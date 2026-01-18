% 图3.3d：1.5s（反馈）SD 与学习速率的关系（Naive vs Transfer，分 2/5 层）
%
% Implementation:
% - Use session-level table from:
%     TransferLearning.Scratch.SpeedVsSd2s_ByGroupLayerMissOnly(1.5)
% - Plot Spearman correlations for LearningSpeed_DeltaNext.
%
% Output:
% - SVG only to \\Data-Server-2\个人数据\张天夫\202601
%
% Execution:
%   TransferLearning.Fig33.D_SD1p5sVsLearningSpeed

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "Fig3_3d_SD1p5s_vs_LearningSpeed.svg";

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

TransferLearning.Scratch.SpeedVsSd2s_ByGroupLayerMissOnly(1.5);
T = evalin('base', 'Scratch_SpeedVsSD1p5_Sessions');
if isempty(T)
	error('Fig3_3d:Empty', 'Scratch_SpeedVsSD1p5_Sessions is empty.');
end
T.Group = string(T.Group);

f = figure('Color','w', 'Name', 'Fig3.3d SD@1.5s vs learning speed');
try
	MATLAB.Graphics.FigureAspectRatio(10, 6, 1/2);
catch
end

tl = tiledlayout(f, 2, 2, 'TileSpacing','compact', 'Padding','compact');

spec = {
	struct('Group',"Naive",   'ZLayer',"MOp2/3", 'XVar',"StdCells1p5_MOp23")
	struct('Group',"Naive",   'ZLayer',"MOp5",   'XVar',"StdCells1p5_MOp5")
	struct('Group',"Transfer",'ZLayer',"MOp2/3", 'XVar',"StdCells1p5_MOp23")
	struct('Group',"Transfer",'ZLayer',"MOp5",   'XVar',"StdCells1p5_MOp5")
};

for i = 1:numel(spec)
	s = spec{i};
	ax = nexttile(tl, i);
	R = T(T.Group==s.Group, :);
	iScatter(ax, R.(s.XVar), R.LearningSpeed_DeltaNext, sprintf('%s | %s', s.Group, s.ZLayer));
	xlabel(ax, sprintf('Inter-cell SD @1.5s (%s)', s.ZLayer));
	ylabel(ax, 'Learning speed (DeltaNext)');
end

sgtitle(tl, '1.5s inter-cell SD vs learning speed (session-level)', 'Interpreter','none');

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

function iScatter(ax, x, y, ttl)
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
	[rho, p] = iSpearman(x(use), y(use));
	title(ax, sprintf('%s\nSpearman \rho=%.2f, p=%.3g, n=%d', ttl, rho, p, nnz(use)), 'Interpreter','none');
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

% 图3.4g：迁移光水会话中 Corr(LW_session, AW_learned) 与 Corr(LW_session, LW_final) 的相关
%
% 实现：
% - 直接复用 Fig37 脚本 K_TransferLW_CorrToAWLearned_vs_CorrToLWFinal 生成 BySess/Summary。
% - 在此基础上作图（每会话一点；按层 MOp23/MOp5 分面）。
%
% Output:
% - SVG (UNC only)
%
% Execution:
%   TransferLearning.Fig34.G_CorrOfCorrs_TransferLW_AWLearned_vs_LWFinal_SessionLevel

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
targetAtSec = 1.5;
subtractAtSec = NaN;
onlyFirstLWPerMouse = false; % Fig3.4g：会话为单位

svgName = "Fig3_4g_CorrOfCorrs_TransferLW_AWLearned_vs_LWFinal_1p5s.svg";

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

% Run Fig37 builder-based extractor (this defines BySess & Summary in this workspace).
exportCSV = false; %#ok<NASGU> % consumed by Fig37.K_TransferLW_CorrToAWLearned_vs_CorrToLWFinal
TransferLearning.Fig37.K_TransferLW_CorrToAWLearned_vs_CorrToLWFinal

if ~exist('BySess','var') || isempty(BySess)
	error('Fig3_4g:NoBySess', 'Expected BySess from Fig37.K_TransferLW_CorrToAWLearned_vs_CorrToLWFinal.');
end

% --- Plot
f = figure('Color','w', 'Name', 'Fig3.4g Corr-of-corrs');
try
	MATLAB.Graphics.FigureAspectRatio(1, 1, 2/3);
catch
end

tl = tiledlayout(f, 1, 2, 'TileSpacing','compact', 'Padding','compact');

axs = gobjects(1,2);

zKeys = ["MOp23","MOp5"];
zLabels = ["MOp2/3","MOp5"];
for iZ = 1:numel(zKeys)
	zKey = zKeys(iZ);
	ax = nexttile(tl, iZ);
	axs(iZ) = ax;
	box(ax,'off'); grid(ax,'on'); hold(ax,'on');

	T = BySess(BySess.ZKey == zKey, :);
	x = double(T.CorrToAWLearned);
	y = double(T.CorrToLWFinal);
	use = isfinite(x) & isfinite(y);

	scatter(ax, x(use), y(use), 20, 'filled', 'MarkerFaceAlpha', 0.7);

	% Fit line
	if nnz(use) >= 2 && std(x(use),'omitnan') > 0
		b = polyfit(x(use), y(use), 1);
		xLine = [min(x(use)), max(x(use))];
		yLine = polyval(b, xLine);
		plot(ax, xLine, yLine, 'k-', 'LineWidth', 1);
	end

	[rho, p, n] = iSpearman(x, y);
	title(ax, zLabels(iZ), 'Interpreter','none');
	subtitle(ax, sprintf('n=%d, \\rho=%.2f, p=%.3g', n, rho, p), 'Interpreter','tex');
end

% Y label on tiledlayout; unify y limits; hide right-panel Y axis.
ylabel(tl, sprintf('Corr to final @%.1fs', double(targetAtSec)), 'Interpreter','none');
try
	MATLAB.Graphics.UnifyAxesLims(axs, 'y');
catch
end
try
	for iAx = 1:numel(axs)
		axs(iAx).YGrid = 'off';
		axs(iAx).YMinorGrid = 'off';
	end
catch
end
try
	axs(2).YTickLabel = [];
	axs(2).YLabel.String = '';
	axs(2).YTick = [];
catch
end

sgtitle(tl, 'Transfer: corr-of-corrs', 'Interpreter','none');

xlabel(tl, sprintf('Corr to learned @%.1fs', double(targetAtSec)), 'Interpreter','none');

% --- Export
try
	if ~isfolder(outDirUNC)
		mkdir(outDirUNC);
	end
catch
end

try
	svgPath = fullfile(outDirUNC, svgName);
	TransferLearning.PrintFigure(f, string(svgPath));
	fprintf('Wrote: %s\n', svgPath);
catch ME
	warning(ME.identifier, 'Export failed: %s', ME.message);
end

%% --- local helpers

function [rho, p, n] = iSpearman(x, y)
	rho = NaN;
	p = NaN;
	x = double(x(:));
	y = double(y(:));
	use = isfinite(x) & isfinite(y);
	n = nnz(use);
	if n < 5
		return;
	end
	try
		[rho, p] = corr(x(use), y(use), 'Type','Spearman');
	catch
		rho = NaN;
		p = NaN;
	end
end

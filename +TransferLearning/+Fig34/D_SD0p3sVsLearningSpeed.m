% 图3.4d：迁移光水相邻会话对中，ΔHit vs Corr(prev session, Final)@1.5s（控 Hit1）
%
% 要求：
% - 复用 Fig3.7K(Fig37K) 的相邻会话对与 100% cutoff 口径。
% - 仅使用 Transfer LightWater 相邻会话对（排除 100% 及以后）。
% - 指标：Corr(prev A, correct Final)@targetAtSec（= Fig37K SignalCorr in PrevA mode）。
% - 统计：Spearman 以及 partial Spearman（控制 Hit1）。
%
% Output:
% - SVG + CSV (UNC only)
%
% Execution:
%   TransferLearning.Fig34.D_SD0p3sVsLearningSpeed

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
targetAtSec = 1.5;

svgName = "Fig3_4d_Transfer_DeltaHit_vs_CorrPrevVsFinal_1p5s_CtrlHit1.svg";
csvPairsName = "Fig3_4d_Transfer_DeltaHit_vs_CorrPrevVsFinal_1p5s_Pairs.csv";
csvSummaryName = "Fig3_4d_Transfer_DeltaHit_vs_CorrPrevVsFinal_1p5s_Summary.csv";

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

% Build adjacent-session pairs using Fig37 builder (PrevA mode means Corr(prev, correct)).
actualSignalMode = "PrevA";
excludeZeroHit = false;
subtractAtSec = NaN;
	[pairs, ~] = TransferLearning.Fig37.iBuildAdjPairs_DeltaHit_vs_TrainSignalMatchMetrics_ByLayer(...
	'TargetAtSec', double(targetAtSec), 'ActualSignalMode', actualSignalMode, 'ExcludeZeroHit', logical(excludeZeroHit), 'SubtractAtSec', double(subtractAtSec)); %#ok<ASGLU>
if isempty(pairs)
	error('Fig3_4d:Empty', 'No valid adjacent session pairs from Fig37 builder.');
end

P = pairs(pairs.Stage == "Transfer", :);
if isempty(P)
	error('Fig3_4d:EmptyTransfer', 'No Transfer-stage pairs available.');
end

% Plot: per layer (MOp23/MOp5)
f = figure('Color','w', 'Name', 'Fig3.4d Transfer: DeltaHit vs Corr(prev, Final) @1.5s');
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
	R = P(P.ZKey == zKey, :);
	iScatter(ax, double(R.SignalCorr), double(R.DeltaHit), double(R.Hit1));
	title(ax, zLabels(iZ), 'Interpreter','none');
end

% Hide right-panel Y axis
try
	axs(2).YTickLabel = [];
	axs(2).YLabel.String = '';
	axs(2).YTick = [];
catch
end

xlabel(tl, sprintf('Corr(prev session, Final) @%.1fs', double(targetAtSec)), 'Interpreter','none');
ylabel(tl, 'Learning increment (\DeltaHit)', 'Interpreter','tex');

try
	MATLAB.Graphics.UnifyAxesLims(axs, 'x');
catch
	try
		xl = arrayfun(@(a) xlim(a), axs, 'UniformOutput', false);
		xl = vertcat(xl{:});
		xl = [min(xl(:,1),[],'omitnan') max(xl(:,2),[],'omitnan')];
		for i = 1:numel(axs)
			xlim(axs(i), xl);
		end
	catch
	end
end

sgtitle(tl, 'Transfer: \DeltaHit vs corr(prev, final)', 'Interpreter','tex');

try
	if ~isfolder(outDirUNC)
		mkdir(outDirUNC);
	end
catch
end

% Export SVG
svgPath = fullfile(outDirUNC, svgName);
try
	TransferLearning.PrintFigure(f, string(svgPath));
	fprintf('Wrote: %s\n', svgPath);
catch ME
	warning(ME.identifier, 'Export failed: %s', ME.message);
end

% NOTE: CSV export disabled by request.

%% --- helpers


function iScatter(ax, x, y, hit1)
	x = double(x);
	y = double(y);
	hit1 = double(hit1);
	use = isfinite(x) & isfinite(y);
	setappdata(ax, 'HasFiniteXY', nnz(use) > 0);

	hold(ax,'on');
	box(ax,'off');
	grid(ax,'on');
	try
		ax.YGrid = 'off';
		ax.YMinorGrid = 'off';
	catch
	end
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

	[~, ~, ~] = iSpearman(x, y);
	[rhoC, pC, ~] = iPartialSpearmanCtrl(x, y, hit1);
	subtitle(ax, sprintf('\\rho=%.2f, p=%.3g', rhoC, pC), 'Interpreter','tex');
end


function Summary = iSummarize(P)
	Summary = table(string.empty(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), ...
		'VariableNames', {'ZKey','N','Rho','P','NCtrlHit1','RhoCtrlHit1','PCtrlHit1'});
	for zKey = ["MOp23","MOp5"]
		T = P(P.ZKey == zKey, :);
		x = double(T.SignalCorr);
		y = double(T.DeltaHit);
		z = double(T.Hit1);
		[rho, p, n] = iSpearman(x, y);
		[rhoC, pC, nC] = iPartialSpearmanCtrl(x, y, z);
		Summary = [Summary; table(string(zKey), double(n), double(rho), double(p), double(nC), double(rhoC), double(pC), ...
			'VariableNames', Summary.Properties.VariableNames)]; %#ok<AGROW>
	end
end

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

function [rho, p, n] = iPartialSpearmanCtrl(x, y, z)
	% Partial Spearman correlation controlling for z (Hit1).
	% Implemented as: rank-transform then correlate residuals after regressing
	% out rank(z) from rank(x) and rank(y).
	rho = NaN;
	p = NaN;
	x = double(x(:));
	y = double(y(:));
	z = double(z(:));
	use = isfinite(x) & isfinite(y) & isfinite(z);
	n = nnz(use);
	if n < 5
		return;
	end
	try
		rx = tiedrank(x(use));
		ry = tiedrank(y(use));
		rz = tiedrank(z(use));
		X = [ones(n,1), rz];
		bx = X \ rx;
		by = X \ ry;
		ex = rx - X*bx;
		ey = ry - X*by;
		[rho, p] = corr(ex, ey, 'Type','Pearson');
	catch
		rho = NaN;
		p = NaN;
	end
end

function outPath = iWriteTableWithRetry(T, outDir, fileName)
	maxTry = 10;
	lastME = [];
	outPath = fullfile(outDir, fileName);
	for k = 1:maxTry
		[p, n, e] = fileparts(outPath);
		if strlength(e) == 0
			e = ".csv";
		end
		tmpPath = fullfile(p, n + ".tmp_" + string(feature('getpid')) + "_" + string(datetime('now','Format','yyyyMMdd_HHmmssSSS')) + e);
		try
			writetable(T, tmpPath);
			try
				movefile(tmpPath, outPath, 'f');
			catch ME2
				% Likely target file is open/locked on UNC. Keep temp.
				warning(ME2.identifier, 'Cannot overwrite %s (locked?). Kept temp: %s', outPath, tmpPath);
				outPath = tmpPath;
				return;
			end
			return;
		catch ME
			lastME = ME;
			try
				if exist(tmpPath, 'file')
					delete(tmpPath);
				end
			catch
			end
			pause(0.5 * k);
		end
	end
	throw(lastME);
end

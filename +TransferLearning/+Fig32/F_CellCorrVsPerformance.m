
function F_CellCorrVsPerformance
% 图3.2f（按论文大纲口径）：相关性与 Performance 显著相关（分 N/T 和 2/5 层）
%
% 4 子图：
% - Naive × (MOp2/3, MOp5)
% - Transfer × (MOp2/3, MOp5)
%
% 数据来源（scratch 输出）：
% - Scratch_CellCorr1s1p5_VsPerformance_Sessions
%
% Output:
% - SVG only to \\Data-Server-2\个人数据\张天夫\202601
%
% Execution:
%   TransferLearning.Fig32.F_CellCorrVsPerformance

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "Fig3_2f_CellCorr1s1p5_vsPerformance_4panels.svg";

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

% --- Ensure scratch exists
try
	TransferLearning.Scratch.NaiveTransfer_CellCorr_1s_1p5s_VsPerformance;
catch
end

if evalin('base', "exist('Scratch_CellCorr1s1p5_VsPerformance_Sessions','var')") ~= 1
	error('Fig3_2f_CellCorrPerf:Missing', 'Missing base var Scratch_CellCorr1s1p5_VsPerformance_Sessions.');
end

rows = evalin('base','Scratch_CellCorr1s1p5_VsPerformance_Sessions');
rows.Group = string(rows.Group);
rows.ZLayer = string(rows.ZLayer);

layerNames = string(["MOp2/3","MOp5"]);

f = figure('Color','w', 'Name','Fig3.2f CellCorr vs Performance');
try
	MATLAB.Graphics.FigureAspectRatio(8,6,1/2);
catch
end
TL = tiledlayout(2,2,'TileSpacing','compact','Padding','compact');

groups = string(["Naive","Transfer"]);

ax1 = nexttile(TL,1); hold(ax1,'on'); iHideToolbar(ax1);
iPanel_One(ax1, rows, groups(1), layerNames(1));

title(ax1, layerNames(1));
ax1.XAxis.Visible = 'off';
ax1.YLabel.String = 'Naive';

ax2 = nexttile(TL,2); hold(ax2,'on'); iHideToolbar(ax2);
iPanel_One(ax2, rows, groups(1), layerNames(2));

title(ax2, layerNames(2));
ax2.XAxis.Visible = 'off';
ax2.YAxis.Visible = 'off';

ax3 = nexttile(TL,3); hold(ax3,'on'); iHideToolbar(ax3);
iPanel_One(ax3, rows, groups(2), layerNames(1));

title(ax3, '');
ax3.YLabel.String = 'Transfer';

ax4 = nexttile(TL,4); hold(ax4,'on'); iHideToolbar(ax4);
iPanel_One(ax4, rows, groups(2), layerNames(2));

title(ax4, '');
ax4.YAxis.Visible = 'off';

% Global labels on tiledlayout
xlabel(TL,'Performance');
ylabel(TL,'CellCorr(1s,1.5s)');

try
	sgtitle(TL, '', 'Interpreter','none');
catch
end

% Unify ranges
try
	MATLAB.Graphics.UnifyAxesLims([ax1 ax2 ax3 ax4], @xlim);
	MATLAB.Graphics.UnifyAxesLims([ax1 ax2 ax3 ax4], @ylim);
catch
end

% Export (SVG only)
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

%% --- local helpers

function iPanel_One(ax, rows, groupName, zLayer)
	R = rows(rows.Group==string(groupName) & rows.ZLayer==string(zLayer), :);
	x = double(R.Performance);
	y = double(R.CellCorr_1s1p5s);
	use = isfinite(x) & isfinite(y);

	xlabel(ax,'');
	ylabel(ax,'');
	grid(ax,'on'); box(ax,'on');

	if nnz(use) == 0
		return;
	end
	scatter(ax, x(use), y(use), 26, 'filled');

	try
		if nnz(use) >= 4 && std(x(use))>0 && std(y(use))>0
			[X2, Y2] = TransferLearning.PolyFitLine(x(use), y(use));
			plot(ax, X2, Y2, 'k-', 'LineWidth', 2);
		end
	catch
	end

	rho = NaN; p = NaN;
	if nnz(use) >= 4 && std(x(use))>0 && std(y(use))>0
		[rho, p] = corr(x(use), y(use), 'type','Spearman');
	end
	fprintf('Fig3.2f %s %s: Spearman rho=%.3f p=%.4g (n=%d)\n', groupName, zLayer, rho, p, nnz(use));
end

function iHideToolbar(ax)
	try
		set(ax.Toolbar, 'Visible', 'off');
	catch
	end
end

end

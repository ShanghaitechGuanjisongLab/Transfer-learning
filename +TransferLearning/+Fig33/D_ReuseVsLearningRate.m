% Fig3.2e（按论文大纲口径）：复用提高 1s/1.5s 相关性（4 panels）
%
% Panels:
%  1) Naive vs Transfer 的 CellCorr(1s,1.5s)，MOp2/3
%  2) Naive vs Transfer 的 CellCorr(1s,1.5s)，MOp5
%  3) Transfer 内 Reuse(1s) vs CellCorr(1s,1.5s)，MOp2/3
%  4) Transfer 内 Reuse(1s) vs CellCorr(1s,1.5s)，MOp5
%
% 排版要求（2026-01-17）：
% - 1/2 图用 MATLAB.Graphics.PLine 画 p 值线
% - 1/2 图标题只写层名 MOp2/3 | MOp5
% - 3/4 图标题去掉；加拟合线段
% - 1/3 图 ylabel 写 Naive vs Transfer | Reuse vs CellCorr；2/4 图 ylabel 去掉
% - 所有子图 box off
%
% Data sources (non-Scratch builders):
% - TransferLearning.Fig33.iBuildNVST_CellCorr_Sessions_1s_1p5s_ByLayer
% - TransferLearning.Fig33.iBuildTransfer_ReuseVsCellCorr_PerMouseLayer_1s_1p5s
%
% Output:
% - SVG only to \\Data-Server-2\个人数据\张天夫\202601
%
% Execution:
%   TransferLearning.Fig32.E_ReuseVsLearningRate

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";

% --- Ensure project loaded
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

% --- Build required tables (non-Scratch)
rowsNVST = TransferLearning.Fig33.iBuildNVST_CellCorr_Sessions_1s_1p5s_ByLayer();
rowsNVST.Group = string(rowsNVST.Group);
rowsNVST.ZLayer = string(rowsNVST.ZLayer);

rowsTR = TransferLearning.Fig33.iBuildTransfer_ReuseVsCellCorr_PerMouseLayer_1s_1p5s();
rowsTR.ZLayer = string(rowsTR.ZLayer);

layerNames = string(["MOp2/3","MOp5"]);
%% 

svgName = "Fig3_3d_CellCorr1s1p5_ReusedPrediction_4panels.svg";
f = figure('Color','w', 'Name','Fig3.2e CellCorr+Reuse');
try
	MATLAB.Graphics.FigureAspectRatio(8,5,1/2);
catch
end
TL = tiledlayout(2,2,'TileSpacing','compact','Padding','compact');

ax1 = nexttile(TL,1); hold(ax1,'on'); iHideToolbar(ax1);
[yN23, yT23, pNVST23] = iPanel_NVST_OneLayer(ax1, rowsNVST, layerNames(1));

ax2 = nexttile(TL,2); hold(ax2,'on'); iHideToolbar(ax2);
[yN5, yT5, pNVST5] = iPanel_NVST_OneLayer(ax2, rowsNVST, layerNames(2));

ax3 = nexttile(TL,3); hold(ax3,'on'); iHideToolbar(ax3);
[rho23, p23] = iPanel_ReuseVsCellCorr_OneLayer(ax3, rowsTR, layerNames(1));

ax4 = nexttile(TL,4); hold(ax4,'on'); iHideToolbar(ax4);
[rho5, p5] = iPanel_ReuseVsCellCorr_OneLayer(ax4, rowsTR, layerNames(2));

% Titles
try
	title(ax1, layerNames(1));
catch
end
try
	subtitle(ax1, '');
catch
end
try
	title(ax2, layerNames(2));
catch
end
try
	subtitle(ax2, '');
catch
end
try
	title(ax3, '');
catch
end
try
	subtitle(ax3, '');
catch
end
try
	title(ax4, '');
catch
end
try
	subtitle(ax4, '');
catch
end

% small titles (rho/p) for panels 3/4
try
	if isfinite(rho23) && isfinite(p23)
		subtitle(ax3, sprintf('\\rho=%.2f, p=%.2g', rho23, p23));
	end
catch
end
try
	if isfinite(rho5) && isfinite(p5)
		subtitle(ax4, sprintf('\\rho=%.2f, p=%.2g', rho5, p5));
	end
catch
end

% ylabels per panel
ax1.YLabel.String = 'Naive vs Transfer';
ax3.YLabel.String = 'Reuse vs CellCorr';
ax2.YLabel.String = '';
ax4.YLabel.String = '';

% hide right y axes
ax2.YAxis.Visible = 'off';
ax4.YAxis.Visible = 'off';

% global metric labels
xlabel(TL, 'Reuse(1s)');
ylabel(TL, 'CellCorr(1s,1.5s)');

% Draw p-value lines for panels 1/2 AFTER layout is built (panels 3/4 done),
% but BEFORE UnifyAxesLims because PLine will force ylim mode to 'auto'.
try
	iPValuePLineScatter(ax1, 1, 2, yN23, yT23, pNVST23);
catch
end
try
	iPValuePLineScatter(ax2, 1, 2, yN5, yT5, pNVST5);
catch
end

% unify Y limits within rows only (panels 3/4 should NOT follow 1/2)
try
	MATLAB.Graphics.UnifyAxesLims([ax1 ax2], @ylim);
catch
end
try
	MATLAB.Graphics.UnifyAxesLims([ax3 ax4], @ylim);
catch
end

% Export SVG
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

function [yN, yT, p] = iPanel_NVST_OneLayer(ax, rowsNVST, zLayer)
	R = rowsNVST(rowsNVST.ZLayer==string(zLayer), :);
	yN = double(R.CellCorr_1s1p5s(R.Group=="Naive"));
	yT = double(R.CellCorr_1s1p5s(R.Group=="Transfer"));
	yN = yN(isfinite(yN));
	yT = yT(isfinite(yT));

	swarmchart(ax, ones(numel(yN),1), yN, 22, 'filled');
	swarmchart(ax, 2*ones(numel(yT),1), yT, 22, 'filled');
	ax.XLim = [0.5 2.5];
	ax.XTick = [1 2];
	ax.XTickLabel = {sprintf('Naive (n=%d)', numel(yN)), sprintf('Transfer (n=%d)', numel(yT))};
	grid(ax,'on'); box(ax,'off');

	p = iRanksum(yN, yT);
	fprintf('Fig3.2e NVST %s: ranksum p=%.4g (nN=%d,nT=%d)\n', zLayer, p, numel(yN), numel(yT));
end

function [rho, p] = iPanel_ReuseVsCellCorr_OneLayer(ax, rowsTR, zLayer)
	R = rowsTR(rowsTR.ZLayer==string(zLayer), :);
	x = double(R.Reuse);
	y = double(R.CellCorr_1s1p5s);
	use = isfinite(x) & isfinite(y);

	scatter(ax, x(use), y(use), 26, 'filled');
	grid(ax,'on'); box(ax,'off');

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
	fprintf('Fig3.2e ReuseVsCellCorr %s: Spearman rho=%.3f p=%.4g (n=%d)\n', zLayer, rho, p, nnz(use));
end

function p = iRanksum(x, y)
	x = double(x(:));
	y = double(y(:));
	x = x(isfinite(x));
	y = y(isfinite(y));
	if isempty(x) || isempty(y)
		p = NaN;
		return;
	end
	try
		p = ranksum(x, y);
	catch
		p = NaN;
	end
end

function [Lines, Texts] = iPValuePLineScatter(ax, x1, x2, y1, y2, p, extraOffset)
	Lines = matlab.graphics.primitive.Line.empty(0,1);
	Texts = matlab.graphics.primitive.Text.empty(0,1);
	if nargin < 7 || isempty(extraOffset)
		extraOffset = 0;
	end
	if ~isfinite(p)
		return;
	end
	y1 = y1(:);
	y2 = y2(:);
	y1 = y1(isfinite(y1));
	y2 = y2(isfinite(y2));
	if isempty(y1) || isempty(y2)
		return;
	end

	X = [x1*ones(numel(y1),1); x2*ones(numel(y2),1)];
	Y = [y1; y2];
	S = scatter(ax, X, Y, 1, 'k', 'filled', 'Visible','off', 'HandleVisibility','off');
	try
		if isprop(S, 'HitTest'); S.HitTest = 'off'; end
		if isprop(S, 'PickableParts'); S.PickableParts = 'none'; end
		if isprop(S, 'AffectAutoLimits'); S.AffectAutoLimits = false; end
	catch
	end

	Descriptors = table(S, 0, 0, "p=" + sprintf('%.3g', p), extraOffset, ...
		'VariableNames', {'ObjectA','IndexA','IndexB','Text','ExtraOffset'});
	try
		[Lines, Texts] = MATLAB.Graphics.PLine(Descriptors);
	catch
	end

	try
		delete(S);
	catch
	end
end

function iHideToolbar(ax)
	try
		if isprop(ax,'Toolbar') && ~isempty(ax.Toolbar)
			ax.Toolbar.Visible = 'off';
		end
	catch
	end
end


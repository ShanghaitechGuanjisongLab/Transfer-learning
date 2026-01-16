% 图3.2d（新版）：Naive vs Transfer 的全细胞标准差/曲线/行为/相关性
%
% 数据要求（硬性）：
% - 一律使用 QueryNTATS(..., UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median)
% - 取每个细胞的“trial median”时间序列后再做跨细胞统计
%
% 子图（4 panels）：
% 1) Naive vs Transfer：全细胞平均钙曲线（每鼠先对细胞取均值，再跨鼠均值±SEM），用 MATLAB.Graphics.MultiShadowedLines
% 2) 1s 处跨细胞标准差：Naive / Transfer / Transfer-NonReuse（从 Transfer 中扣除 Learned 复用细胞）
%    - 统计：ranksum(Naive vs Transfer)；signrank(Transfer vs NonReuse，同鼠配对)
%    - 绘图：Naive swarmchart；Transfer 与 NonReuse 用 marker + 同鼠配对连线
% 3) Naive：Hit vs Miss 回合的全细胞 1s 标准差（同鼠配对）
% 4) Transfer：Performance vs 全细胞 1s 标准差 Spearman 相关
%
% 复用细胞定义（按你当前 Fig3.2 系列的一贯口径）：
% - 在同鼠 Learned(AudioWater) 的最后一次 session 中，细胞满足
%     max(0~1s) > mean(-3~0s) + 3*std(-3~0s)
%   则视为“Learned 复用细胞”（reuse）
% - Transfer-NonReuse = Transfer(全细胞) 中扣除这些 reuse 细胞
%
% Output:
% - SVG only to \\Data-Server-2\个人数据\张天夫\202601
%
% Execution（重要约束，请勿修改）：
% - 本文件必须是“脚本”（不得把文件本身改成 function 文件）。
% - 调用方式：在命令行直接输入包名执行，不得使用 run。
%     TransferLearning.Fig32.D_TransferVsNaive_Activity

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "Fig3_2d_TransferVsNaive_Activity.svg";
excludeMice = string([]);

% --- 0) Ensure project loaded (for UniExp)
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

% DataSets
LAB = TransferLearning.LightAudioBaseline();
LAI = TransferLearning.LAInterspersed();
ALB = TransferLearning.AudioLightBaseline();

% Time axis
xsSec = seconds(TransferLearning.Xs);
baseMask = (xsSec >= -3) & (xsSec < 0);
win01 = (xsSec >= 0) & (xsSec <= 1);
if ~any(baseMask) || ~any(win01)
	error('Fig3_2d:BadTimeMask', 'Baseline(-3~0) or window(0~1) has no samples.');
end
idx1 = find(xsSec == 1, 1, 'first');
if isempty(idx1)
	[~, idx1] = min(abs(xsSec - 1));
end

kSigma = 3;
minTrials = 1;

% --------------------
% 1) Naive cohort (merged imaging cohorts) with purity exclusion
excludeMice = string(excludeMice);
labPure = iFindPureNaiveLightWaterMice(LAB, excludeMice, "LightAudioBaseline");
laiPure = iFindPureNaiveLightWaterMice(LAI, excludeMice, "LAInterspersed");

naiveA = iFirstSessionAllCellsByMouse(LAB, "LightAudioBaseline", "Naive", "LightWater", labPure.Mouse, baseMask, minTrials, xsSec, idx1);
naiveB = iFirstSessionAllCellsByMouse(LAI, "LAInterspersed",     "Naive", "LightWater", laiPure.Mouse, baseMask, minTrials, xsSec, idx1);
naive = [naiveA; naiveB];
naive.Group(:) = "Naive";
iAssertNoDuplicateMiceAcrossSources(naive, "Naive");

% --------------------
% 2) Transfer cohort: first Transfer(LightWater) session per mouse
%    + NonReuse computed by removing reuse cells defined from LAST Learned(AudioWater) session
tran = iFirstTransferWithNonReuseByMouse(ALB, baseMask, win01, idx1, kSigma, minTrials, xsSec);
tran.Group(:) = "Transfer";

assignin('base','Fig3_2d_AllCells_Naive', naive);
assignin('base','Fig3_2d_AllCells_Transfer', tran);

% --------------------
% Stats for panel 2
pN_T = NaN;
try
	xN = naive.SdAt1s_All(isfinite(naive.SdAt1s_All));
	xT = tran.SdAt1s_All(isfinite(tran.SdAt1s_All));
	if numel(xN) >= 3 && numel(xT) >= 3
		pN_T = ranksum(xN, xT);
	end
catch
end

pT_NR = NaN;
nPairT = 0;
try
	maskPair = isfinite(tran.SdAt1s_All) & isfinite(tran.SdAt1s_NonReuse);
	nPairT = nnz(maskPair);
	if nPairT >= 4
		pT_NR = signrank(tran.SdAt1s_All(maskPair), tran.SdAt1s_NonReuse(maskPair));
	end
catch
end

fprintf('Fig3.2d Panel2 SD@1s: ranksum(N vs T) p=%.3g | signrank(T vs T-NonReuse) p=%.3g (paired n=%d)\n', pN_T, pT_NR, nPairT);

% --------------------
% 3) Naive Hit vs Miss (paired within mouse): SD@1s
naiveHM = iNaiveFirstSessionHitMissSdAt1s(LAB, LAI, naive, idx1, baseMask, minTrials, xsSec);
assignin('base','Fig3_2d_Naive_HitMiss_SDAt1s', naiveHM);

pHitMiss = NaN;
nPairHM = 0;
try
	mask = isfinite(naiveHM.SdAt1s_Hit) & isfinite(naiveHM.SdAt1s_Miss);
	nPairHM = nnz(mask);
	if nPairHM >= 4
		pHitMiss = signrank(naiveHM.SdAt1s_Hit(mask), naiveHM.SdAt1s_Miss(mask));
	end
catch
end
fprintf('Fig3.2d Panel3 Naive SD@1s Hit vs Miss: signrank p=%.3g (paired n=%d)\n', pHitMiss, nPairHM);

% --------------------
% 4) Transfer performance vs SD@1s (Spearman)
rho = NaN; pRho = NaN; nCorr = 0;
try
	mask = isfinite(tran.FirstPerformance) & isfinite(tran.SdAt1s_All);
	nCorr = nnz(mask);
	if nCorr >= 5
		[rho, pRho] = corr(tran.FirstPerformance(mask), tran.SdAt1s_All(mask), 'Type','Spearman', 'Rows','complete');
	end
catch
end
fprintf('Fig3.2d Panel4 Spearman(Perf vs SD@1s): rho=%.3g p=%.3g (n=%d)\n', rho, pRho, nCorr);
%% 

% --------------------
% Plot
f = figure('Color','w', 'Name','Fig3.2d (All-cells SD / curves / behavior / correlation)');
try
	MATLAB.Graphics.FigureAspectRatio(8,5,1/2);
catch
end

TL = tiledlayout(2,2,'TileSpacing','compact','Padding','compact');

% (1) Mean curves
ax1 = nexttile(TL, 1);
hold(ax1,'on');
try
	if isprop(ax1,'Toolbar') && ~isempty(ax1.Toolbar)
		ax1.Toolbar.Visible = 'off';
	end
catch
end

[mN, sN, nN] = iMeanSemAcrossMice(naive.MeanCurve_All, numel(xsSec));
[mT, sT, nT] = iMeanSemAcrossMice(tran.MeanCurve_All,  numel(xsSec));

MeanMat = [mN, mT];
SemMat  = [sN, sT];

try
	EdgeColors = GlobalOptimization.ColorAllocate(2, [1,1,1; 1,1,1]);
	P = MATLAB.Graphics.MultiShadowedLines(MeanMat, SemMat, X=xsSec(:), EdgeColors=EdgeColors(1:2,:));
catch
	P = MATLAB.Graphics.MultiShadowedLines(MeanMat, SemMat, X=xsSec(:));
end
legend(ax1, P(1:2), compose(["Naive (n=%d)";"Transfer (n=%d)"], [nN; nT]), 'Location','northwest');
xlabel(ax1,'Time (s)');
ylabel(ax1,'Z');
title(ax1,'All-cells mean Ca trace');
grid(ax1,'on');
box(ax1,'on');

% (2) SD@1s across groups
ax2 = nexttile(TL, 2);
hold(ax2,'on');
try
	if isprop(ax2,'Toolbar') && ~isempty(ax2.Toolbar)
		ax2.Toolbar.Visible = 'off';
	end
catch
end

% x positions
xN = 1;
xT = 2;
xNR = 3;

yN = naive.SdAt1s_All(:);
yT = tran.SdAt1s_All(:);
yNR = tran.SdAt1s_NonReuse(:);

% Naive swarm
yNf = yN(isfinite(yN));
swarmchart(ax2, xN*ones(numel(yNf),1), yNf, 22, 'filled');

% Transfer paired lines to NonReuse
maskPair = isfinite(yT) & isfinite(yNR);
if any(maskPair)
	plot(ax2, [xT xNR], [yT(maskPair) yNR(maskPair)]', '-o', 'LineWidth', 1, 'MarkerSize', 4);
end
% Also show any unpaired points (rare)
maskTonly = isfinite(yT) & ~maskPair;
maskNRonly = isfinite(yNR) & ~maskPair;
plot(ax2, xT*ones(nnz(maskTonly),1), yT(maskTonly), 'o', 'LineStyle','none', 'MarkerSize', 4);
plot(ax2, xNR*ones(nnz(maskNRonly),1), yNR(maskNRonly), 'o', 'LineStyle','none', 'MarkerSize', 4);

ax2.XLim = [0.5 3.5];
ax2.XTick = [xN xT xNR];
ax2.XTickLabel = {'Naive','Transfer','T-NonReuse'};
ylabel(ax2, sprintf('Var@~1s (Z)  [t=%.3gs]', xsSec(idx1)));
ylabel(ax2, sprintf('SD@~1s (Z)  [t=%.3gs]', xsSec(idx1)));
% keep labels short (per request)
ylabel(ax2, 'SD@1s (Z)');
title(ax2, 'All-cells SD@1s');

% p-value brackets inside axes
try
	yAll = [yNf(:); yT(isfinite(yT)); yNR(isfinite(yNR))];
	if ~isempty(yAll)
		yMax = max(yAll);
		yMin = min(yAll);
		yR = max(1e-6, yMax - yMin);
		y0 = yMax + 0.08*yR;
		y1 = yMax + 0.18*yR;
		iPValueBracket(ax2, xN, xT,  y0, pN_T);
		iPValueBracket(ax2, xT, xNR, y1, pT_NR);
		ax2.YLim(2) = max(ax2.YLim(2), yMax + 0.28*yR);
	end
catch
end
grid(ax2,'on');
box(ax2,'on');

% (3) Naive Hit vs Miss paired
ax3 = nexttile(TL, 3);
hold(ax3,'on');
try
	if isprop(ax3,'Toolbar') && ~isempty(ax3.Toolbar)
		ax3.Toolbar.Visible = 'off';
	end
catch
end

xHit = 1; xMiss = 2;
yHit = naiveHM.SdAt1s_Hit(:);
yMiss = naiveHM.SdAt1s_Miss(:);
maskHM = isfinite(yHit) & isfinite(yMiss);
if any(maskHM)
	plot(ax3, [xHit xMiss], [yHit(maskHM) yMiss(maskHM)]', '-o', 'LineWidth', 1, 'MarkerSize', 4);
end
maskHonly = isfinite(yHit) & ~maskHM;
maskMonly = isfinite(yMiss) & ~maskHM;
plot(ax3, xHit*ones(nnz(maskHonly),1), yHit(maskHonly), 'o', 'LineStyle','none', 'MarkerSize', 4);
plot(ax3, xMiss*ones(nnz(maskMonly),1), yMiss(maskMonly), 'o', 'LineStyle','none', 'MarkerSize', 4);

ax3.XLim = [0.5 2.5];
ax3.XTick = [xHit xMiss];
ax3.XTickLabel = {'Hit','Miss'};
ylabel(ax3, 'SD@1s (Z)');
title(ax3, 'Naive Hit vs Miss');

% p-value bracket inside axes
try
	yAll = [yHit(isfinite(yHit)); yMiss(isfinite(yMiss))];
	if ~isempty(yAll)
		yMax = max(yAll);
		yMin = min(yAll);
		yR = max(1e-6, yMax - yMin);
		y0 = yMax + 0.10*yR;
		iPValueBracket(ax3, xHit, xMiss, y0, pHitMiss);
		ax3.YLim(2) = max(ax3.YLim(2), yMax + 0.22*yR);
	end
catch
end
grid(ax3,'on');
box(ax3,'on');

% (4) Performance correlation (Transfer)
ax4 = nexttile(TL, 4);
hold(ax4,'on');
try
	if isprop(ax4,'Toolbar') && ~isempty(ax4.Toolbar)
		ax4.Toolbar.Visible = 'off';
	end
catch
end

maskCorr = isfinite(tran.FirstPerformance) & isfinite(tran.SdAt1s_All);
scatter(ax4, tran.FirstPerformance(maskCorr), tran.SdAt1s_All(maskCorr), 28, 'filled');

% add a simple fitted line (least squares)
try
	x = double(tran.FirstPerformance(maskCorr));
	y = double(tran.SdAt1s_All(maskCorr));
	if numel(x) >= 2 && all(isfinite(x)) && all(isfinite(y))
		pFit = polyfit(x(:), y(:), 1);
		xLine = linspace(min(x), max(x), 100);
		yLine = polyval(pFit, xLine);
		plot(ax4, xLine, yLine, '-', 'LineWidth', 1.2, 'Color', 'k');
	end
catch
end
xlabel(ax4, 'Transfer performance (first session)');
ylabel(ax4, 'SD@1s (Z)');
title(ax4, 'Perf vs SD@1s');
% Put correlation stats inside the axes (keep title short)
try
	statsStr = sprintf('Spearman \\rho=%.2g\np=%.2g, n=%d', rho, pRho, nnz(maskCorr));
	xl = ax4.XLim;
	yl = ax4.YLim;
	text(ax4, xl(1) + 0.03*range(xl), yl(2) - 0.05*range(yl), statsStr, ...
		'HorizontalAlignment','left', 'VerticalAlignment','top', 'Interpreter','tex');
catch
end
grid(ax4,'on');
box(ax4,'on');

% No overall (super) title per request

% --- Export (SVG only)
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

[wmsg, wid] = lastwarn;
if strcmp(string(wid), "UniExp:Exception:Block_must_warn")
	fprintf(2, 'Fig3.2d WARNING (%s): %s\n', wid, wmsg);
	fprintf(2, 'Fig3.2d: Please review the warning details above.\n');
end

%% --- local functions
function iPValueBracket(ax, x1, x2, y, p)
	if nargin < 5
		p = NaN;
	end
	if ~isfinite(y)
		return;
	end
	baseLim = ax.YLim;
	h = 0.04 * max(1e-6, diff(baseLim));
	pad = 0.05 * max(1e-6, diff(baseLim));
	line(ax, [x1 x1 x2 x2], [y y+h y+h y], 'Color', 'k', 'LineWidth', 1);
	if isnan(p)
		label = 'p=nan';
	else
		label = sprintf('p=%.2g', p);
	end
	th = text(ax, mean([x1 x2]), y+h, label, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
	% Ensure the label is fully inside the axes.
	% Note: text Extent is in data units and depends on axis scaling, so expanding
	% YLim can itself change Extent. Use a short fixed-point iteration.
	try
		for iter = 1:2
			drawnow('limitrate');
			ext = th.Extent; % [x y w h] in data units
			requiredTop = ext(2) + ext(4);
			limNow = ax.YLim;
			if isfinite(requiredTop) && requiredTop > limNow(2)
				ax.YLim(2) = requiredTop + pad;
			else
				break;
			end
		end
	catch
	end
end

function T = iTableQueryOrEmpty(DS, vars, varargin)
	try
		T = DS.TableQuery(vars, varargin{:});
	catch
		T = [];
	end
	if isempty(T)
		return;
	end
	if ismember('DateTime', T.Properties.VariableNames)
		try
			T.DateTime = datetime(T.DateTime);
			T.DateTime.TimeZone = '';
		catch
		end
	end
end

function G = iQueryNTATSOrEmpty(DS, query)
	try
		G = DS.QueryNTATS(query, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
	catch
		G = [];
	end
end

function X = iNtatsData(NT)
	if isa(NT, 'MATLAB.DataTypes.NDTable')
		X = NT.Data;
	else
		X = NT;
	end
	X = squeeze(X);
end

function cellUID = iMouseCellUID(DS, mouseName)
	cellUID = uint64([]);
	try
		C = DS.Cells;
		if isempty(C) || ~all(ismember({'Mouse','CellUID'}, C.Properties.VariableNames))
			return;
		end
		m = string(mouseName);
		C.Mouse = string(C.Mouse);
		cellUID = unique(uint64(C.CellUID(C.Mouse == m)));
	catch
		cellUID = uint64([]);
	end
end

function Z = iMedianTraceZScore(DS, cellUID, trialUID)
	Z = [];
	if isempty(cellUID) || isempty(trialUID)
		return;
	end
	q = struct('CellUID', uint64(cellUID), 'TrialUID', uint64(trialUID));
	G = iQueryNTATSOrEmpty(DS, q);
	if isempty(G) || ~all(ismember({'CellUID','NTATS'}, G.Properties.VariableNames))
		return;
	end
	X = iNtatsData(G.NTATS);
	if isempty(X)
		return;
	end
	Z = table(uint64(G.CellUID), X, 'VariableNames', {'CellUID','Trace'});
end

function act = iMedianActive(X, baseMask, winMask, kSigma)
	baseMu = mean(X(:, baseMask), 2, 'omitnan');
	baseSd = std(X(:, baseMask), 0, 2, 'omitnan');
	winMx = max(X(:, winMask), [], 2, 'omitnan');
	act = winMx > (baseMu + kSigma .* baseSd);
end

function out = iFindPureNaiveLightWaterMice(DS, excludeMice, sourceName)
	if nargin < 2 || isempty(excludeMice)
		excludeMice = strings(0, 1);
	end
	excludeMice = string(excludeMice);

	try
		T = DS.TableQuery(["Mouse","BlockUID","DateTime","Phase"], Phase="Naive");
	catch ME
		error('Fig3_2d:PureNaiveQueryFailed', char("Pure-Naive query failed for " + string(sourceName) + ": " + string(ME.message)));
	end

	T.Mouse = string(T.Mouse);
	T = T(~ismember(T.Mouse, excludeMice), :);
	if isempty(T)
		out = table(string.empty(0,1), nan(0,1), 'VariableNames', {'Mouse','NBlocks'});
		return;
	end

	if ~isprop(DS, 'Trials')
		error('Fig3_2d:MissingTrials', char("DataSet " + string(sourceName) + " has no Trials; cannot detect AudioWater mixing."));
	end

	Tr = DS.Trials;
	if ~ismember('Stimulus', Tr.Properties.VariableNames) || ~ismember('BlockUID', Tr.Properties.VariableNames)
		error('Fig3_2d:TrialsMissingFields', char("Trials table for " + string(sourceName) + " lacks Stimulus/BlockUID."));
	end
	Tr.Stimulus = string(Tr.Stimulus);

	mice = unique(T.Mouse);
	keep = false(size(mice));
	nBlocks = nan(size(mice));

	for mouseIdx = 1:numel(mice)
		m = mice(mouseIdx);
		rowsM = (T.Mouse == m);
		bu = unique(uint64(T.BlockUID(rowsM)));
		nLWBlocks = 0;
		hasAudio = false;
		for blockIdx = 1:numel(bu)
			b = bu(blockIdx);
			trB = (uint64(Tr.BlockUID) == b);
			stimB = Tr.Stimulus(trB);
			hasLW = any(stimB == "LightWater");
			if ~hasLW
				continue;
			end
			nLWBlocks = nLWBlocks + 1;
			if any(stimB == "AudioWater")
				hasAudio = true;
				break;
			end
		end
		nBlocks(mouseIdx) = nLWBlocks;
		keep(mouseIdx) = (~hasAudio) & (nLWBlocks > 0);
	end

	bad = mice(~keep);
	if ~isempty(bad)
		fprintf('Fig3.2d: Excluding %d mice from %s due to AudioWater-mixed Naive blocks.\n', numel(bad), char(string(sourceName)));
		fprintf('  %s\n', char(strjoin(bad, ', ')));
	end

	out = table(mice(keep), nBlocks(keep), 'VariableNames', {'Mouse','NBlocks'});
end

function iAssertNoDuplicateMiceAcrossSources(T, groupName)
	if isempty(T)
		return;
	end
	T.Mouse = string(T.Mouse);
	[keys, ~, g] = unique(T.Mouse);
	nPerMouse = accumarray(g, 1);
	dupMice = keys(nPerMouse > 1);
	if isempty(dupMice)
		return;
	end
	linesOut = strings(numel(dupMice), 1);
	for idx = 1:numel(dupMice)
		m = dupMice(idx);
		src = unique(string(T.Source(T.Mouse == m)));
		linesOut(idx) = m + " -> " + strjoin(src, ", ");
	end
	msg = "Duplicate mouse IDs across sources in group '" + string(groupName) + "':\n" + strjoin(linesOut, "\n");
	error('Fig3_2d:DuplicateMouse', char(msg));
end

function rows = iFirstSessionAllCellsByMouse(DS, sourceName, phaseName, stimulusName, whitelistMice, baseMask, minTrials, xsSec, idx1)
	T = iTableQueryOrEmpty(DS, ["TrialUID","Mouse","DateTime","Phase","Stimulus"], Phase=phaseName, Stimulus=stimulusName);
	if isempty(T)
		rows = table;
		return;
	end
	T.Mouse = string(T.Mouse);
	T.Phase = string(T.Phase);
	T.Stimulus = string(T.Stimulus);
	if ~isempty(whitelistMice)
		whitelistMice = string(whitelistMice);
		T = T(ismember(T.Mouse, whitelistMice), :);
	end
	if isempty(T)
		rows = table;
		return;
	end

	mice = unique(T.Mouse);
	rows = table(string.empty(0,1), string.empty(0,1), NaT(0,1), nan(0,1), nan(0,1), nan(0,1), cell(0,1), ...
		'VariableNames', {'Mouse','Source','DateTime','NTrials','NCellsUsed','SdAt1s_All','MeanCurve_All'});

	for iM = 1:numel(mice)
		m = mice(iM);
		Ti = T(T.Mouse==m & T.Phase==string(phaseName) & T.Stimulus==string(stimulusName), :);
		if isempty(Ti)
			continue;
		end
		Ti = sortrows(Ti, 'DateTime');
		dt = Ti.DateTime(1);
		tu = unique(uint64(Ti.TrialUID(Ti.DateTime==dt)));
		if numel(tu) < minTrials
			continue;
		end
		cellUID = iMouseCellUID(DS, m);
		if isempty(cellUID)
			continue;
		end
		Z = iMedianTraceZScore(DS, cellUID, tu);
		if isempty(Z) || height(Z) < 10
			continue;
		end
		X = Z.Trace;
		if size(X,2) ~= numel(xsSec)
			continue;
		end
		meanCurve = mean(X, 1, 'omitnan');
		s1 = std(X(:, idx1), 0, 1, 'omitnan');
		rows = [rows; table(m, string(sourceName), dt, numel(tu), height(Z), s1, {meanCurve}, ...
			'VariableNames', rows.Properties.VariableNames)]; %#ok<AGROW>
	end
end

function rows = iFirstTransferWithNonReuseByMouse(DS, baseMask, win01, idx1, kSigma, minTrials, xsSec)
	Tt = iTableQueryOrEmpty(DS, ["TrialUID","Mouse","DateTime","Phase","Stimulus"], Phase="Transfer", Stimulus="LightWater");
	Tl = iTableQueryOrEmpty(DS, ["TrialUID","Mouse","DateTime","Phase","Stimulus"], Phase="Learned", Stimulus="AudioWater");
	if isempty(Tt)
		rows = table;
		return;
	end
	if isempty(Tl)
		error('Fig3_2d:MissingLearned', 'Missing Learned(AudioWater) trials in AudioLightBaseline.');
	end
	Tt.Mouse = string(Tt.Mouse);
	Tl.Mouse = string(Tl.Mouse);
	Tt = sortrows(Tt, {'Mouse','DateTime'});
	Tl = sortrows(Tl, {'Mouse','DateTime'});

	% Precompute performance per block (LightWater only)
	if ~isprop(DS, 'Trials')
		error('Fig3_2d:MissingTrials', 'AudioLightBaseline has no Trials; cannot compute performance.');
	end
	Tr = DS.Trials;
	need = {'BlockUID','Stimulus','Behavior'};
	if ~all(ismember(need, Tr.Properties.VariableNames))
		error('Fig3_2d:TrialsMissingFields', 'Trials table lacks required fields for performance: %s', strjoin(setdiff(need, Tr.Properties.VariableNames), ','));
	end
	TrStim = string(Tr.Stimulus);
	TrLW = Tr(TrStim == "LightWater", {'BlockUID','Behavior'});
	[G, bu] = findgroups(uint64(TrLW.BlockUID));
	lwPerf = splitapply(@(x) mean(double(x), 'omitnan'), TrLW.Behavior, G);
	perfByBlock = table(uint64(bu), lwPerf, 'VariableNames', {'BlockUID64','LWPerf'});

	mice = unique(Tt.Mouse);
	rows = table(string.empty(0,1), NaT(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), cell(0,1), ...
		'VariableNames', {'Mouse','DateTimeTransfer','NTrialsTransfer','NCellsTransfer','FirstPerformance','SdAt1s_All','SdAt1s_NonReuse','NReuseCells','MeanCurve_All'});

	for iM = 1:numel(mice)
		m = mice(iM);
		Ti = Tt(Tt.Mouse==m, :);
		if isempty(Ti)
			continue;
		end
		Ti = sortrows(Ti, 'DateTime');
		dtT = Ti.DateTime(1);
		tuT = unique(uint64(Ti.TrialUID(Ti.DateTime==dtT)));
		if numel(tuT) < minTrials
			continue;
		end

		% Compute first-session performance (mean per-block LWPerf over blocks in the first session)
		firstPerf = NaN;
		try
			Tblk = iTableQueryOrEmpty(DS, ["Mouse","DateTime","BlockUID","Phase"], Phase="Transfer");
			if ~isempty(Tblk)
				Tblk.Mouse = string(Tblk.Mouse);
				Tblk = Tblk(Tblk.Mouse==m, :);
				Tblk = sortrows(Tblk, 'DateTime');
				if ~isempty(Tblk)
					rows0 = (Tblk.DateTime == dtT);
					blkUID64 = uint64(Tblk.BlockUID(rows0));
					[tf, loc] = ismember(blkUID64, perfByBlock.BlockUID64);
					if any(tf)
						firstPerf = mean(perfByBlock.LWPerf(loc(tf)), 'omitnan');
					end
				end
			end
		catch
			firstPerf = NaN;
		end

		cellUID = iMouseCellUID(DS, m);
		if isempty(cellUID)
			continue;
		end
		ZT = iMedianTraceZScore(DS, cellUID, tuT);
		if isempty(ZT) || height(ZT) < 10
			continue;
		end
		XT = ZT.Trace;
		if size(XT,2) ~= numel(xsSec)
			continue;
		end

		% Learned last session (AudioWater) for reuse classification
		Tlearn = Tl(Tl.Mouse==m, :);
		if isempty(Tlearn)
			% no learned for this mouse
			reuseUID = uint64([]);
		else
			Tlearn = sortrows(Tlearn, 'DateTime');
			dtL = Tlearn.DateTime(end);
			tuL = unique(uint64(Tlearn.TrialUID(Tlearn.DateTime==dtL)));
			ZL = iMedianTraceZScore(DS, cellUID, tuL);
			reuseUID = uint64([]);
			if ~isempty(ZL)
				% restrict to cells present in learned query
				uidL = uint64(ZL.CellUID);
				XL = ZL.Trace;
				if ~isempty(XL) && size(XL,2) == numel(xsSec)
					learnAct = iMedianActive(XL, baseMask, win01, kSigma);
					reuseUID = uidL(learnAct);
				end
			end
		end

	uidT = uint64(ZT.CellUID);
	maskNonReuse = ~ismember(uidT, uint64(reuseUID));
	nReuse = nnz(ismember(uidT, uint64(reuseUID)));

	sdAll = std(XT(:, idx1), 0, 1, 'omitnan');
	sdNR = NaN;
	if nnz(maskNonReuse) >= 5
		sdNR = std(XT(maskNonReuse, idx1), 0, 1, 'omitnan');
	end

	meanCurve = mean(XT, 1, 'omitnan');
	rows = [rows; table(m, dtT, numel(tuT), height(ZT), firstPerf, sdAll, sdNR, nReuse, {meanCurve}, ...
		'VariableNames', rows.Properties.VariableNames)]; %#ok<AGROW>
	end
end

function HM = iNaiveFirstSessionHitMissSdAt1s(LAB, LAI, naiveTable, idx1, baseMask, minTrials, xsSec)
	% For each Naive mouse already included in panel1/2, locate its source DS, then
	% compute SD@1s across all cells for Hit-trials and Miss-trials within its FIRST session.
	
	HM = table(string.empty(0,1), string.empty(0,1), NaT(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), ...
		'VariableNames', {'Mouse','Source','DateTime','NTrialsHit','NTrialsMiss','SdAt1s_Hit','SdAt1s_Miss'});
	if isempty(naiveTable)
		return;
	end
	naiveTable.Mouse = string(naiveTable.Mouse);
	naiveTable.Source = string(naiveTable.Source);
	
	for i = 1:height(naiveTable)
		m = naiveTable.Mouse(i);
		src = naiveTable.Source(i);
		if src == "LightAudioBaseline"
			DS = LAB;
		elseif src == "LAInterspersed"
			DS = LAI;
		else
			continue;
		end

		T = iTableQueryOrEmpty(DS, ["TrialUID","Mouse","DateTime","Phase","Stimulus","Behavior"], Phase="Naive", Stimulus="LightWater");
		if isempty(T)
			continue;
		end
		if ~ismember('Behavior', T.Properties.VariableNames)
			continue;
		end
		T.Mouse = string(T.Mouse);
		T = T(T.Mouse==m, :);
		if isempty(T)
			continue;
		end
		T = sortrows(T, 'DateTime');
		dt = T.DateTime(1);
		T0 = T(T.DateTime==dt, :);
		if isempty(T0)
			continue;
		end
		tuHit = unique(uint64(T0.TrialUID(double(T0.Behavior)==1)));
		tuMiss = unique(uint64(T0.TrialUID(double(T0.Behavior)==0)));
		if numel(tuHit) < minTrials || numel(tuMiss) < minTrials
			HM = [HM; table(m, src, dt, numel(tuHit), numel(tuMiss), NaN, NaN, 'VariableNames', HM.Properties.VariableNames)]; %#ok<AGROW>
			continue;
		end

		cellUID = iMouseCellUID(DS, m);
		if isempty(cellUID)
			continue;
		end

		ZH = iMedianTraceZScore(DS, cellUID, tuHit);
		ZM = iMedianTraceZScore(DS, cellUID, tuMiss);
		sH = NaN; sM = NaN;
		if ~isempty(ZH) && size(ZH.Trace,2) == numel(xsSec) && height(ZH) >= 5
			sH = std(ZH.Trace(:, idx1), 0, 1, 'omitnan');
		end
		if ~isempty(ZM) && size(ZM.Trace,2) == numel(xsSec) && height(ZM) >= 5
			sM = std(ZM.Trace(:, idx1), 0, 1, 'omitnan');
		end

		HM = [HM; table(m, src, dt, numel(tuHit), numel(tuMiss), sH, sM, 'VariableNames', HM.Properties.VariableNames)]; %#ok<AGROW>
	end
end

function [mCurve, sCurve, n] = iMeanSemAcrossMice(curveCell, nTime)
	if nargin < 2 || isempty(nTime)
		nTime = 48;
	end
	if isempty(curveCell)
		mCurve = nan(nTime,1);
		sCurve = nan(nTime,1);
		n = 0;
		return;
	end
	mat = [];
	for i = 1:numel(curveCell)
		c = curveCell{i};
		if isempty(c) || all(~isfinite(c))
			continue;
		end
		mat(end+1, :) = double(c(:)).'; %#ok<AGROW>
	end
	if isempty(mat)
		mCurve = nan(nTime,1);
		sCurve = nan(nTime,1);
		n = 0;
		return;
	end
	n = size(mat,1);
	mCurve = mean(mat, 1, 'omitnan').';
	sd = std(mat, 0, 1, 'omitnan');
	sCurve = (sd ./ sqrt(n)).';
end

% 图3.2d：Naive LightWater vs Transfer LightWater（按 Learned 阶段活跃/不活跃细胞拆分）

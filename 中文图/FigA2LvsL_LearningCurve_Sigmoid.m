% Fig A2L vs L: AL Light vs LA Light learning curve + sigmoid fit
% 来自 A2L_L.mat (AL Light) 和 L2A_L.mat (LA Light)，用1-7天数据

%% --- 0. 项目加载 ---
if ~exist('UniExp.DataSet','class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if ~exist(prjFile, 'file')
		prjFile = fullfile(thisDir, '..', '..', 'Transferlearning.prj');
	end
	if exist(prjFile,'file')
		prj = matlab.project.loadProject(prjFile);
		prjRoot = fileparts(prjFile);
		addpath(prjRoot);
	end
end

dataRoot = '\\Data-Server-2\个人数据\杨青宁\202607\行为学';

%% --- 1. 加载数据 ---
DataSetA2L = UniExp.DataSet(fullfile(dataRoot, 'A2L_L.mat'));
DataSetL   = UniExp.DataSet(fullfile(dataRoot, 'L2A_L.mat'));

%% --- 2. 提取会话表（每鼠每 session 一行） ---
% 尝试 TableQuery，兼容不同字段名
varsTry = ["Mouse","DateTime","Performance"];
try
	SessA2L = DataSetA2L.TableQuery(varsTry);
catch
	SessA2L = DataSetA2L.TableQuery(["Mouse","DateTime","Behavior"]);
	SessA2L.Properties.VariableNames{'Behavior'} = 'Performance';
end
try
	SessL = DataSetL.TableQuery(varsTry);
catch
	SessL = DataSetL.TableQuery(["Mouse","DateTime","Behavior"]);
	SessL.Properties.VariableNames{'Behavior'} = 'Performance';
end

if isempty(SessA2L) || isempty(SessL)
	error('FigA2LvsL:EmptyData', 'One or both datasets returned no sessions.');
end

SessA2L.Mouse = string(SessA2L.Mouse);
SessL.Mouse   = string(SessL.Mouse);
SessA2L.Group(:) = "AL_Light";
SessL.Group(:)   = "LA_Light";

allSessions = [SessA2L; SessL];
allSessions = sortrows(allSessions, ["Group","Mouse","DateTime"]);

% 给每个 Mouse 加 Session 序号
allSessions = iAddSessionIndex(allSessions);

fprintf('AL Light: %d sessions, %d unique mice\n', ...
	height(SessA2L), numel(unique(SessA2L.Mouse)));
fprintf('LA Light: %d sessions, %d unique mice\n', ...
	height(SessL),   numel(unique(SessL.Mouse)));

% 限制到 Session 1-7
allSessions7 = allSessions(allSessions.Session <= 7, :);
if isempty(allSessions7)
	error('FigA2LvsL:NoSessions1to7', 'No sessions in range 1-7.');
end

% 重新编号 Session（1-7 连续）
allSessions7 = sortrows(allSessions7, ["Group","Mouse","DateTime"]);
allSessions7 = iAddSessionIndex(allSessions7);

%% --- 3. UniExp.LearningSummarize ---
sessionForSummary = allSessions7(:, ["Mouse","DateTime","Performance","Group"]);
sessionForSummary.Group = string(sessionForSummary.Group);
sessionForSummary = sortrows(sessionForSummary, ["Group","Mouse","DateTime"]);
[~, SummaryL] = evalc('UniExp.LearningSummarize(sessionForSummary)');

[meanMat, semMat, x] = iUnpackLearningSummarize(SummaryL, ["AL_Light","LA_Light"]);
nMat = iComputeNBySession(allSessions7, x, ["AL_Light","LA_Light"]);

%% --- 4. 提取用于 sigmoid 拟合的数据 ---
displayedAL = iFilterToDisplayedMice(allSessions7(string(allSessions7.Group) == "AL_Light", :));
displayedL  = iFilterToDisplayedMice(allSessions7(string(allSessions7.Group) == "LA_Light", :));

fitAL = iFitSigmoidCurve(displayedAL, "AL_Light");
fitL  = iFitSigmoidCurve(displayedL,  "LA_Light");

%% --- 5. 置换检验 sigmoid slope ---
permResult = iPermutationTestSigmoidSlope(displayedAL, displayedL, 10000, 1);

%% --- 6. Two-way ANOVA ---
groupP = TransferLearning.Style.TwoWayAnovaGroupPValue(allSessions7, 'Performance', 'Session', 'Group', 'Mouse');
fprintf('\n=== Two-way ANOVA (Group effect, all sessions 1-7) ===\n');
fprintf('Group P = %.6g\n', groupP);

%% --- 7. 绘图 ---
xMax = 7;
xSummary = (1:xMax).';
xFit = linspace(max(0, min(xSummary) - 1), max(xSummary) + 1, 200).';
alFitCurve = iSigmoidFromParams(fitAL.ParamRaw, xFit);
lFitCurve  = iSigmoidFromParams(fitL.ParamRaw,  xFit);

% 截断 meanMat/semMat
meanMatOut = nan(numel(xSummary), size(meanMat, 2));
semMatOut = nan(numel(xSummary), size(semMat, 2));
nMatOut    = nan(numel(xSummary), size(nMat, 2));
meanMatOut(1:size(meanMat, 1), :) = meanMat;
semMatOut(1:size(semMat, 1), :)  = semMat;
nMatOut(1:size(nMat, 1), :)      = nMat;

f = figure('Color', 'w', 'Name', 'FigA2LvsL Learning curve');
f.Units = 'centimeters';
f.Position(3:4) = [12, 8];
f.PaperUnits = 'centimeters';
f.PaperSize = [12, 8];
f.PaperPositionMode = 'auto';

ax = axes(f);
hold(ax, 'on');

colorAL = TransferLearning.NaiveColor;
colorL  = TransferLearning.TransferColor;

hAL = iPlotGroupMeanErrorbarsSingleAx(ax, xSummary, meanMatOut(:,1), semMatOut(:,1), xFit, alFitCurve, colorAL);
hL  = iPlotGroupMeanErrorbarsSingleAx(ax, xSummary, meanMatOut(:,2), semMatOut(:,2), xFit, lFitCurve, colorL);

ylabel(ax, 'Hit rate', 'FontSize', 12);
xlabel(ax, 'Session', 'FontSize', 12);
ax.FontSize = 12;
ax.LineWidth = 2;
ax.Color = 'none';
box(ax, 'off');
grid(ax, 'off');
title(ax, '');

% Horizontal P-value line spanning blocks 1-7
max7AL = max(meanMatOut(1:min(7, end), 1), [], 'omitnan');
max7L  = max(meanMatOut(1:min(7, end), 2), [], 'omitnan');
yTop7 = max(max7AL, max7L);
yl = ylim(ax); yrange = yl(2) - yl(1);
yPLine = yTop7 + 0.08 * yrange;
textY = yPLine + 0.1 * yrange;
plot(ax, [1, 7], [yPLine, yPLine], 'k-', 'LineWidth', 1);
if groupP < 0.001, starStr = '＊＊＊＊'; else, starStr = TransferLearning.Style.iFormatPText(groupP); end
text(ax, 4, textY, starStr, ...
	'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', 'FontSize', 12);

% Clean yticks: remove values > 1
yt = yticks(ax);
yticks(ax, yt(yt <= 1 + 1e-6));

% 扩展 y 上限避免 title 与 P 值标注遮挡
yl_ = ylim(ax);
ylim(ax, [yl_(1), yl_(2) + 0.12 * (yl_(2) - yl_(1))]);

allAxes = findall(f, 'Type', 'axes');
for axItem = reshape(allAxes, 1, [])
	if isprop(axItem, 'Toolbar') && ~isempty(axItem.Toolbar)
		axItem.Toolbar.Visible = 'off';
	end
end
title('All mice');
svgPath = TransferLearning.ExportStandardFigure(f, 2, '中文图FigA2LvsL_LearningCurve_Sigmoid.svg');

%% --- 8. Per-mouse blocks-to-50% bar ---
blocks50AL = iPerMouseBlocksTo50(displayedAL);
blocks50L  = iPerMouseBlocksTo50(displayedL);
blocks50AL = blocks50AL.BlocksTo50(isfinite(blocks50AL.BlocksTo50));
blocks50L  = blocks50L.BlocksTo50(isfinite(blocks50L.BlocksTo50));

edgeColorsBar = [TransferLearning.NaiveColor; TransferLearning.TransferColor];
f2 = figure('Name', 'FigA2LvsL per-mouse slope');
f2.Units = 'centimeters';
f2.Position(3:4) = [4, 4];
[~, optional2, bars2, errorBars2] = UniExp.BarScatterCompare({blocks50AL(:), blocks50L(:)}, table([1 2], 'VariableNames', {'GroupPair'}), 'AsteriskThreshold', 1);
ax2 = gca;
ax2.XTickLabel = {};
legend(ax2, 'off');
if isfield(optional2, 'MultiCompare') && ismember('PLine', optional2.MultiCompare.Properties.VariableNames)
	for pl = optional2.MultiCompare.PLine(:)'
		pl.LineWidth = 2;
		pl.Tag = 'PLine';
	end
end
if isfield(optional2, 'MultiCompare') && ismember('PText', optional2.MultiCompare.Properties.VariableNames)
	for pt = optional2.MultiCompare.PText(:)'
		pt.Tag = 'PText';
	end
end
TransferLearning.Style.SetBarPValues(optional2);
iStyleBars(bars2, edgeColorsBar(1,:), edgeColorsBar(2,:));
iStyleErrorBars(errorBars2, edgeColorsBar);
title(ax2, 'Blocks to 50% hit rate');
box(ax2, 'off');
grid(ax2, 'off');
if isprop(ax2, 'Toolbar') && ~isempty(ax2.Toolbar)
	ax2.Toolbar.Visible = 'off';
end
svgPath2 = TransferLearning.ExportStandardFigureTransparent(f2, 2, '中文图FigA2LvsL_PerMouseSlopeBar.svg');

%% --- 9. 选代表鼠 ---
% 对每组：找出与组 sigmoid 拟合曲线最匹配的单鼠
[bestAL, bestALstats] = iFindBestRepresentativeMouse(displayedAL);
[bestL,  bestLstats]  = iFindBestRepresentativeMouse(displayedL);

fprintf('\n=== 代表鼠 ===\n');
fprintf('AL Light 组代表鼠: %s  (拟合误差 MSE=%.4f, nSessions=%d)\n', ...
	bestAL, bestALstats.MSE, bestALstats.NSessions);
fprintf('LA Light 组代表鼠: %s  (拟合误差 MSE=%.4f, nSessions=%d)\n', ...
	bestL,  bestLstats.MSE,  bestLstats.NSessions);

%% --- 10. 输出统计 ---
fprintf('\n=== FigA2LvsL Sigmoid ===\n');
fprintf('AL Light mice: %d\n', numel(unique(string(displayedAL.Mouse))));
fprintf('LA Light mice: %d\n', numel(unique(string(displayedL.Mouse))));
fprintf('AL sigmoid: lower=%.4f, upper=%.4f, slope=%.4f, midpoint=%.4f, R^2=%.4f\n', ...
	fitAL.Lower, fitAL.Upper, fitAL.Slope, fitAL.Midpoint, fitAL.RSquared);
fprintf('LA sigmoid: lower=%.4f, upper=%.4f, slope=%.4f, midpoint=%.4f, R^2=%.4f\n', ...
	fitL.Lower, fitL.Upper, fitL.Slope, fitL.Midpoint, fitL.RSquared);
fprintf('Permutation slope diff P = %.4g (%d permutations)\n', permResult.PValue, permResult.NPermutation);
fprintf('Two-way ANOVA Group P (sessions 1-7) = %.6g\n', groupP);
fprintf('Wrote: %s\n', svgPath);
fprintf('Wrote: %s\n', svgPath2);
fprintf('Per-mouse blocks-to-50%% bar P (BarScatterCompare) = %s\n', TransferLearning.Style.iFormatPText(optional2.MultiCompare.PValue(1)));

assignin('base', 'FigA2LvsL_AllSessions', allSessions7);
assignin('base', 'FigA2LvsL_FitAL', fitAL);
assignin('base', 'FigA2LvsL_FitL', fitL);
assignin('base', 'FigA2LvsL_Permutation', permResult);
assignin('base', 'FigA2LvsL_AnovaGroupP', groupP);
assignin('base', 'FigA2LvsL_BestAL', bestAL);
assignin('base', 'FigA2LvsL_BestL', bestL);
assignin('base', 'FigA2LvsL_Blocks50AL', blocks50AL);
assignin('base', 'FigA2LvsL_Blocks50L', blocks50L);

%% ===================== 本地函数 =====================

function T = iAddSessionIndex(T)
	T.Mouse = string(T.Mouse);
	T = sortrows(T, {'Group','Mouse','DateTime'});
	[G, ~] = findgroups(T.Group, T.Mouse);
	sessCell = splitapply(@(x) {(1:numel(x))'}, T.DateTime, G);
	T.Session = vertcat(sessCell{:});
end

function [meanMat, semMat, x] = iUnpackLearningSummarize(SummaryL, groupOrder)
	groupOrder = string(groupOrder);
	if ~istable(SummaryL)
		if isstruct(SummaryL), SummaryL = struct2table(SummaryL);
		else, error('FigA2LvsL:InvalidLearningSummarizeOutput'); end
	end
	meanCells = SummaryL.MeanCurve(:); semCells = SummaryL.SemCurve(:);
	if ~isempty(SummaryL.Properties.RowNames), rn = string(SummaryL.Properties.RowNames);
	else, rn = strings(numel(meanCells),1); end
	idx = nan(1, numel(groupOrder));
	for k = 1:numel(groupOrder)
		if all(rn == "")
			if k <= numel(meanCells), idx(k) = k; end
		else
			ix = find(rn == groupOrder(k), 1, 'first');
			if ~isempty(ix), idx(k) = ix; end
		end
	end
	maxLen = 0;
	for k = 1:numel(groupOrder)
		if ~isfinite(idx(k)), continue; end
		maxLen = max(maxLen, max(numel(meanCells{idx(k)}), numel(semCells{idx(k)})));
	end
	meanMat = nan(maxLen, numel(groupOrder)); semMat = nan(maxLen, numel(groupOrder));
	for k = 1:numel(groupOrder)
		if ~isfinite(idx(k)), continue; end
		mv = double(meanCells{idx(k)}(:)); sv = double(semCells{idx(k)}(:));
		meanMat(1:numel(mv), k) = mv; semMat(1:numel(sv), k) = sv;
	end
	x = (1:maxLen).';
end

function nMat = iComputeNBySession(T, x, groups)
	groups = string(groups); x = double(x(:)); nMat = zeros(numel(x), numel(groups));
	T.Group = string(T.Group); T.Session = double(T.Session);
	for g = 1:numel(groups)
		rowsG = (T.Group == groups(g));
		for s = 1:numel(x)
			rowsS = rowsG & (T.Session == s) & isfinite(double(T.Performance));
			if any(rowsS), nMat(s,g) = numel(unique(string(T.Mouse(rowsS)))); end
		end
	end
end

function T = iFilterToDisplayedMice(T)
	if isempty(T), return; end
	rows = isfinite(double(T.Session)) & isfinite(double(T.Performance));
	shownMice = unique(string(T.Mouse(rows)), 'stable');
	T = T(ismember(string(T.Mouse), shownMice), :);
end

function hOut = iPlotGroupMeanErrorbarsSingleAx(ax, xSummary, meanVec, semVec, xFit, fitCurve, curveColor)
	meanVec = double(meanVec); semVec = double(semVec);
	useObs = isfinite(meanVec);
	xObs = xSummary(useObs); meanObs = meanVec(useObs); semObs = semVec(useObs);
	semObs(~isfinite(semObs)) = 0;
	hE = errorbar(ax, xObs, meanObs, semObs, 'o', ...
		'Color', curveColor, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', curveColor, ...
		'MarkerSize', 4.5, 'LineWidth', 1.5, 'CapSize', 4, 'LineStyle', 'none');
	hP = plot(ax, xFit, fitCurve, '-', 'Color', curveColor, 'LineWidth', 2.2, 'Tag', 'TransferLearningSupplementalLine');
	hOut = [hE, hP];
end

function iStyleBars(barsObj, colorA, colorB)
	if isscalar(barsObj)
		barsObj.FaceColor = 'flat'; nBars = numel(barsObj.YData);
		barsObj.CData = repmat([colorA; colorB], ceil(nBars/2), 1);
		barsObj.CData = barsObj.CData(1:nBars, :); barsObj.BarWidth = 0.5;
		barsObj.LineWidth = 2; barsObj.BaseLine.LineWidth = 2; barsObj.EdgeColor = 'none';
	end
end

function iStyleErrorBars(errorBarsObj, colors)
	if iscell(errorBarsObj)
		for i = 1:min(numel(errorBarsObj), size(colors, 1))
			if isgraphics(errorBarsObj{i})
				errorBarsObj{i}.Color = colors(i, :); errorBarsObj{i}.LineWidth = 2; errorBarsObj{i}.CapSize = 8;
			end
		end
	elseif istable(errorBarsObj) && ismember('Object', errorBarsObj.Properties.VariableNames)
		for i = 1:min(height(errorBarsObj), size(colors, 1))
			eb = errorBarsObj.Object(i);
			if isgraphics(eb)
				eb.Color = colors(i, :); eb.LineWidth = 2; eb.CapSize = 8;
			end
		end
	end
end

function out = iPerMouseBlocksTo50(Sess)
	if isempty(Sess), out = table(string.empty(0,1), nan(0,1), 'VariableNames', {'Mouse','BlocksTo50'}); return; end
	Sess = sortrows(Sess, {'Mouse','DateTime'});
	mice = unique(string(Sess.Mouse)); blocksVec = nan(numel(mice), 1);
	for iM = 1:numel(mice)
		m = mice(iM); R = sortrows(Sess(string(Sess.Mouse) == m, :), 'DateTime');
		perf = double(R.Performance);
		reached = find(perf >= 1.0, 1, 'first');
		if isempty(reached), continue; end
		R = R(1:reached, :);
		R.Performance(end) = 1;
		hit50 = find(double(R.Performance) >= 0.5, 1, 'first');
		if isempty(hit50), continue; end
		blocksVec(iM) = hit50;
	end
	out = table(mice, blocksVec, 'VariableNames', {'Mouse','BlocksTo50'});
end

function fitOut = iFitSigmoidCurve(T, groupName)
	T = sortrows(T, {'Mouse','DateTime'});
	xObs = double(T.Session(:)); yObs = double(T.Performance(:));
	use = isfinite(xObs) & isfinite(yObs); xObs = xObs(use); yObs = yObs(use);
	if isempty(xObs), error('FigA2LvsL:NoDataForGroup', 'No data for %s.', char(groupName)); end
	p0 = [iLogit(max(min(min(yObs), 0.45), 0.01)); log(0.8); log(max(median(xObs), 1))];
	obj = @(p) sum((yObs - iSigmoidFromParams(p, xObs)).^2, 'omitnan');
	opt = optimset('Display', 'off', 'MaxFunEvals', 10000, 'MaxIter', 10000);
	p = fminsearch(obj, p0, opt);
	yHat = iSigmoidFromParams(p, xObs);
	SSE = sum((yObs - yHat).^2, 'omitnan'); SST = sum((yObs - mean(yObs, 'omitnan')).^2, 'omitnan');
	rSquared = NaN; if SST > 0, rSquared = 1 - SSE / SST; end
	[lower, upper, slope, midpoint] = iDecodeSigmoidParams(p);
	fitOut = struct; fitOut.Group = string(groupName); fitOut.ParamRaw = p;
	fitOut.Lower = lower; fitOut.Upper = upper; fitOut.Slope = slope; fitOut.Midpoint = midpoint;
	fitOut.SSE = SSE; fitOut.RSquared = rSquared; fitOut.XObserved = xObs; fitOut.YObserved = yObs;
end

function permOut = iPermutationTestSigmoidSlope(T1, T2, nPermutation, rngSeed)
	if nargin < 3 || isempty(nPermutation), nPermutation = 2000; end
	if nargin >= 4 && ~isempty(rngSeed), rng(rngSeed); end
	T1 = sortrows(T1, {'Mouse','DateTime'});
	T2 = sortrows(T2, {'Mouse','DateTime'});
	mice1 = unique(string(T1.Mouse), 'stable');
	mice2 = unique(string(T2.Mouse), 'stable');
	allMouseTables = cell(numel(mice1) + numel(mice2), 1);
	for i = 1:numel(mice1), allMouseTables{i} = T1(string(T1.Mouse) == mice1(i), :); end
	for i = 1:numel(mice2), allMouseTables{numel(mice1) + i} = T2(string(T2.Mouse) == mice2(i), :); end
	fit1 = iFitSigmoidCurve(T1, "G1");
	fit2 = iFitSigmoidCurve(T2, "G2");
	observedDiff = fit2.Slope - fit1.Slope;
	permDiff = nan(nPermutation, 1); n1 = numel(mice1);
	for iPerm = 1:nPermutation
		ord = randperm(numel(allMouseTables));
		perm1 = vertcat(allMouseTables{ord(1:n1)});
		perm2 = vertcat(allMouseTables{ord(n1+1:end)});
		fp1 = iFitSigmoidCurve(perm1, "G1Perm");
		fp2 = iFitSigmoidCurve(perm2, "G2Perm");
		permDiff(iPerm) = fp2.Slope - fp1.Slope;
	end
	pValue = mean(abs(permDiff) >= abs(observedDiff));
	permOut = struct; permOut.ObservedSlope1 = fit1.Slope; permOut.ObservedSlope2 = fit2.Slope;
	permOut.ObservedDifference = observedDiff; permOut.PermutedDifference = permDiff;
	permOut.PValue = pValue; permOut.NPermutation = nPermutation;
end

function y = iSigmoidFromParams(p, x)
	[lower, upper, slope, midpoint] = iDecodeSigmoidParams(p);
	y = lower + (upper - lower) ./ (1 + exp(-slope .* (x - midpoint)));
end

function [lower, upper, slope, midpoint] = iDecodeSigmoidParams(p)
	lower = 1 ./ (1 + exp(-p(1))); upper = 1; slope = exp(p(2)); midpoint = exp(p(3));
end

function y = iLogit(x)
	x = min(max(x, 1e-6), 1 - 1e-6); y = log(x ./ (1 - x));
end

function [bestMouse, stats] = iFindBestRepresentativeMouse(T)
	% 对每鼠拟合 sigmoid，选与组 sigmoid 曲线最接近的鼠
	T = sortrows(T, {'Mouse','DateTime'});
	groupFit = iFitSigmoidCurve(T, "Group");
	xRef = 1:7;
	yRef = iSigmoidFromParams(groupFit.ParamRaw, xRef);
	mice = unique(string(T.Mouse));
	bestMSE = inf;
	bestMouse = mice(1);
	bestStats = struct('MSE', NaN, 'NSessions', 0, 'MouseSlope', NaN);
	for m = mice'
		rows = string(T.Mouse) == m & isfinite(double(T.Session)) & isfinite(double(T.Performance));
		if sum(rows) < 2, continue; end
		mouseT = T(rows, :);
		mouseT = sortrows(mouseT, 'DateTime');
		mouseT = iAddSessionIndex(mouseT);
		xM = double(mouseT.Session);
		yM = double(mouseT.Performance);
		% 插值到 xRef 上比较
		yInterp = interp1(xM, yM, xRef, 'linear', 'extrap');
		mse = mean((yInterp - yRef).^2, 'omitnan');
		if mse < bestMSE
			bestMSE = mse;
			bestMouse = m;
			bestStats.MSE = mse;
			bestStats.NSessions = sum(rows);
		end
	end
	stats = bestStats;
end

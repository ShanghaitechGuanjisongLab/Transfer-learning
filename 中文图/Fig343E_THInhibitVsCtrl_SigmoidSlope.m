% 中文图343E：TH抑制与对照组 Sigmoid 斜率
%
% 数据源使用英文图3G：
% - 对照组：TransferLearning.AudioLightBaseline
% - TH抑制组：TransferLearning.THInhibit + PO化学遗传抑制纯行为
%
% 样式模仿中文图313：两组学习曲线均值±SEM + Sigmoid fit。
% 命令行输出鼠数、Sigmoid斜率和鼠级置换检验P值。

svgName = "中文图Fig343E_THInhibitVsCtrl_SigmoidSlope.svg";

if ~exist('UniExp.DataSet','class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile,'file')
		matlab.project.loadProject(prjFile);
	end
end

CtrlDS = TransferLearning.AudioLightBaseline();
THDS = TransferLearning.THInhibit();

ctrlSessions = iBuildFig3GSessions(CtrlDS, "Ctrl");
thSessions = iBuildFig3GSessions(THDS, "TH");
poSessions = iBuildFig3GPOBehaviorSessions();
allSessions = [ctrlSessions; thSessions; poSessions];
if isempty(allSessions)
	error('Fig343E:EmptyData', 'No LightWater sessions found for Fig343E.');
end

allSessions = sortrows(allSessions, ["Group","Mouse","DateTime"]);
allSessions = iAddSessionIndex(allSessions);

displayedCtrl = iFilterToDisplayedMice(allSessions(string(allSessions.Group) == "Ctrl", :));
displayedTH = iFilterToDisplayedMice(allSessions(string(allSessions.Group) == "TH", :));
if isempty(displayedCtrl) || isempty(displayedTH)
	error('Fig343E:EmptyGroupAfterFilter', 'One group has no valid displayed mice after filtering.');
end

ctrlMouseN = numel(unique(string(displayedCtrl.Mouse)));
thMouseN = numel(unique(string(displayedTH.Mouse)));

sessionForSummary = allSessions(:, ["Mouse","DateTime","Performance","Group"]);
sessionForSummary.Group = string(sessionForSummary.Group);
sessionForSummary = sortrows(sessionForSummary, ["Group","Mouse","DateTime"]);
[~, summaryL] = evalc('UniExp.LearningSummarize(sessionForSummary)');
[meanMat, semMat, x] = iUnpackLearningSummarize(summaryL, ["Ctrl","TH"]);
nMat = iComputeNBySession(allSessions, x, ["Ctrl","TH"]);

fitCtrl = iFitSigmoidCurve(displayedCtrl, "Ctrl");
fitTH = iFitSigmoidCurve(displayedTH, "TH");
permResult = iPermutationTestSigmoidSlope(displayedCtrl, displayedTH, 10000, 1);

xFit = (1:max([max(fitCtrl.XObserved), max(fitTH.XObserved), max(x)])).';
ctrlFitCurve = iSigmoidFromParams(fitCtrl.ParamRaw, xFit);
thFitCurve = iSigmoidFromParams(fitTH.ParamRaw, xFit);

meanMatOut = nan(numel(xFit), size(meanMat, 2));
semMatOut = nan(numel(xFit), size(semMat, 2));
nMatOut = nan(numel(xFit), size(nMat, 2));
meanMatOut(1:size(meanMat, 1), :) = meanMat;
semMatOut(1:size(semMat, 1), :) = semMat;
nMatOut(1:size(nMat, 1), :) = nMat;

f = figure('Color', 'w', 'Name', 'Fig343E TH inhibition sigmoid slope');
f.Units = 'centimeters';
f.Position(3:4) = [12, 8];
t = tiledlayout(f, 1, 2, 'TileSpacing', 'tight', 'Padding', 'tight');

curveColor = [0 0 0];
axCtrl = nexttile(t, 1);
iPlotGroupMeanErrorbars(axCtrl, xFit, meanMatOut(:,1), semMatOut(:,1), ctrlFitCurve, curveColor, "Ctrl", fitCtrl, false);

axTH = nexttile(t, 2);
iPlotGroupMeanErrorbars(axTH, xFit, meanMatOut(:,2), semMatOut(:,2), thFitCurve, curveColor, "TH", fitTH, true);

ylabel(axCtrl, 'Hit rate', 'FontSize', 12);
xlabel(t, 'Block', 'FontSize', 12);
ylabel(axTH, '');
axTH.YAxis.Visible = 'off';

allAxes = findall(f, 'Type', 'axes');
for ax = reshape(allAxes, 1, [])
	if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
		ax.Toolbar.Visible = 'off';
	end
end

TransferLearning.Style.ApplyStandardFigureStyle(f, 2);
axTH.YAxis.Visible = 'off';
svgPath = TransferLearning.StandardFigureSvgPath(svgName);
print(f, svgPath, '-dsvg');

fitTable = table;
fitTable.Group = ["Ctrl"; "TH"];
fitTable.Lower = [fitCtrl.Lower; fitTH.Lower];
fitTable.Upper = [fitCtrl.Upper; fitTH.Upper];
fitTable.Slope = [fitCtrl.Slope; fitTH.Slope];
fitTable.Midpoint = [fitCtrl.Midpoint; fitTH.Midpoint];
fitTable.SSE = [fitCtrl.SSE; fitTH.SSE];
fitTable.RSquared = [fitCtrl.RSquared; fitTH.RSquared];
fitTable.NMouse = [ctrlMouseN; thMouseN];

permTable = table;
permTable.ObservedCtrlSlope = permResult.ObservedCtrlSlope;
permTable.ObservedTHSlope = permResult.ObservedTHSlope;
permTable.ObservedDifference = permResult.ObservedDifference;
permTable.PermutationPValue = permResult.PValue;
permTable.PermutationCount = permResult.NPermutation;
permTable.NullMeanDifference = mean(permResult.PermutedDifference, 'omitnan');
permTable.NullStdDifference = std(permResult.PermutedDifference, 'omitnan');
permTable.NullCI_Low = prctile(permResult.PermutedDifference, 2.5);
permTable.NullCI_High = prctile(permResult.PermutedDifference, 97.5);

summaryTable = table;
summaryTable.Block = xFit(:);
summaryTable.CtrlLearningCurve = meanMatOut(:,1);
summaryTable.THLearningCurve = meanMatOut(:,2);
summaryTable.CtrlSem = semMatOut(:,1);
summaryTable.THSem = semMatOut(:,2);
summaryTable.CtrlN = nMatOut(:,1);
summaryTable.THN = nMatOut(:,2);
summaryTable.CtrlSigmoid = ctrlFitCurve(:);
summaryTable.THSigmoid = thFitCurve(:);

fprintf('Wrote: %s\n', svgPath);
fprintf('Ctrl mice: %d\n', ctrlMouseN);
fprintf('TH mice: %d\n', thMouseN);
fprintf('Ctrl sigmoid: lower=%.4f, upper=%.4f, slope=%.4f, midpoint=%.4f, R^2=%.4f\n', fitCtrl.Lower, fitCtrl.Upper, fitCtrl.Slope, fitCtrl.Midpoint, fitCtrl.RSquared);
fprintf('TH sigmoid: lower=%.4f, upper=%.4f, slope=%.4f, midpoint=%.4f, R^2=%.4f\n', fitTH.Lower, fitTH.Upper, fitTH.Slope, fitTH.Midpoint, fitTH.RSquared);
fprintf('Permutation slope difference (TH - Ctrl): %.4f\n', permResult.ObservedDifference);
fprintf('Permutation two-sided p = %.4g (%d permutations)\n', permResult.PValue, permResult.NPermutation);

assignin('base', 'Fig343E_Sigmoid_AllSessions', allSessions);
assignin('base', 'Fig343E_Sigmoid_FitTable', fitTable);
assignin('base', 'Fig343E_Sigmoid_Summary', summaryTable);
assignin('base', 'Fig343E_Sigmoid_Permutation', permResult);

function out = iBuildFig3GSessions(DS, groupName)
	T = iQueryLightWaterBlocks(DS);
	if isempty(T)
		out = iEmptySessionsTable();
		return;
	end
	T.Group = repmat(string(groupName), height(T), 1);
	T.Mouse = string(T.Mouse);
	T.DateTime = iNormalizeDateTime(T.DateTime);
	out = iSessionizeByDateTime(T(:, intersect(T.Properties.VariableNames, {'Mouse','DateTime','Behavior','Performance','Group','Phase'}, 'stable')));
end

function out = iBuildFig3GPOBehaviorSessions()
	out = iEmptySessionsTable();
	poMatPath = "\\Data-Server-2\个人数据\张天夫\202505\化学遗传抑制PO.v1.mat";
	if ~exist(poMatPath, 'file')
		return;
	end
	PO = UniExp.DataSet(poMatPath);
	T = PO.TableQuery(["Mouse","DateTime","Performance","Phase"], Design="LightWater", Expression="溢出");
	if isempty(T)
		return;
	end
	T.Mouse = string(T.Mouse);
	T.DateTime = iNormalizeDateTime(T.DateTime);
	if ismember('Phase', T.Properties.VariableNames)
		T.Phase = string(T.Phase);
		T(T.Phase == "Recall", :) = [];
	else
		T.Phase = strings(height(T), 1);
	end
	if isempty(T)
		return;
	end
	T.Group = repmat("TH", height(T), 1);
	out = unique(T(:, {'Group','Mouse','DateTime','Performance','Phase'}), 'rows');
end

function T = iQueryLightWaterBlocks(DS)
	varsTry = ["Mouse","DateTime","Stimulus","Phase","Behavior"];
	varsFallback = ["Mouse","DateTime","Stimulus","Phase","Performance"];
	try
		T = DS.TableQuery(varsTry, Stimulus="LightWater");
	catch
		T = DS.TableQuery(varsFallback, Stimulus="LightWater");
	end
	if isempty(T)
		return;
	end
	T.Stimulus = string(T.Stimulus);
	T = T(T.Stimulus == "LightWater", :);
end

function T = iEmptySessionsTable()
	T = table(string.empty(0,1), string.empty(0,1), NaT(0,1), nan(0,1), string.empty(0,1), ...
		'VariableNames', {'Group','Mouse','DateTime','Performance','Phase'});
end

function dt = iNormalizeDateTime(dt)
	dt = datetime(dt);
	if isdatetime(dt) && ~isempty(dt.TimeZone)
		dt.TimeZone = '';
	end
end

function S = iSessionizeByDateTime(T)
	useBehavior = ismember('Behavior', string(T.Properties.VariableNames));
	if ~ismember('Phase', string(T.Properties.VariableNames))
		T.Phase = repmat(missing, height(T), 1);
	end
	if useBehavior
		T = T(:, {'Mouse','DateTime','Behavior','Phase','Group'});
	else
		T = T(:, {'Mouse','DateTime','Performance','Phase','Group'});
	end
	T.Mouse = string(T.Mouse);
	T.Group = string(T.Group);
	T = sortrows(T, {'Group','Mouse','DateTime'});
	if useBehavior
		val = double(T.Behavior);
	else
		val = double(T.Performance);
	end
	[G, groupList, mouseList, dtList] = findgroups(T.Group, T.Mouse, T.DateTime);
	perf = splitapply(@(x) mean(x, 'omitnan'), val, G);
	phaseSession = splitapply(@(x) iPickSessionPhase(x), string(T.Phase), G);
	S = table(groupList, mouseList, dtList, perf, phaseSession, 'VariableNames', {'Group','Mouse','DateTime','Performance','Phase'});
end

function ph = iPickSessionPhase(phases)
	phases = string(phases);
	phases = phases(~ismissing(phases) & phases ~= "");
	if isempty(phases)
		ph = "";
		return;
	end
	[u,~,ic] = unique(phases);
	counts = accumarray(ic, 1);
	[~,ix] = max(counts);
	ph = u(ix);
end

function T = iAddSessionIndex(T)
	T.Group = string(T.Group);
	T.Mouse = string(T.Mouse);
	T = sortrows(T, {'Group','Mouse','DateTime'});
	[G, ~] = findgroups(T.Group, T.Mouse);
	sessCell = splitapply(@(x) {(1:numel(x))'}, T.DateTime, G);
	T.Session = vertcat(sessCell{:});
end

function T = iFilterToDisplayedMice(T)
	if isempty(T)
		return;
	end
	rows = isfinite(double(T.Session)) & isfinite(double(T.Performance));
	shownMice = unique(string(T.Mouse(rows)), 'stable');
	T = T(ismember(string(T.Mouse), shownMice), :);
end

function [meanMat, semMat, x] = iUnpackLearningSummarize(summaryL, groupOrder)
	groupOrder = string(groupOrder);
	if ~istable(summaryL)
		if isstruct(summaryL)
			summaryL = struct2table(summaryL);
		else
			error('Fig343E:InvalidLearningSummarizeOutput', 'LearningSummarize output must be table or struct.');
		end
	end

	meanCurve = summaryL.MeanCurve;
	semCurve = summaryL.SemCurve;
	meanCells = meanCurve(:);
	semCells = semCurve(:);
	if ~isempty(summaryL.Properties.RowNames)
		rn = string(summaryL.Properties.RowNames);
	else
		rn = strings(numel(meanCells),1);
	end

	idx = nan(1, numel(groupOrder));
	for k = 1:numel(groupOrder)
		if all(rn == "")
			if k <= numel(meanCells)
				idx(k) = k;
			end
		else
			ix = find(rn == groupOrder(k), 1, 'first');
			if ~isempty(ix)
				idx(k) = ix;
			end
		end
	end

	maxLen = 0;
	for k = 1:numel(groupOrder)
		if ~isfinite(idx(k))
			continue;
		end
		mv = meanCells{idx(k)};
		sv = semCells{idx(k)};
		maxLen = max(maxLen, max(numel(mv), numel(sv)));
	end
	meanMat = nan(maxLen, numel(groupOrder));
	semMat = nan(maxLen, numel(groupOrder));
	for k = 1:numel(groupOrder)
		if ~isfinite(idx(k))
			continue;
		end
		mv = double(meanCells{idx(k)}(:));
		sv = double(semCells{idx(k)}(:));
		meanMat(1:numel(mv), k) = mv;
		semMat(1:numel(sv), k) = sv;
	end
	x = (1:maxLen).';
end

function nMat = iComputeNBySession(T, x, groups)
	groups = string(groups);
	x = double(x(:));
	nMat = zeros(numel(x), numel(groups));
	T.Group = string(T.Group);
	T.Session = double(T.Session);
	for g = 1:numel(groups)
		rowsG = (T.Group == groups(g));
		for s = 1:numel(x)
			rowsS = rowsG & (T.Session == s) & isfinite(double(T.Performance));
			if any(rowsS)
				nMat(s,g) = numel(unique(string(T.Mouse(rowsS))));
			end
		end
	end
end

function iPlotGroupMeanErrorbars(ax, blockX, meanCurve, semCurve, yFit, lineColor, groupName, fitStruct, showLegend)
	hold(ax, 'on');
	ax.FontSize = 12;
	blockX = double(blockX(:));
	meanCurve = double(meanCurve(:));
	semCurve = double(semCurve(:));
	rows = isfinite(blockX) & isfinite(meanCurve);
	semCurve(~isfinite(semCurve)) = 0;
	dataHandle = errorbar(ax, blockX(rows), meanCurve(rows), semCurve(rows), semCurve(rows), 'o', ...
		'LineStyle', 'none', ...
		'Color', lineColor, ...
		'MarkerEdgeColor', lineColor, ...
		'MarkerFaceColor', 'w', ...
		'MarkerSize', 3, ...
		'LineWidth', 0.5, ...
		'CapSize', 5);
	fitHandle = plot(ax, blockX, yFit, '-', 'Color', lineColor, 'LineWidth', 2.8);
	if showLegend && isgraphics(dataHandle)
		lg = legend(ax, [dataHandle, fitHandle], {'Mean ± SEM', 'Sigmoid fit'}, 'Location', 'southeast');
		lg.FontSize = 9;
		lg.Box = 'off';
		lg.NumColumns = 1;
	else
		legend(ax, 'off');
	end
	box(ax, 'off');
	grid(ax, 'off');
	title(ax, {char(groupName), sprintf('slope=%.3f', fitStruct.Slope)}, 'FontSize', 10, 'FontWeight', 'normal');
end

function fitOut = iFitSigmoidCurve(T, groupName)
	T = sortrows(T, {'Mouse','DateTime'});
	xObs = double(T.Session(:));
	yObs = double(T.Performance(:));
	use = isfinite(xObs) & isfinite(yObs);
	xObs = xObs(use);
	yObs = yObs(use);
	if isempty(xObs)
		error('Fig343E:NoDataForGroup', 'No valid session data for group %s.', char(groupName));
	end

	slopeStarts = [0, 0.2, 0.8, 2, 5, 20];
	midpointStarts = unique([median(xObs), min(xObs), max(xObs), min(xObs) - numel(xObs), max(xObs) + numel(xObs)]);
	obj = @(p) sum((yObs - iSigmoidFromParams(p, xObs)).^2, 'omitnan');
	opt = optimset('Display', 'off', 'MaxFunEvals', 10000, 'MaxIter', 10000);
	bestSse = inf;
	p = [sqrt(0.8); median(xObs)];
	for iSlope = 1:numel(slopeStarts)
		for iMidpoint = 1:numel(midpointStarts)
			p0 = [sqrt(slopeStarts(iSlope)); midpointStarts(iMidpoint)];
			pTry = fminsearch(obj, p0, opt);
			sseTry = obj(pTry);
			if sseTry < bestSse
				bestSse = sseTry;
				p = pTry;
			end
		end
	end
	yHat = iSigmoidFromParams(p, xObs);
	SSE = sum((yObs - yHat).^2, 'omitnan');
	SST = sum((yObs - mean(yObs, 'omitnan')).^2, 'omitnan');
	if SST == 0
		rSquared = NaN;
	else
		rSquared = 1 - SSE / SST;
	end
	[lower, upper, slope, midpoint] = iDecodeSigmoidParams(p);
	fitOut = struct;
	fitOut.Group = string(groupName);
	fitOut.ParamRaw = p;
	fitOut.Lower = lower;
	fitOut.Upper = upper;
	fitOut.Slope = slope;
	fitOut.Midpoint = midpoint;
	fitOut.SSE = SSE;
	fitOut.RSquared = rSquared;
	fitOut.XObserved = xObs;
	fitOut.YObserved = yObs;
end

function permOut = iPermutationTestSigmoidSlope(TCtrl, TTH, nPermutation, rngSeed)
	if nargin < 3 || isempty(nPermutation)
		nPermutation = 2000;
	end
	if nargin >= 4 && ~isempty(rngSeed)
		rng(rngSeed);
	end
	TCtrl = sortrows(TCtrl, {'Mouse','DateTime'});
	TTH = sortrows(TTH, {'Mouse','DateTime'});
	ctrlMice = unique(string(TCtrl.Mouse), 'stable');
	thMice = unique(string(TTH.Mouse), 'stable');
	allMouseTables = cell(numel(ctrlMice) + numel(thMice), 1);
	for i = 1:numel(ctrlMice)
		allMouseTables{i} = TCtrl(string(TCtrl.Mouse) == ctrlMice(i), :);
	end
	for i = 1:numel(thMice)
		allMouseTables{numel(ctrlMice) + i} = TTH(string(TTH.Mouse) == thMice(i), :);
	end
	fitCtrl = iFitSigmoidCurve(TCtrl, "Ctrl");
	fitTH = iFitSigmoidCurve(TTH, "TH");
	observedDiff = fitTH.Slope - fitCtrl.Slope;
	permDiff = nan(nPermutation, 1);
	nCtrl = numel(ctrlMice);
	parfor iPerm = 1:nPermutation
		ord = randperm(numel(allMouseTables));
		idxCtrl = ord(1:nCtrl);
		idxTH = ord(nCtrl+1:end);
		permCtrl = vertcat(allMouseTables{idxCtrl});
		permTH = vertcat(allMouseTables{idxTH});
		fitPermCtrl = iFitSigmoidCurve(permCtrl, "CtrlPerm");
		fitPermTH = iFitSigmoidCurve(permTH, "THPerm");
		permDiff(iPerm) = fitPermTH.Slope - fitPermCtrl.Slope;
	end
	pValue = mean(abs(permDiff) >= abs(observedDiff));
	permOut = struct;
	permOut.ObservedCtrlSlope = fitCtrl.Slope;
	permOut.ObservedTHSlope = fitTH.Slope;
	permOut.ObservedDifference = observedDiff;
	permOut.PermutedDifference = permDiff;
	permOut.PValue = pValue;
	permOut.NPermutation = nPermutation;
end

function y = iSigmoidFromParams(p, x)
	[lower, upper, slope, midpoint] = iDecodeSigmoidParams(p);
	y = lower + (upper - lower) ./ (1 + exp(-slope .* (x - midpoint)));
end

function [lower, upper, slope, midpoint] = iDecodeSigmoidParams(p)
	lower = 0;
	upper = 1;
	slope = p(1).^2;
	midpoint = p(2);
end

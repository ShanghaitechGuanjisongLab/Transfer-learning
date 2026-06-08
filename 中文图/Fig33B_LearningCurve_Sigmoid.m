% Fig33B: Naive vs Continual LightWater group learning curve + per-mouse slope bar

if ~exist('UniExp.DataSet','class')
	thisFile = mfilename('fullpath');
	thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, 'Transferlearning.prj');
	if ~exist(prjFile, 'file')
		prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	end
	if exist(prjFile,'file')
		matlab.project.loadProject(prjFile);
	end
end

LAB  = TransferLearning.LightAudioBaseline();
ALB  = TransferLearning.AudioLightBaseline();
LAPB = TransferLearning.LAPureBehavior();
ALPB = TransferLearning.ALPureBehavior();
LAI  = TransferLearning.LAInterspersed();

naiveAnchors = ["Naive","Learned"];
tranAnchors  = ["Transfer","Final"];

naiveA = iLightWaterSessionsByMouse(LAB,  "LightAudioBaseline", true,  naiveAnchors(1), naiveAnchors(2));
naiveB = iLightWaterSessionsByMouse(LAPB, "LAPureBehavior",     false, naiveAnchors(1), naiveAnchors(2));
naiveC = iLightWaterSessionsByMouse_LAInterspersed(LAI, "LAInterspersed", false, naiveAnchors(1), naiveAnchors(2));
tranA  = iLightWaterSessionsByMouse(ALB,  "AudioLightBaseline", true,  tranAnchors(1), tranAnchors(2));
tranB  = iLightWaterSessionsByMouse(ALPB, "ALPureBehavior",     false, tranAnchors(1), tranAnchors(2));

naive = [naiveA; naiveB; naiveC];
tran  = [tranA; tranB];
naive.Group(:) = "Naive";
tran.Group(:)  = "Transfer";

iAssertNoCrossSourceDuplicateMice(naive, "Naive");
iAssertNoCrossSourceDuplicateMice(tran, "Transfer");

allSessions = [naive; tran];
iAssertNoMouseAppearsInMultipleGroups(allSessions);
if isempty(allSessions)
	error('Fig33B:EmptyData', 'No LightWater sessions found.');
end

allSessions = sortrows(allSessions, ["Group","Mouse","DateTime"]);
allSessions = iAddSessionIndex(allSessions);

displayedNaive = iFilterToDisplayedMice(allSessions(string(allSessions.Group) == "Naive", :));
displayedTransfer = iFilterToDisplayedMice(allSessions(string(allSessions.Group) == "Transfer", :));
naiveMouseN = numel(unique(string(displayedNaive.Mouse)));
transferMouseN = numel(unique(string(displayedTransfer.Mouse)));

sessionForSummary = allSessions(:, ["Mouse","DateTime","Performance","Group"]);
sessionForSummary.Group = string(sessionForSummary.Group);
sessionForSummary = sortrows(sessionForSummary, ["Group","Mouse","DateTime"]);
[~, SummaryL] = evalc('UniExp.LearningSummarize(sessionForSummary)');
[meanMat, semMat, x] = iUnpackLearningSummarize(SummaryL, ["Naive","Transfer"]);
nMat = iComputeNBySession(allSessions, x, ["Naive","Transfer"]);

fitNaive = iFitSigmoidCurve(displayedNaive, "Naive");
fitTransfer = iFitSigmoidCurve(displayedTransfer, "Transfer");
permResult = iPermutationTestSigmoidSlope(displayedNaive, displayedTransfer, 10000, 1);
groupP = TransferLearning.Style.TwoWayAnovaGroupPValue(allSessions, 'Performance', 'Session', 'Group', 'Mouse');
sessionsForAnova7 = allSessions(allSessions.Session <= 7, :);
groupP7 = TransferLearning.Style.TwoWayAnovaGroupPValue(sessionsForAnova7, 'Performance', 'Session', 'Group', 'Mouse');

% Per-mouse blocks to 50% hit rate
naiveBlocks50 = iPerMouseBlocksTo50(displayedNaive);
transferBlocks50 = iPerMouseBlocksTo50(displayedTransfer);

xMax = max([max(fitNaive.XObserved), max(fitTransfer.XObserved), max(x)]);
xSummary = (1:xMax).';
xFit = linspace(1, xMax, 200).';
naiveFitCurve = iSigmoidFromParams(fitNaive.ParamRaw, xFit);
transferFitCurve = iSigmoidFromParams(fitTransfer.ParamRaw, xFit);

meanMatOut = nan(numel(xSummary), size(meanMat, 2));
semMatOut = nan(numel(xSummary), size(semMat, 2));
nMatOut = nan(numel(xSummary), size(nMat, 2));
meanMatOut(1:size(meanMat, 1), :) = meanMat;
semMatOut(1:size(semMat, 1), :) = semMat;
nMatOut(1:size(nMat, 1), :) = nMat;
%% Group learning curve

f = figure('Color', 'w', 'Name', 'Fig33B Learning curve');
f.Units = 'centimeters';
f.Position(3:4) = [12, 8];
f.PaperUnits = 'centimeters';
f.PaperSize = [12, 8];
f.PaperPositionMode = 'auto';

curveColors = TransferLearning.GroupColors(["Naive","Continual"]);
curveColorNaive = curveColors(1, :);
curveColorTransfer = curveColors(2, :);
ax = axes(f);
hold(ax, 'on');
hNaive = iPlotGroupMeanErrorbarsSingleAx(ax, xSummary, meanMatOut(:,1), semMatOut(:,1), xFit, naiveFitCurve, curveColorNaive);
hTransfer = iPlotGroupMeanErrorbarsSingleAx(ax, xSummary, meanMatOut(:,2), semMatOut(:,2), xFit, transferFitCurve, curveColorTransfer);

ylabel(ax, 'Hit rate', 'FontSize', 12);
xlabel(ax, 'Block', 'FontSize', 12);
ax.FontSize = 12;
ax.LineWidth = 2;
ax.Color = 'none';
box(ax, 'off');
grid(ax, 'off');
title(ax, '');

naiveLastIndex = find(isfinite(meanMatOut(:, 1)), 1, 'last');
transferLastIndex = find(isfinite(meanMatOut(:, 2)), 1, 'last');
naiveLast = meanMatOut(naiveLastIndex, 1);
transferLast = meanMatOut(transferLastIndex, 2);
yLow = min([naiveLast, transferLast], [], 'omitnan');
yHigh = max([naiveLast, transferLast], [], 'omitnan');
yBottom = yLow;
yTop = yHigh;
if yTop - yBottom < 0.2
	yMid = mean([yBottom, yTop], 'omitnan');
	yBottom = yMid - 0.1;
	yTop = yMid + 0.1;
end
% Horizontal P-value line spanning blocks 1-7 (positions based on ylim range ratio)
max7Naive = max(meanMatOut(1:min(7, end), 1), [], 'omitnan');
max7Transfer = max(meanMatOut(1:min(7, end), 2), [], 'omitnan');
yTop7 = max(max7Naive, max7Transfer);
yl = ylim(ax); yrange = yl(2) - yl(1);
yPLine = yTop7 + 0.08 * yrange;
textY = yPLine + 0.1 * yrange;
plot(ax, [1, 7], [yPLine, yPLine], 'k-', 'LineWidth', 1);
if groupP7 < 0.001, starStr = '＊＊＊＊'; else, starStr = TransferLearning.Style.iFormatPText(groupP7); end
text(ax, 4, textY, starStr, ...
	'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', 'FontSize', 12);

% Clean yticks: remove values > 1
yt = yticks(ax);
yticks(ax, yt(yt <= 1 + 1e-6));

lgd = legend(ax, [hNaive(1), hNaive(2), hTransfer(1), hTransfer(2)], ...
	{'Naive Mean ± SEM', 'Naive Sigmoid', 'Continual Mean ± SEM', 'Continual Sigmoid'}, ...
	'Location', 'southoutside', 'NumColumns', 2);
lgd.Box = 'off';
lgd.FontSize = 10;

allAxes = findall(f, 'Type', 'axes');
for axItem = reshape(allAxes, 1, [])
	if isprop(axItem, 'Toolbar') && ~isempty(axItem.Toolbar)
		axItem.Toolbar.Visible = 'off';
	end
end

svgPath = TransferLearning.ExportStandardFigure(f, 2, '中文图Fig33B_LearningCurve_Sigmoid.svg');

%% Per-mouse blocks-to-50% bar
blocks50Naive = naiveBlocks50.BlocksTo50;
blocks50Transfer = transferBlocks50.BlocksTo50;
blocks50Naive = blocks50Naive(isfinite(blocks50Naive));
blocks50Transfer = blocks50Transfer(isfinite(blocks50Transfer));

edgeColorsBar = TransferLearning.GroupColors(["Naive","Continual"]);
f2 = figure( 'Name', 'Fig33B per-mouse slope');
f2.Units = 'centimeters';
f2.Position(3:4) = [4, 3];
f2.PaperUnits = 'centimeters';
f2.PaperSize = [4, 3];
f2.PaperPositionMode = 'auto';

tiledlayout(1, 1, 'TileSpacing', 'tight', 'Padding', 'tight');
nexttile;
[~, optional2, bars2, errorBars2] = UniExp.BarScatterCompare({blocks50Naive(:), blocks50Transfer(:)}, table([1 2], 'VariableNames', {'GroupPair'}), 'AsteriskThreshold', 1);
ax2 = gca;
delete(findobj(ax2, 'Type', 'Scatter'));
ax2.FontSize = 12;
ax2.LineWidth = 2;
if isprop(ax2.XAxis, 'LineWidth')
	ax2.XAxis.LineWidth = 2;
	ax2.YAxis.LineWidth = 2;
end
ax2.Color = 'none';
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
svgPath2 = TransferLearning.ExportStandardFigureTransparent(f2, 2, '中文图Fig33B_PerMouseSlopeBar.svg');

%% Output
fprintf('Wrote: %s\n', svgPath);
fprintf('Wrote: %s\n', svgPath2);
fprintf('\n=== 中文图33B ===\n');
fprintf('Naive mice: %d\n', naiveMouseN);
fprintf('Continual mice: %d\n', transferMouseN);
fprintf('Naive sigmoid: lower=%.4f, upper=%.4f, slope=%.4f, midpoint=%.4f, R^2=%.4f\n', fitNaive.Lower, fitNaive.Upper, fitNaive.Slope, fitNaive.Midpoint, fitNaive.RSquared);
fprintf('Continual sigmoid: lower=%.4f, upper=%.4f, slope=%.4f, midpoint=%.4f, R^2=%.4f\n', fitTransfer.Lower, fitTransfer.Upper, fitTransfer.Slope, fitTransfer.Midpoint, fitTransfer.RSquared);
fprintf('Two-way ANOVA Group P (all blocks) = %.4g\n', groupP);
fprintf('Two-way ANOVA Group P (blocks 1-7) = %.4g\n', groupP7);
fprintf('Per-mouse blocks-to-50%% bar P (BarScatterCompare) = %s\n', TransferLearning.Style.iFormatPText(optional2.MultiCompare.PValue(1)));

assignin('base', 'Fig33B_AllSessions', allSessions);
assignin('base', 'Fig33B_NaiveBlocksTo50', naiveBlocks50);
assignin('base', 'Fig33B_TransferBlocksTo50', transferBlocks50);

% ====== Local functions ======

function out = iLightWaterSessionsByMouse(DS, sourceName, imagingCohort, startPhase, endPhase)
	T = iQueryLightWaterBehaviorAll(DS);
	if isempty(T)
		out = table(string.empty(0,1), NaT(0,1), nan(0,1), strings(0,1), false(0,1), nan(0,1), ...
			'VariableNames', {'Mouse','DateTime','Performance','Source','ImagingCohort','NBlocksInSession'});
		return;
	end
	T.Mouse = string(T.Mouse);
	T.DateTime = iNormalizeDateTime(T.DateTime);
	T = iSessionizeByDateTime(T);
	T = iSelectSessionsBetweenPhases(T, startPhase, endPhase);
	T.Source = repmat(string(sourceName), height(T), 1);
	T.ImagingCohort = repmat(logical(imagingCohort), height(T), 1);
	out = T(:, {'Mouse','DateTime','Performance','Source','ImagingCohort','NBlocksInSession'});
end

function out = iLightWaterSessionsByMouse_LAInterspersed(DS, sourceName, imagingCohort, startPhase, endPhase)
	if string(startPhase) == "Naive" || string(endPhase) == "Naive"
		badMice = iFindMiceWithAudioWaterInPhase(DS, "Naive");
	else
		badMice = string.empty(0,1);
	end
	T = iQueryLightWaterBehaviorAll(DS);
	if isempty(T)
		out = table(string.empty(0,1), NaT(0,1), nan(0,1), strings(0,1), false(0,1), nan(0,1), ...
			'VariableNames', {'Mouse','DateTime','Performance','Source','ImagingCohort','NBlocksInSession'});
		return;
	end
	T.Mouse = string(T.Mouse);
	if ~isempty(badMice), T = T(~ismember(T.Mouse, badMice), :); end
	T.DateTime = iNormalizeDateTime(T.DateTime);
	T = iSessionizeByDateTime(T);
	T = iSelectSessionsBetweenPhases(T, startPhase, endPhase);
	T.Source = repmat(string(sourceName), height(T), 1);
	T.ImagingCohort = repmat(logical(imagingCohort), height(T), 1);
	out = T(:, {'Mouse','DateTime','Performance','Source','ImagingCohort','NBlocksInSession'});
end

function dt = iNormalizeDateTime(dt)
	dt = datetime(dt);
	if isdatetime(dt) && ~isempty(dt.TimeZone), dt.TimeZone = ''; end
end

function T = iQueryLightWaterBehaviorAll(DS)
	varsTry = ["Mouse","DateTime","Stimulus","Phase","Behavior"];
	varsFallback = ["Mouse","DateTime","Stimulus","Phase","Performance"];
	try
		T = DS.TableQuery(varsTry, Stimulus="LightWater");
	catch
		T = DS.TableQuery(varsFallback, Stimulus="LightWater");
	end
	if isempty(T), return; end
	T.Stimulus = string(T.Stimulus);
	T = T(T.Stimulus == "LightWater", :);
end

function S = iSelectSessionsBetweenPhases(S, startPhase, endPhase)
	startPhase = string(startPhase); endPhase = string(endPhase);
	if isempty(S), return; end
	S.Mouse = string(S.Mouse); S.Phase = string(S.Phase);
	S = sortrows(S, {'Mouse','DateTime'});
	mice = unique(S.Mouse);
	keepRows = false(height(S),1);
	for i = 1:numel(mice)
		idx = find(S.Mouse == mice(i));
		st = find(S.Phase(idx) == startPhase, 1, 'first');
		if isempty(st), continue; end
		ed = find(S.Phase(idx) == endPhase & (1:numel(idx))' >= st, 1, 'first');
		if isempty(ed), ed = numel(idx); end
		keepRows(idx(st:ed)) = true;
	end
	S = S(keepRows, :);
end

function badMice = iFindMiceWithAudioWaterInPhase(DS, phaseName)
	badMice = string.empty(0,1);
	Ta = DS.TableQuery("Mouse", Stimulus="AudioWater", Phase=phaseName);
	if ~isempty(Ta) && ismember("Mouse", string(Ta.Properties.VariableNames))
		badMice = unique(string(Ta.Mouse));
	end
end

function S = iSessionizeByDateTime(T)
	useBehavior = ismember('Behavior', string(T.Properties.VariableNames));
	if ~ismember('Phase', T.Properties.VariableNames), T.Phase = repmat(missing, height(T), 1); end
	if useBehavior
		T = T(:, {'Mouse','DateTime','Behavior','Phase'});
	else
		T = T(:, {'Mouse','DateTime','Performance','Phase'});
	end
	T.Mouse = string(T.Mouse); T = sortrows(T, {'Mouse','DateTime'});
	if useBehavior, val = double(T.Behavior); else, val = double(T.Performance); end
	[G, mouseKeys, dtKeys] = findgroups(T.Mouse, T.DateTime);
	perf = splitapply(@(x) mean(x, 'omitnan'), val, G);
	nBlocks = splitapply(@(x) sum(isfinite(x)), val, G);
	phaseSession = splitapply(@(x) iPickSessionPhase(x), string(T.Phase), G);
	S = table(mouseKeys, dtKeys, perf, nBlocks, phaseSession, 'VariableNames', {'Mouse','DateTime','Performance','NBlocksInSession','Phase'});
end

function ph = iPickSessionPhase(phases)
	[u,~,ic] = unique(phases); counts = accumarray(ic, 1); [~,ix] = max(counts); ph = u(ix);
end

function iAssertNoCrossSourceDuplicateMice(T, groupName)
	if isempty(T), return; end
	T.Mouse = string(T.Mouse); T.Source = string(T.Source);
	[G, mice] = findgroups(T.Mouse);
	nSrc = splitapply(@(x) numel(unique(string(x))), T.Source, G);
	dup = mice(nSrc > 1);
	if ~isempty(dup)
		error('Fig33B:DuplicateMouseAcrossSources', 'Group %s has duplicated mice.', char(string(groupName)));
	end
end

function iAssertNoMouseAppearsInMultipleGroups(T)
	if isempty(T), return; end
	T.Mouse = string(T.Mouse); T.Group = string(T.Group);
	[G, mice] = findgroups(T.Mouse);
	nG = splitapply(@(x) numel(unique(string(x))), T.Group, G);
	if any(nG > 1), error('Fig33B:MouseInMultipleGroups', 'Mice appear in multiple groups.'); end
end

function T = iAddSessionIndex(T)
	T.Mouse = string(T.Mouse); T = sortrows(T, {'Group','Mouse','DateTime'});
	[G, ~] = findgroups(T.Group, T.Mouse);
	sessCell = splitapply(@(x) {(1:numel(x))'}, T.DateTime, G);
	T.Session = vertcat(sessCell{:});
end

function [meanMat, semMat, x] = iUnpackLearningSummarize(SummaryL, groupOrder)
	groupOrder = string(groupOrder);
	if ~istable(SummaryL)
		if isstruct(SummaryL), SummaryL = struct2table(SummaryL);
		else, error('Fig33B:InvalidLearningSummarizeOutput'); end
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
	hE = errorbar(ax, xObs, meanObs, semObs, 'o', 'Color', curveColor, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', curveColor, ...
		'MarkerSize', 4.5, 'LineWidth', 1.5, 'CapSize', 4, 'LineStyle', 'none');
	hP = plot(ax, xFit, fitCurve, '-', 'Color', curveColor, 'LineWidth', 2.2);
	hOut = [hE, hP];
end

function fitOut = iFitSigmoidCurve(T, groupName)
	T = sortrows(T, {'Mouse','DateTime'});
	xObs = double(T.Session(:)); yObs = double(T.Performance(:));
	use = isfinite(xObs) & isfinite(yObs); xObs = xObs(use); yObs = yObs(use);
	if isempty(xObs), error('Fig33B:NoDataForGroup', 'No data for %s.', char(groupName)); end
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

function permOut = iPermutationTestSigmoidSlope(TNaive, TTransfer, nPermutation, rngSeed)
	if nargin < 3 || isempty(nPermutation), nPermutation = 2000; end
	if nargin >= 4 && ~isempty(rngSeed), rng(rngSeed); end
	TNaive = sortrows(TNaive, {'Mouse','DateTime'});
	TTransfer = sortrows(TTransfer, {'Mouse','DateTime'});
	naiveMice = unique(string(TNaive.Mouse), 'stable');
	transferMice = unique(string(TTransfer.Mouse), 'stable');
	allMouseTables = cell(numel(naiveMice) + numel(transferMice), 1);
	for i = 1:numel(naiveMice), allMouseTables{i} = TNaive(string(TNaive.Mouse) == naiveMice(i), :); end
	for i = 1:numel(transferMice), allMouseTables{numel(naiveMice) + i} = TTransfer(string(TTransfer.Mouse) == transferMice(i), :); end
	fitNaive = iFitSigmoidCurve(TNaive, "Naive");
	fitTransfer = iFitSigmoidCurve(TTransfer, "Transfer");
	observedDiff = fitTransfer.Slope - fitNaive.Slope;
	permDiff = nan(nPermutation, 1); nNaive = numel(naiveMice);
	parfor iPerm = 1:nPermutation
		ord = randperm(numel(allMouseTables));
		permNaive = vertcat(allMouseTables{ord(1:nNaive)});
		permTransfer = vertcat(allMouseTables{ord(nNaive+1:end)});
		fitPermNaive = iFitSigmoidCurve(permNaive, "NaivePerm");
		fitPermTransfer = iFitSigmoidCurve(permTransfer, "TransferPerm");
		permDiff(iPerm) = fitPermTransfer.Slope - fitPermNaive.Slope;
	end
	pValue = mean(abs(permDiff) >= abs(observedDiff));
	permOut = struct; permOut.ObservedNaiveSlope = fitNaive.Slope; permOut.ObservedTransferSlope = fitTransfer.Slope;
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

function slopeOut = iPerMouseSlopeSessions(Sess)
	if isempty(Sess), slopeOut = table(string.empty(0,1), nan(0,1), 'VariableNames', {'Mouse','Slope'}); return; end
	Sess = sortrows(Sess, {'Mouse','DateTime'});
	mice = unique(string(Sess.Mouse)); slopeVec = nan(numel(mice), 1);
	for iM = 1:numel(mice)
		m = mice(iM); R = sortrows(Sess(string(Sess.Mouse) == m, :), 'DateTime');
		if height(R) < 2, continue; end
		perf = double(R.Performance);
		reached = find(perf >= 1.0, 1, 'first');
		if isempty(reached), continue; end % never reached 100% → exclude from per-mouse slope
		R = R(1:reached, :); % truncate after first 100%
		R.Performance(end) = 1; % ensure last point is exactly 1
		perf = double(R.Performance);
		if height(R) < 2 || numel(unique(perf)) < 2, continue; end
		fitTable = R(:, {'Mouse','DateTime','Performance'}); fitTable.Group = repmat("Fit", height(fitTable), 1);
		fitTable = movevars(fitTable, 'Group', 'Before', 'Mouse'); fitTable.Session = (1:height(fitTable))';
		fitOut = iFitSigmoidCurvePerMouse(fitTable, m); slopeVec(iM) = fitOut.Slope;
	end
	slopeOut = table(mice, slopeVec, 'VariableNames', {'Mouse','Slope'});
end

function fitOut = iFitSigmoidCurvePerMouse(T, groupName)
	xObs = double(T.Session(:)); yObs = double(T.Performance(:));
	use = isfinite(xObs) & isfinite(yObs); xObs = xObs(use); yObs = yObs(use);
	slopeStarts = [0, 0.2, 0.8, 2, 5, 20];
	midpointStarts = unique([median(xObs), min(xObs), max(xObs), min(xObs) - numel(xObs), max(xObs) + numel(xObs)]);
	opt = optimset('Display', 'off', 'MaxFunEvals', 10000, 'MaxIter', 10000);
	obj = @(p) sum((yObs - iSigmoidFromFixedLowerParams(p, xObs)).^2, 'omitnan');
	bestSse = inf; p = [sqrt(0.8); median(xObs)];
	for iSlope = 1:numel(slopeStarts)
		for iMidpoint = 1:numel(midpointStarts)
			p0 = [sqrt(slopeStarts(iSlope)); midpointStarts(iMidpoint)];
			pTry = fminsearch(obj, p0, opt); sseTry = obj(pTry);
			if sseTry < bestSse, bestSse = sseTry; p = pTry; end
		end
	end
	yHat = iSigmoidFromFixedLowerParams(p, xObs);
	sse = sum((yObs - yHat).^2, 'omitnan'); sst = sum((yObs - mean(yObs, 'omitnan')).^2, 'omitnan');
	if sst == 0, rSquared = NaN; else, rSquared = 1 - sse / sst; end
	[lower, upper, slope, midpoint] = iDecodeFixedLowerSigmoidParams(p);
	fitOut = struct; fitOut.Group = string(groupName); fitOut.ParamRaw = p;
	fitOut.Lower = lower; fitOut.Upper = upper; fitOut.Slope = slope; fitOut.Midpoint = midpoint;
	fitOut.SSE = sse; fitOut.RSquared = rSquared; fitOut.XObserved = xObs; fitOut.YObserved = yObs;
end

function y = iSigmoidFromFixedLowerParams(p, x)
	[lower, upper, slope, midpoint] = iDecodeFixedLowerSigmoidParams(p);
	y = lower + (upper - lower) ./ (1 + exp(-slope .* (x - midpoint)));
end

function [lower, upper, slope, midpoint] = iDecodeFixedLowerSigmoidParams(p)
	lower = 0; upper = 1; slope = p(1).^2; midpoint = p(2);
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
		if isempty(reached), continue; end % never reached 100% — exclude
		R = R(1:reached, :);
		R.Performance(end) = 1;
		hit50 = find(double(R.Performance) >= 0.5, 1, 'first');
		if isempty(hit50), continue; end
		blocksVec(iM) = hit50;
	end
	out = table(mice, blocksVec, 'VariableNames', {'Mouse','BlocksTo50'});
end

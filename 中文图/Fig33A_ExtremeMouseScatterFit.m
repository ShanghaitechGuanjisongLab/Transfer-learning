% Fig33A: Extreme-mouse LightWater naive (lowest slope) vs Transfer (highest slope)
% scatter + sigmoid fits on a single axis (like Fig33B)
%
% Shares data loading with Fig33B. Applies carry-forward + truncation rule:
% only mice that reached 100% are included; data truncated after first 100%.

if ~exist('UniExp.DataSet','class')
	thisFile = mfilename('fullpath'); thisDir = fileparts(thisFile);
	prjFile = fullfile(thisDir, 'Transferlearning.prj');
	if ~exist(prjFile, 'file'), prjFile = fullfile(thisDir, '..', 'Transferlearning.prj'); end
	if exist(prjFile,'file'), matlab.project.loadProject(prjFile); end
end

LAB  = TransferLearning.LightAudioBaseline();
ALB  = TransferLearning.AudioLightBaseline();
LAPB = TransferLearning.LAPureBehavior(); ALPB = TransferLearning.ALPureBehavior(); LAI = TransferLearning.LAInterspersed();
naiveAnchors = ["Naive","Learned"]; tranAnchors = ["Transfer","Final"];

naiveA = iLightWaterSessionsByMouse(LAB,  "LightAudioBaseline", true,  naiveAnchors(1), naiveAnchors(2));
naiveB = iLightWaterSessionsByMouse(LAPB, "LAPureBehavior",     false, naiveAnchors(1), naiveAnchors(2));
naiveC = iLightWaterSessionsByMouse_LAInterspersed(LAI, "LAInterspersed", false, naiveAnchors(1), naiveAnchors(2));
tranA  = iLightWaterSessionsByMouse(ALB,  "AudioLightBaseline", true,  tranAnchors(1), tranAnchors(2));
tranB  = iLightWaterSessionsByMouse(ALPB, "ALPureBehavior",     false, tranAnchors(1), tranAnchors(2));

naive = [naiveA; naiveB; naiveC]; naive.Group(:) = "Naive";
tran  = [tranA; tranB];          tran.Group(:)  = "Transfer";
allSessions = [naive; tran];
allSessions = sortrows(allSessions, ["Group","Mouse","DateTime"]);
allSessions = iAddSessionIndex(allSessions);

displayedNaive = iFilterToDisplayedMice(allSessions(string(allSessions.Group) == "Naive", :));
displayedTransfer = iFilterToDisplayedMice(allSessions(string(allSessions.Group) == "Transfer", :));

% Per-mouse slopes with carry-forward + truncation
naiveSlopeData = iPerMouseSlopeSessions(displayedNaive);
transferSlopeData = iPerMouseSlopeSessions(displayedTransfer);

slopeN = naiveSlopeData.Slope; miceN = naiveSlopeData.Mouse;
slopeT = transferSlopeData.Slope; miceT = transferSlopeData.Mouse;
keepN = isfinite(slopeN); slopeN = slopeN(keepN); miceN = miceN(keepN);
keepT = isfinite(slopeT); slopeT = slopeT(keepT); miceT = miceT(keepT);

% Ensure selected mice have at least 3 data points (sessions)
nSessN = iCountSessionsPerMouse(displayedNaive, miceN);
nSessT = iCountSessionsPerMouse(displayedTransfer, miceT);
enoughN = nSessN >= 3;
enoughT = nSessT >= 3;
slopeN = slopeN(enoughN); miceN = miceN(enoughN);
slopeT = slopeT(enoughT); miceT = miceT(enoughT);

[~, idxMinN] = min(slopeN); mouseMinN = miceN(idxMinN);
[~, idxMaxT] = max(slopeT); mouseMaxT = miceT(idxMaxT);

% Extract & truncate individual session data
naiveSess = iLoadPerMouseTruncatedSessions(displayedNaive, mouseMinN);
tranSess  = iLoadPerMouseTruncatedSessions(displayedTransfer, mouseMaxT);

fitN = iFitSigmoidCurvePerMouse_33(naiveSess, mouseMinN);
fitT = iFitSigmoidCurvePerMouse_33(tranSess, mouseMaxT);

%% Single-axis figure like Fig33B
f = figure('Color', 'w', 'Name', 'Fig33A Extreme mouse learning');
f.Units = 'centimeters'; f.Position(3:4) = [12, 8];
f.PaperUnits = 'centimeters'; f.PaperSize = [12, 8]; f.PaperPositionMode = 'auto';

curveColors = [TransferLearning.NaiveColor;TransferLearning.TransferColor];
ax = axes(f); hold(ax, 'on');

% Naive (lowest slope)
xN = double(naiveSess.Session(:)); yN = double(naiveSess.Performance(:));
hN = scatter(ax, xN, yN, 50, curveColors(1,:), 'o');

% Transfer (highest slope)
xT = double(tranSess.Session(:)); yT = double(tranSess.Performance(:));
hT = scatter(ax, xT, yT, 50, curveColors(2,:), 'o');

% Shared sigmoid fit X range: data min-1 to max+1
xFit = linspace(min([xN; xT]) - 1, max([xN; xT]) + 1, 200)';
plot(ax, xFit, iSigmoidFromFixedLowerParams(fitN.ParamRaw, xFit), '-', ...
	'Color', curveColors(1,:), 'LineWidth', 2.2, 'Tag', 'TransferLearningSupplementalLine');
plot(ax, xFit, iSigmoidFromFixedLowerParams(fitT.ParamRaw, xFit), '-', ...
	'Color', curveColors(2,:), 'LineWidth', 2.2, 'Tag', 'TransferLearningSupplementalLine');

xlabel(ax, 'Block', 'FontSize', 12); ylabel(ax, 'Hit rate');
ax.FontSize = 12; ax.LineWidth = 2; ax.Color = 'none';
box(ax, 'off'); grid(ax, 'off'); title(ax, '');

legend(ax, [hN, hT], {'Naive', 'Transfer'}, 'Location', 'best', 'Box', 'off');
title('Representative mice');
TransferLearning.ApplyStandardExportStyle(f, 2);
ax.YTick(ax.YTick<0-eps|ax.YTick>1+eps)=[];
svgPath = TransferLearning.StandardFigureSvgPath('中文图Fig33A_ExtremeMouseScatterFit.svg');
print(f, svgPath, '-dsvg');

fprintf('Wrote: %s\n', svgPath);
fprintf('\n=== 中文图33A ===\n');
fprintf('Naive lowest-slope mouse: %s, slope=%.4f\n', mouseMinN, fitN.Slope);
fprintf('Transfer highest-slope mouse: %s, slope=%.4f\n', mouseMaxT, fitT.Slope);

% ====== Local functions ======

function out = iLightWaterSessionsByMouse(DS, sourceName, imagingCohort, startPhase, endPhase)
	T = iQueryLightWaterBehaviorAll(DS);
	if isempty(T), out = iEmptySess(); return; end
	T.Mouse = string(T.Mouse); T.DateTime = iNormDt(T.DateTime);
	T = iSessionizeByDateTime(T); T = iSelectSessionsBetweenPhases(T, startPhase, endPhase);
	T.Source = repmat(string(sourceName), height(T), 1);
	T.ImagingCohort = repmat(logical(imagingCohort), height(T), 1);
	out = T(:, {'Mouse','DateTime','Performance','Source','ImagingCohort','NBlocksInSession'});
end

function out = iLightWaterSessionsByMouse_LAInterspersed(DS, sourceName, imagingCohort, startPhase, endPhase)
	badMice = string.empty(0,1);
	if string(startPhase)=="Naive"||string(endPhase)=="Naive", badMice = iFindAudioMice(DS, "Naive"); end
	T = iQueryLightWaterBehaviorAll(DS);
	if isempty(T), out = iEmptySess(); return; end
	T.Mouse = string(T.Mouse); if ~isempty(badMice), T = T(~ismember(T.Mouse, badMice), :); end
	T.DateTime = iNormDt(T.DateTime); T = iSessionizeByDateTime(T);
	T = iSelectSessionsBetweenPhases(T, startPhase, endPhase);
	T.Source = repmat(string(sourceName), height(T), 1);
	T.ImagingCohort = repmat(logical(imagingCohort), height(T), 1);
	out = T(:, {'Mouse','DateTime','Performance','Source','ImagingCohort','NBlocksInSession'});
end

function out = iEmptySess()
	out = table(string.empty(0,1), NaT(0,1), nan(0,1), strings(0,1), false(0,1), nan(0,1), ...
		'VariableNames', {'Mouse','DateTime','Performance','Source','ImagingCohort','NBlocksInSession'});
end

function dt = iNormDt(dt), dt = datetime(dt); if isdatetime(dt) && ~isempty(dt.TimeZone), dt.TimeZone = ''; end, end

function T = iQueryLightWaterBehaviorAll(DS)
	varsTry = ["Mouse","DateTime","Stimulus","Phase","Behavior"];
	varsFallback = ["Mouse","DateTime","Stimulus","Phase","Performance"];
	try, T = DS.TableQuery(varsTry, Stimulus="LightWater"); catch, T = DS.TableQuery(varsFallback, Stimulus="LightWater"); end
	if isempty(T), return; end
	T.Stimulus = string(T.Stimulus); T = T(T.Stimulus == "LightWater", :);
end

function S = iSelectSessionsBetweenPhases(S, startPhase, endPhase)
	startPhase = string(startPhase); endPhase = string(endPhase); if isempty(S), return; end
	S.Mouse = string(S.Mouse); S.Phase = string(S.Phase); S = sortrows(S, {'Mouse','DateTime'});
	mice = unique(S.Mouse); keepRows = false(height(S),1);
	for i = 1:numel(mice)
		idx = find(S.Mouse == mice(i)); st = find(S.Phase(idx) == startPhase, 1, 'first');
		if isempty(st), continue; end
		ed = find(S.Phase(idx) == endPhase & (1:numel(idx))' >= st, 1, 'first');
		if isempty(ed), ed = numel(idx); end
		keepRows(idx(st:ed)) = true;
	end, S = S(keepRows, :);
end

function badMice = iFindAudioMice(DS, phaseName)
	badMice = string.empty(0,1);
	Ta = DS.TableQuery("Mouse", Stimulus="AudioWater", Phase=phaseName);
	if ~isempty(Ta) && ismember("Mouse", string(Ta.Properties.VariableNames)), badMice = unique(string(Ta.Mouse)); end
end

function S = iSessionizeByDateTime(T)
	useBehavior = ismember('Behavior', string(T.Properties.VariableNames));
	if ~ismember('Phase', T.Properties.VariableNames), T.Phase = repmat(missing, height(T), 1); end
	T = T(:, intersect(T.Properties.VariableNames, {'Mouse','DateTime','Behavior','Phase','Performance'}, 'stable'));
	T.Mouse = string(T.Mouse); T = sortrows(T, {'Mouse','DateTime'});
	if useBehavior, val = double(T.Behavior); else, val = double(T.Performance); end
	[G, mouseKeys, dtKeys] = findgroups(T.Mouse, T.DateTime);
	perf = splitapply(@(x) mean(x, 'omitnan'), val, G);
	nBlocks = splitapply(@(x) sum(isfinite(x)), val, G);
	phaseSession = splitapply(@(x) iPickPhase(x), string(T.Phase), G);
	S = table(mouseKeys, dtKeys, perf, nBlocks, phaseSession, 'VariableNames', {'Mouse','DateTime','Performance','NBlocksInSession','Phase'});
end

function ph = iPickPhase(phases), [u,~,ic] = unique(phases); counts = accumarray(ic, 1); [~,ix] = max(counts); ph = u(ix); end

function iAssertNoCrossSourceDuplicateMice(T, groupName)
	if isempty(T), return; end
	T.Mouse = string(T.Mouse); T.Source = string(T.Source);
	[G, ~] = findgroups(T.Mouse); nSrc = splitapply(@(x) numel(unique(string(x))), T.Source, G);
	if any(nSrc > 1), error('Fig33A:DuplicateMouse', 'Group %s duplicated.', char(string(groupName))); end
end

function iAssertNoMouseAppearsInMultipleGroups(T)
	if isempty(T), return; end
	T.Mouse = string(T.Mouse); T.Group = string(T.Group);
	[G, ~] = findgroups(T.Mouse); nG = splitapply(@(x) numel(unique(string(x))), T.Group, G);
	if any(nG > 1), error('Fig33A:MouseInMultipleGroups'); end
end

function T = iAddSessionIndex(T)
	T.Mouse = string(T.Mouse); T = sortrows(T, {'Group','Mouse','DateTime'});
	[G, ~] = findgroups(T.Group, T.Mouse); sessCell = splitapply(@(x) {(1:numel(x))'}, T.DateTime, G);
	T.Session = vertcat(sessCell{:});
end

function T = iFilterToDisplayedMice(T)
	if isempty(T), return; end
	rows = isfinite(double(T.Session)) & isfinite(double(T.Performance));
	shownMice = unique(string(T.Mouse(rows)), 'stable'); T = T(ismember(string(T.Mouse), shownMice), :);
end

function sessOut = iLoadPerMouseTruncatedSessions(Sess, mouseName)
	R = sortrows(Sess(string(Sess.Mouse) == mouseName, :), 'DateTime');
	perf = double(R.Performance);
	reached = find(perf >= 1.0, 1, 'first');
	if ~isempty(reached)
		R = R(1:reached, :); R.Performance(end) = 1;
	end
	R.Session = (1:height(R))';
	sessOut = R;
end

function slopeOut = iPerMouseSlopeSessions(Sess)
	if isempty(Sess), slopeOut = table(string.empty(0,1), nan(0,1), 'VariableNames', {'Mouse','Slope'}); return; end
	Sess = sortrows(Sess, {'Mouse','DateTime'}); mice = unique(string(Sess.Mouse)); slopeVec = nan(numel(mice), 1);
	for iM = 1:numel(mice)
		m = mice(iM); R = sortrows(Sess(string(Sess.Mouse) == m, :), 'DateTime');
		if height(R) < 2, continue; end
		perf = double(R.Performance); reached = find(perf >= 1.0, 1, 'first');
		if isempty(reached), continue; end
		R = R(1:reached, :); R.Performance(end) = 1; perf = double(R.Performance);
		if height(R) < 2 || numel(unique(perf)) < 2, continue; end
		fitTable = R(:, {'Mouse','DateTime','Performance'}); fitTable.Group = repmat("Fit", height(fitTable), 1);
		fitTable = movevars(fitTable, 'Group', 'Before', 'Mouse'); fitTable.Session = (1:height(fitTable))';
		fitOut = iFitSigmoidCurvePerMouse_33(fitTable, m); slopeVec(iM) = fitOut.Slope;
	end
	slopeOut = table(mice, slopeVec, 'VariableNames', {'Mouse','Slope'});
end

function fitOut = iFitSigmoidCurvePerMouse_33(T, groupName)
	T = sortrows(T, {'Mouse','DateTime'}); xObs = double(T.Session(:)); yObs = double(T.Performance(:));
	use = isfinite(xObs) & isfinite(yObs); xObs = xObs(use); yObs = yObs(use);
	slopeStarts = [0, 0.2, 0.8, 2, 5, 20];
	midpointStarts = unique([median(xObs), min(xObs), max(xObs), min(xObs) - numel(xObs), max(xObs) + numel(xObs)]);
	opt = optimset('Display', 'off', 'MaxFunEvals', 10000, 'MaxIter', 10000);
	obj = @(p) sum((yObs - iSigmoidFromFixedLowerParams(p, xObs)).^2, 'omitnan');
	bestSse = inf; p = [sqrt(0.8); median(xObs)];
	for iSlope = 1:numel(slopeStarts)
		for iMidpoint = 1:numel(midpointStarts)
			pTry = fminsearch(obj, [sqrt(slopeStarts(iSlope)); midpointStarts(iMidpoint)], opt);
			if obj(pTry) < bestSse, bestSse = obj(pTry); p = pTry; end
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

function sessCounts = iCountSessionsPerMouse(Sess, mice)
	mice = string(mice); Sess.Mouse = string(Sess.Mouse);
	sessCounts = zeros(numel(mice), 1);
	for i = 1:numel(mice)
		R = Sess(Sess.Mouse == mice(i), :);
		perf = double(R.Performance);
		reached = find(perf >= 1.0, 1, 'first');
		if ~isempty(reached), R = R(1:reached, :); end
		sessCounts(i) = height(R);
	end
end

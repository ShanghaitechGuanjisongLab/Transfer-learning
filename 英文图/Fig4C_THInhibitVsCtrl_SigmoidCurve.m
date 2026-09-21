% English Fig4C: thalamus (PO) inhibited vs Control light-water learning,
% group-level sigmoid fits (caliber copied from Chinese Fig61B)
%
% Data (identical to Chinese Fig61B / old Fig3G):
% - Control: TransferLearning.AudioLightBaseline
% - TH:      TransferLearning.THInhibit imaging mice + PO chemogenetic
%            inhibition behavior-only mice (\\Data-Server-2\个人数据\张天夫\202505\
%            化学遗传抑制PO.v1.mat, Design="LightWater", Expression="溢出",
%            Recall sessions excluded) merged into the TH group
%
% Per-mouse sigmoid fits use carry-forward performance (a reaching-100% mouse
% is filled with 1.0 for all later sessions, matching UniExp.LearningSummarize
% scatter points). The learning-curve group effect is the two-way ANOVA group
% term over blocks 1-7 (Performance ~ Session * Group + (1|Mouse)), i.e. the
% same statistic as Chinese Fig61B, Fig3B and Fig2H — NOT a permutation test.
%
% Claim: thalamus inhibition lowers the learning slope but leaves first-block
% performance unchanged.
%
% Outputs (SVG):
%   - English_Fig4C_THInhibitVsCtrl_SigmoidCurve.svg   (legend -> Scale = 2)
%
% Execution (hard requirement):
% - Keep this file as a script (do NOT convert to function).
% - Open in MATLAB Editor and Run/F5.

outDirUNC = fullfile('\\Data-Server-2\个人数据\张天夫', char(datetime('now', 'Format', 'yyyyMM')));
svgName = "English_Fig4C_THInhibitVsCtrl_SigmoidCurve.svg";

thisDir = fileparts(mfilename('fullpath'));
if ~exist('UniExp.DataSet', 'class')
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file')
		matlab.project.loadProject(prjFile);
	end
end

CtrlDS = TransferLearning.AudioLightBaseline();
THDS = TransferLearning.THInhibit();

% ---------- sessions (Ctrl + TH imaging + PO behavior-only) ----------
ctrlSessions = iBuildFig3GSessions(CtrlDS, "Ctrl");
thSessions = iBuildFig3GSessions(THDS, "TH");
poSessions = iBuildFig3GPOBehaviorSessions();
allSessions = [ctrlSessions; thSessions; poSessions];
if isempty(allSessions)
	error('English_Fig4C:EmptyData', 'No LightWater sessions found for Fig4C.');
end

allSessions = sortrows(allSessions, ["Group","Mouse","DateTime"]);
allSessions = iAddSessionIndex(allSessions);

displayedCtrl = iFilterToDisplayedMice(allSessions(string(allSessions.Group) == "Ctrl", :));
displayedTH = iFilterToDisplayedMice(allSessions(string(allSessions.Group) == "TH", :));
if isempty(displayedCtrl) || isempty(displayedTH)
	error('English_Fig4C:EmptyGroupAfterFilter', 'One group has no valid displayed mice after filtering.');
end

ctrlMouseN = numel(unique(string(displayedCtrl.Mouse)));
thMouseN = numel(unique(string(displayedTH.Mouse)));

sessionForSummary = allSessions(:, ["Mouse","DateTime","Performance","Group"]);
sessionForSummary.Group = string(sessionForSummary.Group);
sessionForSummary = sortrows(sessionForSummary, ["Group","Mouse","DateTime"]);
[~, summaryL] = evalc('UniExp.LearningSummarize(sessionForSummary)');
[meanMat, semMat, x] = iUnpackLearningSummarize(summaryL, ["Ctrl","TH"]);
nMat = iComputeNBySession(allSessions, x, ["Ctrl","TH"]);

% ---------- per-mouse sigmoid fits on carry-forward data ----------
fitCtrl = iFitSigmoidCurve(iCarryForwardSessions(displayedCtrl), "Ctrl");
fitTH = iFitSigmoidCurve(iCarryForwardSessions(displayedTH), "TH");
groupSessions = iCarryForwardSessions([displayedCtrl; displayedTH]);
groupP = TransferLearning.Style.TwoWayAnovaGroupPValue(groupSessions, 'Performance', 'Session', 'Group', 'Mouse');
sessions7 = groupSessions(groupSessions.Session <= 7, :);
groupP7 = TransferLearning.Style.TwoWayAnovaGroupPValue(sessions7, 'Performance', 'Session', 'Group', 'Mouse');

xSummary = (1:max([max(fitCtrl.XObserved), max(fitTH.XObserved), max(x)])).';
xFit = linspace(max(0, min(xSummary) - 1), max(xSummary) + 1, 200).';
ctrlFitCurve = iSigmoidFromParams(fitCtrl.ParamRaw, xFit);
thFitCurve = iSigmoidFromParams(fitTH.ParamRaw, xFit);

meanMatOut = nan(numel(xSummary), size(meanMat, 2));
semMatOut = nan(numel(xSummary), size(semMat, 2));
nMatOut = nan(numel(xSummary), size(nMat, 2));
meanMatOut(1:size(meanMat, 1), :) = meanMat;
semMatOut(1:size(semMat, 1), :) = semMat;
nMatOut(1:size(nMat, 1), :) = nMat;

% ---------- figure ----------
% 规范：基础高 4 cm；有 legend 放大 ×2 → 8 cm；宽 12 cm（多曲线+图例）
f = figure('Color', 'w', 'Name', 'English Fig4C TH vs Control sigmoid');
f.Units = 'centimeters';
f.Position(3:4) = [12, 8];
f.PaperUnits = 'centimeters';
f.PaperSize = [12, 8];
f.PaperPositionMode = 'auto';
ax = axes(f);
hold(ax, 'on');
curveColors = [TransferLearning.TransferColor; TransferLearning.ColorB];
hCtrl = iPlotGroupMeanErrorbars(ax, xSummary, meanMatOut(:,1), semMatOut(:,1), xFit, ctrlFitCurve, curveColors(1, :));
hTH = iPlotGroupMeanErrorbars(ax, xSummary, meanMatOut(:,2), semMatOut(:,2), xFit, thFitCurve, curveColors(2, :));

ylabel(ax, 'Hit rate');
xlabel(ax, 'Block');
ax.Color = 'none';
box(ax, 'off');
grid(ax, 'off');

% blocks 1-7 组效应 P 值线（manual plot + text，同 Fig3B；带 PLine/PText tag 供导出重调线宽）
max7Ctrl = max(meanMatOut(1:min(7, end), 1), [], 'omitnan');
max7TH = max(meanMatOut(1:min(7, end), 2), [], 'omitnan');
yTop7 = max(max7Ctrl, max7TH);
yl = ylim(ax);
yrange = yl(2) - yl(1);
yPLine = yTop7;
plot(ax, [1, 7], [yPLine, yPLine], 'k-', 'LineWidth', 1, 'Tag', 'PLine_1', 'HandleVisibility', 'off');
textY = yPLine + 0.2 * yrange;
starStr = TransferLearning.Style.iFormatPText(groupP7);
text(ax, 4, textY, starStr, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', 'Tag', 'PText_1', AffectAutoLimits = true);

xlim(ax, [0, 20]);
yt = yticks(ax);
yticks(ax, yt(yt <= 1 + 1e-6));

lgd = legend(ax, [hCtrl(1), hTH(1)], {'Control', 'TH inhibited'}, 'Location', 'southeast');
lgd.Box = 'off';
lgd.AutoUpdate = false;

if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
	ax.Toolbar.Visible = 'off';
end

if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end
svgPath = TransferLearning.ExportStandardFigure(f, 2, svgName);
fprintf('Wrote: %s\n', svgPath);

fprintf('=== English Fig4C TH vs Control sigmoid ===\n');
fprintf('Ctrl mice: %d | TH mice: %d\n', ctrlMouseN, thMouseN);
fprintf('Ctrl sigmoid: slope=%.4f, midpoint=%.4f, R^2=%.4f\n', fitCtrl.Slope, fitCtrl.Midpoint, fitCtrl.RSquared);
fprintf('TH   sigmoid: slope=%.4f, midpoint=%.4f, R^2=%.4f\n', fitTH.Slope, fitTH.Midpoint, fitTH.RSquared);
fprintf('Two-way ANOVA Group P (blocks 1-7) = %.4g\n', groupP7);
fprintf('Two-way ANOVA Group P (all blocks) = %.4g\n', groupP);

% first-block hit rate (claim: unchanged)
f1 = allSessions(allSessions.Session == 1, :);
c1 = f1.Performance(f1.Group == "Ctrl");
t1 = f1.Performance(f1.Group == "TH");
[pFirst, ~] = ranksum(c1, t1);
fprintf('First block: Ctrl %.3f +/- %.3f (n=%d) vs TH %.3f +/- %.3f (n=%d), rank-sum p = %.4g\n', ...
	mean(c1,'omitnan'), iSem(c1), sum(isfinite(c1)), mean(t1,'omitnan'), iSem(t1), sum(isfinite(t1)), pFirst);

fitTable = table(["Ctrl"; "TH"], ...
	[fitCtrl.Slope; fitTH.Slope], [fitCtrl.Midpoint; fitTH.Midpoint], ...
	[fitCtrl.RSquared; fitTH.RSquared], [ctrlMouseN; thMouseN], ...
	'VariableNames', {'Group','Slope','Midpoint','RSquared','NMouse'});

assignin('base', 'Fig4C_SessionTable', allSessions);
assignin('base', 'Fig4C_SigmoidStats', fitTable);
assignin('base', 'Fig4C_ANOVA', struct('p7', groupP7, 'pAll', groupP, 'pFirst', pFirst));

%% ========== local functions (copied from Chinese Fig61B) ==========
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

function T = iCarryForwardSessions(T)
% Fill Performance=1 for all sessions after a mouse first reaches 100%,
% matching the carry-forward used by UniExp.LearningSummarize.
if isempty(T)
	return;
end
T = sortrows(T, {'Mouse', 'Session'});
mice = unique(string(T.Mouse));
maxSession = max(double(T.Session));
outPieces = cell(numel(mice), 1);
for iM = 1:numel(mice)
	mM = T(string(T.Mouse) == mice(iM), :);
	xm = double(mM.Session);
	ym = double(mM.Performance);
	reached = find(ym >= 1.0, 1, 'first');
	if isempty(reached)
		outPieces{iM} = mM;
		continue;
	end
	sessReached = xm(reached);
	if sessReached >= maxSession
		outPieces{iM} = mM;
		continue;
	end
	fillBlocks = (sessReached + 1 : maxSession)';
	newRows = mM(1, :);
	newRows = repmat(newRows, numel(fillBlocks), 1);
	newRows.Session = fillBlocks;
	newRows.Performance = repmat(1, numel(fillBlocks), 1);
	outPieces{iM} = [mM; newRows];
end
T = sortrows(vertcat(outPieces{:}), {'Mouse', 'Session'});
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
		error('English_Fig4C:InvalidLearningSummarizeOutput', 'LearningSummarize output must be table or struct.');
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

function hOut = iPlotGroupMeanErrorbars(ax, xSummary, meanCurve, semCurve, xFit, fitCurve, lineColor)
hold(ax, 'on');
xSummary = double(xSummary(:));
meanCurve = double(meanCurve(:));
semCurve = double(semCurve(:));
rows = isfinite(xSummary) & isfinite(meanCurve);
semCurve(~isfinite(semCurve)) = 0;
dataHandle = errorbar(ax, xSummary(rows), meanCurve(rows), semCurve(rows), 'o', ...
	'Color', lineColor, 'MarkerFaceColor', lineColor, 'MarkerEdgeColor', lineColor, ...
	'MarkerSize', 4, 'LineWidth', 1, 'CapSize', 4, 'LineStyle', 'none');
fitHandle = plot(ax, xFit, fitCurve, '-', 'Color', lineColor, 'LineWidth', 1, 'Tag', 'TransferLearningSupplementalLine');
hOut = [dataHandle, fitHandle];
end

function fitOut = iFitSigmoidCurve(T, groupName)
T = sortrows(T, {'Mouse','DateTime'});
xObs = double(T.Session(:));
yObs = double(T.Performance(:));
use = isfinite(xObs) & isfinite(yObs);
xObs = xObs(use);
yObs = yObs(use);
if isempty(xObs)
	error('English_Fig4C:NoDataForGroup', 'No valid session data for group %s.', char(groupName));
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

function s = iSem(v)
v = v(:);
ok = isfinite(v);
if ~any(ok)
	s = NaN;
	return;
end
s = std(v(ok)) / sqrt(sum(ok));
end

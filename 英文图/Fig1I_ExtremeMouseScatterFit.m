% 英文图1I：模仿中文图33A，展示 Naive 最低斜率鼠与12 h迁移最高斜率鼠的光水学习曲线。
% 沿用模板的会话筛选、首次100%命中率截断、至少三个会话要求及固定上下限 sigmoid 多起点拟合。
% 散点与拟合线按队列使用 ColorNaive/255、Color12h/255；这两只极端鼠不代表队列平均表现。
% 输出 English_Fig1I_ExtremeMouseScatterFit.svg；保持脚本形式，在 MATLAB 编辑器中运行。

if ~exist('UniExp.DataSet', 'class')
	thisDir = fileparts(mfilename('fullpath'));
	prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
	if exist(prjFile, 'file'), matlab.project.loadProject(prjFile); end
end

LAB = TransferLearning.LightAudioBaseline();
ALB = TransferLearning.AudioLightBaseline();
LAPB = TransferLearning.LAPureBehavior();
ALPB = TransferLearning.ALPureBehavior();
LAI = TransferLearning.LAInterspersed();
naiveAnchors = ["Naive", "Learned"];
tranAnchors = ["Transfer", "Final"];

naiveA = iLightWaterSessionsByMouse(LAB, "LightAudioBaseline", true, naiveAnchors(1), naiveAnchors(2));
naiveB = iLightWaterSessionsByMouse(LAPB, "LAPureBehavior", false, naiveAnchors(1), naiveAnchors(2));
naiveC = iLightWaterSessionsByMouse_LAInterspersed(LAI, "LAInterspersed", false, naiveAnchors(1), naiveAnchors(2));
tranA = iLightWaterSessionsByMouse(ALB, "AudioLightBaseline", true, tranAnchors(1), tranAnchors(2));
tranB = iLightWaterSessionsByMouse(ALPB, "ALPureBehavior", false, tranAnchors(1), tranAnchors(2));

naive = [naiveA; naiveB; naiveC];
naive.Group(:) = "Naive";
tran = [tranA; tranB];
tran.Group(:) = "Transfer";
allSessions = sortrows([naive; tran], ["Group", "Mouse", "DateTime"]);
allSessions = iAddSessionIndex(allSessions);
displayedNaive = iFilterToDisplayedMice(allSessions(string(allSessions.Group) == "Naive", :));
displayedTransfer = iFilterToDisplayedMice(allSessions(string(allSessions.Group) == "Transfer", :));

naiveSlopeData = iPerMouseSlopeSessions(displayedNaive);
transferSlopeData = iPerMouseSlopeSessions(displayedTransfer);
slopeN = naiveSlopeData.Slope;
miceN = naiveSlopeData.Mouse;
slopeT = transferSlopeData.Slope;
miceT = transferSlopeData.Mouse;
keepN = isfinite(slopeN);
slopeN = slopeN(keepN); miceN = miceN(keepN);
keepT = isfinite(slopeT);
slopeT = slopeT(keepT); miceT = miceT(keepT);
nSessN = iCountSessionsPerMouse(displayedNaive, miceN);
nSessT = iCountSessionsPerMouse(displayedTransfer, miceT);
enoughN = nSessN >= 3;
enoughT = nSessT >= 3;
slopeN = slopeN(enoughN); miceN = miceN(enoughN);
slopeT = slopeT(enoughT); miceT = miceT(enoughT);
if isempty(slopeN) || isempty(slopeT)
	error('Fig1I:NoEligibleMice', '两个队列均须有达到100%%命中率且至少三个会话的有效鼠。');
end
[~, idxMinN] = min(slopeN); mouseMinN = miceN(idxMinN);
[~, idxMaxT] = max(slopeT); mouseMaxT = miceT(idxMaxT);
naiveSess = iLoadPerMouseTruncatedSessions(displayedNaive, mouseMinN);
tranSess = iLoadPerMouseTruncatedSessions(displayedTransfer, mouseMaxT);
fitN = iFitSigmoidCurvePerMouse_33(naiveSess, mouseMinN);
fitT = iFitSigmoidCurvePerMouse_33(tranSess, mouseMaxT);
%%

fig = figure('Color', 'w', 'Name', 'English Fig1I extreme mouse learning');
fig.Units = 'centimeters'; fig.Position(3:4) = [12, 8];
fig.PaperUnits = 'centimeters'; fig.PaperSize = [12, 8]; fig.PaperPositionMode = 'auto';
curveColors = [TransferLearning.ColorNaive; TransferLearning.Color12h] / 255;
ax = axes(fig); hold(ax, 'on');
xN = double(naiveSess.Session(:)); yN = double(naiveSess.Performance(:));
xT = double(tranSess.Session(:)); yT = double(tranSess.Performance(:));
hN = scatter(ax, xN, yN, 50, curveColors(1, :), 'o');
hT = scatter(ax, xT, yT, 50, curveColors(2, :), 'o');
xFit = linspace(min([xN; xT]) - 1, max([xN; xT]) + 1, 200)';
plot(ax, xFit, iSigmoidFromFixedLowerParams(fitN.ParamRaw, xFit), '-', 'Color', curveColors(1, :), 'LineWidth', 2.2, 'Tag', 'TransferLearningSupplementalLine');
plot(ax, xFit, iSigmoidFromFixedLowerParams(fitT.ParamRaw, xFit), '-', 'Color', curveColors(2, :), 'LineWidth', 2.2, 'Tag', 'TransferLearningSupplementalLine');
xlabel(ax, 'Block', 'FontSize', 12); ylabel(ax, 'Hit rate');
ax.FontSize = 12; ax.LineWidth = 2; ax.Color = 'none';
box(ax, 'off'); grid(ax, 'off');
legend(ax, [hN, hT], {'Naive', '12 h'}, 'Location', 'best', 'Box', 'off');
title(ax, 'Representative mice');
if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar), ax.Toolbar.Visible = 'off'; end
TransferLearning.ApplyStandardExportStyle(fig, 2);
ax.YTick(ax.YTick < 0 - eps | ax.YTick > 1 + eps) = [];
svgPath = TransferLearning.StandardFigureSvgPath('English_Fig1I_ExtremeMouseScatterFit.svg');
print(fig, svgPath, '-dsvg');
fprintf('Wrote: %s\n', svgPath);
fprintf('\n=== 英文图1I ===\n');
fprintf('Naive 最低斜率鼠：%s，斜率=%.4f\n', mouseMinN, fitN.Slope);
fprintf('12 h 最高斜率鼠：%s，斜率=%.4f\n', mouseMaxT, fitT.Slope);

%% 局部函数
function out = iLightWaterSessionsByMouse(DS, sourceName, imagingCohort, startPhase, endPhase)
	data = iQueryLightWaterBehaviorAll(DS);
	if isempty(data), out = iEmptySess(); return; end
	data.Mouse = string(data.Mouse); data.DateTime = iNormDt(data.DateTime);
	data = iSessionizeByDateTime(data); data = iSelectSessionsBetweenPhases(data, startPhase, endPhase);
	data.Source = repmat(string(sourceName), height(data), 1);
	data.ImagingCohort = repmat(logical(imagingCohort), height(data), 1);
	out = data(:, {'Mouse', 'DateTime', 'Performance', 'Source', 'ImagingCohort', 'NBlocksInSession'});
end

function out = iLightWaterSessionsByMouse_LAInterspersed(DS, sourceName, imagingCohort, startPhase, endPhase)
	badMice = string.empty(0, 1);
	if string(startPhase) == "Naive" || string(endPhase) == "Naive", badMice = iFindAudioMice(DS, "Naive"); end
	data = iQueryLightWaterBehaviorAll(DS);
	if isempty(data), out = iEmptySess(); return; end
	data.Mouse = string(data.Mouse);
	if ~isempty(badMice), data = data(~ismember(data.Mouse, badMice), :); end
	data.DateTime = iNormDt(data.DateTime); data = iSessionizeByDateTime(data);
	data = iSelectSessionsBetweenPhases(data, startPhase, endPhase);
	data.Source = repmat(string(sourceName), height(data), 1);
	data.ImagingCohort = repmat(logical(imagingCohort), height(data), 1);
	out = data(:, {'Mouse', 'DateTime', 'Performance', 'Source', 'ImagingCohort', 'NBlocksInSession'});
end

function out = iEmptySess()
	out = table(string.empty(0, 1), NaT(0, 1), nan(0, 1), strings(0, 1), false(0, 1), nan(0, 1), 'VariableNames', {'Mouse', 'DateTime', 'Performance', 'Source', 'ImagingCohort', 'NBlocksInSession'});
end

function dt = iNormDt(dt)
	dt = datetime(dt);
	if isdatetime(dt) && ~isempty(dt.TimeZone), dt.TimeZone = ''; end
end

function data = iQueryLightWaterBehaviorAll(DS)
	varsTry = ["Mouse", "DateTime", "Stimulus", "Phase", "Behavior"];
	varsFallback = ["Mouse", "DateTime", "Stimulus", "Phase", "Performance"];
	try, data = DS.TableQuery(varsTry, Stimulus="LightWater"); catch, data = DS.TableQuery(varsFallback, Stimulus="LightWater"); end
	if isempty(data), return; end
	data.Stimulus = string(data.Stimulus); data = data(data.Stimulus == "LightWater", :);
end

function sessions = iSelectSessionsBetweenPhases(sessions, startPhase, endPhase)
	startPhase = string(startPhase); endPhase = string(endPhase);
	if isempty(sessions), return; end
	sessions.Mouse = string(sessions.Mouse); sessions.Phase = string(sessions.Phase);
	sessions = sortrows(sessions, {'Mouse', 'DateTime'});
	mice = unique(sessions.Mouse); keepRows = false(height(sessions), 1);
	for mouseIndex = 1:numel(mice)
		indices = find(sessions.Mouse == mice(mouseIndex));
		startIndex = find(sessions.Phase(indices) == startPhase, 1, 'first');
		if isempty(startIndex), continue; end
		endIndex = find(sessions.Phase(indices) == endPhase & (1:numel(indices))' >= startIndex, 1, 'first');
		if isempty(endIndex), endIndex = numel(indices); end
		keepRows(indices(startIndex:endIndex)) = true;
	end
	sessions = sessions(keepRows, :);
end

function badMice = iFindAudioMice(DS, phaseName)
	badMice = string.empty(0, 1);
	audioTable = DS.TableQuery("Mouse", Stimulus="AudioWater", Phase=phaseName);
	if ~isempty(audioTable) && ismember("Mouse", string(audioTable.Properties.VariableNames)), badMice = unique(string(audioTable.Mouse)); end
end

function sessions = iSessionizeByDateTime(data)
	useBehavior = ismember('Behavior', string(data.Properties.VariableNames));
	if ~ismember('Phase', data.Properties.VariableNames), data.Phase = repmat(missing, height(data), 1); end
	data = data(:, intersect(data.Properties.VariableNames, {'Mouse', 'DateTime', 'Behavior', 'Phase', 'Performance'}, 'stable'));
	data.Mouse = string(data.Mouse); data = sortrows(data, {'Mouse', 'DateTime'});
	if useBehavior, values = double(data.Behavior); else, values = double(data.Performance); end
	[groupId, mouseKeys, dtKeys] = findgroups(data.Mouse, data.DateTime);
	performance = splitapply(@(values) mean(values, 'omitnan'), values, groupId);
	nBlocks = splitapply(@(values) sum(isfinite(values)), values, groupId);
	phaseSession = splitapply(@(phases) iPickPhase(phases), string(data.Phase), groupId);
	sessions = table(mouseKeys, dtKeys, performance, nBlocks, phaseSession, 'VariableNames', {'Mouse', 'DateTime', 'Performance', 'NBlocksInSession', 'Phase'});
end

function phase = iPickPhase(phases)
	[uniquePhases, ~, phaseIndices] = unique(phases);
	counts = accumarray(phaseIndices, 1); [~, maxIndex] = max(counts); phase = uniquePhases(maxIndex);
end

function sessions = iAddSessionIndex(sessions)
	sessions.Mouse = string(sessions.Mouse); sessions = sortrows(sessions, {'Group', 'Mouse', 'DateTime'});
	[groupId, ~] = findgroups(sessions.Group, sessions.Mouse);
	sessionCell = splitapply(@(dateTimes) {(1:numel(dateTimes))'}, sessions.DateTime, groupId);
	sessions.Session = vertcat(sessionCell{:});
end

function sessions = iFilterToDisplayedMice(sessions)
	if isempty(sessions), return; end
	rows = isfinite(double(sessions.Session)) & isfinite(double(sessions.Performance));
	shownMice = unique(string(sessions.Mouse(rows)), 'stable'); sessions = sessions(ismember(string(sessions.Mouse), shownMice), :);
end

function sessOut = iLoadPerMouseTruncatedSessions(sessions, mouseName)
	mouseSessions = sortrows(sessions(string(sessions.Mouse) == mouseName, :), 'DateTime');
	performance = double(mouseSessions.Performance);
	reached = find(performance >= 1.0, 1, 'first');
	if ~isempty(reached), mouseSessions = mouseSessions(1:reached, :); mouseSessions.Performance(end) = 1; end
	mouseSessions.Session = (1:height(mouseSessions))';
	sessOut = mouseSessions;
end

function slopeOut = iPerMouseSlopeSessions(sessions)
	if isempty(sessions), slopeOut = table(string.empty(0, 1), nan(0, 1), 'VariableNames', {'Mouse', 'Slope'}); return; end
	sessions = sortrows(sessions, {'Mouse', 'DateTime'}); mice = unique(string(sessions.Mouse)); slopeVec = nan(numel(mice), 1);
	for mouseIndex = 1:numel(mice)
		mouseName = mice(mouseIndex); mouseSessions = sortrows(sessions(string(sessions.Mouse) == mouseName, :), 'DateTime');
		if height(mouseSessions) < 2, continue; end
		performance = double(mouseSessions.Performance); reached = find(performance >= 1.0, 1, 'first');
		if isempty(reached), continue; end
		mouseSessions = mouseSessions(1:reached, :); mouseSessions.Performance(end) = 1; performance = double(mouseSessions.Performance);
		if height(mouseSessions) < 2 || numel(unique(performance)) < 2, continue; end
		fitTable = mouseSessions(:, {'Mouse', 'DateTime', 'Performance'}); fitTable.Group = repmat("Fit", height(fitTable), 1);
		fitTable = movevars(fitTable, 'Group', 'Before', 'Mouse'); fitTable.Session = (1:height(fitTable))';
		fitOut = iFitSigmoidCurvePerMouse_33(fitTable, mouseName); slopeVec(mouseIndex) = fitOut.Slope;
	end
	slopeOut = table(mice, slopeVec, 'VariableNames', {'Mouse', 'Slope'});
end

function fitOut = iFitSigmoidCurvePerMouse_33(sessions, groupName)
	sessions = sortrows(sessions, {'Mouse', 'DateTime'}); xObs = double(sessions.Session(:)); yObs = double(sessions.Performance(:));
	use = isfinite(xObs) & isfinite(yObs); xObs = xObs(use); yObs = yObs(use);
	slopeStarts = [0, 0.2, 0.8, 2, 5, 20];
	midpointStarts = unique([median(xObs), min(xObs), max(xObs), min(xObs) - numel(xObs), max(xObs) + numel(xObs)]);
	opt = optimset('Display', 'off', 'MaxFunEvals', 10000, 'MaxIter', 10000);
	objective = @(params) sum((yObs - iSigmoidFromFixedLowerParams(params, xObs)).^2, 'omitnan');
	bestSse = inf; params = [sqrt(0.8); median(xObs)];
	for slopeIndex = 1:numel(slopeStarts)
		for midpointIndex = 1:numel(midpointStarts)
			paramsTry = fminsearch(objective, [sqrt(slopeStarts(slopeIndex)); midpointStarts(midpointIndex)], opt);
			if objective(paramsTry) < bestSse, bestSse = objective(paramsTry); params = paramsTry; end
		end
	end
	yHat = iSigmoidFromFixedLowerParams(params, xObs);
	sse = sum((yObs - yHat).^2, 'omitnan'); sst = sum((yObs - mean(yObs, 'omitnan')).^2, 'omitnan');
	if sst == 0, rSquared = NaN; else, rSquared = 1 - sse / sst; end
	[lower, upper, slope, midpoint] = iDecodeFixedLowerSigmoidParams(params);
	fitOut = struct; fitOut.Group = string(groupName); fitOut.ParamRaw = params;
	fitOut.Lower = lower; fitOut.Upper = upper; fitOut.Slope = slope; fitOut.Midpoint = midpoint;
	fitOut.SSE = sse; fitOut.RSquared = rSquared; fitOut.XObserved = xObs; fitOut.YObserved = yObs;
end

function values = iSigmoidFromFixedLowerParams(params, sessionIndex)
	[lower, upper, slope, midpoint] = iDecodeFixedLowerSigmoidParams(params);
	values = lower + (upper - lower) ./ (1 + exp(-slope .* (sessionIndex - midpoint)));
end

function [lower, upper, slope, midpoint] = iDecodeFixedLowerSigmoidParams(params)
	lower = 0; upper = 1; slope = params(1).^2; midpoint = params(2);
end

function sessCounts = iCountSessionsPerMouse(sessions, mice)
	mice = string(mice); sessions.Mouse = string(sessions.Mouse); sessCounts = zeros(numel(mice), 1);
	for mouseIndex = 1:numel(mice)
		mouseSessions = sessions(sessions.Mouse == mice(mouseIndex), :);
		performance = double(mouseSessions.Performance); reached = find(performance >= 1.0, 1, 'first');
		if ~isempty(reached), mouseSessions = mouseSessions(1:reached, :); end
		sessCounts(mouseIndex) = height(mouseSessions);
	end
end
% Fig312A sigmoid fit: LightWater learning curve for Naive vs Continual
%
% Output:
% - SVG figure to \\Data-Server-2\个人数据\杨青宁\202604
% - script copy to the same directory

outDirUNC = '\\Data-Server-2\个人数据\杨青宁\202604';
svgName = 'Fig312A_LightWaterLearningCurve_Sigmoid.svg';
scriptCopyName = 'Fig312A_LightWaterLearningCurve_Sigmoid.m';
fitCsvName = 'Fig312A_LightWaterLearningCurve_SigmoidFit.csv';
summaryCsvName = 'Fig312A_LightWaterLearningCurve_SigmoidSummary.csv';
excludedCsvName = 'Fig312A_LightWaterLearningCurve_SigmoidExcludedMice.csv';

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

LAB  = UniExp.DataSet('\\Data-Server-2\个人数据\张天夫\202512\光声迁移无穿插MOp成像（含学会后三次）.v3.mat');
ALB  = UniExp.DataSet('\\Data-Server-2\个人数据\张天夫\202512\声光迁移MOp成像（含学会后三次）.v5.mat');
LAPB = UniExp.DataSet('\\Data-Server-2\个人数据\张天夫\202601\基本迁移行为 光水转声水.v3.mat');
ALPB = UniExp.DataSet('\\Data-Server-2\个人数据\张天夫\202511\基本迁移行为 声水转光水.v2.mat');
LAI  = UniExp.DataSet('\\data-server-2\个人数据\张天夫\202601\光声迁移MOp成像有穿插.v5.mat');

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
	error('Fig312A_Sigmoid:EmptyData', 'No LightWater sessions found for Fig312A sigmoid fit.');
end

allSessions = sortrows(allSessions, ["Group","Mouse","DateTime"]);
allSessions = iAddSessionIndex(allSessions);
[allSessions, excludedMice] = iExcludePostTrainingZeroMice(allSessions);

displayedNaive = iFilterToDisplayedMice(allSessions(string(allSessions.Group) == "Naive", :));
displayedTransfer = iFilterToDisplayedMice(allSessions(string(allSessions.Group) == "Transfer", :));

sessionForSummary = allSessions(:, ["Mouse","DateTime","Performance","Group"]);
sessionForSummary.Group = string(sessionForSummary.Group);
sessionForSummary = sortrows(sessionForSummary, ["Group","Mouse","DateTime"]);
[~, summaryL] = evalc('UniExp.LearningSummarize(sessionForSummary)');
[meanMat, semMat, x] = iUnpackLearningSummarize(summaryL, ["Naive","Transfer"]);
nMat = iComputeNBySession(allSessions, x, ["Naive","Transfer"]);

fitNaive = iFitSigmoidCurve(displayedNaive, "Naive");
fitTransfer = iFitSigmoidCurve(displayedTransfer, "Continual");

xFit = (1:max([max(fitNaive.XObserved), max(fitTransfer.XObserved), max(x)])).';
naiveFitCurve = iSigmoidFromParams(fitNaive.ParamRaw, xFit);
transferFitCurve = iSigmoidFromParams(fitTransfer.ParamRaw, xFit);

f = figure('Color', 'w', 'Name', 'Fig312A LightWater learning curve sigmoid');
f.Units = 'centimeters';
f.Position(3:4) = [16, 7.5];
t = tiledlayout(f, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

palette = TransferLearning.FigurePalette(2);
axNaive = nexttile(t, 1);
iPlotGroupMouseCurves(axNaive, displayedNaive, xFit, naiveFitCurve, palette(1,:), "Naive", fitNaive);

axTransfer = nexttile(t, 2);
iPlotGroupMouseCurves(axTransfer, displayedTransfer, xFit, transferFitCurve, palette(2,:), "Continual", fitTransfer);

ylabel(axNaive, 'Hit rate', 'FontSize', 12);
xlabel(axNaive, 'Block', 'FontSize', 12);
xlabel(axTransfer, 'Block', 'FontSize', 12);
title(t, 'Fig312A LightWater learning curve sigmoid fit', 'FontSize', 13, 'FontWeight', 'normal');

if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end

allAxes = findall(f, 'Type', 'axes');
for ax = reshape(allAxes, 1, [])
	if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
		ax.Toolbar.Visible = 'off';
	end
end

thisFile = mfilename('fullpath');
copyfile([thisFile, '.m'], fullfile(outDirUNC, scriptCopyName));
svgPath = fullfile(outDirUNC, svgName);
exportgraphics(f, svgPath, 'ContentType', 'vector');

fitTable = table;
fitTable.Group = ["Naive"; "Continual"];
fitTable.Lower = [fitNaive.Lower; fitTransfer.Lower];
fitTable.Upper = [fitNaive.Upper; fitTransfer.Upper];
fitTable.Slope = [fitNaive.Slope; fitTransfer.Slope];
fitTable.Midpoint = [fitNaive.Midpoint; fitTransfer.Midpoint];
fitTable.SSE = [fitNaive.SSE; fitTransfer.SSE];
fitTable.RSquared = [fitNaive.RSquared; fitTransfer.RSquared];
writetable(fitTable, fullfile(outDirUNC, fitCsvName));

summaryTable = table;
summaryTable.Block = x(:);
summaryTable.NaiveMean = meanMat(:,1);
summaryTable.ContinualMean = meanMat(:,2);
summaryTable.NaiveSem = semMat(:,1);
summaryTable.ContinualSem = semMat(:,2);
summaryTable.NaiveN = nMat(:,1);
summaryTable.ContinualN = nMat(:,2);
writetable(summaryTable, fullfile(outDirUNC, summaryCsvName));
if ~isempty(excludedMice)
	writetable(excludedMice, fullfile(outDirUNC, excludedCsvName));
	fprintf('Wrote: %s\n', fullfile(outDirUNC, excludedCsvName));
	disp(excludedMice);
end

fprintf('Wrote: %s\n', svgPath);
fprintf('Wrote: %s\n', fullfile(outDirUNC, scriptCopyName));
fprintf('Wrote: %s\n', fullfile(outDirUNC, fitCsvName));
fprintf('Wrote: %s\n', fullfile(outDirUNC, summaryCsvName));
fprintf('Naive sigmoid: lower=%.4f, upper=%.4f, slope=%.4f, midpoint=%.4f, R^2=%.4f\n', fitNaive.Lower, fitNaive.Upper, fitNaive.Slope, fitNaive.Midpoint, fitNaive.RSquared);
fprintf('Continual sigmoid: lower=%.4f, upper=%.4f, slope=%.4f, midpoint=%.4f, R^2=%.4f\n', fitTransfer.Lower, fitTransfer.Upper, fitTransfer.Slope, fitTransfer.Midpoint, fitTransfer.RSquared);

assignin('base', 'Fig312A_Sigmoid_AllSessions', allSessions);
assignin('base', 'Fig312A_Sigmoid_FitTable', fitTable);
assignin('base', 'Fig312A_Sigmoid_Summary', summaryTable);
assignin('base', 'Fig312A_Sigmoid_ExcludedMice', excludedMice);

function out = iLightWaterSessionsByMouse(DS, sourceName, imagingCohort, startPhase, endPhase)
	T = iQueryLightWaterBehaviorAll(DS);
	if isempty(T)
		out = table(string.empty(0,1), NaT(0,1), nan(0,1), strings(0,1), false(0,1), nan(0,1), strings(0,1), ...
			'VariableNames', {'Mouse','DateTime','Performance','Source','ImagingCohort','NBlocksInSession','Phase'});
		return;
	end
	T.Mouse = string(T.Mouse);
	T.DateTime = iNormalizeDateTime(T.DateTime);
	T = iSessionizeByDateTime(T);
	T = iSelectSessionsBetweenPhases(T, startPhase, endPhase);
	T.Source = repmat(string(sourceName), height(T), 1);
	T.ImagingCohort = repmat(logical(imagingCohort), height(T), 1);
	out = T(:, {'Mouse','DateTime','Performance','Source','ImagingCohort','NBlocksInSession','Phase'});
end

function out = iLightWaterSessionsByMouse_LAInterspersed(DS, sourceName, imagingCohort, startPhase, endPhase)
	badMice = iFindMiceWithAudioWaterInPhase(DS, "Naive");
	T = iQueryLightWaterBehaviorAll(DS);
	if isempty(T)
		out = table(string.empty(0,1), NaT(0,1), nan(0,1), strings(0,1), false(0,1), nan(0,1), strings(0,1), ...
			'VariableNames', {'Mouse','DateTime','Performance','Source','ImagingCohort','NBlocksInSession','Phase'});
		return;
	end
	T.Mouse = string(T.Mouse);
	if ~isempty(badMice)
		T = T(~ismember(T.Mouse, badMice), :);
	end
	T.DateTime = iNormalizeDateTime(T.DateTime);
	T = iSessionizeByDateTime(T);
	T = iSelectSessionsBetweenPhases(T, startPhase, endPhase);
	T.Source = repmat(string(sourceName), height(T), 1);
	T.ImagingCohort = repmat(logical(imagingCohort), height(T), 1);
	out = T(:, {'Mouse','DateTime','Performance','Source','ImagingCohort','NBlocksInSession','Phase'});
end

function T = iQueryLightWaterBehaviorAll(DS)
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

function dt = iNormalizeDateTime(dt)
	dt = datetime(dt);
	if isdatetime(dt) && ~isempty(dt.TimeZone)
		dt.TimeZone = '';
	end
end

function S = iSessionizeByDateTime(T)
	useBehavior = ismember('Behavior', string(T.Properties.VariableNames));
	if ~ismember('Phase', T.Properties.VariableNames)
		T.Phase = repmat(missing, height(T), 1);
	end
	if useBehavior
		T = T(:, {'Mouse','DateTime','Behavior','Phase'});
	else
		T = T(:, {'Mouse','DateTime','Performance','Phase'});
	end
	T.Mouse = string(T.Mouse);
	T = sortrows(T, {'Mouse','DateTime'});
	if useBehavior
		val = double(T.Behavior);
	else
		val = double(T.Performance);
	end
	[G, mouseKeys, dtKeys] = findgroups(T.Mouse, T.DateTime);
	perf = splitapply(@(x) mean(x, 'omitnan'), val, G);
	nBlocks = splitapply(@(x) sum(isfinite(x)), val, G);
	phaseSession = splitapply(@(x) iPickSessionPhase(x), string(T.Phase), G);
	S = table(mouseKeys, dtKeys, perf, nBlocks, phaseSession, 'VariableNames', {'Mouse','DateTime','Performance','NBlocksInSession','Phase'});
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

function S = iSelectSessionsBetweenPhases(S, startPhase, endPhase)
	S.Mouse = string(S.Mouse);
	S.Phase = string(S.Phase);
	S = sortrows(S, {'Mouse','DateTime'});
	mice = unique(S.Mouse);
	keepRows = false(height(S),1);
	for i = 1:numel(mice)
		idx = find(S.Mouse == mice(i));
		ph = S.Phase(idx);
		st = find(ph == string(startPhase), 1, 'first');
		if isempty(st)
			continue;
		end
		ed = find(ph == string(endPhase) & (1:numel(ph))' >= st, 1, 'first');
		if isempty(ed)
			ed = numel(ph);
		end
		keepRows(idx(st:ed)) = true;
	end
	S = S(keepRows, :);
end

function badMice = iFindMiceWithAudioWaterInPhase(DS, phaseName)
	Ta = DS.TableQuery("Mouse", Stimulus="AudioWater", Phase=phaseName);
	if isempty(Ta)
		badMice = string.empty(0,1);
	else
		badMice = unique(string(Ta.Mouse));
	end
end

function iAssertNoCrossSourceDuplicateMice(T, groupName)
	T.Mouse = string(T.Mouse);
	T.Source = string(T.Source);
	[G, mice] = findgroups(T.Mouse);
	nSrc = splitapply(@(x) numel(unique(string(x))), T.Source, G);
	dup = mice(nSrc > 1);
	if ~isempty(dup)
		error('Fig312A_Sigmoid:DuplicateMouseAcrossSources', 'Group %s has duplicated mice across sources.', char(string(groupName)));
	end
end

function iAssertNoMouseAppearsInMultipleGroups(T)
	T.Mouse = string(T.Mouse);
	T.Group = string(T.Group);
	[G, mice] = findgroups(T.Mouse);
	nG = splitapply(@(x) numel(unique(string(x))), T.Group, G);
	dup = mice(nG > 1);
	if ~isempty(dup)
		error('Fig312A_Sigmoid:MouseInMultipleGroups', 'Some mice appear in multiple groups.');
	end
end

function T = iAddSessionIndex(T)
	T.Mouse = string(T.Mouse);
	T = sortrows(T, {'Group','Mouse','DateTime'});
	[G, ~] = findgroups(T.Group, T.Mouse);
	sessCell = splitapply(@(x) {(1:numel(x))'}, T.DateTime, G);
	T.Session = vertcat(sessCell{:});
end

function [meanMat, semMat, x] = iUnpackLearningSummarize(summaryL, groupOrder)
	groupOrder = string(groupOrder);
	meanCells = summaryL.MeanCurve(:);
	semCells = summaryL.SemCurve(:);
	if ~isempty(summaryL.Properties.RowNames)
		rn = string(summaryL.Properties.RowNames);
	else
		rn = strings(numel(meanCells),1);
	end
	idx = nan(1, numel(groupOrder));
	for k = 1:numel(groupOrder)
		ix = find(rn == groupOrder(k), 1, 'first');
		if isempty(ix) && k <= numel(meanCells)
			ix = k;
		end
		idx(k) = ix;
	end
	maxLen = 0;
	for k = 1:numel(groupOrder)
		if isfinite(idx(k))
			maxLen = max(maxLen, numel(meanCells{idx(k)}));
		end
	end
	meanMat = nan(maxLen, numel(groupOrder));
	semMat = nan(maxLen, numel(groupOrder));
	for k = 1:numel(groupOrder)
		if isfinite(idx(k))
			mv = double(meanCells{idx(k)}(:));
			sv = double(semCells{idx(k)}(:));
			meanMat(1:numel(mv),k) = mv;
			semMat(1:numel(sv),k) = sv;
		end
	end
	x = (1:maxLen).';
end

function nMat = iComputeNBySession(T, x, groups)
	nMat = zeros(numel(x), numel(groups));
	for g = 1:numel(groups)
		rowsG = string(T.Group) == string(groups(g));
		for s = 1:numel(x)
			rowsS = rowsG & (double(T.Session) == s) & isfinite(double(T.Performance));
			if any(rowsS)
				nMat(s,g) = numel(unique(string(T.Mouse(rowsS))));
			end
		end
	end
end

function [T, excluded] = iExcludePostTrainingZeroMice(T)
	if isempty(T)
		excluded = table;
		return;
	end
	T.Mouse = string(T.Mouse);
	T.Group = string(T.Group);
	T = sortrows(T, {'Group','Mouse','Session'});
	[G, groupNames, mouseNames] = findgroups(T.Group, T.Mouse);
	shouldExclude = splitapply(@iHasPostTrainingZero, double(T.Session), double(T.Performance), G);
	excluded = table(groupNames(shouldExclude), mouseNames(shouldExclude), 'VariableNames', {'Group','Mouse'});
	if isempty(excluded)
		return;
	end
	keepRows = ~ismember(T.Mouse, excluded.Mouse);
	T = T(keepRows, :);
end

function tf = iHasPostTrainingZero(sessionIdx, perf)
	valid = isfinite(sessionIdx) & isfinite(perf);
	sessionIdx = sessionIdx(valid);
	perf = perf(valid);
	if isempty(sessionIdx)
		tf = false;
		return;
	end
	tf = any(sessionIdx > 1 & perf == 0);
end

function T = iFilterToDisplayedMice(T)
	if isempty(T)
		return;
	end
	rows = isfinite(double(T.Session)) & isfinite(double(T.Performance));
	shownMice = unique(string(T.Mouse(rows)), 'stable');
	T = T(ismember(string(T.Mouse), shownMice), :);
end

function iPlotGroupMouseCurves(ax, T, xFit, yFit, lineColor, groupName, fitStruct)
	hold(ax, 'on');
	ax.FontSize = 12;
	ax.LineWidth = 2;
	if isprop(ax.XAxis, 'LineWidth')
		ax.XAxis.LineWidth = 2;
		ax.YAxis.LineWidth = 2;
	end
	T = sortrows(T, {'Mouse','Session'});
	T.Mouse = string(T.Mouse);
	mice = unique(T.Mouse, 'stable');
	nMice = numel(mice);
	lightColor = 1 - (1 - lineColor) * 0.35;
	mouseHandles = gobjects(0,1);
	for i = 1:nMice
		rows = T.Mouse == mice(i) & isfinite(double(T.Session)) & isfinite(double(T.Performance));
		if ~any(rows)
			continue;
		end
		xMouse = double(T.Session(rows));
		yMouse = double(T.Performance(rows));
		h = plot(ax, xMouse, yMouse, '-o', ...
			'Color', lightColor, ...
			'LineWidth', 0.9, ...
			'MarkerSize', 4, ...
			'MarkerFaceColor', lightColor, ...
			'MarkerEdgeColor', lineColor);
		if isempty(mouseHandles)
			mouseHandles = h;
		end
	end
	fitHandle = plot(ax, xFit, yFit, '-', 'Color', lineColor, 'LineWidth', 2.8);
	if ~isempty(mouseHandles)
		lg = legend(ax, [mouseHandles(1), fitHandle], {'Per-mouse hit rate', 'Sigmoid fit'}, 'Location', 'southeast');
		lg.FontSize = 9;
		lg.Box = 'off';
	end
	xlabel(ax, 'Block', 'FontSize', 12);
	ylim(ax, [0 1]);
	xlim(ax, [1 max(xFit)]);
	box(ax, 'off');
	grid(ax, 'off');
	title(ax, sprintf('%s (n=%d mice)', char(groupName), nMice), 'FontSize', 12, 'FontWeight', 'normal');
	txt = sprintf('lower=%.3f, upper=%.3f, slope=%.3f, midpoint=%.2f', fitStruct.Lower, fitStruct.Upper, fitStruct.Slope, fitStruct.Midpoint);
	text(ax, 0.02, 0.96, txt, 'Units', 'normalized', 'Color', lineColor, 'FontSize', 8.5, 'VerticalAlignment', 'top', 'BackgroundColor', 'w', 'Margin', 2);
end

function fitOut = iFitSigmoidCurve(T, groupName)
	T = sortrows(T, {'Mouse','DateTime'});
	xObs = double(T.Session(:));
	yObs = double(T.Performance(:));
	use = isfinite(xObs) & isfinite(yObs);
	xObs = xObs(use);
	yObs = yObs(use);
	if isempty(xObs)
		error('Fig312A_Sigmoid:NoDataForGroup', 'No valid session data for group %s.', char(groupName));
	end
	p0 = [iLogit(max(min(min(yObs), 0.45), 0.01)); 0; log(0.8); log(max(median(xObs), 1))];
	obj = @(p) sum((yObs - iSigmoidFromParams(p, xObs)).^2, 'omitnan');
	opt = optimset('Display', 'off', 'MaxFunEvals', 10000, 'MaxIter', 10000);
	p = fminsearch(obj, p0, opt);
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
	lower = 1 ./ (1 + exp(-p(1)));
	spanFrac = 1 ./ (1 + exp(-p(2)));
	upper = lower + (1 - lower) .* spanFrac;
	slope = exp(p(3));
	midpoint = exp(p(4));
end

function y = iLogit(x)
	x = min(max(x, 1e-6), 1 - 1e-6);
	y = log(x ./ (1 - x));
end
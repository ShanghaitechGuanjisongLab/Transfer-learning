% Fig1B sigmoid fit: Naive vs Transfer LightWater learning curve
%
% Output: SVG and sidecar files through the standard figure output path.

svgName = '中文图Fig313A_LearningCurve_Sigmoid.svg';
scriptCopyName = '中文图Fig313A_LearningCurve_Sigmoid.m';
fitCsvName = '中文图Fig313A_LearningCurve_SigmoidFit.csv';
summaryCsvName = '中文图Fig313A_LearningCurve_SigmoidSummary.csv';
permCsvName = '中文图Fig313A_LearningCurve_SigmoidPermutation.csv';
statsTxtName = '中文图Fig313A_LearningCurve_SigmoidPermutation.txt';

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
	error('Fig1B_Sigmoid:EmptyData', 'No LightWater sessions found for Fig1B sigmoid fit.');
end

allSessions = sortrows(allSessions, ["Group","Mouse","DateTime"]);
allSessions = iAddSessionIndex(allSessions);

displayedNaive = iFilterToDisplayedMice(allSessions(string(allSessions.Group) == "Naive", :));
displayedTransfer = iFilterToDisplayedMice(allSessions(string(allSessions.Group) == "Transfer", :));

sessionForSummary = allSessions(:, ["Mouse","DateTime","Performance","Group"]);
sessionForSummary.Group = string(sessionForSummary.Group);
sessionForSummary = sortrows(sessionForSummary, ["Group","Mouse","DateTime"]);
[~, SummaryL] = evalc('UniExp.LearningSummarize(sessionForSummary)');
[meanMat, semMat, x] = iUnpackLearningSummarize(SummaryL, ["Naive","Transfer"]);
nMat = iComputeNBySession(allSessions, x, ["Naive","Transfer"]);

fitNaive = iFitSigmoidCurve(displayedNaive, "Naive");
fitTransfer = iFitSigmoidCurve(displayedTransfer, "Transfer");
permResult = iPermutationTestSigmoidSlope(displayedNaive, displayedTransfer, 10000, 1);

xFit = (1:max([max(fitNaive.XObserved), max(fitTransfer.XObserved), max(x)])).';
naiveFitCurve = iSigmoidFromParams(fitNaive.ParamRaw, xFit);
transferFitCurve = iSigmoidFromParams(fitTransfer.ParamRaw, xFit);

meanMatOut = nan(numel(xFit), size(meanMat, 2));
semMatOut = nan(numel(xFit), size(semMat, 2));
nMatOut = nan(numel(xFit), size(nMat, 2));
meanMatOut(1:size(meanMat, 1), :) = meanMat;
semMatOut(1:size(semMat, 1), :) = semMat;
nMatOut(1:size(nMat, 1), :) = nMat;

f = figure('Color', 'w', 'Name', 'Fig1B Learning curve sigmoid');
f.Units = 'centimeters';
f.Position(3:4) = [16, 10.5];
t = tiledlayout(f, 1, 2, 'TileSpacing', 'loose', 'Padding', 'loose');

curveColor = [0 0 0];
axNaive = nexttile(t, 1);
iPlotGroupMouseCurves(axNaive, displayedNaive, xFit, naiveFitCurve, curveColor, "Naive", fitNaive, true);

axTransfer = nexttile(t, 2);
iPlotGroupMouseCurves(axTransfer, displayedTransfer, xFit, transferFitCurve, curveColor, "Continual", fitTransfer, false);

ylabel(axNaive, 'Hit rate', 'FontSize', 12);
xlabel(axNaive, 'Block', 'FontSize', 12);
xlabel(axTransfer, 'Block', 'FontSize', 12);
ylabel(axTransfer, '');
axTransfer.YAxis.Visible = 'off';

allAxes = findall(f, 'Type', 'axes');
for ax = reshape(allAxes, 1, [])
	if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
		ax.Toolbar.Visible = 'off';
	end
end

TransferLearning.Style.ApplyStandardFigureStyle(f, 2);
iRetuneSingleMouseCurves(f);
axTransfer.YAxis.Visible = 'off';
svgPath = TransferLearning.StandardFigureSvgPath(svgName);
print(f, svgPath, '-dsvg');
outDirUNC = fileparts(svgPath);
thisFile = mfilename('fullpath');
copyfile([thisFile, '.m'], fullfile(outDirUNC, scriptCopyName));

fitTable = table;
fitTable.Group = ["Naive"; "Transfer"];
fitTable.Lower = [fitNaive.Lower; fitTransfer.Lower];
fitTable.Upper = [fitNaive.Upper; fitTransfer.Upper];
fitTable.Slope = [fitNaive.Slope; fitTransfer.Slope];
fitTable.Midpoint = [fitNaive.Midpoint; fitTransfer.Midpoint];
fitTable.SSE = [fitNaive.SSE; fitTransfer.SSE];
fitTable.RSquared = [fitNaive.RSquared; fitTransfer.RSquared];
writetable(fitTable, fullfile(outDirUNC, fitCsvName));

permTable = table;
permTable.ObservedNaiveSlope = permResult.ObservedNaiveSlope;
permTable.ObservedTransferSlope = permResult.ObservedTransferSlope;
permTable.ObservedDifference = permResult.ObservedDifference;
permTable.PermutationPValue = permResult.PValue;
permTable.PermutationCount = permResult.NPermutation;
permTable.NullMeanDifference = mean(permResult.PermutedDifference, 'omitnan');
permTable.NullStdDifference = std(permResult.PermutedDifference, 'omitnan');
permTable.NullCI_Low = prctile(permResult.PermutedDifference, 2.5);
permTable.NullCI_High = prctile(permResult.PermutedDifference, 97.5);
writetable(permTable, fullfile(outDirUNC, permCsvName));

summaryTable = table;
summaryTable.Block = xFit(:);
summaryTable.NaiveLearningCurve = meanMatOut(:,1);
summaryTable.TransferLearningCurve = meanMatOut(:,2);
summaryTable.NaiveSem = semMatOut(:,1);
summaryTable.TransferSem = semMatOut(:,2);
summaryTable.NaiveN = nMatOut(:,1);
summaryTable.TransferN = nMatOut(:,2);
summaryTable.NaiveSigmoid = naiveFitCurve(:);
summaryTable.TransferSigmoid = transferFitCurve(:);
writetable(summaryTable, fullfile(outDirUNC, summaryCsvName));

statsPath = fullfile(outDirUNC, statsTxtName);
fid = fopen(statsPath, 'w');
if fid < 0
	error('Fig1B_Sigmoid:OpenStatsTxtFailed', 'Cannot open %s for writing.', statsPath);
end
cleanupObj = onCleanup(@() fclose(fid));
fprintf(fid, 'Fig1B sigmoid slope permutation test\n');
fprintf(fid, 'Observed Naive slope: %.6f\n', permResult.ObservedNaiveSlope);
fprintf(fid, 'Observed Transfer slope: %.6f\n', permResult.ObservedTransferSlope);
fprintf(fid, 'Observed slope difference (Transfer - Naive): %.6f\n', permResult.ObservedDifference);
fprintf(fid, 'Permutation count: %d\n', permResult.NPermutation);
fprintf(fid, 'Two-sided permutation p-value: %.6g\n', permResult.PValue);
fprintf(fid, 'Null difference mean: %.6f\n', mean(permResult.PermutedDifference, 'omitnan'));
fprintf(fid, 'Null difference std: %.6f\n', std(permResult.PermutedDifference, 'omitnan'));
fprintf(fid, 'Null difference 95%% interval: [%.6f, %.6f]\n', prctile(permResult.PermutedDifference, 2.5), prctile(permResult.PermutedDifference, 97.5));

fprintf('Wrote: %s\n', svgPath);
fprintf('Wrote: %s\n', fullfile(outDirUNC, scriptCopyName));
fprintf('Wrote: %s\n', fullfile(outDirUNC, fitCsvName));
fprintf('Wrote: %s\n', fullfile(outDirUNC, summaryCsvName));
fprintf('Wrote: %s\n', fullfile(outDirUNC, permCsvName));
fprintf('Wrote: %s\n', statsPath);
fprintf('Naive sigmoid: lower=%.4f, upper=%.4f, slope=%.4f, midpoint=%.4f, R^2=%.4f\n', fitNaive.Lower, fitNaive.Upper, fitNaive.Slope, fitNaive.Midpoint, fitNaive.RSquared);
fprintf('Transfer sigmoid: lower=%.4f, upper=%.4f, slope=%.4f, midpoint=%.4f, R^2=%.4f\n', fitTransfer.Lower, fitTransfer.Upper, fitTransfer.Slope, fitTransfer.Midpoint, fitTransfer.RSquared);
fprintf('Permutation slope difference (Transfer - Naive): %.4f\n', permResult.ObservedDifference);
fprintf('Permutation two-sided p = %.4g (%d permutations)\n', permResult.PValue, permResult.NPermutation);

assignin('base', 'Fig1B_Sigmoid_AllSessions', allSessions);
assignin('base', 'Fig1B_Sigmoid_FitTable', fitTable);
assignin('base', 'Fig1B_Sigmoid_Summary', summaryTable);
assignin('base', 'Fig1B_Sigmoid_Permutation', permResult);

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
	if ~isempty(badMice)
		keep = ~ismember(T.Mouse, badMice);
		T = T(keep, :);
	end

	T.DateTime = iNormalizeDateTime(T.DateTime);
	T = iSessionizeByDateTime(T);
	T = iSelectSessionsBetweenPhases(T, startPhase, endPhase);
	T.Source = repmat(string(sourceName), height(T), 1);
	T.ImagingCohort = repmat(logical(imagingCohort), height(T), 1);
	out = T(:, {'Mouse','DateTime','Performance','Source','ImagingCohort','NBlocksInSession'});
end

function dt = iNormalizeDateTime(dt)
	dt = datetime(dt);
	if isdatetime(dt) && ~isempty(dt.TimeZone)
		dt.TimeZone = '';
	end
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

function S = iSelectSessionsBetweenPhases(S, startPhase, endPhase)
	startPhase = string(startPhase);
	endPhase = string(endPhase);
	if isempty(S)
		return;
	end

	S.Mouse = string(S.Mouse);
	S.Phase = string(S.Phase);
	S = sortrows(S, {'Mouse','DateTime'});
	mice = unique(S.Mouse);
	keepRows = false(height(S),1);
	for i = 1:numel(mice)
		m = mice(i);
		idx = find(S.Mouse == m);
		ph = S.Phase(idx);
		st = find(ph == startPhase, 1, 'first');
		if isempty(st)
			continue;
		end
		ed = find(ph == endPhase & (1:numel(ph))' >= st, 1, 'first');
		if isempty(ed)
			ed = numel(ph);
		end
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
	S = table(mouseKeys, dtKeys, perf, nBlocks, phaseSession, ...
		'VariableNames', {'Mouse','DateTime','Performance','NBlocksInSession','Phase'});
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

function iAssertNoCrossSourceDuplicateMice(T, groupName)
	if isempty(T)
		return;
	end
	T.Mouse = string(T.Mouse);
	T.Source = string(T.Source);
	[G, mice] = findgroups(T.Mouse);
	nSrc = splitapply(@(x) numel(unique(string(x))), T.Source, G);
	dup = mice(nSrc > 1);
	if ~isempty(dup)
		msgLines = strings(numel(dup),1);
		for i = 1:numel(dup)
			m = dup(i);
			srcs = unique(T.Source(T.Mouse == m));
			msgLines(i) = m + ": " + strjoin(srcs, ",");
		end
		error('Fig1B_Sigmoid:DuplicateMouseAcrossSources', ...
			'Group %s has duplicated mice across sources.\n%s', char(string(groupName)), char(strjoin(msgLines, newline)));
	end
end

function iAssertNoMouseAppearsInMultipleGroups(T)
	if isempty(T)
		return;
	end
	T.Mouse = string(T.Mouse);
	T.Group = string(T.Group);
	[G, mice] = findgroups(T.Mouse);
	nG = splitapply(@(x) numel(unique(string(x))), T.Group, G);
	dup = mice(nG > 1);
	if ~isempty(dup)
		msgLines = strings(numel(dup),1);
		for i = 1:numel(dup)
			m = dup(i);
			gs = unique(T.Group(T.Mouse == m));
			msgLines(i) = m + ": " + strjoin(gs, ",");
		end
		error('Fig1B_Sigmoid:MouseInMultipleGroups', 'Some mice appear in multiple groups.\n%s', char(strjoin(msgLines, newline)));
	end
end

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
		if isstruct(SummaryL)
			SummaryL = struct2table(SummaryL);
		else
			error('Fig1B_Sigmoid:InvalidLearningSummarizeOutput', 'LearningSummarize output must be table or struct.');
		end
	end

	meanCurve = SummaryL.MeanCurve;
	semCurve = SummaryL.SemCurve;
	meanCells = meanCurve(:);
	semCells = semCurve(:);
	if ~isempty(SummaryL.Properties.RowNames)
		rn = string(SummaryL.Properties.RowNames);
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

function T = iFilterToDisplayedMice(T)
	if isempty(T)
		return;
	end
	rows = isfinite(double(T.Session)) & isfinite(double(T.Performance));
	shownMice = unique(string(T.Mouse(rows)), 'stable');
	T = T(ismember(string(T.Mouse), shownMice), :);
end

function [yCells, sCells, xCells] = iBuildCellsForMultiShadowedLines(meanMat, semMat)
	nLines = size(meanMat, 2);
	yCells = cell(1, nLines);
	sCells = cell(1, nLines);
	xCells = cell(1, nLines);
	for j = 1:nLines
		y = meanMat(:, j);
		s = semMat(:, j);
		last = find(isfinite(y) & isfinite(s), 1, 'last');
		if isempty(last)
			yCells{j} = nan(0,1);
			sCells{j} = nan(0,1);
			xCells{j} = nan(0,1);
		else
			yCells{j} = y(1:last);
			sCells{j} = s(1:last);
			xCells{j} = (1:last).';
		end
	end
end

function iPlotGroupMouseCurves(ax, T, xFit, yFit, lineColor, groupName, fitStruct, showLegend)
	hold(ax, 'on');
	ax.FontSize = 12;
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
		h = plot(ax, xMouse, yMouse, '-', ...
			'Color', lightColor, ...
			'LineWidth', 0.5, ...
			'Marker', 'none', ...
			'Tag', 'SingleMouseCurve');
		if isempty(mouseHandles)
			mouseHandles = h;
		end
	end
	fitHandle = plot(ax, xFit, yFit, '-', 'Color', lineColor, 'LineWidth', 2.8);
	if showLegend && ~isempty(mouseHandles)
		lg = legend(ax, [mouseHandles(1), fitHandle], {'Per-mouse hit rate', 'Sigmoid fit'}, 'Location', 'southoutside');
		lg.FontSize = 9;
		lg.Box = 'off';
		lg.NumColumns = 2;
	else
		legend(ax, 'off');
	end
	xlabel(ax, 'Block', 'FontSize', 12);
	ylim(ax, [0 1.02]);
	xlim(ax, [1 max(xFit)]);
	box(ax, 'off');
	grid(ax, 'off');
	title(ax, {char(groupName), sprintf('slope=%.3f', fitStruct.Slope)}, 'FontSize', 10, 'FontWeight', 'normal');
end

function iRetuneSingleMouseCurves(fig)
	mouseLines = findall(fig, 'Type', 'line', 'Tag', 'SingleMouseCurve');
	for iLine = 1:numel(mouseLines)
		mouseLines(iLine).LineWidth = 0.5;
		mouseLines(iLine).Marker = 'none';
	end
end

function fitOut = iFitSigmoidCurve(T, groupName)
	T = sortrows(T, {'Mouse','DateTime'});
	xObs = double(T.Session(:));
	yObs = double(T.Performance(:));
	use = isfinite(xObs) & isfinite(yObs);
	xObs = xObs(use);
	yObs = yObs(use);
	if isempty(xObs)
		error('Fig1B_Sigmoid:NoDataForGroup', 'No valid session data for group %s.', char(groupName));
	end

	p0 = [iLogit(max(min(min(yObs), 0.45), 0.01)); log(0.8); log(max(median(xObs), 1))];
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

function permOut = iPermutationTestSigmoidSlope(TNaive, TTransfer, nPermutation, rngSeed)
	if nargin < 3 || isempty(nPermutation)
		nPermutation = 2000;
	end
	if nargin >= 4 && ~isempty(rngSeed)
		rng(rngSeed);
	end
	TNaive = sortrows(TNaive, {'Mouse','DateTime'});
	TTransfer = sortrows(TTransfer, {'Mouse','DateTime'});
	naiveMice = unique(string(TNaive.Mouse), 'stable');
	transferMice = unique(string(TTransfer.Mouse), 'stable');
	allMouseTables = cell(numel(naiveMice) + numel(transferMice), 1);
	for i = 1:numel(naiveMice)
		allMouseTables{i} = TNaive(string(TNaive.Mouse) == naiveMice(i), :);
	end
	for i = 1:numel(transferMice)
		allMouseTables{numel(naiveMice) + i} = TTransfer(string(TTransfer.Mouse) == transferMice(i), :);
	end
	fitNaive = iFitSigmoidCurve(TNaive, "Naive");
	fitTransfer = iFitSigmoidCurve(TTransfer, "Transfer");
	observedDiff = fitTransfer.Slope - fitNaive.Slope;
	permDiff = nan(nPermutation, 1);
	nNaive = numel(naiveMice);
	for iPerm = 1:nPermutation
		ord = randperm(numel(allMouseTables));
		idxNaive = ord(1:nNaive);
		idxTransfer = ord(nNaive+1:end);
		permNaive = vertcat(allMouseTables{idxNaive});
		permTransfer = vertcat(allMouseTables{idxTransfer});
		fitPermNaive = iFitSigmoidCurve(permNaive, "NaivePerm");
		fitPermTransfer = iFitSigmoidCurve(permTransfer, "TransferPerm");
		permDiff(iPerm) = fitPermTransfer.Slope - fitPermNaive.Slope;
	end
	pValue = mean(abs(permDiff) >= abs(observedDiff));
	permOut = struct;
	permOut.ObservedNaiveSlope = fitNaive.Slope;
	permOut.ObservedTransferSlope = fitTransfer.Slope;
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
	lower = 1 ./ (1 + exp(-p(1)));
	upper = 1;
	slope = exp(p(2));
	midpoint = exp(p(3));
end

function y = iLogit(x)
	x = min(max(x, 1e-6), 1 - 1e-6);
	y = log(x ./ (1 - x));
end
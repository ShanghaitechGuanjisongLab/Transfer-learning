% Fig1B sigmoid significance visualization: slope bars plus permutation null

outDirUNC = '\\Data-Server-2\个人数据\杨青宁\202605';
svgName = 'Fig1B_LearningCurve_Sigmoid_Significance.svg';
scriptCopyName = 'Fig1B_LearningCurve_Sigmoid_Significance.m';
slopeCsvName = 'Fig1B_LearningCurve_Sigmoid_Significance_Slopes.csv';
permCsvName = 'Fig1B_LearningCurve_Sigmoid_Significance_PermutationNull.csv';
statsTxtName = 'Fig1B_LearningCurve_Sigmoid_Significance.txt';

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
tranAnchors = ["Transfer","Final"];

naiveA = iLightWaterSessionsByMouse(LAB,  "LightAudioBaseline", true,  naiveAnchors(1), naiveAnchors(2));
naiveB = iLightWaterSessionsByMouse(LAPB, "LAPureBehavior",     false, naiveAnchors(1), naiveAnchors(2));
naiveC = iLightWaterSessionsByMouse_LAInterspersed(LAI, "LAInterspersed", false, naiveAnchors(1), naiveAnchors(2));
tranA = iLightWaterSessionsByMouse(ALB,  "AudioLightBaseline", true,  tranAnchors(1), tranAnchors(2));
tranB = iLightWaterSessionsByMouse(ALPB, "ALPureBehavior",     false, tranAnchors(1), tranAnchors(2));

naive = [naiveA; naiveB; naiveC];
tran = [tranA; tranB];
naive.Group(:) = "Naive";
tran.Group(:) = "Transfer";

iAssertNoCrossSourceDuplicateMice(naive, "Naive");
iAssertNoCrossSourceDuplicateMice(tran, "Transfer");

allSessions = [naive; tran];
iAssertNoMouseAppearsInMultipleGroups(allSessions);
if isempty(allSessions)
	error('Fig1B_Sigmoid_Significance:EmptyData', 'No LightWater sessions found for Fig1B significance figure.');
end

allSessions = sortrows(allSessions, ["Group","Mouse","DateTime"]);
allSessions = iAddSessionIndex(allSessions);

displayedNaive = iFilterToDisplayedMice(allSessions(string(allSessions.Group) == "Naive", :));
displayedTransfer = iFilterToDisplayedMice(allSessions(string(allSessions.Group) == "Transfer", :));

fitNaive = iFitSigmoidCurve(displayedNaive, "Naive");
fitTransfer = iFitSigmoidCurve(displayedTransfer, "Transfer");
permResult = iPermutationTestSigmoidSlope(displayedNaive, displayedTransfer, 10000, 1);

palette = TransferLearning.FigurePalette(2);
f = figure('Color', 'w', 'Name', 'Fig1B sigmoid significance');
f.Units = 'centimeters';
f.Position(3:4) = [16, 7.8];
f.PaperUnits = 'centimeters';
f.PaperSize = [16, 7.8];

tl = tiledlayout(f, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile(tl, 1);
iPlotSlopeBars(ax1, fitNaive.Slope, fitTransfer.Slope, permResult.PValue, palette);

ax2 = nexttile(tl, 2);
iPlotPermutationHistogram(ax2, permResult, palette(2,:));

title(tl, 'Fig1B learning-curve significance from mouse-level permutation', 'FontSize', 12, 'FontWeight', 'normal');

if ~isfolder(outDirUNC)
	mkdir(outDirUNC);
end

allAxes = findall(f, 'Type', 'axes');
for ax = reshape(allAxes, 1, [])
	if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
		ax.Toolbar.Visible = 'off';
	end
end

svgPath = fullfile(outDirUNC, svgName);
exportgraphics(f, svgPath, 'ContentType', 'vector');

thisFile = mfilename('fullpath');
copyfile([thisFile, '.m'], fullfile(outDirUNC, scriptCopyName));

slopeTable = table(["Naive"; "Transfer"], [fitNaive.Slope; fitTransfer.Slope], ...
	[fitNaive.Midpoint; fitTransfer.Midpoint], [fitNaive.RSquared; fitTransfer.RSquared], ...
	'VariableNames', {'Group','Slope','Midpoint','RSquared'});
writetable(slopeTable, fullfile(outDirUNC, slopeCsvName));

permTable = table(permResult.PermutedDifference, 'VariableNames', {'PermutedSlopeDifference'});
permTable.ObservedDifference = repmat(permResult.ObservedDifference, height(permTable), 1);
permTable.PermutationPValue = repmat(permResult.PValue, height(permTable), 1);
writetable(permTable, fullfile(outDirUNC, permCsvName));

statsPath = fullfile(outDirUNC, statsTxtName);
fid = fopen(statsPath, 'w');
if fid < 0
	error('Fig1B_Sigmoid_Significance:OpenStatsTxtFailed', 'Cannot open %s for writing.', statsPath);
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, 'Fig1B sigmoid significance visualization\n');
fprintf(fid, 'Naive slope: %.6f\n', fitNaive.Slope);
fprintf(fid, 'Transfer slope: %.6f\n', fitTransfer.Slope);
fprintf(fid, 'Observed slope difference (Transfer - Naive): %.6f\n', permResult.ObservedDifference);
fprintf(fid, 'Permutation count: %d\n', permResult.NPermutation);
fprintf(fid, 'Two-sided permutation p-value: %.6g\n', permResult.PValue);
fprintf(fid, 'Null difference mean: %.6f\n', mean(permResult.PermutedDifference, 'omitnan'));
fprintf(fid, 'Null difference std: %.6f\n', std(permResult.PermutedDifference, 'omitnan'));
fprintf(fid, 'Null difference 95%% interval: [%.6f, %.6f]\n', prctile(permResult.PermutedDifference, 2.5), prctile(permResult.PermutedDifference, 97.5));

fprintf('Wrote: %s\n', svgPath);
fprintf('Wrote: %s\n', fullfile(outDirUNC, scriptCopyName));
fprintf('Wrote: %s\n', fullfile(outDirUNC, slopeCsvName));
fprintf('Wrote: %s\n', fullfile(outDirUNC, permCsvName));
fprintf('Wrote: %s\n', statsPath);
fprintf('Naive slope: %.4f\n', fitNaive.Slope);
fprintf('Transfer slope: %.4f\n', fitTransfer.Slope);
fprintf('Observed difference (Transfer - Naive): %.4f\n', permResult.ObservedDifference);
fprintf('Permutation two-sided p = %.4g (%d permutations)\n', permResult.PValue, permResult.NPermutation);

assignin('base', 'Fig1B_Sigmoid_Significance_SlopeTable', slopeTable);
assignin('base', 'Fig1B_Sigmoid_Significance_Permutation', permResult);

function iPlotSlopeBars(ax, slopeNaive, slopeTransfer, pValue, palette)
	barH = bar(ax, [1 2], [slopeNaive slopeTransfer], 0.62, 'FaceColor', 'flat', 'EdgeColor', 'none');
	barH.CData(1,:) = palette(1,:);
	barH.CData(2,:) = palette(2,:);
	hold(ax, 'on');
	plot(ax, 1, slopeNaive, 'o', 'MarkerSize', 5, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', palette(1,:), 'LineWidth', 1);
	plot(ax, 2, slopeTransfer, 'o', 'MarkerSize', 5, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', palette(2,:), 'LineWidth', 1);
	yMax = max([slopeNaive, slopeTransfer]) * 1.28;
	if ~isfinite(yMax) || yMax <= 0
		yMax = 1;
	end
	ylim(ax, [0 yMax]);
	xlim(ax, [0.4 2.6]);
	set(ax, 'XTick', [1 2], 'XTickLabel', {'Naive','Transfer'}, 'FontSize', 11);
	ylabel(ax, 'Sigmoid slope', 'FontSize', 12);
	title(ax, 'Observed group slope', 'FontSize', 12, 'FontWeight', 'normal');
	box(ax, 'off');
	text(ax, 1, slopeNaive + yMax * 0.03, sprintf('%.3f', slopeNaive), 'HorizontalAlignment', 'center', 'FontSize', 10);
	text(ax, 2, slopeTransfer + yMax * 0.03, sprintf('%.3f', slopeTransfer), 'HorizontalAlignment', 'center', 'FontSize', 10);
	iAddPBracket(ax, 1, 2, yMax * 0.88, iFormatPLabel(pValue));
end

function iPlotPermutationHistogram(ax, permResult, lineColor)
	permDiff = double(permResult.PermutedDifference(:));
	permDiff = permDiff(isfinite(permDiff));
	xLo = prctile(permDiff, 0.5);
	xHi = prctile(permDiff, 99.5);
	xShownLo = min([xLo, 0, permResult.ObservedDifference]);
	xShownHi = max([xHi, 0, permResult.ObservedDifference]);
	pad = max((xShownHi - xShownLo) * 0.08, 0.05);
	histogram(ax, permDiff, 32, 'BinLimits', [xShownLo, xShownHi], 'FaceColor', [0.75 0.75 0.75], 'EdgeColor', 'none', 'FaceAlpha', 1);
	hold(ax, 'on');
	xline(ax, 0, '--', 'Color', [0.2 0.2 0.2], 'LineWidth', 1);
	xline(ax, permResult.ObservedDifference, '-', 'Color', lineColor, 'LineWidth', 2.2);
	xlim(ax, [xShownLo - pad, xShownHi + pad]);
	xlabel(ax, 'Permuted slope difference (Transfer - Naive)', 'FontSize', 12);
	ylabel(ax, 'Count', 'FontSize', 12);
	title(ax, 'Mouse-level permutation null (central 99%)', 'FontSize', 12, 'FontWeight', 'normal');
	box(ax, 'off');
	text(ax, 0.97, 0.97, {
		sprintf('obs = %.3f', permResult.ObservedDifference), ...
		sprintf('%s, n = %d', iFormatPLabel(permResult.PValue), permResult.NPermutation)
		}, 'Units', 'normalized', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', 'FontSize', 10);
end

function iAddPBracket(ax, x1, x2, y, labelText)
	yRange = ylim(ax);
	barH = diff(yRange) * 0.035;
	plot(ax, [x1 x1 x2 x2], [y - barH y y y - barH], '-', 'Color', [0.2 0.2 0.2], 'LineWidth', 1);
	text(ax, mean([x1 x2]), y + barH * 0.15, labelText, 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 10);
end

function s = iFormatPLabel(p)
	if ~isfinite(p)
		s = 'p = NaN';
	elseif p < 0.001
		s = 'p < 0.001';
	elseif p < 0.01
		s = sprintf('p = %.3f', p);
	else
		s = sprintf('p = %.2f', p);
	end
end

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
		error('Fig1B_Sigmoid_Significance:DuplicateMouseAcrossSources', ...
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
		error('Fig1B_Sigmoid_Significance:MouseInMultipleGroups', 'Some mice appear in multiple groups.\n%s', char(strjoin(msgLines, newline)));
	end
end

function T = iAddSessionIndex(T)
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

function fitOut = iFitSigmoidCurve(T, groupName)
	T = sortrows(T, {'Mouse','DateTime'});
	xObs = double(T.Session(:));
	yObs = double(T.Performance(:));
	use = isfinite(xObs) & isfinite(yObs);
	xObs = xObs(use);
	yObs = yObs(use);
	if isempty(xObs)
		error('Fig1B_Sigmoid_Significance:NoDataForGroup', 'No valid session data for group %s.', char(groupName));
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
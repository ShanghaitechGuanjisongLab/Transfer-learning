% Fig3C sigmoid fit: learning curves for cohorts used in Fig3C slope vs heterogeneity
%
% Output:
% - SVG figure to \\Data-Server-2\个人数据\杨青宁\202604
% - script copy and CSV summaries to the same directory

outDirUNC = '\\Data-Server-2\个人数据\杨青宁\202604';
svgName = 'Fig3C_LearningCurve_Sigmoid.svg';
scriptCopyName = 'Fig3C_LearningCurve_Sigmoid.m';
fitCsvName = 'Fig3C_LearningCurve_SigmoidFit.csv';
summaryCsvName = 'Fig3C_LearningCurve_SigmoidSummary.csv';
permCsvName = 'Fig3C_LearningCurve_SigmoidPermutation.csv';
statsTxtName = 'Fig3C_LearningCurve_SigmoidPermutation.txt';
perMouseFitCsvName = 'Fig3C_LearningCurve_SigmoidPerMouseFit.csv';
perMouseStatsTxtName = 'Fig3C_LearningCurve_SigmoidPerMouseStats.txt';

naiveMouseAllow = ["vtf0030"; "yqn0022"; "yqn0044"; "yqn0404"; "yqn0440"; "yqn1001"; "yqn1002"; "yqn1013"; "yqn2003"; "yqn2005"; "yqn3000"; "yqn3001"; "yqn3002"];
continualMouseAllow = ["vtf0233"; "vtf0352"; "vtf0353"; "vtf0354"; "vtf1233"; "yqn0133"; "yqn0411"; "yqn1018"];

if ~exist('TransferLearning','class') || ~exist('UniExp.DataSet','class')
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

DS_LAB = TransferLearning.LightAudioBaseline();
DS_LAI = TransferLearning.LAInterspersed();
DS_T = TransferLearning.AudioLightBaseline();

naiveSess = iGatherNaiveSessions(DS_LAB, DS_LAI);
naiveSess = iExcludeAudioWaterSessions(naiveSess, DS_LAB, DS_LAI);
naiveSess = iExcludeCeilingSessions(naiveSess);
[naiveUsed, naiveMice, ~] = iPerMouseSlopeSessions(naiveSess);
naiveUsed.Group(:) = "Naive";

contSess = iLightWaterSessions(DS_T);
contSess = iKeepPureLW_NoMustWarn(DS_T, contSess);
contSess = iKeepPhaseRange(DS_T, contSess, "Transfer", "Final");
contSess = iExcludeCeilingSessions(contSess);
contSess.Source(:) = "Transfer";
[contUsed, contMice, ~] = iPerMouseSlopeSessions(contSess);
contUsed.Group(:) = "Transfer";

if isempty(naiveUsed) || isempty(contUsed)
	error('Fig3C_Sigmoid:EmptyData', 'No valid sessions remained for one or both Fig3C cohorts.');
end

allSessions = [naiveUsed(:, {'Mouse','DateTime','Performance','Source','Group'}); contUsed(:, {'Mouse','DateTime','Performance','Source','Group'})];
allSessions = sortrows(allSessions, ["Group","Mouse","DateTime"]);
allSessions.Mouse = string(allSessions.Mouse);
keepNaive = string(allSessions.Group) == "Naive" & ismember(allSessions.Mouse, naiveMouseAllow);
keepContinual = string(allSessions.Group) == "Transfer" & ismember(allSessions.Mouse, continualMouseAllow);
allSessions = allSessions(keepNaive | keepContinual, :);
if ~any(keepNaive)
	error('Fig3C_Sigmoid:NoNaiveAfterFilter', 'No Naive mice remained after applying the fixed mouse list.');
end
if ~any(keepContinual)
	error('Fig3C_Sigmoid:NoContinualAfterFilter', 'No Continual mice remained after applying the fixed mouse list.');
end
allSessions = iAddSessionIndex(allSessions);

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
permResult = iPermutationTestSigmoidSlope(displayedNaive, displayedTransfer, 10000, 1);
perMouseFitTable = iFitSigmoidPerMouse([displayedNaive; displayedTransfer]);
perMouseStats = iComparePerMouseSigmoidSlope(perMouseFitTable);

xFit = (1:max([max(fitNaive.XObserved), max(fitTransfer.XObserved), max(x)])).';
naiveFitCurve = iSigmoidFromParams(fitNaive.ParamRaw, xFit);
transferFitCurve = iSigmoidFromParams(fitTransfer.ParamRaw, xFit);

f = figure('Color', 'w', 'Name', 'Fig3C learning curve sigmoid');
f.Units = 'centimeters';
f.Position(3:4) = [16, 10.5];
t = tiledlayout(f, 1, 2, 'TileSpacing', 'loose', 'Padding', 'loose');

palette = TransferLearning.FigurePalette(2);
axNaive = nexttile(t, 1);
iPlotGroupMouseCurves(axNaive, displayedNaive, xFit, naiveFitCurve, palette(1,:), "Naive", fitNaive);

axTransfer = nexttile(t, 2);
iPlotGroupMouseCurves(axTransfer, displayedTransfer, xFit, transferFitCurve, palette(2,:), "Continual", fitTransfer);

ylabel(axNaive, 'Hit rate', 'FontSize', 12);
xlabel(axNaive, 'Block', 'FontSize', 12);
xlabel(axTransfer, 'Block', 'FontSize', 12);
title(t, 'Fig3C learning curve sigmoid fit', 'FontSize', 12, 'FontWeight', 'normal');

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

permTable = table;
permTable.ObservedNaiveSlope = permResult.ObservedNaiveSlope;
permTable.ObservedContinualSlope = permResult.ObservedContinualSlope;
permTable.ObservedNaiveLogSlope = permResult.ObservedNaiveLogSlope;
permTable.ObservedContinualLogSlope = permResult.ObservedContinualLogSlope;
permTable.ObservedLogSlopeDifference = permResult.ObservedDifference;
permTable.PermutationPValue = permResult.PValue;
permTable.PermutationCount = permResult.NPermutation;
permTable.NullMeanDifference = mean(permResult.PermutedDifference, 'omitnan');
permTable.NullStdDifference = std(permResult.PermutedDifference, 'omitnan');
permTable.NullCI_Low = prctile(permResult.PermutedDifference, 2.5);
permTable.NullCI_High = prctile(permResult.PermutedDifference, 97.5);
writetable(permTable, fullfile(outDirUNC, permCsvName));
writetable(perMouseFitTable, fullfile(outDirUNC, perMouseFitCsvName));

summaryTable = table;
summaryTable.Block = x(:);
summaryTable.NaiveMean = meanMat(:,1);
summaryTable.ContinualMean = meanMat(:,2);
summaryTable.NaiveSem = semMat(:,1);
summaryTable.ContinualSem = semMat(:,2);
summaryTable.NaiveN = nMat(:,1);
summaryTable.ContinualN = nMat(:,2);
writetable(summaryTable, fullfile(outDirUNC, summaryCsvName));

statsPath = fullfile(outDirUNC, statsTxtName);
fid = fopen(statsPath, 'w');
if fid < 0
	error('Fig3C_Sigmoid:OpenStatsTxtFailed', 'Cannot open %s for writing.', statsPath);
end
cleanupObj = onCleanup(@() fclose(fid));
fprintf(fid, 'Fig3C sigmoid log-slope permutation test\n');
fprintf(fid, 'Observed Naive slope: %.6f\n', permResult.ObservedNaiveSlope);
fprintf(fid, 'Observed Continual slope: %.6f\n', permResult.ObservedContinualSlope);
fprintf(fid, 'Observed Naive log-slope: %.6f\n', permResult.ObservedNaiveLogSlope);
fprintf(fid, 'Observed Continual log-slope: %.6f\n', permResult.ObservedContinualLogSlope);
fprintf(fid, 'Observed log-slope difference (Continual - Naive): %.6f\n', permResult.ObservedDifference);
fprintf(fid, 'Permutation count: %d\n', permResult.NPermutation);
fprintf(fid, 'Two-sided permutation p-value: %.6g\n', permResult.PValue);
fprintf(fid, 'Null difference mean: %.6f\n', mean(permResult.PermutedDifference, 'omitnan'));
fprintf(fid, 'Null difference std: %.6f\n', std(permResult.PermutedDifference, 'omitnan'));
fprintf(fid, 'Null difference 95%% interval: [%.6f, %.6f]\n', prctile(permResult.PermutedDifference, 2.5), prctile(permResult.PermutedDifference, 97.5));

perMouseStatsPath = fullfile(outDirUNC, perMouseStatsTxtName);
fidPerMouse = fopen(perMouseStatsPath, 'w');
if fidPerMouse < 0
	error('Fig3C_Sigmoid:OpenPerMouseStatsTxtFailed', 'Cannot open %s for writing.', perMouseStatsPath);
end
cleanupPerMouse = onCleanup(@() fclose(fidPerMouse));
fprintf(fidPerMouse, 'Fig3C per-mouse sigmoid slope comparison\n');
fprintf(fidPerMouse, 'Naive mice fitted: %d\n', perMouseStats.NaiveCount);
fprintf(fidPerMouse, 'Continual mice fitted: %d\n', perMouseStats.ContinualCount);
fprintf(fidPerMouse, 'Naive slope median: %.6f\n', perMouseStats.NaiveSlopeMedian);
fprintf(fidPerMouse, 'Continual slope median: %.6f\n', perMouseStats.ContinualSlopeMedian);
fprintf(fidPerMouse, 'Naive log-slope median: %.6f\n', perMouseStats.NaiveLogSlopeMedian);
fprintf(fidPerMouse, 'Continual log-slope median: %.6f\n', perMouseStats.ContinualLogSlopeMedian);
fprintf(fidPerMouse, 'Ranksum p on slope: %.6g\n', perMouseStats.SlopePValue);
fprintf(fidPerMouse, 'Ranksum z on slope: %.6f\n', perMouseStats.SlopeZValue);
fprintf(fidPerMouse, 'Ranksum p on log-slope: %.6g\n', perMouseStats.LogSlopePValue);
fprintf(fidPerMouse, 'Ranksum z on log-slope: %.6f\n', perMouseStats.LogSlopeZValue);

fprintf('Wrote: %s\n', svgPath);
fprintf('Wrote: %s\n', fullfile(outDirUNC, scriptCopyName));
fprintf('Wrote: %s\n', fullfile(outDirUNC, fitCsvName));
fprintf('Wrote: %s\n', fullfile(outDirUNC, summaryCsvName));
fprintf('Wrote: %s\n', fullfile(outDirUNC, permCsvName));
fprintf('Wrote: %s\n', statsPath);
fprintf('Wrote: %s\n', fullfile(outDirUNC, perMouseFitCsvName));
fprintf('Wrote: %s\n', perMouseStatsPath);
fprintf('Naive mice used: %d\n', numel(unique(string(displayedNaive.Mouse))));
fprintf('Continual mice used: %d\n', numel(unique(string(displayedTransfer.Mouse))));
fprintf('Naive mouse list: %s\n', strjoin(unique(string(displayedNaive.Mouse), 'stable'), ', '));
fprintf('Continual mouse list: %s\n', strjoin(unique(string(displayedTransfer.Mouse), 'stable'), ', '));
fprintf('Naive sigmoid: lower=%.4f, upper=%.4f, slope=%.4f, midpoint=%.4f, R^2=%.4f\n', fitNaive.Lower, fitNaive.Upper, fitNaive.Slope, fitNaive.Midpoint, fitNaive.RSquared);
fprintf('Continual sigmoid: lower=%.4f, upper=%.4f, slope=%.4f, midpoint=%.4f, R^2=%.4f\n', fitTransfer.Lower, fitTransfer.Upper, fitTransfer.Slope, fitTransfer.Midpoint, fitTransfer.RSquared);
fprintf('Permutation log-slope difference (Continual - Naive): %.4f\n', permResult.ObservedDifference);
fprintf('Permutation two-sided p = %.4g (%d permutations)\n', permResult.PValue, permResult.NPermutation);
fprintf('Per-mouse ranksum p on slope = %.4g\n', perMouseStats.SlopePValue);
fprintf('Per-mouse ranksum p on log-slope = %.4g\n', perMouseStats.LogSlopePValue);

assignin('base', 'Fig3C_Sigmoid_AllSessions', allSessions);
assignin('base', 'Fig3C_Sigmoid_FitTable', fitTable);
assignin('base', 'Fig3C_Sigmoid_Summary', summaryTable);
assignin('base', 'Fig3C_Sigmoid_NaiveMice', naiveMice);
assignin('base', 'Fig3C_Sigmoid_ContinualMice', contMice);
assignin('base', 'Fig3C_Sigmoid_Permutation', permResult);
assignin('base', 'Fig3C_Sigmoid_PerMouseFit', perMouseFitTable);
assignin('base', 'Fig3C_Sigmoid_PerMouseStats', perMouseStats);

function [SessUsed, mice, slopeVec] = iPerMouseSlopeSessions(Sess)
	if isempty(Sess)
		SessUsed = Sess;
		mice = string.empty(0,1);
		slopeVec = [];
		return;
	end
	Sess = sortrows(Sess, {'Mouse','DateTime'});
	mice = unique(string(Sess.Mouse));
	slopeVec = nan(numel(mice), 1);
	keepRows = false(height(Sess), 1);
	for iM = 1:numel(mice)
		m = mice(iM);
		R = sortrows(Sess(string(Sess.Mouse) == m, :), 'DateTime');
		if height(R) < 2
			continue;
		end
		first100 = find(double(R.Performance) >= 1 - 1e-12, 1, 'first');
		if ~isempty(first100)
			if first100 == 1
				continue;
			end
			R = R(1:first100-1, :);
		end
		if height(R) < 2
			continue;
		end
		xi = (1:height(R))';
		yi = double(R.Performance);
		ok = isfinite(yi);
		if nnz(ok) < 2
			continue;
		end
		fitP = polyfit(xi(ok), yi(ok), 1);
		slopeVec(iM) = fitP(1);
		rows = string(Sess.Mouse) == m & ismember(Sess.DateTime, R.DateTime);
		if ismember('Source', Sess.Properties.VariableNames)
			rows = rows & ismember(string(Sess.Source), unique(string(R.Source)));
		end
		keepRows = keepRows | rows;
	end
	SessUsed = Sess(keepRows, :);
end

function Sess = iLightWaterSessions(DS)
	blockVars = string(DS.Blocks.Properties.VariableNames);
	if any(blockVars == "MustWarn")
		Blocks = DS.Blocks(:, {'BlockUID','DateTime','MustWarn'});
	else
		Blocks = DS.Blocks(:, {'BlockUID','DateTime'});
		Blocks.MustWarn = strings(height(Blocks), 1);
	end
	Blocks.BlockUID = uint64(Blocks.BlockUID);
	Blocks.DateTime = iNormDT(datetime(Blocks.DateTime));
	Blocks.MustWarn = string(Blocks.MustWarn);
	DT = DS.DateTimes(:, {'DateTime','Mouse','Phase'});
	DT.DateTime = iNormDT(datetime(DT.DateTime));
	DT.Mouse = string(DT.Mouse);
	DT.Phase = string(DT.Phase);
	Tr = DS.Trials(:, {'BlockUID','Stimulus','Behavior'});
	Tr.BlockUID = uint64(Tr.BlockUID);
	TrLW = Tr(string(Tr.Stimulus) == "LightWater", {'BlockUID','Behavior'});
	if isempty(TrLW)
		Sess = table(string.empty(0,1), NaT(0,1), string.empty(0,1), nan(0,1), ...
			'VariableNames', {'Mouse','DateTime','Phase','Performance'});
		return;
	end
	[G, bu] = findgroups(uint64(TrLW.BlockUID));
	lwPerf = splitapply(@(x) mean(double(x), 'omitnan'), TrLW.Behavior, G);
	perfByBlock = table(uint64(bu), lwPerf, 'VariableNames', {'BlockUID','LWPerf'});
	T = innerjoin(perfByBlock, Blocks, 'Keys', 'BlockUID');
	keep = ismissing(T.MustWarn) | (T.MustWarn == "");
	T = T(keep, :);
	T = innerjoin(T, DT, 'Keys', 'DateTime');
	[G2, mouse, dt] = findgroups(T.Mouse, T.DateTime);
	perf2 = splitapply(@(x) mean(double(x), 'omitnan'), T.LWPerf, G2);
	phase2 = splitapply(@(x) string(x(1)), T.Phase, G2);
	Sess = table(mouse, dt, phase2, perf2, 'VariableNames', {'Mouse','DateTime','Phase','Performance'});
	Sess = sortrows(Sess, {'Mouse','DateTime'});
end

function SessOut = iKeepPureLW_NoMustWarn(DS, SessIn)
	SessOut = SessIn;
	if isempty(SessOut)
		return;
	end
	Blocks = DS.Blocks(:, {'BlockUID','DateTime'});
	Blocks.BlockUID = uint64(Blocks.BlockUID);
	Blocks.DateTime = iNormDT(datetime(Blocks.DateTime));
	Tr = DS.Trials(:, {'BlockUID','Stimulus'});
	Tr.BlockUID = uint64(Tr.BlockUID);
	TrAW = Tr(string(Tr.Stimulus) == "AudioWater", {'BlockUID'});
	if isempty(TrAW)
		return;
	end
	blkAW = unique(uint64(TrAW.BlockUID));
	TAW = innerjoin(table(blkAW, 'VariableNames', {'BlockUID'}), Blocks, 'Keys', 'BlockUID');
	dtAW = unique(TAW.DateTime);
	SessOut = SessOut(~ismember(SessOut.DateTime, dtAW), :);
end

function SessOut = iKeepPhaseRange(DS, SessIn, phaseStart, phaseEnd)
	SessOut = SessIn;
	if isempty(SessOut)
		return;
	end
	DT = DS.DateTimes(:, {'DateTime','Mouse','Phase'});
	DT.DateTime = iNormDT(datetime(DT.DateTime));
	DT.Mouse = string(DT.Mouse);
	DT.Phase = string(DT.Phase);
	keep = false(height(SessOut), 1);
	for m = unique(string(SessOut.Mouse))'
		dtM = DT(DT.Mouse == m, :);
		phDates = dtM.DateTime(dtM.Phase == phaseStart);
		endDates = dtM.DateTime(dtM.Phase == phaseEnd);
		if isempty(phDates) || isempty(endDates)
			continue;
		end
		startDT = min(phDates);
		endDT = max(endDates);
		rows = (string(SessOut.Mouse) == m) & (SessOut.DateTime >= startDT) & (SessOut.DateTime <= endDT);
		keep = keep | rows;
	end
	SessOut = SessOut(keep, :);
end

function AllSess = iGatherNaiveSessions(LAB, LAI)
	AllSess = table(strings(0,1), NaT(0,1), nan(0,1), strings(0,1), 'VariableNames', {'Mouse','DateTime','Performance','Source'});
	for iDS = 1:2
		if iDS == 1
			DS = LAB;
			srcName = "LAB";
		else
			DS = LAI;
			srcName = "LAI";
		end
		T = DS.TableQuery(["Mouse","DateTime","Phase","BlockUID"]);
		T.Mouse = string(T.Mouse);
		T.DateTime = iNormDT(datetime(T.DateTime));
		T.Phase = string(T.Phase);
		Tr = DS.Trials;
		mice = unique(T.Mouse);
		for iM = 1:numel(mice)
			m = mice(iM);
			Tm = T(T.Mouse == m, :);
			phases = unique(Tm.Phase);
			if ~any(phases == "Naive")
				continue;
			end
			hasLearned = any(phases == "Learned");
			hasTransfer = any(phases == "Transfer");
			sessDTs = sort(unique(Tm.DateTime));
			sessPhase = strings(numel(sessDTs), 1);
			for ii = 1:numel(sessDTs)
				ph = Tm.Phase(Tm.DateTime == sessDTs(ii));
				ph = ph(ph ~= "" & ~ismissing(ph));
				if isempty(ph)
					sessPhase(ii) = "";
					continue;
				end
				[uPh, ~, ic] = unique(ph);
				counts = accumarray(ic, 1);
				[~, mx] = max(counts);
				sessPhase(ii) = uPh(mx);
			end
			idxNaiveStart = find(sessPhase == "Naive", 1, 'first');
			if hasLearned
				idxEnd = find(sessPhase == "Learned", 1, 'last');
			elseif hasTransfer
				idxEnd = find(sessPhase == "Transfer", 1, 'first') - 1;
			else
				idxEnd = numel(sessDTs);
			end
			if isempty(idxNaiveStart) || idxEnd < idxNaiveStart
				continue;
			end
			for k = idxNaiveStart:idxEnd
				dt = sessDTs(k);
				blks = uint64(Tm.BlockUID(Tm.DateTime == dt));
				TrSess = Tr(ismember(uint64(Tr.BlockUID), blks), :);
				if isempty(TrSess)
					continue;
				end
				lwMask = string(TrSess.Stimulus) == "LightWater";
				if ~any(lwMask)
					continue;
				end
				perf = mean(double(TrSess.Behavior(lwMask)), 'omitnan');
				if ~isfinite(perf)
					continue;
				end
				AllSess = [AllSess; table(m, dt, perf, srcName, 'VariableNames', {'Mouse','DateTime','Performance','Source'})]; %#ok<AGROW>
			end
		end
	end
	AllSess = sortrows(AllSess, {'Mouse','DateTime'});
	[~, ia] = unique(AllSess(:, {'Mouse','DateTime'}), 'rows');
	AllSess = AllSess(ia, :);
end

function AllSess = iExcludeAudioWaterSessions(AllSess, LAB, LAI)
	keep = true(height(AllSess), 1);
	for i = 1:height(AllSess)
		if AllSess.Source(i) == "LAB"
			DS = LAB;
		else
			DS = LAI;
		end
		if iHasStimulus(DS, AllSess.Mouse(i), AllSess.DateTime(i), "AudioWater")
			keep(i) = false;
		end
	end
	AllSess = AllSess(keep, :);
end

function SessOut = iExcludeCeilingSessions(SessIn)
	SessOut = sortrows(SessIn, {'Mouse','DateTime'});
	remove = false(height(SessOut), 1);
	for m = unique(SessOut.Mouse)'
		rows = find(SessOut.Mouse == m);
		p = double(SessOut.Performance(rows));
		i100 = find(p >= 1 - 1e-12, 1, 'first');
		if ~isempty(i100)
			remove(rows(i100:end)) = true;
		end
	end
	SessOut(remove, :) = [];
	perf = double(SessOut.Performance);
	SessOut = SessOut(isfinite(perf) & perf >= -1e-12 & perf < 1 - 1e-12, :);
end

function tf = iHasStimulus(DS, mouseName, dt, stim)
	tf = false;
	Tdt = DS.TableQuery("Stimulus", Mouse=string(mouseName), DateTime=dt);
	if isempty(Tdt) || ~ismember('Stimulus', Tdt.Properties.VariableNames)
		return;
	end
	st = unique(string(Tdt.Stimulus));
	st = st(~ismissing(st));
	tf = any(st == string(stim));
end

function dt = iNormDT(dt)
	try
		if isdatetime(dt) && ~isempty(dt.TimeZone)
			dt.TimeZone = '';
		end
	catch
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
			meanMat(1:numel(mv), k) = mv;
			semMat(1:numel(sv), k) = sv;
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
		lg = legend(ax, [mouseHandles(1), fitHandle], {'Per-mouse hit rate', 'Sigmoid fit'}, 'Location', 'southoutside');
		lg.FontSize = 9;
		lg.Box = 'off';
		lg.NumColumns = 2;
	end
	xlabel(ax, 'Block', 'FontSize', 12);
	ylim(ax, [0 1.02]);
	xlim(ax, [1 max(xFit)]);
	box(ax, 'off');
	grid(ax, 'off');
	title(ax, {
		sprintf('%s (n=%d mice)', char(groupName), nMice), ...
		sprintf('lower=%.3f, upper=%.3f', fitStruct.Lower, fitStruct.Upper), ...
		sprintf('slope=%.3f, midpoint=%.2f', fitStruct.Slope, fitStruct.Midpoint)
		}, 'FontSize', 10, 'FontWeight', 'normal');
end

function fitOut = iFitSigmoidCurve(T, groupName)
	T = sortrows(T, {'Mouse','DateTime'});
	xObs = double(T.Session(:));
	yObs = double(T.Performance(:));
	use = isfinite(xObs) & isfinite(yObs);
	xObs = xObs(use);
	yObs = yObs(use);
	if isempty(xObs)
		error('Fig3C_Sigmoid:NoDataForGroup', 'No valid session data for group %s.', char(groupName));
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
	fitOut.LogSlope = p(2);
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
	allMice = [naiveMice; transferMice];
	for i = 1:numel(naiveMice)
		allMouseTables{i} = TNaive(string(TNaive.Mouse) == naiveMice(i), :);
	end
	for i = 1:numel(transferMice)
		allMouseTables{numel(naiveMice) + i} = TTransfer(string(TTransfer.Mouse) == transferMice(i), :);
	end
	fitNaive = iFitSigmoidCurve(TNaive, "Naive");
	fitTransfer = iFitSigmoidCurve(TTransfer, "Continual");
	observedDiff = fitTransfer.LogSlope - fitNaive.LogSlope;
	permDiff = nan(nPermutation, 1);
	nNaive = numel(naiveMice);
	for iPerm = 1:nPermutation
		ord = randperm(numel(allMice));
		idxNaive = ord(1:nNaive);
		idxTransfer = ord(nNaive+1:end);
		permNaive = vertcat(allMouseTables{idxNaive});
		permTransfer = vertcat(allMouseTables{idxTransfer});
		fitPermNaive = iFitSigmoidCurve(permNaive, "NaivePerm");
		fitPermTransfer = iFitSigmoidCurve(permTransfer, "TransferPerm");
		permDiff(iPerm) = fitPermTransfer.LogSlope - fitPermNaive.LogSlope;
	end
	pValue = mean(abs(permDiff) >= abs(observedDiff));
	permOut = struct;
	permOut.ObservedNaiveSlope = fitNaive.Slope;
	permOut.ObservedContinualSlope = fitTransfer.Slope;
	permOut.ObservedNaiveLogSlope = fitNaive.LogSlope;
	permOut.ObservedContinualLogSlope = fitTransfer.LogSlope;
	permOut.ObservedDifference = observedDiff;
	permOut.PermutedDifference = permDiff;
	permOut.PValue = pValue;
	permOut.NPermutation = nPermutation;
end

function fitTable = iFitSigmoidPerMouse(T)
	T = sortrows(T, {'Group','Mouse','DateTime'});
	mice = unique(string(T.Mouse), 'stable');
	groupPerMouse = strings(numel(mice), 1);
	lowerVec = nan(numel(mice), 1);
	upperVec = nan(numel(mice), 1);
	logSlopeVec = nan(numel(mice), 1);
	slopeVec = nan(numel(mice), 1);
	midpointVec = nan(numel(mice), 1);
	sseVec = nan(numel(mice), 1);
	rSquaredVec = nan(numel(mice), 1);
	nSessionVec = zeros(numel(mice), 1);
	keep = false(numel(mice), 1);
	for iMouse = 1:numel(mice)
		mouseRows = string(T.Mouse) == mice(iMouse);
		mouseTable = T(mouseRows, :);
		mouseTable = sortrows(mouseTable, 'DateTime');
		groupPerMouse(iMouse) = string(mouseTable.Group(1));
		finiteRows = isfinite(double(mouseTable.Session)) & isfinite(double(mouseTable.Performance));
		mouseTable = mouseTable(finiteRows, :);
		nSessionVec(iMouse) = height(mouseTable);
		if height(mouseTable) < 2
			continue;
		end
		if numel(unique(double(mouseTable.Performance))) < 2
			continue;
		end
		fitMouse = iFitSigmoidCurve(mouseTable, mice(iMouse));
		lowerVec(iMouse) = fitMouse.Lower;
		upperVec(iMouse) = fitMouse.Upper;
		logSlopeVec(iMouse) = fitMouse.LogSlope;
		slopeVec(iMouse) = fitMouse.Slope;
		midpointVec(iMouse) = fitMouse.Midpoint;
		sseVec(iMouse) = fitMouse.SSE;
		rSquaredVec(iMouse) = fitMouse.RSquared;
		keep(iMouse) = true;
	end
	fitTable = table;
	fitTable.Group = groupPerMouse(keep);
	fitTable.Mouse = mice(keep);
	fitTable.NSession = nSessionVec(keep);
	fitTable.Lower = lowerVec(keep);
	fitTable.Upper = upperVec(keep);
	fitTable.LogSlope = logSlopeVec(keep);
	fitTable.Slope = slopeVec(keep);
	fitTable.Midpoint = midpointVec(keep);
	fitTable.SSE = sseVec(keep);
	fitTable.RSquared = rSquaredVec(keep);
	fitTable = sortrows(fitTable, {'Group','Mouse'});
end

function statsOut = iComparePerMouseSigmoidSlope(fitTable)
	naiveRows = string(fitTable.Group) == "Naive";
	continualRows = string(fitTable.Group) == "Transfer";
	naiveSlope = fitTable.Slope(naiveRows);
	continualSlope = fitTable.Slope(continualRows);
	naiveLogSlope = fitTable.LogSlope(naiveRows);
	continualLogSlope = fitTable.LogSlope(continualRows);
	[slopePValue, ~, slopeStats] = ranksum(naiveSlope, continualSlope);
	[logSlopePValue, ~, logSlopeStats] = ranksum(naiveLogSlope, continualLogSlope);
	statsOut = struct;
	statsOut.NaiveCount = nnz(naiveRows);
	statsOut.ContinualCount = nnz(continualRows);
	statsOut.NaiveSlopeMedian = median(naiveSlope, 'omitnan');
	statsOut.ContinualSlopeMedian = median(continualSlope, 'omitnan');
	statsOut.NaiveLogSlopeMedian = median(naiveLogSlope, 'omitnan');
	statsOut.ContinualLogSlopeMedian = median(continualLogSlope, 'omitnan');
	statsOut.SlopePValue = slopePValue;
	statsOut.SlopeZValue = slopeStats.zval;
	statsOut.LogSlopePValue = logSlopePValue;
	statsOut.LogSlopeZValue = logSlopeStats.zval;
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
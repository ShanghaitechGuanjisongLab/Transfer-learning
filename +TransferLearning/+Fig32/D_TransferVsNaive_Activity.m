% 图3.2d（按论文大纲口径）：Transfer 与 Naive 对比（2 panels）
%
% 大纲要求：
% 1) 1s 处 ZScore（swarmchart + p 值线）
% 2) 活跃细胞占比（swarmchart + p 值线）
%
% Active cell 定义（硬性口径）：
%   QueryNTATS Median ZScore 的 1s 值 > mean(-3~0s) + 3*std(-3~0s)
%
% 数据：
% - Naive cohort（imaging cohorts 合并）：
%     LAB = TransferLearning.LightAudioBaseline()  Phase=Naive/Learned Stimulus=LightWater
%     LAI = TransferLearning.LAInterspersed()      Phase=Naive/Learned Stimulus=LightWater
% - Transfer cohort：
%     ALB = TransferLearning.AudioLightBaseline()  Phase=Transfer/Final Stimulus=LightWater
%     + LearnedAudio (for exclusion): Phase=Learned Stimulus=AudioWater
%
% Output:
% - SVG only to \\Data-Server-2\个人数据\张天夫\202601
%
% Execution（重要约束）：
% - 本文件必须是脚本（不得改为 function 文件）。
% - 以包名方式调用，不要用 run：
%     TransferLearning.Fig32.D_TransferVsNaive_Activity

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
excludeMice = string([]);

% --- 0) Ensure project loaded (for UniExp)
try
	if ~exist('UniExp.DataSet','class')
		thisFile = mfilename('fullpath');
		thisDir = fileparts(thisFile);
		prjFile = fullfile(thisDir, '..', '..', 'Transferlearning.prj');
		if exist(prjFile,'file')
			try
				matlab.project.loadProject(prjFile);
			catch
			end
		end
	end
catch
end

% DataSets
LAB = TransferLearning.LightAudioBaseline();
LAI = TransferLearning.LAInterspersed();
ALB = TransferLearning.AudioLightBaseline();

% Time axis
xsSec = seconds(TransferLearning.Xs);
baseMask = (xsSec >= -3) & (xsSec < 0);
if ~any(baseMask)
	error('Fig3_2dOutline1s:BadTimeMask', 'Baseline(-3~0) has no samples.');
end
idx1 = find(xsSec == 1, 1, 'first');
if isempty(idx1)
	[dtMin, idx1] = min(abs(xsSec - 1));
	if isempty(idx1) || ~isfinite(dtMin) || dtMin > 0.25
		error('Fig3_2dOutline1s:No1sSample', 'Cannot find a sample close to 1s in TransferLearning.Xs.');
	end
end
kSigma = 3;
minCells = 10;
minTrials = 1;

% --------------------
% 1) Naive/Learned LightWater cohort (merged imaging cohorts; exclude mixed sessions)
excludeMice = string(excludeMice);
labMice = iMiceWithPhaseStimulus(LAB, "Naive", "LightWater", excludeMice);
laiMice = iMiceWithPhaseStimulus(LAI, "Naive", "LightWater", excludeMice);

% Capture exclusion diagnostics
[naiveA, skipA] = iNaiveMouseRowsOneDataSet(LAB, labMice, baseMask, idx1, kSigma, minTrials, minCells, xsSec);
[naiveB, skipB] = iNaiveMouseRowsOneDataSet(LAI, laiMice, baseMask, idx1, kSigma, minTrials, minCells, xsSec);
naive = [naiveA; naiveB];
naive.Group(:) = "Naive";
naive = iRemoveDuplicateMice(naive, "Naive");

% --------------------
% 2) Transfer cohort: first Transfer(LightWater) and last Final(LightWater)
tran = iTransferMouseRows(ALB, excludeMice, baseMask, idx1, kSigma, minTrials, minCells, xsSec);
tran.Group(:) = "Transfer";

assignin('base','Fig3_2dOutline1s_NaiveRows', naive);
assignin('base','Fig3_2dOutline1s_TransferRows', tran);
try
	skipNaive = [skipA; skipB];
	assignin('base','Fig3_2dOutline1s_NaiveSkip', skipNaive);
catch
end

% Extra diagnostics: distinguish "no Learned LightWater" vs "Learned LightWater exists but mixed with AudioWater"
try
	diagLab = iMouseSessionPurityDiag(LAB, labMice, phaseName="Learned", stimulusName="LightWater", forbiddenStimulus="AudioWater");
	diagLab.Source(:) = "LightAudioBaseline";
	diagLai = iMouseSessionPurityDiag(LAI, laiMice, phaseName="Learned", stimulusName="LightWater", forbiddenStimulus="AudioWater");
	diagLai.Source(:) = "LAInterspersed";
	diag = [diagLab; diagLai];
	assignin('base','Fig3_2dOutline1s_NaiveLearnedLight_PurityDiag', diag);
catch
end

% --------------------
% Stats
pZ = iRankSumP(naive.MeanZAt1s_All, tran.MeanZAt1s_All);
pAct = iRankSumP(naive.ActiveRate, tran.ActiveRate);

fprintf('Fig3.2d Panel1 Z@1s: ranksum(N vs T) p=%.3g\n', pZ);
fprintf('Fig3.2d Panel2 ActiveRate: ranksum(N vs T) p=%.3g\n', pAct);
%% 

svgName = "Fig3_2d_TransferVsNaive_Activity_1sZ_ActiveRate.svg";
% --------------------
% Plot
f = figure('Color','w', 'Name','Fig3.2d Transfer vs Naive');
try
	MATLAB.Graphics.FigureAspectRatio(8,5,1/2);
catch
end
TL = tiledlayout(1,2,'TileSpacing','compact','Padding','compact');

% (1) ZScore at 1s
ax1 = nexttile(TL, 1);
hold(ax1,'on');
iHideToolbar(ax1);
iSwarm2(ax1, naive.MeanZAt1s_All, tran.MeanZAt1s_All, {'Naive','Transfer'}, 'Z@1s', pZ);

% (2) Active cell proportion
ax2 = nexttile(TL, 2);
hold(ax2,'on');
iHideToolbar(ax2);
iSwarm2(ax2, naive.ActiveRate, tran.ActiveRate, {'Naive','Transfer'}, 'Active cell rate', pAct);

grid(ax1,'on'); box(ax1,'on');
grid(ax2,'on'); box(ax2,'on');

% No figure-number titles in exported figure
try
	sgtitle(TL, '', 'Interpreter','none');
catch
end

% Export
try
	if ~isfolder(outDirUNC)
		mkdir(outDirUNC);
	end
catch
end
svgPath = fullfile(outDirUNC, svgName);
try
	exportgraphics(f, svgPath, 'ContentType','vector');
	fprintf('Wrote: %s\n', svgPath);
catch ME
	warning(ME.identifier, 'Export failed: %s', ME.message);
end

%% --- local functions

function mice = iMiceWithPhaseStimulus(DS, phaseName, stimulusName, excludeMice)
	mice = string([]);
	try
		T = DS.TableQuery(["Mouse"], Phase=phaseName, Stimulus=stimulusName);
		if isempty(T)
			return;
		end
		mice = unique(string(T.Mouse));
		mice = mice(~ismissing(mice));
		mice = mice(~ismember(mice, string(excludeMice)));
	catch
		mice = string([]);
	end
end

function [rows, skip] = iNaiveMouseRowsOneDataSet(DS, mice, baseMask, idx1, kSigma, minTrials, minCells, xsSec)
	rows = table(string.empty(0,1), string.empty(0,1), NaT(0,1), NaT(0,1), ...
		nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), ...
		nan(0,1), nan(0,1), ...
		cell(0,1), ...
		string.empty(0,1), ...
		'VariableNames', {'Mouse','Source','DateTimeNaive','DateTimeLearned', ...
		'NTrialsNaive','NTrialsLearned','NCellsNaive','MeanZAt1s_All','ActiveRate','NActive', ...
		'Reuse_NL_over_Learned','Reuse_NL_over_Naive', ...
		'MeanCurve_All', ...
		'Group'});
	skip = table(string.empty(0,1), string.empty(0,1), string.empty(0,1), ...
		'VariableNames', {'Mouse','Source','Reason'});

	for iM = 1:numel(mice)
		m = mice(iM);
		[Tn, dtN] = iTrialsByMousePureSession(DS, m, "Naive", "LightWater", "first", forbiddenStimulus="AudioWater");
		[Tl, dtL] = iTrialsByMousePureSession(DS, m, "Learned", "LightWater", "last", forbiddenStimulus="AudioWater");
		if isempty(Tn)
			skip = [skip; table(m, string(class(DS)), "NoPureNaiveLightSession", 'VariableNames', skip.Properties.VariableNames)]; %#ok<AGROW>
			continue;
		end
		if isempty(Tl)
			skip = [skip; table(m, string(class(DS)), "NoPureLearnedLightSession", 'VariableNames', skip.Properties.VariableNames)]; %#ok<AGROW>
			continue;
		end
		if numel(Tn) < minTrials
			skip = [skip; table(m, string(class(DS)), "TooFewNaiveTrials", 'VariableNames', skip.Properties.VariableNames)]; %#ok<AGROW>
			continue;
		end
		if numel(Tl) < minTrials
			skip = [skip; table(m, string(class(DS)), "TooFewLearnedTrials", 'VariableNames', skip.Properties.VariableNames)]; %#ok<AGROW>
			continue;
		end
		cellUID = iMouseCellUID(DS, m);
		if isempty(cellUID)
			skip = [skip; table(m, string(class(DS)), "NoCellsForMouse", 'VariableNames', skip.Properties.VariableNames)]; %#ok<AGROW>
			continue;
		end
		Zn = iMedianTraceZScore(DS, cellUID, Tn);
		Zl = iMedianTraceZScore(DS, cellUID, Tl);
		if isempty(Zn) || isempty(Zl)
			skip = [skip; table(m, string(class(DS)), "QueryNTATSEmpty", 'VariableNames', skip.Properties.VariableNames)]; %#ok<AGROW>
			continue;
		end
		% Intersect cells to make reuse meaningful
		uid = intersect(uint64(Zn.CellUID), uint64(Zl.CellUID));
		if numel(uid) < minCells
			skip = [skip; table(m, string(class(DS)), sprintf("TooFewCommonCells(%d)", numel(uid)), 'VariableNames', skip.Properties.VariableNames)]; %#ok<AGROW>
			continue;
		end
		Zn = sortrows(Zn(ismember(uint64(Zn.CellUID), uid), :), 'CellUID');
		Zl = sortrows(Zl(ismember(uint64(Zl.CellUID), uid), :), 'CellUID');

		actN = iActiveAt1s(Zn.Trace, baseMask, idx1, kSigma);
		actL = iActiveAt1s(Zl.Trace, baseMask, idx1, kSigma);

		uidActN = uid(actN);
		uidActL = uid(actL);

		denL = numel(uidActL);
		denN = numel(uidActN);
		reuseNL_over_L = NaN;
		reuseNL_over_N = NaN;
		if denL > 0
			reuseNL_over_L = numel(intersect(uidActN, uidActL)) / denL;
		end
		if denN > 0
			reuseNL_over_N = numel(intersect(uidActN, uidActL)) / denN;
		end

		meanZ1 = mean(Zn.Trace(:, idx1), 'omitnan');
		activeRate = mean(double(actN), 'omitnan');

		meanCurve = mean(Zn.Trace, 1, 'omitnan');
		meanCurve = meanCurve(:);
		if numel(meanCurve) ~= numel(xsSec)
			continue;
		end

		rows = [rows; table(m, string(class(DS)), dtN, dtL, ...
			numel(Tn), numel(Tl), numel(uid), meanZ1, activeRate, nnz(actN), ...
			reuseNL_over_L, reuseNL_over_N, ...
			{meanCurve}, "", ...
			'VariableNames', rows.Properties.VariableNames)]; %#ok<AGROW>
	end
end

function rows = iTransferMouseRows(DS, excludeMice, baseMask, idx1, kSigma, minTrials, minCells, xsSec)
	% Transfer cohort: first Transfer(LightWater), last Final(LightWater), last Learned(AudioWater)
	Tt = iTableQueryOrEmpty(DS, ["Mouse"], Phase="Transfer", Stimulus="LightWater");
	Tf = iTableQueryOrEmpty(DS, ["Mouse"], Phase="Final", Stimulus="LightWater");
	Tl = iTableQueryOrEmpty(DS, ["Mouse"], Phase="Learned", Stimulus="AudioWater");
	if isempty(Tt) || isempty(Tf) || isempty(Tl)
		error('Fig3_2dOutline1s:MissingTrials', 'Missing Transfer/Final LightWater or Learned AudioWater trials.');
	end
	mice = intersect(intersect(unique(string(Tt.Mouse)), unique(string(Tf.Mouse))), unique(string(Tl.Mouse)));
	mice = mice(~ismember(mice, string(excludeMice)));

	rows = table(string.empty(0,1), NaT(0,1), NaT(0,1), NaT(0,1), ...
		nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), ...
		nan(0,1), nan(0,1), nan(0,1), ...
		cell(0,1), ...
		string.empty(0,1), ...
		'VariableNames', {'Mouse','DateTimeTransfer','DateTimeFinal','DateTimeLearnedAudio', ...
		'NTrialsTransfer','NTrialsFinal','NTrialsLearnedAudio','NCellsCommonTF','MeanZAt1s_All','ActiveRate', ...
		'Reuse_TF_over_Final','Reuse_TF_over_Final_exclLearnedAudio','NFinalActive', ...
		'MeanCurve_All', ...
		'Group'});

	for iM = 1:numel(mice)
		m = mice(iM);
		[Ttr, dtT] = iTrialsByMousePureSession(DS, m, "Transfer", "LightWater", "first", forbiddenStimulus="AudioWater");
		[Tfi, dtF] = iTrialsByMousePureSession(DS, m, "Final", "LightWater", "last", forbiddenStimulus="AudioWater");
		[Tla, dtLA] = iTrialsByMousePureSession(DS, m, "Learned", "AudioWater", "last", forbiddenStimulus="LightWater");
		if isempty(Ttr) || isempty(Tfi) || isempty(Tla) || numel(Ttr) < minTrials || numel(Tfi) < minTrials || numel(Tla) < minTrials
			continue;
		end

		cellUID = iMouseCellUID(DS, m);
		if isempty(cellUID)
			continue;
		end

		ZT = iMedianTraceZScore(DS, cellUID, Ttr);
		ZF = iMedianTraceZScore(DS, cellUID, Tfi);
		ZLA = iMedianTraceZScore(DS, cellUID, Tla);
		if isempty(ZT) || isempty(ZF) || isempty(ZLA)
			continue;
		end

		uidTF = intersect(uint64(ZT.CellUID), uint64(ZF.CellUID));
		if numel(uidTF) < minCells
			continue;
		end
		ZT = sortrows(ZT(ismember(uint64(ZT.CellUID), uidTF), :), 'CellUID');
		ZF = sortrows(ZF(ismember(uint64(ZF.CellUID), uidTF), :), 'CellUID');
		uidTF = uint64(ZT.CellUID);

		actT = iActiveAt1s(ZT.Trace, baseMask, idx1, kSigma);
		actF = iActiveAt1s(ZF.Trace, baseMask, idx1, kSigma);

		uidActT = uidTF(actT);
		uidActF = uidTF(actF);
		denF = numel(uidActF);
		if denF < 1
			continue;
		end

		reuseTF = numel(intersect(uidActT, uidActF)) / denF;

		% LearnedAudio active set (no need to intersect with TF beyond UID membership)
		uidLA = uint64(ZLA.CellUID);
		actLA = iActiveAt1s(ZLA.Trace, baseMask, idx1, kSigma);
		uidActLA = uidLA(actLA);
		uidActT_nonLA = setdiff(uidActT, uidActLA);
		reuseTFnon = numel(intersect(uidActT_nonLA, uidActF)) / denF;

		meanZ1 = mean(ZT.Trace(:, idx1), 'omitnan');
		activeRate = mean(double(actT), 'omitnan');

		meanCurve = mean(ZT.Trace, 1, 'omitnan');
		meanCurve = meanCurve(:);
		if numel(meanCurve) ~= numel(xsSec)
			continue;
		end

		rows = [rows; table(m, dtT, dtF, dtLA, ...
			numel(Ttr), numel(Tfi), numel(Tla), numel(uidTF), meanZ1, activeRate, ...
			reuseTF, reuseTFnon, denF, ...
			{meanCurve}, "", ...
			'VariableNames', rows.Properties.VariableNames)]; %#ok<AGROW>
	end
end

function [trialUID, dt] = iTrialsByMousePureSession(DS, mouseName, phaseName, stimulusName, whichOne, opts)
	% Pick a session (DateTime) within mouse+phase that contains the desired stimulus,
	% and DOES NOT contain any forbiddenStimulus within the same DateTime.
	arguments
		DS
		mouseName
		phaseName
		stimulusName
		whichOne
		opts.forbiddenStimulus string = string([])
	end
	trialUID = uint64([]);
	dt = NaT;
	forbidden = string(opts.forbiddenStimulus);
	try
		T = iTableQueryOrEmpty(DS, ["TrialUID","Mouse","DateTime","Phase","Stimulus"], Mouse=mouseName, Phase=phaseName);
		if isempty(T)
			return;
		end
		T.Mouse = string(T.Mouse);
		T.Phase = string(T.Phase);
		T.Stimulus = string(T.Stimulus);
		T = T(string(T.Mouse)==string(mouseName), :);
		if isempty(T)
			return;
		end
		T = iNormalizeDateTime(T);
		T = T(~ismissing(T.DateTime), :);
		if isempty(T)
			return;
		end
		T = sortrows(T, 'DateTime');
		allDT = unique(T.DateTime, 'stable');
		if isempty(allDT)
			return;
		end
		if strcmpi(whichOne, 'last')
			allDT = flipud(allDT);
		end
		for iD = 1:numel(allDT)
			dtTry = allDT(iD);
			Ti = T(T.DateTime==dtTry, :);
			stims = unique(string(Ti.Stimulus));
			stims = stims(~ismissing(stims));
			if isempty(stims)
				continue;
			end
			% Must include desired stimulus
			if ~any(stims == string(stimulusName))
				continue;
			end
			% Must NOT contain forbidden stimulus
			if ~isempty(forbidden) && any(stims == forbidden)
				continue;
			end
			% Return only trials of the desired stimulus in that session
			Tu = unique(uint64(Ti.TrialUID(string(Ti.Stimulus)==string(stimulusName))));
			if isempty(Tu)
				continue;
			end
			dt = dtTry;
			trialUID = Tu;
			return;
		end
	catch
		trialUID = uint64([]);
		dt = NaT;
	end
end

function T = iTableQueryOrEmpty(DS, vars, varargin)
	try
		T = DS.TableQuery(vars, varargin{:});
	catch
		T = [];
	end
	if isempty(T)
		return;
	end
	T = iNormalizeDateTime(T);
end

function T = iNormalizeDateTime(T)
	if isempty(T) || ~ismember('DateTime', T.Properties.VariableNames)
		return;
	end
	try
		T.DateTime = datetime(T.DateTime);
		T.DateTime.TimeZone = '';
	catch
	end
end

function G = iQueryNTATSOrEmpty(DS, query)
	try
		G = DS.QueryNTATS(query, UniExp.Flags.ZScore, 1:24, UniExp.Flags.Median);
	catch
		G = [];
	end
end

function X = iNtatsData(NT)
	if isa(NT, 'MATLAB.DataTypes.NDTable')
		X = NT.Data;
	else
		X = NT;
	end
	X = squeeze(X);
end

function Z = iMedianTraceZScore(DS, cellUID, trialUID)
	Z = [];
	if isempty(cellUID) || isempty(trialUID)
		return;
	end
	q = struct('CellUID', uint64(cellUID), 'TrialUID', uint64(trialUID));
	G = iQueryNTATSOrEmpty(DS, q);
	if isempty(G) || ~all(ismember({'CellUID','NTATS'}, G.Properties.VariableNames))
		return;
	end
	X = iNtatsData(G.NTATS);
	if isempty(X)
		return;
	end
	Z = table(uint64(G.CellUID), X, 'VariableNames', {'CellUID','Trace'});
end

function cellUID = iMouseCellUID(DS, mouseName)
	cellUID = uint64([]);
	try
		C = DS.Cells;
		if isempty(C) || ~all(ismember({'Mouse','CellUID'}, C.Properties.VariableNames))
			return;
		end
		m = string(mouseName);
		C.Mouse = string(C.Mouse);
		cellUID = unique(uint64(C.CellUID(C.Mouse == m)));
	catch
		cellUID = uint64([]);
	end
end

function act = iActiveAt1s(X, baseMask, idx1, kSigma)
	baseMu = mean(X(:, baseMask), 2, 'omitnan');
	baseSd = std(X(:, baseMask), 0, 2, 'omitnan');
	val1 = X(:, idx1);
	act = val1 > (baseMu + kSigma .* baseSd);
end

function [m, s, n] = iMeanSemAcrossMice(curveCell, nT)
	m = nan(nT,1);
	s = nan(nT,1);
	n = 0;
	if isempty(curveCell)
		return;
	end
	try
		M = nan(nT, numel(curveCell));
		for i = 1:numel(curveCell)
			v = curveCell{i};
			if isempty(v) || numel(v) ~= nT
				continue;
			end
			M(:,i) = v(:);
		end
		good = any(isfinite(M),1);
		M = M(:,good);
		n = size(M,2);
		m = mean(M, 2, 'omitnan');
		s = std(M, 0, 2, 'omitnan') ./ sqrt(max(1,n));
	catch
	end
end

function p = iRankSumP(x, y)
	x = x(isfinite(x));
	y = y(isfinite(y));
	p = NaN;
	if numel(x) < 3 || numel(y) < 3
		return;
	end
	try
		p = ranksum(x, y);
	catch
		p = NaN;
	end
end

function [p, nPairs] = iSignrankPairedVec(x, y)
	mask = isfinite(x) & isfinite(y);
	x = x(mask);
	y = y(mask);
	nPairs = numel(x);
	p = NaN;
	if nPairs < 4
		return;
	end
	try
		p = signrank(x, y);
	catch
		p = NaN;
	end
end

function rows = iRemoveDuplicateMice(rows, tag)
	if isempty(rows)
		return;
	end
	m = string(rows.Mouse);
	[um, ia] = unique(m, 'stable');
	if numel(um) ~= numel(m)
		dup = setdiff(m, um(ia)); %#ok<NASGU>
		fprintf('[%s] removing duplicate mice across sources: kept %d/%d\n', tag, numel(ia), numel(m));
		rows = rows(ia, :);
	end
end

function iHideToolbar(ax)
	try
		if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
			ax.Toolbar.Visible = 'off';
		end
	catch
	end
end

function iSwarm2(ax, y1, y2, labels, ylab, pval)
	y1 = y1(:); y2 = y2(:);
	y1 = y1(isfinite(y1));
	y2 = y2(isfinite(y2));
	swarmchart(ax, ones(numel(y1),1), y1, 22, 'filled');
	swarmchart(ax, 2*ones(numel(y2),1), y2, 22, 'filled');
	ax.XLim = [0.5 2.5];
	ax.XTick = [1 2];
	ax.XTickLabel = {sprintf('%s (n=%d)', labels{1}, numel(y1)), sprintf('%s (n=%d)', labels{2}, numel(y2))};
	ylabel(ax, ylab);
	grid(ax,'on');
	box(ax,'on');
	% p-value line (via MATLAB.Graphics.PLine)
	try
		iPValuePLineScatter(ax, 1, 2, y1, y2, pval);
	catch
	end
	% p-value is shown via bracket; do not add statistical text to title.
end

function iPValuePLineScatter(ax, x1, x2, y1, y2, p, opts)
	arguments
		ax
		x1
		x2
		y1
		y2
		p
		opts.extraOffset double = 0
	end
	if ~isfinite(p)
		return;
	end
	y1 = y1(:);
	y2 = y2(:);
	y1 = y1(isfinite(y1));
	y2 = y2(isfinite(y2));
	if isempty(y1) || isempty(y2)
		return;
	end

	% Create an invisible scatter with exactly two unique X values.
	X = [x1*ones(numel(y1),1); x2*ones(numel(y2),1)];
	Y = [y1; y2];
	S = scatter(ax, X, Y, 1, 'k', 'filled', 'Visible','off', 'HandleVisibility','off');
	try
		if isprop(S, 'HitTest'); S.HitTest = 'off'; end
		if isprop(S, 'PickableParts'); S.PickableParts = 'none'; end
		if isprop(S, 'AffectAutoLimits'); S.AffectAutoLimits = false; end
	catch
	end

	Descriptors = table(S, 0, 0, "p=" + sprintf('%.3g', p), opts.extraOffset, ...
		'VariableNames', {'ObjectA','IndexA','IndexB','Text','ExtraOffset'});
	try
		MATLAB.Graphics.PLine(Descriptors);
	catch
		% fallback
		try
			yAll = Y(isfinite(Y));
			if isempty(yAll); return; end
			yMax = max(yAll);
			yMin = min(yAll);
			yR = max(1e-6, yMax - yMin);
			y0 = yMax + 0.12*yR;
			plot(ax, [x1 x1 x2 x2], [y0-0.01*yR y0 y0 y0-0.01*yR], 'k-', 'LineWidth', 1);
			text(ax, mean([x1 x2]), y0, sprintf('p=%.3g', p), 'HorizontalAlignment','center', 'VerticalAlignment','bottom', 'Interpreter','none');
		catch
		end
	end

	try
		delete(S);
	catch
	end
end

function [DescriptorRow, S] = iPLineScatterDescriptor(ax, x1, x2, y1, y2, p, opts)
	arguments
		ax
		x1
		x2
		y1
		y2
		p
		opts.extraOffset double = 0
	end
	vn = {'ObjectA','IndexA','IndexB','Text','ExtraOffset'};
	DescriptorRow = table(matlab.graphics.GraphicsPlaceholder.empty(0,1), zeros(0,1), zeros(0,1), strings(0,1), zeros(0,1), ...
		'VariableNames', vn);
	S = gobjects(0,1);
	if ~isfinite(p)
		return;
	end
	y1 = y1(:);
	y2 = y2(:);
	y1 = y1(isfinite(y1));
	y2 = y2(isfinite(y2));
	if isempty(y1) || isempty(y2)
		return;
	end
	X = [x1*ones(numel(y1),1); x2*ones(numel(y2),1)];
	Y = [y1; y2];
	S = scatter(ax, X, Y, 1, 'k', 'filled', 'Visible','off', 'HandleVisibility','off');
	try
		if isprop(S, 'HitTest'); S.HitTest = 'off'; end
		if isprop(S, 'PickableParts'); S.PickableParts = 'none'; end
		if isprop(S, 'AffectAutoLimits'); S.AffectAutoLimits = false; end
	catch
	end
	DescriptorRow = table(S, 0, 0, "p=" + sprintf('%.3g', p), opts.extraOffset, ...
		'VariableNames', vn);
end

function diag = iMouseSessionPurityDiag(DS, mice, opts)
	arguments
		DS
		mice
		opts.phaseName string
		opts.stimulusName string
		opts.forbiddenStimulus string = string([])
	end
	diag = table(string.empty(0,1), string.empty(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), nan(0,1), ...
		'VariableNames', {'Mouse','Source','NTrials_Target','NSessions_Target','NSessions_PureTarget','NSessions_MixedWithForbidden','NTrials_ForbiddenInPhase'});
	for iM = 1:numel(mice)
		m = string(mice(iM));
		% Query all trials in this phase for this mouse (so we can see mixing within DateTime)
		T = iTableQueryOrEmpty(DS, ["TrialUID","Mouse","DateTime","Phase","Stimulus"], Mouse=m, Phase=opts.phaseName);
		if isempty(T)
			diag = [diag; table(m, "", 0, 0, 0, 0, 0, 'VariableNames', diag.Properties.VariableNames)]; %#ok<AGROW>
			continue;
		end
		T.Mouse = string(T.Mouse);
		T.Phase = string(T.Phase);
		T.Stimulus = string(T.Stimulus);
		T = iNormalizeDateTime(T);
		T = T(~ismissing(T.DateTime), :);
		if isempty(T)
			diag = [diag; table(m, "", 0, 0, 0, 0, 0, 'VariableNames', diag.Properties.VariableNames)]; %#ok<AGROW>
			continue;
		end

		% Target trials/sessions
		isTarget = (T.Stimulus == opts.stimulusName);
		nTrialsTarget = nnz(isTarget);
		dtTarget = unique(T.DateTime(isTarget));
		dtTarget = dtTarget(~ismissing(dtTarget));
		nSessTarget = numel(dtTarget);

		% Forbidden trials in same phase (regardless of DateTime)
		forbidden = string(opts.forbiddenStimulus);
		nTrialsForbidden = 0;
		if ~isempty(forbidden)
			nTrialsForbidden = nnz(T.Stimulus == forbidden);
		end

		nSessPure = 0;
		nSessMixed = 0;
		if nSessTarget > 0 && ~isempty(forbidden)
			for iD = 1:numel(dtTarget)
				dt = dtTarget(iD);
				stims = unique(T.Stimulus(T.DateTime==dt));
				if any(stims == forbidden)
					nSessMixed = nSessMixed + 1;
				else
					nSessPure = nSessPure + 1;
				end
			end
		elseif nSessTarget > 0
			% No forbidden specified => treat all as pure
			nSessPure = nSessTarget;
		end

		diag = [diag; table(m, "", nTrialsTarget, nSessTarget, nSessPure, nSessMixed, nTrialsForbidden, ...
			'VariableNames', diag.Properties.VariableNames)]; %#ok<AGROW>
	end
end
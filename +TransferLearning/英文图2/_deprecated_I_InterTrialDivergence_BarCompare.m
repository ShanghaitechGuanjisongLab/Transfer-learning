% [DEPRECATED] 已被 v6 设计文档 Panel E (E_DivergenceBarCompare_Dual) 替代
%
% 英文图1L：Inter-trial divergence（Bar compare）
%
% Compare two groups (paired by mouse):
%   - Naive AudioOnly
%   - Learned AudioWater
%
% Divergence computed per mouse, using the same cohort sources as PCA:
%   - TransferLearning.AudioLightBaseline()
%   - TransferLearning.ALInterspersed()
%
% Plot style: UniExp.BarScatterCompare (no manual bars)
% Output: SVG to \\Data-Server-2\个人数据\张天夫\202601
%
% Execution:
%   TransferLearning.英文图1.L_InterTrialDivergence_BarCompare

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "English_Fig2I_InterTrialDivergence_BarCompare.svg";

stimulusLearned = "AudioWater";
stimulusNaiveAO = "AudioOnly";

% Baseline time (seconds) for normalization (subtract this timepoint)
baselineSec = 0;

% Toggle late-peak cell filtering (true = filter, false = use all cells)
useCellFilter = true;

% --- 0) Ensure project loaded
try
	if ~exist('UniExp.DataSet','class')
		thisFile = mfilename('fullpath');
		thisDir = fileparts(thisFile);
		prjFile = fullfile(thisDir, '..', '..', 'Transferlearning.prj');
		if exist(prjFile,'file')
			try matlab.project.loadProject(prjFile); catch, end
		end
	end
catch
end

% --- 1) Datasets
Sources = {
	builtin('struct', 'Name', "AudioLightBaseline", 'DS', TransferLearning.AudioLightBaseline())
	builtin('struct', 'Name', "ALInterspersed",     'DS', TransferLearning.ALInterspersed())
};

perSource = cell(size(Sources));
diagSource = cell(size(Sources));
for iS = 1:numel(Sources)
	[perSource{iS}, diagSource{iS}] = iPerSourceDivergence( ...
		Sources{iS}.DS, Sources{iS}.Name, stimulusLearned, stimulusNaiveAO, baselineSec, useCellFilter);
	try
		d = diagSource{iS};
		fprintf('%s: candidate mice=%d, with NTS=%d, finite both=%d\n', string(d.Source), d.NCandidateMice, d.NWithNTS, d.NFiniteBoth);
	catch
	end
end

allPerMouse = vertcat(perSource{:});
if isempty(allPerMouse)
	error('Fig1L:EmptyAll', 'No mice computed from AudioLightBaseline/ALInterspersed.');
end

% Collapse duplicates across sources by mouse (mean)
[miceAll, naiveAOAll, learnedAWAll, nSrc] = iCollapseByMouse(allPerMouse);

% Consistent mouse set: finite both
keep = isfinite(naiveAOAll) & isfinite(learnedAWAll);
miceKeep = miceAll(keep);
naiveAO = naiveAOAll(keep);
learnedAW = learnedAWAll(keep);

fprintf('Fig1L: %d mice after merging sources\n', numel(miceKeep));
if any(nSrc > 1)
	fprintf('Note: %d mice appeared in multiple sources; values averaged.\n', sum(nSrc > 1));
end

if isempty(miceKeep)
	error('Fig1L:EmptyAfterFilter', 'No mice left after filtering non-finite divergence.');
end

% Stats (paired)
pSignedRank = nan;
try
	pSignedRank = signrank(naiveAO, learnedAW);
	fprintf('Wilcoxon signed-rank (paired): Naive AudioOnly vs Learned AudioWater: p=%.6g\n', pSignedRank);
catch
end

% --- 2) Plot
DataCell = {naiveAO, learnedAW};
CompareGroup = table([1 2], 'VariableNames', {'GroupPair'});

f = figure('Color','w', 'Name', 'English Fig2I Inter-trial divergence');
f.Units = 'centimeters';
f.Position(3:4) = [3.0, 4.0]; % 30mm x 20mm

tiledlayout(1,1,'TileSpacing','compact','Padding','compact');
nexttile;

[~, Optional, Bars, ErrorBars] = UniExp.BarScatterCompare(DataCell, false, CompareGroup, 'AsteriskThreshold', 0.05);
ax = gca;
ax.FontSize = 6;
ax.FontName = 'Segoe UI Emoji';

try
	ax.XTick = [1, 2];
	ax.XTickLabel = {'Naive🔊', '🔊💧100%'};
	legend(ax, 'off');
catch
end

% Set asterisk font size
if isfield(Optional, 'MultiCompare') && ismember('PText', Optional.MultiCompare.Properties.VariableNames)
	for pt = Optional.MultiCompare.PText(:)'
		pt.FontSize = 6;
	end
end

% Bar styling (red/blue)
colorNaive = [1 0 0];
colorLearn = [0 0 1];
try
	if numel(Bars) == 1
		Bars.FaceColor = 'flat';
		nBars = numel(Bars.YData);
		reps = ceil(nBars/2);
		Bars.CData = repmat([colorNaive; colorLearn], reps, 1);
		Bars.CData = Bars.CData(1:nBars, :);
		Bars.BarWidth = 0.5;
		Bars.LineWidth = 0.5;
		Bars.FaceAlpha = 1/3;
	else
		if numel(Bars) >= 2
			Bars(1).FaceColor = colorNaive;
			Bars(2).FaceColor = colorLearn;
			Bars(1).LineWidth = 0.5;
			Bars(2).LineWidth = 0.5;
			Bars(1).FaceAlpha = 1/3;
			Bars(2).FaceAlpha = 1/3;
		end
	end
catch
end

for eb = ErrorBars.Object(:)'
	eb.LineWidth = 0.5;
end

ylabel(ax, 'Divergence', 'FontSize', 6);
box(ax, 'off');
try, ax.Toolbar.Visible = 'off'; catch, end

% --- 3) Export
try
	if ~isfolder(outDirUNC)
		mkdir(outDirUNC);
	end
catch
end

svgPath = fullfile(outDirUNC, svgName);
TransferLearning.PrintFigure(f, svgPath);
fprintf('Wrote: %s\n', svgPath);

% Save summary to base
Summary = table;
Summary.Group = ["NaiveAO"; "LearnedAW"];
Summary.N = [numel(naiveAO); numel(learnedAW)];
Summary.Mean = [mean(naiveAO,'omitnan'); mean(learnedAW,'omitnan')];
Summary.SEM = [std(naiveAO,'omitnan')/sqrt(numel(naiveAO)); std(learnedAW,'omitnan')/sqrt(numel(learnedAW))];
Summary.P_SignRank_NaiveAO_vs_LearnedAW = repmat(pSignedRank, 2, 1);
assignin('base', 'Fig1L_InterTrialDivergence_Summary', Summary);
assignin('base', 'Fig1L_InterTrialDivergence_PerMouse', table(miceKeep, naiveAO, learnedAW, 'VariableNames', {'Mouse','NaiveAO','LearnedAW'}));

function [perMouse, diag] = iPerSourceDivergence(DS, sourceName, stimulusLearned, stimulusNaiveAO, baselineSec, useCellFilter)
% Per source: compute per-mouse divergence for Naive AudioOnly and Learned AudioWater.

diag = builtin('struct');
diag.Source = string(sourceName);
diag.NCandidateMice = 0;
diag.NWithNTS = 0;
diag.NFiniteBoth = 0;

TLearned = DS.TableQuery(["Mouse","DateTime"], Phase="Learned", Stimulus=stimulusLearned);
TNaiveAO = DS.TableQuery(["Mouse","DateTime"], Phase="Naive",  Stimulus=stimulusNaiveAO);
if isempty(TLearned) || isempty(TNaiveAO)
	perMouse = table(string.empty(0,1), nan(0,1), nan(0,1), strings(0,1), ...
		'VariableNames', {'Mouse','NaiveAO','LearnedAW','Source'});
	return
end

TLearned.Mouse = string(TLearned.Mouse);
TNaiveAO.Mouse = string(TNaiveAO.Mouse);
TLearned.DateTime = datetime(TLearned.DateTime); try, TLearned.DateTime.TimeZone = ''; catch, end
TNaiveAO.DateTime = datetime(TNaiveAO.DateTime); try, TNaiveAO.DateTime.TimeZone = ''; catch, end

mice = intersect(unique(TLearned.Mouse), unique(TNaiveAO.Mouse));
diag.NCandidateMice = numel(mice);
if isempty(mice)
	perMouse = table(string.empty(0,1), nan(0,1), nan(0,1), strings(0,1), ...
		'VariableNames', {'Mouse','NaiveAO','LearnedAW','Source'});
	return
end

learnDt = NaT(numel(mice),1);
aoDt = NaT(numel(mice),1);
for i = 1:numel(mice)
	m = mice(i);
	learnDt(i) = max(TLearned.DateTime(TLearned.Mouse == m));
	aoDt(i) = min(TNaiveAO.DateTime(TNaiveAO.Mouse == m));
end

naiveAODiv = nan(numel(mice),1);
learnDiv = nan(numel(mice),1);
hasNts = false(numel(mice),1);

for i = 1:numel(mice)
	m = mice(i);

	% Naive AO
	ntsAO = iQueryNtsOnce(DS, stimulusNaiveAO, m);
	if isempty(ntsAO)
		continue
	end
	% Learned AW
	ntsLW = iQueryNtsOnce(DS, stimulusLearned, m);
	if isempty(ntsLW)
		continue
	end
	hasNts(i) = true;

	[trialUIDsAO, nts2AO] = iPrepareSessionTrials(DS, ntsAO, "Naive", stimulusNaiveAO, m, aoDt(i));
	[trialUIDsL,  nts2L]  = iPrepareSessionTrials(DS, ntsLW, "Learned", stimulusLearned, m, learnDt(i));
	if isempty(trialUIDsAO) || isempty(trialUIDsL) || isempty(nts2AO) || isempty(nts2L)
		continue
	end

	ntatsAO = iQueryNtatsSession(DS, stimulusNaiveAO, m, "Naive", aoDt(i));
	ntatsL  = iQueryNtatsSession(DS, stimulusLearned,  m, "Learned", learnDt(i));

	if useCellFilter
		keepAO = iSelectLatePeakCellsNtats(ntatsAO);
		keepL  = iSelectLatePeakCellsNtats(ntatsL);
	else
		keepAO = unique(uint64(nts2AO.CellUID));
		keepL  = unique(uint64(nts2L.CellUID));
	end
	if isempty(keepAO) || isempty(keepL)
		continue
	end

	naiveAODiv(i) = iDivergenceForMouseSession(nts2AO, trialUIDsAO, keepAO, baselineSec);
	learnDiv(i)   = iDivergenceForMouseSession(nts2L,  trialUIDsL,  keepL,  baselineSec);
end

diag.NWithNTS = sum(hasNts);
keep = isfinite(naiveAODiv) & isfinite(learnDiv);
diag.NFiniteBoth = sum(keep);

perMouse = table(mice(keep), naiveAODiv(keep), learnDiv(keep), repmat(string(sourceName), sum(keep), 1), ...
	'VariableNames', {'Mouse','NaiveAO','LearnedAW','Source'});
end

function [miceOut, naiveAOOut, learnedAWOut, nSourceOut] = iCollapseByMouse(T)
T.Mouse = string(T.Mouse);
[G, miceOut] = findgroups(T.Mouse);
naiveAOOut = splitapply(@(x) mean(x,'omitnan'), T.NaiveAO, G);
learnedAWOut = splitapply(@(x) mean(x,'omitnan'), T.LearnedAW, G);
nSourceOut = splitapply(@(x) numel(unique(string(x))), T.Source, G);
end

function nts = iQueryNtsOnce(DS, stimulusName, mouseId)
nts = [];
try
	ntsCell = DS.QueryNTS(struct('Stimulus', string(stimulusName), 'Mouse', string(mouseId)), UniExp.Flags.DeltaF, 1:24);
	if iscell(ntsCell) && ~isempty(ntsCell)
		nts = ntsCell{1};
	else
		nts = ntsCell;
	end
catch
	nts = [];
end
end

function ntatsGroup = iQueryNtatsSession(DS, stimulusName, mouseId, phaseName, sessionDateTime)
ntatsGroup = [];
queryStruct = struct('Stimulus', string(stimulusName), 'Phase', string(phaseName), 'Mouse', string(mouseId), 'DateTime', sessionDateTime);
try
	ntatsGroup = DS.QueryNTATS(queryStruct, UniExp.Flags.DeltaF, 1:24, UniExp.Flags.Median);
catch
	ntatsGroup = [];
end
end

function [trialUIDs, nts2] = iPrepareSessionTrials(DS, nts, phaseName, stimulusName, mouseId, sessionDateTime)
trialUIDs = uint64([]);
nts2 = [];
try
	T = DS.TableQuery(["TrialUID","TrialIndex"], Phase=phaseName, Stimulus=stimulusName, Mouse=mouseId, DateTime=sessionDateTime);
catch
	return
end
if isempty(T)
	return
end
T = sortrows(T, "TrialIndex");
trialUIDs = uint64(T.TrialUID);
trialUIDs = unique(trialUIDs(:), 'stable');
try
	inTrial = ismember(uint64(nts.TrialUID), trialUIDs);
	nts2 = nts(inTrial, :);
catch
	trialUIDs = uint64([]);
	nts2 = [];
	return
end
if isempty(nts2)
	trialUIDs = uint64([]);
	return
end
uNts = unique(uint64(nts2.TrialUID));
trialUIDs = trialUIDs(ismember(trialUIDs, uNts));
if numel(trialUIDs) < 2
	trialUIDs = uint64([]);
	nts2 = [];
	return
end
end

function keepUids = iSelectLatePeakCellsNtats(ntatsGroup)
keepUids = uint64([]);
if isempty(ntatsGroup) || height(ntatsGroup) == 0
	return
end

try
	data = ntatsGroup.NTATS{:,:, 1};
catch
	return
end

data = squeeze(data);
if ~ismatrix(data)
	return
end

cellUIDs = uint64(ntatsGroup.CellUID);
sampleRate = 8;
idxCue0 = 3 * sampleRate;
idx0 = max(1, min(size(data, 2), idxCue0));
sigNtats = data - data(:, idx0);

idx0_1 = idxCue0:(idxCue0 + sampleRate);
idx1_2 = (idxCue0 + sampleRate):(idxCue0 + 2 * sampleRate);
idx0_1 = idx0_1(idx0_1 >= 1 & idx0_1 <= size(sigNtats, 2));
idx1_2 = idx1_2(idx1_2 >= 1 & idx1_2 <= size(sigNtats, 2));
if isempty(idx0_1) || isempty(idx1_2)
	return
end

peak0_1 = max(sigNtats(:, idx0_1), [], 2);
peak1_2 = max(sigNtats(:, idx1_2), [], 2);
keepUids = cellUIDs(peak1_2 > peak0_1);
end

function div = iDivergenceForMouseSession(nts2, trialUIDs, keepUids, baselineSec)
div = nan;
if isempty(trialUIDs) || isempty(nts2) || isempty(keepUids)
	return
end

cellUIDs = unique(uint64(nts2.CellUID));
cellUIDs = cellUIDs(ismember(cellUIDs, uint64(keepUids)));
if isempty(cellUIDs)
	return
end

cellTraces = cell(0,1);
for iC = 1:numel(cellUIDs)
	cid = cellUIDs(iC);
	rowsC = (uint64(nts2.CellUID) == cid);
	if sum(rowsC) < numel(trialUIDs)
		continue
	end
	uid = uint64(nts2.TrialUID(rowsC));
	sig = double(nts2.TrialSignal(rowsC, :));
	[tf, loc] = ismember(trialUIDs, uid);
	if ~all(tf)
		continue
	end
	sigOrdered = sig(loc, :);
	if any(~isfinite(sigOrdered), 'all')
		continue
	end
	cellTraces{end+1,1} = sigOrdered; %#ok<AGROW>
end

if isempty(cellTraces)
	return
end

nCells = numel(cellTraces);
nTrials = size(cellTraces{1}, 1);
nTime = size(cellTraces{1}, 2);
CellTrialTimes = nan(nCells, nTrials, nTime);
for iC = 1:nCells
	CellTrialTimes(iC,:,:) = cellTraces{iC};
end

% Baseline normalization at baselineSec
sampleRate = 8;
idx0 = 3 * sampleRate + round(baselineSec * sampleRate);
idx0 = max(1, min(nTime, idx0));
baseline0 = CellTrialTimes(:,:,idx0);
CellTrialTimes = CellTrialTimes - baseline0;

div = TransferLearning.Divergence(CellTrialTimes);
end

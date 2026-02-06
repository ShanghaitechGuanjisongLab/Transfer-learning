% Script: AudioWater_Divergence_NaiveLearned_LikeEnglishFig1L
% TransferLearning.AudioWater_Divergence_NaiveLearned_LikeEnglishFig1L
%
% Divergence comparison for AudioWater using the SAME cohort sources as the PCA plot,
% and additionally including ALInterspersed per user request:
%   - TransferLearning.AudioLightBaseline()
%   - TransferLearning.ALInterspersed()
%
% Per-mouse:
%   - Naive: earliest AudioWater session
%   - Learned: latest AudioWater session
%   - Use ALL trials within each chosen session
%
% Plot style: like English Fig1L (UniExp.BarScatterCompare + bar styling)
% Output: SVG to \\Data-Server-2\个人数据\张天夫\202601

outDirUNC = "\\Data-Server-2\个人数据\张天夫\202601";
svgName = "AudioWater_Divergence_NaiveVsLearned_LikeEnglishFig1L.svg";

% --- 0) Ensure project loaded (for UniExp)
try
	if ~exist('UniExp.DataSet','class')
		thisFile = mfilename('fullpath');
		thisDir = fileparts(thisFile);
		prjFile = fullfile(thisDir, '..', 'Transferlearning.prj');
		if exist(prjFile,'file')
			try
				matlab.project.loadProject(prjFile);
			catch
			end
		end
	end
catch
end

stimulusName = "AudioWater";
stimulusAudioOnly = "AudioOnly";

% Baseline time (seconds) for normalization (subtract this timepoint)
baselineSec = 0;

% Toggle late-peak cell filtering (true = filter, false = use all cells)
useCellFilter = true;

% --- 1) Datasets
Sources = {
	builtin('struct', 'Name', "AudioLightBaseline", 'DS', TransferLearning.AudioLightBaseline())
	builtin('struct', 'Name', "ALInterspersed",     'DS', TransferLearning.ALInterspersed())
};

perSource = cell(size(Sources));
diagSource = cell(size(Sources));
for iS = 1:numel(Sources)
	[perSource{iS}, diagSource{iS}] = iPerSourceDivergence(Sources{iS}.DS, Sources{iS}.Name, stimulusName, stimulusAudioOnly, baselineSec, useCellFilter);
	try
		d = diagSource{iS};
		fprintf('%s: candidate mice=%d, with NTS=%d, finite both=%d\n', string(d.Source), d.NCandidateMice, d.NWithNTS, d.NFiniteBoth);
	catch
	end
end

allPerMouse = vertcat(perSource{:});
if isempty(allPerMouse)
	error('AudioWaterDiv:EmptyAll', 'No mice computed from AudioLightBaseline/ALInterspersed for Stimulus=%s.', stimulusName);
end

% Collapse duplicates across sources by mouse (mean)
[miceAll, naiveAWAll, learnAWAll, naiveAOAll, nSrc] = iCollapseByMouse(allPerMouse);

% Use a consistent mouse set that has all three values.
keepAll = isfinite(naiveAWAll) & isfinite(learnAWAll) & isfinite(naiveAOAll);
miceKeep = miceAll(keepAll);
naiveKeep = naiveAWAll(keepAll);
learnKeep = learnAWAll(keepAll);
naiveAudioOnlyKeep = naiveAOAll(keepAll);

fprintf('AudioWater divergence (NaiveAW vs LearnedAW; plus NaiveAO vs LearnedAW): %d mice after merging sources\n', numel(miceKeep));
if any(nSrc > 1)
	fprintf('Note: %d mice appeared in multiple sources; values averaged.\n', sum(nSrc > 1));
end

if isempty(miceKeep)
	error('AudioWaterDiv:EmptyAfterFilter', 'No mice left after filtering non-finite divergence.');
end

% Stats (paired, same mice)
pSignedRank_AW = nan;
pSignedRank_AO = nan;
try
	pSignedRank_AW = signrank(naiveKeep, learnKeep);
	fprintf('Wilcoxon signed-rank (paired): Naive AudioWater vs Learned AudioWater: p=%.6g\n', pSignedRank_AW);
catch
end
try
	pSignedRank_AO = signrank(naiveAudioOnlyKeep, learnKeep);
	fprintf('Wilcoxon signed-rank (paired): Naive AudioOnly vs Learned AudioWater: p=%.6g\n', pSignedRank_AO);
catch
end

% --- 4) Plot (like English Fig1L)
DataCell = {naiveKeep, learnKeep, naiveAudioOnlyKeep};
CompareGroup = table([1 2; 3 2], 'VariableNames', {'GroupPair'});

f = figure('Color','w', 'Name', 'AudioWater divergence (NaiveAW/LearnedAW/NaiveAO)');
f.Units = 'centimeters';
f.Position(3:4) = [3.0, 2.0]; % 30mm x 20mm

tiledlayout(1,1,'TileSpacing','compact','Padding','compact');
nexttile;

[~, Optional, Bars, ErrorBars] = UniExp.BarScatterCompare(DataCell, false, CompareGroup, 'AsteriskThreshold', 0.05);
ax = gca;
ax.FontSize = 6;

try
	ax.XTick = [1, 2, 3];
	ax.XTickLabel = {'Nai.AW', 'Lea.AW', 'Nai.AO'};
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
		reps = ceil(nBars/3);
		Bars.CData = repmat([colorNaive; colorLearn; colorNaive], reps, 1);
		Bars.CData = Bars.CData(1:nBars, :);
		Bars.BarWidth = 0.5;
		Bars.LineWidth = 0.5;
		Bars.FaceAlpha = 1/3;
	else
		if numel(Bars) >= 3
			Bars(1).FaceColor = colorNaive;
			Bars(2).FaceColor = colorLearn;
			Bars(3).FaceColor = colorNaive;
			Bars(1).LineWidth = 0.5;
			Bars(2).LineWidth = 0.5;
			Bars(3).LineWidth = 0.5;
			Bars(1).FaceAlpha = 1/3;
			Bars(2).FaceAlpha = 1/3;
			Bars(3).FaceAlpha = 1/3;
		end
	end
catch
end

for eb = ErrorBars.Object(:)'
	eb.LineWidth = 0.5;
end

try
	ax.XLim = [0.5, 3.5];
catch
end

ylabel(ax, 'Divergence', 'FontSize', 6);
box(ax, 'off');
try, ax.Toolbar.Visible = 'off'; catch, end

% --- 5) Export
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
Summary.Group = ["NaiveAW"; "LearnedAW"; "NaiveAO"];
Summary.N = [numel(naiveKeep); numel(learnKeep); numel(naiveAudioOnlyKeep)];
Summary.Mean = [mean(naiveKeep,'omitnan'); mean(learnKeep,'omitnan'); mean(naiveAudioOnlyKeep,'omitnan')];
Summary.SEM = [std(naiveKeep,'omitnan')/sqrt(numel(naiveKeep)); std(learnKeep,'omitnan')/sqrt(numel(learnKeep)); std(naiveAudioOnlyKeep,'omitnan')/sqrt(numel(naiveAudioOnlyKeep))];
Summary.P_SignRank_NaiveAW_vs_LearnedAW = repmat(pSignedRank_AW, 3, 1);
Summary.P_SignRank_NaiveAO_vs_LearnedAW = repmat(pSignedRank_AO, 3, 1);
assignin('base', 'AudioWater_Divergence_NaiveLearned_Summary', Summary);
assignin('base', 'AudioWater_Divergence_NaiveLearned_PerMouse', table(miceKeep, naiveKeep, learnKeep, naiveAudioOnlyKeep, 'VariableNames', {'Mouse','NaiveAW','LearnedAW','NaiveAO'}));


function [perMouse, diag] = iPerSourceDivergence(DS, sourceName, stimulusName, stimulusAudioOnly, baselineSec, useCellFilter)
% Compute per-mouse Naive/Learned divergence within one dataset source.

diag = builtin('struct');
diag.Source = string(sourceName);
diag.NCandidateMice = 0;
diag.NWithNTS = 0;
diag.NFiniteBoth = 0;

Tn = DS.TableQuery(["Mouse","DateTime"], Phase="Naive",  Stimulus=stimulusName);
Tl = DS.TableQuery(["Mouse","DateTime"], Phase="Learned", Stimulus=stimulusName);
Ta = DS.TableQuery(["Mouse","DateTime"], Phase="Naive",  Stimulus=stimulusAudioOnly);
if isempty(Tn) || isempty(Tl)
	perMouse = table(string.empty(0,1), nan(0,1), nan(0,1), nan(0,1), strings(0,1), ...
		'VariableNames', {'Mouse','Naive','Learned','NaiveAudioOnly','Source'});
	return
end

Tn.Mouse = string(Tn.Mouse);
Tl.Mouse = string(Tl.Mouse);
Ta.Mouse = string(Ta.Mouse);
Tn.DateTime = datetime(Tn.DateTime); try, Tn.DateTime.TimeZone = ''; catch, end
Tl.DateTime = datetime(Tl.DateTime); try, Tl.DateTime.TimeZone = ''; catch, end
Ta.DateTime = datetime(Ta.DateTime); try, Ta.DateTime.TimeZone = ''; catch, end

mice = intersect(unique(Tn.Mouse), unique(Tl.Mouse));
diag.NCandidateMice = numel(mice);
if isempty(mice)
	perMouse = table(string.empty(0,1), nan(0,1), nan(0,1), nan(0,1), strings(0,1), ...
		'VariableNames', {'Mouse','Naive','Learned','NaiveAudioOnly','Source'});
	return
end

naiveDt = NaT(numel(mice),1);
learnDt = NaT(numel(mice),1);
audioOnlyDt = NaT(numel(mice),1);
for i = 1:numel(mice)
	m = mice(i);
	naiveDt(i) = min(Tn.DateTime(Tn.Mouse == m));
	learnDt(i) = max(Tl.DateTime(Tl.Mouse == m));
	if ~isempty(Ta)
		try
			audioOnlyDt(i) = min(Ta.DateTime(Ta.Mouse == m));
		catch
			audioOnlyDt(i) = NaT;
		end
	end
end

naiveDiv = nan(numel(mice),1);
learnDiv = nan(numel(mice),1);
audioOnlyDiv = nan(numel(mice),1);
hasNts = false(numel(mice),1);

for i = 1:numel(mice)
	m = mice(i);
	nts = iQueryNtsOnce(DS, stimulusName, m);
	if isempty(nts)
		continue
	end
	hasNts(i) = true;
	[trialUIDsN, nts2N] = iPrepareSessionTrials(DS, nts, "Naive", stimulusName, m, naiveDt(i));
	[trialUIDsL, nts2L] = iPrepareSessionTrials(DS, nts, "Learned", stimulusName, m, learnDt(i));
	if isempty(trialUIDsN) || isempty(trialUIDsL) || isempty(nts2N) || isempty(nts2L)
		continue
	end
	ntatsN = iQueryNtatsSession(DS, stimulusName, m, "Naive", naiveDt(i));
	ntatsL = iQueryNtatsSession(DS, stimulusName, m, "Learned", learnDt(i));
	ntatsA = [];
	trialUIDsA = uint64([]);
	nts2A = [];
	if ~ismissing(audioOnlyDt(i))
		ntsA = iQueryNtsOnce(DS, stimulusAudioOnly, m);
		if ~isempty(ntsA)
			[trialUIDsA, nts2A] = iPrepareSessionTrials(DS, ntsA, "Naive", stimulusAudioOnly, m, audioOnlyDt(i));
			ntatsA = iQueryNtatsSession(DS, stimulusAudioOnly, m, "Naive", audioOnlyDt(i));
		end
	end
	if useCellFilter
		keepN = iSelectLatePeakCellsNtats(ntatsN);
		keepL = iSelectLatePeakCellsNtats(ntatsL);
		keepA = iSelectLatePeakCellsNtats(ntatsA);
	else
		keepN = unique(uint64(nts2N.CellUID));
		keepL = unique(uint64(nts2L.CellUID));
		keepA = unique(uint64(nts2A.CellUID));
	end
	if isempty(keepN) || isempty(keepL)
		continue
	end
	naiveDiv(i) = iDivergenceForMouseSession(nts2N, trialUIDsN, keepN, baselineSec);
	learnDiv(i) = iDivergenceForMouseSession(nts2L, trialUIDsL, keepL, baselineSec);
	if ~isempty(trialUIDsA) && ~isempty(nts2A) && ~isempty(keepA)
		audioOnlyDiv(i) = iDivergenceForMouseSession(nts2A, trialUIDsA, keepA, baselineSec);
	end
end

diag.NWithNTS = sum(hasNts);
keep = isfinite(naiveDiv) & isfinite(learnDiv);
diag.NFiniteBoth = sum(keep);

perMouse = table(mice(keep), naiveDiv(keep), learnDiv(keep), audioOnlyDiv(keep), repmat(string(sourceName), sum(keep), 1), ...
	'VariableNames', {'Mouse','Naive','Learned','NaiveAudioOnly','Source'});
end

function [miceOut, naiveOut, learnedOut, audioOnlyOut, nSourceOut] = iCollapseByMouse(T)
% Collapse duplicates by mouse using mean for Naive/Learned/AudioOnly separately.
T.Mouse = string(T.Mouse);
[G, miceOut] = findgroups(T.Mouse);
naiveOut = splitapply(@(x) mean(x,'omitnan'), T.Naive, G);
learnedOut = splitapply(@(x) mean(x,'omitnan'), T.Learned, G);
audioOnlyOut = splitapply(@(x) mean(x,'omitnan'), T.NaiveAudioOnly, G);
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
% QueryNTATS for a single session to select late-peak cells.
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
	try
		data = ntatsGroup.NTATS{:,:, 1};
	catch
		return
	end
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
